
module FPS_Display (
    input clk_pixel,
    input rstn_pixel,
    input vsync,
    input hsync,
    input de,
    input [11:0] xpos,
    input [11:0] ypos,
    input [23:0] video_data_in,
    output reg [23:0] video_data_out,
    input fps_display_en
);
    // 系统参数
    localparam CLK_FREQ = 74_250_000;  // 74.25MHz支持60FPS
    localparam DISPLAY_X = 12'd40;
    localparam DISPLAY_Y = 12'd32;
    localparam CHAR_WIDTH = 8;
    localparam CHAR_HEIGHT = 16;
    // 帧率计算寄存器
    reg [31:0] frame_start_time;
    reg [31:0] last_frame_start_time;
    reg [31:0] frame_period;
    reg [15:0] fps_value;
    reg frame_start_detected;
    reg vsync_prev;
    // 字符显示寄存器（增加百位字符）
    reg [7:0] fps_string_0; // F
    reg [7:0] fps_string_1; // P
    reg [7:0] fps_string_2; // S
    reg [7:0] fps_string_3; // :
    reg [7:0] fps_string_4; // 百位
    reg [7:0] fps_string_5; // 十位
    reg [7:0] fps_string_6; // 个位
    reg [23:0] char_color;
    reg [23:0] background_color;
    // 像素计数器
    reg [31:0] pixel_counter;
    
    // 字符生成器相关信号
    wire char_pixel_en;
    wire pixel_on;
    wire [7:0] char_data;
    
    // 初始化颜色值
    always @(posedge clk_pixel or negedge rstn_pixel) begin
        if (!rstn_pixel) begin
            char_color <= 24'h4169E1;  // 蓝色
            background_color <= 24'hFFFFFF;  // 白色
        end
        else begin
            char_color <= 24'h4169E1;
            background_color <= 24'hFFFFFF;
        end
    end
    
    // 像素计数器
    always @(posedge clk_pixel or negedge rstn_pixel) begin
        if (!rstn_pixel) begin
            pixel_counter <= 32'd0;
        end
        else begin
            pixel_counter <= pixel_counter + 1;
        end
    end
    
    // 帧开始检测
    always @(posedge clk_pixel or negedge rstn_pixel) begin
        if (!rstn_pixel) begin
            vsync_prev <= 1'b0;
            frame_start_detected <= 1'b0;
            frame_start_time <= 32'd0;
            last_frame_start_time <= 32'd0;
            frame_period <= 32'd0;
            fps_value <= 16'd0;
        end
        else begin
            vsync_prev <= vsync;
            // 检测VSync上升沿（帧开始）
            if (vsync && !vsync_prev) begin
                frame_start_time <= pixel_counter;
                frame_start_detected <= 1'b1;
                
                // 计算帧周期
                if (last_frame_start_time != 0) begin
                    frame_period <= pixel_counter - last_frame_start_time;
                    // 计算FPS（乘以10保留一位小数）
                    if (frame_period != 0) begin
                        // 支持最高120帧（1200 = 120×10）
                        if ((CLK_FREQ * 10) / frame_period > 1200)
                            fps_value <= 16'd1200; 
                        else
                            fps_value <= (CLK_FREQ * 10) / frame_period;
                    end
                end
                last_frame_start_time <= pixel_counter;
            end
        end
    end
    
    // 将FPS值转换为字符串（三位数字）
    reg [15:0] temp_fps;
    always @(posedge clk_pixel or negedge rstn_pixel) begin
        if (!rstn_pixel) begin
            fps_string_0 <= 8'h20;  // 空格
            fps_string_1 <= 8'h20;
            fps_string_2 <= 8'h20;
            fps_string_3 <= 8'h20;
            fps_string_4 <= 8'h20;
            fps_string_5 <= 8'h20;
            fps_string_6 <= 8'h20;
        end
        else begin
            fps_string_0 <= 8'h46;  // F
            fps_string_1 <= 8'h50;  // P
            fps_string_2 <= 8'h53;  // S
            fps_string_3 <= 8'h3A;  // :
            
            // 计算整数帧率（除以10）
            temp_fps = fps_value / 10;
            
            // 提取百位、十位、个位
            fps_string_4 <= (temp_fps >= 100) ? 8'h30 + (temp_fps / 100) : 8'h20; // 百位（或空格）
            fps_string_5 <= (temp_fps >= 10) ? 8'h30 + ((temp_fps % 100) / 10) : 8'h30; // 十位
            fps_string_6 <= 8'h30 + (temp_fps % 10); // 个位
        end
    end
    
    // 输出数据选择
    always @(posedge clk_pixel) begin
        if (fps_display_en && char_pixel_en) begin
            if (pixel_on) 
                video_data_out <= char_color;     // 字符笔画像素
            else 
                video_data_out <= video_data_in;  // 字符背景区域（透明）
        end
        else begin
            video_data_out <= video_data_in;      // 非字符区域
        end
    end
    
    // 字符生成器实例化（增加第六个字符）
    Character_Generator u_char_gen (
        .clk(clk_pixel),
        .rst_n(rstn_pixel),
        .xpos(xpos),
        .ypos(ypos),
        .display_x(DISPLAY_X),
        .display_y(DISPLAY_Y),
        .char_width(CHAR_WIDTH),
        .char_height(CHAR_HEIGHT),
        .string_data_0(fps_string_0),
        .string_data_1(fps_string_1),
        .string_data_2(fps_string_2),
        .string_data_3(fps_string_3),
        .string_data_4(fps_string_4),
        .string_data_5(fps_string_5),
        .string_data_6(fps_string_6),  // 新增个位字符
        .char_pixel_en(char_pixel_en),
        .pixel_on(pixel_on),
        .char_data(char_data)
    );
