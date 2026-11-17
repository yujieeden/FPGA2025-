// =========================================================================================================================================
// Medical Endoscope AE (Auto Exposure) Module
// =========================================================================================================================================
module medical_ae_controller (
    input                               clk,                    // 像素时钟
    input                               rst_n,                  // 复位信号（低有效）
    
    // 视频流输入接口
    input                               vsync_i,                // 输入垂直同步
    input                               href_i,                 // 输入行有效
    input                               de_i,                   // 输入数据使能
    input               [23:0]          rgb_i,                  // 输入RGB数据
    
    // 视频流输出接口  
    output  reg                         vsync_o,                // 输出垂直同步
    output  reg                         href_o,                 // 输出行有效
    output  reg                         de_o,                   // 输出数据使能
    output  reg         [23:0]          rgb_o,                  // 输出RGB数据
    
    // AE控制接口
    input                               ae_enable,              // AE使能信号
    input               [7:0]           target_brightness,      // 目标亮度值 (默认128)
    input               [7:0]           max_brightness_threshold, // 最大亮度阈值
    input               [7:0]           min_brightness_threshold, // 最小亮度阈值
    
    // 状态输出
    output  reg         [7:0]           current_brightness,     // 当前帧平均亮度
    output  reg         [7:0]           ae_gain,                // AE增益值
    output  reg                         ae_locked,              // AE锁定状态
    output  reg         [15:0]          frame_counter           // 帧计数器
);

// ===================================================================
// 内部参数定义
// ===================================================================
localparam IMG_WIDTH = 1280;
localparam IMG_HEIGHT = 720;
localparam BRIGHTNESS_HIST_BINS = 64;  // 直方图bin数量
localparam DEFAULT_TARGET = 8'd70;     // 默认目标亮度 (从80降低到70)
localparam STABILITY_THRESHOLD = 8;    // 稳定性计数阈值
localparam SCENE_CHANGE_THRESHOLD = 30; // 场景变化检测阈值
localparam HIGH_BRIGHTNESS_START = 6'd40; // 高亮度区域起始bin从45改为40

// ===================================================================
// 内部信号定义
// ===================================================================
// VSYNC边沿检测
reg         [1:0]           vsync_dly;              // VSYNC延迟寄存器
wire                        vsync_posedge;          // VSYNC上升沿
wire                        vsync_negedge;          // VSYNC下降沿

// 像素和行计数
reg         [15:0]          pixel_counter;          // 像素计数器
reg         [15:0]          line_counter;           // 行计数器

// 亮度计算相关
reg         [31:0]          frame_brightness_sum;   // 帧亮度累加和
reg         [19:0]          valid_pixel_count;      // 有效像素计数
wire        [7:0]           pixel_brightness;       // 像素亮度值

// 直方图统计 - 使用寄存器数组替代内存数组
reg         [15:0]          brightness_hist_0;
reg         [15:0]          brightness_hist_1;
reg         [15:0]          brightness_hist_2;
reg         [15:0]          brightness_hist_3;
reg         [15:0]          brightness_hist_4;
reg         [15:0]          brightness_hist_5;
reg         [15:0]          brightness_hist_6;
reg         [15:0]          brightness_hist_7;
reg         [15:0]          brightness_hist_8;
reg         [15:0]          brightness_hist_9;
reg         [15:0]          brightness_hist_10;
reg         [15:0]          brightness_hist_11;
reg         [15:0]          brightness_hist_12;
reg         [15:0]          brightness_hist_13;
reg         [15:0]          brightness_hist_14;
reg         [15:0]          brightness_hist_15;
reg         [15:0]          brightness_hist_16;
reg         [15:0]          brightness_hist_17;
reg         [15:0]          brightness_hist_18;
reg         [15:0]          brightness_hist_19;
reg         [15:0]          brightness_hist_20;
reg         [15:0]          brightness_hist_21;
reg         [15:0]          brightness_hist_22;
reg         [15:0]          brightness_hist_23;
reg         [15:0]          brightness_hist_24;
reg         [15:0]          brightness_hist_25;
reg         [15:0]          brightness_hist_26;
reg         [15:0]          brightness_hist_27;
reg         [15:0]          brightness_hist_28;
reg         [15:0]          brightness_hist_29;
reg         [15:0]          brightness_hist_30;
reg         [15:0]          brightness_hist_31;
reg         [15:0]          brightness_hist_32;
reg         [15:0]          brightness_hist_33;
reg         [15:0]          brightness_hist_34;
reg         [15:0]          brightness_hist_35;
reg         [15:0]          brightness_hist_36;
reg         [15:0]          brightness_hist_37;
reg         [15:0]          brightness_hist_38;
reg         [15:0]          brightness_hist_39;
reg         [15:0]          brightness_hist_40;
reg         [15:0]          brightness_hist_41;
reg         [15:0]          brightness_hist_42;
reg         [15:0]          brightness_hist_43;
reg         [15:0]          brightness_hist_44;
reg         [15:0]          brightness_hist_45;
reg         [15:0]          brightness_hist_46;
reg         [15:0]          brightness_hist_47;
reg         [15:0]          brightness_hist_48;
reg         [15:0]          brightness_hist_49;
reg         [15:0]          brightness_hist_50;
reg         [15:0]          brightness_hist_51;
reg         [15:0]          brightness_hist_52;
reg         [15:0]          brightness_hist_53;
reg         [15:0]          brightness_hist_54;
reg         [15:0]          brightness_hist_55;
reg         [15:0]          brightness_hist_56;
reg         [15:0]          brightness_hist_57;
reg         [15:0]          brightness_hist_58;
reg         [15:0]          brightness_hist_59;
reg         [15:0]          brightness_hist_60;
reg         [15:0]          brightness_hist_61;
reg         [15:0]          brightness_hist_62;
reg         [15:0]          brightness_hist_63;

