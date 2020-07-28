`include"Cache_define.v"

module ICache_Ram(
    input clk,
	input wen,//写使能
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
	ICache_Ram_IP_data idata(
		.addra(a),
		.dina(dina),
		.douta(douta),
		.clka(clk),
		.wea(wen),
		.ena(1'b1)
	);
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
		else if(wen) begin
			valid[a] <= w_valid;
		end
	end
endmodule
//注意select、何时写与dirty