module qspi_top
(
    input         I_clk         , //50MHzϵͳʱ��
    input         rst           , //ϵͳ��λ
	
    input         eth_rxc   	, //RGMII��������ʱ��
    input         eth_rx_ctl	, //RGMII����������Ч�ź�
    input  [3:0]  eth_rxd   	, //RGMII��������
    output        eth_txc   	, //RGMII��������ʱ��    
    output        eth_tx_ctl	, //RGMII���������Ч�ź�
    output [3:0]  eth_txd   	, //RGMII�������          
    output        eth_rst_n 	,//��̫��оƬ��λ�źţ��͵�ƽ��Ч 

    output        O_qspi_clk    , // QPI���ߴ���ʱ����
    output        O_qspi_cs     , // QPI����Ƭѡ�ź�
    inout         IO_qspi_io0   , // QPI��������/����ź���
    inout         IO_qspi_io1   , // QPI��������/����ź���
    inout         IO_qspi_io2   , // QPI��������/����ź���
    inout         IO_qspi_io3     // QPI��������/����ź���  
);

//parameter define
//������MAC��ַ 00-11-22-33-44-55
parameter  BOARD_MAC = 48'h00_11_22_33_44_55;     
//������IP��ַ 192.168.1.10
parameter  BOARD_IP  = {8'd192,8'd168,8'd1,8'd10};  
//Ŀ��MAC��ַ ff_ff_ff_ff_ff_ff
parameter  DES_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//Ŀ��IP��ַ 192.168.1.102     
parameter  DES_IP    = {8'd192,8'd168,8'd1,8'd102};  
//��������IO��ʱ,�˴�Ϊ0,������ʱ(���Ϊn,��ʾ��ʱn*78ps) 
parameter IDELAY_VALUE = 16;

(* mark_debug = "true" *)wire          	I_rst_n          	;// ϵͳ��λ
(* mark_debug = "true" *)wire          	clk_25M          	;// 25MHzȫ��ʱ��
wire          	clk_200M         	;// ����IO��ʱ��ʱ��(IDELAYCTRLԭ��Ĳο�ʱ��Ƶ��)    
wire          	W_done_sig       	;// ָ��ִ�н�����־
(* mark_debug = "true" *)wire [7:0]    	W_read_data      	;// ��QSPI Flash����������
wire          	W_read_byte_valid	;// ��һ���ֽ���ɵı�־
(* mark_debug = "true" *)wire [3:0]		W_qspi_state	 	;//	״̬���������ڶ������
wire [4:0]    	R_cmd_type       	;// ��������
(* mark_debug = "true" *)wire [7:0]    	R_flash_cmd 		;//	������
(* mark_debug = "true" *)wire [23:0]   	R_flash_addr		;//	Flash��ַ
wire [15:0]   	R_status_reg     	;// ����״̬�Ĵ�����ֵ
wire [7:0]    	R_test_vec       	;// ��������������д0����д1
	
wire          	gmii_rx_clk; //GMII����ʱ��
wire          	gmii_rx_dv ; //GMII����������Ч�ź�
wire  [7:0]   	gmii_rxd   ; //GMII��������
wire          	gmii_tx_clk; //GMII����ʱ��
wire          	gmii_tx_en ; //GMII��������ʹ���ź�
wire  [7:0]   	gmii_txd   ; //GMII��������     
	
wire          	rec_pkt_done  ; //UDP�������ݽ�������ź�
wire          	rec_en        ; //UDP���յ�����ʹ���ź�
wire  [31:0]  	rec_data      ; //UDP���յ�����
wire  [15:0]  	rec_byte_num  ; //UDP���յ���Ч�ֽ��� ��λ:byte 
wire  [15:0]  	tx_byte_num   ; //UDP���͵���Ч�ֽ��� ��λ:byte 
wire          	udp_tx_done   ; //UDP��������ź�
(* mark_debug = "true" *)wire          	tx_req        ; //UDP�����������ź�
(* mark_debug = "true" *)wire  [31:0]  	tx_data       ; //UDP����������	
(* mark_debug = "true" *)wire  			tx_start_en	  ;								 
	
wire 		  	rd_rst			;//FIFO����λ�ź�
wire			wr_rst			;//FIFOд��λ�ź�
(* mark_debug = "true" *)wire  [8:0]		rd_data_count	;
wire  [10:0]	wr_data_count	;
wire          	rd_req    		;//�����������ź�
wire          	wr_req			;//д���������ź�
wire          	empty	    	;//�����ź�	
wire		  	full	    	;//д���ź�
wire 			locked			;
 
assign  eth_rst_n = 1'b1	;//��λ�ź�һֱ����
assign  tx_byte_num = 16'd1024;	//һ��UPDģ�鷢��1024���ֽ�

