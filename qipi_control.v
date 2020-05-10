module qspi_control
(
    input                clk_25M             , //25M时钟
    input                I_rst_n             , //系统复位，低电平有效 
    
	input                W_done_sig		     , //命令完成脉冲信号
	input        [7:0]   W_read_data 		 ,
	
	output  reg  [4:0]   R_cmd_type          , //命令类型
	output  reg  [7:0]   R_flash_cmd		 ,
	output  reg	 [23:0]  R_flash_addr		 ,
	output  reg  [15:0]  R_status_reg        , //输入状态寄存器的值
	output  reg  [7:0]   R_test_vec            //测试向量，决定写0还是写1  	 
);
     
(* mark_debug = "true" *)reg [3:0]   R_state             ;
reg [23:0]  R_addr_cnt          ;//地址计数
   
          
////////////////////////////////////////////////////////////////////
//功能：测试状态机
////////////////////////////////////////////////////////////////////
always @(posedge clk_25M or negedge I_rst_n)
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
				4'd0://读Device ID指令
                    begin
                        if(W_done_sig) 
                            begin 
                                R_flash_cmd <= 8'h00            ; 
                                R_state     <= R_state + 1'b1   ; 
                                R_cmd_type  <= 5'b0_0000        ; 
                            end
                        else 
                            begin 
                                R_flash_cmd  <= 8'h9F           ; 
                                R_flash_addr <= 24'd0           ; 
                                R_cmd_type   <= 5'b1_0000       ; 
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
                4'd2:// 扇区擦除(Sector Erase)指令
                    begin
                        if(W_done_sig) 
                            begin 
                                R_flash_cmd <= 8'h00            ; 
                                R_state     <= R_state + 1'b1   ; 
                                R_cmd_type  <= 5'b0_0000        ; 
                            end
                        else 
                            begin 
                                R_flash_cmd <= 8'hD8            ; 
                                R_flash_addr<= 24'd0            ; 
                                R_cmd_type  <= 5'b1_0010        ; 
                            end
                    end            
                4'd3://读状态寄存器, 当Busy位(状态寄存器1的最低位)为0时表示擦除操作完成
                    begin
                        if(W_done_sig) 
                            begin 
                                if(W_read_data[0]==1'b0) 
                                    begin 
                                        R_flash_cmd <= 8'h00            ; 
                                        R_state     <= R_state + 1'b1   ;
                                        R_cmd_type  <= 5'b0_0000        ; 
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
				4'd4://写非易失配置寄存器(WRITE NONVOLATILE CONFIGU-RATION REGISTER)指令，用来把QE(Quad Enable)位置0
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
                4'd5://写使能(Write Enable)指令
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
                4'd6: //四线模式页编程操作(Quad Page Program): 将地址24'd0至24'd2048都写0
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
                4'd7://读状态寄存器, 当Busy位(状态寄存器的最低位)为0时表示写操作完成
                    begin
                        if(W_done_sig) 
                            begin 
                                if(W_read_data[0]==1'b0) 
                                    begin
										if(R_addr_cnt < 24'd2048)
											begin
												R_flash_cmd <= 8'h00            ; 
												R_addr_cnt  <= R_addr_cnt + 256 ;//写一字节完成后，地址+256
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
                4'd8://单线模式地址从低到高读0
                    begin
						if(W_done_sig) 
							begin								
								if (R_addr_cnt < 24'd2048)
									begin
									R_addr_cnt <= R_addr_cnt + 256 ;
									R_state    <= R_state          ;
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
								R_flash_cmd <= 8'h02            ; 
								R_flash_addr<= R_addr_cnt       ; 
								R_cmd_type  <= 5'b1_0101        ; 
							end
                    end        
                4'd9:// 结束状态
                    begin
                        R_flash_cmd <= 8'h00            ; 
                        R_state     <= 4'd0            	;
                        R_cmd_type  <= 5'b0_0000        ; 
                    end
                default :   R_state     <= 4'd0         ;
            endcase
        end           
end 

endmodule
