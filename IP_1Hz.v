`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:00:18 10/23/2019 
// Design Name: 
// Module Name:    IP_1Hz 
// Project Name:   ż����Ƶ
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

module IP_1Hz(clk,rst,clk_N);  //clk=33.8688MHz,N��Ƶģ�� 
	input clk;
	input rst;
	output reg clk_N;
	parameter N=33868800;
	integer count;
	always@(posedge clk or posedge rst)begin
		if(rst) begin
			clk_N<=0;
			count<=0;
		end
		else if(count==N/2-1) begin
		clk_N<= ~clk_N;
		count<=0;
		end
		else count<=count+1;
	end
endmodule