// 直方图索引
wire        [5:0]           hist_bin_index;

// AE控制状态机
reg         [2:0]           ae_state;
localparam  AE_IDLE         = 3'd0;
localparam  AE_CALC_BRIGHTNESS = 3'd1;
localparam  AE_UPDATE_GAIN  = 3'd2;
localparam  AE_APPLY_GAIN   = 3'd3;

// 增益控制
reg         [7:0]           target_brightness_reg;
reg         [7:0]           ae_gain_next;
reg         [3:0]           stability_counter;
reg         [7:0]           prev_brightness;        // 前一帧亮度
reg         [7:0]           brightness_diff;        // 亮度差值
reg                         scene_change_detected;  // 场景变化检测标志

// 动态增益调整参数
reg         [7:0]           gain_step;              // 当前增益步长
reg         [2:0]           gain_step_counter;      // 增益步长调整计数器

// 直方图分析结果
reg         [7:0]           hist_median;            // 直方图中值
reg         [7:0]           hist_peak;              // 直方图峰值
reg         [7:0]           hist_low_ratio;         // 低亮度区域比例
reg         [7:0]           hist_high_ratio;        // 高亮度区域比例

// ===================================================================
// VSYNC边沿检测
// ===================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vsync_dly <= 2'b00;
    end else begin
        vsync_dly <= {vsync_dly[0], vsync_i};
    end
end

assign vsync_posedge = (~vsync_dly[1] & vsync_dly[0]);
assign vsync_negedge = (vsync_dly[1] & ~vsync_dly[0]);

// ===================================================================
// 像素亮度计算 
// ===================================================================
// 医疗内窥镜通常更关注绿色通道，因为血管在绿色通道中对比度最高
wire [15:0] weighted_r = rgb_i[23:16] * 8'd25;   // 25/128 ≈ 0.195 (降低红色权重)
wire [15:0] weighted_g = rgb_i[15:8]  * 8'd78;   // 78/128 ≈ 0.609 (提高绿色权重)  
wire [15:0] weighted_b = rgb_i[7:0]   * 8'd25;   // 25/128 ≈ 0.195 (降低蓝色权重)

assign pixel_brightness = (weighted_r + weighted_g + weighted_b) >> 7;

// 直方图索引计算
assign hist_bin_index = pixel_brightness[7:2]; // 256/64=4，每个bin覆盖4个亮度级别

