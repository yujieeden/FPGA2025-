`timescale 1ns / 1ps

// =================================================================================
// 血管增强模块 (Vessel Enhancement Module)
// 提供清晰的血管结构显示
// =================================================================================

module vessel_enhancement_improved (
    // 时钟和复位
    input               clk,                    // 像素时钟
    input               rst_n,                  // 异步复位，低有效
    
    // 输入视频信号
    input               in_vsync,              // 输入场同步
    input               in_href,               // 输入行有效
    input               in_de,                 // 输入数据使能
    input       [7:0]   in_r,                  // 输入红色分量
    input       [7:0]   in_g,                  // 输入绿色分量
    input       [7:0]   in_b,                  // 输入蓝色分量
    
    // 输出视频信号
    output reg          out_vsync,             // 输出场同步
    output reg          out_href,              // 输出行有效
    output reg          out_de,                // 输出数据使能
    output reg  [7:0]   out_r,                 // 输出红色分量
    output reg  [7:0]   out_g,                 // 输出绿色分量
    output reg  [7:0]   out_b,                 // 输出蓝色分量
    
    // 控制信号
    input       [2:0]   enhance_strength,      // 增强强度: 0-7
    input               medical_mode_en        // 医疗模式使能
);

// =================================================================================
// 参数定义
// =================================================================================
localparam KERNEL_SIZE = 3;                    // 卷积核大小 3x3
localparam LINE_BUFFER_DEPTH = 1280;           // 行缓存深度，适应1280宽度

// 血管增强系数 - 基于医疗内窥镜优化
localparam [7:0] VESSEL_ENHANCE_R = 8'd64;    // 红色增强系数
localparam [7:0] VESSEL_ENHANCE_G = 8'd128;   // 绿色增强系数（血管主要显示为绿色）
localparam [7:0] VESSEL_ENHANCE_B = 8'd32;    // 蓝色增强系数

// =================================================================================
// 信号定义
// =================================================================================
// 行缓存信号
reg [7:0] line_buffer_0_r [0:LINE_BUFFER_DEPTH-1];
reg [7:0] line_buffer_1_r [0:LINE_BUFFER_DEPTH-1];
reg [7:0] line_buffer_2_r [0:LINE_BUFFER_DEPTH-1];
reg [7:0] line_buffer_0_g [0:LINE_BUFFER_DEPTH-1];
reg [7:0] line_buffer_1_g [0:LINE_BUFFER_DEPTH-1];
reg [7:0] line_buffer_2_g [0:LINE_BUFFER_DEPTH-1];
reg [7:0] line_buffer_0_b [0:LINE_BUFFER_DEPTH-1];
reg [7:0] line_buffer_1_b [0:LINE_BUFFER_DEPTH-1];
reg [7:0] line_buffer_2_b [0:LINE_BUFFER_DEPTH-1];

// 3x3 窗口寄存器
reg [7:0] window_r [0:8];  // 红色分量窗口 [0-8] 对应 3x3 矩阵
reg [7:0] window_g [0:8];  // 绿色分量窗口
reg [7:0] window_b [0:8];  // 蓝色分量窗口

// 同步信号延迟链
reg [4:0] vsync_delay;
reg [4:0] href_delay;
reg [4:0] de_delay;

// 中间处理信号
wire [7:0] gray_value;                         // 灰度值
wire [7:0] vessel_strength;                    // 血管强度
reg  [7:0] final_r, final_g, final_b;          // 最终RGB输出

// 血管检测相关信号
wire [10:0] gradient_magnitude;                // 梯度幅值
wire [7:0]  vessel_mask;                       // 血管掩膜

// 行缓存索引信号
reg [10:0] buffer_index;

// =================================================================================
// 行缓存管理
// =================================================================================
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位行缓存
        for (i = 0; i < LINE_BUFFER_DEPTH; i = i + 1) begin
            line_buffer_0_r[i] <= 8'd0;
            line_buffer_1_r[i] <= 8'd0;
            line_buffer_2_r[i] <= 8'd0;
            line_buffer_0_g[i] <= 8'd0;
            line_buffer_1_g[i] <= 8'd0;
            line_buffer_2_g[i] <= 8'd0;
            line_buffer_0_b[i] <= 8'd0;
            line_buffer_1_b[i] <= 8'd0;
            line_buffer_2_b[i] <= 8'd0;
        end
        buffer_index <= 0;
    end else if (in_de) begin
        // 更新行缓存 - 移位操作
        for (i = LINE_BUFFER_DEPTH-1; i > 0; i = i - 1) begin
            // 红色分量行缓存
            line_buffer_2_r[i] <= line_buffer_2_r[i-1];
            line_buffer_1_r[i] <= line_buffer_1_r[i-1];
            line_buffer_0_r[i] <= line_buffer_0_r[i-1];
            // 绿色分量行缓存
            line_buffer_2_g[i] <= line_buffer_2_g[i-1];
            line_buffer_1_g[i] <= line_buffer_1_g[i-1];
            line_buffer_0_g[i] <= line_buffer_0_g[i-1];
            // 蓝色分量行缓存
            line_buffer_2_b[i] <= line_buffer_2_b[i-1];
            line_buffer_1_b[i] <= line_buffer_1_b[i-1];
            line_buffer_0_b[i] <= line_buffer_0_b[i-1];
        end
        
        // 更新行缓存首元素
        line_buffer_2_r[0] <= line_buffer_1_r[0];
        line_buffer_1_r[0] <= line_buffer_0_r[0];
        line_buffer_0_r[0] <= in_r;
        
        line_buffer_2_g[0] <= line_buffer_1_g[0];
        line_buffer_1_g[0] <= line_buffer_0_g[0];
        line_buffer_0_g[0] <= in_g;
        
        line_buffer_2_b[0] <= line_buffer_1_b[0];
        line_buffer_1_b[0] <= line_buffer_0_b[0];
        line_buffer_0_b[0] <= in_b;
        
        // 更新缓存索引
        buffer_index <= (buffer_index == LINE_BUFFER_DEPTH-1) ? 0 : buffer_index + 1;
    end
end

// =================================================================================
// 3x3 窗口生成
// =================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 9; i = i + 1) begin
            window_r[i] <= 8'd0;
            window_g[i] <= 8'd0;
            window_b[i] <= 8'd0;
        end
    end else if (in_de) begin
        // 更新完整的3x3窗口 - 红色分量
        // 第1行 (上一行)
        window_r[0] <= line_buffer_2_r[2]; 
        window_r[1] <= line_buffer_2_r[1]; 
        window_r[2] <= line_buffer_2_r[0];
        // 第2行 (当前行)
        window_r[3] <= line_buffer_1_r[2]; 
        window_r[4] <= line_buffer_1_r[1]; 
        window_r[5] <= line_buffer_1_r[0];
        // 第3行 (下一行)
        window_r[6] <= line_buffer_0_r[2]; 
        window_r[7] <= line_buffer_0_r[1]; 
        window_r[8] <= line_buffer_0_r[0];
        
        // 更新完整的3x3窗口 - 绿色分量
        // 第1行 (上一行)
        window_g[0] <= line_buffer_2_g[2]; 
        window_g[1] <= line_buffer_2_g[1]; 
        window_g[2] <= line_buffer_2_g[0];
        // 第2行 (当前行)
        window_g[3] <= line_buffer_1_g[2]; 
        window_g[4] <= line_buffer_1_g[1]; 
        window_g[5] <= line_buffer_1_g[0];
        // 第3行 (下一行)
        window_g[6] <= line_buffer_0_g[2]; 
        window_g[7] <= line_buffer_0_g[1]; 
        window_g[8] <= line_buffer_0_g[0];
        
        // 更新完整的3x3窗口 - 蓝色分量
        // 第1行 (上一行)
        window_b[0] <= line_buffer_2_b[2]; 
        window_b[1] <= line_buffer_2_b[1]; 
        window_b[2] <= line_buffer_2_b[0];
        // 第2行 (当前行)
        window_b[3] <= line_buffer_1_b[2]; 
        window_b[4] <= line_buffer_1_b[1]; 
        window_b[5] <= line_buffer_1_b[0];
        // 第3行 (下一行)
        window_b[6] <= line_buffer_0_b[2]; 
        window_b[7] <= line_buffer_0_b[1]; 
        window_b[8] <= line_buffer_0_b[0];
    end
end

// =================================================================================
// 同步信号延迟
// =================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vsync_delay <= 5'b0;
        href_delay  <= 5'b0;
        de_delay    <= 5'b0;
    end else begin
        vsync_delay <= {vsync_delay[3:0], in_vsync};
        href_delay  <= {href_delay[3:0], in_href};
        de_delay    <= {de_delay[3:0], in_de};
    end
end

// =================================================================================
// 灰度转换
// =================================================================================
assign gray_value = (in_r * 8'd28 + in_g * 8'd147 + in_b * 8'd17) >> 8;  // 0.299R + 0.587G + 0.114B

// =================================================================================
// Sobel 边缘检测 - 血管梯度计算
// =================================================================================
wire [10:0] sobel_x, sobel_y;

// Sobel X 方向梯度
assign sobel_x = (
    (window_g[0] + (window_g[3] << 1) + window_g[6]) - 
    (window_g[2] + (window_g[5] << 1) + window_g[8])
);

// Sobel Y 方向梯度  
assign sobel_y = (
    (window_g[0] + (window_g[1] << 1) + window_g[2]) - 
    (window_g[6] + (window_g[7] << 1) + window_g[8])
);

// 梯度幅值计算 (近似)
assign gradient_magnitude = (sobel_x > sobel_y) ? sobel_x + (sobel_y >> 1) : sobel_y + (sobel_x >> 1);

// 血管强度映射
assign vessel_strength = (gradient_magnitude > 11'd255) ? 8'd255 : gradient_magnitude[7:0];

// =================================================================================
// 血管增强算法核心
// =================================================================================
reg [7:0] enhanced_strength;

always @(*) begin
    // 根据控制信号调整增强强度
    case (enhance_strength)
        3'd0: enhanced_strength = vessel_strength >> 3;  // 最低强度
        3'd1: enhanced_strength = vessel_strength >> 2;
        3'd2: enhanced_strength = vessel_strength >> 1;
        3'd3: enhanced_strength = vessel_strength;
        3'd4: enhanced_strength = (vessel_strength * 3'd2) > 8'd255 ? 8'd255 : (vessel_strength * 3'd2);
        3'd5: enhanced_strength = (vessel_strength * 3'd3) > 8'd255 ? 8'd255 : (vessel_strength * 3'd3);
        3'd6: enhanced_strength = (vessel_strength * 3'd4) > 8'd255 ? 8'd255 : (vessel_strength * 3'd4);
        3'd7: enhanced_strength = (vessel_strength * 3'd5) > 8'd255 ? 8'd255 : (vessel_strength * 3'd5);
        default: enhanced_strength = vessel_strength;
    endcase
    
    if (medical_mode_en) begin
        // 医疗模式 - 绿色血管增强显示
        final_r = (in_r > enhanced_strength) ? (in_r - enhanced_strength) : 8'd0;
        final_g = (in_g + enhanced_strength) > 8'd255 ? 8'd255 : (in_g + enhanced_strength);
        final_b = (in_b > enhanced_strength) ? (in_b - enhanced_strength) : 8'd0;
    end else begin
        // 普通模式 - 保持自然色彩
        final_r = in_r;
        final_g = in_g;
        final_b = in_b;
    end
end

// =================================================================================
// 输出寄存器
// =================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_vsync <= 1'b0;
        out_href  <= 1'b0;
        out_de    <= 1'b0;
        out_r     <= 8'd0;
        out_g     <= 8'd0;
        out_b     <= 8'd0;
    end else begin
        out_vsync <= vsync_delay[4];
        out_href  <= href_delay[4];
        out_de    <= de_delay[4];
        out_r     <= final_r;
        out_g     <= final_g;
        out_b     <= final_b;
    end
end

endmodule