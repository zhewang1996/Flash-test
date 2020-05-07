`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:58:16 10/31/2019 
// Design Name: 
// Module Name:    IP_ButtonDebounce 
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
module IP_ButtonDebounce( clk,rst,BTN0,BTN_DEB );
	input clk;
	input rst;
	input BTN0;
	output BTN_DEB;
	//∑÷∆µµ√200HZ£¨5ms ±÷”
	wire clk_169344;
	IP_1Hz #(169344) U1
	      (
			 .clk(clk),
			 .rst(rst),
			 .clk_N(clk_169344)
	      );
	reg BTN_r,BTN_rr,BTN_rrr;
	always@(posedge rst or posedge clk_169344 ) begin
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
