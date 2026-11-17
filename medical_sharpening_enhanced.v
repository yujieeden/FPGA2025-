// =================================================================================
// 医疗专用自适应锐化模块
// 优化内容：
// 1. 改进边界处理算法，消除边界伪影
// 2. 优化图像质量，减少细节损失
// 3. 保持原有功能不变
// =================================================================================
`timescale 1ns/1ps

module medical_sharpening_enhanced #(
    parameter IMG_WIDTH = 1280,
    parameter IMG_HEIGHT = 720,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    
    // 输入视频信号
    input wire in_vsync,
    input wire in_href,
    input wire in_de,
    input wire [DATA_WIDTH-1:0] in_r,
    input wire [DATA_WIDTH-1:0] in_g,
    input wire [DATA_WIDTH-1:0] in_b,
    
    // 输出视频信号
    output reg out_vsync,
    output reg out_href,
    output reg out_de,
    output reg [DATA_WIDTH-1:0] out_r,
    output reg [DATA_WIDTH-1:0] out_g,
    output reg [DATA_WIDTH-1:0] out_b,
    
    // 控制参数
    input wire [7:0] sharpness_strength,    // 锐化强度 (0-255)
    input wire [7:0] edge_threshold,        // 边缘检测阈值
    input wire adaptive_mode,               // 自适应模式使能
    input wire [2:0] detail_preservation,   // 细节保护级别
    input wire noise_aware,                 // 噪声感知使能
    
    // 医疗图像特征输入
    input wire [7:0] tissue_contrast,       // 组织对比度特征
    input wire [7:0] vessel_density,        // 血管密度特征
    input wire [2:0] noise_level,           // 噪声水平评估
    input wire is_bleeding_area,            // 出血区域标志
    input wire [2:0] vessel_scale_select,   // 血管尺度选择
    
    // 可配置权重参数
    input wire [7:0] base_weight,           // 基础锐化权重
    input wire [7:0] tissue_weight,         // 组织对比度权重
    input wire [7:0] vessel_weight          // 血管密度权重
);

// =================================================================================
// 内部信号定义
// =================================================================================

// 行缓冲器 - 使用寄存器数组存储3行数据
reg [DATA_WIDTH-1:0] line_buf_r [0:2];
reg [DATA_WIDTH-1:0] line_buf_g [0:2];  
reg [DATA_WIDTH-1:0] line_buf_b [0:2];

// 当前行像素缓存
reg [DATA_WIDTH-1:0] pixel_cache_r [0:2];
reg [DATA_WIDTH-1:0] pixel_cache_g [0:2];
reg [DATA_WIDTH-1:0] pixel_cache_b [0:2];

// 3x3窗口寄存器 - 拆分为独立信号
reg [DATA_WIDTH-1:0] win_r0, win_r1, win_r2;
reg [DATA_WIDTH-1:0] win_r3, win_r4, win_r5;
reg [DATA_WIDTH-1:0] win_r6, win_r7, win_r8;

reg [DATA_WIDTH-1:0] win_g0, win_g1, win_g2;
reg [DATA_WIDTH-1:0] win_g3, win_g4, win_g5;
reg [DATA_WIDTH-1:0] win_g6, win_g7, win_g8;

reg [DATA_WIDTH-1:0] win_b0, win_b1, win_b2;
reg [DATA_WIDTH-1:0] win_b3, win_b4, win_b5;
reg [DATA_WIDTH-1:0] win_b6, win_b7, win_b8;

// 位置计数器
reg [10:0] pixel_count;
reg [10:0] line_count;
reg [1:0] line_ptr;
reg [1:0] prev_line_ptr, next_line_ptr;

// 流水线控制信号
reg [4:0] vsync_delay;
reg [4:0] href_delay;
reg [4:0] de_delay;

// 特征分析信号
reg [7:0] local_contrast;
reg [7:0] edge_strength;
reg [7:0] texture_density;
reg is_vessel_region;
reg is_detail_region;

// 锐化处理流水线信号
reg [7:0] adaptive_strength_r, adaptive_strength_g, adaptive_strength_b;
reg [DATA_WIDTH-1:0] sharpened_r, sharpened_g, sharpened_b;

// 行缓冲器写入控制信号
reg line_buf_wr_en;

// 边界处理优化信号
reg [DATA_WIDTH-1:0] boundary_pixel_r, boundary_pixel_g, boundary_pixel_b;
reg [1:0] boundary_type; // 0:正常, 1:左边界, 2:右边界, 3:上边界, 4:下边界

// 边界缓存
reg [DATA_WIDTH-1:0] prev_boundary_r [0:2];
reg [DATA_WIDTH-1:0] prev_boundary_g [0:2];
reg [DATA_WIDTH-1:0] prev_boundary_b [0:2];

// 流水线寄存器
reg [DATA_WIDTH-1:0] stage1_r, stage1_g, stage1_b;
reg [DATA_WIDTH-1:0] stage2_r, stage2_g, stage2_b;
reg [DATA_WIDTH-1:0] stage3_r, stage3_g, stage3_b;

// =================================================================================
// 参数定义
// =================================================================================

// 图像处理参数
localparam [7:0] VESSEL_ENHANCE_FACTOR = 8'd25;
localparam [7:0] TISSUE_ENHANCE_FACTOR = 8'd15;
localparam [7:0] DETAIL_BOOST_FACTOR = 8'd20;

// =================================================================================
// 边界处理优化函数
// =================================================================================

// 边界像素计算函数
function [DATA_WIDTH-1:0] calculate_boundary_pixel;
    input [DATA_WIDTH-1:0] center_pixel;
    input [DATA_WIDTH-1:0] neighbor1;
    input [DATA_WIDTH-1:0] neighbor2;
    input [1:0] b_type;
    reg [DATA_WIDTH+1:0] weighted_sum;
    begin
        case (b_type)
            2'b01: begin // 左边界 - 使用右侧邻居加权
                weighted_sum = (center_pixel * 3) + (neighbor1 * 2) + neighbor2;
                calculate_boundary_pixel = weighted_sum / 6;
            end
            2'b10: begin // 右边界 - 使用左侧邻居加权
                weighted_sum = (center_pixel * 3) + (neighbor1 * 2) + neighbor2;
                calculate_boundary_pixel = weighted_sum / 6;
            end
            2'b11: begin // 上下边界 - 使用相邻行加权
                weighted_sum = (center_pixel * 2) + neighbor1 + neighbor2;
                calculate_boundary_pixel = weighted_sum / 4;
            end
            default: begin // 正常情况
                calculate_boundary_pixel = center_pixel;
            end
        endcase
    end
endfunction

// 边界类型检测函数
function [1:0] detect_boundary_type;
    input [10:0] p_count;
    input [10:0] l_count;
    input [10:0] img_width;
    input [10:0] img_height;
    begin
        if (l_count == 0) begin
            detect_boundary_type = 2'b11; // 上边界
        end else if (l_count == img_height - 1) begin
            detect_boundary_type = 2'b11; // 下边界
        end else if (p_count == 0) begin
            detect_boundary_type = 2'b01; // 左边界
        end else if (p_count == img_width - 1) begin
            detect_boundary_type = 2'b10; // 右边界
        end else begin
            detect_boundary_type = 2'b00; // 正常
        end
    end
endfunction

// 计算局部对比度 - 优化边界处理
function [7:0] calculate_local_contrast_optimized;
    input [7:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;
    input [1:0] b_type;
    reg [7:0] min_val, max_val;
    reg [7:0] valid_pixels [0:8];
    integer i, count;
    begin
        // 根据边界类型选择有效像素
        count = 0;
        case (b_type)
            2'b00: begin // 正常情况 - 使用所有像素
                valid_pixels[0] = p0; valid_pixels[1] = p1; valid_pixels[2] = p2;
                valid_pixels[3] = p3; valid_pixels[4] = p4; valid_pixels[5] = p5;
                valid_pixels[6] = p6; valid_pixels[7] = p7; valid_pixels[8] = p8;
                count = 9;
            end
            2'b01: begin // 左边界 - 避免使用左侧像素
                valid_pixels[0] = p1; valid_pixels[1] = p2;
                valid_pixels[2] = p4; valid_pixels[3] = p5;
                valid_pixels[4] = p7; valid_pixels[5] = p8;
                count = 6;
            end
            2'b10: begin // 右边界 - 避免使用右侧像素
                valid_pixels[0] = p0; valid_pixels[1] = p1;
                valid_pixels[2] = p3; valid_pixels[3] = p4;
                valid_pixels[4] = p6; valid_pixels[5] = p7;
                count = 6;
            end
            2'b11: begin // 上下边界 - 避免使用上下像素
                valid_pixels[0] = p1; valid_pixels[1] = p3;
                valid_pixels[2] = p4; valid_pixels[3] = p5;
                valid_pixels[4] = p7;
                count = 5;
            end
        endcase
        
        // 计算有效像素的最小最大值
        if (count > 0) begin
            min_val = valid_pixels[0];
            max_val = valid_pixels[0];
            for (i = 1; i < count && i < 9; i = i + 1) begin
                if (valid_pixels[i] < min_val) min_val = valid_pixels[i];
                if (valid_pixels[i] > max_val) max_val = valid_pixels[i];
            end
        end else begin
            min_val = 0;
            max_val = 0;
        end
        
        calculate_local_contrast_optimized = max_val - min_val;
    end
endfunction

// 计算边缘强度 - 优化边界处理
function [7:0] calculate_edge_strength_optimized;
    input [7:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;
    input [1:0] b_type;
    reg signed [10:0] grad_x, grad_y;
    reg [10:0] magnitude;
    begin
        case (b_type)
            2'b00: begin // 正常情况
                grad_x = (p2 + (p5 << 1) + p8) - (p0 + (p3 << 1) + p6);
                grad_y = (p6 + (p7 << 1) + p8) - (p0 + (p1 << 1) + p2);
            end
            2'b01: begin // 左边界 - 调整卷积核
                grad_x = (p2 + (p5 << 1) + p8) - (p4 + (p3 << 1) + p6);
                grad_y = (p6 + (p7 << 1) + p8) - (p4 + (p1 << 1) + p2);
            end
            2'b10: begin // 右边界 - 调整卷积核
                grad_x = (p4 + (p5 << 1) + p8) - (p0 + (p3 << 1) + p6);
                grad_y = (p6 + (p7 << 1) + p8) - (p0 + (p1 << 1) + p4);
            end
            2'b11: begin // 上下边界 - 调整卷积核
                grad_x = (p2 + (p5 << 1) + p8) - (p0 + (p3 << 1) + p6);
                grad_y = (p4 + (p7 << 1) + p8) - (p0 + (p1 << 1) + p2);
            end
        endcase
        
        // 梯度幅值计算
        magnitude = (grad_x > 0 ? grad_x : -grad_x) + 
                   (grad_y > 0 ? grad_y : -grad_y);
        
        // 医疗图像专用增强
        if (magnitude > 100) 
            magnitude = magnitude + (magnitude >> 2);
        
        // 饱和处理
        if (magnitude > 255) magnitude = 255;
        calculate_edge_strength_optimized = magnitude[7:0];
    end
endfunction

// 拉普拉斯锐化 
function [DATA_WIDTH-1:0] medical_laplacian_sharpen_optimized;
    input [7:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;
    input [7:0] strength;
    input [7:0] contrast;
    input is_vessel;
    input is_detail;
    input [1:0] b_type;
    
    reg signed [11:0] laplacian_sum;
    reg signed [11:0] sharpened_value;
    reg [7:0] enhanced_strength;
    reg [7:0] center_weight;
    reg [7:0] edge_weight;
    begin
        // 根据边界类型调整卷积权重
        case (b_type)
            2'b00: begin // 正常情况
                center_weight = 9;
                edge_weight = 1;
                laplacian_sum = (p4 * center_weight) - 
                               (p1 + p3 + p5 + p7 + ((p0 + p2 + p6 + p8) * edge_weight));
            end
            2'b01: begin // 左边界 - 调整权重
                center_weight = 7;
                edge_weight = 1;
                laplacian_sum = (p4 * center_weight) - 
                               (p3 + p5 + p7 + ((p1 + p6 + p8) * edge_weight));
            end
            2'b10: begin // 右边界 - 调整权重
                center_weight = 7;
                edge_weight = 1;
                laplacian_sum = (p4 * center_weight) - 
                               (p3 + p5 + p7 + ((p1 + p6 + p8) * edge_weight));
            end
            2'b11: begin // 上下边界 - 调整权重
                center_weight = 7;
                edge_weight = 1;
                laplacian_sum = (p4 * center_weight) - 
                               (p1 + p3 + p5 + p7);
            end
        endcase
        
        // 自适应强度增强
        enhanced_strength = strength;
        if (is_vessel) 
            enhanced_strength = enhanced_strength + (enhanced_strength >> 2);
        if (is_detail)
            enhanced_strength = enhanced_strength + (enhanced_strength >> 3);
        
        // 非线性锐化 - 边界感知
        sharpened_value = p4 + ((laplacian_sum * enhanced_strength) >> 8);
        
        // 边界区域保护 - 减少过度锐化
        if (b_type != 2'b00) begin
            if (sharpened_value > p4 + 25) 
                sharpened_value = p4 + 25;
            if (sharpened_value < p4 - 25)
                sharpened_value = p4 - 25;
        end else begin
            // 正常区域
            if (sharpened_value > p4 + 40) 
                sharpened_value = p4 + 40;
            if (sharpened_value < p4 - 40)
                sharpened_value = p4 - 40;
        end
        
        // 饱和处理
        if (sharpened_value > 255) sharpened_value = 255;
        if (sharpened_value < 0) sharpened_value = 0;
        
        medical_laplacian_sharpen_optimized = sharpened_value[7:0];
    end
endfunction

// 辅助函数
function [7:0] calculate_adaptive_strength_simple;
    input [7:0] base_strength;
    input [7:0] contrast;
    input is_vessel;
    input [2:0] noise_lvl;
    
    reg [7:0] adaptive_strength;
    begin
        adaptive_strength = base_strength;
        
        // 血管区域增强
        if (is_vessel) 
            adaptive_strength = adaptive_strength + 20;
        
        // 对比度调整
        if (contrast > 30) 
            adaptive_strength = adaptive_strength + ((contrast - 30) >> 3);
        
        // 噪声抑制
        if (noise_aware) begin
            case (noise_lvl)
                3'd1: adaptive_strength = adaptive_strength - 5;
                3'd2: adaptive_strength = adaptive_strength - 10;
                3'd3: adaptive_strength = adaptive_strength - 15;
                default: adaptive_strength = adaptive_strength;
            endcase
        end
        
        // 饱和处理
        if (adaptive_strength > 200) adaptive_strength = 200;
        if (adaptive_strength < 30) adaptive_strength = 30;
        
        calculate_adaptive_strength_simple = adaptive_strength;
    end
endfunction

// =================================================================================
// 主处理逻辑
// =================================================================================

// 位置计数器管理
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_count <= 0;
        line_count <= 0;
        line_ptr <= 0;
        prev_line_ptr <= 2;
        next_line_ptr <= 1;
        boundary_type <= 0;
    end else begin
        if (in_vsync) begin
            pixel_count <= 0;
            line_count <= 0;
            line_ptr <= 0;
            prev_line_ptr <= 2;
            next_line_ptr <= 1;
            boundary_type <= 0;
        end else if (in_de) begin
            // 检测边界类型
            boundary_type <= detect_boundary_type(pixel_count, line_count, IMG_WIDTH, IMG_HEIGHT);
            
            if (pixel_count == IMG_WIDTH-1) begin
                pixel_count <= 0;
                if (line_count == IMG_HEIGHT-1) begin
                    line_count <= 0;
                end else begin
                    line_count <= line_count + 1;
                end
                // 更新行指针
                line_ptr <= (line_ptr == 2) ? 0 : line_ptr + 1;
                prev_line_ptr <= (line_ptr == 0) ? 2 : line_ptr - 1;
                next_line_ptr <= (line_ptr == 2) ? 0 : line_ptr + 1;
            end else begin
                pixel_count <= pixel_count + 1;
            end
        end
    end
end

// 像素缓存管理 - 优化边界处理
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 初始化像素缓存
        pixel_cache_r[0] <= 0; pixel_cache_r[1] <= 0; pixel_cache_r[2] <= 0;
        pixel_cache_g[0] <= 0; pixel_cache_g[1] <= 0; pixel_cache_g[2] <= 0;
        pixel_cache_b[0] <= 0; pixel_cache_b[1] <= 0; pixel_cache_b[2] <= 0;
        
        // 初始化行缓冲器
        line_buf_r[0] <= 0; line_buf_r[1] <= 0; line_buf_r[2] <= 0;
        line_buf_g[0] <= 0; line_buf_g[1] <= 0; line_buf_g[2] <= 0;
        line_buf_b[0] <= 0; line_buf_b[1] <= 0; line_buf_b[2] <= 0;
        
        // 初始化边界缓存
        prev_boundary_r[0] <= 0; prev_boundary_r[1] <= 0; prev_boundary_r[2] <= 0;
        prev_boundary_g[0] <= 0; prev_boundary_g[1] <= 0; prev_boundary_g[2] <= 0;
        prev_boundary_b[0] <= 0; prev_boundary_b[1] <= 0; prev_boundary_b[2] <= 0;
        
        line_buf_wr_en <= 0;
        boundary_pixel_r <= 0;
        boundary_pixel_g <= 0;
        boundary_pixel_b <= 0;
    end else if (in_de) begin
        // 更新像素缓存 - 移位寄存器方式
        pixel_cache_r[0] <= pixel_cache_r[1];
        pixel_cache_r[1] <= pixel_cache_r[2];
        pixel_cache_r[2] <= in_r;
        
        pixel_cache_g[0] <= pixel_cache_g[1];
        pixel_cache_g[1] <= pixel_cache_g[2];
        pixel_cache_g[2] <= in_g;
        
        pixel_cache_b[0] <= pixel_cache_b[1];
        pixel_cache_b[1] <= pixel_cache_b[2];
        pixel_cache_b[2] <= in_b;
        
        // 边界像素计算
        case (boundary_type)
            2'b01: begin // 左边界
                boundary_pixel_r <= calculate_boundary_pixel(in_r, pixel_cache_r[1], pixel_cache_r[2], 2'b01);
                boundary_pixel_g <= calculate_boundary_pixel(in_g, pixel_cache_g[1], pixel_cache_g[2], 2'b01);
                boundary_pixel_b <= calculate_boundary_pixel(in_b, pixel_cache_b[1], pixel_cache_b[2], 2'b01);
            end
            2'b10: begin // 右边界
                boundary_pixel_r <= calculate_boundary_pixel(in_r, pixel_cache_r[0], pixel_cache_r[1], 2'b10);
                boundary_pixel_g <= calculate_boundary_pixel(in_g, pixel_cache_g[0], pixel_cache_g[1], 2'b10);
                boundary_pixel_b <= calculate_boundary_pixel(in_b, pixel_cache_b[0], pixel_cache_b[1], 2'b10);
            end
            2'b11: begin // 上下边界
                boundary_pixel_r <= calculate_boundary_pixel(in_r, line_buf_r[line_ptr], line_buf_r[prev_line_ptr], 2'b11);
                boundary_pixel_g <= calculate_boundary_pixel(in_g, line_buf_g[line_ptr], line_buf_g[prev_line_ptr], 2'b11);
                boundary_pixel_b <= calculate_boundary_pixel(in_b, line_buf_b[line_ptr], line_buf_b[prev_line_ptr], 2'b11);
            end
            default: begin // 正常情况
                boundary_pixel_r <= in_r;
                boundary_pixel_g <= in_g;
                boundary_pixel_b <= in_b;
            end
        endcase
        
        // 行缓冲器写入使能
        line_buf_wr_en <= (pixel_count >= 1) && (pixel_count < IMG_WIDTH-1);
        
        // 行缓冲器更新 - 使用边界优化后的像素
        if (line_buf_wr_en) begin
            line_buf_r[line_ptr] <= boundary_pixel_r;
            line_buf_g[line_ptr] <= boundary_pixel_g;
            line_buf_b[line_ptr] <= boundary_pixel_b;
        end
        
        // 边界缓存更新
        if (pixel_count == 0) begin
            prev_boundary_r[0] <= line_buf_r[prev_line_ptr];
            prev_boundary_g[0] <= line_buf_g[prev_line_ptr];
            prev_boundary_b[0] <= line_buf_b[prev_line_ptr];
        end
    end
end

// 3x3窗口生成
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 初始化所有窗口像素为0
        win_r0 <= 0; win_r1 <= 0; win_r2 <= 0;
        win_r3 <= 0; win_r4 <= 0; win_r5 <= 0;
        win_r6 <= 0; win_r7 <= 0; win_r8 <= 0;
        
        win_g0 <= 0; win_g1 <= 0; win_g2 <= 0;
        win_g3 <= 0; win_g4 <= 0; win_g5 <= 0;
        win_g6 <= 0; win_g7 <= 0; win_g8 <= 0;
        
        win_b0 <= 0; win_b1 <= 0; win_b2 <= 0;
        win_b3 <= 0; win_b4 <= 0; win_b5 <= 0;
        win_b6 <= 0; win_b7 <= 0; win_b8 <= 0;
    end else if (in_de) begin
        case (boundary_type)
            2'b00: begin // 正常情况
                // R通道 - 上一行
                win_r0 <= line_buf_r[prev_line_ptr];
                win_r1 <= line_buf_r[prev_line_ptr];
                win_r2 <= line_buf_r[prev_line_ptr];
                
                // R通道 - 当前行
                win_r3 <= pixel_cache_r[0];
                win_r4 <= pixel_cache_r[1];
                win_r5 <= pixel_cache_r[2];
                
                // R通道 - 下一行
                win_r6 <= line_buf_r[next_line_ptr];
                win_r7 <= line_buf_r[next_line_ptr];
                win_r8 <= line_buf_r[next_line_ptr];
                
                // G通道
                win_g0 <= line_buf_g[prev_line_ptr];
                win_g1 <= line_buf_g[prev_line_ptr];
                win_g2 <= line_buf_g[prev_line_ptr];
                
                win_g3 <= pixel_cache_g[0];
                win_g4 <= pixel_cache_g[1];
                win_g5 <= pixel_cache_g[2];
                
                win_g6 <= line_buf_g[next_line_ptr];
                win_g7 <= line_buf_g[next_line_ptr];
                win_g8 <= line_buf_g[next_line_ptr];
                
                // B通道
                win_b0 <= line_buf_b[prev_line_ptr];
                win_b1 <= line_buf_b[prev_line_ptr];
                win_b2 <= line_buf_b[prev_line_ptr];
                
                win_b3 <= pixel_cache_b[0];
                win_b4 <= pixel_cache_b[1];
                win_b5 <= pixel_cache_b[2];
                
                win_b6 <= line_buf_b[next_line_ptr];
                win_b7 <= line_buf_b[next_line_ptr];
                win_b8 <= line_buf_b[next_line_ptr];
            end
            
            2'b01: begin // 左边界
                // 使用边界优化像素填充左侧
                win_r0 <= boundary_pixel_r; win_r1 <= boundary_pixel_r; win_r2 <= line_buf_r[prev_line_ptr];
                win_r3 <= boundary_pixel_r; win_r4 <= pixel_cache_r[1]; win_r5 <= pixel_cache_r[2];
                win_r6 <= boundary_pixel_r; win_r7 <= boundary_pixel_r; win_r8 <= line_buf_r[next_line_ptr];
                
                win_g0 <= boundary_pixel_g; win_g1 <= boundary_pixel_g; win_g2 <= line_buf_g[prev_line_ptr];
                win_g3 <= boundary_pixel_g; win_g4 <= pixel_cache_g[1]; win_g5 <= pixel_cache_g[2];
                win_g6 <= boundary_pixel_g; win_g7 <= boundary_pixel_g; win_g8 <= line_buf_g[next_line_ptr];
                
                win_b0 <= boundary_pixel_b; win_b1 <= boundary_pixel_b; win_b2 <= line_buf_b[prev_line_ptr];
                win_b3 <= boundary_pixel_b; win_b4 <= pixel_cache_b[1]; win_b5 <= pixel_cache_b[2];
                win_b6 <= boundary_pixel_b; win_b7 <= boundary_pixel_b; win_b8 <= line_buf_b[next_line_ptr];
            end
            
            2'b10: begin // 右边界
                // 使用边界优化像素填充右侧
                win_r0 <= line_buf_r[prev_line_ptr]; win_r1 <= boundary_pixel_r; win_r2 <= boundary_pixel_r;
                win_r3 <= pixel_cache_r[0]; win_r4 <= pixel_cache_r[1]; win_r5 <= boundary_pixel_r;
                win_r6 <= line_buf_r[next_line_ptr]; win_r7 <= boundary_pixel_r; win_r8 <= boundary_pixel_r;
                
                win_g0 <= line_buf_g[prev_line_ptr]; win_g1 <= boundary_pixel_g; win_g2 <= boundary_pixel_g;
                win_g3 <= pixel_cache_g[0]; win_g4 <= pixel_cache_g[1]; win_g5 <= boundary_pixel_g;
                win_g6 <= line_buf_g[next_line_ptr]; win_g7 <= boundary_pixel_g; win_g8 <= boundary_pixel_g;
                
                win_b0 <= line_buf_b[prev_line_ptr]; win_b1 <= boundary_pixel_b; win_b2 <= boundary_pixel_b;
                win_b3 <= pixel_cache_b[0]; win_b4 <= pixel_cache_b[1]; win_b5 <= boundary_pixel_b;
                win_b6 <= line_buf_b[next_line_ptr]; win_b7 <= boundary_pixel_b; win_b8 <= boundary_pixel_b;
            end
            
            2'b11: begin // 上下边界
                // 使用边界优化像素填充上下
                win_r0 <= boundary_pixel_r; win_r1 <= boundary_pixel_r; win_r2 <= boundary_pixel_r;
                win_r3 <= pixel_cache_r[0]; win_r4 <= pixel_cache_r[1]; win_r5 <= pixel_cache_r[2];
                win_r6 <= boundary_pixel_r; win_r7 <= boundary_pixel_r; win_r8 <= boundary_pixel_r;
                
                win_g0 <= boundary_pixel_g; win_g1 <= boundary_pixel_g; win_g2 <= boundary_pixel_g;
                win_g3 <= pixel_cache_g[0]; win_g4 <= pixel_cache_g[1]; win_g5 <= pixel_cache_g[2];
                win_g6 <= boundary_pixel_g; win_g7 <= boundary_pixel_g; win_g8 <= boundary_pixel_g;
                
                win_b0 <= boundary_pixel_b; win_b1 <= boundary_pixel_b; win_b2 <= boundary_pixel_b;
                win_b3 <= pixel_cache_b[0]; win_b4 <= pixel_cache_b[1]; win_b5 <= pixel_cache_b[2];
                win_b6 <= boundary_pixel_b; win_b7 <= boundary_pixel_b; win_b8 <= boundary_pixel_b;
            end
        endcase
    end
end

// 特征分析
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        local_contrast <= 0;
        edge_strength <= 0;
        texture_density <= 0;
        is_vessel_region <= 0;
        is_detail_region <= 0;
    end else if (de_delay[0]) begin
        // 使用边界感知的特征计算
        local_contrast <= calculate_local_contrast_optimized(win_r0, win_r1, win_r2, win_r3, win_r4, win_r5, win_r6, win_r7, win_r8, boundary_type);
        edge_strength <= calculate_edge_strength_optimized(win_r0, win_r1, win_r2, win_r3, win_r4, win_r5, win_r6, win_r7, win_r8, boundary_type);
        
        // 保持原有检测逻辑（简化）
        is_vessel_region <= (edge_strength > 20) && (edge_strength < 150) && (local_contrast > 40);
        is_detail_region <= (local_contrast > 10) && (local_contrast < 150);
    end
end

// 自适应锐化强度计算
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        adaptive_strength_r <= 0;
        adaptive_strength_g <= 0;
        adaptive_strength_b <= 0;
    end else if (de_delay[1]) begin
        if (adaptive_mode) begin
            adaptive_strength_r <= calculate_adaptive_strength_simple(
                sharpness_strength, local_contrast, 
                is_vessel_region, noise_level);
                
            adaptive_strength_g <= calculate_adaptive_strength_simple(
                sharpness_strength, local_contrast, 
                is_vessel_region, noise_level);
                
            adaptive_strength_b <= calculate_adaptive_strength_simple(
                sharpness_strength, local_contrast, 
                is_vessel_region, noise_level);
        end else begin
            adaptive_strength_r <= sharpness_strength;
            adaptive_strength_g <= sharpness_strength;
            adaptive_strength_b <= sharpness_strength;
        end
    end
end

// 锐化处理
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sharpened_r <= 0;
        sharpened_g <= 0;
        sharpened_b <= 0;
        
        stage1_r <= 0; stage1_g <= 0; stage1_b <= 0;
        stage2_r <= 0; stage2_g <= 0; stage2_b <= 0;
        stage3_r <= 0; stage3_g <= 0; stage3_b <= 0;
    end else begin
        // 流水线阶段1：缓存输入数据
        if (de_delay[2]) begin
            stage1_r <= win_r4;
            stage1_g <= win_g4;
            stage1_b <= win_b4;
        end
        
        // 流水线阶段2：执行边界优化的锐化计算
        if (de_delay[3]) begin
            stage2_r <= medical_laplacian_sharpen_optimized(win_r0, win_r1, win_r2, win_r3, stage1_r, win_r5, win_r6, win_r7, win_r8, 
                                                adaptive_strength_r, local_contrast, is_vessel_region, is_detail_region, boundary_type);
            stage2_g <= medical_laplacian_sharpen_optimized(win_g0, win_g1, win_g2, win_g3, stage1_g, win_g5, win_g6, win_g7, win_g8,
                                                adaptive_strength_g, local_contrast, is_vessel_region, is_detail_region, boundary_type);
            stage2_b <= medical_laplacian_sharpen_optimized(win_b0, win_b1, win_b2, win_b3, stage1_b, win_b5, win_b6, win_b7, win_b8,
                                                adaptive_strength_b, local_contrast, is_vessel_region, is_detail_region, boundary_type);
        end
        
        // 流水线阶段3：输出结果
        if (de_delay[4]) begin
            sharpened_r <= stage2_r;
            sharpened_g <= stage2_g;
            sharpened_b <= stage2_b;
        end
    end
end

// 控制信号延迟
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vsync_delay <= 0;
        href_delay <= 0;
        de_delay <= 0;
    end else begin
        vsync_delay <= {vsync_delay[3:0], in_vsync};
        href_delay <= {href_delay[3:0], in_href};
        de_delay <= {de_delay[3:0], in_de};
    end
end

// 输出阶段
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_vsync <= 0;
        out_href <= 0;
        out_de <= 0;
        out_r <= 0;
        out_g <= 0;
        out_b <= 0;
    end else begin
        out_vsync <= vsync_delay[4];
        out_href <= href_delay[4];
        out_de <= de_delay[4];
        
        if (de_delay[4]) begin
            out_r <= sharpened_r;
            out_g <= sharpened_g;
            out_b <= sharpened_b;
        end else begin
            out_r <= 0;
            out_g <= 0;
            out_b <= 0;
        end
    end
end

endmodule