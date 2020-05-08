module fifo_ctrl(
    input   	clk_25M,
    input   	gmii_tx_clk,
    input   	I_rst_n,
	input [8:0] rd_data_count,
    
    output  	rd_rst,
    output  	wr_rst,
	output reg 	tx_start_en
    );
	
/*********************************************************
复位信号同步模块
*********************************************************/
	
reg rd_rst_s1;
reg rd_rst_s2;
reg wr_rst_s1;
reg wr_rst_s2;

always@(posedge clk_25M or negedge I_rst_n) begin
	if (!I_rst_n)begin
		rd_rst_s1 <= 1'b0;
		rd_rst_s2 <= 1'b0;
	end
	else begin
		rd_rst_s1 <= 1'b1;
		rd_rst_s2 <= rd_rst_s1;
	end
end   

always@(posedge gmii_tx_clk or negedge I_rst_n) begin
	if (!I_rst_n)begin
		wr_rst_s1 <= 1'b0;
		wr_rst_s2 <= 1'b0;
	end
	else begin
		wr_rst_s1 <= 1'b1;
		wr_rst_s2 <= wr_rst_s1;
	end
end 

assign rd_rst = rd_rst_s2 ;
assign wr_rst = wr_rst_s2 ;

/*********************************************************
以太网发送信号产生模块
*********************************************************/
localparam N=256; //一次UPD模块发送1024个字接,UPD数据位宽为32，N=1024/(32/8)=256

always@(posedge gmii_tx_clk or negedge I_rst_n) begin
	if (!I_rst_n)
		tx_start_en <= 0;
	else begin	
		if (rd_data_count >= N) 
			tx_start_en <= 1'b1;
		else 
			tx_start_en <= 1'b0;
	end
end
 
endmodule
