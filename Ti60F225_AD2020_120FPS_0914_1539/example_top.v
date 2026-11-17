  `timescale 1ns/1ps

//`include "ddr3_controller.vh"


module example_top 
(
	////////////////////////////////////////////////////////////////
	//	External Clock & Reset
	//input 			nrst, 			//	Button K2
	//外部晶振，基础时钟源
	input 			clk_24m,			//	24MHz Crystal
	input 			clk_25m,			//	25MHz Crystal 
	
	
	////////////////////////////////////////////////////////////////
	//	System Clock
	output 			sys_pll_rstn_o, 		//系统PLL复位信号输出，低电平有效
	
	input 			clk_sys,			//	Sys PLL 96MHz 
	input 			clk_pixel,			//	Sys PLL 74.25MHz，像素时钟
	input 			clk_pixel_2x,		//	Sys PLL 148.5MHz
	input 			clk_pixel_10x,		//	Sys PLL 742.5MHz
	
	input 			sys_pll_lock,		//	Sys PLL Lock，锁定状态输入
	
	////////////////////////////////////////////////////////////////
	//	MIPI-DSI Clock & Reset
	output 			dsi_pll_rstn_o,     //DSI PLL复位信号输出，低电平有效
	
	input 			dsi_refclk_i,		//	48MHz Reference Clock (for DSI PLL),参考时钟
	input 			dsi_byteclk_i,		//	DSI Byte Clock (1X)
	input 			dsi_serclk_i,		//	DSI Serial Clock (4X 45)
	input 			dsi_txcclk_i,		//	DSI Serial Clock (4X 135)
	
	input 			dsi_pll_lock,       // DSI PLL锁定状态输入
	
	////////////////////////////////////////////////////////////////
	//	DDR Clock
	output 			ddr_pll_rstn_o,     // DDR PLL复位信号输出(低电平有效)
	
	input 			tdqss_clk,			// DDR相关时钟
	input 			core_clk,			//	DDR PLL 200MHz核心时钟
	input 			tac_clk,			 // DDR相关时钟
	input 			twd_clk,			 // DDR相关时钟
	
	input 			ddr_pll_lock,		//	DDR PLL Lock   DDR PLL锁定状态输入
	
	////////////////////////////////////////////////////////////////
	//	DDR PLL Phase Shift Interface
	output 	[2:0] 	shift,       // 相位调整值输出
	output 	[4:0] 	shift_sel,   // 相位选择信号输出
	output 			shift_ena,    // 相位调整使能输出
	
	
	
	////////////////////////////////////////////////////////////////
	//	LVDS Clock
	output 			lvds_pll_rstn_o,     // LVDS PLL复位信号输出(低电平有效)
	
	input 			clk_lvds_1x,         // LVDS 1倍频时钟
	input 			clk_lvds_7x,         // LVDS 7倍频时钟
	input 			clk_27m, 			//	RGB 1X Clock (16MHz)
	input 			clk_54m, 			//	RGB 2X Clock (32MHz, for export control)
	
	input 			lvds_pll_lock,     // LVDS PLL锁定状态输入
	
	
	
	////////////////////////////////////////////////////////////////
	//	DDR Interface Ports
	output 	[15:0] 	addr,       // DDR地址总线(16位)
	output 	[2:0] 	ba,         // DDR Bank地址(3位)
	output 			we,         // 写使能信号
	output 			reset,       // DDR复位信号
	output 			ras,         // 行地址选通信号
	output 			cas,         // 列地址选通信号
	output 			odt,         // 芯片上拉/下拉终端使能
	output 			cke,         // 时钟使能信号
	output 			cs,          // 芯片选择信号
	
	//	DQ I/O
	input 	[15:0] 	i_dq_hi,    // 高位数据输入(16位)
	input 	[15:0] 	i_dq_lo,    // 低位数据输入(16位)
	
	output 	[15:0] 	o_dq_hi,     // 高位数据输出(16位)
	output 	[15:0] 	o_dq_lo,     // 低位数据输出(16位)
	output 	[15:0] 	o_dq_oe,     // 数据输出使能控制(16位)
	
	//	DM O
	output 	[1:0] 	o_dm_hi,            // 高位数据掩码输出(2位)
    output  [1:0]   o_dm_lo,            // 低位数据掩码输出(2位)
	
	//	DQS I/O  数据选通信号，双向信号，数据同步功能，边沿对齐，差分传输
	input 	[1:0] 	i_dqs_hi,    // 高位DQS时钟输入(2位)
	input 	[1:0] 	i_dqs_lo,     // 低位DQS时钟输入(2位)
	
	input 	[1:0] 	i_dqs_n_hi,    // 高位反相DQS时钟输入(2位)
	input 	[1:0] 	i_dqs_n_lo,    // 低位反相DQS时钟输入(2位)
	
	output 	[1:0] 	o_dqs_hi,    // 高位DQS时钟输出(2位)
	output 	[1:0] 	o_dqs_lo,    // 低位DQS时钟输出(2位)
	
	output 	[1:0] 	o_dqs_n_hi,   // 高位反相DQS时钟输出(2位)
	output 	[1:0] 	o_dqs_n_lo,   // 低位反相DQS时钟输出(2位)
	
	output 	[1:0] 	o_dqs_oe,      // DQS输出使能控制(2位)
	output 	[1:0] 	o_dqs_n_oe,    // 反相DQS输出使能控制(2位)
	
	//	CK
	output 			clk_p_hi,     // 高位时钟正相信号
	output 			clk_p_lo,     // 低位时钟正相信号
	output 			clk_n_hi,     // 高位时钟负相信号
	output 			clk_n_lo,     // 低位时钟负相信号
	
	
	
	////////////////////////////////////////////////////////////////
	//	MIPI-CSI Ctl / I2C
	//MIPI_CSI控制
	output 			csi_ctl0_o,    // CSI控制信号0输出
	output 			csi_ctl0_oe,   // CSI控制信号0输出使能
	input 			csi_ctl0_i,     // CSI控制信号0输入
	
	output 			csi_ctl1_o,     // CSI控制信号1输出
	output 			csi_ctl1_oe,     // CSI控制信号1输出使能
	input 			csi_ctl1_i,      // CSI控制信号1输入

	//I2C接口
	
	output 			csi_scl_o,    // I2C时钟线输出
	output 			csi_scl_oe,   // I2C时钟线输出使能
	input 			csi_scl_i,    // I2C时钟线输入
	
	output 			csi_sda_o,     // I2C数据线输出
	output 			csi_sda_oe,    // I2C数据线输出使能
	input 			csi_sda_i,     // I2C数据线输入
	
	//	MIPI-CSI RXC 
	input 			csi_rxc_lp_p_i,   // RXC低功耗模式正相输入
	input 			csi_rxc_lp_n_i,   // RXC低功耗模式负相输入
	output 			csi_rxc_hs_en_o,  // RXC高速模式使能输出
	output 			csi_rxc_hs_term_en_o,  // RXC高速模式终端使能输出
	input 			csi_rxc_i,     // RXC信号输入
	
	//	MIPI-CSI RXD0   receive data
	output 			csi_rxd0_rst_o,   // RXD0复位输出
	output 			csi_rxd0_hs_en_o, // RXD0高速模式使能输出

	output 			csi_rxd0_hs_term_en_o, // RXD0高速模式使能输出

	
	input 			csi_rxd0_lp_p_i,  // RXD0低功耗模式正相输入
	input 			csi_rxd0_lp_n_i,  // RXD0低功耗模式负相输入
	input 	[7:0] 	csi_rxd0_hs_i,     // RXD0高速模式数据输入(8位)
	
	//	MIPI-CSI RXD1
	output 			csi_rxd1_rst_o,
	output 			csi_rxd1_hs_en_o,
	output 			csi_rxd1_hs_term_en_o,
	
	input 			csi_rxd1_lp_n_i,
	input 			csi_rxd1_lp_p_i,
	input 	[7:0] 	csi_rxd1_hs_i,
	
	//	MIPI-CSI RXD2
	output 			csi_rxd2_rst_o,
	output 			csi_rxd2_hs_en_o,
	output 			csi_rxd2_hs_term_en_o,
	
	input 			csi_rxd2_lp_p_i,
	input 			csi_rxd2_lp_n_i,
	input 	[7:0] 	csi_rxd2_hs_i,
	
	//	MIPI-CSI RXD3
	output 			csi_rxd3_rst_o,
	output 			csi_rxd3_hs_en_o,
	output 			csi_rxd3_hs_term_en_o,
	
	input 			csi_rxd3_lp_p_i,
	input 			csi_rxd3_lp_n_i,
	input 	[7:0] 	csi_rxd3_hs_i,
	
	//output 			csi_rxd0_fifo_rd_o, 
	//input 			csi_rxd0_fifo_empty_i, 
	//output 			csi_rxd1_fifo_rd_o, 
	//input 			csi_rxd1_fifo_empty_i, 
	//output 			csi_rxd2_fifo_rd_o, 
	//input 			csi_rxd2_fifo_empty_i, 
	//output 			csi_rxd3_fifo_rd_o, 
	//input 			csi_rxd3_fifo_empty_i, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	DSI PWM & Reset Control   //正相信号，相位差为0/360，负相信号相位差180
	//pulse with modulation,周期性方波，占空比：高电平持续市场在整个周期里所占的比例
	output 			dsi_pwm_o,			//	MIPI-DSI LCD PWM     用于控制LCD背光亮度
	output 			dsi_resetn_o,		//	MIPI-DSI LCD Reset   DSI LCD面板的复位信号(低电平有效)
	
	//	MIPI-DSI TXC / TXD
	output 			dsi_txc_rst_o,    // DSI时钟通道复位输出
	output 			dsi_txc_lp_p_oe,    //DSI时钟通道低功耗模式正相信号输出使能
	output 			dsi_txc_lp_p_o,   //DSI时钟通道低功耗模式正相信号输出
	output 			dsi_txc_lp_n_oe,  //DSI时钟通道低功耗模式负相信号输出使能

	output 			dsi_txc_lp_n_o,  //DSI时钟通道低功耗模式负相信号输出
	output 			dsi_txc_hs_oe,  // DSI时钟通道高速模式输出使能
	output 	[7:0] 	dsi_txc_hs_o,   // DSI时钟通道高速模式数据输出(8位)
	
	output 			dsi_txd0_rst_o,  //DSI数据通道0复位输出
	output 			dsi_txd0_hs_oe,  //DSI数据通道0高速模式输出使能
	output 	[7:0] 	dsi_txd0_hs_o,   //DSI数据通道0高速模式数据输出(8位)
	output 			dsi_txd0_lp_p_oe,//DSI数据通道0低功耗模式正相信号输出使能

	output 			dsi_txd0_lp_p_o, // DSI数据通道0低功耗模式正相信号输出
	output 			dsi_txd0_lp_n_oe,  //DSI数据通道0低功耗模式负相信号输出使能
	output 			dsi_txd0_lp_n_o,  //DSI数据通道0低功耗模式负相信号输出
	
	output 			dsi_txd1_rst_o,
	output 			dsi_txd1_lp_p_oe,
	output 			dsi_txd1_lp_p_o,
	output 			dsi_txd1_lp_n_oe,
	output 			dsi_txd1_lp_n_o,
	output 			dsi_txd1_hs_oe,
	output 	[7:0] 	dsi_txd1_hs_o,
	
	output 			dsi_txd2_rst_o,
	output 			dsi_txd2_lp_p_oe,
	output 			dsi_txd2_lp_p_o,
	output 			dsi_txd2_lp_n_oe,
	output 			dsi_txd2_lp_n_o,
	output 			dsi_txd2_hs_oe,
	output 	[7:0] 	dsi_txd2_hs_o,
	
	output 			dsi_txd3_rst_o,
	output 			dsi_txd3_lp_p_oe,
	output 			dsi_txd3_lp_p_o,
	output 			dsi_txd3_lp_n_oe,
	output 			dsi_txd3_lp_n_o,
	output 			dsi_txd3_hs_oe,
	output 	[7:0] 	dsi_txd3_hs_o,
	//DSI数据通道低功耗模式输入信号，用于读取LCD面板的反馈信息
	input 			dsi_txd0_lp_p_i,
	input 			dsi_txd0_lp_n_i,
	input 			dsi_txd1_lp_p_i,
	input 			dsi_txd1_lp_n_i,
	input 			dsi_txd2_lp_p_i,
	input 			dsi_txd2_lp_n_i,
	input 			dsi_txd3_lp_p_i,
	input 			dsi_txd3_lp_n_i,
	
	
	////////////////////////////////////////////////////////////////
	//	UART Interface                   460800波特率，8位数据，无校验，1位停止位
	input 		 	uart_rx_i,			//	Support 460800-8-N-1.  UART串口接收输入，支持
	output 		 	uart_tx_o,          //UART串口发送输出
	
	
	output 	[5:0] 	led_o,			//	6位LED输出信号，用于状态指示
	
	
	////////////////////////////////////////////////////////////////
	//	CMOS Sensor  用于接受图像数据
	output 			cmos_sclk,  //CMOS传感器时钟输出
	input 			cmos_sdat_IN,  //CMOS传感器数据输入
	output 			cmos_sdat_OUT,  //CMOS传感器数据输出
	output 			cmos_sdat_OE,  //CMOS传感器数据输出使能
	
	//	CMOS Interface
	input 			cmos_pclk,   // CMOS像素时钟输入
	input 			cmos_vsync,  //CMOS垂直同步信号输入
	input 			cmos_href,  //CMOS行有效信号输入
	input 	[7:0] 	cmos_data,  // CMOS图像数据输入(8位)
	input 			cmos_ctl1,   //CMOS控制信号输入
	output 			cmos_ctl2,   //CMOS控制信号输出
	output 			cmos_ctl3,
	
	
	////////////////////////////////////////////////////////////////
	//	HDMI Interface  用于视频输出
	output 			hdmi_txc_oe,  //HDMI时钟通道输出使能
	output 			hdmi_txd0_oe, //HDMI数据通道0输出使能
	output 			hdmi_txd1_oe,
	output 			hdmi_txd2_oe,
	
	output 			hdmi_txc_rst_o,  //HDMI时钟通道复位输出
	output 			hdmi_txd0_rst_o, //HDMI数据通道0复位输出
	output 			hdmi_txd1_rst_o,
	output 			hdmi_txd2_rst_o,
	
	output 	[9:0] 	hdmi_txc_o,   //HDMI时钟通道输出(10位)
	output 	[9:0] 	hdmi_txd0_o,  //HDMI数据通道0输出(10位)
	output 	[9:0] 	hdmi_txd1_o,
	output 	[9:0] 	hdmi_txd2_o,
	
	
	////////////////////////////////////////////////////////////////
	//	LVDS Interface
	output 			lvds_txc_oe,   //LVDS时钟通道输出使能信号
	output 	[6:0] 	lvds_txc_o,  // LVDS时钟通道输出使能信号(7位)
	output 			lvds_txc_rst_o,  //LVDS时钟通道复位输出信号
	
	output 			lvds_txd0_oe,  //LVDS数据通道0输出使能信号
	output 	[6:0] 	lvds_txd0_o,  //VDS数据通道0数据输出(7位)
	output 			lvds_txd0_rst_o,  //LVDS数据通道0复位输出信号
	
	output 			lvds_txd1_oe,
	output 	[6:0] 	lvds_txd1_o,
	output 			lvds_txd1_rst_o,
	
	output 			lvds_txd2_oe,
	output 	[6:0] 	lvds_txd2_o,
	output 			lvds_txd2_rst_o,
	
	output 			lvds_txd3_oe,
	output 	[6:0] 	lvds_txd3_o,
	output 			lvds_txd3_rst_o,
	
	
	////////////////////////////////////////////////////////////////
	//	RGB LCD 5Inch 800x480
	output 			lcd_tp_sda_o,		//	TP SDA  触摸屏I2C数据线输出
	output 			lcd_tp_sda_oe,      //触摸屏I2C数据线输出使能
	input 			lcd_tp_sda_i,       //触摸屏I2C数据线输入
	
	output 			lcd_tp_scl_o,		//	TP SCL  触摸屏I2C时钟线输出
	output 			lcd_tp_scl_oe,      //触摸屏I2C时钟线输出使能
	input 			lcd_tp_scl_i,       //触摸屏I2C时钟线输入
	
	output 			lcd_tp_int_o,		//	TP INT  触摸屏中断信号输出
	output 			lcd_tp_int_oe,      //触摸屏中断信号输出使能
	input 			lcd_tp_int_i,       //触摸屏中断信号输入
	
	output 			lcd_tp_rst_o,		//	TP RST 触摸屏复位信号输出
	
	output 			lcd_pwm_o,			//	Backlight  LCD背光PWM控制信号输出
	output 			lcd_blen_o,          //LCD背光PWM使能信号
	
	//output 			lcd_pclk_o,			//	PCLK & SCK Mux
	output 			lcd_vs_o,			//	LCD垂直同步信号输出 VS & SSN Mux. Fixed to 1. Use DE-Only mode. 
	output 			lcd_hs_o,			//	LCD水平同步信号输出 HS. Fixed to 1. Use DE-Only mode. 
	output 			lcd_de_o,			//	LCD数据使能信号输出  DE. 

	output 	[7:0] 	lcd_b7_0_o,			//	 LCD蓝色数据输出(8位) B7:B0. 
	output 	[7:0] 	lcd_g7_0_o,			//	 LCD绿色数据输出(8位) G7:G0. Must output 8'hFF when access SPI. 
	output 	[7:0] 	lcd_r7_0_o,			//	LCD红色数据输出(8位) R7:R0. 
	
	output 	[7:0] 	lcd_b7_0_oe,		//	LCD蓝色数据输出使能(8位) B7:B0. 
	output 	[7:0] 	lcd_g7_0_oe,		//	LCD绿色数据输出使能(8位) G7:G0. Must output 8'hFF when access SPI. 
	output 	[7:0] 	lcd_r7_0_oe,		//	LCD红色数据输出使能(8位) R7:R0. 

	input 	[7:0] 	lcd_b7_0_i,			//	LCD蓝色数据输入(8位) B7:B0. 
	input 	[7:0] 	lcd_g7_0_i,			//	LCD绿色数据输入(8位) G7:G0. Must output 8'hFF when access SPI. 
	input 	[7:0] 	lcd_r7_0_i,			//	LCD红色数据输入(8位) R7:R0. 
	
	//	SPI Pins
	output 			spi_sck_o,    // SPI时钟信号输出
	output 			spi_ssn_o 	  //SPI片选信号输出
);
	//用于CSI接收器的FIFO控制
	wire 			csi_rxd0_fifo_rd_o; 
	wire 			csi_rxd0_fifo_empty_i = 0;  
	wire 			csi_rxd1_fifo_rd_o;  
	wire 			csi_rxd1_fifo_empty_i = 0;  
	wire 			csi_rxd2_fifo_rd_o;  
	wire 			csi_rxd2_fifo_empty_i = 0;  
	wire 			csi_rxd3_fifo_rd_o;  
	wire 			csi_rxd3_fifo_empty_i = 0;  
	
	
	parameter 	SIM_DATA 	= 0;  //仿真数据参数
	
	//	Hardware Configuration  用于配置DDR3存储器的时钟信号，实现180度相位偏移
	assign clk_p_hi = 1'b0;	//	DDR3 Clock requires 180 degree shifted. 
	assign clk_p_lo = 1'b1; //DDR3时钟正相信号的高/低电平
	assign clk_n_hi = 1'b1;
	assign clk_n_lo = 1'b0; //DDR3时钟负相信号的高/低电平
	
	//	System Clock Tree Control
	assign sys_pll_rstn_o = 1'b1; 	//	nrst; 	//	Reset whole system when nrst (K2) is pressed. 
	     //系统PLL复位信号输出，当前硬连接为高电平(非复位状态)
	assign dsi_pll_rstn_o = sys_pll_lock; //DSI PLL复位信号，与系统PLL锁定状态同步
	assign ddr_pll_rstn_o = sys_pll_lock; //DDR PLL复位信号，与系统PLL锁定状态同步
	assign lvds_pll_rstn_o = sys_pll_lock; //LVDS PLL复位信号，与系统PLL锁定状态同步
	
	wire 			w_pll_lock = sys_pll_lock && dsi_pll_lock && ddr_pll_lock && lvds_pll_lock; 
	//所有PLL锁定状态的组合信号，只有当所有PLL都锁定时才为高电平
	//	Synchronize System Resets.  rstn_*表示复位信号的非反相信号(低电平有效)     rst_*表示复位信号的反相信号(高电平有效)
	reg 			rstn_sys = 0, rstn_pixel = 0; 
	wire 			rst_sys = ~rstn_sys, rst_pixel = ~rstn_pixel; 
	
	reg 			rstn_dsi_refclk = 0, rstn_dsi_byteclk = 0; 
	wire 			rst_dsi_refclk = ~rstn_dsi_refclk, rst_dsi_byteclk = ~rstn_dsi_byteclk; 
	
	reg 			rstn_lvds_1x = 0; 
	wire 			rst_lvds_1x = ~rstn_lvds_1x; 
	
	reg 			rstn_27m = 0, rstn_54m = 0; 
	wire 			rst_27m = ~rstn_27m, rst_54m = ~rstn_54m; 
	
	//	Clock Gen  当对应的PLL未锁定时，相应的复位信号被置为复位状态(0) 当PLL锁定时，复位信号被释放(置为1)
	always @(posedge clk_27m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_27m <= 0; else rstn_27m <= 1; end
	always @(posedge clk_54m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_54m <= 0; else rstn_54m <= 1; end
	always @(posedge clk_sys or negedge w_pll_lock) begin if(~w_pll_lock) rstn_sys <= 0; else rstn_sys <= 1; end
	always @(posedge clk_pixel or negedge w_pll_lock) begin if(~w_pll_lock) rstn_pixel <= 0; else rstn_pixel <= 1; end
	always @(posedge dsi_refclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_refclk <= 0; else rstn_dsi_refclk <= 1; end
	always @(posedge dsi_byteclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_byteclk <= 0; else rstn_dsi_byteclk <= 1; end
	always @(posedge clk_lvds_1x or negedge w_pll_lock) begin if(~w_pll_lock) rstn_lvds_1x <= 0; else rstn_lvds_1x <= 1; end
	
	
	localparam 	CLOCK_MAIN 	= 96000000; 	//	System clock using 96MHz.  定义主系统时钟频率为96MHz
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	Flash Burner Control
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	wire 			w_ustick, w_mstick;   //微秒和毫秒时钟信号
	
	wire  [7:0] 	w_dev_index_o;  //设备控制接口信号(索引、命令、数据、有效信号等)
	wire  [7:0] 	w_dev_cmd_o;  
	wire  [31:0] 	w_dev_wdata_o;  
	wire  		w_dev_wvalid_o;  
	wire  		w_dev_rvalid_o;  
	wire 	[31:0] 	w_dev_rdata_i;  
	
	wire 			w_spi_ssn_o, w_spi_sck_o;  //SPI接口信号(片选、时钟、数据输入/输出/输出使能)
	wire 	[3:0] 	w_spi_data_o, w_spi_data_oe; 
	wire 	[3:0] 	w_spi_data_i; 
	
	//	Flash Control
	reg 	r_flash_en = 0; //	0x00:0x00 Enable Flash   Flash使能寄存器，初始值为0(禁用)
	
	always @(posedge clk_sys) begin
		r_flash_en <= (w_dev_wvalid_o && (w_dev_index_o == 8'h00) && (w_dev_cmd_o == 8'h00)) ? w_dev_wdata_o : r_flash_en; 
	end
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	LCD Data Mux
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	wire 	[7:0] 	w_lcd_b_o, w_lcd_g_o, w_lcd_r_o; 
	 //Flash使能寄存器，初始值为0(禁用)
	assign lcd_b7_0_o = r_flash_en ? {4'b0, w_spi_data_o[3:2], 2'b0} : w_lcd_b_o; 
	assign lcd_g7_0_o = r_flash_en ? {6'h0, w_spi_data_o[1:0]} : w_lcd_g_o; 
	assign lcd_r7_0_o = r_flash_en ? {8'h00} : w_lcd_r_o; 
	
	assign lcd_b7_0_oe = r_flash_en ? {4'b0, w_spi_data_oe[3:2], 2'b0} : 8'hFF; 
	assign lcd_g7_0_oe = r_flash_en ? {6'h0, w_spi_data_oe[1:0]} : 8'hFF; 
	assign lcd_r7_0_oe = r_flash_en ? {8'h00} : 8'hFF; 
	
	assign spi_sck_o = w_spi_sck_o; 
	assign spi_ssn_o = w_spi_ssn_o; 
	assign w_spi_data_i = {lcd_b7_0_i[3:2], lcd_g7_0_i[1:0]}; 
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	DDR3 Controller
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	wire			w_ddr3_ui_clk = clk_sys;  //DDR3用户接口时钟，连接到系统时钟(96MHz)
	wire			w_ddr3_ui_rst = rst_sys;  // DDR3用户接口复位信号(高电平有效)
	wire			w_ddr3_ui_areset = rst_sys;// DDR3用户接口异步复位信号(高电平有效)
	wire			w_ddr3_ui_aresetn = rstn_sys;//DDR3用户接口异步复位信号(低电平有效)
	

	//	General AXI Interface 
	wire	[3:0] 	w_ddr3_awid;  //写地址ID标识符
	wire	[31:0]	w_ddr3_awaddr;  //写地址
	wire	[7:0]		w_ddr3_awlen;//突发传输长度
	wire			w_ddr3_awvalid;// 写地址有效信号
	wire			w_ddr3_awready;// 写地址准备好信号
	
	wire 	[3:0]  	w_ddr3_wid;   //写数据ID标识符
	wire 	[127:0] 	w_ddr3_wdata;  //写数据(128位)
	wire 	[15:0]	w_ddr3_wstrb;  //写数据选通信号(字节使能)
	wire			w_ddr3_wlast; //写数据最后传输标志
	wire			w_ddr3_wvalid; //写数据有效信号
	wire			w_ddr3_wready; //写数据准备好信号
	
	wire 	[3:0] 	w_ddr3_bid;  // 响应ID标识符
	wire 	[1:0] 	w_ddr3_bresp; //写响应状态
	wire			w_ddr3_bvalid;//响应有效信号
	wire			w_ddr3_bready;//响应准备好信号
	
	wire	[3:0] 	w_ddr3_arid;  //读地址ID标识符
	wire	[31:0]	w_ddr3_araddr;// 读地址
	wire	[7:0]		w_ddr3_arlen;//突发传输长度
	wire			w_ddr3_arvalid;//读地址有效信号
	wire			w_ddr3_arready;//读地址准备好信号
	
	wire 	[3:0] 	w_ddr3_rid;//读数据ID标识符
	wire 	[127:0] 	w_ddr3_rdata;//读数据(128位)
	wire			w_ddr3_rlast;//读数据最后传输标志
	wire			w_ddr3_rvalid;//读数据有效信号
	wire			w_ddr3_rready;//读数据准备好信号
	wire 	[1:0] 	w_ddr3_rresp;//读响应状态
	
	
	//	AXI Interface Request
	wire 	[3:0] 	w_ddr3_aid;//AXI请求ID标识符
	wire 	[31:0] 	w_ddr3_aaddr;//AXI请求地址
	wire 	[7:0]  	w_ddr3_alen;//请求长度
	wire 	[2:0]  	w_ddr3_asize;//请求大小（传输宽度）
	wire 	[1:0]  	w_ddr3_aburst;//突发类型
	wire 	[1:0]  	w_ddr3_alock;//锁定类型
	wire			w_ddr3_avalid;//请求有效信号
	wire			w_ddr3_aready;//请求准备好信号
	wire			w_ddr3_atype;//请求类型(读或写)
	
	wire 			w_ddr3_cal_done, w_ddr3_cal_pass; //DDR3初始化校准完成信号//DDR3初始化校准通过信号
	
	//	Do not issue DDR read / write when ~cal_done. 
	reg 			r_ddr_unlock = 0; //DDR3解锁寄存器，初始值为0(锁定状态)
	always @(posedge w_ddr3_ui_clk or negedge w_ddr3_ui_aresetn) begin
		if(~w_ddr3_ui_aresetn)
			r_ddr_unlock <= 0; 
		else
			r_ddr_unlock <= w_ddr3_cal_done; 
	end
	
	DdrCtrl ddr3_ctl_axi (	
		.core_clk		(core_clk),
		.tac_clk		(tac_clk),
		.twd_clk		(twd_clk),	
		.tdqss_clk		(tdqss_clk),
		
		.reset		(reset),
		.cs			(cs),
		.ras			(ras),
		.cas			(cas),
		.we			(we),
		.cke			(cke),    
		.addr			(addr),
		.ba			(ba),
		.odt			(odt),
		
		.o_dm_hi		(o_dm_hi),
		.o_dm_lo		(o_dm_lo),
		
		.i_dq_hi		(i_dq_hi),
		.i_dq_lo		(i_dq_lo),
		.o_dq_hi		(o_dq_hi),
		.o_dq_lo		(o_dq_lo),
		.o_dq_oe		(o_dq_oe),
		
		.i_dqs_hi		(i_dqs_hi),
		.i_dqs_lo		(i_dqs_lo),
		.i_dqs_n_hi		(i_dqs_n_hi),
		.i_dqs_n_lo		(i_dqs_n_lo),
		.o_dqs_hi		(o_dqs_hi),
		.o_dqs_lo		(o_dqs_lo),
		.o_dqs_n_hi		(o_dqs_n_hi),
		.o_dqs_n_lo		(o_dqs_n_lo),
		.o_dqs_oe		(o_dqs_oe),
		.o_dqs_n_oe		(o_dqs_n_oe),
		
		.clk			(w_ddr3_ui_clk),
		.reset_n		(w_ddr3_ui_aresetn),
		
		.axi_avalid		(w_ddr3_avalid && r_ddr_unlock),	//	Enable command only when unlocked. 
		.axi_aready		(w_ddr3_aready),
		.axi_aaddr		(w_ddr3_aaddr),
		.axi_aid		(w_ddr3_aid),
		.axi_alen		(w_ddr3_alen),
		.axi_asize		(w_ddr3_asize),
		.axi_aburst		(w_ddr3_aburst),
		.axi_alock		(w_ddr3_alock),
		.axi_atype		(w_ddr3_atype),
		
		.axi_wid		(w_ddr3_wid),
		.axi_wvalid		(w_ddr3_wvalid),
		.axi_wready		(w_ddr3_wready),
		.axi_wdata		(w_ddr3_wdata),
		.axi_wstrb		(w_ddr3_wstrb),
		.axi_wlast		(w_ddr3_wlast),
		
		.axi_bvalid		(w_ddr3_bvalid),
		.axi_bready		(w_ddr3_bready),
		.axi_bid		(w_ddr3_bid),
		.axi_bresp		(w_ddr3_bresp),
		
		.axi_rvalid		(w_ddr3_rvalid),
		.axi_rready		(w_ddr3_rready),
		.axi_rdata		(w_ddr3_rdata),
		.axi_rid		(w_ddr3_rid),
		.axi_rresp		(w_ddr3_rresp),
		.axi_rlast		(w_ddr3_rlast),
		
		.shift		(shift),
		.shift_sel		(),
		.shift_ena		(shift_ena),
		
		.cal_ena		(1'b1),
		.cal_done		(w_ddr3_cal_done),
		.cal_pass		(w_ddr3_cal_pass)
	);
	
	assign w_ddr3_bready = 1'b1; // 始终准备好接收写响应
	assign shift_sel = 5'b00100; 		//	ddr_tac_clk always use PLLOUT[2]. DDR PLL相位选择信号，固定使用PLLOUT[2]
	
	
	AXI4_AWARMux #(.AID_LEN(4), .AADDR_LEN(32)) axi4_awar_mux (
		.aclk_i			(w_ddr3_ui_clk), 
		.arst_i			(w_ddr3_ui_rst), 
		
		.awid_i			(w_ddr3_awid),
		.awaddr_i			(w_ddr3_awaddr),
		.awlen_i			(w_ddr3_awlen),
		.awvalid_i			(w_ddr3_awvalid),
		.awready_o			(w_ddr3_awready),
		
		.arid_i			(w_ddr3_arid),
		.araddr_i			(w_ddr3_araddr),
		.arlen_i			(w_ddr3_arlen),
		.arvalid_i			(w_ddr3_arvalid),
		.arready_o			(w_ddr3_arready),
		
		.aid_o			(w_ddr3_aid),
		.aaddr_o			(w_ddr3_aaddr),
		.alen_o			(w_ddr3_alen),
		.atype_o			(w_ddr3_atype),
		.avalid_o			(w_ddr3_avalid),
		.aready_i			(w_ddr3_aready)
	);
	
	assign w_ddr3_asize = 4; 		//	Fixed 128 bits (16 bytes, size = 4)
	assign w_ddr3_aburst = 1;      //突发类型设置
	assign w_ddr3_alock = 0;       //锁定类型设置
	
	//assign led_o[1:0] = {w_ddr3_cal_pass, w_ddr3_cal_done}; 
	
	
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	I2C Config (SC130GS)
	
	//  i2c timing controller module of 16Bit
	wire            [ 7:0]          sc130_i2c_config_index;// I2C配置寄存器索引
	wire            [23:0]          sc130_i2c_config_data;//I2C配置数据
	wire            [ 7:0]          sc130_i2c_config_size;//I2C配置数据大小
	wire                            sc130_i2c_config_done;//I2C配置完成标志
	//端口连接：时钟和复位：使用系统时钟和复位 I2C接口：连接到CSI的SCL和SDA信号 配置数据：连接配置索引、数据、大小和完成信号
	i2c_timing_ctrl_16bit
	#(
	    .CLK_FREQ           (CLOCK_MAIN),                              //  100 MHz
	    .I2C_FREQ           (10_000    )                               //  10 KHz(<= 400KHz)
	) u_i2c_timing_ctrl_16bit (
	    //  global clock
	    .clk                (clk_sys                 ),                          //  96MHz
	    .rst_n              (rstn_sys                ),                          //  system reset

	    //  i2c interface
	    .i2c_sclk           (csi_scl_o               ),                          //  i2c clock
	    .i2c_sdat_IN        (csi_sda_i               ),
	    .i2c_sdat_OUT       (csi_sda_o               ),
	    .i2c_sdat_OE        (csi_sda_oe              ),

	    //  i2c config data
	    .i2c_config_index   (sc130_i2c_config_index        ),                          //  i2c config reg index, read 2 reg and write xx reg
	    .i2c_config_data    ({8'h6a, sc130_i2c_config_data}),                     //  i2c config data
	    .i2c_config_size    (sc130_i2c_config_size         ),                          //  i2c config data counte
	    .i2c_config_done    (sc130_i2c_config_done         ),                          //  i2c config timing complete


		.config_clk                        (w_csi_rx_clk                ),
		.config_data                       (config_data               ),
		.config_data_valid                 (config_data_valid         ) 
	
		);
	assign csi_scl_oe = 1; 

	//  I2C Configure Data of SC130GS
	I2C_AD2020_1280960_FPS60_1Lane_Config u_I2C_AD2020_1280960_FPS60_1Lane_Config 
	(
	    .LUT_INDEX  (sc130_i2c_config_index   ),
	    .LUT_DATA   (sc130_i2c_config_data    ),
	    .LUT_SIZE   (sc130_i2c_config_size    )
	);
	
//I2C配置数据模块实例化，为SC130GS传感器提供查找表配置数据

	
	//	Output LED
	reg 	[3:0]		r_cmos_fv_o = 0; // CMOS帧有效计数器
	reg 	[1:0] 	r_cmos_rx_vsync0_in = 0; //检测CMOS vsync信号的上升沿来计数帧数
	always @(posedge cmos_pclk) begin
		r_cmos_rx_vsync0_in <= {r_cmos_rx_vsync0_in, cmos_vsync}; 
		r_cmos_fv_o <= r_cmos_fv_o + ((r_cmos_rx_vsync0_in == 2'b01) ? 1 : 0); 
	end
	// assign led_o[5] = r_cmos_fv_o[3]; 
	assign led_o[5] = csi_rxc_i;//led_o[5]连接到CSI接收时钟信号，用于指示CSI时钟活动
	
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	System Control. Can be removed for public. 
	
	localparam 	CLK_FREQ 	= 96_000_000; 	//	clk_sys is 96MHz.系统时钟频率96MHz
	localparam 	BAUD_RATE 	= 460_800; 		//	Use 460800-8-N-1. UART波特率460800
	
	
	//	SFR I/O Interface
	wire 	[7:0] 	w_sfr_addr_o; 	// SFR地址	SFR Address (0xFF00 ~ 0xFFFF). 00:Power; 40~5F:Stream0; 60~7F:Stream1. 
	wire 	[7:0] 	w_sfr_wdata_o; 	//SFR写数据 	SFR Write Data. 
	wire 			w_sfr_we_o; 		//SFR写使能	SFR WE. 
	reg 	[7:0] 	w_sfr_rdata_i; 	//SFR读数据	Must be valid after sfr_rd_o. 
	wire 			w_sfr_rd_o; 		//SFR读使能	SFR RD. 
	
	
	//	System Control Registers
	reg 			r_dsi_tx_rstn = 0; 	// DSI发送器复位信号	DSI TX Reset
	reg 	[7:0] 	r_dsi_pwm = 64; 		// DSI PWM控制值([6:0]为PWM值，[7]为极性)	[6:0]PWM, [7]Pol
	reg 			r_dsi_resetn_o = 0; 	//DSI面板复位信号	DSI Panel Reset
	reg 			r_dsi_data_rstn = 0; 	//DSI数据复位信号	DSI TX Reset
	
	reg 	[3:0] 	r_dsi_lp_p_ovr = 0; 	//DSI低功耗模式覆盖控制
	reg 	[3:0] 	r_dsi_lp_n_ovr = 0; 	
	
	
	
	//	AXI-Lite Interface Bridge   AXI接口选择标识
	localparam 	CSI_AXILITE_ID 	= 0; 				//	Select DSI_TX when r_axi_sel = DSI_AXILITE_ID. 
	localparam 	DSI_AXILITE_ID 	= 1; 				//	Select DSI_TX when r_axi_sel = DSI_AXILITE_ID. 
	
	reg 	[7:0] 	r_axi_addr = 8'h18; 		// AXI地址寄存器	0xE0 (RW)
	reg 	[31:0] 	r_axi_wdata = 32'h0000000A; 	//AXI写数据寄存器	0xE1~0xE4 (RW)
	wire 	[31:0] 	w_axi_rdata; 			// AXI读数据信号	0xE5~0xE8 (RO)
	reg 	[0:0] 	r_axi_sel = 1; 			//AXI选择寄存器	0xE9[7:2] (RW)
	reg 			r_axi_r1w0 = 0; 			// 读/写选择	0xE9[1] (RW)
	reg 			r_axi_req = 0; 			//AXI请求信号	0xE9[0] (WO, Single Cycle)
	reg 			r_axi_req_o = 0; 			//延迟的AXI请求信号	Delayed of r_axi_req. 
	
	
	//	Buffered AXI Read Data
	reg 	[31:0] 	r_axi_rdata = 0; 		// 缓冲的AXI读数据	Use state machine
	reg 			r_axi_idle = 0; 		//AXI空闲状态	AXI Idle 
	
	reg 	[3:0] 	rs_axilite = 0; 		//AXI访问状态机	AXI Access
	wire 	[3:0] 	ws_axilite_idle = 0; 	//定义	
	wire 	[3:0] 	ws_axilite_write = 1; 
	wire 	[3:0] 	ws_axilite_read = 2; 
	wire 	[3:0] 	ws_axilite_endread = 3; 
	
	reg 			r_axi_awvalid = 0, r_axi_wvalid = 0, r_axi_arvalid = 0; 
	wire 			w_axi_awready, w_axi_wready, w_axi_arready, w_axi_rvalid; 
	
	
	reg 	[3:0] 	rc_axi_init = 0; 

	always @(posedge clk_sys or posedge rst_sys) begin
		if(rst_sys) begin//复位时清零所有控制寄存器  
			r_dsi_tx_rstn <= 0; 
			r_dsi_pwm <= 64; 
			r_axi_req <= 0; 
			r_dsi_resetn_o <= 0; 
			r_dsi_data_rstn <= 0; 
			
			rs_axilite <= 0; 
			r_axi_awvalid <= 0; 
			r_axi_wvalid <= 0;
			r_axi_arvalid <= 0; 
			
			r_dsi_lp_p_ovr <= 0; 
			r_dsi_lp_n_ovr <= 0; 
			
			rc_axi_init <= 0; 
			r_axi_idle <= 0; 
			
		end else begin//复位释放后使能DSI相关复位信号
			r_dsi_tx_rstn <= 1; 
			r_dsi_resetn_o <= 1; 
			r_dsi_data_rstn <= 1; 
			
		end
	end
	
	assign dsi_resetn_o = r_dsi_resetn_o; // DSI复位输出信号
	
	assign csi_ctl0_oe = 0; //禁用CSI控制信号输出使能
	assign csi_ctl1_oe = 0; 
	
//PWM实例化
	PWMLite dsi_pwm (		//	#(.ENABLE_TICK(0), .PWM_BITS(7)) 
		.clk_i			(clk_sys),
		.rst_i			(rst_sys),
		.pwm_i			(r_dsi_pwm[6:0]),
		.pol_i			(r_dsi_pwm[7]), 
		.pwm_o			(dsi_pwm_o)
	);






	////////////////////////////////////////////////////////////////
	//	MIPI CSI RX  //FIFO和数据处理信号
	wire                                    empty_o;//FIFO空状态信号
wire                                    wr_en                      ;//写使能信号
wire                   [  31:0]         wr_data                    ;//写入FIFO的数据(32位)
wire                   [   7:0]         rd_data                    ;// 从FIFO读取的数据(8位)
wire                                    prepare_vsync              ;//处理后的垂直同步信号
wire                                    prepare_valid              ;//处理后的数据有效信号
wire                   [   7:0]         prepare_data               ;//处理后的图像数据
wire                   [  10:0]         rd_count                   ;//FIFO读计数
reg                                     rd_en                      ;//FIFO读使能信号
reg                    [  10:0]         pixel_cnt                  ;//像素计数器
	
	//	The CSI RXC shall not be inverted. Data can be inverted with swapped LP data and flipped HS data. 
	// localparam 	CSI_RXD_INV 	= 4'b1111; 
	// localparam 	CSI_RXD_INV 	= 4'b0000; 
	localparam 	CSI_RXD_INV 	= 4'b0000; //CSI数据通道反相控制(4位)，当前设置为不反相
	// localparam 	CSI_RXD_INV 	= 4'b0001; 
	localparam 	CSI_DATA_WIDTH 	= 8; 	// CSI数据宽度，设置为8位		
	localparam 	CSI_STRB_WIDTH 	= CSI_DATA_WIDTH / 8; //CSI数据选通宽度

	//	Current implementation supports RAW8 only. 
	wire 			w_csi_rx_clk; //CSI接收器时钟

	wire 			w_csi_rx_vsync0, w_csi_rx_hsync0, w_csi_rx_dvalid; //CSI垂直同步信号  CSI水平同步信号  CSI数据有效信号
	wire 	[63:0] 	w_csi_rx_data;   //CSI接收的原始数据(64位)
	wire 	[47:0] 	w_csi_rx_data_rel_raw;   // CSI接收的原始数据(48位)
	
	//	AXI Interface
	wire 	[31:0] 	w_csi_axi_rdata;   // AXI读数据
	wire 			w_csi_axi_awready, w_csi_axi_wready, w_csi_axi_arready, w_csi_axi_rvalid; 
	
	// AXI写地址准备好   AXI写数据准备好  AXI读地址准备好  AXI读数据有效
	
	
	
	wire [7:0] data_typer;   //数据类型信号  检测到vsync下降沿后，延迟16个周期才使能像素数据
	//	Reset pixel 16 cycles after ~vsync. 
	reg 			r_reset_pixen_n = 0;    //像素使能复位信号
	reg 	[1:0] 	r_csi_rx_vsync0_i = 0;  //vsync信号寄存器
	reg 	[3:0] 	rc_csi_rx_vsync0_f = 0; //vsync滤波计数器
	always @(posedge w_csi_rx_clk or negedge rstn_sys) begin
		if(~rstn_sys) begin
			r_reset_pixen_n <= 0; 
			r_csi_rx_vsync0_i <= 0; 
			rc_csi_rx_vsync0_f <= 0; 
		end else begin
			r_csi_rx_vsync0_i <= {r_csi_rx_vsync0_i, w_csi_rx_vsync0}; 
			if(r_csi_rx_vsync0_i == 2'b10) 
				rc_csi_rx_vsync0_f <= 1; 
			else
				rc_csi_rx_vsync0_f <= rc_csi_rx_vsync0_f + (|rc_csi_rx_vsync0_f); 
			r_reset_pixen_n <= (&rc_csi_rx_vsync0_f) ? 0 : 1; 
		end
	end

	// `define PRI_IP
	`ifdef PRI_IP
	wire 	[7:0] 	w_mipi_d0 = (CSI_RXD_INV[0] ? 8'hFF : 8'h00) ^ csi_rxd0_hs_i; 
	wire 	[7:0] 	w_mipi_d1 = (CSI_RXD_INV[1] ? 8'hFF : 8'h00) ^ csi_rxd1_hs_i; 
	wire 	[7:0] 	w_mipi_d2 = (CSI_RXD_INV[2] ? 8'hFF : 8'h00) ^ csi_rxd2_hs_i; 
	wire 	[7:0] 	w_mipi_d3 = (CSI_RXD_INV[3] ? 8'hFF : 8'h00) ^ csi_rxd3_hs_i; 
	MIPIRx1LaneFre mipi0_rx (
		.sclk_i			(clk_sys), 
		.srst_i			(rst_sys), 
		
		.mipi_rx_byteclk_i	(csi_rxc_i), 
		.mipi_rx_d0_i		({w_mipi_d0[0], w_mipi_d0[1], w_mipi_d0[2], w_mipi_d0[3], w_mipi_d0[4], w_mipi_d0[5], w_mipi_d0[6], w_mipi_d0[7]}), 
		.mipi_rx_d1_i		({w_mipi_d1[0], w_mipi_d1[1], w_mipi_d1[2], w_mipi_d1[3], w_mipi_d1[4], w_mipi_d1[5], w_mipi_d1[6], w_mipi_d1[7]}), 
		.mipi_rx_d2_i		({w_mipi_d2[0], w_mipi_d2[1], w_mipi_d2[2], w_mipi_d2[3], w_mipi_d2[4], w_mipi_d2[5], w_mipi_d2[6], w_mipi_d2[7]}), 
		.mipi_rx_d3_i		({w_mipi_d3[0], w_mipi_d3[1], w_mipi_d3[2], w_mipi_d3[3], w_mipi_d3[4], w_mipi_d3[5], w_mipi_d3[6], w_mipi_d3[7]}), 
		.mipi_rx_clk_lp_p_i	(csi_rxc_lp_p_i), 
		.mipi_rx_clk_lp_n_i	(csi_rxc_lp_n_i), 
		.mipi_rx_d0_lp_p_i	(CSI_RXD_INV[0] ? csi_rxd0_lp_n_i : csi_rxd0_lp_p_i), 
		.mipi_rx_d0_lp_n_i	(CSI_RXD_INV[0] ? csi_rxd0_lp_p_i : csi_rxd0_lp_n_i), 
		.mipi_rx_rst_o		(), 
		.mipi_rx_rst_n_o		(), 
		.mipi_rx_clk_hs_en_o	(csi_rxc_hs_en_o), 
		.mipi_rx_dat_hs_en_o	(csi_rxd0_hs_en_o), 
		.mipi_rx_clk_term_en_o	(csi_rxc_hs_term_en_o), 
		.mipi_rx_dat_term_en_o	(csi_rxd0_hs_term_en_o), 
		
		.CLK				(w_csi_rx_clk), 
		.VSYNC			(w_csi_rx_vsync0), 
		.HSYNC			(w_csi_rx_hsync0), 
		.DE				(w_csi_rx_dvalid), 
		.DAT				(w_csi_rx_data_rel_raw)
	);
	assign w_csi_rx_data = {2{w_csi_rx_data_rel_raw[47:40], w_csi_rx_data_rel_raw[35:28], w_csi_rx_data_rel_raw[23:16], w_csi_rx_data_rel_raw[11:4]}}; 
	assign {csi_rxd3_hs_en_o, csi_rxd2_hs_en_o, csi_rxd1_hs_en_o} = {3{csi_rxd0_hs_en_o}}; 
	assign {csi_rxd3_hs_term_en_o, csi_rxd2_hs_term_en_o, csi_rxd1_hs_term_en_o} = {3{csi_rxd0_hs_term_en_o}}; 
assign wr_data = {w_csi_rx_data_rel_raw[39:32], w_csi_rx_data_rel_raw[29:22],w_csi_rx_data_rel_raw[19:12], w_csi_rx_data_rel_raw[9:2]} ;

`else
	
	assign w_csi_rx_clk = clk_sys; //使用系统时钟作为CSI接收时钟
    csi_rx mipi_rx_0(//复位和时钟信号
    .reset_n                           (rstn_sys                  ),
    .clk                               (w_csi_rx_clk              ),
    .reset_byte_HS_n                   (rstn_sys                  ),
    .clk_byte_HS                       (csi_rxc_i                 ),
    .reset_pixel_n                     (r_reset_pixen_n           ),//rstn_sys), 
    .clk_pixel                         (w_csi_rx_clk              ),
    // .Rx_LP_CLK_P                       (    csi_rxc_lp_n_i        ),
    // .Rx_LP_CLK_N                       (    csi_rxc_lp_p_i        ),
    .Rx_LP_CLK_P                       (csi_rxc_lp_p_i         ),
    .Rx_LP_CLK_N                       (csi_rxc_lp_n_i         ),
   //低功耗和高速模式信号
    .Rx_HS_enable_C                    (csi_rxc_hs_en_o           ),
    .LVDS_termen_C                     (csi_rxc_hs_term_en_o      ),
		
		//	Lane inversion affects HS & LP data only.  数据通道信号(支持反相)
    .Rx_LP_D_P                         ({CSI_RXD_INV[3] ? csi_rxd3_lp_n_i : csi_rxd3_lp_p_i, CSI_RXD_INV[2] ? csi_rxd2_lp_n_i : csi_rxd2_lp_p_i, CSI_RXD_INV[1] ? csi_rxd1_lp_n_i : csi_rxd1_lp_p_i, CSI_RXD_INV[0] ? csi_rxd0_lp_n_i : csi_rxd0_lp_p_i}),
    .Rx_LP_D_N                         ({CSI_RXD_INV[3] ? csi_rxd3_lp_p_i : csi_rxd3_lp_n_i, CSI_RXD_INV[2] ? csi_rxd2_lp_p_i : csi_rxd2_lp_n_i, CSI_RXD_INV[1] ? csi_rxd1_lp_p_i : csi_rxd1_lp_n_i, CSI_RXD_INV[0] ? csi_rxd0_lp_p_i : csi_rxd0_lp_n_i}),
    .Rx_HS_D_0                         ((CSI_RXD_INV[0] ? 8'hFF : 8'h00) ^ csi_rxd0_hs_i),
    .Rx_HS_D_1                         ((CSI_RXD_INV[1] ? 8'hFF : 8'h00) ^ csi_rxd1_hs_i),
    .Rx_HS_D_2                         ((CSI_RXD_INV[2] ? 8'hFF : 8'h00) ^ csi_rxd2_hs_i),
    .Rx_HS_D_3                         ((CSI_RXD_INV[3] ? 8'hFF : 8'h00) ^ csi_rxd3_hs_i),
    .Rx_HS_D_4                         (                          ),
    .Rx_HS_D_5                         (                          ),
    .Rx_HS_D_6                         (                          ),
    .Rx_HS_D_7                         (                          ),
		
    .Rx_HS_enable_D                    ({csi_rxd3_hs_en_o, csi_rxd2_hs_en_o, csi_rxd1_hs_en_o, csi_rxd0_hs_en_o}),
    .LVDS_termen_D                     ({csi_rxd3_hs_term_en_o, csi_rxd2_hs_term_en_o, csi_rxd1_hs_term_en_o, csi_rxd0_hs_term_en_o}),
    .fifo_rd_enable                    ({csi_rxd3_fifo_rd_o, csi_rxd2_fifo_rd_o, csi_rxd1_fifo_rd_o, csi_rxd0_fifo_rd_o}),
    .fifo_rd_empty                     ({csi_rxd3_fifo_empty_i, csi_rxd2_fifo_empty_i, csi_rxd1_fifo_empty_i, csi_rxd0_fifo_empty_i}),
    .DLY_enable_D                      (                          ),
    .DLY_inc_D                         (                          ),
    .u_dly_enable_D                    (0                         ),
    .u_dly_inc_D                       (                          ),
	//同步信号(vsync, hsync)	
    .vsync_vc1                         (                          ),
    .vsync_vc15                        (                          ),
    .vsync_vc12                        (                          ),
    .vsync_vc9                         (                          ),
    .vsync_vc7                         (                          ),
    .vsync_vc14                        (                          ),
    .vsync_vc13                        (                          ),
    .vsync_vc11                        (                          ),
    .vsync_vc10                        (                          ),
    .vsync_vc8                         (                          ),
    .vsync_vc6                         (                          ),
    .vsync_vc4                         (                          ),
    .vsync_vc0                         (w_csi_rx_vsync0           ),
    .vsync_vc5                         (                          ),
    .vsync_vc3                         (                          ),
    .vsync_vc2                         (                          ),
	
    .irq                               (                          ),
		
    .pixel_data_valid                  (w_csi_rx_dvalid           ),
    .pixel_data                        (w_csi_rx_data             ),
    .pixel_per_clk                     (                          ),
    .datatype                          (data_typer                ),
    .shortpkt_data_field               (                          ),
    .word_count                        (                          ),
    .vcx                               (                          ),
    .vc                                (                          ),
    .hsync_vc3                         (                          ),
    .hsync_vc2                         (                          ),
    .hsync_vc8                         (                          ),
    .hsync_vc12                        (                          ),
    .hsync_vc7                         (                          ),
    .hsync_vc10                        (                          ),
    .hsync_vc1                         (                          ),
    .hsync_vc0                         (w_csi_rx_hsync0           ),
    .hsync_vc13                        (                          ),
    .hsync_vc4                         (                          ),
    .hsync_vc11                        (                          ),
    .hsync_vc6                         (                          ),
    .hsync_vc9                         (                          ),
    .hsync_vc15                        (                          ),
    .hsync_vc14                        (                          ),
    .hsync_vc5                         (                          ),
	//AXI接口信号	
    .axi_clk                           (clk_sys                   ),
    .axi_reset_n                       (rstn_sys                  ),
		
    .axi_awaddr                        (r_axi_addr                ),
    .axi_awvalid                       ((r_axi_sel == CSI_AXILITE_ID) && r_axi_awvalid),
    .axi_awready                       (w_csi_axi_awready         ),
	
    .axi_wvalid                        ((r_axi_sel == CSI_AXILITE_ID) && r_axi_wvalid),
    .axi_wdata                         (r_axi_wdata               ),
    .axi_wready                        (w_csi_axi_wready          ),
	
    .axi_bvalid                        (                          ),
    .axi_bready                        (1                         ),
		
    .axi_araddr                        (r_axi_addr                ),
    .axi_arvalid                       ((r_axi_sel == CSI_AXILITE_ID) && r_axi_arvalid),
    .axi_arready                       (w_csi_axi_arready         ),
		
    .axi_rready                        (1                         ),
    .axi_rvalid                        (w_csi_axi_rvalid          ),
    .axi_rdata                         (w_csi_axi_rdata           ) 
		
    );  //数据写入赋值
assign wr_data = {w_csi_rx_data[39:32], w_csi_rx_data[29:22],w_csi_rx_data[19:12], w_csi_rx_data[9:2]} ;

`endif //CSI数据通道的复位信号连接到系统复位
	assign csi_rxd0_rst_o = rst_sys; 
	assign csi_rxd1_rst_o = rst_sys; 
	assign csi_rxd2_rst_o = rst_sys; 
	assign csi_rxd3_rst_o = rst_sys; 
	
	
	//	Output LED
	reg 	[5:0]		r_csi_fv_o = 0;   // CSI帧计数器(6位)
	reg 	[1:0] 	r_csi_rx_vsync0_in = 0; //vsync信号寄存器，用于检测上升沿
	always @(posedge w_csi_rx_clk) begin
		r_csi_rx_vsync0_in <= {r_csi_rx_vsync0_in, w_csi_rx_vsync0}; 
		r_csi_fv_o <= r_csi_fv_o + ((r_csi_rx_vsync0_in == 2'b01) ? 1 : 0); //检测到vsync信号上升沿时，帧计数器加1
	end
	assign led_o[4] = r_csi_fv_o[5];//输出帧计数器最高位，用于指示CSI活动状态


//行列计数器
wire [10:0] cnt_pixel;
wire [10:0] cnt_row;

Row_Line_Counter  u_Row_Line_Counter (
    .Data_clk                          (w_csi_rx_clk               ),
    .Data_rst_n                        (rstn_sys             ),
    .Data_vsync                        (w_csi_rx_vsync0         ),
    .Data_hsync                        (w_csi_rx_hsync0         ),//用于统计行
    .Data_valid                        (w_csi_rx_dvalid         ),//用于统计每一行的像素

    .cnt_pixel                         (cnt_pixel   [10:0]),
    .cnt_row                           (cnt_row     [10:0]) 
);
// =========================================================================================================================================
// data 32 to 8
// ========================================================================================================================================= 

//c1
// assign wr_data = {w_csi_rx_data[9:2], w_csi_rx_data[19:12], w_csi_rx_data[29:22], w_csi_rx_data[39:32]} ;
assign wr_en = w_csi_rx_hsync0 && w_csi_rx_dvalid;// FIFO写使能信号

always@(posedge w_csi_rx_clk or negedge rstn_sys)
begin
	if(!rstn_sys)
		begin
			rd_en   <=  'd0 ;  //复位时读使能为0

		end
	else if(pixel_cnt == 1279)  //当像素计数达到1279时，停止读取
		begin
			rd_en   <=  'd0 ;
		end
	else if(rd_count >=1280)  //当FIFO中数据量>=1280时，启动读取

		begin
			rd_en   <=  1;
		end
	else
		begin
			rd_en   <=  rd_en ;  //其他情况下保持当前状态

		end
end
always@(posedge w_csi_rx_clk or negedge rstn_sys)//像素计数器控制
begin
	if(!rstn_sys)//复位时清零
		begin
			pixel_cnt   <=  'd0 ;
		end
	else if(pixel_cnt == 1279)//计数到1279后重新开始
		begin
			pixel_cnt   <=  'd0 ;
		end
	else if(rd_en)//读使能时递增计数
		begin
			pixel_cnt   <=  pixel_cnt + 1 ;
		end
	else
		begin
			pixel_cnt   <=  'd0 ;//其他情况保持为0
		end
end
//c232位到8位FIFO转换：

/*将32位宽的CSI数据转换为8位宽的数据输出
提供写时钟、写数据、写使能等写控制信号
提供读时钟、读使能、读数据等读控制信号
输出FIFO状态信号如空状态和读计数*/
afifo_w32r8_reshape u_afifo_w32r8_reshape
(
	.full_o                            (                          ),
    .rst_busy                          (                          ),
	.empty_o                           (empty_o                   ),
    .a_rst_i                           (~rstn_sys              ),
   
    .wr_clk_i                          (w_csi_rx_clk                ),
    .wdata                             (wr_data                   ),
    .wr_en_i                           (wr_en                     ),
    .wr_datacount_o                    (                          ),
    
    .rd_clk_i                          (w_csi_rx_clk                ),
    .rd_en_i                           (rd_en                     ),
    .rdata                             (rd_data                   ),
    .rd_datacount_o                    (rd_count                  ) 
);
//c3  延迟寄存器
/*同步信号延迟：

使用延迟寄存器对vsync信号进行延迟处理
延迟级别为1280个时钟周期

*/
wire                                    delay_vsync                ;
delay_reg #(.delay_level(1280),.reg_width(1)) DR0(
    .clk                               (w_csi_rx_clk                ),
    .rst                               (~rstn_sys              ),
    .din                               (w_csi_rx_vsync0      ),

    .dout                              (delay_vsync               ) 
);
assign prepare_vsync = delay_vsync;
assign prepare_valid = rd_en;
assign prepare_data = rd_data;
// =========================================================================================================================================
// DPC
// ========================================================================================================================================= 
// wire                                    post_frame_vsync           ;
// wire                                    post_frame_href            ;
// wire                                    post_frame_hsync           ;
// wire                   [   7:0]         final_data                 ;
// bad_dot_improve #(
//     .IMG_HDISP                         (1280                      ),
//     .IMG_VDISP                         (960 )                     ) 
//  u_bad_dot_improve (
//     .clk                               (w_csi_rx_clk                ),
//     .rst_n                             (rstn_sys               ),
//     .per_frame_vsync                   (prepare_vsync             ),
//     .per_frame_href                    (prepare_valid             ),
//     .per_frame_hsync                   (prepare_valid             ),
//     .per_img_RAW                       (prepare_data       [   7:0]),

//     .post_frame_vsync                  (post_frame_vsync          ),
//     .post_frame_href                   (post_frame_href           ),
//     .post_frame_hsync                  (post_frame_hsync          ),
//     .final_data                        (final_data        [   7:0]) 
// );
// =========================================================================================================================================
// XYCrop  图像裁剪模块
// ========================================================================================================================================= 
	wire			XYCrop_frame_vsync; 
	wire			XYCrop_frame_href;
	wire			XYCrop_frame_de;
	wire	[7:0]	XYCrop_frame_Gray;

    Sensor_Image_XYCrop
    #(
    .IMAGE_HSIZE_SOURCE                (1280 / CSI_STRB_WIDTH     ),
    .IMAGE_VSIZE_SOURCE                (960                       ),
    .IMAGE_HSIZE_TARGET                (1280 / CSI_STRB_WIDTH     ),
    .IMAGE_YSIZE_TARGET                (720                       ),
    .PIXEL_DATA_WIDTH                  (8                        ) //	32		 )
    )
    u_Sensor_Image_XYCrop
    (
		//	globel clock
    .clk                               (w_csi_rx_clk              ),//	image pixel clock
    .rst_n                             (rstn_sys                  ),//	system reset
		
		//CMOS Sensor interface
    .image_in_vsync                    (prepare_vsync           ),//H : Data Valid; L : Frame Sync(Set it by register)
    .image_in_href                     (prepare_valid       ),//H : Data vaild, L : Line Sync
    .image_in_de                       (prepare_valid            ),//H : Data Enable, L : Line Sync
    .image_in_data                     (prepare_data),//8 bits cmos data input
    // .image_in_vsync                    (post_frame_vsync           ),//H : Data Valid; L : Frame Sync(Set it by register)
    // .image_in_href                     (post_frame_href &&    post_frame_hsync        ),//H : Data vaild, L : Line Sync
    // .image_in_de                       (post_frame_href &&    post_frame_hsync             ),//H : Data Enable, L : Line Sync
    // .image_in_data                     (final_data),//8 bits cmos data input
		
    .image_out_vsync                   (XYCrop_frame_vsync        ),//H : Data Valid; L : Frame Sync(Set it by register)
    .image_out_href                    (XYCrop_frame_href         ),//H : Data vaild, L : Line Sync
    .image_out_de                      (XYCrop_frame_de           ),//H : Data Enable, L : Line Sync
    .image_out_data                    (XYCrop_frame_Gray         ) //8 bits cmos data input	
    );

	reg			r_XYCrop_frame_vsync = 0; 
	reg			r_XYCrop_frame_href = 0;
	reg			r_XYCrop_frame_de = 0;
	reg	[63:0]	r_XYCrop_frame_Gray = 0;
	
	always @(posedge w_csi_rx_clk) begin
		r_XYCrop_frame_vsync <= XYCrop_frame_vsync; 
		r_XYCrop_frame_href <= XYCrop_frame_href;
		r_XYCrop_frame_de <= XYCrop_frame_de;
		r_XYCrop_frame_Gray <= XYCrop_frame_Gray;
	end
	
	//	Data Write Assignment
	wire			cmos_frame_vsync = r_XYCrop_frame_vsync;                     //  cmos frame data vsync valid signal
	wire			cmos_frame_href = r_XYCrop_frame_href && r_XYCrop_frame_de;	 //  cmos frame data href vaild  signal
	wire	[7:0]	cmos_frame_Gray = r_XYCrop_frame_Gray; 

	//c1 crop data
wire                                    crop_vsync                 ;
wire                                    crop_valid                 ;
wire                   [   7:0]         crop_data                  ;
assign crop_vsync = r_XYCrop_frame_vsync;
assign crop_valid = cmos_frame_href ;
assign crop_data = cmos_frame_Gray;
// =========================================================================================================================================
// P1_Bayer2rgb
// ========================================================================================================================================= 
wire 			w_rgb_vsync, w_rgb_hsync, w_rgb_href; 
wire 	[7:0] 	w_rgb_r, w_rgb_g, w_rgb_b; 
wire [11:0] cnt_bayer_pixel;
wire [11:0] cnt_bayer_row  ;
VIP_RAW8_RGB888 #(.IMG_HDISP(1280), .IMG_VDISP(720)) ori_bayer2rgb (
    .clk                               (w_csi_rx_clk                ),//cmos video pixel clock
    .rst_n                             (rstn_sys               ),//global reset
	
    .mirror                            (2'b11                     ),

		//CMOS YCbCr444 data output
    .per_frame_vsync                   (crop_vsync                ),//Prepared Image data vsync valid signal. Reset on falling edge. 
    .per_frame_hsync                   (crop_valid                ),//Prepared Image data href vaild  signal
    .per_frame_href                    (crop_valid                ),//Prepared Image data href vaild  signal
    .per_img_RAW                       (crop_data                 ),//Prepared Image data 8 Bit RAW Data

    .post_frame_vsync                  (w_rgb_vsync               ),//Processed Image data vsync valid signal
    .post_frame_hsync                  (w_rgb_hsync               ),//Processed Image data href vaild  signal
    .post_frame_href                   (w_rgb_href                ),//Processed Image data href vaild  signal
    .post_img_red                      (w_rgb_r                   ),//Prepared Image green data to be processed 
    .post_img_green                    (w_rgb_g                   ),//Prepared Image green data to be processed
    .post_img_blue                     (w_rgb_b                   ) //Prepared Image blue data to be processed
);
// =========================================================================================================================================
//P2_MWB
// ========================================================================================================================================= 
//c1

wire                                    rgb_vsync                  ;
wire                                    rgb_valid                  ;
wire                   [  23:0]         rgb_data                   ;
wire                   [   7:0]         w_mwb_rgb_r                ;
wire                   [   7:0]         w_mwb_rgb_g                ;
wire                   [   7:0]         w_mwb_rgb_b                ;
wire     [17:0]     w_rgb_r_mult = w_rgb_r * 409; //409
wire     [17:0]     w_rgb_b_mult = w_rgb_b * 384; //384

assign w_mwb_rgb_r = w_rgb_r_mult[17:16] ? 8'hFF : w_rgb_r_mult[15: 8]; 
assign w_mwb_rgb_g = w_rgb_g; 
assign w_mwb_rgb_b = w_rgb_b_mult[17:16] ? 8'hFF : w_rgb_b_mult[15: 8]; 
//c2
assign rgb_vsync = w_rgb_vsync;
assign rgb_valid = w_rgb_href;
assign rgb_data = {w_mwb_rgb_r,w_mwb_rgb_g,w_mwb_rgb_b};
// =========================================================================================================================================
// DDR Ctrl
// ========================================================================================================================================= 
	wire                            lcd_de;
	wire                            lcd_hs;      
	wire                            lcd_vs;
	wire 					  lcd_request; 
	wire            [7:0]           lcd_red, lcd_red2;
	wire            [7:0]           lcd_green, lcd_green2;
	wire            [7:0]           lcd_blue, lcd_blue2;
	wire            [31:0]          lcd_data;


	assign w_ddr3_awid = 0; 
	assign w_ddr3_wid = 0; 
	
	wire 			w_wframe_vsync; 
	wire 	[7:0] 	w_axi_tp; 
	
	axi4_ctrl #(.C_RD_END_ADDR(1280 * 720 *4), .C_W_WIDTH(32), .C_R_WIDTH(32), .C_ID_LEN(4)) u_axi4_ctrl (

		.axi_clk        (w_ddr3_ui_clk            ),
		.axi_reset      (w_ddr3_ui_rst            ),

		.axi_awaddr     (w_ddr3_awaddr       ),
		.axi_awlen      (w_ddr3_awlen        ),
		.axi_awvalid    (w_ddr3_awvalid      ),
		.axi_awready    (w_ddr3_awready      ),

		.axi_wdata      (w_ddr3_wdata        ),
		.axi_wstrb      (w_ddr3_wstrb        ),
		.axi_wlast      (w_ddr3_wlast        ),
		.axi_wvalid     (w_ddr3_wvalid       ),
		.axi_wready     (w_ddr3_wready       ),

		.axi_bid        (0          ),
		.axi_bresp      (0        ),
		.axi_bvalid     (1       ),

		.axi_arid       (w_ddr3_arid         ),
		.axi_araddr     (w_ddr3_araddr       ),
		.axi_arlen      (w_ddr3_arlen        ),
		.axi_arvalid    (w_ddr3_arvalid      ),
		.axi_arready    (w_ddr3_arready      ),

		.axi_rid        (w_ddr3_rid          ),
		.axi_rdata      (w_ddr3_rdata        ),
		.axi_rresp      (0        ),
		.axi_rlast      (w_ddr3_rlast        ),
		.axi_rvalid     (w_ddr3_rvalid       ),
		.axi_rready     (w_ddr3_rready       ),

		.wframe_pclk    (w_csi_rx_clk          ),
		.wframe_vsync   (rgb_vsync), //w_wframe_vsync   ),		//	Writter VSync. Flush on rising edge. Connect to EOF. 
		.wframe_data_en (rgb_valid   ),
		.wframe_data    ({8'b0,rgb_data} ),
		
		.rframe_pclk    (clk_pixel            ),
		.rframe_vsync   (~lcd_vs             ),		//	Reader VSync. Flush on rising edge. Connect to ~EOF. 
		.rframe_data_en (lcd_request             ),
		.rframe_data    (lcd_data           ),
		
		.tp_o 		(w_axi_tp)
	);
	assign led_o[3:0] = w_axi_tp; 
// =========================================================================================================================================
// lcd_driver
// ========================================================================================================================================= 
	
wire [11:0] x_pos;
wire [11:0] y_pos;
wire [23:0] char_data;
wire data_enable;
wire data_enable2;


    lcd_driver u_lcd_driver
    (
	    //  global clock
    .clk                               (clk_pixel                 ),
    .rst_n                             (rstn_pixel                ),
	    
	    //  lcd interface
    .lcd_dclk                          (                          ),
    .lcd_blank                         (                          ),
    .lcd_sync                          (                          ),
    .lcd_request                       (lcd_request               ),//	Request data 1 cycle ahead. 
    .lcd_hs                            (lcd_hs                    ),
    .lcd_vs                            (lcd_vs                    ),
    .lcd_en                            (lcd_de                    ),
    .lcd_rgb                           ({lcd_red2,lcd_green2,lcd_blue2, lcd_red,lcd_green,lcd_blue}),
	    
	    //  user interface
    .lcd_data                          ({lcd_data[23:0] ,lcd_data[23:0]}),
    .lcd_xpos                          (x_pos                     ),
    .lcd_ypos                          (y_pos                     ) 
    );
	
	// wire [23:0] hdmi_data = (data_enable||data_enable2)? char_data : {lcd_red,lcd_green,lcd_blue}    ;
	wire [23:0] hdmi_data =  {lcd_red,lcd_green,lcd_blue}    ;
// =========================================================================================================================================
// BoundCrop
// ========================================================================================================================================= 

wire                                    w_rgb_vs_o, w_rgb_hs_o, w_rgb_de_o;
wire                   [  23:0]         w_rgb_data_o               ;
FrameBoundCrop #(.SKIP_ROWS(4),.SKIP_COLS(2),.TOTAL_ROWS(720),.TOTAL_COLS(1280)) inst_FrameCrop(
    .clk_i                             (clk_pixel                 ),
    .rst_i                             (~rstn_pixel                ),
	
    .hs_i                              (lcd_hs              ),
    .vs_i                              (lcd_vs              ),
    .de_i                              (lcd_de              ),
    .data_i                            (hdmi_data            ),
	
    .vs_o                              (w_rgb_vs_o                ),
    .hs_o                              (w_rgb_hs_o                ),
    .de_o                              (w_rgb_de_o                ),
    .data_o                            (w_rgb_data_o              ) 
);
	
// =========================================================================================================================================
// HDMI Interface
// ========================================================================================================================================= 
	assign hdmi_txd0_rst_o = rst_pixel; 
	assign hdmi_txd1_rst_o = rst_pixel; 
	assign hdmi_txd2_rst_o = rst_pixel; 
	assign hdmi_txc_rst_o = rst_pixel; 
	
	assign hdmi_txd0_oe = 1'b1; 
	assign hdmi_txd1_oe = 1'b1; 
	assign hdmi_txd2_oe = 1'b1; 
	assign hdmi_txc_oe = 1'b1; 
	
	//-------------------------------------
	//Digilent HDMI-TX IP Modified by CB elec.
	
	// 添加FPS显示模块实例化前的信号定义
	wire [23:0] video_data_in;
	wire [23:0] video_data_out;
	wire fps_display_en = 1'b1; // 使能FPS显示
	
	// 连接视频数据输入
	assign video_data_in = w_rgb_data_o;
	
	// 实例化FPS显示模块
	FPS_Display u_fps_display (
		.clk_pixel(clk_pixel),
		.rstn_pixel(rstn_pixel),
		.vsync(w_rgb_vs_o),
		.hsync(w_rgb_hs_o),
		.de(w_rgb_de_o),
		.xpos(x_pos),
		.ypos(y_pos),
		.video_data_in(video_data_in),
		.video_data_out(video_data_out),
		.fps_display_en(fps_display_en)
	);
	
    rgb2dvi #(.ENABLE_OSERDES(0)) u_rgb2dvi
    (
    .oe_i                              (1                         ),//	Always enable output
    .bitflip_i                         (4'b0000                   ),//	Reverse clock & data lanes. 
		
    .aRst                              (1'b0                      ),
    .aRst_n                            (1'b1                      ),
		
    .PixelClk                          (clk_pixel                 ),//pixel clk = 74.25M
    .SerialClk                         (                          ),//pixel clk *5 = 371.25M
		
    .vid_pVSync                        (w_rgb_vs_o                    ),
    .vid_pHSync                        (w_rgb_hs_o                    ),
    .vid_pVDE                          (w_rgb_de_o                    ),
    // 修改数据连接，使用带FPS显示的输出数据
    .vid_pData                         (video_data_out),
		
    .txc_o                             (hdmi_txc_o                ),
    .txd0_o                            (hdmi_txd0_o               ),
    .txd1_o                            (hdmi_txd1_o               ),
    .txd2_o                            (hdmi_txd2_o               ) 
    );
		
	






	
	
endmodule


