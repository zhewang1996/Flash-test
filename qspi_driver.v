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
output                  O_qspi_clk          , // QSPI Flash Quad SPI(QPI)���ߴ���ʱ����
output reg              O_qspi_cs           , // QPI����Ƭѡ�ź�
inout                   IO_qspi_io0         , // QPI��������/����ź���
inout                   IO_qspi_io1         , // QPI��������/����ź���
inout                   IO_qspi_io2         , // QPI��������/����ź���
inout                   IO_qspi_io3         , // QPI��������/����ź���
                                            
input                   I_rst_n             , // ��λ�ź�

input                   I_clk_25M           , // 25MHzʱ���ź�
input       [4:0]       I_cmd_type          , // ��������
input       [7:0]       I_cmd_code          , // ������
input       [23:0]      I_qspi_addr         , // QSPI Flash��ַ
input       [15:0]      I_status_reg        , // QSPI Flash״̬�Ĵ�����ֵ
input       [7:0]       I_test_vec          , // ��������

output reg              O_done_sig          , // ָ��ִ�н�����־
output reg  [7:0]       O_read_data         , // ��QSPI Flash����������
output reg              O_read_byte_valid   , // ��һ���ֽ���ɵı�־
output reg  [3:0]       O_qspi_state          // ״̬���������ڶ��������
);


parameter   C_IDLE            =   4'b0000  ; // 0_����״̬
parameter   C_SEND_CMD        =   4'b0001  ; // 1_����������
parameter   C_SEND_ADDR       =   4'b0010  ; // 2_���͵�ַ��
parameter   C_READ_WAIT       =   4'b0011  ; // 3_����ģʽ���ȴ�
parameter   C_WRITE_DATA      =   4'b0100  ; // 4_����ģʽд���ݵ�QSPI Flash
parameter   C_WRITE_STATE_REG =   4'b0101  ; // 5_д״̬�Ĵ���
parameter   C_WRITE_DATA_QUAD =   4'b0110  ; // 6_����ģʽд���ݵ�QSPI Flash
parameter   C_DUMMY           =   4'b0111  ; // 7_����ģʽ��������Ҫ10��ʱ�����ڵ�dummy clock������Լӿ�����ݵ��ٶ�
parameter   C_READ_WAIT_QUAD  =   4'b1001  ; // 8_����ģʽ���ȴ�״̬
parameter   C_FINISH_DONE     =   4'b1010  ; // 9_һ��ָ��ִ�н���


// QSPI Flash IO�������״̬���ƼĴ���
reg         R_qspi_io0          ;
reg         R_qspi_io1          ;
reg         R_qspi_io2          ;
reg         R_qspi_io3          ;          
reg         R_qspi_io0_out_en   ;
reg         R_qspi_io1_out_en   ;
reg         R_qspi_io2_out_en   ;
reg         R_qspi_io3_out_en   ;

reg         [7:0]   R_read_data_reg     ; // ��Flash�ж���������������������л��棬�ȶ������ڰ����������ֵ�����
reg                 R_qspi_clk_en       ; // ����ʱ��ʹ���ź�
reg                 R_data_come_single  ; // ���߲���������ʹ���źţ�������ź�Ϊ��ʱ
reg                 R_data_come_quad    ; // ���߲���������ʹ���źţ�������ź�Ϊ��ʱ
            
reg         [7:0]   R_cmd_reg           ; // ������Ĵ���
reg         [23:0]  R_address_reg       ; // ��ַ��Ĵ��� 
reg         [15:0]  R_status_reg        ; // ״̬�Ĵ���

reg         [7:0]   R_write_bits_cnt    ; // дbit��������д����֮ǰ������ʼ��Ϊ7������һ��bit�ͼ�1
reg         [8:0]   R_write_bytes_cnt   ; // д�ֽڼ�����������һ���ֽ����ݾͰ�����1
reg         [7:0]   R_read_bits_cnt     ; // дbit������������һ��bit�ͼ�1
reg         [8:0]   R_read_bytes_cnt    ; // ���ֽڼ�����������һ���ֽ����ݾͰ�����1
reg         [8:0]   R_read_bytes_num    ; // Ҫ���յ���������
reg                 R_read_finish       ; // �����ݽ�����־λ

