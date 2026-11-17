// 直方图分析模块
module histogram_analyzer_enhanced (
    input               clk,
    input               rst_n,
    input               valid,
    input       [11:0]  x_pos,
    input       [11:0]  y_pos,
    input       [23:0]  rgb_data,
    output reg  [7:0]   avg_brightness,      // 平均亮度
    output reg  [7:0]   target_brightness,   // 目标亮度
    output reg          frame_done           // 帧处理完成标志
);

// 直方图存储器 (简化为32个bin以节省资源)
reg [15:0] histogram_0;
reg [15:0] histogram_1;
reg [15:0] histogram_2;
reg [15:0] histogram_3;
reg [15:0] histogram_4;
reg [15:0] histogram_5;
reg [15:0] histogram_6;
reg [15:0] histogram_7;
reg [15:0] histogram_8;
reg [15:0] histogram_9;
reg [15:0] histogram_10;
reg [15:0] histogram_11;
reg [15:0] histogram_12;
reg [15:0] histogram_13;
reg [15:0] histogram_14;
reg [15:0] histogram_15;
reg [15:0] histogram_16;
reg [15:0] histogram_17;
reg [15:0] histogram_18;
reg [15:0] histogram_19;
reg [15:0] histogram_20;
reg [15:0] histogram_21;
reg [15:0] histogram_22;
reg [15:0] histogram_23;
reg [15:0] histogram_24;
reg [15:0] histogram_25;
reg [15:0] histogram_26;
reg [15:0] histogram_27;
reg [15:0] histogram_28;
reg [15:0] histogram_29;
reg [15:0] histogram_30;
reg [15:0] histogram_31;

// 累计亮度和像素计数
reg [31:0] total_brightness;
reg [31:0] pixel_count;

// 帧计数器
reg [11:0] current_x;
reg [11:0] current_y;
reg [11:0] max_x;
reg [11:0] max_y;

// 计算当前像素的亮度相关信号
wire [7:0] pixel_brightness;
wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;
wire [15:0] brightness_temp;

// 累计计数变量
reg [31:0] cumulative_count;

assign red = rgb_data[23:16];
assign green = rgb_data[15:8];
assign blue = rgb_data[7:0];
assign brightness_temp = red * 8'd76 + green * 8'd150 + blue * 8'd29;
assign pixel_brightness = brightness_temp >> 8;

