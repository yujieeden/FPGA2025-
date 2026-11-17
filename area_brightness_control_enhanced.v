// 增强版区域亮度调节模块
module area_brightness_control_enhanced (
    input               clk,
    input               rst_n,
    input               valid,              // 像素有效信号
    input       [11:0]  x_pos,              // X坐标
    input       [11:0]  y_pos,              // Y坐标
    input       [23:0]  rgb_in,             // 输入RGB数据
    output reg  [23:0]  rgb_out,            // 输出RGB数据
    
    // 多区域控制参数
    input       [11:0]  area1_x_start,      // 区域1 X起始坐标
    input       [11:0]  area1_x_end,        // 区域1 X结束坐标
    input       [11:0]  area1_y_start,      // 区域1 Y起始坐标
    input       [11:0]  area1_y_end,        // 区域1 Y结束坐标
    input       [7:0]   area1_brightness_ctrl, // 区域1亮度控制参数
    
    input       [11:0]  area2_x_start,      // 区域2 X起始坐标
    input       [11:0]  area2_x_end,        // 区域2 X结束坐标
    input       [11:0]  area2_y_start,      // 区域2 Y起始坐标
    input       [11:0]  area2_y_end,        // 区域2 Y结束坐标
    input       [7:0]   area2_brightness_ctrl, // 区域2亮度控制参数
    
    input       [3:0]   transition_width    // 软边界过渡宽度
);

// ==================== 流水线寄存器定义 ====================
// 第1级流水线：输入缓存
reg [11:0] x_pos_r1, y_pos_r1;
reg [23:0] rgb_in_r1;
reg valid_r1;

// 第2级流水线：区域判断
reg in_area1_r2, in_area2_r2;
reg [11:0] x_pos_r2, y_pos_r2;
reg [23:0] rgb_in_r2;
reg valid_r2;

// 第3级流水线：距离计算
reg [11:0] distance_to_area1_edge_r3, distance_to_area2_edge_r3;
reg [11:0] x_pos_r3, y_pos_r3;
reg [23:0] rgb_in_r3;
reg valid_r3;

// 第4级流水线：权重计算
reg [7:0] area1_weight_r4, area2_weight_r4;
reg [11:0] x_pos_r4, y_pos_r4;
reg [23:0] rgb_in_r4;
reg valid_r4;

// 第5级流水线：亮度调节
reg [7:0] base_red_r5, base_green_r5, base_blue_r5;
reg [7:0] area1_weight_r5, area2_weight_r5;
reg [23:0] rgb_in_r5;
reg valid_r5;

// 第6级流水线：最终混合
reg [23:0] rgb_out_r6;
reg valid_r6;

// ==================== 中间信号定义 ====================
wire in_area1, in_area2;
wire [11:0] distance_to_area1_edge, distance_to_area2_edge;
wire [7:0] area1_weight, area2_weight;
wire [7:0] base_red, base_green, base_blue;
wire [23:0] final_rgb;

// ==================== 第1级流水线：输入缓存 ====================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_pos_r1 <= 12'd0;
        y_pos_r1 <= 12'd0;
        rgb_in_r1 <= 24'd0;
        valid_r1 <= 1'b0;
    end else begin
        x_pos_r1 <= x_pos;
        y_pos_r1 <= y_pos;
        rgb_in_r1 <= rgb_in;
        valid_r1 <= valid;
    end
end

// ==================== 第2级流水线：区域判断 ====================
assign in_area1 = (x_pos_r1 >= area1_x_start) && (x_pos_r1 <= area1_x_end) &&
                  (y_pos_r1 >= area1_y_start) && (y_pos_r1 <= area1_y_end) && valid_r1;

assign in_area2 = (x_pos_r1 >= area2_x_start) && (x_pos_r1 <= area2_x_end) &&
                  (y_pos_r1 >= area2_y_start) && (y_pos_r1 <= area2_y_end) && valid_r1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_area1_r2 <= 1'b0;
        in_area2_r2 <= 1'b0;
        x_pos_r2 <= 12'd0;
        y_pos_r2 <= 12'd0;
        rgb_in_r2 <= 24'd0;
        valid_r2 <= 1'b0;
    end else begin
        in_area1_r2 <= in_area1;
        in_area2_r2 <= in_area2;
        x_pos_r2 <= x_pos_r1;
        y_pos_r2 <= y_pos_r1;
        rgb_in_r2 <= rgb_in_r1;
        valid_r2 <= valid_r1;
    end
end