////���ܣ���λ������
////////////////////////////////////////////////////////////////////
IP_ButtonDebounce m1(.clk(I_clk),.rst(1'b0),.BTN0(rst),.BTN_DEB(I_rst_n));
////////////////////////////////////////////////////////////////////
pll u_pll
(
    .clk_in1   (I_clk   ),
    .clk_out1  (clk_200M  ),
	.clk_out2  (clk_25M   ),
    .reset     (~I_rst_n  ), 
    .locked    (locked    )
);

qspi_control U_qspi_control
(
.clk_25M             (clk_25M			), 
.I_rst_n             (I_rst_n & locked	),
					 
.W_done_sig          (W_done_sig		),
.W_read_data         (W_read_data		),
					 
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
                   
.I_rst_n             (I_rst_n & locked  ), // ��λ�ź�

.I_clk_25M           (clk_25M           ), // 25MHzʱ���ź�
.I_cmd_type          (R_cmd_type        ), // ��������
.I_cmd_code          (R_flash_cmd       ), // ������
.I_qspi_addr         (R_flash_addr      ), // QSPI Flash��ַ
.I_status_reg        (R_status_reg      ), // QSPI Flash״̬�Ĵ���
.I_test_vec          (R_test_vec        ),

.O_done_sig          (W_done_sig        ), // ָ��ִ�н�����־
.O_read_data         (W_read_data       ), // ��QSPI Flash����������
.O_read_byte_valid   (W_read_byte_valid ), // ��һ���ֽ���ɵı�־
.O_qspi_state        (W_qspi_state      )  // ״̬���������ڶ������
);

fifo_ctrl u_fifo_ctrl
(
.clk_25M	(clk_25M	),
.gmii_tx_clk(gmii_tx_clk),
.I_rst_n	(I_rst_n	),
.rd_rst		(rd_rst		),//ϵͳ��λ�ź�ͬ����FIFO
.wr_rst		(wr_rst		),
.tx_start_en(tx_start_en),//��̫����ʼ�����ź�
.rd_data_count(rd_data_count)
); 

  
fifo_2048 u_fifo_2048
(
.rd_rst      (~rd_rst			),
.wr_rst      (~wr_rst			),

.wr_clk      (clk_25M			),          
.wr_en       (W_read_byte_valid ),          //fifoдʹ��
.din         (W_read_data   	),          //fifoд����

.rd_clk      (gmii_tx_clk		),
.rd_en       (tx_req    		),          //fifo��ʹ��
.dout        (tx_data   		),          //fifo������

.empty       (empty				),
.full        (full				),

.rd_data_count(rd_data_count	),
.wr_data_count(wr_data_count	)
);
	
//GMII�ӿ�תRGMII�ӿ�
gmii_to_rgmii 
    #(
     .IDELAY_VALUE (IDELAY_VALUE)
     )
    u_gmii_to_rgmii(
    .idelay_clk    (clk_200M    ),

    .gmii_rx_clk   (gmii_rx_clk ),
    .gmii_rx_dv    (gmii_rx_dv  ),
    .gmii_rxd      (gmii_rxd    ),
    .gmii_tx_clk   (gmii_tx_clk ),
    .gmii_tx_en    (gmii_tx_en  ),
    .gmii_txd      (gmii_txd    ),
    
    .rgmii_rxc     (eth_rxc     ),
    .rgmii_rx_ctl  (eth_rx_ctl  ),
    .rgmii_rxd     (eth_rxd     ),
    .rgmii_txc     (eth_txc     ),
    .rgmii_tx_ctl  (eth_tx_ctl  ),
    .rgmii_txd     (eth_txd     )
    );


udp                                             
   #(
    .BOARD_MAC     (BOARD_MAC),      //��������
    .BOARD_IP      (BOARD_IP ),
    .DES_MAC       (DES_MAC  ),
    .DES_IP        (DES_IP   )
    )
   u_udp(
    .rst_n         (I_rst_n     ),  
    
    .gmii_rx_clk   (gmii_rx_clk ),           
    .gmii_rx_dv    (gmii_rx_dv  ),         
    .gmii_rxd      (gmii_rxd    ),                   
    .gmii_tx_clk   (gmii_tx_clk ), 
    .gmii_tx_en    (gmii_tx_en),         
    .gmii_txd      (gmii_txd),  

    .rec_pkt_done  (rec_pkt_done),    
    .rec_en        (rec_en      ),     
    .rec_data      (rec_data    ),         
    .rec_byte_num  (rec_byte_num),      
    .tx_start_en   (tx_start_en ),        
    .tx_data       (tx_data     ),         
    .tx_byte_num   (tx_byte_num ),  
    .des_mac       (48'b0       ),
    .des_ip        (32'b0       ),    
    .tx_done       (udp_tx_done ),        
    .tx_req        (tx_req      )           
    ); 
endmodule
