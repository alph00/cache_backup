`include"Cache_define.v"

module ICache_Ram(
    input clk,
	input [4*(2**`WORD_OFF_SIZE_I) - 1: 0] wen,//写使能
	input wen_v,
	input resetn,
	//data
	input  [`INDEX_SIZE_I - 1:0] a,//写地址
	input  [`INDEX_SIZE_I - 1:0] dpra,//读地址
	input  [`TAG_SIZE_I   - 1:0] d,//写TAG
	output [`TAG_SIZE_I   - 1:0] dpo,//读TAG
	input  [32 * (2**`WORD_OFF_SIZE_I) - 1:0] dina,//写data
	output [32 * (2**`WORD_OFF_SIZE_I) - 1:0] douta,//读data
	
	input          w_valid,
	output         cache_valid
);
	parameter WORDS_PER_LINE = 2**`WORD_OFF_SIZE_I;
	parameter LINES = 2**`INDEX_SIZE_I; 

	//tag Ram(dist)
	ICache_Ram_IP_tag itag (
		.a(a),
		.d(d),
		.dpo(dpo),
		.clk(clk),
		.we(wen),
		.dpra(dpra)
	);
	//data Ram(block)
	genvar t;
	generate for(t = 0;t < WORDS_PER_LINE; t = t + 1) begin
		ICache_Ram_IP_data idata(
		.addra(a),
		.dina(dina[t*32+:32]),
		.douta(douta[t*32+:32]),
		.clka(clk),
		.wea(wen[t*4+:4]),
		.ena(1'b1)
	);
	end endgenerate
	
	//V
	reg 	   valid 	[LINES - 1:0];
	//读V
	assign cache_valid = valid[dpra];
	//写V
	integer k;
	always@(posedge clk) begin
		if(!resetn) begin
			for(k = 0 ;k < LINES ;k = k + 1) begin
				valid[k] <= 0;
			end
		end
		else if(wen_v) begin
			valid[a] <= w_valid;
		end
	end
endmodule
//注意select、何时写与dirty