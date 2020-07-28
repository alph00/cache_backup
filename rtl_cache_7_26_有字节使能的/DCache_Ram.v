`include "Cache_define.v"
module DCache_Ram(
    input clk,
	input wen,//写使能
	input wen_dv,
	input resetn,
	//data
	input  [`INDEX_SIZE_D - 1:0] a,//写地址
	input  [`INDEX_SIZE_D - 1:0] dpra,//读地址
	input  [`TAG_SIZE_D   - 1:0] d,//写TAG
	output [`TAG_SIZE_D   - 1:0] dpo,//读TAG
	input  [32 * (2**`WORD_OFF_SIZE_D) - 1:0] dina,//写数
	output [32 * (2**`WORD_OFF_SIZE_D) - 1:0] douta,//读数

	input                        w_dirty,
	input                        w_valid,

	output                       cache_dirty,
	output                       cache_valid
);
	parameter WORDS_PER_LINE = 2**`WORD_OFF_SIZE_D;
	parameter LINES = 2**`INDEX_SIZE_D; 

	//data Ram
	DCache_Ram_IP_tag dtag(
		.a(a),
		.d(d),
		.dpo(dpo),
		.clk(clk),
		.we(wen),//这个东西是上升沿检测的吗
		.dpra(dpra)
	);

	DCache_Ram_IP_data ddata(
		.addra(a),
		.dina(dina),
		.douta(douta),
		.clka(clk),
		.wea(wen),
		.ena(1'b1)
	);
	//DV
	reg 	   valid 	[LINES - 1:0];
	reg        dirty    [LINES - 1:0];
	//读DV
	assign     cache_valid = valid[dpra];
	assign     cache_dirty = dirty[dpra];
	//写DV
	integer k;//注意这时会不会出问题
	always@(posedge clk) begin
		if(!resetn) begin
			for(k = 0 ;k < LINES ;k = k + 1) begin
				valid[k] <= 0;
				dirty[k] <= 0;
			end
		end
		else if(wen_dv) begin
			valid[a] <= w_valid;
			dirty[a] <= w_dirty;
		end
	end
endmodule
//注意select、何时写与dirty