//wire        [7:0]   W_rom_addr          ;  


assign O_qspi_clk = R_qspi_clk_en ? I_clk_25M : 0   ; // ��������ʱ���ź�
//assign W_rom_addr = R_write_bytes_cnt               ;

// QSPI IO�������
assign IO_qspi_io0     =   R_qspi_io0_out_en ? R_qspi_io0 : 1'bz ;                
assign IO_qspi_io1     =   R_qspi_io1_out_en ? R_qspi_io1 : 1'bz ;                
assign IO_qspi_io2     =   R_qspi_io2_out_en ? R_qspi_io2 : 1'bz ;                
assign IO_qspi_io3     =   R_qspi_io3_out_en ? R_qspi_io3 : 1'bz ; 
////////////////////////////////////////////////////////////////////////////////////////////
// ���ܣ���ʱ�ӵ��½��ط�������
////////////////////////////////////////////////////////////////////////////////////////////
always @(negedge I_clk_25M or negedge I_rst_n)
begin
    if(!I_rst_n)
        begin
            O_qspi_cs           <=  1'b1   ;        
            O_qspi_state        <=  C_IDLE ;
            R_cmd_reg           <=  0      ;
            R_address_reg       <=  0      ;
            R_qspi_clk_en       <=  1'b0   ;  //QSPI clock�����ʹ��
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
                C_IDLE:  // ��ʼ�������Ĵ���������⵽����������Ч(�������͵����λλ1)�Ժ�,���뷢��������״̬
                    begin                              
                        R_qspi_clk_en          <=   1'b0         ;
                        O_qspi_cs              <=   1'b1         ;
                        R_qspi_io0             <=   1'b0         ;    
                        R_cmd_reg              <=   I_cmd_code   ;
                        R_address_reg          <=   I_qspi_addr  ;
                        R_status_reg           <=   I_status_reg ;
                        O_done_sig             <=   1'b0         ;
                        R_qspi_io3_out_en   <=   1'b0         ; // ����IO_qspi_io3Ϊ����
                        R_qspi_io2_out_en   <=   1'b0         ; // ����IO_qspi_io2Ϊ����
                        R_qspi_io1_out_en   <=   1'b0         ; // ����IO_qspi_io1Ϊ����
                        R_qspi_io0_out_en   <=   1'b0         ; // ����IO_qspi_io0Ϊ����
                        if(I_cmd_type[4] == 1'b1) 
                            begin                //���flash������������
                                O_qspi_state        <=  C_SEND_CMD  ;
                                R_write_bits_cnt    <=  7           ;        
                                R_write_bytes_cnt   <=  0           ;
                                R_read_bytes_num    <=  0           ;                    
                            end
                    end
                C_SEND_CMD: // ����8-bit������״̬ 
                    begin
                        R_qspi_io0_out_en   <=  1'b1    ; // ����IO_qspi_io0Ϊ���
                        R_qspi_clk_en       <=  1'b1    ; // ��SPI����ʱ��SCLK��ʹ�ܿ���
                        O_qspi_cs           <=  1'b0    ; // ����Ƭѡ�ź�CS
                        if(R_write_bits_cnt > 0) 
                            begin                           //���R_cmd_reg��û�з�����
                                R_qspi_io0            <=  R_cmd_reg[R_write_bits_cnt] ;         //����bit7~bit1λ
                                R_write_bits_cnt       <=  R_write_bits_cnt-1'b1       ;
                            end                            
                        else 
                            begin                                 //����bit0
                                R_qspi_io0 <=  R_cmd_reg[0]    ;
                                if ((I_cmd_type[3:0] == 4'b0001) | (I_cmd_type[3:0] == 4'b0100)) 
                                    begin    //�����дʹ��ָ��(Write Enable)����д��ʹ��ָ��(Write Disable)
                                        O_qspi_state    <=  C_FINISH_DONE   ;
                                    end
								else if (I_cmd_type[3:0] == 4'b0000) 
                                    begin    //����Ƕ��豸IDָ��(Read Device ID)
                                        O_qspi_state        <=  C_READ_WAIT ;
                                        R_write_bits_cnt    <=  7           ;
                                        R_read_bytes_num    <=  21          ;//���豸IDָ����Ҫ����20���ֽ�����		
									end	
                                else if (I_cmd_type[3:0] == 4'b0011) 
                                    begin    //����Ƕ�״̬�Ĵ���ָ��(Read Register)
                                        O_qspi_state        <=  C_READ_WAIT ;
                                        R_write_bits_cnt    <=  7           ;
                                        R_read_bytes_num    <=  1           ;//��״̬�Ĵ���ָ����Ҫ����һ���ֽ����� 
                                    end
								else if (I_cmd_type[3:0] == 4'b1010) 
                                    begin    //����Ƕ�����ʧ�����üĴ���
                                        O_qspi_state        <=  C_READ_WAIT ;
                                        R_write_bits_cnt    <=  7           ;
                                        R_read_bytes_num    <=  2           ;//��״̬�Ĵ���ָ����Ҫ���������ֽ����� 
                                    end		
                                else if( (I_cmd_type[3:0] == 4'b0010) ||  // �������������(Sector Erase)
                                         (I_cmd_type[3:0] == 4'b0101) ||  // �����ҳ���ָ��(Page Program)
                                         (I_cmd_type[3:0] == 4'b0111) ||  // ����Ƕ�����ָ��(Read Data)
                                         (I_cmd_type[3:0] == 4'b1000) ||  // ���������ģʽҳ���ָ��(Quad Page Program)
                                         (I_cmd_type[3:0] == 4'b1001)     // ���������ģʽ������ָ��(Quad Read Data)
                                        ) 
                                    begin                          
                                        O_qspi_state        <=  C_SEND_ADDR ;
                                        R_write_bits_cnt    <=  23          ; // �⼸��ָ����涼��Ҫ��һ��24-bit�ĵ�ַ��
                                    end
                                else if (I_cmd_type[3:0] == 4'b0110) 
                                    begin    //�����д����ʧ�����üĴ���
                                        O_qspi_state        <=  C_WRITE_STATE_REG   ;
                                        R_write_bits_cnt    <=  15                  ;
                                    end 
                            end
                    end
                C_WRITE_STATE_REG   :
                    begin
                        R_qspi_io0_out_en   <=  1'b1    ;   // ����IO0Ϊ���
                        if(R_write_bits_cnt > 0)  
                            begin                           //���R_cmd_reg��û�з�����
                                R_qspi_io0         <=  R_status_reg[R_write_bits_cnt] ;   //����bit15~bit1λ
                                R_write_bits_cnt   <=  R_write_bits_cnt    -   1      ;    
                            end                                 
                        else 
                            begin                                        //����bit0
                                R_qspi_io0      <=  R_status_reg[0]    ;   
                                O_qspi_state    <=  C_FINISH_DONE      ;                                          
                            end                            
                    end 
                C_SEND_ADDR: // ���͵�ַ״̬
                    begin
                        R_qspi_io0_out_en   <=  1'b1    ;
                        if(R_write_bits_cnt > 0)  //���R_cmd_reg��û�з�����
                            begin                                 
                                R_qspi_io0            <=  R_address_reg[R_write_bits_cnt] ; //����bit23~bit1λ
                                R_write_bits_cnt       <=  R_write_bits_cnt    -   1       ;    
                            end                                 
                        else 
                            begin 
                                R_qspi_io0 <=  R_address_reg[0]    ;   //����bit0
                                if(I_cmd_type[3:0] == 4'b0010) // ��������(Sector Erase)ָ��
                                    begin  //��������(Sector Erase)ָ���24-bit��ַ���ִ�н����ˣ�����ֱ����������״̬
                                        O_qspi_state <= C_FINISH_DONE   ;    
                                    end
                                else if (I_cmd_type[3:0] == 4'b0101) // ҳ���(Page Program)ָ��,ҳ���ָ���д����ָ����һ����˼
                                    begin                              
                                        O_qspi_state        <=  C_WRITE_DATA    ;
                                        R_write_bits_cnt    <=  7               ;                       
                                    end                                                        
                                else if (I_cmd_type[3:0] == 4'b0111) // ������(Read Data)ָ��
                                    begin
                                        O_qspi_state        <=  C_READ_WAIT     ;
                                        R_read_bytes_num    <=  1               ;   //����1������        
                                    end 
                                else if (I_cmd_type[3:0] == 4'b1000) 
                                    begin   //���������ģʽҳ���ָ��(Quad Page Program)                               
                                        O_qspi_state        <=  C_WRITE_DATA_QUAD   ;
                                        R_write_bits_cnt    <=  7                   ;                       
                                    end 
                                else if (I_cmd_type[3:0] == 4'b1001) 
                                    begin   //��������߶�����                               
                                        O_qspi_state        <=  C_DUMMY         ;
                                        R_read_bytes_num    <=  1               ; //����1������    
                                        R_write_bits_cnt    <=  9               ; //10��dummy clock                    
                                    end 
                            end
                    end 
                C_DUMMY:  // ���߶�����֮ǰ��Ҫ�ȴ�10��dummy clock
                    begin  
                        R_qspi_io3_out_en   <=  1'b0            ; // ����IO_qspi_io3Ϊ����
                        R_qspi_io2_out_en   <=  1'b0            ; // ����IO_qspi_io2Ϊ����
                        R_qspi_io1_out_en   <=  1'b0            ; // ����IO_qspi_io1Ϊ����
                        R_qspi_io0_out_en   <=  1'b0            ; // ����IO_qspi_io0Ϊ����       
                        if(R_write_bits_cnt > 0)    
                            R_write_bits_cnt    <=  R_write_bits_cnt - 1 ;                                    
                        else 
                            O_qspi_state        <=  C_READ_WAIT_QUAD     ;                                          
                    end   
                C_READ_WAIT: // ����ģʽ���ȴ�״̬
                    begin
                        if(R_read_finish)  
                            begin
                                O_qspi_state        <=  C_FINISH_DONE   ;
                                R_data_come_single  <=  1'b0            ;
                            end
                        else
                            begin
                                R_data_come_single  <=  1'b1            ; // ����ģʽ�¶����ݱ�־�źţ����ź�Ϊ�߱�־���ڽ�������
                                R_qspi_io1_out_en   <=  1'b0            ;
                            end
                    end
                C_READ_WAIT_QUAD: // ����ģʽ���ȴ�״̬
                    begin
                        if(R_read_finish)  
                            begin
                                O_qspi_state        <=  C_FINISH_DONE   ;
                                R_data_come_quad    <=  1'b0            ;
                            end
                        else
                            R_data_come_quad        <=  1'b1            ;
                    end
                C_WRITE_DATA: // д����״̬
                    begin
                        if(R_write_bytes_cnt < 1) // ��QSPI Flash��д�� 1 ������
                            begin                       
                                if(R_write_bits_cnt > 0) //������ݻ�û�з�����
                                    begin                           
                                        R_qspi_io0             <=  I_test_vec[R_write_bits_cnt] ; //����bit7~bit1λ
                                        R_write_bits_cnt    <=  R_write_bits_cnt  - 1'b1    ;                        
                                    end                 
                                else 
                                    begin                                 
                                        R_qspi_io0             <=  I_test_vec[0]                ; //����bit0
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
                C_WRITE_DATA_QUAD    ://д���ݲ���(����ģʽ)
                    begin
                        R_qspi_io0_out_en   <=  1'b1    ;   // ����IO0Ϊ���
                        R_qspi_io1_out_en   <=  1'b1    ;   // ����IO1Ϊ���
                        R_qspi_io2_out_en   <=  1'b1    ;   // ����IO2Ϊ���
                        R_qspi_io3_out_en   <=  1'b1    ;   // ����IO3Ϊ���                          
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
                                        R_qspi_io3          <=  I_test_vec[3]                     ; // �ֱ���bit3
                                        R_qspi_io2          <=  I_test_vec[2]                     ; // �ֱ���bit2
                                        R_qspi_io1          <=  I_test_vec[1]                     ; // �ֱ���bit1
                                        R_qspi_io0          <=  I_test_vec[0]                     ; // �ֱ���bit0
                                    end
                                else
                                    begin
                                        R_write_bits_cnt    <=  R_write_bits_cnt - 4            ;
                                        R_qspi_io3          <=  I_test_vec[R_write_bits_cnt - 0] ; // �ֱ���bit7
                                        R_qspi_io2          <=  I_test_vec[R_write_bits_cnt - 1] ; // �ֱ���bit6
                                        R_qspi_io1          <=  I_test_vec[R_write_bits_cnt - 2] ; // �ֱ���bit5
                                        R_qspi_io0          <=  I_test_vec[R_write_bits_cnt - 3] ; // �ֱ���bit4
                                    end 
                            end                                            
                    end 
                C_FINISH_DONE:
                    begin
                        O_qspi_cs           <=  1'b1    ;
                        R_qspi_io0          <=  1'b0    ;
                        R_qspi_clk_en       <=  1'b0    ;
                        O_done_sig          <=  1'b1    ;
                        R_qspi_io3_out_en   <=  1'b0    ; // ����IO_qspi_io3Ϊ����
                        R_qspi_io2_out_en   <=  1'b0    ; // ����IO_qspi_io2Ϊ����
                        R_qspi_io1_out_en   <=  1'b0    ; // ����IO_qspi_io1Ϊ����
                        R_qspi_io0_out_en   <=  1'b0    ; // ����IO_qspi_io0Ϊ����
                        R_data_come_single  <=  1'b0    ;
                        R_data_come_quad    <=  1'b0    ;
                        O_qspi_state        <=  C_IDLE  ;
                    end
                default:O_qspi_state    <=  C_IDLE      ;
            endcase         
        end
end

//////////////////////////////////////////////////////////////////////////////
// ���ܣ�����QSPI Flash���͹���������    
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
    else if(R_data_come_single)   // ���ź�Ϊ�߱�ʾ�������ݴ�QSPI Flash������������
        begin
            if(R_read_bytes_cnt < R_read_bytes_num) 
                begin            
                    if(R_read_bits_cnt < 7)  //����һ��Byte��bit0~bit6    
                        begin                         
                            O_read_byte_valid   <=  1'b0                               ;
                            R_read_data_reg     <=  {R_read_data_reg[6:0],IO_qspi_io1} ;
                            R_read_bits_cnt     <=  R_read_bits_cnt +   1'b1           ;
                        end
                    else  
                        begin
                            O_read_byte_valid   <=  1'b1                               ;  //һ��byte������Ч
                            O_read_data         <=  {R_read_data_reg[6:0],IO_qspi_io1} ;  //����bit7
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
                begin  //��������              
                    if(R_read_bits_cnt < 8'd1)
                        begin
                            O_read_byte_valid       <=  1'b0                    ;
                            R_read_data_reg         <=  {R_read_data_reg[3:0],IO_qspi_io3,IO_qspi_io2,IO_qspi_io1,IO_qspi_io0};//����ǰ��λ
                            R_read_bits_cnt         <=  R_read_bits_cnt + 1     ; 
                        end
                    else    
                        begin
                            O_read_byte_valid       <=  1'b1                    ;
                            O_read_data             <=  {R_read_data_reg[3:0],IO_qspi_io3,IO_qspi_io2,IO_qspi_io1,IO_qspi_io0};  //���պ���λ
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
