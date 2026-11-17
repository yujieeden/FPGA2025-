// 高斯滤波器模块
module gaussian_filter
#(
    parameter   [10:0]  IMG_HDISP = 11'd1280,            // 水平显示像素数
    parameter   [10:0]  IMG_VDISP = 11'd720              // 垂直显示像素数
)
(
    input  wire                 clk             ,        // 时钟信号
    input  wire                 rst_n           ,        // 复位信号（低电平有效）
    
    // 待处理图像数据输入
    input  wire                 per_img_vsync   ,        // 输入图像垂直同步信号
    input  wire                 per_img_href    ,        // 输入图像行有效信号
    input  wire     [7:0]       per_img_gray    ,        // 输入图像灰度值
    
    // 处理后图像数据输出
    output reg                  post_img_vsync  ,        // 输出图像垂直同步信号
    output reg                  post_img_href   ,        // 输出图像行有效信号
    output reg      [7:0]       post_img_gray            // 输出图像灰度值
);

//----------------------------------------------------------------------
// 5x5矩阵生成模块实例化
wire                            matrix_img_vsync;
wire                            matrix_img_href;
wire                            matrix_top_edge_flag;
wire                            matrix_bottom_edge_flag;
wire                            matrix_left_edge_flag;
wire                            matrix_right_edge_flag;
wire            [7:0]           matrix_p11;
wire            [7:0]           matrix_p12;
wire            [7:0]           matrix_p13;
wire            [7:0]           matrix_p14;
wire            [7:0]           matrix_p15;
wire            [7:0]           matrix_p21;
wire            [7:0]           matrix_p22;
wire            [7:0]           matrix_p23;
wire            [7:0]           matrix_p24;
wire            [7:0]           matrix_p25;
wire            [7:0]           matrix_p31;
wire            [7:0]           matrix_p32;
wire            [7:0]           matrix_p33;
wire            [7:0]           matrix_p34;
wire            [7:0]           matrix_p35;
wire            [7:0]           matrix_p41;
wire            [7:0]           matrix_p42;
wire            [7:0]           matrix_p43;
wire            [7:0]           matrix_p44;
wire            [7:0]           matrix_p45;
wire            [7:0]           matrix_p51;
wire            [7:0]           matrix_p52;
wire            [7:0]           matrix_p53;
wire            [7:0]           matrix_p54;
wire            [7:0]           matrix_p55;

Matrix_Generate_5X5_8Bit
#(
    .IMG_HDISP  (IMG_HDISP  ),
    .IMG_VDISP  (IMG_VDISP  )
)
u_Matrix_Generate_5X5_8Bit
(
    // 全局时钟和复位
    .clk                    (clk                    ),
    .rst_n                  (rst_n                  ),
    
    // 待处理图像数据输入
    .per_img_vsync          (per_img_vsync          ),  // 输入图像垂直同步信号
    .per_img_href           (per_img_href           ),  // 输入图像行有效信号
    .per_img_gray           (per_img_gray           ),  // 输入图像灰度值
    
    // 图像数据处理结果输出
    .matrix_img_vsync       (matrix_img_vsync       ),  // 处理后的图像垂直同步信号
    .matrix_img_href        (matrix_img_href        ),  // 处理后的图像行有效信号
    .matrix_top_edge_flag   (matrix_top_edge_flag   ),  // 图像上边缘标志
    .matrix_bottom_edge_flag(matrix_bottom_edge_flag),  // 图像下边缘标志
    .matrix_left_edge_flag  (matrix_left_edge_flag  ),  // 图像左边缘标志
    .matrix_right_edge_flag (matrix_right_edge_flag ),  // 图像右边缘标志
    .matrix_p11             (matrix_p11             ),  // 5x5矩阵输出
    .matrix_p12             (matrix_p12             ),
    .matrix_p13             (matrix_p13             ),
    .matrix_p14             (matrix_p14             ),
    .matrix_p15             (matrix_p15             ),
    .matrix_p21             (matrix_p21             ),
    .matrix_p22             (matrix_p22             ),
    .matrix_p23             (matrix_p23             ),
    .matrix_p24             (matrix_p24             ),
    .matrix_p25             (matrix_p25             ),
    .matrix_p31             (matrix_p31             ),  
    .matrix_p32             (matrix_p32             ),
    .matrix_p33             (matrix_p33             ),
    .matrix_p34             (matrix_p34             ),
    .matrix_p35             (matrix_p35             ),
    .matrix_p41             (matrix_p41             ),
    .matrix_p42             (matrix_p42             ),
    .matrix_p43             (matrix_p43             ),
    .matrix_p44             (matrix_p44             ),
    .matrix_p45             (matrix_p45             ),
    .matrix_p51             (matrix_p51             ),
    .matrix_p52             (matrix_p52             ),
    .matrix_p53             (matrix_p53             ),
    .matrix_p54             (matrix_p54             ),
    .matrix_p55             (matrix_p55             )
);

