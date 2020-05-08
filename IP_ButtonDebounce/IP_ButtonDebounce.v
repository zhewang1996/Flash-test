module IP_ButtonDebounce( clk,rst,BTN0,BTN_DEB );
	input clk;
	input rst;
	input BTN0;
	output BTN_DEB;
	//∑÷∆µµ√200HZ£¨5ms ±÷”
	wire clk_5ms;
	IP_1Hz #(250000) U1
	      (
			 .clk(clk),
			 .rst(rst),
			 .clk_N(clk_5ms)
	      );
	reg BTN_r,BTN_rr,BTN_rrr;
	always@(posedge rst or posedge clk_5ms ) begin
		if(rst) begin
			BTN_rrr<='b0;
			BTN_rr<='b0;
			BTN_r<='b0;
		end
		else begin 
			BTN_rrr<=BTN_rr;
			BTN_rr<=BTN_r;
			BTN_r<=BTN0;
		end
	end
	assign BTN_DEB=BTN_r&BTN_rr&BTN_rrr;
endmodule
