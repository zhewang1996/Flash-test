`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:37:43 11/29/2019 
// Design Name: 
// Module Name:    QUAD_qspi_driver 
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
module qspi_driver(
output                  O_qspi_clk          , // QSPI Flash Quad SPI(QPI)总线串行时钟线
output reg              O_qspi_cs           , // QPI总线片选信号
inout                   IO_qspi_io0         , // QPI总线输入/输出信号线
inout                   IO_qspi_io1         , // QPI总线输入/输出信号线
inout                   IO_qspi_io2         , // QPI总线输入/输出信号线
inout                   IO_qspi_io3         , // QPI总线输入/输出信号线
                                            
input                   I_rst_n             , // 复位信号

input                   I_clk_25M           , // 25MHz时钟信号
input       [4:0]       I_cmd_type          , // 命令类型
input       [7:0]       I_cmd_code          , // 命令码
input       [23:0]      I_qspi_addr         , // QSPI Flash地址
input       [15:0]      I_status_reg        , // QSPI Flash状态寄存器的值
input       [7:0]       I_test_vec          , // 测试向量

output reg              O_done_sig          , // 指令执行结束标志
output reg  [7:0]       O_read_data         , // 从QSPI Flash读出的数据
output reg              O_read_byte_valid   , // 读一个字节完成的标志
output reg  [3:0]       O_qspi_state          // 状态机，用于在顶层调试用
);


parameter   C_IDLE            =   4'b0000  ; // 0_空闲状态
parameter   C_SEND_CMD        =   4'b0001  ; // 1_发送命令码
parameter   C_SEND_ADDR       =   4'b0010  ; // 2_发送地址码
parameter   C_READ_WAIT       =   4'b0011  ; // 3_单线模式读等待
parameter   C_WRITE_DATA      =   4'b0100  ; // 4_单线模式写数据到QSPI Flash
parameter   C_WRITE_STATE_REG =   4'b0101  ; // 5_写状态寄存器
parameter   C_WRITE_DATA_QUAD =   4'b0110  ; // 6_四线模式写数据到QSPI Flash
parameter   C_DUMMY           =   4'b0111  ; // 7_四线模式读数据需要10个时钟周期的dummy clock，这可以加快读数据的速度
parameter   C_READ_WAIT_QUAD  =   4'b1001  ; // 8_四线模式读等待状态
parameter   C_FINISH_DONE     =   4'b1010  ; // 9_一条指令执行结束


// QSPI Flash IO输入输出状态控制寄存器
reg         R_qspi_io0          ;
reg         R_qspi_io1          ;
reg         R_qspi_io2          ;
reg         R_qspi_io3          ;          
reg         R_qspi_io0_out_en   ;
reg         R_qspi_io1_out_en   ;
reg         R_qspi_io2_out_en   ;
reg         R_qspi_io3_out_en   ;

reg         [7:0]   R_read_data_reg     ; // 从Flash中读出的数据用这个变量进行缓存，等读完了在把这个变量的值给输出
reg                 R_qspi_clk_en       ; // 串行时钟使能信号
reg                 R_data_come_single  ; // 单线操作读数据使能信号，当这个信号为高时
reg                 R_data_come_quad    ; // 四线操作读数据使能信号，当这个信号为高时
            
reg         [7:0]   R_cmd_reg           ; // 命令码寄存器
reg         [23:0]  R_address_reg       ; // 地址码寄存器 
reg         [15:0]  R_status_reg        ; // 状态寄存器

reg         [7:0]   R_write_bits_cnt    ; // 写bit计数器，写数据之前把它初始化为7，发送一个bit就减1
reg         [8:0]   R_write_bytes_cnt   ; // 写字节计数器，发送一个字节数据就把它加1
reg         [7:0]   R_read_bits_cnt     ; // 写bit计数器，接收一个bit就加1
reg         [8:0]   R_read_bytes_cnt    ; // 读字节计数器，接收一个字节数据就把它加1
reg         [8:0]   R_read_bytes_num    ; // 要接收的数据总数
reg                 R_read_finish       ; // 读数据结束标志位

//wire        [7:0]   W_rom_addr          ;  


assign O_qspi_clk = R_qspi_clk_en ? I_clk_25M : 0   ; // 产生串行时钟信号
//assign W_rom_addr = R_write_bytes_cnt               ;

// QSPI IO方向控制
assign IO_qspi_io0     =   R_qspi_io0_out_en ? R_qspi_io0 : 1'bz ;                
assign IO_qspi_io1     =   R_qspi_io1_out_en ? R_qspi_io1 : 1'bz ;                
assign IO_qspi_io2     =   R_qspi_io2_out_en ? R_qspi_io2 : 1'bz ;                
assign IO_qspi_io3     =   R_qspi_io3_out_en ? R_qspi_io3 : 1'bz ; 
////////////////////////////////////////////////////////////////////////////////////////////
// 功能：用时钟的下降沿发送数据
////////////////////////////////////////////////////////////////////////////////////////////
always @(negedge I_clk_25M or negedge I_rst_n)
begin
    if(!I_rst_n)
        begin
            O_qspi_cs           <=  1'b1   ;        
            O_qspi_state        <=  C_IDLE ;
            R_cmd_reg           <=  0      ;
            R_address_reg       <=  0      ;
            R_qspi_clk_en       <=  1'b0   ;  //QSPI clock输出不使能
            R_write_bits_cnt    <=  0      ;
            R_write_bytes_cnt   <=  0      ;
            R_read_bytes_num    <=  0      ;    
            R_address_reg       <=  0      ;
            O_done_sig          <=  1'b0   ;
            R_data_come_single  <=  1'b0   ;           
            R_data_come_quad      <=  1'b0   ;           
        end
    else
        begin
            case(O_qspi_state)
                C_IDLE:  // 初始化各个寄存器，当检测到命令类型有效(命令类型的最高位位1)以后,进入发送命令码状态
                    begin                              
                        R_qspi_clk_en          <=   1'b0         ;
                        O_qspi_cs              <=   1'b1         ;
                        R_qspi_io0             <=   1'b0         ;    
                        R_cmd_reg              <=   I_cmd_code   ;
                        R_address_reg          <=   I_qspi_addr  ;
                        R_status_reg           <=   I_status_reg ;
                        O_done_sig             <=   1'b0         ;
                        R_qspi_io3_out_en   <=   1'b0         ; // 设置IO_qspi_io3为高阻
                        R_qspi_io2_out_en   <=   1'b0         ; // 设置IO_qspi_io2为高阻
                        R_qspi_io1_out_en   <=   1'b0         ; // 设置IO_qspi_io1为高阻
                        R_qspi_io0_out_en   <=   1'b0         ; // 设置IO_qspi_io0为高阻
                        if(I_cmd_type[4] == 1'b1) 
                            begin                //如果flash操作命令请求
                                O_qspi_state        <=  C_SEND_CMD  ;
                                R_write_bits_cnt    <=  7           ;        
                                R_write_bytes_cnt   <=  0           ;
                                R_read_bytes_num    <=  0           ;                    
                            end
                    end
                C_SEND_CMD: // 发送8-bit命令码状态 
                    begin
                        R_qspi_io0_out_en   <=  1'b1    ; // 设置IO_qspi_io0为输出
                        R_qspi_clk_en       <=  1'b1    ; // 打开SPI串行时钟SCLK的使能开关
                        O_qspi_cs           <=  1'b0    ; // 拉低片选信号CS
                        if(R_write_bits_cnt > 0) 
                            begin                           //如果R_cmd_reg还没有发送完
                                R_qspi_io0            <=  R_cmd_reg[R_write_bits_cnt] ;         //发送bit7~bit1位
                                R_write_bits_cnt       <=  R_write_bits_cnt-1'b1       ;
                            end                            
                        else 
                            begin                                 //发送bit0
                                R_qspi_io0 <=  R_cmd_reg[0]    ;
                                if ((I_cmd_type[3:0] == 4'b0001) | (I_cmd_type[3:0] == 4'b0100)) 
                                    begin    //如果是写使能指令(Write Enable)或者写不使能指令(Write Disable)
                                        O_qspi_state    <=  C_FINISH_DONE   ;
                                    end
								else if (I_cmd_type[3:0] == 4'b0000) 
                                    begin    //如果是读设备ID指令(Read Device ID)
                                        O_qspi_state        <=  C_READ_WAIT ;
                                        R_write_bits_cnt    <=  7           ;
                                        R_read_bytes_num    <=  21          ;//读设备ID指令需要接收20个字节数据		
									end	
                                else if (I_cmd_type[3:0] == 4'b0011) 
                                    begin    //如果是读状态寄存器指令(Read Register)
                                        O_qspi_state        <=  C_READ_WAIT ;
                                        R_write_bits_cnt    <=  7           ;
                                        R_read_bytes_num    <=  1           ;//读状态寄存器指令需要接收一个字节数据 
                                    end
								else if (I_cmd_type[3:0] == 4'b1010) 
                                    begin    //如果是读非易失性配置寄存器
                                        O_qspi_state        <=  C_READ_WAIT ;
                                        R_write_bits_cnt    <=  7           ;
                                        R_read_bytes_num    <=  2           ;//读状态寄存器指令需要接收两个字节数据 
                                    end		
                                else if( (I_cmd_type[3:0] == 4'b0010) ||  // 如果是扇区擦除(Sector Erase)
                                         (I_cmd_type[3:0] == 4'b0101) ||  // 如果是页编程指令(Page Program)
                                         (I_cmd_type[3:0] == 4'b0111) ||  // 如果是读数据指令(Read Data)
                                         (I_cmd_type[3:0] == 4'b1000) ||  // 如果是四线模式页编程指令(Quad Page Program)
                                         (I_cmd_type[3:0] == 4'b1001)     // 如果是四线模式读数据指令(Quad Read Data)
                                        ) 
                                    begin                          
                                        O_qspi_state        <=  C_SEND_ADDR ;
                                        R_write_bits_cnt    <=  23          ; // 这几条指令后面都需要跟一个24-bit的地址码
                                    end
                                else if (I_cmd_type[3:0] == 4'b0110) 
                                    begin    //如果是写非易失性配置寄存器
                                        O_qspi_state        <=  C_WRITE_STATE_REG   ;
                                        R_write_bits_cnt    <=  15                  ;
                                    end 
                            end
                    end
                C_WRITE_STATE_REG   :
                    begin
                        R_qspi_io0_out_en   <=  1'b1    ;   // 设置IO0为输出
                        if(R_write_bits_cnt > 0)  
                            begin                           //如果R_cmd_reg还没有发送完
                                R_qspi_io0         <=  R_status_reg[R_write_bits_cnt] ;   //发送bit15~bit1位
                                R_write_bits_cnt   <=  R_write_bits_cnt    -   1      ;    
                            end                                 
                        else 
                            begin                                        //发送bit0
                                R_qspi_io0      <=  R_status_reg[0]    ;   
                                O_qspi_state    <=  C_FINISH_DONE      ;                                          
                            end                            
                    end 
                C_SEND_ADDR: // 发送地址状态
                    begin
                        R_qspi_io0_out_en   <=  1'b1    ;
                        if(R_write_bits_cnt > 0)  //如果R_cmd_reg还没有发送完
                            begin                                 
                                R_qspi_io0            <=  R_address_reg[R_write_bits_cnt] ; //发送bit23~bit1位
                                R_write_bits_cnt       <=  R_write_bits_cnt    -   1       ;    
                            end                                 
                        else 
                            begin 
                                R_qspi_io0 <=  R_address_reg[0]    ;   //发送bit0
                                if(I_cmd_type[3:0] == 4'b0010) // 扇区擦除(Sector Erase)指令
                                    begin  //扇区擦除(Sector Erase)指令发完24-bit地址码就执行结束了，所以直接跳到结束状态
                                        O_qspi_state <= C_FINISH_DONE   ;    
                                    end
                                else if (I_cmd_type[3:0] == 4'b0101) // 页编程(Page Program)指令,页编程指令和写数据指令是一个意思
                                    begin                              
                                        O_qspi_state        <=  C_WRITE_DATA    ;
                                        R_write_bits_cnt    <=  7               ;                       
                                    end                                                        
                                else if (I_cmd_type[3:0] == 4'b0111) // 读数据(Read Data)指令
                                    begin
                                        O_qspi_state        <=  C_READ_WAIT     ;
                                        R_read_bytes_num    <=  1               ;   //接收1个数据        
                                    end 
                                else if (I_cmd_type[3:0] == 4'b1000) 
                                    begin   //如果是四线模式页编程指令(Quad Page Program)                               
                                        O_qspi_state        <=  C_WRITE_DATA_QUAD   ;
                                        R_write_bits_cnt    <=  7                   ;                       
                                    end 
                                else if (I_cmd_type[3:0] == 4'b1001) 
                                    begin   //如果是四线读操作                               
                                        O_qspi_state        <=  C_DUMMY         ;
                                        R_read_bytes_num    <=  1               ; //接收1个数据    
                                        R_write_bits_cnt    <=  9               ; //10个dummy clock                    
                                    end 
                            end
                    end 
                C_DUMMY:  // 四线读操作之前需要等待10个dummy clock
                    begin  
                        R_qspi_io3_out_en   <=  1'b0            ; // 设置IO_qspi_io3为高阻
                        R_qspi_io2_out_en   <=  1'b0            ; // 设置IO_qspi_io2为高阻
                        R_qspi_io1_out_en   <=  1'b0            ; // 设置IO_qspi_io1为高阻
                        R_qspi_io0_out_en   <=  1'b0            ; // 设置IO_qspi_io0为高阻       
                        if(R_write_bits_cnt > 0)    
                            R_write_bits_cnt    <=  R_write_bits_cnt - 1 ;                                    
                        else 
                            O_qspi_state        <=  C_READ_WAIT_QUAD     ;                                          
                    end   
                C_READ_WAIT: // 单线模式读等待状态
                    begin
                        if(R_read_finish)  
                            begin
                                O_qspi_state        <=  C_FINISH_DONE   ;
                                R_data_come_single  <=  1'b0            ;
                            end
                        else
                            begin
                                R_data_come_single  <=  1'b1            ; // 单线模式下读数据标志信号，此信号为高标志正在接收数据
                                R_qspi_io1_out_en   <=  1'b0            ;
                            end
                    end
                C_READ_WAIT_QUAD: // 四线模式读等待状态
                    begin
                        if(R_read_finish)  
                            begin
                                O_qspi_state        <=  C_FINISH_DONE   ;
                                R_data_come_quad    <=  1'b0            ;
                            end
                        else
                            R_data_come_quad        <=  1'b1            ;
                    end
                C_WRITE_DATA: // 写数据状态
                    begin
                        if(R_write_bytes_cnt < 1) // 往QSPI Flash中写入 1 个数据
                            begin                       
                                if(R_write_bits_cnt > 0) //如果数据还没有发送完
                                    begin                           
                                        R_qspi_io0             <=  I_test_vec[R_write_bits_cnt] ; //发送bit7~bit1位
                                        R_write_bits_cnt    <=  R_write_bits_cnt  - 1'b1    ;                        
                                    end                 
                                else 
                                    begin                                 
                                        R_qspi_io0             <=  I_test_vec[0]                ; //发送bit0
                                        R_write_bits_cnt    <=  7                           ;
                                        R_write_bytes_cnt   <=  R_write_bytes_cnt + 1'b1    ;
                                    end
                            end
                        else 
                            begin
                                O_qspi_state    <=  C_FINISH_DONE   ;
                                R_qspi_clk_en   <=  1'b0            ;
                            end
                    end
                C_WRITE_DATA_QUAD    ://写数据操作(四线模式)
                    begin
                        R_qspi_io0_out_en   <=  1'b1    ;   // 设置IO0为输出
                        R_qspi_io1_out_en   <=  1'b1    ;   // 设置IO1为输出
                        R_qspi_io2_out_en   <=  1'b1    ;   // 设置IO2为输出
                        R_qspi_io3_out_en   <=  1'b1    ;   // 设置IO3为输出                          
                        if(R_write_bytes_cnt == 9'd1)
                            begin
                                O_qspi_state   <=  C_FINISH_DONE    ;    
                                R_qspi_clk_en  <=  1'b0             ; 
                            end 
                        else
                            begin      
                                if(R_write_bits_cnt == 8'd3)
                                    begin
                                        R_write_bytes_cnt   <=  R_write_bytes_cnt + 1'b1         ;
                                        R_write_bits_cnt    <=  8'd7                             ;
                                        R_qspi_io3          <=  I_test_vec[3]                     ; // 分别发送bit3
                                        R_qspi_io2          <=  I_test_vec[2]                     ; // 分别发送bit2
                                        R_qspi_io1          <=  I_test_vec[1]                     ; // 分别发送bit1
                                        R_qspi_io0          <=  I_test_vec[0]                     ; // 分别发送bit0
                                    end
                                else
                                    begin
                                        R_write_bits_cnt    <=  R_write_bits_cnt - 4            ;
                                        R_qspi_io3          <=  I_test_vec[R_write_bits_cnt - 0] ; // 分别发送bit7
                                        R_qspi_io2          <=  I_test_vec[R_write_bits_cnt - 1] ; // 分别发送bit6
                                        R_qspi_io1          <=  I_test_vec[R_write_bits_cnt - 2] ; // 分别发送bit5
                                        R_qspi_io0          <=  I_test_vec[R_write_bits_cnt - 3] ; // 分别发送bit4
                                    end 
                            end                                            
                    end 
                C_FINISH_DONE:
                    begin
                        O_qspi_cs           <=  1'b1    ;
                        R_qspi_io0          <=  1'b0    ;
                        R_qspi_clk_en       <=  1'b0    ;
                        O_done_sig          <=  1'b1    ;
                        R_qspi_io3_out_en   <=  1'b0    ; // 设置IO_qspi_io3为高阻
                        R_qspi_io2_out_en   <=  1'b0    ; // 设置IO_qspi_io2为高阻
                        R_qspi_io1_out_en   <=  1'b0    ; // 设置IO_qspi_io1为高阻
                        R_qspi_io0_out_en   <=  1'b0    ; // 设置IO_qspi_io0为高阻
                        R_data_come_single  <=  1'b0    ;
                        R_data_come_quad    <=  1'b0    ;
                        O_qspi_state        <=  C_IDLE  ;
                    end
                default:O_qspi_state    <=  C_IDLE      ;
            endcase         
        end
end

//////////////////////////////////////////////////////////////////////////////
// 功能：接收QSPI Flash发送过来的数据    
//////////////////////////////////////////////////////////////////////////////
always @(posedge I_clk_25M)
begin
    if(!I_rst_n)
        begin
            R_read_bytes_cnt    <=  0       ;
            R_read_bits_cnt     <=  0       ;
            R_read_finish       <=  1'b0    ;
            O_read_byte_valid   <=  1'b0    ;
            R_read_data_reg     <=  0       ;
            O_read_data         <=  0       ;
        end
    else if(R_data_come_single)   // 此信号为高表示接收数据从QSPI Flash发过来的数据
        begin
            if(R_read_bytes_cnt < R_read_bytes_num) 
                begin            
                    if(R_read_bits_cnt < 7)  //接收一个Byte的bit0~bit6    
                        begin                         
                            O_read_byte_valid   <=  1'b0                               ;
                            R_read_data_reg     <=  {R_read_data_reg[6:0],IO_qspi_io1} ;
                            R_read_bits_cnt     <=  R_read_bits_cnt +   1'b1           ;
                        end
                    else  
                        begin
                            O_read_byte_valid   <=  1'b1                               ;  //一个byte数据有效
                            O_read_data         <=  {R_read_data_reg[6:0],IO_qspi_io1} ;  //接收bit7
                            R_read_bits_cnt     <=  0                                  ;
                            R_read_bytes_cnt    <=  R_read_bytes_cnt    +   1'b1       ;
                        end
                end                               
            else 
                begin 
                    R_read_bytes_cnt    <=  0       ;
                    R_read_finish       <=  1'b1    ;
                    O_read_byte_valid   <=  1'b0    ;
                end
        end 
    else if(R_data_come_quad)   
        begin
            if(R_read_bytes_cnt < R_read_bytes_num) 
                begin  //接收数据              
                    if(R_read_bits_cnt < 8'd1)
                        begin
                            O_read_byte_valid       <=  1'b0                    ;
                            R_read_data_reg         <=  {R_read_data_reg[3:0],IO_qspi_io3,IO_qspi_io2,IO_qspi_io1,IO_qspi_io0};//接收前四位
                            R_read_bits_cnt         <=  R_read_bits_cnt + 1     ; 
                        end
                    else    
                        begin
                            O_read_byte_valid       <=  1'b1                    ;
                            O_read_data             <=  {R_read_data_reg[3:0],IO_qspi_io3,IO_qspi_io2,IO_qspi_io1,IO_qspi_io0};  //接收后四位
                            R_read_bits_cnt         <=  0                       ;
                            R_read_bytes_cnt        <=  R_read_bytes_cnt + 1'b1 ;     
                        end
                end                               
            else 
                begin 
                    R_read_bytes_cnt    <=  0       ;
                    R_read_finish       <=  1'b1    ;
                    O_read_byte_valid   <=  1'b0    ;
                end
        end
    else 
        begin
            R_read_bytes_cnt    <=  0       ;
            R_read_bits_cnt     <=  0       ;
            R_read_finish       <=  1'b0    ;
            O_read_byte_valid   <=  1'b0    ;
            R_read_data_reg     <=  0       ;
        end
end         


endmodule
