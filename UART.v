
`timescale 1ns/1ns

// UART回环测试顶层模块
module uart_loopback_test (
    input               clk,                // 系统时钟 24MHz
    input               rst_n,              // 复位信号，低电平有效
    
    // UART接口
    input               fpga_rxd,           // 来自PC的UART接收数据
    output              fpga_txd            // 发送到PC的UART发送数据
);

// 时钟分频参数
localparam CLK_FREQ = 24_000_000;           // 系统时钟频率 24MHz
localparam BAUD_RATE = 115200;              // 波特率 115200
localparam DIV_COUNT = CLK_FREQ / BAUD_RATE / 16; // 分频计数 (16倍采样)

// 时钟分频器输出
wire clken_16bps;

// 整数分频器实例
integer_divider #(
    .DEVIDE_CNT(DIV_COUNT)
) u_integer_divider (
    .clk        (clk),
    .rst_n      (rst_n),
    .divide_clken(clken_16bps)
);

// 接收到的数据和标志
wire [7:0] rxd_data;
wire       rxd_flag;

// UART接收器实例
uart_receiver u_uart_receiver (
    .clk          (clk),
    .rst_n        (rst_n),
    .clken_16bps  (clken_16bps),
    .rxd          (fpga_rxd),
    .rxd_data     (rxd_data),
    .rxd_flag     (rxd_flag)
);

// UART发送器实例
uart_transfer u_uart_transfer (
    .clk          (clk),
    .rst_n        (rst_n),
    .clken_16bps  (clken_16bps),
    .txd          (fpga_txd),
    .txd_en       (rxd_flag),         // 接收到数据后立即发送
    .txd_data     (rxd_data),         // 回传接收到的数据
    .txd_flag     ()                  // 不使用发送完成信号
);

endmodule





module uart_receiver
(
	//gobal clock
	input				clk,
	input				rst_n,
	
	//user interface
	input				clken_16bps,//clk_bps * 16
	
	//uart interface
	input				rxd,		//uart txd interface
	output	reg	[7:0]	rxd_data,	//uart data receive
	output	reg			rxd_flag	//uart data receive done 
);


/**************************************************************************
..IDLE...Start...............UART DATA........................End...IDLE...
________													 ______________
        |____< D0 >< D1 >< D2 >< D3 >< D4 >< D5 >< D6 >< D7 >
		Bit0  Bit1  Bit2  Bit3  Bit4  Bit5  Bit6  Bit7  Bit8  Bit9
**************************************************************************/

//---------------------------------
//sync the rxd data: rxd_sync
reg	rxd_sync;				
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		rxd_sync <= 1;
	else
		rxd_sync <= rxd;
end

//---------------------------------------
//parameter of uart transfer
localparam	R_IDLE		=	2'd0;		//detect if the uart data is begin
localparam	R_START		=	2'd1;		//uart transfert start mark bit
localparam	R_SAMPLE	=	2'd2;		//uart 8 bit data receive
localparam	R_STOP		=	2'd3;		//uart transfer stop mark bit
reg	[1:0]	rxd_state;					//uart receive state
reg	[3:0]	rxd_cnt;					//uart 8 bit data counter
reg	[3:0]	smp_cnt;					//16 * clk_bps, the center for sample
localparam	SMP_TOP		=	4'd15;
localparam	SMP_CENTER	=	4'd7;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		smp_cnt <= 0;
		rxd_cnt <= 0;
		rxd_state <= R_IDLE;
		end
	else 
		case(rxd_state)
		R_IDLE:		//Wait for start bit
			begin
			rxd_cnt <= 0;
			smp_cnt <= 0;
			if(rxd_sync == 1'b0)			//uart rxd start bit
				rxd_state <= R_START;
			else
				rxd_state <= R_IDLE;
			end
		R_START:
			begin
			if(clken_16bps == 1)			//clk_bps * 16
				begin
				smp_cnt <= smp_cnt + 1'b1;
				if(smp_cnt == SMP_CENTER && rxd_sync != 1'b0)	//invalid data	
					begin
					rxd_cnt <= 0;
					rxd_state <= R_IDLE;
					end
				else if(smp_cnt == SMP_TOP)	//Count for 16 clocks
					begin
					rxd_cnt <= 1;
					rxd_state <= R_SAMPLE;	//start mark bit is over
					end
				else
					begin
					rxd_cnt <= 0;
					rxd_state <= R_START;	//wait start mark bit over
					end
				end
			else							//invalid data
				begin
				smp_cnt <= smp_cnt;
				rxd_state <= rxd_state;
				end
			end
		R_SAMPLE:	//Sample 8 bit of Uart: {LSB, MSB}
			begin
			if(clken_16bps == 1)			//clk_bps * 16
				begin
				smp_cnt <= smp_cnt + 1'b1;
				if(smp_cnt == SMP_TOP)
					begin
					if(rxd_cnt < 4'd8)		//Totally 8 data
						begin
						rxd_cnt <= rxd_cnt + 1'b1;
						rxd_state <= R_SAMPLE;
						end
					else
						begin
						rxd_cnt <= 4'd9;	//Turn of stop bit
						rxd_state <= R_STOP;
						end
					end
				else
					begin
					rxd_cnt <= rxd_cnt;
					rxd_state <= rxd_state;
					end
				end
			else
				begin
				smp_cnt <= smp_cnt;
				rxd_cnt <= rxd_cnt;
				rxd_state <= rxd_state;
				end
			end
		R_STOP:
			begin
			if(clken_16bps == 1)		//clk_bps * 16
				begin
				smp_cnt <= smp_cnt + 1'b1;
				if(smp_cnt == SMP_TOP)
					begin
					rxd_state <= R_IDLE;
					rxd_cnt <= 0;		//Stop data bit is done
					end
				else
					begin
					rxd_cnt <= 9;		//Stop data bit
					rxd_state <= R_STOP;
					end
				end
			else
				begin
				smp_cnt <= smp_cnt;
				rxd_cnt <= rxd_cnt;
				rxd_state <= rxd_state;
				end
			end
				
		endcase
end

//----------------------------------
//uart data receive in center point
reg	[7:0]	rxd_data_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		rxd_data_r <= 0;
	else if(rxd_state == R_SAMPLE)
		begin
		if(clken_16bps == 1 && smp_cnt == SMP_CENTER)	//sample center point
			case(rxd_cnt)
			4'd1:	rxd_data_r[0] <= rxd_sync;
			4'd2:	rxd_data_r[1] <= rxd_sync;
			4'd3:	rxd_data_r[2] <= rxd_sync;
			4'd4:	rxd_data_r[3] <= rxd_sync;
			4'd5:	rxd_data_r[4] <= rxd_sync;
			4'd6:	rxd_data_r[5] <= rxd_sync;
			4'd7:	rxd_data_r[6] <= rxd_sync;
			4'd8:	rxd_data_r[7] <= rxd_sync;
			default:;
			endcase
		else
			rxd_data_r <= rxd_data_r;
		end
	else if(rxd_state == R_STOP)
		rxd_data_r <= rxd_data_r;
	else
		rxd_data_r <= 0;
end

//----------------------------------
//update uart receive data and receive flag signal
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		rxd_data <= 0;
		rxd_flag <= 0;
		end
	else if(clken_16bps == 1 &&  rxd_cnt == 4'd9 && smp_cnt == SMP_TOP)	//Start + 8 Bit + Stop Bit
		begin
		rxd_data <= rxd_data_r;
		rxd_flag <= 1;
		end
	else
		begin
		rxd_data <= rxd_data;
		rxd_flag <= 0;
		end
end


endmodule


module uart_transfer
(
	//gobal clock
	input				clk,
	input				rst_n,
	
	//uart interface
	input				clken_16bps,//clk_bps * 16
	output	reg			txd,		//uart txd interface
	
	//user interface
	input				txd_en,		//uart data transfer enable
	input		[7:0]	txd_data,	//uart transfer data
	output	reg			txd_flag	//uart data transfer done
);

/**************************************************************************
..IDLE...Start...............UART DATA........................End...IDLE...
________													 ______________
        |____< D0 >< D1 >< D2 >< D3 >< D4 >< D5 >< D6 >< D7 >
		Bit0  Bit1  Bit2  Bit3  Bit4  Bit5  Bit6  Bit7  Bit8  Bit9
**************************************************************************/
//---------------------------------------
//parameter of uart transfer
localparam	T_IDLE	=	2'b0;	//test the flag to transfer data
localparam	T_SEND	=	2'b1;	//uart transfer data
reg	[1:0]	txd_state;			//uart transfer state
reg	[3:0]	smp_cnt;			//16 * clk_bps, the center for sample
reg	[3:0]	txd_cnt;			//txd data counter
localparam	SMP_TOP		=	4'd15;
localparam	SMP_CENTER	=	4'd7;
always@(posedge clk	or negedge rst_n)
begin
	if(!rst_n)
		begin
		smp_cnt <= 0;
		txd_cnt <= 0;	
		txd_state <= T_IDLE;
		end
	else
		begin
		case(txd_state)
		T_IDLE:		
			begin
			smp_cnt <= 0;
			txd_cnt <= 0;
			if(txd_en == 1)
				txd_state <= T_SEND;
			else
				txd_state <= T_IDLE;
			end	
		T_SEND:	
			begin
			if(clken_16bps == 1)
				begin
				smp_cnt <= smp_cnt + 1'b1;
				if(smp_cnt == SMP_TOP)
					begin
					if(txd_cnt < 4'd9)
						begin
						txd_cnt <= txd_cnt + 1'b1;
						txd_state <= T_SEND;
						end
					else
						begin
						txd_cnt <= 0;
						txd_state <= T_IDLE;
						end
					end
				else
					begin
					txd_cnt <= txd_cnt;
					txd_state <= txd_state;
					end
				end	
			else
				begin
				txd_cnt <= txd_cnt;
				txd_state <= txd_state;
				end
			end		
		endcase
		end
end


//--------------------------------------
//uart 8 bit data transfer
always@(*)
begin
	if(txd_state == T_SEND)
		case(txd_cnt)
		4'd0:	txd = 0;
		4'd1:	txd = txd_data[0];
		4'd2:	txd = txd_data[1];
		4'd3:	txd = txd_data[2];
		4'd4:	txd = txd_data[3];
		4'd5:	txd = txd_data[4];
		4'd6:	txd = txd_data[5];
		4'd7:	txd = txd_data[6];
		4'd8:	txd = txd_data[7];
		4'd9:	txd = 1;
		default:txd = 1;
		endcase
	else
		txd = 1'b1;	//default state
end


//-------------------------------------
//Capture the falling of data transfer over
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		txd_flag <= 0;
	else if(clken_16bps == 1 &&  txd_cnt == 4'd9 && smp_cnt == SMP_TOP)	//Totally 8 data is done
		txd_flag <= 1;
	else
		txd_flag <= 0;
end

endmodule

 


module	integer_divider
#(
	parameter		DEVIDE_CNT = 16'd13	//115200bps * 16
)
(
	//global clock
	input			clk,
	input			rst_n,
	
	//user interface
	output			divide_clken
);

//------------------------------------------------------
//RTL1: Precise fractional frequency for uart bps clock 
reg	[31:0]	cnt;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		cnt <= 0;
	else
		cnt <= (cnt < DEVIDE_CNT - 1'b1) ? cnt + 1'b1 : 16'd0;		
end

assign divide_clken = (cnt == DEVIDE_CNT - 1'b1) ? 1'b1 : 1'b0;


endmodule






module	precise_divider
#(
	//DEVIDE_CNT = 42.94967296 * fo
//	parameter		DEVIDE_CNT = 32'd175921860	//256000bps * 16
//	parameter		DEVIDE_CNT = 32'd87960930	//128000bps * 16
//	parameter		DEVIDE_CNT = 32'd79164837	//115200bps * 16
	parameter		DEVIDE_CNT = 32'd6597070	//9600bps * 16
)
(
	//global clock
	input			clk,
	input			rst_n,
	
	//user interface
	output			divide_clk,
	output			divide_clken
);

//------------------------------------------------------
//RTL1: Precise fractional frequency for uart bps clock 
reg	[31:0]	cnt;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		cnt <= 0;
	else
		cnt <= cnt + DEVIDE_CNT;		
end

//------------------------------------------------------
//RTL2: Equal division of the Frequency division clock
reg	cnt_equal;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		cnt_equal <= 0;
	else if(cnt < 32'h7FFF_FFFF)
		cnt_equal <= 0;
	else
		cnt_equal <= 1;
end

//------------------------------------------------------
//RTL3: Generate enable clock for clock
reg	cnt_equal_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		cnt_equal_r <= 0;
	else
		cnt_equal_r <= cnt_equal;
end
assign	divide_clken = (~cnt_equal_r & cnt_equal) ? 1'b1 : 1'b0; 
assign	divide_clk = cnt_equal_r;


endmodule