// 乘法运算结果寄存器
reg             [13:0]          mult_result11;
reg             [13:0]          mult_result12;
reg             [13:0]          mult_result13;
reg             [13:0]          mult_result14;
reg             [13:0]          mult_result15;
reg             [13:0]          mult_result21;
reg             [13:0]          mult_result22;
reg             [13:0]          mult_result23;
reg             [13:0]          mult_result24;
reg             [13:0]          mult_result25;
reg             [13:0]          mult_result31;
reg             [13:0]          mult_result32;
reg             [13:0]          mult_result33;
reg             [13:0]          mult_result34;
reg             [13:0]          mult_result35;
reg             [13:0]          mult_result41;
reg             [13:0]          mult_result42;
reg             [13:0]          mult_result43;
reg             [13:0]          mult_result44;
reg             [13:0]          mult_result45;
reg             [13:0]          mult_result51;
reg             [13:0]          mult_result52;
reg             [13:0]          mult_result53;
reg             [13:0]          mult_result54;
reg             [13:0]          mult_result55;

// 高斯核乘法运算（权重系数分别为32, 38, 40, 45, 47, 50）
always @(posedge clk)
begin
    mult_result11 <= matrix_p11 * 6'd32;
    mult_result12 <= matrix_p12 * 6'd38;
    mult_result13 <= matrix_p13 * 6'd40;
    mult_result14 <= matrix_p14 * 6'd38;
    mult_result15 <= matrix_p15 * 6'd32;
    mult_result21 <= matrix_p21 * 6'd38;
    mult_result22 <= matrix_p22 * 6'd45;
    mult_result23 <= matrix_p23 * 6'd47;
    mult_result24 <= matrix_p24 * 6'd45;
    mult_result25 <= matrix_p25 * 6'd38;
    mult_result31 <= matrix_p31 * 6'd40;
    mult_result32 <= matrix_p32 * 6'd47;
    mult_result33 <= matrix_p33 * 6'd50;
    mult_result34 <= matrix_p34 * 6'd47;
    mult_result35 <= matrix_p35 * 6'd40;
    mult_result41 <= matrix_p41 * 6'd38;
    mult_result42 <= matrix_p42 * 6'd45;
    mult_result43 <= matrix_p43 * 6'd47;
    mult_result44 <= matrix_p44 * 6'd45;
    mult_result45 <= matrix_p45 * 6'd38;
    mult_result51 <= matrix_p51 * 6'd32;
    mult_result52 <= matrix_p52 * 6'd38;
    mult_result53 <= matrix_p53 * 6'd40;
    mult_result54 <= matrix_p54 * 6'd38;
    mult_result55 <= matrix_p55 * 6'd32;
end

// 每行乘法结果求和
reg             [15:0]          sum_result1;
reg             [15:0]          sum_result2;
reg             [15:0]          sum_result3;
reg             [15:0]          sum_result4;
reg             [15:0]          sum_result5;

always @(posedge clk)
begin
    sum_result1 <= mult_result11 + mult_result12 + mult_result13 + mult_result14 + mult_result15;
    sum_result2 <= mult_result21 + mult_result22 + mult_result23 + mult_result24 + mult_result25;
    sum_result3 <= mult_result31 + mult_result32 + mult_result33 + mult_result34 + mult_result35;
    sum_result4 <= mult_result41 + mult_result42 + mult_result43 + mult_result44 + mult_result45;
    sum_result5 <= mult_result51 + mult_result52 + mult_result53 + mult_result54 + mult_result55;