// 计算直方图bin索引
wire [4:0] bin_index;
assign bin_index = pixel_brightness[7:3]; // 256级亮度分为32个bin

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        max_x <= 12'd1280;
        max_y <= 12'd720;
        // 初始化直方图
        histogram_0 <= 16'd0;
        histogram_1 <= 16'd0;
        histogram_2 <= 16'd0;
        histogram_3 <= 16'd0;
        histogram_4 <= 16'd0;
        histogram_5 <= 16'd0;
        histogram_6 <= 16'd0;
        histogram_7 <= 16'd0;
        histogram_8 <= 16'd0;
        histogram_9 <= 16'd0;
        histogram_10 <= 16'd0;
        histogram_11 <= 16'd0;
        histogram_12 <= 16'd0;
        histogram_13 <= 16'd0;
        histogram_14 <= 16'd0;
        histogram_15 <= 16'd0;
        histogram_16 <= 16'd0;
        histogram_17 <= 16'd0;
        histogram_18 <= 16'd0;
        histogram_19 <= 16'd0;
        histogram_20 <= 16'd0;
        histogram_21 <= 16'd0;
        histogram_22 <= 16'd0;
        histogram_23 <= 16'd0;
        histogram_24 <= 16'd0;
        histogram_25 <= 16'd0;
        histogram_26 <= 16'd0;
        histogram_27 <= 16'd0;
        histogram_28 <= 16'd0;
        histogram_29 <= 16'd0;
        histogram_30 <= 16'd0;
        histogram_31 <= 16'd0;
        
        total_brightness <= 32'd0;
        pixel_count <= 32'd0;
        avg_brightness <= 8'd0;
        target_brightness <= 8'd128; // 默认目标亮度
        frame_done <= 1'b0;
        current_x <= 12'd0;
        current_y <= 12'd0;
        cumulative_count <= 32'd0;
    end else begin
        frame_done <= 1'b0;
        
        if (valid) begin
            current_x <= x_pos;
            current_y <= y_pos;
            
            // 更新直方图
            case (bin_index)
                5'd0:  if (histogram_0 < 16'hFFFE) histogram_0 <= histogram_0 + 1;
                5'd1:  if (histogram_1 < 16'hFFFE) histogram_1 <= histogram_1 + 1;
                5'd2:  if (histogram_2 < 16'hFFFE) histogram_2 <= histogram_2 + 1;
                5'd3:  if (histogram_3 < 16'hFFFE) histogram_3 <= histogram_3 + 1;
                5'd4:  if (histogram_4 < 16'hFFFE) histogram_4 <= histogram_4 + 1;
                5'd5:  if (histogram_5 < 16'hFFFE) histogram_5 <= histogram_5 + 1;
                5'd6:  if (histogram_6 < 16'hFFFE) histogram_6 <= histogram_6 + 1;
                5'd7:  if (histogram_7 < 16'hFFFE) histogram_7 <= histogram_7 + 1;
                5'd8:  if (histogram_8 < 16'hFFFE) histogram_8 <= histogram_8 + 1;
                5'd9:  if (histogram_9 < 16'hFFFE) histogram_9 <= histogram_9 + 1;
                5'd10: if (histogram_10 < 16'hFFFE) histogram_10 <= histogram_10 + 1;
                5'd11: if (histogram_11 < 16'hFFFE) histogram_11 <= histogram_11 + 1;
                5'd12: if (histogram_12 < 16'hFFFE) histogram_12 <= histogram_12 + 1;
                5'd13: if (histogram_13 < 16'hFFFE) histogram_13 <= histogram_13 + 1;
                5'd14: if (histogram_14 < 16'hFFFE) histogram_14 <= histogram_14 + 1;
                5'd15: if (histogram_15 < 16'hFFFE) histogram_15 <= histogram_15 + 1;
                5'd16: if (histogram_16 < 16'hFFFE) histogram_16 <= histogram_16 + 1;
                5'd17: if (histogram_17 < 16'hFFFE) histogram_17 <= histogram_17 + 1;
                5'd18: if (histogram_18 < 16'hFFFE) histogram_18 <= histogram_18 + 1;
                5'd19: if (histogram_19 < 16'hFFFE) histogram_19 <= histogram_19 + 1;
                5'd20: if (histogram_20 < 16'hFFFE) histogram_20 <= histogram_20 + 1;
                5'd21: if (histogram_21 < 16'hFFFE) histogram_21 <= histogram_21 + 1;
                5'd22: if (histogram_22 < 16'hFFFE) histogram_22 <= histogram_22 + 1;
                5'd23: if (histogram_23 < 16'hFFFE) histogram_23 <= histogram_23 + 1;
                5'd24: if (histogram_24 < 16'hFFFE) histogram_24 <= histogram_24 + 1;
                5'd25: if (histogram_25 < 16'hFFFE) histogram_25 <= histogram_25 + 1;
                5'd26: if (histogram_26 < 16'hFFFE) histogram_26 <= histogram_26 + 1;
                5'd27: if (histogram_27 < 16'hFFFE) histogram_27 <= histogram_27 + 1;
                5'd28: if (histogram_28 < 16'hFFFE) histogram_28 <= histogram_28 + 1;
                5'd29: if (histogram_29 < 16'hFFFE) histogram_29 <= histogram_29 + 1;
                5'd30: if (histogram_30 < 16'hFFFE) histogram_30 <= histogram_30 + 1;
                5'd31: if (histogram_31 < 16'hFFFE) histogram_31 <= histogram_31 + 1;
            endcase
            
            // 累计亮度和像素数
            total_brightness <= total_brightness + pixel_brightness;
            pixel_count <= pixel_count + 1;
            
            // 检查是否完成一帧
            if ((x_pos == max_x - 1) && (y_pos == max_y - 1)) begin
                // 计算平均亮度
                if (pixel_count > 0) begin
                    avg_brightness <= total_brightness / pixel_count;
                end else begin
                    avg_brightness <= 8'd0;
                end
                
                // 根据直方图分析计算目标亮度
                // 确定目标亮度级别（例如，使50%的像素在其下方）
                cumulative_count <= 32'd0;
                
                // 查找中值亮度bin
                if (cumulative_count + histogram_0 >= pixel_count/2) begin
                    target_brightness <= 8'd4;
                end else begin
                    cumulative_count <= cumulative_count + histogram_0;
                    if (cumulative_count + histogram_1 >= pixel_count/2) begin
                        target_brightness <= 8'd12;
                    end else begin
                        cumulative_count <= cumulative_count + histogram_1;
                        if (cumulative_count + histogram_2 >= pixel_count/2) begin
                            target_brightness <= 8'd20;
                        end else begin
                            cumulative_count <= cumulative_count + histogram_2;
                            if (cumulative_count + histogram_3 >= pixel_count/2) begin
                                target_brightness <= 8'd28;
                            end else begin
                                cumulative_count <= cumulative_count + histogram_3;
                                if (cumulative_count + histogram_4 >= pixel_count/2) begin
                                    target_brightness <= 8'd36;
                                end else begin
                                    cumulative_count <= cumulative_count + histogram_4;
                                    if (cumulative_count + histogram_5 >= pixel_count/2) begin
                                        target_brightness <= 8'd44;
                                    end else begin
                                        cumulative_count <= cumulative_count + histogram_5;
                                        if (cumulative_count + histogram_6 >= pixel_count/2) begin
                                            target_brightness <= 8'd52;
                                        end else begin
                                            cumulative_count <= cumulative_count + histogram_6;
                                            if (cumulative_count + histogram_7 >= pixel_count/2) begin
                                                target_brightness <= 8'd60;
                                            end else begin
                                                cumulative_count <= cumulative_count + histogram_7;
                                                if (cumulative_count + histogram_8 >= pixel_count/2) begin
                                                    target_brightness <= 8'd68;
                                                end else begin
                                                    cumulative_count <= cumulative_count + histogram_8;
                                                    if (cumulative_count + histogram_9 >= pixel_count/2) begin
                                                        target_brightness <= 8'd76;
                                                    end else begin
                                                        cumulative_count <= cumulative_count + histogram_9;
                                                        if (cumulative_count + histogram_10 >= pixel_count/2) begin
                                                            target_brightness <= 8'd84;
                                                        end else begin
                                                            cumulative_count <= cumulative_count + histogram_10;
                                                            if (cumulative_count + histogram_11 >= pixel_count/2) begin
                                                                target_brightness <= 8'd92;
                                                            end else begin
                                                                cumulative_count <= cumulative_count + histogram_11;
                                                                if (cumulative_count + histogram_12 >= pixel_count/2) begin
                                                                    target_brightness <= 8'd100;
                                                                end else begin
                                                                    cumulative_count <= cumulative_count + histogram_12;
                                                                    if (cumulative_count + histogram_13 >= pixel_count/2) begin
                                                                        target_brightness <= 8'd108;
                                                                    end else begin
                                                                        cumulative_count <= cumulative_count + histogram_13;
                                                                        if (cumulative_count + histogram_14 >= pixel_count/2) begin
                                                                            target_brightness <= 8'd116;
                                                                        end else begin
                                                                            cumulative_count <= cumulative_count + histogram_14;
                                                                            if (cumulative_count + histogram_15 >= pixel_count/2) begin
                                                                                target_brightness <= 8'd124;
                                                                            end else begin
                                                                                cumulative_count <= cumulative_count + histogram_15;
                                                                                if (cumulative_count + histogram_16 >= pixel_count/2) begin
                                                                                    target_brightness <= 8'd132;
                                                                                end else begin
                                                                                    cumulative_count <= cumulative_count + histogram_16;
                                                                                    if (cumulative_count + histogram_17 >= pixel_count/2) begin
                                                                                        target_brightness <= 8'd140;
                                                                                    end else begin
                                                                                        cumulative_count <= cumulative_count + histogram_17;
                                                                                        if (cumulative_count + histogram_18 >= pixel_count/2) begin
                                                                                            target_brightness <= 8'd148;
                                                                                        end else begin
                                                                                            cumulative_count <= cumulative_count + histogram_18;
                                                                                            if (cumulative_count + histogram_19 >= pixel_count/2) begin
                                                                                                target_brightness <= 8'd156;
                                                                                            end else begin
                                                                                                cumulative_count <= cumulative_count + histogram_19;
                                                                                                if (cumulative_count + histogram_20 >= pixel_count/2) begin
                                                                                                    target_brightness <= 8'd164;
                                                                                                end else begin
                                                                                                    cumulative_count <= cumulative_count + histogram_20;
                                                                                                    if (cumulative_count + histogram_21 >= pixel_count/2) begin
                                                                                                        target_brightness <= 8'd172;
                                                                                                    end else begin
                                                                                                        cumulative_count <= cumulative_count + histogram_21;
                                                                                                        if (cumulative_count + histogram_22 >= pixel_count/2) begin
                                                                                                            target_brightness <= 8'd180;
                                                                                                        end else begin
                                                                                                            cumulative_count <= cumulative_count + histogram_22;
                                                                                                            if (cumulative_count + histogram_23 >= pixel_count/2) begin
                                                                                                                target_brightness <= 8'd188;
                                                                                                            end else begin
                                                                                                                cumulative_count <= cumulative_count + histogram_23;
                                                                                                                if (cumulative_count + histogram_24 >= pixel_count/2) begin
                                                                                                                    target_brightness <= 8'd196;
                                                                                                                end else begin
                                                                                                                    cumulative_count <= cumulative_count + histogram_24;
                                                                                                                    if (cumulative_count + histogram_25 >= pixel_count/2) begin
                                                                                                                        target_brightness <= 8'd204;
                                                                                                                    end else begin
                                                                                                                        cumulative_count <= cumulative_count + histogram_25;
                                                                                                                        if (cumulative_count + histogram_26 >= pixel_count/2) begin
                                                                                                                            target_brightness <= 8'd212;
                                                                                                                        end else begin
                                                                                                                            cumulative_count <= cumulative_count + histogram_26;
                                                                                                                            if (cumulative_count + histogram_27 >= pixel_count/2) begin
                                                                                                                                target_brightness <= 8'd220;
                                                                                                                            end else begin
                                                                                                                                cumulative_count <= cumulative_count + histogram_27;
                                                                                                                                if (cumulative_count + histogram_28 >= pixel_count/2) begin
                                                                                                                                    target_brightness <= 8'd228;
                                                                                                                                end else begin
                                                                                                                                    cumulative_count <= cumulative_count + histogram_28;
                                                                                                                                    if (cumulative_count + histogram_29 >= pixel_count/2) begin
                                                                                                                                        target_brightness <= 8'd236;
                                                                                                                                    end else begin
                                                                                                                                        cumulative_count <= cumulative_count + histogram_29;
                                                                                                                                        if (cumulative_count + histogram_30 >= pixel_count/2) begin
                                                                                                                                            target_brightness <= 8'd244;
                                                                                                                                        end else begin
                                                                                                                                            cumulative_count <= cumulative_count + histogram_30;
                                                                                                                                            if (cumulative_count + histogram_31 >= pixel_count/2) begin
                                                                                                                                                target_brightness <= 8'd252;
                                                                                                                                            end else begin
                                                                                                                                                target_brightness <= 8'd252; // 默认值
                                                                                                                                            end
                                                                                                                                        end
                                                                                                                                    end
                                                                                                                                end
                                                                                                                            end
                                                                                                                        end
                                                                                                                    end
                                                                                                                end
                                                                                                            end
                                                                                                        end
                                                                                                    end
                                                                                                end
                                                                                            end
                                                                                        end
                                                                                    end
                                                                                end
                                                                            end
                                                                        end
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                // 重置计数器
                total_brightness <= 32'd0;
                pixel_count <= 32'd0;
                
                // 清零直方图
                histogram_0 <= 16'd0;
                histogram_1 <= 16'd0;
                histogram_2 <= 16'd0;
                histogram_3 <= 16'd0;
                histogram_4 <= 16'd0;
                histogram_5 <= 16'd0;
                histogram_6 <= 16'd0;
                histogram_7 <= 16'd0;
                histogram_8 <= 16'd0;
                histogram_9 <= 16'd0;
                histogram_10 <= 16'd0;
                histogram_11 <= 16'd0;
                histogram_12 <= 16'd0;
                histogram_13 <= 16'd0;
                histogram_14 <= 16'd0;
                histogram_15 <= 16'd0;
                histogram_16 <= 16'd0;
                histogram_17 <= 16'd0;
                histogram_18 <= 16'd0;
                histogram_19 <= 16'd0;
                histogram_20 <= 16'd0;
                histogram_21 <= 16'd0;
                histogram_22 <= 16'd0;
                histogram_23 <= 16'd0;
                histogram_24 <= 16'd0;
                histogram_25 <= 16'd0;
                histogram_26 <= 16'd0;
                histogram_27 <= 16'd0;
                histogram_28 <= 16'd0;
                histogram_29 <= 16'd0;
                histogram_30 <= 16'd0;
                histogram_31 <= 16'd0;
                
                frame_done <= 1'b1;
            end
        end
    end
end

endmodule