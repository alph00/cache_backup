module DCache_Ram#(parameter 
    INDEX_SIZE = 6,//行索引大小
	WORD_OFF_SIZE = 4,//字偏移量大小
	TAG_SIZE = 20//标签地址大小
) (
    input clk,
	input wen,//写使能
	input wen_dv,
	input resetn,
	//data
	input  [5:0] a,//写地址
	input  [5:0] dpra,//读地址
	input  [531:0] d,//写数据（包括TAG）
	output [531:0] dpo,//读数据（包括TAG）

	input                        w_dirty,
	input                        w_valid,

	output                       cache_dirty,
	output                       cache_valid
);
	parameter WORDS_PER_LINE = 2**WORD_OFF_SIZE;
	parameter LINES = 32-TAG_SIZE -2-WORD_OFF_SIZE; 

	//data Ram
	DCache_Ram_IP byte_all (
		.a(a),
		.d(d),
		.dpo(dpo),
		.clk(clk),
		.we(wen),//这个东西是上升沿检测的吗
		.dpra(dpra)
	);
	//DV
	reg 	   valid 	[63:0];
	reg        dirty    [63:0];
	//读DV
	assign     cache_valid = valid[dpra];
	assign     cache_dirty = dirty[dpra];
	//写DV
	always@(posedge clk) begin
		if(!resetn) begin
			valid[0] <= 0;
			valid[1] <= 0;
			valid[2] <= 0;
			valid[3] <= 0;
			valid[4] <= 0;
			valid[5] <= 0;
			valid[6] <= 0;
			valid[7] <= 0;
			valid[8] <= 0;
			valid[9] <= 0;
			valid[10] <= 0;
			valid[11] <= 0;
			valid[12] <= 0;
			valid[13] <= 0;
			valid[14] <= 0;
			valid[15] <= 0;
			valid[16] <= 0;
			valid[17] <= 0;
			valid[18] <= 0;
			valid[19] <= 0;
			valid[20] <= 0;
			valid[21] <= 0;
			valid[22] <= 0;
			valid[23] <= 0;
			valid[24] <= 0;
			valid[25] <= 0;
			valid[26] <= 0;
			valid[27] <= 0;
			valid[28] <= 0;
			valid[29] <= 0;
			valid[30] <= 0;
			valid[31] <= 0;
			valid[32] <= 0;
			valid[33] <= 0;
			valid[34] <= 0;
			valid[35] <= 0;
			valid[36] <= 0;
			valid[37] <= 0;
			valid[38] <= 0;
			valid[39] <= 0;
			valid[40] <= 0;
			valid[41] <= 0;
			valid[42] <= 0;
			valid[43] <= 0;
			valid[44] <= 0;
			valid[45] <= 0;
			valid[46] <= 0;
			valid[47] <= 0;
			valid[48] <= 0;
			valid[49] <= 0;
			valid[50] <= 0;
			valid[51] <= 0;
			valid[52] <= 0;
			valid[53] <= 0;
			valid[54] <= 0;
			valid[55] <= 0;
			valid[56] <= 0;
			valid[57] <= 0;
			valid[58] <= 0;
			valid[59] <= 0;
			valid[50] <= 0;
			valid[51] <= 0;
			valid[52] <= 0;
			valid[53] <= 0;
			valid[54] <= 0;
			valid[55] <= 0;
			valid[56] <= 0;
			valid[57] <= 0;
			valid[58] <= 0;
			valid[59] <= 0;
			valid[50] <= 0;
			valid[51] <= 0;
			valid[52] <= 0;
			valid[53] <= 0;
			valid[54] <= 0;
			valid[55] <= 0;
			valid[56] <= 0;
			valid[57] <= 0;
			valid[58] <= 0;
			valid[59] <= 0;
			valid[60] <= 0;
			valid[61] <= 0;
			valid[62] <= 0;
			valid[63] <= 0;

			dirty[0] <= 0;
			dirty[1] <= 0;
			dirty[2] <= 0;
			dirty[3] <= 0;
			dirty[4] <= 0;
			dirty[5] <= 0;
			dirty[6] <= 0;
			dirty[7] <= 0;
			dirty[8] <= 0;
			dirty[9] <= 0;
			dirty[10] <= 0;
			dirty[11] <= 0;
			dirty[12] <= 0;
			dirty[13] <= 0;
			dirty[14] <= 0;
			dirty[15] <= 0;
			dirty[16] <= 0;
			dirty[17] <= 0;
			dirty[18] <= 0;
			dirty[19] <= 0;
			dirty[20] <= 0;
			dirty[21] <= 0;
			dirty[22] <= 0;
			dirty[23] <= 0;
			dirty[24] <= 0;
			dirty[25] <= 0;
			dirty[26] <= 0;
			dirty[27] <= 0;
			dirty[28] <= 0;
			dirty[29] <= 0;
			dirty[30] <= 0;
			dirty[31] <= 0;
			dirty[32] <= 0;
			dirty[33] <= 0;
			dirty[34] <= 0;
			dirty[35] <= 0;
			dirty[36] <= 0;
			dirty[37] <= 0;
			dirty[38] <= 0;
			dirty[39] <= 0;
			dirty[40] <= 0;
			dirty[41] <= 0;
			dirty[42] <= 0;
			dirty[43] <= 0;
			dirty[44] <= 0;
			dirty[45] <= 0;
			dirty[46] <= 0;
			dirty[47] <= 0;
			dirty[48] <= 0;
			dirty[49] <= 0;
			dirty[50] <= 0;
			dirty[51] <= 0;
			dirty[52] <= 0;
			dirty[53] <= 0;
			dirty[54] <= 0;
			dirty[55] <= 0;
			dirty[56] <= 0;
			dirty[57] <= 0;
			dirty[58] <= 0;
			dirty[59] <= 0;
			dirty[50] <= 0;
			dirty[51] <= 0;
			dirty[52] <= 0;
			dirty[53] <= 0;
			dirty[54] <= 0;
			dirty[55] <= 0;
			dirty[56] <= 0;
			dirty[57] <= 0;
			dirty[58] <= 0;
			dirty[59] <= 0;
			dirty[50] <= 0;
			dirty[51] <= 0;
			dirty[52] <= 0;
			dirty[53] <= 0;
			dirty[54] <= 0;
			dirty[55] <= 0;
			dirty[56] <= 0;
			dirty[57] <= 0;
			dirty[58] <= 0;
			dirty[59] <= 0;
			dirty[60] <= 0;
			dirty[61] <= 0;
			dirty[62] <= 0;
			dirty[63] <= 0;
		end
		else if(wen_dv) begin
			valid[a] <= w_valid;
			dirty[a] <= w_dirty;
		end
	end
endmodule
//注意select、何时写与dirty