end

// 所有行结果总和
reg             [17:0]          sum_result;

always @(posedge clk)
begin
    sum_result <= sum_result1 + sum_result2 + sum_result3 + sum_result4 + sum_result5;
end

// 最终像素数据计算（除以256并四舍五入）
reg             [7:0]           pixel_data;

always @(posedge clk)
begin
    pixel_data <= sum_result[17:10] + sum_result[9];  // 取高8位加上第9位进行四舍五入
end

//----------------------------------------------------------------------
// 信号延迟4个时钟周期同步
reg             [3:0]           matrix_img_vsync_r;
reg             [3:0]           matrix_img_href_r;
reg             [3:0]           matrix_edge_flag_r;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        matrix_img_vsync_r <= 4'b0;
        matrix_img_href_r  <= 4'b0;
        matrix_edge_flag_r <= 4'b0;
    end
    else
    begin
        matrix_img_vsync_r <= {matrix_img_vsync_r[2:0],matrix_img_vsync};
        matrix_img_href_r  <= {matrix_img_href_r[2:0],matrix_img_href};
        matrix_edge_flag_r <= {matrix_edge_flag_r[2:0],matrix_top_edge_flag | matrix_bottom_edge_flag | matrix_left_edge_flag | matrix_right_edge_flag};
    end
end

// 中心像素数据延迟
reg             [7:0]           matrix_p33_r    [0:3];

always @(posedge clk)
begin
    matrix_p33_r[0] <= matrix_p33;
    matrix_p33_r[1] <= matrix_p33_r[0];
    matrix_p33_r[2] <= matrix_p33_r[1];
    matrix_p33_r[3] <= matrix_p33_r[2];
end

//----------------------------------------------------------------------
// 结果输出控制逻辑
always @(posedge clk)
begin
    if(matrix_edge_flag_r[3] == 1'b1)
        post_img_gray <= matrix_p33_r[3];  // 边缘区域直接输出原始中心像素值
    else
        post_img_gray <= pixel_data;       // 非边缘区域输出高斯滤波处理结果
end

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        post_img_vsync <= 1'b0;
        post_img_href  <= 1'b0;
    end
    else
    begin
        post_img_vsync <= matrix_img_vsync_r[3];
        post_img_href  <= matrix_img_href_r[3];
    end
end

endmodule

// 5x5矩阵生成模块
module Matrix_Generate_5X5_8Bit
#(
    parameter   [10:0]  IMG_HDISP = 11'd1280,            // 水平显示像素数
    parameter   [10:0]  IMG_VDISP = 11'd720,             // 垂直显示像素数
    parameter   [10:0]  DELAY_NUM = 11'd10               // 延迟参数
)
(
    // 全局时钟与复位
    input  wire                 clk                     ,
    input  wire                 rst_n                   ,
    
    // 待处理图像数据输入
    input  wire                 per_img_vsync           ,   // 输入图像垂直同步信号
    input  wire                 per_img_href            ,   // 输入图像行有效信号
    input  wire     [7:0]       per_img_gray            ,   // 输入图像灰度值
    
    // 图像数据处理结果输出
    output wire                 matrix_img_vsync        ,   // 处理后的图像垂直同步信号
    output wire                 matrix_img_href         ,   // 处理后的图像行有效信号
    output wire                 matrix_top_edge_flag    ,   // 图像上边缘标志
    output wire                 matrix_bottom_edge_flag ,   // 图像下边缘标志
    output wire                 matrix_left_edge_flag   ,   // 图像左边缘标志
    output wire                 matrix_right_edge_flag  ,   // 图像右边缘标志
    output reg      [7:0]       matrix_p11              ,   // 5x5矩阵输出
    output reg      [7:0]       matrix_p12              ,
    output reg      [7:0]       matrix_p13              ,
    output reg      [7:0]       matrix_p14              ,
    output reg      [7:0]       matrix_p15              ,
    output reg      [7:0]       matrix_p21              ,
    output reg      [7:0]       matrix_p22              ,
    output reg      [7:0]       matrix_p23              ,
    output reg      [7:0]       matrix_p24              ,
    output reg      [7:0]       matrix_p25              ,
    output reg      [7:0]       matrix_p31              ,   
    output reg      [7:0]       matrix_p32              ,
    output reg      [7:0]       matrix_p33              ,
    output reg      [7:0]       matrix_p34              ,
    output reg      [7:0]       matrix_p35              ,
    output reg      [7:0]       matrix_p41              ,
    output reg      [7:0]       matrix_p42              ,
    output reg      [7:0]       matrix_p43              ,
    output reg      [7:0]       matrix_p44              ,
    output reg      [7:0]       matrix_p45              ,
    output reg      [7:0]       matrix_p51              ,
    output reg      [7:0]       matrix_p52              ,
    output reg      [7:0]       matrix_p53              ,
    output reg      [7:0]       matrix_p54              ,
    output reg      [7:0]       matrix_p55              
);

