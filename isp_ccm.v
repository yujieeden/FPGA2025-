
`timescale 1 ns / 1 ps

module isp_ccm
#(
parameter BITS   = 12   ,
parameter WIDTH  = 1920 ,
parameter HEIGHT = 1080
)
(
input pclk ,                         //时钟信号
input rst_n,                         //复位信号

input signed [7:0] m_rr, m_rg, m_rb, //颜色校正矩阵中的系数（有符号8位）
input signed [7:0] m_gr, m_gg, m_gb, //颜色校正矩阵中的系数（有符号8位）
input signed [7:0] m_br, m_bg, m_bb, //颜色校正矩阵中的系数（有符号8位）

input in_href        ,               //输入行同步信号
input in_vsync       ,               //输入场同步信号
input [BITS-1:0] in_r,               //输入红色分量（BITS位）
input [BITS-1:0] in_g,               //输入绿色分量（BITS位）
input [BITS-1:0] in_b,               //输入蓝色分量（BITS位）
                                     
output out_href        ,             //输出行同步信号
output out_vsync       ,             //输出场同步信号
output [BITS-1:0] out_r,             //输出红色分量（BITS位）
output [BITS-1:0] out_g,             //输出绿色分量（BITS位）
output [BITS-1:0] out_b              //输出蓝色分量（BITS位）
);


///////////////////////////////////////////////////////////////////
// [Rout]   [Mrr, Mrg, Mrb]   [Rin]
// [Gout] = [Mgr, Mgg, Mgb] * [Gin]
// [Bout]   [Mbr, Mbg, Mbb]   [Bin]
//localparam CCM_RR =  8'sh1a, CCM_RG = -8'sh05, CCM_RB = -8'sh05;
//localparam CCM_GR = -8'sh05, CCM_GG =  8'sh1a, CCM_GB = -8'sh05;
//localparam CCM_BR = -8'sh05, CCM_BG = -8'sh05, CCM_BB =  8'sh1a;
///////////////////////////////////////////////////////////////////


/*in_r_1、in_g_1和in_b_1是输入红色分量、绿色分量和蓝色分量的寄存器变量。
它们的赋值表示将当前输入的红色、绿色和蓝色分量值存储在对应的寄存器中。
in_r_1、in_g_1和in_b_1是输入红色分量、绿色分量和蓝色分量的寄存器变量。
它们的赋值表示将当前输入的红色、绿色和蓝色分量值存储在对应的寄存器中。*/

reg signed [BITS:0] in_r_1, in_g_1, in_b_1;

always @ (posedge pclk or negedge rst_n) begin
	if (!rst_n) begin
		in_r_1 <= 0;
		in_g_1 <= 0;
		in_b_1 <= 0;
	end
	else begin
		in_r_1 <= {1'b0, in_r};
		in_g_1 <= {1'b0, in_g};
		in_b_1 <= {1'b0, in_b};
	end
end


//颜色校正矩阵计算的中间结果
reg signed [BITS+8:0] data_rr, data_rg, data_rb;
reg signed [BITS+8:0] data_gr, data_gg, data_gb;
reg signed [BITS+8:0] data_br, data_bg, data_bb;

always @ (posedge pclk or negedge rst_n) begin
	if (!rst_n) begin
		data_rr <= 0;
		data_rg <= 0;
		data_rb <= 0;
		data_gr <= 0;
		data_gg <= 0;
		data_gb <= 0;
		data_br <= 0;
		data_bg <= 0;
		data_bb <= 0;
	end
	else begin
		data_rr <= m_rr * in_r_1;
		data_rg <= m_rg * in_g_1;
		data_rb <= m_rb * in_b_1;
		data_gr <= m_gr * in_r_1;
		data_gg <= m_gg * in_g_1;
		data_gb <= m_gb * in_b_1;
		data_br <= m_br * in_r_1;
		data_bg <= m_bg * in_g_1;
		data_bb <= m_bb * in_b_1;
	end
end

reg signed [BITS+8:0] data_r, data_g, data_b;
always @ (posedge pclk or negedge rst_n) begin
	if (!rst_n) begin
		data_r <= 0;
		data_g <= 0;
		data_b <= 0;
	end
	else begin
		data_r <= (data_rr + data_rg + data_rb) >>> 4;
		data_g <= (data_gr + data_gg + data_gb) >>> 4;
		data_b <= (data_br + data_bg + data_bb) >>> 4;
	end
end


//对data_r_1, data_g_1, data_b_1进行范围限制，确保 data_r_1 的值在 0 到 2^BITS-1 的范围内。
reg [BITS-1:0] data_r_1, data_g_1, data_b_1;
always @ (posedge pclk or negedge rst_n) begin
	if (!rst_n) begin
		data_r_1 <= 0;
		data_g_1 <= 0;
		data_b_1 <= 0;
	end
	else begin
		data_r_1 <= data_r < 8'sd0 ? {BITS{1'b0}} : (data_r > {BITS{1'b1}} ? {BITS{1'b1}} : data_r[BITS-1:0]);
		data_g_1 <= data_g < 8'sd0 ? {BITS{1'b0}} : (data_g > {BITS{1'b1}} ? {BITS{1'b1}} : data_g[BITS-1:0]);
		data_b_1 <= data_b < 8'sd0 ? {BITS{1'b0}} : (data_b > {BITS{1'b1}} ? {BITS{1'b1}} : data_b[BITS-1:0]);
	end
end

//时序延迟，用于延迟输入信号 in_href 和 in_vsync
localparam DLY_CLK = 4;
reg [DLY_CLK-1:0] href_dly;
reg [DLY_CLK-1:0] vsync_dly;
always @ (posedge pclk or negedge rst_n) begin
	if (!rst_n) begin
		href_dly <= 0;
		vsync_dly <= 0;
	end
	else begin
		href_dly <= {href_dly[DLY_CLK-2:0], in_href};
		vsync_dly <= {vsync_dly[DLY_CLK-2:0], in_vsync};
	end
end

	assign out_href = href_dly[DLY_CLK-1];
	assign out_vsync = vsync_dly[DLY_CLK-1];
	assign out_r = out_href ? data_r_1 : {BITS{1'b0}};
	assign out_g = out_href ? data_g_1 : {BITS{1'b0}};
	assign out_b = out_href ? data_b_1 : {BITS{1'b0}};
	
endmodule
