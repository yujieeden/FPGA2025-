`timescale 1ns/1ps

module hsv_adjustment (
    input               clk,
    input               rst_n,
    input               enable,        // 添加使能信号
    
    // 视频输入接口
    input               in_vsync,
    input               in_href,
    input               in_de,
    input       [23:0]  in_rgb,
    
    // 调节参数输入 (3位表示5级: 000=-2, 001=-1, 010=0, 011=+1, 100=+2)
    input       [2:0]   hue_level,        // 色调调节级别
    input       [2:0]   saturation_level, // 饱和度调节级别  
    input       [2:0]   value_level,      // 亮度调节级别
    input       [2:0]   contrast_level,   // 对比度调节级别
    
    // 视频输出接口
    output reg          out_vsync,
    output reg          out_href,
    output reg          out_de,
    output reg  [23:0]  out_rgb
);

// ===================================================================
// 参数定义
// ===================================================================
localparam WIDTH = 1280;
localparam HEIGHT = 720;
// 色调调节 (-90° to +90°, 5级调节) - 添加H_adjusted声明
reg [8:0] H_adjusted;
// 同步信号流水线
reg [4:0] vsync_pipe, href_pipe, de_pipe;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vsync_pipe <= 0;
        href_pipe <= 0;
        de_pipe <= 0;
    end else begin
        vsync_pipe <= {vsync_pipe[3:0], in_vsync};
        href_pipe <= {href_pipe[3:0], in_href};
        de_pipe <= {de_pipe[3:0], in_de};
    end
end

// ===================================================================
// RGB转HSV转换
// ===================================================================
wire [7:0] R = in_rgb[23:16];
wire [7:0] G = in_rgb[15:8];
wire [7:0] B = in_rgb[7:0];

// 找到RGB中的最大值和最小值
reg [7:0] max_rgb, min_rgb;
reg [7:0] delta;

always @(posedge clk) begin
    if (R >= G && R >= B) 
        max_rgb <= R;
    else if (G >= R && G >= B) 
        max_rgb <= G;
    else 
        max_rgb <= B;
    
    if (R <= G && R <= B) 
        min_rgb <= R;
    else if (G <= R && G <= B) 
        min_rgb <= G;
    else 
        min_rgb <= B;
    
    delta <= max_rgb - min_rgb;
end


// 计算H分量 (0-359度，用9位表示)
reg [8:0] H;
reg [15:0] H_temp;
always @(posedge clk) begin
    if (delta == 0) begin
        H <= 0;
    end else if (max_rgb == R) begin
        H_temp <= (G >= B) ? (G - B) * 60 : (G - B) * 60 + 360*delta;
        if (delta != 0) H_temp <= H_temp / delta;
        H <= H_temp[8:0];
    end else if (max_rgb == G) begin
        H_temp <= (B - R) * 60 + 120*delta;
        if (delta != 0) H_temp <= H_temp / delta;
        H <= H_temp[8:0];
    end else begin // max_rgb == B
        H_temp <= (R - G) * 60 + 240*delta;
        if (delta != 0) H_temp <= H_temp / delta;
        H <= H_temp[8:0];
    end
end


// 计算S分量 (0-255)
reg [7:0] S;
always @(posedge clk) begin
    if (max_rgb == 0)
        S <= 0;
    else begin
        S <= (delta * 255) / max_rgb;
    end
end

// V分量就是最大值
reg [7:0] V;
always @(posedge clk) begin
    V <= max_rgb;
end

// ===================================================================
// HSV参数调节
// ===================================================================
// 色调调节 (-60° to +60°, 5级调节)

always @(posedge clk) begin
    case (hue_level)
        3'b000: H_adjusted <= (H >= 60) ? H - 9'd60 : H + 9'd300;  // -2级: -60°
        3'b001: H_adjusted <= (H >= 30) ? H - 9'd30 : H + 9'd330;  // -1级: -30°
        3'b010: H_adjusted <= H;                                   //  0级: 不变
        3'b011: H_adjusted <= (H <= 329) ? H + 9'd30 : H - 9'd330; // +1级: +30°
        3'b100: H_adjusted <= (H <= 299) ? H + 9'd60 : H - 9'd300; // +2级: +60°
        default: H_adjusted <= H;
    endcase
end



// 饱和度调节 - 使用非线性调节增强效果
reg [7:0] S_adjusted;
reg [15:0] S_temp;
always @(posedge clk) begin
    case (saturation_level)
        3'b000: S_temp <= S * S * S / (255 * 255);              // -2级: 立方衰减
        3'b001: S_temp <= S * S / 255;      
        3'b010: S_temp <= S;                        //  0级: 1.0x
        3'b011: S_temp <= S + (255 - S) * 8'd64 / 256;        
        3'b100: S_temp <= 8'd224;                   // +2级: 最大饱和度
        default: S_temp <= S;
    endcase
    S_adjusted <= (S_temp > 255) ? 8'd255 : S_temp[7:0];
end

// 亮度调节 - 使用伽马校正增强效果
reg [7:0] V_adjusted;
reg [15:0] V_temp;
always @(posedge clk) begin
    case (value_level)
        3'b000: begin
            // 降低亮度
            V_temp <= V * V / 255;
        end
        3'b001: begin
            // 轻微降低亮度
            V_temp <= V * 8'd128 / 8'd256;
        end
        3'b010: begin
            // 正常亮度
            V_temp <= V;
        end
        3'b011: begin
            // 轻微增加亮度
            V_temp <= V + (255 - V) / 4;
        end
        3'b100: begin
            // 大幅增加亮度
            V_temp <= 255 - (255 - V) * (255 - V) / 255;
        end
        default: V_temp <= V;
    endcase
    V_adjusted <= (V_temp > 255) ? 8'd255 : V_temp[7:0];
end



// ===================================================================
// HSV转RGB转换
// ===================================================================
reg [7:0] R_out, G_out, B_out;
reg [2:0] region;
reg [15:0] f, p, q, t;

always @(posedge clk) begin
    if (S_adjusted == 0) begin
        // 无色相情况
        R_out <= V_adjusted;
        G_out <= V_adjusted;
        B_out <= V_adjusted;
    end else begin
        region <= H_adjusted / 9'd60;  // 0-5区域
        f <= (H_adjusted % 9'd60) * 255 / 60;  // 小数部分
        
        p <= V_adjusted * (255 - S_adjusted) / 255;
        q <= V_adjusted * (255 - (S_adjusted * f) / 255) / 255;
        t <= V_adjusted * (255 - (S_adjusted * (255 - f)) / 255) / 255;
        
        case (region)
            3'd0: begin R_out <= V_adjusted; G_out <= t[7:0]; B_out <= p[7:0]; end
            3'd1: begin R_out <= q[7:0]; G_out <= V_adjusted; B_out <= p[7:0]; end
            3'd2: begin R_out <= p[7:0]; G_out <= V_adjusted; B_out <= t[7:0]; end
            3'd3: begin R_out <= p[7:0]; G_out <= q[7:0]; B_out <= V_adjusted; end
            3'd4: begin R_out <= t[7:0]; G_out <= p[7:0]; B_out <= V_adjusted; end
            3'd5: begin R_out <= V_adjusted; G_out <= p[7:0]; B_out <= q[7:0]; end
            default: begin R_out <= V_adjusted; G_out <= V_adjusted; B_out <= V_adjusted; end
        endcase
    end
end

    
// 对比度调节
reg [7:0] R_contrast, G_contrast, B_contrast;
reg [15:0] R_temp, G_temp, B_temp;

always @(posedge clk) begin
    case (contrast_level)
        3'b000: begin  // -2级: 极低对比度
            R_temp <= 64 + R_out / 2;
            G_temp <= 64 + G_out / 2;
            B_temp <= 64 + B_out / 2;
        end
        3'b001: begin  // -1级: 低对比度
            R_temp <= 32 + (R_out * 192) / 255;
            G_temp <= 32 + (G_out * 192) / 255;
            B_temp <= 32 + (B_out * 192) / 255;
        end
        3'b010: begin  // 0级: 正常对比度
            R_temp <= R_out;
            G_temp <= G_out;
            B_temp <= B_out;
        end
        3'b011: begin  // +1级: 高对比度
            if (R_out > 128)
                R_temp <= 128 + ((R_out - 128) * 384) / 255;
            else
                R_temp <= (R_out * 128) / 255;
                
            if (G_out > 128)
                G_temp <= 128 + ((G_out - 128) * 384) / 255;
            else
                G_temp <= (G_out * 128) / 255;
                
            if (B_out > 128)
                B_temp <= 128 + ((B_out - 128) * 384) / 255;
            else
                B_temp <= (B_out * 128) / 255;
        end
        3'b100: begin  // +2级: 极高对比度
            //使用简单的S型曲线增强对比度
            R_temp <= (R_out < 128) ? R_out * R_out / 255 : 255 - (255 - R_out) * (255 - R_out) / 255;
            G_temp <= (G_out < 128) ? G_out * G_out / 255 : 255 - (255 - G_out) * (255 - G_out) / 255;
            B_temp <= (B_out < 128) ? B_out * B_out / 255 : 255 - (255 - B_out) * (255 - B_out) / 255;
        end
        default: begin
            R_temp <= R_out;
            G_temp <= G_out;
            B_temp <= B_out;
        end
    endcase
    
    // 钳位到0-255
    R_contrast <= (R_temp > 255) ? 8'd255 : R_temp[7:0];
    G_contrast <= (G_temp > 255) ? 8'd255 : G_temp[7:0];
    B_contrast <= (B_temp > 255) ? 8'd255 : B_temp[7:0];
end

// ===================================================================
// 输出阶段
// ===================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_vsync <= 0;
        out_href <= 0;
        out_de <= 0;
        out_rgb <= 0;
    end else begin
        if (enable) begin
            // 使能时执行HSV调整
            out_vsync <= vsync_pipe[4];
            out_href <= href_pipe[4];
            out_de <= de_pipe[4];
            out_rgb <= {R_contrast, G_contrast, B_contrast};
        end else begin
            // 禁用时直通输入信号
            out_vsync <= in_vsync;
            out_href <= in_href;
            out_de <= in_de;
            out_rgb <= in_rgb;
        end
    end
end


endmodule