//----------------------------------------------------------------------
// 行有效信号和垂直同步信号计数器
reg             [10:0]          hcnt;  // 水平计数器

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        hcnt <= 11'b0;
    else
    begin
        if(per_img_href == 1'b1)
            hcnt <= hcnt + 1'b1;
        else
            hcnt <= 11'b0;
    end
end

reg                             per_img_href_dly;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        per_img_href_dly <= 1'b0;
    else
        per_img_href_dly <= per_img_href;
end

wire img_href_neg = ~per_img_href & per_img_href_dly;       // 行有效信号下降沿检测

reg             [10:0]          vcnt;  // 垂直计数器

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        vcnt <= 11'b0;
    else
    begin
        if(per_img_vsync == 1'b0)
            vcnt <= 11'b0;
        else if(img_href_neg == 1'b1)
            vcnt <= vcnt + 1'b1;
        else
            vcnt <= vcnt;
    end
end

//----------------------------------------------------------------------
// 两行数据缓冲FIFO
reg             [11:0]          extend_last_two_row_cnt;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        extend_last_two_row_cnt <= 12'b0;
    else
    begin
        if((per_img_href == 1'b1)&&(vcnt == IMG_VDISP - 1'b1)&&(hcnt == IMG_HDISP - 1'b1))
            extend_last_two_row_cnt <= 12'd1;
        else if((extend_last_two_row_cnt > 12'b0)&&(extend_last_two_row_cnt < {DELAY_NUM,1'b0} + {IMG_HDISP,1'b0}))
            extend_last_two_row_cnt <= extend_last_two_row_cnt + 1'b1;
        else
            extend_last_two_row_cnt <= 12'b0;
    end
end

wire extend_2nd_last_row_en = (extend_last_two_row_cnt > DELAY_NUM)&(extend_last_two_row_cnt <= DELAY_NUM + IMG_HDISP) ? 1'b1 : 1'b0;
wire extend_1st_last_row_en = (extend_last_two_row_cnt > {DELAY_NUM,1'b0} + IMG_HDISP) ? 1'b1 : 1'b0;

// FIFO控制信号和数据线定义
wire                            fifo1_wenb;
wire            [7:0]           fifo1_wdata;
wire                            fifo1_renb;
wire            [7:0]           fifo1_rdata;

wire                            fifo2_wenb;
wire            [7:0]           fifo2_wdata;
wire                            fifo2_renb;
wire            [7:0]           fifo2_rdata;

wire                            fifo3_wenb;
wire            [7:0]           fifo3_wdata;
wire                            fifo3_renb;
wire            [7:0]           fifo3_rdata;

wire                            fifo4_wenb;
wire            [7:0]           fifo4_wdata;
wire                            fifo4_renb;
wire            [7:0]           fifo4_rdata;

// FIFO读写使能和数据连接
assign fifo1_wenb  = per_img_href;
assign fifo1_wdata = per_img_gray;
assign fifo1_renb  = per_img_href & (vcnt > 11'd0) | extend_2nd_last_row_en;

assign fifo2_wenb  = per_img_href & (vcnt > 11'd0) | extend_2nd_last_row_en;
assign fifo2_wdata = fifo1_rdata;
assign fifo2_renb  = per_img_href & (vcnt > 11'd1) | extend_2nd_last_row_en | extend_1st_last_row_en;

assign fifo3_wenb  = per_img_href & (vcnt > 11'd1) | extend_2nd_last_row_en;
assign fifo3_wdata = fifo2_rdata;
assign fifo3_renb  = per_img_href & (vcnt > 11'd2) | extend_2nd_last_row_en | extend_1st_last_row_en;

assign fifo4_wenb  = per_img_href & (vcnt > 11'd2) | extend_2nd_last_row_en;
assign fifo4_wdata = fifo3_rdata;
assign fifo4_renb  = per_img_href & (vcnt > 11'd3) | extend_2nd_last_row_en | extend_1st_last_row_en;

// 实例化四个同步FIFO
sync_fifo
#(
    .C_FIFO_WIDTH   (8      ),
    .C_FIFO_DEPTH   (2048  )
)
u1_sync_fifo
(
    .rst        (~rst_n     ),
    .clk        (clk        ),
    
    .wr_en      (fifo1_wenb ),
    .din        (fifo1_wdata), 
    .full       (           ),
    
    .rd_en      (fifo1_renb ),
    .dout       (fifo1_rdata),
    .empty      (           ),
    .data_count (           )
);

sync_fifo
#(
    .C_FIFO_WIDTH   (8      ),
    .C_FIFO_DEPTH   (2048  )
)
u2_sync_fifo
(
    .rst        (~rst_n     ),
    .clk        (clk        ),
    
    .wr_en      (fifo2_wenb ),
    .din        (fifo2_wdata), 
    .full       (           ),
    
    .rd_en      (fifo2_renb ),
    .dout       (fifo2_rdata),
    .empty      (           ),
    .data_count (           )
);

sync_fifo
#(
    .C_FIFO_WIDTH   (8      ),
    .C_FIFO_DEPTH   (2048   )
)
u3_sync_fifo
(
    .rst        (~rst_n     ),
    .clk        (clk        ),
    
    .wr_en      (fifo3_wenb ),
    .din        (fifo3_wdata), 
    .full       (           ),
    
    .rd_en      (fifo3_renb ),
    .dout       (fifo3_rdata),
    .empty      (           ),
    .data_count (           )
);

sync_fifo
#(
    .C_FIFO_WIDTH   (8      ),
    .C_FIFO_DEPTH   (2048   )
)
u4_sync_fifo
(
    .rst        (~rst_n     ),
    .clk        (clk        ),
    
    .wr_en      (fifo4_wenb ),
    .din        (fifo4_wdata), 
    .full       (           ),
    
    .rd_en      (fifo4_renb ),
    .dout       (fifo4_rdata),
    .empty      (           ),
    .data_count (           )
);

//----------------------------------------------------------------------
// 从FIFO读取数据构建5x5矩阵
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        {matrix_p11, matrix_p12, matrix_p13, matrix_p14, matrix_p15} <= 40'h0;
        {matrix_p21, matrix_p22, matrix_p23, matrix_p24, matrix_p25} <= 40'h0;
        {matrix_p31, matrix_p32, matrix_p33, matrix_p34, matrix_p35} <= 40'h0;
        {matrix_p41, matrix_p42, matrix_p43, matrix_p44, matrix_p45} <= 40'h0;
        {matrix_p51, matrix_p52, matrix_p53, matrix_p54, matrix_p55} <= 40'h0;
    end
    else
    begin
        {matrix_p11, matrix_p12, matrix_p13, matrix_p14, matrix_p15} <= {matrix_p12, matrix_p13, matrix_p14, matrix_p15, fifo4_rdata};      // 第一行输入
        {matrix_p21, matrix_p22, matrix_p23, matrix_p24, matrix_p25} <= {matrix_p22, matrix_p23, matrix_p24, matrix_p25, fifo3_rdata};      // 第二行输入
        {matrix_p31, matrix_p32, matrix_p33, matrix_p34, matrix_p35} <= {matrix_p32, matrix_p33, matrix_p34, matrix_p35, fifo2_rdata};      // 第三行输入
        {matrix_p41, matrix_p42, matrix_p43, matrix_p44, matrix_p45} <= {matrix_p42, matrix_p43, matrix_p44, matrix_p45, fifo1_rdata};      // 第四行输入
        {matrix_p51, matrix_p52, matrix_p53, matrix_p54, matrix_p55} <= {matrix_p52, matrix_p53, matrix_p54, matrix_p55, per_img_gray};     // 第五行输入
    end
end

reg                             extend_1st_last_row_en_dly;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        extend_1st_last_row_en_dly <= 1'b0;
    else
        extend_1st_last_row_en_dly <= extend_1st_last_row_en;
end

// 各种标志信号延迟寄存器
reg             [2:0]           vsync;
reg             [2:0]           href;
reg             [2:0]           top_edge_flag;
reg             [2:0]           bottom_edge_flag;
reg             [2:0]           left_edge_flag;
reg             [2:0]           right_edge_flag;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        vsync <= 3'b0;
    else
    begin
        if((per_img_href == 1'b1)&&(vcnt == 11'd2)&&(hcnt == 11'b0))
            vsync[0] <= 1'b1;
        else if((extend_1st_last_row_en == 1'b0)&&(extend_1st_last_row_en_dly == 1'b1))
            vsync[0] <= 1'b0;
        else
            vsync[0] <= vsync[0];
        vsync[2:1] <= vsync[1:0];
    end
end

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        href             <= 3'b0;
        top_edge_flag    <= 3'b0;
        bottom_edge_flag <= 3'b0;
        left_edge_flag   <= 3'b0;
        right_edge_flag  <= 3'b0;
    end
    else
    begin
        href[0]               <= per_img_href & (vcnt > 11'd1) | extend_2nd_last_row_en | extend_1st_last_row_en;
        href[2:1]             <= href[1:0];
        top_edge_flag[0]      <= per_img_href & ((vcnt == 11'd2) | (vcnt == 11'd3));
        top_edge_flag[2:1]    <= top_edge_flag[1:0];
        bottom_edge_flag[0]   <= extend_2nd_last_row_en | extend_1st_last_row_en;
        bottom_edge_flag[2:1] <= bottom_edge_flag[1:0];
        left_edge_flag[0]     <= per_img_href & (vcnt > 11'd1) & (hcnt <= 11'd1) | (extend_last_two_row_cnt == DELAY_NUM + 1'b1) | (extend_last_two_row_cnt == DELAY_NUM + 2'd2) 
                                | (extend_last_two_row_cnt == {DELAY_NUM,1'b0} + IMG_HDISP + 1'b1) | (extend_last_two_row_cnt == {DELAY_NUM,1'b0} + IMG_HDISP + 2'd2);
        left_edge_flag[2:1]   <= left_edge_flag[1:0];
        right_edge_flag[0]    <= per_img_href & (vcnt > 11'd1) & (hcnt >= IMG_HDISP - 2'd2) | (extend_last_two_row_cnt == DELAY_NUM + IMG_HDISP - 1'b1) | (extend_last_two_row_cnt == DELAY_NUM + IMG_HDISP) 
                                | (extend_last_two_row_cnt == {DELAY_NUM,1'b0} + {IMG_HDISP,1'b0} - 1'b1) | (extend_last_two_row_cnt == {DELAY_NUM,1'b0} + {IMG_HDISP,1'b0});
        right_edge_flag[2:1]  <= right_edge_flag[1:0];
    end
end

// 输出信号赋值
assign matrix_img_vsync        = vsync[2];
assign matrix_img_href         = href[2];
assign matrix_top_edge_flag    = top_edge_flag[2];
assign matrix_bottom_edge_flag = bottom_edge_flag[2];
assign matrix_left_edge_flag   = left_edge_flag[2];
assign matrix_right_edge_flag  = right_edge_flag[2];

endmodule