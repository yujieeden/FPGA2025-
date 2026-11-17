// ========================================================================
// Medical Endoscope Advanced Auto White Balance Module
// ========================================================================
module medical_awb_advanced (
    input               clk,                    // 像素时钟
    input               rst_n,                  // 复位信号（低有效）
    
    // 视频流输入接口
    input               vsync_i,                // 输入垂直同步
    input               href_i,                 // 输入行有效
    input       [23:0]  rgb_i,                  // 输入RGB数据 [R,G,B]
    
    // 配置参数接口
    input               awb_enable,             // AWB使能
    input       [2:0]   awb_mode,               // AWB模式选择
    input       [7:0]   color_temp_target,      // 目标色温
    input       [7:0]   saturation_threshold,   // 饱和度阈值
    input       [7:0]   brightness_threshold,   // 亮度阈值
    input       [3:0]   adaptation_speed,       // 适应速度控制
    
    // 手动增益控制（当AWB禁用时使用）
    input       [7:0]   manual_r_gain,
    input       [7:0]   manual_g_gain, 
    input       [7:0]   manual_b_gain,
    
    // 视频流输出接口
    output reg          vsync_o,                // 输出垂直同步
    output reg          href_o,                 // 输出行有效
    output reg  [23:0]  rgb_o,                  // 输出RGB数据 [R,G,B]
    
    // 状态输出
    output reg  [7:0]   r_gain,                 // 当前红色增益
    output reg  [7:0]   g_gain,                 // 当前绿色增益
    output reg  [7:0]   b_gain,                 // 当前蓝色增益
    output reg          awb_locked,             // AWB锁定状态
    output reg  [7:0]   estimated_color_temp    // 估计色温
);

// ========================================================================
// 参数定义
// ========================================================================
localparam MODE_AUTO        = 3'b000;   // 全自动模式
localparam MODE_MANUAL      = 3'b001;   // 手动增益模式  
localparam MODE_PRESET      = 3'b010;   // 预设色温模式
localparam MODE_TISSUE      = 3'b011;   // 组织优化模式
localparam MODE_BLOOD       = 3'b100;   // 血液增强模式

// 预设色温值
localparam COLOR_TEMP_3200K = 8'h40;    // 3200K（暖白）
localparam COLOR_TEMP_4500K = 8'h60;    // 4500K（自然白）
localparam COLOR_TEMP_5500K = 8'h80;    // 5500K（日光）
localparam COLOR_TEMP_6500K = 8'hA0;    // 6500K（冷白）

// ========================================================================
// 内部信号定义
// ========================================================================
reg [23:0] rgb_d1, rgb_d2;
reg href_d1, href_d2, vsync_d1, vsync_d2;

// 统计相关信号
reg [31:0] r_sum, g_sum, b_sum;
reg [31:0] pixel_count;
reg [31:0] valid_pixel_count;
reg [7:0]  r_max, g_max, b_max;
reg [7:0]  r_min, g_min, b_min;

// 灰度世界算法信号
reg [15:0] r_gain_gw, g_gain_gw, b_gain_gw;
reg [15:0] avg_r, avg_g, avg_b;

// 完美反射算法信号  
reg [15:0] r_gain_pr, g_gain_pr, b_gain_pr;

// 色温估计信号
reg [15:0] color_ratio_rb, color_ratio_bg;
reg [7:0]  color_temp_estimated;

// 组织特征检测信号
reg [10:0] tissue_pixel_count;
reg [10:0] blood_pixel_count;
reg        tissue_dominant;
reg        blood_dominant;

// 状态机控制
reg [2:0]  current_state, next_state;
localparam STATE_IDLE      = 3'b000;
localparam STATE_STAT      = 3'b001;
localparam STATE_CALC      = 3'b010;
localparam STATE_APPLY     = 3'b011;
localparam STATE_LOCKED    = 3'b100;

// ========================================================================
// 输入流水线
// ========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rgb_d1 <= 24'h0;
        rgb_d2 <= 24'h0;
        href_d1 <= 1'b0;
        href_d2 <= 1'b0;
        vsync_d1 <= 1'b0;
        vsync_d2 <= 1'b0;
    end else begin
        rgb_d1 <= rgb_i;
        rgb_d2 <= rgb_d1;
        href_d1 <= href_i;
        href_d2 <= href_d1;
        vsync_d1 <= vsync_i;
        vsync_d2 <= vsync_d1;
    end
end

