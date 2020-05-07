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
    input                I_clk               , //ϵͳʱ��
    input                I_rst_n             , //ϵͳ��λ���͵�ƽ��Ч 
    
	input                W_done_sig		     , //������������ź�
	input        [7:0]   W_read_data 		 ,
	input      			 wr_req              ,
	
	output  reg          R_clk_25M           , //25Mʱ�ӣ���50Mϵͳʱ�Ӷ���Ƶ
	output  reg  [4:0]   R_cmd_type          , //��������
	output  reg  [7:0]   R_flash_cmd		 ,
	output  reg	 [23:0]  R_flash_addr		 ,
	output  reg  [15:0]  R_status_reg        , //����״̬�Ĵ�����ֵ
	output  reg  [7:0]   R_test_vec            //��������������д0����д1  	 
);
     
(*KEEP = "TRUE"*)reg [3:0]   R_state             ;
(*KEEP = "TRUE"*)reg [23:0]  R_addr_cnt          ;//��ַ����
   
          
     
//���ܣ�����Ƶ�߼�          
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
//���ܣ�����״̬��
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
				4'd0://д����ʧ���üĴ���(WRITE NONVOLATILE CONFIGU-RATION REGISTER)ָ�������QE(Quad Enable)λ��0
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
                4'd1://дʹ��(Write Enable)ָ��
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
                4'd2: //����ģʽҳ��̲���(Quad Page Program): ����ַ24'd0��24'd255��д0
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
								R_test_vec  <= 8'b0             ;//дһ���ֽڵ�0
                            end
                    end
                4'd3://��״̬�Ĵ���, ��Busyλ(״̬�Ĵ��������λ)Ϊ0ʱ��ʾд�������
                    begin
                        if(W_done_sig) 
                            begin 
                                if(W_read_data[0]==1'b0) 
                                    begin
										if(R_addr_cnt < 256)
											begin
												R_flash_cmd <= 8'h00            ; 
												R_addr_cnt  <= R_addr_cnt + 1   ;//дһ�ֽ���ɺ󣬵�ַ+1
												R_state     <= R_state - 1'b1   ;//���ص���һ״̬����д��
												R_cmd_type  <= 5'b0_0000        ; 
											end
										else
											begin
												R_addr_cnt  <= 0                 ;
												R_state     <= R_state + 1'b1    ;//�ӵ͵���ȫ��д�꣬������һ״̬
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
                4'd6://����ģʽ��ַ�ӵ͵��߶�0
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
                4'd7:// ����״̬
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