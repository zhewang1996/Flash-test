module qspi_top
(
    input         I_clk         , //50MHz系统时钟
    input         rst           , //系统复位
	
    input         eth_rxc   	, //RGMII接收数据时钟
    input         eth_rx_ctl	, //RGMII输入数据有效信号
    input  [3:0]  eth_rxd   	, //RGMII输入数据
    output        eth_txc   	, //RGMII发送数据时钟    
    output        eth_tx_ctl	, //RGMII输出数据有效信号
    output [3:0]  eth_txd   	, //RGMII输出数据          
    output        eth_rst_n 	,//以太网芯片复位信号，低电平有效 

    output        O_qspi_clk    , // QPI总线串行时钟线
    output        O_qspi_cs     , // QPI总线片选信号
    inout         IO_qspi_io0   , // QPI总线输入/输出信号线
    inout         IO_qspi_io1   , // QPI总线输入/输出信号线
    inout         IO_qspi_io2   , // QPI总线输入/输出信号线
    inout         IO_qspi_io3     // QPI总线输入/输出信号线  
);

//parameter define
//开发板MAC地址 00-11-22-33-44-55
parameter  BOARD_MAC = 48'h00_11_22_33_44_55;     
//开发板IP地址 192.168.1.10
parameter  BOARD_IP  = {8'd192,8'd168,8'd1,8'd10};  
//目的MAC地址 ff_ff_ff_ff_ff_ff
parameter  DES_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//目的IP地址 192.168.1.102     
parameter  DES_IP    = {8'd192,8'd168,8'd1,8'd102};  
//输入数据IO延时,此处为0,即不延时(如果为n,表示延时n*78ps) 
parameter IDELAY_VALUE = 16;

(* mark_debug = "true" *)wire          	I_rst_n          	;// 系统复位
(* mark_debug = "true" *)wire          	clk_25M          	;// 25MHz全局时钟
wire          	clk_200M         	;// 用于IO延时的时钟(IDELAYCTRL原语的参考时钟频率)    
wire          	W_done_sig       	;// 指令执行结束标志
(* mark_debug = "true" *)wire [7:0]    	W_read_data      	;// 从QSPI Flash读出的数据
wire          	W_read_byte_valid	;// 读一个字节完成的标志
(* mark_debug = "true" *)wire [3:0]		W_qspi_state	 	;//	状态机，用于在顶层调用
wire [4:0]    	R_cmd_type       	;// 命令类型
(* mark_debug = "true" *)wire [7:0]    	R_flash_cmd 		;//	命令码
(* mark_debug = "true" *)wire [23:0]   	R_flash_addr		;//	Flash地址
wire [15:0]   	R_status_reg     	;// 输入状态寄存器的值
wire [7:0]    	R_test_vec       	;// 测试向量，决定写0还是写1
	
wire          	gmii_rx_clk; //GMII接收时钟
wire          	gmii_rx_dv ; //GMII接收数据有效信号
wire  [7:0]   	gmii_rxd   ; //GMII接收数据
wire          	gmii_tx_clk; //GMII发送时钟
wire          	gmii_tx_en ; //GMII发送数据使能信号
wire  [7:0]   	gmii_txd   ; //GMII发送数据     
	
wire          	rec_pkt_done  ; //UDP单包数据接收完成信号
wire          	rec_en        ; //UDP接收的数据使能信号
wire  [31:0]  	rec_data      ; //UDP接收的数据
wire  [15:0]  	rec_byte_num  ; //UDP接收的有效字节数 单位:byte 
wire  [15:0]  	tx_byte_num   ; //UDP发送的有效字节数 单位:byte 
wire          	udp_tx_done   ; //UDP发送完成信号
(* mark_debug = "true" *)wire          	tx_req        ; //UDP读数据请求信号
(* mark_debug = "true" *)wire  [31:0]  	tx_data       ; //UDP待发送数据	
(* mark_debug = "true" *)wire  			tx_start_en	  ;								 
	
wire 		  	rd_rst			;//FIFO读复位信号
wire			wr_rst			;//FIFO写复位信号
(* mark_debug = "true" *)wire  [8:0]		rd_data_count	;
wire  [10:0]	wr_data_count	;
wire          	rd_req    		;//读数据请求信号
wire          	wr_req			;//写数据请求信号
wire          	empty	    	;//读空信号	
wire		  	full	    	;//写满信号
wire 			locked			;
 
assign  eth_rst_n = 1'b1	;//复位信号一直拉高
assign  tx_byte_num = 16'd1024;	//一次UPD模块发送1024个字节

////功能：复位键消抖
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
.O_qspi_clk          (O_qspi_clk        ), // QPI总线串行时钟线
.O_qspi_cs           (O_qspi_cs         ), // QPI总线片选信号
.IO_qspi_io0         (IO_qspi_io0       ), // QPI总线输入/输出信号线
.IO_qspi_io1         (IO_qspi_io1       ), // QPI总线输入/输出信号线
.IO_qspi_io2         (IO_qspi_io2       ), // QPI总线输入/输出信号线
.IO_qspi_io3         (IO_qspi_io3       ), // QPI总线输入/输出信号线
                   
.I_rst_n             (I_rst_n & locked  ), // 复位信号

.I_clk_25M           (clk_25M           ), // 25MHz时钟信号
.I_cmd_type          (R_cmd_type        ), // 命令类型
.I_cmd_code          (R_flash_cmd       ), // 命令码
.I_qspi_addr         (R_flash_addr      ), // QSPI Flash地址
.I_status_reg        (R_status_reg      ), // QSPI Flash状态寄存器
.I_test_vec          (R_test_vec        ),

.O_done_sig          (W_done_sig        ), // 指令执行结束标志
.O_read_data         (W_read_data       ), // 从QSPI Flash读出的数据
.O_read_byte_valid   (W_read_byte_valid ), // 读一个字节完成的标志
.O_qspi_state        (W_qspi_state      )  // 状态机，用于在顶层调用
);

fifo_ctrl u_fifo_ctrl
(
.clk_25M	(clk_25M	),
.gmii_tx_clk(gmii_tx_clk),
.I_rst_n	(I_rst_n	),
.rd_rst		(rd_rst		),//系统复位信号同步至FIFO
.wr_rst		(wr_rst		),
.tx_start_en(tx_start_en),//以太网开始发送信号
.rd_data_count(rd_data_count)
); 

  
fifo_2048 u_fifo_2048
(
.rd_rst      (~rd_rst			),
.wr_rst      (~wr_rst			),

.wr_clk      (clk_25M			),          
.wr_en       (W_read_byte_valid ),          //fifo写使能
.din         (W_read_data   	),          //fifo写数据

.rd_clk      (gmii_tx_clk		),
.rd_en       (tx_req    		),          //fifo读使能
.dout        (tx_data   		),          //fifo读数据

.empty       (empty				),
.full        (full				),

.rd_data_count(rd_data_count	),
.wr_data_count(wr_data_count	)
);
	
//GMII接口转RGMII接口
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
    .BOARD_MAC     (BOARD_MAC),      //参数例化
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