endmodule

// 在指定区域显示字符
module Character_Generator (
    input clk,
    input rst_n,
    input [11:0] xpos,
    input [11:0] ypos,
    input [11:0] display_x,
    input [11:0] display_y,
    input [7:0] char_width,
    input [7:0] char_height,
    input [7:0] string_data_0,
    input [7:0] string_data_1,
    input [7:0] string_data_2,
    input [7:0] string_data_3,
    input [7:0] string_data_4,
    input [7:0] string_data_5,
    input [7:0] string_data_6,  // 新增第六个字符
    output reg char_pixel_en,
    output reg pixel_on,
    output reg [7:0] char_data
);
    // 字符 ROM 定义
    reg [7:0] char_rom [0:255][0:15];
    
    // 字符显示位置计算
    reg [11:0] char_xpos;
    reg [11:0] char_ypos;
    reg [3:0] char_index;
    reg [3:0] pixel_x_in_char;
    reg [3:0] pixel_y_in_char;
    
    // 字符数据寄存器
    reg [7:0] string_data_0_reg;
    reg [7:0] string_data_1_reg;
    reg [7:0] string_data_2_reg;
    reg [7:0] string_data_3_reg;
    reg [7:0] string_data_4_reg;
    reg [7:0] string_data_5_reg;
    reg [7:0] string_data_6_reg;  
    
    // ROM数据线
    wire [7:0] char_line_data;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_pixel_en <= 1'b0;
            pixel_on <= 1'b0;
            char_data <= 8'h00;
            char_xpos <= 12'd0;
            char_ypos <= 12'd0;
            char_index <= 4'd0;
            pixel_x_in_char <= 4'd0;
            pixel_y_in_char <= 4'd0;
            string_data_0_reg <= 8'h00;
            string_data_1_reg <= 8'h00;
            string_data_2_reg <= 8'h00;
            string_data_3_reg <= 8'h00;
            string_data_4_reg <= 8'h00;
            string_data_5_reg <= 8'h00;
            string_data_6_reg <= 8'h00;  
        end
        else begin
            // 寄存器输入字符数据（包括新增字符）
            string_data_0_reg <= string_data_0;
            string_data_1_reg <= string_data_1;
            string_data_2_reg <= string_data_2;
            string_data_3_reg <= string_data_3;
            string_data_4_reg <= string_data_4;
            string_data_5_reg <= string_data_5;
            string_data_6_reg <= string_data_6;  
            
            // 计算相对于显示位置的坐标
            if (xpos >= display_x && ypos >= display_y) begin
                char_xpos <= xpos - display_x;
                char_ypos <= ypos - display_y;
            end
            else begin
                char_xpos <= 12'd0;
                char_ypos <= 12'd0;
            end
            
            // 计算字符索引和字符内坐标
            if (char_width != 0) begin
                char_index <= char_xpos / char_width;
                pixel_x_in_char <= char_xpos % char_width;
            end
            else begin
                char_index <= 4'd0;
                pixel_x_in_char <= 4'd0;
            end
            pixel_y_in_char <= char_ypos;
            
            // 字符区域检测
            // 只在指定区域内显示字符
            if (char_xpos < (7 * char_width) && char_ypos < char_height) begin
                char_pixel_en <= 1'b1;
                // 选择当前字符
                case (char_index)
                    0: char_data <= string_data_0_reg;
                    1: char_data <= string_data_1_reg;
                    2: char_data <= string_data_2_reg;
                    3: char_data <= string_data_3_reg;
                    4: char_data <= string_data_4_reg;
                    5: char_data <= string_data_5_reg;
                    6: char_data <= string_data_6_reg; 
                    default: char_data <= 8'h00;
                endcase
                
                // 计算像素点使能
                if (pixel_x_in_char < char_width) begin
                    // 获取当前字符行的点阵数据
                    pixel_on <= char_rom[char_data][pixel_y_in_char][7 - pixel_x_in_char];
                end
                else begin
                    pixel_on <= 1'b0;
                end
            end
            else begin
                char_pixel_en <= 1'b0;
                pixel_on <= 1'b0;
                char_data <= 8'h00;
            end
        end
    end
    
    // 初始化字符 ROM（保持原样）
    integer i, j;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                char_rom[i][j] = 8'h00;
            end
        end
        
    // 数字0
    char_rom[8'h30][0] = 8'b00111100;
    char_rom[8'h30][1] = 8'b01000010;
    char_rom[8'h30][2] = 8'b01000010;
    char_rom[8'h30][3] = 8'b01000010;
    char_rom[8'h30][4] = 8'b01000010;
    char_rom[8'h30][5] = 8'b01000010;
    char_rom[8'h30][6] = 8'b01000010;
    char_rom[8'h30][7] = 8'b00111100;
    
    // 数字1
    char_rom[8'h31][0] = 8'b00011000;
    char_rom[8'h31][1] = 8'b00101000;
    char_rom[8'h31][2] = 8'b01001000;
    char_rom[8'h31][3] = 8'b00001000;
    char_rom[8'h31][4] = 8'b00001000;
    char_rom[8'h31][5] = 8'b00001000;
    char_rom[8'h31][6] = 8'b00001000;
    char_rom[8'h31][7] = 8'b00111110;
    
    // 数字2
    char_rom[8'h32][0] = 8'b00111100;
    char_rom[8'h32][1] = 8'b01000010;
    char_rom[8'h32][2] = 8'b00000010;
    char_rom[8'h32][3] = 8'b00001100;
    char_rom[8'h32][4] = 8'b00010000;
    char_rom[8'h32][5] = 8'b00100000;
    char_rom[8'h32][6] = 8'b01000000;
    char_rom[8'h32][7] = 8'b01111110;
    
    // 数字3
    char_rom[8'h33][0] = 8'b00111100;
    char_rom[8'h33][1] = 8'b01000010;
    char_rom[8'h33][2] = 8'b00000010;
    char_rom[8'h33][3] = 8'b00011100;
    char_rom[8'h33][4] = 8'b00000010;
    char_rom[8'h33][5] = 8'b00000010;
    char_rom[8'h33][6] = 8'b01000010;
    char_rom[8'h33][7] = 8'b00111100;
    
    // 数字4
    char_rom[8'h34][0] = 8'b00001000;
    char_rom[8'h34][1] = 8'b00011000;
    char_rom[8'h34][2] = 8'b00101000;
    char_rom[8'h34][3] = 8'b01001000;
    char_rom[8'h34][4] = 8'b01111110;
    char_rom[8'h34][5] = 8'b00001000;
    char_rom[8'h34][6] = 8'b00001000;
    char_rom[8'h34][7] = 8'b00001000;
    
    // 数字5
    char_rom[8'h35][0] = 8'b01111110;
    char_rom[8'h35][1] = 8'b01000000;
    char_rom[8'h35][2] = 8'b01000000;
    char_rom[8'h35][3] = 8'b01111100;
    char_rom[8'h35][4] = 8'b00000010;
    char_rom[8'h35][5] = 8'b00000010;
    char_rom[8'h35][6] = 8'b01000010;
    char_rom[8'h35][7] = 8'b00111100;
    
    // 数字6
    char_rom[8'h36][0] = 8'b00111100;
    char_rom[8'h36][1] = 8'b01000010;
    char_rom[8'h36][2] = 8'b01000000;
    char_rom[8'h36][3] = 8'b01111100;
    char_rom[8'h36][4] = 8'b01000010;
    char_rom[8'h36][5] = 8'b01000010;
    char_rom[8'h36][6] = 8'b01000010;
    char_rom[8'h36][7] = 8'b00111100;
    
    // 数字7
    char_rom[8'h37][0] = 8'b01111110;
    char_rom[8'h37][1] = 8'b00000010;
    char_rom[8'h37][2] = 8'b00000100;
    char_rom[8'h37][3] = 8'b00001000;
    char_rom[8'h37][4] = 8'b00010000;
    char_rom[8'h37][5] = 8'b00100000;
    char_rom[8'h37][6] = 8'b00100000;
    char_rom[8'h37][7] = 8'b00100000;
    
    // 数字8
    char_rom[8'h38][0] = 8'b00111100;
    char_rom[8'h38][1] = 8'b01000010;
    char_rom[8'h38][2] = 8'b01000010;
    char_rom[8'h38][3] = 8'b00111100;
    char_rom[8'h38][4] = 8'b01000010;
    char_rom[8'h38][5] = 8'b01000010;
    char_rom[8'h38][6] = 8'b01000010;
    char_rom[8'h38][7] = 8'b00111100;
    
    // 数字9
    char_rom[8'h39][0] = 8'b00111100;
    char_rom[8'h39][1] = 8'b01000010;
    char_rom[8'h39][2] = 8'b01000010;
    char_rom[8'h39][3] = 8'b00111110;
    char_rom[8'h39][4] = 8'b00000010;
    char_rom[8'h39][5] = 8'b00000010;
    char_rom[8'h39][6] = 8'b01000010;
    char_rom[8'h39][7] = 8'b00111100;
    
    // 冒号 ':'
    char_rom[8'h3A][0] = 8'b00000000;
    char_rom[8'h3A][1] = 8'b00011000;
    char_rom[8'h3A][2] = 8'b00011000;
    char_rom[8'h3A][3] = 8'b00000000;
    char_rom[8'h3A][4] = 8'b00000000;
    char_rom[8'h3A][5] = 8'b00011000;
    char_rom[8'h3A][6] = 8'b00011000;
    char_rom[8'h3A][7] = 8'b00000000;
    
    // 字母 'F'
    char_rom[8'h46][0] = 8'b01111110;
    char_rom[8'h46][1] = 8'b01000000;
    char_rom[8'h46][2] = 8'b01000000;
    char_rom[8'h46][3] = 8'b01111100;
    char_rom[8'h46][4] = 8'b01000000;
    char_rom[8'h46][5] = 8'b01000000;
    char_rom[8'h46][6] = 8'b01000000;
    char_rom[8'h46][7] = 8'b01000000;
    
    // 字母 'P'
    char_rom[8'h50][0] = 8'b01111110;
    char_rom[8'h50][1] = 8'b01000001;
    char_rom[8'h50][2] = 8'b01000001;
    char_rom[8'h50][3] = 8'b01111110;
    char_rom[8'h50][4] = 8'b01000000;
    char_rom[8'h50][5] = 8'b01000000;
    char_rom[8'h50][6] = 8'b01000000;
    char_rom[8'h50][7] = 8'b01000000;
    
    // 字母 'S'
    char_rom[8'h53][0] = 8'b00111100;
    char_rom[8'h53][1] = 8'b01000010;
    char_rom[8'h53][2] = 8'b01000000;
    char_rom[8'h53][3] = 8'b00111100;
    char_rom[8'h53][4] = 8'b00000010;
    char_rom[8'h53][5] = 8'b01000010;
    char_rom[8'h53][6] = 8'b01000010;
    char_rom[8'h53][7] = 8'b00111100;

    end
endmodule