// ========================================================================
// 帧统计模块 - 灰度世界算法、完美反射算法
// ========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_sum <= 32'h0;
        g_sum <= 32'h0;
        b_sum <= 32'h0;
        pixel_count <= 32'h0;
        valid_pixel_count <= 32'h0;
        r_max <= 8'h0;
        g_max <= 8'h0;
        b_max <= 8'h0;
        r_min <= 8'hFF;
        g_min <= 8'hFF;
        b_min <= 8'hFF;
    end else if (vsync_i && !vsync_d1) begin // vsync上升沿，开始新帧
        r_sum <= 32'h0;
        g_sum <= 32'h0;
        b_sum <= 32'h0;
        pixel_count <= 32'h0;
        valid_pixel_count <= 32'h0;
        r_max <= 8'h0;
        g_max <= 8'h0;
        b_max <= 8'h0;
        r_min <= 8'hFF;
        g_min <= 8'hFF;
        b_min <= 8'hFF;
    end else if (href_i && awb_enable) begin
        // 更新统计信息
        r_sum <= r_sum + rgb_i[23:16];
        g_sum <= g_sum + rgb_i[15:8];
        b_sum <= b_sum + rgb_i[7:0];
        pixel_count <= pixel_count + 1;
        
        // 更新最大值
        if (rgb_i[23:16] > r_max) r_max <= rgb_i[23:16];
        if (rgb_i[15:8] > g_max) g_max <= rgb_i[15:8];
        if (rgb_i[7:0] > b_max) b_max <= rgb_i[7:0];
        
        // 更新最小值
        if (rgb_i[23:16] < r_min) r_min <= rgb_i[23:16];
        if (rgb_i[15:8] < g_min) g_min <= rgb_i[15:8];
        if (rgb_i[7:0] < b_min) b_min <= rgb_i[7:0];
        
        // 统计有效像素（非饱和、非过暗）
        if ((rgb_i[23:16] > brightness_threshold) && 
            (rgb_i[23:16] < (255 - saturation_threshold)) &&
            (rgb_i[15:8] > brightness_threshold) && 
            (rgb_i[15:8] < (255 - saturation_threshold)) &&
            (rgb_i[7:0] > brightness_threshold) && 
            (rgb_i[7:0] < (255 - saturation_threshold))) begin
            valid_pixel_count <= valid_pixel_count + 1;
        end
    end
end

