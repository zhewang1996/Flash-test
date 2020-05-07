`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:39:30 11/29/2019 
// Design Name: 
// Module Name:    QUAD_qspi_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module qspi_top
(
    input         I_clk         , //系统时钟
    input         rst           , //系统复位
	
    input         eth_tx_clk    , //MII发送数据时钟  
    output        eth_tx_en     , //MII输出数据有效信号
    output [3:0]  eth_tx_data   , //MII输出数据          
    output        eth_rst_n     , //以太网芯片复位信号，低电平有效 

    output        O_qspi_clk    , // QPI总线串行时钟线
    output        O_qspi_cs     , // QPI总线片选信号
    inout         IO_qspi_io0   , // QPI总线输入/输出信号线
    inout         IO_qspi_io1   , // QPI总线输入/输出信号线
    inout         IO_qspi_io2   , // QPI总线输入/输出信号线
    inout         IO_qspi_io3     // QPI总线输入/输出信号线  
);
   
(*KEEP = "TRUE"*)wire         W_done_sig          ;
(*KEEP = "TRUE"*)wire [7:0]   W_read_data         ;
(*KEEP = "TRUE"*)wire         W_read_byte_valid   ;
(*KEEP = "TRUE"*)wire         I_rst_n             ;
(*KEEP = "TRUE"*)wire         R_clk_25M           ;
(*KEEP = "TRUE"*)wire [4:0]   R_cmd_type          ;//命令类型
(*KEEP = "TRUE"*)wire [7:0]   R_flash_cmd 		  ;
(*KEEP = "TRUE"*)wire [23:0]  R_flash_addr		  ;
(*KEEP = "TRUE"*)wire [15:0]  R_status_reg        ;//输入状态寄存器的值
(*KEEP = "TRUE"*)wire [7:0]   R_test_vec          ;//测试向量，决定写0还是写1

(*KEEP = "TRUE"*)wire [31:0]  tx_data             ;//以太网待发送数据  
(*KEEP = "TRUE"*)wire [15:0]  tx_byte_num         ;//以太网发送的有效字节数
(*KEEP = "TRUE"*)wire [31:0]  crc_data            ;//CRC校验数据
(*KEEP = "TRUE"*)wire [31:0]  crc_next            ;//CRC下次校验完成数据
(*KEEP = "TRUE"*)wire         tx_req              ;//读数据请求信号
(*KEEP = "TRUE"*)wire         crc_en              ;//CRC开始校验使能
(*KEEP = "TRUE"*)wire         crc_clr             ;//CRC数据复位信号
(*KEEP = "TRUE"*)wire [3:0]   crc_d4    		     ;//输入待校验4位数据

(*KEEP = "TRUE"*)wire         rd_req 			;
(*KEEP = "TRUE"*)wire         wr_req			;
(*KEEP = "TRUE"*)wire         empty				;
(*KEEP = "TRUE"*)wire		  full				;
 
assign  crc_d4 = eth_tx_data;
assign  eth_rst_n = 1'b1;                 //复位信号一直拉高
assign  rd_req = (empty == 0 && wr_req == 0)? 1:0 ;	
assign  wr_req = (full == 0 && rd_req == 0)? 1:0 ;
assign  tx_byte_num = 16'd1024;	
////功能：复位键消抖
////////////////////////////////////////////////////////////////////
IP_ButtonDebounce m1(.clk(I_clk),.rst(1'b0),.BTN0(rst),.BTN_DEB(I_rst_n));
////////////////////////////////////////////////////////////////////
qspi_control U_qspi_control
(
.I_clk               (I_clk				), 
.I_rst_n             (I_rst_n			),
					 
.W_done_sig          (W_done_sig		),
.W_read_data         (W_read_data		),
.wr_req              (wr_req			),
					 
.R_clk_25M           (R_clk_25M			),
.R_cmd_type          (R_cmd_type		),
.R_flash_cmd         (R_flash_cmd		),
.R_flash_addr        (R_flash_addr		),
.R_status_reg        (R_status_reg		),
.R_test_vec          (R_test_vec		)
);
   
qspi_driver U_qspi_driver
(
.O_qspi_clk          (O_qspi_clk        ), // QPI总线串行时钟线
.O_qspi_cs           (O_qspi_cs         ), // QPI总线片选信号
.IO_qspi_io0         (IO_qspi_io0       ), // QPI总线输入/输出信号线
.IO_qspi_io1         (IO_qspi_io1       ), // QPI总线输入/输出信号线
.IO_qspi_io2         (IO_qspi_io2       ), // QPI总线输入/输出信号线
.IO_qspi_io3         (IO_qspi_io3       ), // QPI总线输入/输出信号线
                   
.I_rst_n             (I_rst_n           ), // 复位信号

.I_clk_25M           (R_clk_25M         ), // 25MHz时钟信号
.I_cmd_type          (R_cmd_type        ), // 命令类型
.I_cmd_code          (R_flash_cmd       ), // 命令码
.I_qspi_addr         (R_flash_addr      ), // QSPI Flash地址
.I_status_reg        (R_status_reg      ), // QSPI Flash状态寄存器
.I_test_vec          (R_test_vec        ),

.O_done_sig          (W_done_sig        ), // 指令执行结束标志
.O_read_data         (W_read_data       ), // 从QSPI Flash读出的数据
.O_read_byte_valid   (W_read_byte_valid ), // 读一个字节完成的标志
.O_qspi_state        (                  )  // 状态机，用于在顶层调试用
);
     
fifo_1024 u_fifo_1024
(
.rst         (~I_rst_n			),
.din         (W_read_data   	),          //fifo写数据
.rd_clk      (eth_tx_clk		),
.rd_en       (tx_req    		),          //fifo读使能
.wr_clk      (R_clk_25M			),          
.wr_en       (W_read_byte_valid ),          //fifo写使能
.dout        (tx_data   		),          //fifo读数据
.empty       (empty				),
.full        (full				)
);

ip_send u_ip_send
(
.clk             (eth_tx_clk	    ),        
.rst_n           (I_rst_n		    ),             
.tx_start_en     (rd_en             ),    //以太网开始发送信号           
.tx_data         (tx_data		    ),    //以太网待发送数据  
.tx_byte_num     (tx_byte_num       ),    //以太网发送的有效字节数
.crc_data        (crc_data		    ),    //CRC校验数据
.crc_next        (crc_next[31:28]   ),    //CRC下次校验完成数据
.tx_done         (					),    //以太网发送完成信号
.tx_req          (tx_req			),    //读数据请求信号
.eth_tx_en       (eth_tx_en			),    //MII输出数据有效信号
.eth_tx_data     (eth_tx_data		),    //MII输出数据
.crc_en          (crc_en			),    //CRC开始校验使能
.crc_clr         (crc_clr			)     //CRC数据复位信号 
); 

crc32_d4   u_crc32_d4
(
.clk             (eth_tx_clk		),                      
.rst_n           (I_rst_n 			),                          
.data            (crc_d4			),            
.crc_en          (crc_en			),                          
.crc_clr         (crc_clr			),                         
.crc_data        (crc_data			),                        
.crc_next        (crc_next			)                         
);
                              

endmodule
