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
    input         I_clk         , //ϵͳʱ��
    input         rst           , //ϵͳ��λ
	
    input         eth_tx_clk    , //MII��������ʱ��  
    output        eth_tx_en     , //MII���������Ч�ź�
    output [3:0]  eth_tx_data   , //MII�������          
    output        eth_rst_n     , //��̫��оƬ��λ�źţ��͵�ƽ��Ч 

    output        O_qspi_clk    , // QPI���ߴ���ʱ����
    output        O_qspi_cs     , // QPI����Ƭѡ�ź�
    inout         IO_qspi_io0   , // QPI��������/����ź���
    inout         IO_qspi_io1   , // QPI��������/����ź���
    inout         IO_qspi_io2   , // QPI��������/����ź���
    inout         IO_qspi_io3     // QPI��������/����ź���  
);
   
(*KEEP = "TRUE"*)wire         W_done_sig          ;
(*KEEP = "TRUE"*)wire [7:0]   W_read_data         ;
(*KEEP = "TRUE"*)wire         W_read_byte_valid   ;
(*KEEP = "TRUE"*)wire         I_rst_n             ;
(*KEEP = "TRUE"*)wire         R_clk_25M           ;
(*KEEP = "TRUE"*)wire [4:0]   R_cmd_type          ;//��������
(*KEEP = "TRUE"*)wire [7:0]   R_flash_cmd 		  ;
(*KEEP = "TRUE"*)wire [23:0]  R_flash_addr		  ;
(*KEEP = "TRUE"*)wire [15:0]  R_status_reg        ;//����״̬�Ĵ�����ֵ
(*KEEP = "TRUE"*)wire [7:0]   R_test_vec          ;//��������������д0����д1

(*KEEP = "TRUE"*)wire [31:0]  tx_data             ;//��̫������������  
(*KEEP = "TRUE"*)wire [15:0]  tx_byte_num         ;//��̫�����͵���Ч�ֽ���
(*KEEP = "TRUE"*)wire [31:0]  crc_data            ;//CRCУ������
(*KEEP = "TRUE"*)wire [31:0]  crc_next            ;//CRC�´�У���������
(*KEEP = "TRUE"*)wire         tx_req              ;//�����������ź�
(*KEEP = "TRUE"*)wire         crc_en              ;//CRC��ʼУ��ʹ��
(*KEEP = "TRUE"*)wire         crc_clr             ;//CRC���ݸ�λ�ź�
(*KEEP = "TRUE"*)wire [3:0]   crc_d4    		     ;//�����У��4λ����

(*KEEP = "TRUE"*)wire         rd_req 			;
(*KEEP = "TRUE"*)wire         wr_req			;
(*KEEP = "TRUE"*)wire         empty				;
(*KEEP = "TRUE"*)wire		  full				;
 
assign  crc_d4 = eth_tx_data;
assign  eth_rst_n = 1'b1;                 //��λ�ź�һֱ����
assign  rd_req = (empty == 0 && wr_req == 0)? 1:0 ;	
assign  wr_req = (full == 0 && rd_req == 0)? 1:0 ;
assign  tx_byte_num = 16'd1024;	
////���ܣ���λ������
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
.O_qspi_clk          (O_qspi_clk        ), // QPI���ߴ���ʱ����
.O_qspi_cs           (O_qspi_cs         ), // QPI����Ƭѡ�ź�
.IO_qspi_io0         (IO_qspi_io0       ), // QPI��������/����ź���
.IO_qspi_io1         (IO_qspi_io1       ), // QPI��������/����ź���
.IO_qspi_io2         (IO_qspi_io2       ), // QPI��������/����ź���
.IO_qspi_io3         (IO_qspi_io3       ), // QPI��������/����ź���
                   
.I_rst_n             (I_rst_n           ), // ��λ�ź�

.I_clk_25M           (R_clk_25M         ), // 25MHzʱ���ź�
.I_cmd_type          (R_cmd_type        ), // ��������
.I_cmd_code          (R_flash_cmd       ), // ������
.I_qspi_addr         (R_flash_addr      ), // QSPI Flash��ַ
.I_status_reg        (R_status_reg      ), // QSPI Flash״̬�Ĵ���
.I_test_vec          (R_test_vec        ),

.O_done_sig          (W_done_sig        ), // ָ��ִ�н�����־
.O_read_data         (W_read_data       ), // ��QSPI Flash����������
.O_read_byte_valid   (W_read_byte_valid ), // ��һ���ֽ���ɵı�־
.O_qspi_state        (                  )  // ״̬���������ڶ��������
);
     
fifo_1024 u_fifo_1024
(
.rst         (~I_rst_n			),
.din         (W_read_data   	),          //fifoд����
.rd_clk      (eth_tx_clk		),
.rd_en       (tx_req    		),          //fifo��ʹ��
.wr_clk      (R_clk_25M			),          
.wr_en       (W_read_byte_valid ),          //fifoдʹ��
.dout        (tx_data   		),          //fifo������
.empty       (empty				),
.full        (full				)
);

ip_send u_ip_send
(
.clk             (eth_tx_clk	    ),        
.rst_n           (I_rst_n		    ),             
.tx_start_en     (rd_en             ),    //��̫����ʼ�����ź�           
.tx_data         (tx_data		    ),    //��̫������������  
.tx_byte_num     (tx_byte_num       ),    //��̫�����͵���Ч�ֽ���
.crc_data        (crc_data		    ),    //CRCУ������
.crc_next        (crc_next[31:28]   ),    //CRC�´�У���������
.tx_done         (					),    //��̫����������ź�
.tx_req          (tx_req			),    //�����������ź�
.eth_tx_en       (eth_tx_en			),    //MII���������Ч�ź�
.eth_tx_data     (eth_tx_data		),    //MII�������
.crc_en          (crc_en			),    //CRC��ʼУ��ʹ��
.crc_clr         (crc_clr			)     //CRC���ݸ�λ�ź� 
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