// ========================================================================
// 灰度世界算法计算
// ========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        avg_r <= 16'h0;
        avg_g <= 16'h0;
        avg_b <= 16'h0;
        r_gain_gw <= 16'h100; // 1.0的增益
        g_gain_gw <= 16'h100;
        b_gain_gw <= 16'h100;
    end else if (!vsync_i && vsync_d1 && valid_pixel_count > 0) begin // 帧结束
        // 计算平均值
        avg_r <= (r_sum * 256) / valid_pixel_count; // 左移8位用于定点运算
        avg_g <= (g_sum * 256) / valid_pixel_count;
        avg_b <= (b_sum * 256) / valid_pixel_count;
        
        // 计算增益（以绿色为基准）
        if (avg_r != 0) r_gain_gw <= (avg_g * 256) / avg_r;
        else r_gain_gw <= 16'h100;
        
        g_gain_gw <= 16'h100; // 绿色增益保持1.0
        
        if (avg_b != 0) b_gain_gw <= (avg_g * 256) / avg_b;
        else b_gain_gw <= 16'h100;
        
        // 增益限制（防止过度放大）
        if (r_gain_gw > 16'h200) r_gain_gw <= 16'h200; // 最大2.0倍
        if (b_gain_gw > 16'h200) b_gain_gw <= 16'h200;
        if (r_gain_gw < 16'h80) r_gain_gw <= 16'h80;   // 最小0.5倍
        if (b_gain_gw < 16'h80) b_gain_gw <= 16'h80;
    end
end

// ========================================================================
// 完美反射算法计算
// ========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_gain_pr <= 16'h100;
        g_gain_pr <= 16'h100;
        b_gain_pr <= 16'h100;
    end else if (!vsync_i && vsync_d1 && (r_max > 0) && (g_max > 0) && (b_max > 0)) begin
        // 以最亮像素为白点参考
        r_gain_pr <= (g_max * 256) / r_max;
        g_gain_pr <= 16'h100;
        b_gain_pr <= (g_max * 256) / b_max;
        
        // 增益限制
        if (r_gain_pr > 16'h200) r_gain_pr <= 16'h200;
        if (b_gain_pr > 16'h200) b_gain_pr <= 16'h200;
        if (r_gain_pr < 16'h80) r_gain_pr <= 16'h80;
        if (b_gain_pr < 16'h80) b_gain_pr <= 16'h80;
    end
end

// ========================================================================
// 色温估计模块
// ========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        color_ratio_rb <= 16'h0;
        color_ratio_bg <= 16'h0;
        color_temp_estimated <= 8'h80;
    end else if (!vsync_i && vsync_d1 && (avg_r > 0) && (avg_b > 0) && (avg_g > 0)) begin
        // 计算颜色比率
        color_ratio_rb <= (avg_r * 256) / avg_b;
        color_ratio_bg <= (avg_b * 256) / avg_g;
        
        // 基于比率估计色温（简化模型）
        if (color_ratio_rb > 16'h180) begin        // 红色偏多，低色温
            color_temp_estimated <= 8'h40;         // ~3200K
        end else if (color_ratio_rb > 16'h140) begin
            color_temp_estimated <= 8'h60;         // ~4500K
        end else if (color_ratio_rb > 16'h100) begin
            color_temp_estimated <= 8'h80;         // ~5500K
        end else begin                             // 蓝色偏多，高色温
            color_temp_estimated <= 8'hA0;         // ~6500K
        end
    end
end

// ========================================================================
// 组织特征检测
// ========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tissue_pixel_count <= 11'h0;
        blood_pixel_count <= 11'h0;
        tissue_dominant <= 1'b0;
        blood_dominant <= 1'b0;
    end else if (vsync_i && !vsync_d1) begin // 新帧开始
        tissue_pixel_count <= 11'h0;
        blood_pixel_count <= 11'h0;
        tissue_dominant <= 1'b0;
        blood_dominant <= 1'b0;
    end else if (href_i) begin
        // 组织检测（粉红色调范围）
        if ((rgb_i[23:16] > 8'h80) && (rgb_i[15:8] > 8'h40) && 
            (rgb_i[15:8] < 8'hA0) && (rgb_i[7:0] > 8'h60) && 
            (rgb_i[7:0] < 8'hC0)) begin
            tissue_pixel_count <= tissue_pixel_count + 1;
        end
        
        // 血液检测（红色调范围）
        if ((rgb_i[23:16] > 8'hA0) && (rgb_i[15:8] < 8'h60) && 
            (rgb_i[7:0] < 8'h60)) begin
            blood_pixel_count <= blood_pixel_count + 1;
        end
        
        // 帧结束时判断主导特征
        if (!vsync_i && vsync_d1) begin
            if (tissue_pixel_count > blood_pixel_count) begin
                tissue_dominant <= 1'b1;
                blood_dominant <= 1'b0;
            end else if (blood_pixel_count > tissue_pixel_count) begin
                tissue_dominant <= 1'b0;
                blood_dominant <= 1'b1;
            end else begin
                tissue_dominant <= 1'b0;
                blood_dominant <= 1'b0;
            end
        end
    end
end

// ========================================================================
// AWB状态机
// ========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= STATE_IDLE;
    end else begin
        current_state <= next_state;
    end
end

always @(*) begin
    case (current_state)
        STATE_IDLE: begin
            if (vsync_i && awb_enable) 
                next_state = STATE_STAT;
            else
                next_state = STATE_IDLE;
        end
        STATE_STAT: begin
            if (!vsync_i) 
                next_state = STATE_CALC;
            else
                next_state = STATE_STAT;
        end
        STATE_CALC: begin
            next_state = STATE_APPLY;
        end
        STATE_APPLY: begin
            if (adaptation_speed > 4'h8) // 快速适应
                next_state = STATE_LOCKED;
            else if (vsync_i)
                next_state = STATE_LOCKED;
            else
                next_state = STATE_APPLY;
        end
        STATE_LOCKED: begin
            if (!awb_enable || !vsync_i)
                next_state = STATE_IDLE;
            else
                next_state = STATE_LOCKED;
        end
        default: next_state = STATE_IDLE;
    endcase
end

// ========================================================================
// 增益计算和选择
// ========================================================================
reg [15:0] target_r_gain, target_g_gain, target_b_gain;
reg [15:0] current_r_gain, current_g_gain, current_b_gain;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        target_r_gain <= 16'h100;
        target_g_gain <= 16'h100;
        target_b_gain <= 16'h100;
        current_r_gain <= 16'h100;
        current_g_gain <= 16'h100;
        current_b_gain <= 16'h100;
        awb_locked <= 1'b0;
    end else begin
        case (current_state)
            STATE_CALC: begin
                case (awb_mode)
                    MODE_AUTO: begin
                        // 自动模式：结合灰度世界和完美反射算法
                        target_r_gain <= (r_gain_gw + r_gain_pr) >> 1;
                        target_g_gain <= 16'h100;
                        target_b_gain <= (b_gain_gw + b_gain_pr) >> 1;
                    end
                    MODE_MANUAL: begin
                        target_r_gain <= {8'h0, manual_r_gain};
                        target_g_gain <= {8'h0, manual_g_gain};
                        target_b_gain <= {8'h0, manual_b_gain};
                    end
                    MODE_PRESET: begin
                        // 基于目标色温的预设增益
                        case (color_temp_target)
                            COLOR_TEMP_3200K: begin // 暖白
                                target_r_gain <= 16'h140; // 1.25
                                target_g_gain <= 16'h100; // 1.00
                                target_b_gain <= 16'h0C0; // 0.75
                            end
                            COLOR_TEMP_4500K: begin // 自然白
                                target_r_gain <= 16'h120; // 1.125
                                target_g_gain <= 16'h100; // 1.00
                                target_b_gain <= 16'h0E0; // 0.875
                            end
                            COLOR_TEMP_5500K: begin // 日光
                                target_r_gain <= 16'h100; // 1.00
                                target_g_gain <= 16'h100; // 1.00
                                target_b_gain <= 16'h100; // 1.00
                            end
                            COLOR_TEMP_6500K: begin // 冷白
                                target_r_gain <= 16'h0E0; // 0.875
                                target_g_gain <= 16'h100; // 1.00
                                target_b_gain <= 16'h120; // 1.125
                            end
                            default: begin
                                target_r_gain <= 16'h100;
                                target_g_gain <= 16'h100;
                                target_b_gain <= 16'h100;
                            end
                        endcase
                    end
                    MODE_TISSUE: begin
                        // 组织优化模式：增强组织细节
                        target_r_gain <= 16'h110; // 轻微增强红色
                        target_g_gain <= 16'h100;
                        target_b_gain <= 16'h0F0; // 轻微减弱蓝色
                    end
                    MODE_BLOOD: begin
                        // 血液增强模式：提高血液对比度
                        target_r_gain <= 16'h130; // 显著增强红色
                        target_g_gain <= 16'h100;
                        target_b_gain <= 16'h0D0; // 显著减弱蓝色
                    end
                    default: begin
                        target_r_gain <= 16'h100;
                        target_g_gain <= 16'h100;
                        target_b_gain <= 16'h100;
                    end
                endcase
                awb_locked <= 1'b0;
            end
            STATE_APPLY: begin
                // 平滑过渡到目标增益
                if (current_r_gain < target_r_gain) 
                    current_r_gain <= current_r_gain + adaptation_speed;
                else if (current_r_gain > target_r_gain)
                    current_r_gain <= current_r_gain - adaptation_speed;
                    
                if (current_g_gain < target_g_gain) 
                    current_g_gain <= current_g_gain + adaptation_speed;
                else if (current_g_gain > target_g_gain)
                    current_g_gain <= current_g_gain - adaptation_speed;
                    
                if (current_b_gain < target_b_gain) 
                    current_b_gain <= current_b_gain + adaptation_speed;
                else if (current_b_gain > target_b_gain)
                    current_b_gain <= current_b_gain - adaptation_speed;
            end
            STATE_LOCKED: begin
                awb_locked <= 1'b1;
            end
            default: begin
                // 保持当前增益
            end
        endcase
    end
end

// ========================================================================
// 颜色校正应用
// ========================================================================
reg [23:0] corrected_rgb;
reg [15:0] r_temp, g_temp, b_temp;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_temp <= 16'h0;
        g_temp <= 16'h0;
        b_temp <= 16'h0;
        corrected_rgb <= 24'h0;
    end else if (href_d1) begin
        // 应用增益校正（定点乘法）
        r_temp = (rgb_d1[23:16] * current_r_gain) >> 8;
        g_temp = (rgb_d1[15:8] * current_g_gain) >> 8;
        b_temp = (rgb_d1[7:0] * current_b_gain) >> 8;
        
        // 限幅处理
        corrected_rgb[23:16] <= (r_temp > 255) ? 8'hFF : r_temp[7:0];
        corrected_rgb[15:8]  <= (g_temp > 255) ? 8'hFF : g_temp[7:0];
        corrected_rgb[7:0]   <= (b_temp > 255) ? 8'hFF : b_temp[7:0];
    end
end

// ========================================================================
// 输出流水线
// ========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vsync_o <= 1'b0;
        href_o <= 1'b0;
        rgb_o <= 24'h0;
        r_gain <= 8'h0;
        g_gain <= 8'h0;
        b_gain <= 8'h0;
        estimated_color_temp <= 8'h0;
    end else begin
        vsync_o <= vsync_d2;
        href_o <= href_d2;
        
        if (awb_enable) begin
            rgb_o <= corrected_rgb;
        end else begin
            rgb_o <= rgb_d2; // AWB禁用时直通
        end
        
        // 输出当前状态
        r_gain <= current_r_gain[7:0];
        g_gain <= current_g_gain[7:0];
        b_gain <= current_b_gain[7:0];
        estimated_color_temp <= color_temp_estimated;
    end
end

endmodule