// ==================== 第3级流水线：距离计算 ====================
// 简化的距离计算 - 使用曼哈顿距离
wire [11:0] dx_area1_left = (x_pos_r2 < area1_x_start) ? (area1_x_start - x_pos_r2) : 12'd0;
wire [11:0] dx_area1_right = (x_pos_r2 > area1_x_end) ? (x_pos_r2 - area1_x_end) : 12'd0;
wire [11:0] dy_area1_top = (y_pos_r2 < area1_y_start) ? (area1_y_start - y_pos_r2) : 12'd0;
wire [11:0] dy_area1_bottom = (y_pos_r2 > area1_y_end) ? (y_pos_r2 - area1_y_end) : 12'd0;

wire [11:0] dx_area2_left = (x_pos_r2 < area2_x_start) ? (area2_x_start - x_pos_r2) : 12'd0;
wire [11:0] dx_area2_right = (x_pos_r2 > area2_x_end) ? (x_pos_r2 - area2_x_end) : 12'd0;
wire [11:0] dy_area2_top = (y_pos_r2 < area2_y_start) ? (area2_y_start - y_pos_r2) : 12'd0;
wire [11:0] dy_area2_bottom = (y_pos_r2 > area2_y_end) ? (y_pos_r2 - area2_y_end) : 12'd0;

// 计算到区域边界的曼哈顿距离
assign distance_to_area1_edge = (in_area1_r2) ? 12'd0 : 
                               (dx_area1_left | dx_area1_right | dy_area1_top | dy_area1_bottom);

assign distance_to_area2_edge = (in_area2_r2) ? 12'd0 : 
                               (dx_area2_left | dx_area2_right | dy_area2_top | dy_area2_bottom);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        distance_to_area1_edge_r3 <= 12'd0;
        distance_to_area2_edge_r3 <= 12'd0;
        x_pos_r3 <= 12'd0;
        y_pos_r3 <= 12'd0;
        rgb_in_r3 <= 24'd0;
        valid_r3 <= 1'b0;
    end else begin
        distance_to_area1_edge_r3 <= distance_to_area1_edge;
        distance_to_area2_edge_r3 <= distance_to_area2_edge;
        x_pos_r3 <= x_pos_r2;
        y_pos_r3 <= y_pos_r2;
        rgb_in_r3 <= rgb_in_r2;
        valid_r3 <= valid_r2;
    end
end

