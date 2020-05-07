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
module qspi_control
(
    input                I_clk               , //系统时钟
    input                I_rst_n             , //系统复位，低电平有效 
    
	input                W_done_sig		     , //命令完成脉冲信号
	input        [7:0]   W_read_data 		 ,
	input      			 wr_req              ,
	
	output  reg          R_clk_25M           , //25M时钟，由50M系统时钟二分频
	output  reg  [4:0]   R_cmd_type          , //命令类型
	output  reg  [7:0]   R_flash_cmd		 ,
	output  reg	 [23:0]  R_flash_addr		 ,
	output  reg  [15:0]  R_status_reg        , //输入状态寄存器的值
	output  reg  [7:0]   R_test_vec            //测试向量，决定写0还是写1  	 
);
     
(*KEEP = "TRUE"*)reg [3:0]   R_state             ;
(*KEEP = "TRUE"*)reg [23:0]  R_addr_cnt          ;//地址计数
   
          
     
//功能：二分频逻辑          
////////////////////////////////////////////////////////////////////          
always @(posedge I_clk or negedge I_rst_n)
begin
    if(!I_rst_n) 
        R_clk_25M   <=  1'b0        ;
    else 
        R_clk_25M   <=  ~R_clk_25M  ;
end
////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////
//功能：测试状态机
////////////////////////////////////////////////////////////////////
always @(posedge R_clk_25M or negedge I_rst_n)
begin
    if(!I_rst_n) 
        begin
            R_state         <=  4'd0        ;
            R_flash_addr    <=  24'd0       ;
            R_flash_cmd     <=  8'h00       ;
            R_cmd_type      <=  5'b0_0000   ;
			R_status_reg    <=  16'hffff    ;
			R_addr_cnt      <=  24'd0       ;
			R_test_vec      <=  8'b0        ;
        end
     else 
        begin
            case(R_state)                                      
				4'd0://写非易失配置寄存器(WRITE NONVOLATILE CONFIGU-RATION REGISTER)指令，用来把QE(Quad Enable)位置0
                    begin
                        if(W_done_sig) 
                            begin 
                                R_flash_cmd <= 8'h00            ; 
                                R_state     <= R_state + 1'b1   ; 
                                R_cmd_type  <= 5'b0_0000        ; 
                            end
                        else 
                            begin
                                R_flash_cmd <= 8'hB1            ; 
                                R_cmd_type  <= 5'b1_0110        ; 
                                R_status_reg<= 16'hafe7         ;//1010_1111_1110_0111
                            end
                    end 
                4'd1://写使能(Write Enable)指令
                    begin
                        if(W_done_sig) 
                            begin 
                                R_flash_cmd <= 8'h00            ; 
                                R_state     <= R_state + 1'b1   ; 
                                R_cmd_type  <= 5'b0_0000        ; 
                            end
                        else 
                            begin
                                R_flash_cmd <= 8'h06            ; 
                                R_cmd_type  <= 5'b1_0001        ; 
                            end
                    end             
                4'd2: //四线模式页编程操作(Quad Page Program): 将地址24'd0至24'd255都写0
                    begin
                        if(W_done_sig) 
                            begin 
                                R_flash_cmd <= 8'h00            ; 
                                R_state     <= R_state + 1'b1   ; 
                                R_cmd_type  <= 5'b0_0000        ;
								R_test_vec  <= 8'b0             ;
                            end
                        else 
                            begin 
                                R_flash_cmd <= 8'h32            ; 
                                R_flash_addr<= R_addr_cnt       ; 
                                R_cmd_type  <= 5'b1_1000        ;
								R_test_vec  <= 8'b0             ;//写一个字节的0
                            end
                    end
                4'd3://读状态寄存器, 当Busy位(状态寄存器的最低位)为0时表示写操作完成
                    begin
                        if(W_done_sig) 
                            begin 
                                if(W_read_data[0]==1'b0) 
                                    begin
										if(R_addr_cnt < 256)
											begin
												R_flash_cmd <= 8'h00            ; 
												R_addr_cnt  <= R_addr_cnt + 1   ;//写一字节完成后，地址+1
												R_state     <= R_state - 1'b1   ;//并回到上一状态继续写入
												R_cmd_type  <= 5'b0_0000        ; 
											end
										else
											begin
												R_addr_cnt  <= 0                 ;
												R_state     <= R_state + 1'b1    ;//从低到高全部写完，进入下一状态
											end
                                    end
                                else 
                                    begin 
                                        R_flash_cmd <= 8'h05        ; 
                                        R_cmd_type  <= 5'b1_0011    ; 
                                    end
                            end
                        else 
                            begin 
                                R_flash_cmd <= 8'h05        ; 
                                R_cmd_type  <= 5'b1_0011    ; 
                            end
                    end           
                4'd6://四线模式地址从低到高读0
                    begin
						if(wr_req)
							begin
								if(W_done_sig) 
									begin								
										if (R_addr_cnt < 256)
											begin
											R_addr_cnt <= R_addr_cnt + 1 ;
											R_state    <= R_state        ;
											end
										else
											begin
												R_flash_cmd <= 8'h00            ; 
												R_state     <= R_state + 1'b1   ;
												R_cmd_type  <= 5'b0_0000        ; 
												R_addr_cnt  <= 24'b0            ;
											end
									end
								else 
									begin 
										R_flash_cmd <= 8'h6B            ; 
										R_flash_addr<= R_addr_cnt       ; 
										R_cmd_type  <= 5'b1_1001        ; 
									end
							end
						else
							begin
								R_flash_cmd <= 8'h00            ; 
								R_state     <= R_state          ;
								R_cmd_type  <= 5'b0_0000        ; 
								R_addr_cnt  <= R_addr_cnt       ;
							end
                    end        
                4'd7:// 结束状态
                    begin
                        R_flash_cmd <= 8'h00            ; 
                        R_state     <= 4'd10            ;
                        R_cmd_type  <= 5'b0_0000        ; 
                    end
                default :   R_state     <= 4'd0         ;
            endcase
        end           
end 

endmodule