// ===================================================================
// 帧统计 - 平均亮度和直方图
// ===================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frame_brightness_sum <= 32'd0;
        valid_pixel_count <= 20'd0;
        pixel_counter <= 16'd0;
        line_counter <= 16'd0;
        
        // 重置直方图
        brightness_hist_0 <= 16'd0;
        brightness_hist_1 <= 16'd0;
        brightness_hist_2 <= 16'd0;
        brightness_hist_3 <= 16'd0;
        brightness_hist_4 <= 16'd0;
        brightness_hist_5 <= 16'd0;
        brightness_hist_6 <= 16'd0;
        brightness_hist_7 <= 16'd0;
        brightness_hist_8 <= 16'd0;
        brightness_hist_9 <= 16'd0;
        brightness_hist_10 <= 16'd0;
        brightness_hist_11 <= 16'd0;
        brightness_hist_12 <= 16'd0;
        brightness_hist_13 <= 16'd0;
        brightness_hist_14 <= 16'd0;
        brightness_hist_15 <= 16'd0;
        brightness_hist_16 <= 16'd0;
        brightness_hist_17 <= 16'd0;
        brightness_hist_18 <= 16'd0;
        brightness_hist_19 <= 16'd0;
        brightness_hist_20 <= 16'd0;
        brightness_hist_21 <= 16'd0;
        brightness_hist_22 <= 16'd0;
        brightness_hist_23 <= 16'd0;
        brightness_hist_24 <= 16'd0;
        brightness_hist_25 <= 16'd0;
        brightness_hist_26 <= 16'd0;
        brightness_hist_27 <= 16'd0;
        brightness_hist_28 <= 16'd0;
        brightness_hist_29 <= 16'd0;
        brightness_hist_30 <= 16'd0;
        brightness_hist_31 <= 16'd0;
        brightness_hist_32 <= 16'd0;
        brightness_hist_33 <= 16'd0;
        brightness_hist_34 <= 16'd0;
        brightness_hist_35 <= 16'd0;
        brightness_hist_36 <= 16'd0;
        brightness_hist_37 <= 16'd0;
        brightness_hist_38 <= 16'd0;
        brightness_hist_39 <= 16'd0;
        brightness_hist_40 <= 16'd0;
        brightness_hist_41 <= 16'd0;
        brightness_hist_42 <= 16'd0;
        brightness_hist_43 <= 16'd0;
        brightness_hist_44 <= 16'd0;
        brightness_hist_45 <= 16'd0;
        brightness_hist_46 <= 16'd0;
        brightness_hist_47 <= 16'd0;
        brightness_hist_48 <= 16'd0;
        brightness_hist_49 <= 16'd0;
        brightness_hist_50 <= 16'd0;
        brightness_hist_51 <= 16'd0;
        brightness_hist_52 <= 16'd0;
        brightness_hist_53 <= 16'd0;
        brightness_hist_54 <= 16'd0;
        brightness_hist_55 <= 16'd0;
        brightness_hist_56 <= 16'd0;
        brightness_hist_57 <= 16'd0;
        brightness_hist_58 <= 16'd0;
        brightness_hist_59 <= 16'd0;
        brightness_hist_60 <= 16'd0;
        brightness_hist_61 <= 16'd0;
        brightness_hist_62 <= 16'd0;
        brightness_hist_63 <= 16'd0;
    end else begin
        // 像素和行计数
        if (vsync_posedge) begin
            pixel_counter <= 16'd0;
            line_counter <= 16'd0;
        end else if (href_i && de_i) begin
            pixel_counter <= pixel_counter + 1;
            if (pixel_counter == IMG_WIDTH - 1) begin
                line_counter <= line_counter + 1;
            end
        end
        
        // 亮度统计（仅在有效图像区域内）
        if (href_i && de_i && line_counter < IMG_HEIGHT && pixel_counter < IMG_WIDTH) begin
            frame_brightness_sum <= frame_brightness_sum + pixel_brightness;
            valid_pixel_count <= valid_pixel_count + 1;
            
            // 直方图统计
            case (hist_bin_index)
                6'd0:  brightness_hist_0 <= brightness_hist_0 + 1;
                6'd1:  brightness_hist_1 <= brightness_hist_1 + 1;
                6'd2:  brightness_hist_2 <= brightness_hist_2 + 1;
                6'd3:  brightness_hist_3 <= brightness_hist_3 + 1;
                6'd4:  brightness_hist_4 <= brightness_hist_4 + 1;
                6'd5:  brightness_hist_5 <= brightness_hist_5 + 1;
                6'd6:  brightness_hist_6 <= brightness_hist_6 + 1;
                6'd7:  brightness_hist_7 <= brightness_hist_7 + 1;
                6'd8:  brightness_hist_8 <= brightness_hist_8 + 1;
                6'd9:  brightness_hist_9 <= brightness_hist_9 + 1;
                6'd10: brightness_hist_10 <= brightness_hist_10 + 1;
                6'd11: brightness_hist_11 <= brightness_hist_11 + 1;
                6'd12: brightness_hist_12 <= brightness_hist_12 + 1;
                6'd13: brightness_hist_13 <= brightness_hist_13 + 1;
                6'd14: brightness_hist_14 <= brightness_hist_14 + 1;
                6'd15: brightness_hist_15 <= brightness_hist_15 + 1;
                6'd16: brightness_hist_16 <= brightness_hist_16 + 1;
                6'd17: brightness_hist_17 <= brightness_hist_17 + 1;
                6'd18: brightness_hist_18 <= brightness_hist_18 + 1;
                6'd19: brightness_hist_19 <= brightness_hist_19 + 1;
                6'd20: brightness_hist_20 <= brightness_hist_20 + 1;
                6'd21: brightness_hist_21 <= brightness_hist_21 + 1;
                6'd22: brightness_hist_22 <= brightness_hist_22 + 1;
                6'd23: brightness_hist_23 <= brightness_hist_23 + 1;
                6'd24: brightness_hist_24 <= brightness_hist_24 + 1;
                6'd25: brightness_hist_25 <= brightness_hist_25 + 1;
                6'd26: brightness_hist_26 <= brightness_hist_26 + 1;
                6'd27: brightness_hist_27 <= brightness_hist_27 + 1;
                6'd28: brightness_hist_28 <= brightness_hist_28 + 1;
                6'd29: brightness_hist_29 <= brightness_hist_29 + 1;
                6'd30: brightness_hist_30 <= brightness_hist_30 + 1;
                6'd31: brightness_hist_31 <= brightness_hist_31 + 1;
                6'd32: brightness_hist_32 <= brightness_hist_32 + 1;
                6'd33: brightness_hist_33 <= brightness_hist_33 + 1;
                6'd34: brightness_hist_34 <= brightness_hist_34 + 1;
                6'd35: brightness_hist_35 <= brightness_hist_35 + 1;
                6'd36: brightness_hist_36 <= brightness_hist_36 + 1;
                6'd37: brightness_hist_37 <= brightness_hist_37 + 1;
                6'd38: brightness_hist_38 <= brightness_hist_38 + 1;
                6'd39: brightness_hist_39 <= brightness_hist_39 + 1;
                6'd40: brightness_hist_40 <= brightness_hist_40 + 1; 
                6'd41: brightness_hist_41 <= brightness_hist_41 + 1; 
                6'd42: brightness_hist_42 <= brightness_hist_42 + 1; 
                6'd43: brightness_hist_43 <= brightness_hist_43 + 1; 
                6'd44: brightness_hist_44 <= brightness_hist_44 + 1; 
                6'd45: brightness_hist_45 <= brightness_hist_45 + 1;
                6'd46: brightness_hist_46 <= brightness_hist_46 + 1;
                6'd47: brightness_hist_47 <= brightness_hist_47 + 1;
                6'd48: brightness_hist_48 <= brightness_hist_48 + 1;
                6'd49: brightness_hist_49 <= brightness_hist_49 + 1;
                6'd50: brightness_hist_50 <= brightness_hist_50 + 1;
                6'd51: brightness_hist_51 <= brightness_hist_51 + 1;
                6'd52: brightness_hist_52 <= brightness_hist_52 + 1;
                6'd53: brightness_hist_53 <= brightness_hist_53 + 1;
                6'd54: brightness_hist_54 <= brightness_hist_54 + 1;
                6'd55: brightness_hist_55 <= brightness_hist_55 + 1;
                6'd56: brightness_hist_56 <= brightness_hist_56 + 1;
                6'd57: brightness_hist_57 <= brightness_hist_57 + 1;
                6'd58: brightness_hist_58 <= brightness_hist_58 + 1;
                6'd59: brightness_hist_59 <= brightness_hist_59 + 1;
                6'd60: brightness_hist_60 <= brightness_hist_60 + 1;
                6'd61: brightness_hist_61 <= brightness_hist_61 + 1;
                6'd62: brightness_hist_62 <= brightness_hist_62 + 1;
                6'd63: brightness_hist_63 <= brightness_hist_63 + 1;
                default: ; 
            endcase
        end
        
        // 帧结束时重置统计
        if (vsync_negedge) begin
            frame_brightness_sum <= 32'd0;
            valid_pixel_count <= 20'd0;
            
            // 重置直方图
            if (ae_enable) begin
                brightness_hist_0 <= 16'd0;
                brightness_hist_1 <= 16'd0;
                brightness_hist_2 <= 16'd0;
                brightness_hist_3 <= 16'd0;
                brightness_hist_4 <= 16'd0;
                brightness_hist_5 <= 16'd0;
                brightness_hist_6 <= 16'd0;
                brightness_hist_7 <= 16'd0;
                brightness_hist_8 <= 16'd0;
                brightness_hist_9 <= 16'd0;
                brightness_hist_10 <= 16'd0;
                brightness_hist_11 <= 16'd0;
                brightness_hist_12 <= 16'd0;
                brightness_hist_13 <= 16'd0;
                brightness_hist_14 <= 16'd0;
                brightness_hist_15 <= 16'd0;
                brightness_hist_16 <= 16'd0;
                brightness_hist_17 <= 16'd0;
                brightness_hist_18 <= 16'd0;
                brightness_hist_19 <= 16'd0;
                brightness_hist_20 <= 16'd0;
                brightness_hist_21 <= 16'd0;
                brightness_hist_22 <= 16'd0;
                brightness_hist_23 <= 16'd0;
                brightness_hist_24 <= 16'd0;
                brightness_hist_25 <= 16'd0;
                brightness_hist_26 <= 16'd0;
                brightness_hist_27 <= 16'd0;
                brightness_hist_28 <= 16'd0;
                brightness_hist_29 <= 16'd0;
                brightness_hist_30 <= 16'd0;
                brightness_hist_31 <= 16'd0;
                brightness_hist_32 <= 16'd0;
                brightness_hist_33 <= 16'd0;
                brightness_hist_34 <= 16'd0;
                brightness_hist_35 <= 16'd0;
                brightness_hist_36 <= 16'd0;
                brightness_hist_37 <= 16'd0;
                brightness_hist_38 <= 16'd0;
                brightness_hist_39 <= 16'd0;
                brightness_hist_40 <= 16'd0;
                brightness_hist_41 <= 16'd0;
                brightness_hist_42 <= 16'd0;
                brightness_hist_43 <= 16'd0;
                brightness_hist_44 <= 16'd0;
                brightness_hist_45 <= 16'd0;
                brightness_hist_46 <= 16'd0;
                brightness_hist_47 <= 16'd0;
                brightness_hist_48 <= 16'd0;
                brightness_hist_49 <= 16'd0;
                brightness_hist_50 <= 16'd0;
                brightness_hist_51 <= 16'd0;
                brightness_hist_52 <= 16'd0;
                brightness_hist_53 <= 16'd0;
                brightness_hist_54 <= 16'd0;
                brightness_hist_55 <= 16'd0;
                brightness_hist_56 <= 16'd0;
                brightness_hist_57 <= 16'd0;
                brightness_hist_58 <= 16'd0;
                brightness_hist_59 <= 16'd0;
                brightness_hist_60 <= 16'd0;
                brightness_hist_61 <= 16'd0;
                brightness_hist_62 <= 16'd0;
                brightness_hist_63 <= 16'd0;
            end
        end
    end