// ==================== 第4级流水线：权重计算 ====================
// 权重计算，查找表替代除法
function [7:0] calculate_weight;
    input [11:0] distance;
    input in_area;
    input [3:0] trans_width;
    reg [7:0] weight;
    begin
        if (in_area && (distance >= trans_width)) begin
            weight = 8'd255; // 完全在区域内
        end else if (!in_area && (distance >= trans_width)) begin
            weight = 8'd128; // 完全在区域外
        end else begin
            // 使用移位替代除法：weight = (trans_width - distance) * 32
            if (trans_width != 0) begin
                weight = (trans_width - distance[3:0]) << 5; // 近似 *32
                if (weight > 8'd255) weight = 8'd255;
            end else begin
                weight = in_area ? 8'd255 : 8'd128;
            end
        end
        calculate_weight = weight;
    end
endfunction

assign area1_weight = calculate_weight(distance_to_area1_edge_r3, in_area1_r2, transition_width);
assign area2_weight = calculate_weight(distance_to_area2_edge_r3, in_area2_r2, transition_width);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        area1_weight_r4 <= 8'd128;
        area2_weight_r4 <= 8'd128;
        x_pos_r4 <= 12'd0;
        y_pos_r4 <= 12'd0;
        rgb_in_r4 <= 24'd0;
        valid_r4 <= 1'b0;
    end else begin
        area1_weight_r4 <= area1_weight;
        area2_weight_r4 <= area2_weight;
        x_pos_r4 <= x_pos_r3;
        y_pos_r4 <= y_pos_r3;
        rgb_in_r4 <= rgb_in_r3;
        valid_r4 <= valid_r3;
    end
end

// ==================== 第5级流水线：亮度调节 ====================
// 共享的亮度调节计算单元
function [7:0] apply_brightness;
    input [7:0] color;
    input [7:0] brightness_ctrl;
    reg [15:0] temp;
    begin
        if (brightness_ctrl != 8'd128) begin
            temp = (color * brightness_ctrl) >> 7;
            apply_brightness = (temp > 8'hFF) ? 8'hFF : temp[7:0];
        end else begin
            apply_brightness = color;
        end
    end
endfunction

// 区域1亮度调节
wire [7:0] area1_red = apply_brightness(rgb_in_r4[23:16], area1_brightness_ctrl);
wire [7:0] area1_green = apply_brightness(rgb_in_r4[15:8], area1_brightness_ctrl);
wire [7:0] area1_blue = apply_brightness(rgb_in_r4[7:0], area1_brightness_ctrl);

// 区域2亮度调节（在区域1基础上）
wire [7:0] area2_red = apply_brightness(area1_red, area2_brightness_ctrl);
wire [7:0] area2_green = apply_brightness(area1_green, area2_brightness_ctrl);
wire [7:0] area2_blue = apply_brightness(area1_blue, area2_brightness_ctrl);

assign base_red = (area1_weight_r4 != 8'd0 || area2_weight_r4 != 8'd0) ? 
                 ((area1_weight_r4 >= area2_weight_r4) ? area1_red : area2_red) : 
                 rgb_in_r4[23:16];

assign base_green = (area1_weight_r4 != 8'd0 || area2_weight_r4 != 8'd0) ? 
                   ((area1_weight_r4 >= area2_weight_r4) ? area1_green : area2_green) : 
                   rgb_in_r4[15:8];

assign base_blue = (area1_weight_r4 != 8'd0 || area2_weight_r4 != 8'd0) ? 
                  ((area1_weight_r4 >= area2_weight_r4) ? area1_blue : area2_blue) : 
                  rgb_in_r4[7:0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        base_red_r5 <= 8'd0;
        base_green_r5 <= 8'd0;
        base_blue_r5 <= 8'd0;
        area1_weight_r5 <= 8'd128;
        area2_weight_r5 <= 8'd128;
        rgb_in_r5 <= 24'd0;
        valid_r5 <= 1'b0;
    end else begin
        base_red_r5 <= base_red;
        base_green_r5 <= base_green;
        base_blue_r5 <= base_blue;
        area1_weight_r5 <= area1_weight_r4;
        area2_weight_r5 <= area2_weight_r4;
        rgb_in_r5 <= rgb_in_r4;
        valid_r5 <= valid_r4;
    end
end

// ==================== 第6级流水线：最终混合 ====================
function [7:0] final_mix;
    input [7:0] base_color;
    input [7:0] area1_color;
    input [7:0] area2_color;
    input [7:0] area1_weight;
    input [7:0] area2_weight;
    reg [15:0] weighted_color;
    begin
        if (area1_weight >= area2_weight) begin
            weighted_color = (base_color * (8'd255 - area1_weight) + area1_color * area1_weight) >> 8;
        end else begin
            weighted_color = (base_color * (8'd255 - area2_weight) + area2_color * area2_weight) >> 8;
        end
        final_mix = (weighted_color > 8'hFF) ? 8'hFF : weighted_color[7:0];
    end
endfunction

// 重新计算区域颜色用于最终混合
wire [7:0] final_area1_red = apply_brightness(rgb_in_r5[23:16], area1_brightness_ctrl);
wire [7:0] final_area1_green = apply_brightness(rgb_in_r5[15:8], area1_brightness_ctrl);
wire [7:0] final_area1_blue = apply_brightness(rgb_in_r5[7:0], area1_brightness_ctrl);

wire [7:0] final_area2_red = apply_brightness(final_area1_red, area2_brightness_ctrl);
wire [7:0] final_area2_green = apply_brightness(final_area1_green, area2_brightness_ctrl);
wire [7:0] final_area2_blue = apply_brightness(final_area1_blue, area2_brightness_ctrl);

wire [7:0] final_red = final_mix(base_red_r5, final_area1_red, final_area2_red, 
                                area1_weight_r5, area2_weight_r5);
wire [7:0] final_green = final_mix(base_green_r5, final_area1_green, final_area2_green, 
                                  area1_weight_r5, area2_weight_r5);
wire [7:0] final_blue = final_mix(base_blue_r5, final_area1_blue, final_area2_blue, 
                                 area1_weight_r5, area2_weight_r5);

assign final_rgb = {final_red, final_green, final_blue};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rgb_out_r6 <= 24'd0;
        valid_r6 <= 1'b0;
    end else begin
        rgb_out_r6 <= (area1_weight_r5 != 8'd0 || area2_weight_r5 != 8'd0) ? final_rgb : rgb_in_r5;
        valid_r6 <= valid_r5;
    end
end

// ==================== 输出赋值 ====================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rgb_out <= 24'd0;
    end else if (valid_r6) begin
        rgb_out <= rgb_out_r6;
    end
end

endmodule