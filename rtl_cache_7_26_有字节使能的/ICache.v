`include "Cache_define.v"

//state 
`define HIT	                    4'd0
`define HIT_READ_AFTER          4'd1

`define MEM_READ_PRE            4'd2
`define MEM_READ_ON             4'd3
`define MEM_READ_END            4'd4
`define MEM_READ_END_TRUE       4'd5


`define UNCACHED_READ_PRE       4'd7
`define UNCACHED_READ_ON        4'd8
`define UNCACHED_READ_END       4'd9



module ICache (
	// 
	input  resetn_p,
	input  clk,
    // CPU wires
	input  [31:0] i_addr,
	input         i_en_p,//00为不读不写，01为读，10为写
	output reg    i_stall,
    input         cached,//0为不需要cache，1为需要cache//*
    
    //cache指令
    input [4:0]   c_op,
    //input [31:0]  c_tag,
    //地址通过普通接口传


    //双发射
    output reg    i_ready_1,
    output reg    i_ready_2,
    output reg [31:0] i_rdata_1,
    output reg [31:0] i_rdata_2,
	
	//axi wires
    output reg  [  3 : 0 ] arid,
    output reg  [ 31 : 0 ] araddr,
    output reg  [  3 : 0 ] arlen,
    output wire [  2 : 0 ] arsize,
    output wire [  1 : 0 ] arburst,
    output wire [  1 : 0 ] arlock,
    output wire [  3 : 0 ] arcache,
    output wire [  2 : 0 ] arprot,
    output reg             arvalid,
    input  wire            arready,
    input  wire [  3 : 0 ] rid,
    input  wire [ 31 : 0 ] rdata,
    input  wire [  1 : 0 ] rresp,
    input  wire            rlast,
    input  wire            rvalid,
    output wire            rready,
    output wire [  3 : 0 ] awid,
    output wire [ 31 : 0 ] awaddr,
    output wire [  3 : 0 ] awlen,
    output wire [  2 : 0 ] awsize,
    output wire [  1 : 0 ] awburst,
    output wire [  1 : 0 ] awlock,
    output wire [  3 : 0 ] awcache,
    output wire [  2 : 0 ] awprot,
    output wire            awvalid,
    input  wire            awready,
    output wire [  3 : 0 ] wid,
    output wire [ 31 : 0 ] wdata,
    output wire [  3 : 0 ] wstrb,
    output wire            wlast,
    output wire            wvalid,
    input  wire            wready,
    input  wire [  3 : 0 ] bid,
    input  wire [  1 : 0 ] bresp,
    input  wire            bvalid,
    output wire            bready

	
);
    reg resetn;
    always @(posedge clk) resetn <= resetn_p;
    wire [0:1] i_en = {0,i_en_p};

    //axi 默认值
    assign arsize   = 3'b010;
    assign arburst  = 2'b01;
    assign arlock   = 2'b0;
    assign arcache  = 4'b0;
    assign arprot   = 3'b0;

    assign rready   = 1'b1;
    assign awid     = 4'b0;
    assign awaddr   = 32'b0;

    assign awlen    = 4'b0;
    assign awsize   = 3'b010;
    assign awburst  = 2'b01;
    assign awlock   = 2'b0;
    assign awcache  = 4'b0;
    assign awprot   = 3'b0;
    
    assign awvalid  = 1'b0;
    assign wid      = 4'b0;
    assign wdata    = 32'b0;
    assign wstrb    = 4'b0;
    assign wlast    = 1'b0;
    assign wvalid   = 1'b0;
    assign bready   = 1'b1;

    //宏定义
    parameter WORDS_PER_LINE = 2**`WORD_OFF_SIZE_I ;//每行有几个字
    parameter LINES = 2**`INDEX_SIZE_I;//行数
    //i_addr分解
    wire [`TAG_SIZE_I - 1      : 0] tag    = i_addr[31                           : `WORD_OFF_SIZE_I + `INDEX_SIZE_I + 2];
    wire [`INDEX_SIZE_I - 1    : 0] index  = i_addr[`WORD_OFF_SIZE_I + `INDEX_SIZE_I + 1 : `WORD_OFF_SIZE_I + 2];
    wire [`WORD_OFF_SIZE_I - 1 : 0] offset = i_addr[`WORD_OFF_SIZE_I + 1            : 2];
    //cache_data*16
    wire [32 * WORDS_PER_LINE - 1:0]            cache_line;
    wire [32 * WORDS_PER_LINE - 1:0]            w_line; 
    //cache本身保存的
    wire                                        cache_valid;
    wire [`TAG_SIZE_I - 1 : 0]                  cache_tag;
    wire [31:0]                                 cache_data[WORDS_PER_LINE - 1 :0];
    //要写入的
    wire [`TAG_SIZE_I - 1 : 0]                  w_tag;
    reg                                         w_valid;
    reg [31:0]                                  w_data[WORDS_PER_LINE - 1 :0];
    //
    reg [`CNT_SIZE_I:0]                         cnt;
    reg [4*WORDS_PER_LINE - 1 :0]               w_en;
    reg                                         w_en_v;
    reg [3:0]                                   state;
    reg [3:0]                                   state_next;

    reg [31:0]                                  uncached_data;
    //
	ICache_Ram my_ICache_Ram (
		.clk(clk),
        .wen(w_en),
        .resetn(resetn),

        .a(index),
        .dpra(index),
        .d(w_tag),
        .dpo(cache_tag),
        .dina(w_line),
        .douta(cache_line),

        .w_valid(w_valid),
        .cache_valid(cache_valid)
	);
    //
    genvar i;
    generate for (i = 0; i < WORDS_PER_LINE; i = i + 1) begin
	assign cache_data[i] = cache_line[i*32 +: 32];
    end
	endgenerate
    //
    assign w_tag = tag;
    generate for (i = 0; i < WORDS_PER_LINE; i = i + 1) begin
	assign w_line[i*32 +: 32] = w_data[i];
    end
	endgenerate
        
    //hit
    wire hit = cache_valid && (cache_tag == tag) && i_en;//始终以组合逻辑判断命中
    //
	wire need_mem_read = cached && i_en && (~cache_valid || ~hit);
    //关于uncached
    wire need_uncached_read = !cached && i_en;

    //logic FSM controller//只控制控制性变量
    reg [1:0] i_en_next;
    reg need_mem_read_next;
    reg need_uncached_read_next;
    always@(posedge clk) begin
        if(!resetn) begin
            state_next <= `HIT;
        end
        else begin
            state_next <= state;
            i_en_next  <= i_en;
            need_mem_read_next <= need_mem_read;
            need_uncached_read_next <= need_uncached_read;
        end
    end
    always@(*) begin
        if(!resetn) begin
            w_en   = {WORDS_PER_LINE*{4'b1111}};
            w_en_v = 1;
        end
        else begin
            w_en   = 0;
            w_en_v = 0;
        end
        i_ready_1 = 0;
        i_ready_2 = 0;
        i_rdata_1 = 0;
        i_rdata_2 = 0;
        i_stall   = 0;
        case(state_next)
        `HIT:begin
            if(!need_mem_read && !need_uncached_read && (i_en == 2'b01)) begin
                i_stall   = 1;       
            end
            else begin
                i_stall = resetn;//可能有问题
            end
        end
        `HIT_READ_AFTER: begin
            if(!(!need_mem_read_next && !need_uncached_read_next && (i_en_next == 2'b01))) begin
                i_stall = 1;
            end 
            else begin
                i_stall   = 0;
                i_ready_1 = 1;
                i_ready_2 = (offset != `AXI_COUNT_I );
                i_rdata_1 = cache_data[offset];
                i_rdata_2 = (offset != `AXI_COUNT_I ) ? cache_data[offset + 1] : 0;
            end
        end
        `MEM_READ_PRE : begin
            i_stall = 1;
        end
        `MEM_READ_ON : begin
            i_stall = 1;
        end
        `MEM_READ_END: begin
            w_en    = {WORDS_PER_LINE*{4'b1111}};
            w_en_v  = 1;
            i_stall = 1;
        end
        `MEM_READ_END_TRUE : begin
            i_stall   = 0;
            w_en      = 0;
            w_en_v    = 0;
            i_ready_1 = 1;
            i_ready_2 = (offset != `AXI_COUNT_I );
            i_rdata_1 = w_data[offset];
            i_rdata_2 = (offset != `AXI_COUNT_I) ? w_data[offset + 1] : 0;
        end



        `UNCACHED_READ_PRE : begin
            i_stall   = 1;
        end
        `UNCACHED_READ_ON : begin
            i_stall   = 1;
        end
        `UNCACHED_READ_END : begin
            i_stall   = 0;
            i_ready_1 = 1;  
            i_rdata_1 = uncached_data;
        end
        endcase

    end
    integer k;
    // FSM controller//只控制存储型变量
    always @(posedge clk) begin
        if(!resetn) begin
            cnt      <= 0;
            arid     <= 0;
            araddr   <= 0;
            arlen    <= 0;
            arvalid  <= 0;

            w_valid  <= 0;

            for(k = 0; k < WORDS_PER_LINE ;k = k + 1)
                w_data[k] <= 0;
           
            state      <= `HIT;
           
        end
        
        else begin
            arvalid  <= 0;
            case(state)
            
            `HIT : begin
                if(need_mem_read) begin
                    state <= `MEM_READ_PRE;
                end
                else if(need_uncached_read) begin
                    state <= `UNCACHED_READ_PRE;
                end
                else if((i_en == 2'b01) && hit) begin
                    state <= `HIT_READ_AFTER;
                end
            end
            `HIT_READ_AFTER: begin
                if(!(!need_mem_read && !need_uncached_read && hit && (i_en == 2'b01))) begin
                    state       <= `HIT;//感觉这样还是有点没必要，还是要考虑一下
                end
                else begin
                    state       <= `HIT;
                end
            end
            `MEM_READ_PRE: begin
                if(!need_mem_read) begin
                    state   <= `HIT;
                end
                else if(arvalid && arready) 
                    state   <= `MEM_READ_ON;
                else begin
                    arid    <= 4'b0011;
                    araddr  <= {i_addr[31:`WORD_OFF_SIZE_I + 2],{(`WORD_OFF_SIZE_I + 2){1'b0}}};
                    arlen   <= `AXI_COUNT_I;
                    arvalid <= 1;
                end
            end
            `MEM_READ_ON: begin
                if(rvalid) begin
                    w_data[cnt] <= rdata;//rdata也相当于一个电平信号，需要保持一周期
                    cnt         <= cnt + 1;
                    if(rlast) begin
                        state   <= `MEM_READ_END;
                        w_valid <= 1;//是不是一定要放在这里呢？好像无所谓，因为用到valid的地方是组合逻辑，所以似乎也可以往后放一个周期。//其实我感觉往前放几个周期也没有影响
                    end
                end
            end
            `MEM_READ_END: begin
                    state   <= `MEM_READ_END_TRUE;
            end
            `MEM_READ_END_TRUE: begin
                    state   <= `HIT;
            end
            `UNCACHED_READ_PRE : begin
                if(!need_uncached_read) begin
                    state   <= `HIT;
                end
                else if(arvalid && arready) 
                    state   <= `UNCACHED_READ_ON;
                    else begin
                        arid    <= 4'b0010;
                        araddr  <= i_addr;
                        arlen   <= 4'h0;
                        arvalid <= 1;
                    end
                end
            `UNCACHED_READ_ON: begin
                if(rvalid) begin
                    uncached_data <= rdata;
                    if(rlast) begin
                        state <= `UNCACHED_READ_END;
                    end
                end
            end
            `UNCACHED_READ_END: begin
                    state   <= `HIT;
            end
            default: begin
                state <= `HIT;
            end
            endcase
        end
    end
    

endmodule