end


// ===================================================================
// 直方图分析模块
// ===================================================================
reg [5:0] hist_analysis_index;
reg [15:0] hist_accumulator;
reg [15:0] half_pixel_count;
reg [7:0] median_bin;
reg [15:0] max_hist_value;
reg [5:0] peak_bin;
reg [15:0] low_region_accumulator;  // 低亮度区域累加器(0-15)
reg [15:0] high_region_accumulator; // 高亮度区域累加器(40-63) 


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hist_median <= 8'd0;
        hist_peak <= 8'd0;
        hist_low_ratio <= 8'd0;
        hist_high_ratio <= 8'd0;
        hist_analysis_index <= 6'd0;
        hist_accumulator <= 16'd0;
        half_pixel_count <= 16'd0;
        median_bin <= 6'd0;
        max_hist_value <= 16'd0;
        peak_bin <= 6'd0;
        low_region_accumulator <= 16'd0;
        high_region_accumulator <= 16'd0;
    end else begin
        // 在帧结束时进行直方图分析
        if (vsync_negedge && ae_enable) begin
            hist_analysis_index <= 6'd0;
            hist_accumulator <= 16'd0;
            half_pixel_count <= valid_pixel_count >> 1; // 计算像素总数的一半
            median_bin <= 6'd0;
            max_hist_value <= 16'd0;
            peak_bin <= 6'd0;
            low_region_accumulator <= 16'd0;
            high_region_accumulator <= 16'd0;
        end else if (ae_state == AE_CALC_BRIGHTNESS) begin
            // 逐步分析直方图
            if (hist_analysis_index < BRIGHTNESS_HIST_BINS) begin
                // 获取当前bin的值
                case (hist_analysis_index)
                    6'd0:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_0; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_0; 
                           end
                    6'd1:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_1; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_1; 
                           end
                    6'd2:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_2; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_2; 
                           end
                    6'd3:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_3; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_3; 
                           end
                    6'd4:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_4; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_4; 
                           end
                    6'd5:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_5; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_5; 
                           end
                    6'd6:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_6; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_6; 
                           end
                    6'd7:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_7; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_7; 
                           end
                    6'd8:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_8; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_8; 
                           end
                    6'd9:  begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_9; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_9; 
                           end
                    6'd10: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_10; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_10; 
                           end
                    6'd11: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_11; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_11; 
                           end
                    6'd12: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_12; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_12; 
                           end
                    6'd13: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_13; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_13; 
                           end
                    6'd14: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_14; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_14; 
                           end
                    6'd15: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_15; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_15; 
                           end
                    6'd16: hist_accumulator <= hist_accumulator + brightness_hist_16;
                    6'd17: hist_accumulator <= hist_accumulator + brightness_hist_17;
                    6'd18: hist_accumulator <= hist_accumulator + brightness_hist_18;
                    6'd19: hist_accumulator <= hist_accumulator + brightness_hist_19;
                    6'd20: hist_accumulator <= hist_accumulator + brightness_hist_20;
                    6'd21: hist_accumulator <= hist_accumulator + brightness_hist_21;
                    6'd22: hist_accumulator <= hist_accumulator + brightness_hist_22;
                    6'd23: hist_accumulator <= hist_accumulator + brightness_hist_23;
                    6'd24: hist_accumulator <= hist_accumulator + brightness_hist_24;
                    6'd25: hist_accumulator <= hist_accumulator + brightness_hist_25;
                    6'd26: hist_accumulator <= hist_accumulator + brightness_hist_26;
                    6'd27: hist_accumulator <= hist_accumulator + brightness_hist_27;
                    6'd28: hist_accumulator <= hist_accumulator + brightness_hist_28;
                    6'd29: hist_accumulator <= hist_accumulator + brightness_hist_29;
                    6'd30: hist_accumulator <= hist_accumulator + brightness_hist_30;
                    6'd31: hist_accumulator <= hist_accumulator + brightness_hist_31;
                    6'd32: hist_accumulator <= hist_accumulator + brightness_hist_32;
                    6'd33: hist_accumulator <= hist_accumulator + brightness_hist_33;
                    6'd34: hist_accumulator <= hist_accumulator + brightness_hist_34;
                    6'd35: hist_accumulator <= hist_accumulator + brightness_hist_35;
                    6'd36: hist_accumulator <= hist_accumulator + brightness_hist_36;
                    6'd37: hist_accumulator <= hist_accumulator + brightness_hist_37;
                    6'd38: hist_accumulator <= hist_accumulator + brightness_hist_38;
                    6'd39: hist_accumulator <= hist_accumulator + brightness_hist_39;
                    6'd40: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_40; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_40; 
                           end
                    6'd41: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_41; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_41; 
                           end
                    6'd42: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_42; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_42; 
                           end
                    6'd43: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_43; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_43; 
                           end
                    6'd44: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_44; 
                             low_region_accumulator <= low_region_accumulator + brightness_hist_44; 
                           end
                    6'd45: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_45;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_45;
                           end
                    6'd46: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_46;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_46;
                           end
                    6'd47: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_47;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_47;
                           end
                    6'd48: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_48;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_48;
                           end
                    6'd49: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_49;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_49;
                           end
                    6'd50: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_50;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_50;
                           end
                    6'd51: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_51;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_51;
                           end
                    6'd52: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_52;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_52;
                           end
                    6'd53: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_53;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_53;
                           end
                    6'd54: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_54;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_54;
                           end
                    6'd55: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_55;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_55;
                           end
                    6'd56: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_56;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_56;
                           end
                    6'd57: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_57;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_57;
                           end
                    6'd58: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_58;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_58;
                           end
                    6'd59: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_59;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_59;
                           end
                    6'd60: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_60;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_60;
                           end
                    6'd61: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_61;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_61;
                           end
                    6'd62: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_62;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_62;
                           end
                    6'd63: begin 
                             hist_accumulator <= hist_accumulator + brightness_hist_63;
                             high_region_accumulator <= high_region_accumulator + brightness_hist_63;
                           end
                    default: ; 
                endcase
                
                // 查找峰值
                case (hist_analysis_index)
                    6'd0:  if (brightness_hist_0 > max_hist_value) begin max_hist_value <= brightness_hist_0; peak_bin <= 6'd0; end
                    6'd1:  if (brightness_hist_1 > max_hist_value) begin max_hist_value <= brightness_hist_1; peak_bin <= 6'd1; end
                    6'd2:  if (brightness_hist_2 > max_hist_value) begin max_hist_value <= brightness_hist_2; peak_bin <= 6'd2; end
                    6'd3:  if (brightness_hist_3 > max_hist_value) begin max_hist_value <= brightness_hist_3; peak_bin <= 6'd3; end
                    6'd4:  if (brightness_hist_4 > max_hist_value) begin max_hist_value <= brightness_hist_4; peak_bin <= 6'd4; end
                    6'd5:  if (brightness_hist_5 > max_hist_value) begin max_hist_value <= brightness_hist_5; peak_bin <= 6'd5; end
                    6'd6:  if (brightness_hist_6 > max_hist_value) begin max_hist_value <= brightness_hist_6; peak_bin <= 6'd6; end
                    6'd7:  if (brightness_hist_7 > max_hist_value) begin max_hist_value <= brightness_hist_7; peak_bin <= 6'd7; end
                    6'd8:  if (brightness_hist_8 > max_hist_value) begin max_hist_value <= brightness_hist_8; peak_bin <= 6'd8; end
                    6'd9:  if (brightness_hist_9 > max_hist_value) begin max_hist_value <= brightness_hist_9; peak_bin <= 6'd9; end
                    6'd10: if (brightness_hist_10 > max_hist_value) begin max_hist_value <= brightness_hist_10; peak_bin <= 6'd10; end
                    6'd11: if (brightness_hist_11 > max_hist_value) begin max_hist_value <= brightness_hist_11; peak_bin <= 6'd11; end
                    6'd12: if (brightness_hist_12 > max_hist_value) begin max_hist_value <= brightness_hist_12; peak_bin <= 6'd12; end
                    6'd13: if (brightness_hist_13 > max_hist_value) begin max_hist_value <= brightness_hist_13; peak_bin <= 6'd13; end
                    6'd14: if (brightness_hist_14 > max_hist_value) begin max_hist_value <= brightness_hist_14; peak_bin <= 6'd14; end
                    6'd15: if (brightness_hist_15 > max_hist_value) begin max_hist_value <= brightness_hist_15; peak_bin <= 6'd15; end
                    6'd16: if (brightness_hist_16 > max_hist_value) begin max_hist_value <= brightness_hist_16; peak_bin <= 6'd16; end
                    6'd17: if (brightness_hist_17 > max_hist_value) begin max_hist_value <= brightness_hist_17; peak_bin <= 6'd17; end
                    6'd18: if (brightness_hist_18 > max_hist_value) begin max_hist_value <= brightness_hist_18; peak_bin <= 6'd18; end
                    6'd19: if (brightness_hist_19 > max_hist_value) begin max_hist_value <= brightness_hist_19; peak_bin <= 6'd19; end
                    6'd20: if (brightness_hist_20 > max_hist_value) begin max_hist_value <= brightness_hist_20; peak_bin <= 6'd20; end
                    6'd21: if (brightness_hist_21 > max_hist_value) begin max_hist_value <= brightness_hist_21; peak_bin <= 6'd21; end
                    6'd22: if (brightness_hist_22 > max_hist_value) begin max_hist_value <= brightness_hist_22; peak_bin <= 6'd22; end
                    6'd23: if (brightness_hist_23 > max_hist_value) begin max_hist_value <= brightness_hist_23; peak_bin <= 6'd23; end
                    6'd24: if (brightness_hist_24 > max_hist_value) begin max_hist_value <= brightness_hist_24; peak_bin <= 6'd24; end
                    6'd25: if (brightness_hist_25 > max_hist_value) begin max_hist_value <= brightness_hist_25; peak_bin <= 6'd25; end
                    6'd26: if (brightness_hist_26 > max_hist_value) begin max_hist_value <= brightness_hist_26; peak_bin <= 6'd26; end
                    6'd27: if (brightness_hist_27 > max_hist_value) begin max_hist_value <= brightness_hist_27; peak_bin <= 6'd27; end
                    6'd28: if (brightness_hist_28 > max_hist_value) begin max_hist_value <= brightness_hist_28; peak_bin <= 6'd28; end
                    6'd29: if (brightness_hist_29 > max_hist_value) begin max_hist_value <= brightness_hist_29; peak_bin <= 6'd29; end
                    6'd30: if (brightness_hist_30 > max_hist_value) begin max_hist_value <= brightness_hist_30; peak_bin <= 6'd30; end
                    6'd31: if (brightness_hist_31 > max_hist_value) begin max_hist_value <= brightness_hist_31; peak_bin <= 6'd31; end
                    6'd32: if (brightness_hist_32 > max_hist_value) begin max_hist_value <= brightness_hist_32; peak_bin <= 6'd32; end
                    6'd33: if (brightness_hist_33 > max_hist_value) begin max_hist_value <= brightness_hist_33; peak_bin <= 6'd33; end
                    6'd34: if (brightness_hist_34 > max_hist_value) begin max_hist_value <= brightness_hist_34; peak_bin <= 6'd34; end
                    6'd35: if (brightness_hist_35 > max_hist_value) begin max_hist_value <= brightness_hist_35; peak_bin <= 6'd35; end
                    6'd36: if (brightness_hist_36 > max_hist_value) begin max_hist_value <= brightness_hist_36; peak_bin <= 6'd36; end
                    6'd37: if (brightness_hist_37 > max_hist_value) begin max_hist_value <= brightness_hist_37; peak_bin <= 6'd37; end
                    6'd38: if (brightness_hist_38 > max_hist_value) begin max_hist_value <= brightness_hist_38; peak_bin <= 6'd38; end
                    6'd39: if (brightness_hist_39 > max_hist_value) begin max_hist_value <= brightness_hist_39; peak_bin <= 6'd39; end
                    6'd40: if (brightness_hist_40 > max_hist_value) begin max_hist_value <= brightness_hist_40; peak_bin <= 6'd40; end
                    6'd41: if (brightness_hist_41 > max_hist_value) begin max_hist_value <= brightness_hist_41; peak_bin <= 6'd41; end
                    6'd42: if (brightness_hist_42 > max_hist_value) begin max_hist_value <= brightness_hist_42; peak_bin <= 6'd42; end
                    6'd43: if (brightness_hist_43 > max_hist_value) begin max_hist_value <= brightness_hist_43; peak_bin <= 6'd43; end
                    6'd44: if (brightness_hist_44 > max_hist_value) begin max_hist_value <= brightness_hist_44; peak_bin <= 6'd44; end
                    6'd45: if (brightness_hist_45 > max_hist_value) begin max_hist_value <= brightness_hist_45; peak_bin <= 6'd45; end
                    6'd46: if (brightness_hist_46 > max_hist_value) begin max_hist_value <= brightness_hist_46; peak_bin <= 6'd46; end
                    6'd47: if (brightness_hist_47 > max_hist_value) begin max_hist_value <= brightness_hist_47; peak_bin <= 6'd47; end
                    6'd48: if (brightness_hist_48 > max_hist_value) begin max_hist_value <= brightness_hist_48; peak_bin <= 6'd48; end
                    6'd49: if (brightness_hist_49 > max_hist_value) begin max_hist_value <= brightness_hist_49; peak_bin <= 6'd49; end
                    6'd50: if (brightness_hist_50 > max_hist_value) begin max_hist_value <= brightness_hist_50; peak_bin <= 6'd50; end
                    6'd51: if (brightness_hist_51 > max_hist_value) begin max_hist_value <= brightness_hist_51; peak_bin <= 6'd51; end
                    6'd52: if (brightness_hist_52 > max_hist_value) begin max_hist_value <= brightness_hist_52; peak_bin <= 6'd52; end
                    6'd53: if (brightness_hist_53 > max_hist_value) begin max_hist_value <= brightness_hist_53; peak_bin <= 6'd53; end
                    6'd54: if (brightness_hist_54 > max_hist_value) begin max_hist_value <= brightness_hist_54; peak_bin <= 6'd54; end
                    6'd55: if (brightness_hist_55 > max_hist_value) begin max_hist_value <= brightness_hist_55; peak_bin <= 6'd55; end
                    6'd56: if (brightness_hist_56 > max_hist_value) begin max_hist_value <= brightness_hist_56; peak_bin <= 6'd56; end
                    6'd57: if (brightness_hist_57 > max_hist_value) begin max_hist_value <= brightness_hist_57; peak_bin <= 6'd57; end
                    6'd58: if (brightness_hist_58 > max_hist_value) begin max_hist_value <= brightness_hist_58; peak_bin <= 6'd58; end
                    6'd59: if (brightness_hist_59 > max_hist_value) begin max_hist_value <= brightness_hist_59; peak_bin <= 6'd59; end
                    6'd60: if (brightness_hist_60 > max_hist_value) begin max_hist_value <= brightness_hist_60; peak_bin <= 6'd60; end
                    6'd61: if (brightness_hist_61 > max_hist_value) begin max_hist_value <= brightness_hist_61; peak_bin <= 6'd61; end
                    6'd62: if (brightness_hist_62 > max_hist_value) begin max_hist_value <= brightness_hist_62; peak_bin <= 6'd62; end
                    6'd63: if (brightness_hist_63 > max_hist_value) begin max_hist_value <= brightness_hist_63; peak_bin <= 6'd63; end
                    default: ; // 防止综合器警告
                endcase
                
                // 检查是否达到中值
                if (median_bin == 6'd0 && hist_accumulator >= half_pixel_count) begin
                    median_bin <= hist_analysis_index;
                end
                
                hist_analysis_index <= hist_analysis_index + 1;
            end else begin
                // 分析完成，更新结果
                hist_median <= median_bin << 2; // 转换回亮度值
                hist_peak <= peak_bin << 2;
                
                // 计算低亮度区域比例(0-15)
                hist_low_ratio <= (low_region_accumulator * 8'd100) / valid_pixel_count;
                
                // 计算高亮度区域比例(40-63) - 修改
                hist_high_ratio <= (high_region_accumulator * 8'd100) / valid_pixel_count;
            end
        end
    end
end

// ===================================================================
// AE控制状态机 - 增强过曝检测
// ===================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ae_state <= AE_IDLE;
        current_brightness <= 8'd0;
        ae_gain <= 8'd128;  // 初始增益1.0 (128/128)
        ae_gain_next <= 8'd128;
        ae_locked <= 1'b0;
        stability_counter <= 4'd0;
        target_brightness_reg <= DEFAULT_TARGET;
        frame_counter <= 16'd0;
        prev_brightness <= 8'd0;
        brightness_diff <= 8'd0;
        scene_change_detected <= 1'b0;
        gain_step <= 8'd2;  // 初始增益步长
        gain_step_counter <= 3'd0;
    end else begin
        // 帧计数器
        if (vsync_posedge) begin
            frame_counter <= frame_counter + 1;
        end
        
        // 更新目标亮度寄存器
        target_brightness_reg <= (target_brightness != 0) ? target_brightness : DEFAULT_TARGET;
        
        case (ae_state)
            AE_IDLE: begin
                if (vsync_negedge && ae_enable) begin
                    ae_state <= AE_CALC_BRIGHTNESS;
                end
            end
            
            AE_CALC_BRIGHTNESS: begin
                // 计算平均亮度
                if (valid_pixel_count != 0) begin
                    current_brightness <= frame_brightness_sum / valid_pixel_count;
                end
                
                // 计算亮度差值
                brightness_diff <= (current_brightness > prev_brightness) ? 
                                 (current_brightness - prev_brightness) : 
                                 (prev_brightness - current_brightness);
                
                // 场景变化检测
                scene_change_detected <= (brightness_diff > SCENE_CHANGE_THRESHOLD);
                
                // 更新前一帧亮度
                prev_brightness <= current_brightness;
                
                ae_state <= AE_UPDATE_GAIN;
            end
            
            AE_UPDATE_GAIN: begin
                // 动态调整增益步长
                if (scene_change_detected) begin
                    // 场景变化时使用大步长
                    gain_step <= 8'd8;
                    gain_step_counter <= 3'd0;
                end else begin
                    // 根据亮度差值调整步长
                    if (brightness_diff > 20) begin
                        gain_step <= 8'd6;
                    end else if (brightness_diff > 10) begin
                        gain_step <= 8'd4;
                    end else if (brightness_diff > 5) begin
                        gain_step <= 8'd2;
                    end else begin
                        gain_step <= 8'd1;
                    end
                    
                    // 稳定后逐步减小步长
                    if (stability_counter >= 4'd4) begin
                        gain_step_counter <= gain_step_counter + 1;
                        if (gain_step_counter >= 3'd3) begin
                            gain_step <= (gain_step > 8'd1) ? (gain_step - 8'd1) : 8'd1;
                            gain_step_counter <= 3'd0;
                        end
                    end
                end
                
                // 基于直方图分析调整目标亮度
                if (hist_low_ratio > 8'd50) begin  // 修改：从60%降低到50%
                    // 低亮度区域过多，适当提高目标亮度
                    target_brightness_reg <= (target_brightness_reg < 8'd100) ? 
                                           (target_brightness_reg + 8'd3) : 8'd100;  // 修改：减小步长
                end else if (hist_high_ratio > 8'd8) begin  // 修改：降低阈值从15%到8%
                    // 高亮度区域过多，适当降低目标亮度
                    target_brightness_reg <= (target_brightness_reg > 8'd40) ? 
                                           (target_brightness_reg - 8'd8) : 8'd40;  // 修改：增大步长
                end
                
                // 修改：增强过曝检测逻辑
                if (hist_high_ratio > 8'd8) begin  // 修改：降低阈值从15%到8%
                    // 高亮度区域超过8%，强制减少增益
                    if (hist_high_ratio > 8'd15) begin  // 修改：降低阈值从30%到15%
                        // 严重过曝，大幅减少增益
                        ae_gain_next <= (ae_gain > 8'd64) ? (ae_gain - (gain_step << 3)) : 8'd32;
                    end else begin
                        // 轻度过曝，适度减少增益
                        ae_gain_next <= (ae_gain > 8'd48) ? (ae_gain - (gain_step << 2)) : 8'd32;
                    end
                    stability_counter <= 4'd0;
                end 
                else if (current_brightness > (target_brightness_reg + 5)) begin  // 修改：降低阈值从+8到+5
                    // 图像偏亮，减少增益
                    if (current_brightness > (target_brightness_reg + 20)) begin  // 修改：降低阈值从+25到+20
                        // 亮度远高于目标，大幅减少增益
                        ae_gain_next <= (ae_gain > 8'd64) ? (ae_gain - (gain_step << 2)) : 8'd32;
                    end else begin
                        // 亮度略高于目标，适度减少增益
                        ae_gain_next <= (ae_gain > 8'd48) ? (ae_gain - (gain_step << 1)) : 8'd32;
                    end
                    stability_counter <= 4'd0;
                end 
                else if (current_brightness < (target_brightness_reg - 15)) begin
                    // 图像偏暗，增加增益
                    ae_gain_next <= (ae_gain < 8'd200) ? (ae_gain + gain_step) : 8'd200;
                    stability_counter <= 4'd0;
                end 
                else begin
                    // 亮度在目标范围内，增加稳定性计数
                    stability_counter <= (stability_counter < 4'd15) ? stability_counter + 1 : 4'd15;
                end
                
                // 检查是否达到稳定状态
                ae_locked <= (stability_counter >= STABILITY_THRESHOLD);
                ae_state <= AE_APPLY_GAIN;
            end
            
            AE_APPLY_GAIN: begin
                // 应用新的增益值
                ae_gain <= ae_gain_next;
                ae_state <= AE_IDLE;
            end
            
            default: begin
                ae_state <= AE_IDLE;
            end
        endcase
        
        // AE禁用时重置状态
        if (!ae_enable) begin
            ae_state <= AE_IDLE;
            ae_gain <= 8'd128;
            ae_locked <= 1'b0;
            stability_counter <= 4'd0;
            gain_step <= 8'd2;
            gain_step_counter <= 3'd0;
        end
    end
end

// ===================================================================
// 亮度调整 - 应用AE增益
// ===================================================================
wire [15:0] r_adjusted = (rgb_i[23:16] * ae_gain) >> 7;
wire [15:0] g_adjusted = (rgb_i[15:8]  * ae_gain) >> 7;
wire [15:0] b_adjusted = (rgb_i[7:0]   * ae_gain) >> 7;

// 饱和度处理 - 限制在0-255范围内
wire [7:0] r_final = (r_adjusted > 255) ? 8'd255 : r_adjusted[7:0];
wire [7:0] g_final = (g_adjusted > 255) ? 8'd255 : g_adjusted[7:0];
wire [7:0] b_final = (b_adjusted > 255) ? 8'd255 : b_adjusted[7:0];

// ===================================================================
// 输出数据流水线
// ===================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vsync_o <= 1'b0;
        href_o <= 1'b0;
        de_o <= 1'b0;
        rgb_o <= 24'd0;
    end else begin
        // 传递同步信号（可根据需要添加延迟以匹配处理流水线）
        vsync_o <= vsync_i;
        href_o <= href_i;
        de_o <= de_i;
        
        // 输出调整后的RGB数据
        if (ae_enable && de_i) begin
            rgb_o <= {r_final, g_final, b_final};
        end else begin
            rgb_o <= rgb_i;  // AE禁用时直通
        end
    end
end

endmodule