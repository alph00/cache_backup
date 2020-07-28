`include "Cache_define.v"
//state
`define HIT	                    5'd0
`define HIT_WRITE               5'd1
`define HIT_READ_AFTER          5'd2
`define HIT_WRITE_BEFORE        5'd3

`define MEM_READ_PRE            5'd4
`define MEM_READ_ON             5'd5
`define MEM_READ_END            5'd6
`define MEM_READ_END_TRUE       5'd7

`define MEM_WRITE_PRE           5'd8
`define MEM_WRITE_ON            5'd9
`define MEM_WRITE_END           5'd10

`define UNCACHED_READ_PRE       5'd11
`define UNCACHED_READ_ON        5'd12
`define UNCACHED_READ_END       5'd13
`define UNCACHED_WRITE_PRE      5'd14
`define UNCACHED_WRITE_ON       5'd15
`define UNCACHED_WRITE_END      5'd16
module DCache(
	// 
	input                 resetn_p,
	input                 clk,
    // CPU wires
	input      [31:0]     d_addr,
	input      [3:0]      w_b_s,
	input                 d_en_p,//00为不读不写，01为读，10为写//当uncached==0时也需要这个信号来确定是读还是写
    input      [31:0]     d_wdata,
	output reg [31:0]     d_rdata,
	output reg            d_stall,
    input      [1:0]      d_size_p,

    input                 cached,//0为不需要cache，1为需要cache//*
    
    //cache指令
    input [4:0] c_op,//默认时置为11111，作为无效使能
    //input [31:0] c_tag,
    //地址通过普通接口传
	
	//axi wires
    output reg  [  3 : 0 ] arid,
    output reg  [ 31 : 0 ] araddr,
    output reg  [  3 : 0 ] arlen,
    output reg  [  2 : 0 ] arsize,
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
    output reg  [ 31 : 0 ] awaddr,
    output reg  [  3 : 0 ] awlen,
    output reg  [  2 : 0 ] awsize,
    output wire [  1 : 0 ] awburst,
    output wire [  1 : 0 ] awlock,
    output wire [  3 : 0 ] awcache,
    output wire [  2 : 0 ] awprot,
    output reg             awvalid,
    input  wire            awready,
    output wire [  3 : 0 ] wid,
    output wire [ 31 : 0 ] wdata,
    output reg  [  3 : 0 ] wstrb,
    output reg             wlast,
    output reg             wvalid,
    input  wire            wready,
    input  wire [  3 : 0 ] bid,
    input  wire [  1 : 0 ] bresp,
    input  wire            bvalid,
    output wire            bready

	
);
    reg resetn;
    always @(posedge clk) resetn <= resetn_p;
    wire [1:0] d_en = w_b_s ? 2'b10: {0,d_en_p};
    wire [2:0] d_size = {0,d_size_p};

    
    //axi 默认值
    assign arburst  = 2'b01;
    assign arlock   = 2'b0;
    assign arcache  = 4'b0;
    assign arprot   = 3'b0;
    assign rready   = 1'b1;
    assign awid     = 4'b0;
    assign awburst  = 2'b01;
    assign awlock   = 2'b0;
    assign awcache  = 4'b0;
    assign awprot   = 3'b0;
    assign wid      = 4'b0;
    assign bready   = 1'b1;
    //宏定义
    parameter WORDS_PER_LINE = 2**`WORD_OFF_SIZE_D ;//每行有几个字
    parameter LINES = 2**`INDEX_SIZE_D;//行数
    //d_addr分解
    wire [`INDEX_SIZE_D - 1    : 0] index  = d_addr[`WORD_OFF_SIZE_D + `INDEX_SIZE_D + 1 : `WORD_OFF_SIZE_D + 2];
    wire [`TAG_SIZE_D - 1      : 0] tag    = d_addr[31                           : `WORD_OFF_SIZE_D + `INDEX_SIZE_D + 2];
    wire [`WORD_OFF_SIZE_D - 1 : 0] offset = d_addr[`WORD_OFF_SIZE_D + 1            : 2];
    //cache_data*16
    wire [32 * WORDS_PER_LINE - 1:0]       cache_line;
    wire [32 * WORDS_PER_LINE - 1:0]       w_line; 
    //cache本身保存的
    wire                                   cache_valid;
    wire                                   cache_dirty;
    wire [`TAG_SIZE_D - 1 : 0]             cache_tag;
    wire [31:0]                            cache_data[WORDS_PER_LINE - 1 :0];
    //要写入的
    wire [`TAG_SIZE_D - 1 : 0]             w_tag;        
    reg                                    w_valid;
    reg                                    w_dirty;
    reg [31:0]                             w_data[WORDS_PER_LINE - 1 :0];
    //
    reg [`CNT_SIZE_D:0]                    cnt;
    reg                                    w_en;
    reg                                    w_en_dv;
    reg [4:0]                              state;
    reg [4:0]                              state_next;
    reg                                    state_small;

    reg [31:0]                             axi_wdata;
    //
    DCache_Ram my_DCache_Ram (
		.clk(clk),
        .wen(w_en),
        .wen_dv(w_en_dv),
        .resetn(resetn),

        .a(index),
        .dpra(index),
        .d(w_tag),
        .dpo(cache_tag),
        .dina(w_line),
        .douta(cache_line),

        .w_valid(w_valid),
        .w_dirty(w_dirty),
        .cache_valid(cache_valid),
        .cache_dirty(cache_dirty)

	);
    //读连线导出分解：线到线
    genvar i;
    generate for (i = 0; i < WORDS_PER_LINE; i = i + 1) begin
	assign cache_data[i] = cache_line[i*32 +: 32];
    end
	endgenerate
    //写连线合并导入：reg到线
    assign w_tag = tag;
    generate for (i = 0; i < WORDS_PER_LINE; i = i + 1) begin
	assign w_line[i*32 +: 32] = w_data[i];
    end
	endgenerate
    //hit
    wire hit = cache_valid && (cache_tag == tag);
    //stall
    wire need_mem_write = resetn && cached && cache_valid && (
        ((d_en == 1) && !hit && cache_dirty)                  ||
        ((d_en == 2) && hit  && cache_dirty)                  ||
        ((d_en == 2) && !hit && cache_dirty)
    );
	wire need_mem_read  = resetn && cached &&                (
        ((d_en == 1) && !cache_valid )                        ||
        ((d_en == 1) && cache_valid  && !hit && !cache_dirty) ||
        ((d_en == 2) && !cache_valid && !hit)                 ||
        ((d_en == 2) && cache_valid  && !hit && !cache_dirty)
    );
     //关于uncached
    reg [31:0] uncached_data;
    wire need_uncached_read  = !cached && (d_en == 2'b01);
    wire need_uncached_write = !cached && (d_en == 2'b10);
    //
    reg [1:0] d_en_next;
    reg need_mem_read_next;
    reg need_mem_write_next;
    reg need_uncached_read_next;
    reg need_uncached_write_next;
    always@(posedge clk) begin
        if(!resetn) begin
            state_next  <= `HIT;
        end
        else begin
            state_next <= state;
            d_en_next  <= d_en;
            need_mem_read_next <= need_mem_read;
            need_mem_write_next <= need_mem_write;
            need_uncached_read_next <= need_uncached_read;
            need_uncached_write_next <= need_uncached_write;
        end
    end//剩下的先不加上
    //logic FSM controller//只控制控制性变量
    always@(*) begin
        if(!resetn_p && !resetn) begin
            w_en  = 1;
            w_en_dv = 1;
        end
        else if(resetn_p && !resetn) begin
            w_en  = 0;
            w_en_dv = 0;
        end
        else if(resetn_p && resetn) begin
            w_en  = 0;
            w_en_dv = 0;
        end
        d_rdata   = 0;
        d_stall   = 0;
        case(state_next)
        `HIT:begin
            //命中读
            if((d_en == 2'b01) && !need_mem_read && !need_mem_write && !need_uncached_read && !need_uncached_write) begin
                d_stall = 1;
            end
            //命中写，转到HIT_WRITE_BEFORE
            else if((d_en == 2'b10) && !need_mem_read && !need_mem_write && !need_uncached_read && !need_uncached_write) begin
                d_stall = 1;
            end
            //不工作
            else if(d_en == 2'b00) begin
                d_stall = 0;
            end
            //转到其他状态
            else begin
                d_stall = resetn;
            end
        end
        `HIT_READ_AFTER: begin
            if(!((d_en_next == 2'b01) && !need_mem_read_next && !need_mem_write_next && !need_uncached_read_next && !need_uncached_write_next)) begin
                d_stall  = 1;
            end
            else begin
                d_stall  = 0;
                d_rdata  = cache_data[offset];
            end
        end
        `HIT_WRITE_BEFORE: begin
            d_stall = 1;
            if(!((d_en_next == 2'b10) && !need_mem_read_next && !need_mem_write_next && !need_uncached_read_next && !need_uncached_write_next)) begin
                w_en    = 0;
                w_en_dv = 0;
            end
            else begin
                w_en    = 1;
                w_en_dv = 1;
            end
        end
        `HIT_WRITE : begin
            w_en     = 0;
            w_en_dv  = 0;
            d_stall  = 0;
        end
        `MEM_READ_PRE : begin
            d_stall   = 1;
        end
        `MEM_READ_ON : begin
            d_stall   = 1;
        end
        `MEM_READ_END : begin
            d_stall   = 1;
            w_en      = 1;
            w_en_dv   = 1;
        end
        `MEM_READ_END_TRUE: begin
            d_stall   = 0;
            w_en      = 0;
            w_en_dv   = 0;
            d_rdata   = w_data[offset] ;
        end

        `MEM_WRITE_PRE: begin
            d_stall   = 1;
        end
        `MEM_WRITE_ON: begin
            d_stall   = 1;
            w_en_dv   = 1;
        end
        `MEM_WRITE_END: begin
            w_en_dv   = 0;
            if(!state_small) begin
                d_stall = 1;
            end
            else if(state_small && hit) begin
                d_stall = 1;
            end
            else if(state_small && !hit) begin
                d_stall = 1;
            end  
        end

        `UNCACHED_READ_PRE : begin
            d_stall   = 1;
        end
        `UNCACHED_READ_ON : begin
            d_stall   = 1;
        end
        `UNCACHED_READ_END : begin
            d_stall   = 0;
            d_rdata   = uncached_data;
        end
        
        `UNCACHED_WRITE_PRE: begin
            d_stall   = 1;
        end
        `UNCACHED_WRITE_ON: begin
            d_stall   = 1;
        end
        `UNCACHED_WRITE_END: begin
            if(state_small)
                d_stall = 0;
            else
                d_stall = 1;
        end
        endcase

    end    
    reg [100:0] uncached_data_cnt;
    reg [100:0] cached_data_cnt;
	// FSM controller
    assign wdata = cached ? axi_wdata : d_wdata;
    integer k,j;
    always @(posedge clk) begin
        if(!resetn) begin
            cnt         <= 0;
            
            for(k = 0; k < WORDS_PER_LINE ;k = k + 1)
                w_data[k] <= 0;
            w_dirty     <= 0;
            w_valid     <= 0;
            state_small <= 0;

            arid        <= 0;
            araddr      <= 0;
            arlen       <= 0;
            arsize      <= 0;
            arvalid     <= 0;
            awaddr      <= 0;
            awlen       <= 0;
            awsize      <= 0;
            awvalid     <= 0;
            wstrb       <= 0;
            wlast       <= 0;
            wvalid      <= 0;
 
            state       <= `HIT;
            //
            uncached_data_cnt <= 0;
            cached_data_cnt   <= 0;
        end
        else begin
            arvalid     <= 0;
            awvalid     <= 0;
            wvalid      <= 0; 
            wlast       <= 0;   
                 
            case(state)
            `HIT : begin
                if(need_mem_read) begin
                    cnt          <= 0;
                    state        <= `MEM_READ_PRE;
                end
                else if(need_mem_write ) begin
                    cnt          <= 0;
                    state        <= `MEM_WRITE_PRE;
                    state_small  <= 0;
                end
                else if(need_uncached_read) begin
                    state        <= `UNCACHED_READ_PRE;
                end
                else if(need_uncached_write) begin
                    state        <= `UNCACHED_WRITE_PRE;
                    state_small  <= 0;
                end
                else begin
                    if((d_en == 2'b10)) begin
                        state    <= `HIT_WRITE_BEFORE;
                    end
                    else if((d_en == 2'b01)) begin
                        state    <= `HIT_READ_AFTER;
                    end
                end
            end
            `HIT_WRITE_BEFORE :begin
                if(!((d_en == 2'b10) && !need_mem_read && !need_mem_write && !need_uncached_read && !need_uncached_write)) begin
                    state        <= `HIT;
                end
                else begin
                    w_dirty  <= 1;
                    for(j = 0 ;j < WORDS_PER_LINE; j = j + 1) begin
                        w_data[j][31:24] <= (((offset==j)&&w_b_s[3]) ? d_wdata[31:24] : cache_data[j][31:24]);
                        w_data[j][23:16] <= (((offset==j)&&w_b_s[2]) ? d_wdata[23:16] : cache_data[j][23:16]);
                        w_data[j][15:8]  <= (((offset==j)&&w_b_s[1]) ? d_wdata[15:8]  : cache_data[j][15:8]);
                        w_data[j][7:0]   <= (((offset==j)&&w_b_s[0]) ? d_wdata[7:0]   : cache_data[j][7:0]);
                    end
                    state             <= `HIT_WRITE; 
                end
            end
            `HIT_READ_AFTER: begin
                if(!((d_en == 2'b01) && !need_mem_read && !need_mem_write && !need_uncached_read && !need_uncached_write)) begin
                    state <= `HIT;
                end
                else begin
                    state <= `HIT; 
                end
            end
            `HIT_WRITE :begin
                state <= `HIT;
            end
            `MEM_READ_PRE: begin
                if(!need_mem_read) begin
                    state <= `HIT;
                end
                else if(arvalid && arready) 
                    state <= `MEM_READ_ON;
                else begin
                    arid         <= 4'b0101;
                    araddr       <= {d_addr[31:`WORD_OFF_SIZE_D + 2],{(`WORD_OFF_SIZE_D + 2){1'b0}}};
                    arlen        <= `AXI_COUNT_D;
                    arsize       <= `AXI_SIZE_D;
                    arvalid      <= 1;
                    
                    w_valid      <= 0;
                end
            end
            `MEM_READ_ON: begin
                if(rvalid) begin
                    if((cnt == offset) && (d_en == 2'b10)) begin
                        w_data[cnt][31:24] <= (w_b_s[3] ? d_wdata[31:24] : rdata[31:24]);
                        w_data[cnt][23:16] <= (w_b_s[2] ? d_wdata[23:16] : rdata[23:16]);
                        w_data[cnt][15:8]  <= (w_b_s[1] ? d_wdata[15:8]  : rdata[15:8]);
                        w_data[cnt][7:0]   <= (w_b_s[0] ? d_wdata[7:0]   : rdata[7:0]);
                        w_dirty            <= 1;
                    end
                    else begin
                        w_data[cnt]    <= rdata;
                    end

                    cnt          <= cnt + 1;

                    if(rlast) begin
                        state          <= `MEM_READ_END;
                        w_valid        <= 1;
                    end
                end
            end
            `MEM_READ_END: begin
                    state        <= `MEM_READ_END_TRUE;
            end
            `MEM_READ_END_TRUE: begin
                    state        <= `HIT;
            end

            `MEM_WRITE_PRE: begin
                if(!need_mem_write) begin
                    state <= `HIT;
                end
                else if(awvalid && awready) begin
                    state        <= `MEM_WRITE_ON ;//不去管wready
                    wstrb        <= 4'hF;
                    cached_data_cnt <= cached_data_cnt + 1;
                end
                else begin
                    awaddr       <= {cache_tag,d_addr[`WORD_OFF_SIZE_D + `INDEX_SIZE_D + 1 :`WORD_OFF_SIZE_D + 2],{(`WORD_OFF_SIZE_D + 2){1'b0}}};
                    awlen        <= `AXI_COUNT_D;
                    awsize       <= `AXI_SIZE_D;
                    awvalid      <= 1;
                end
            end
            `MEM_WRITE_ON: begin
                wvalid          <= 1;
                axi_wdata       <= cache_data[cnt];
                wstrb           <= 4'hF;
                if(cnt == `AXI_COUNT_D) begin
                    state        <= `MEM_WRITE_END;
                    w_dirty      <= 0;
                    wlast        <= 1;
                end
                else begin
                    cnt          <= cnt + 1;
                end
            end
            `MEM_WRITE_END: begin
                if(bvalid) begin
                    state_small  <= 1; 
                    cnt          <= 0;
                    if(hit) begin
                        state      <= `HIT;
                    end
                    else begin
                        state      <= `MEM_READ_PRE;
                    end
                end
            end

            `UNCACHED_READ_PRE : begin
                if(!need_uncached_read) begin
                    state   <= `HIT;
                end
                else if(arvalid && arready) 
                    state   <= `UNCACHED_READ_ON;
                else begin
                    arid    <= 4'b0100;
                    araddr  <= d_addr;
                    arlen   <= 4'h0;
                    arsize  <= d_size;
                    arvalid <= 1;
                end
            end
            `UNCACHED_READ_ON: begin
                if(rvalid) begin
                    uncached_data  <= rdata;
                    if(rlast) begin
                        state <= `UNCACHED_READ_END;
                    end
                end
            end
            `UNCACHED_READ_END: begin
                    state   <= `HIT;
            end

            `UNCACHED_WRITE_PRE: begin
                if(!need_uncached_write) begin
                    state   <= `HIT;
                end
                else if(awvalid && awready) begin
                    state <= `UNCACHED_WRITE_ON;
                    uncached_data_cnt <= uncached_data_cnt + 1;
                end
                else begin
                    awaddr  <= d_addr;
                    awlen   <= 4'h0;
                    awsize  <= d_size;
                    awvalid <= 1;
                end
            end
            `UNCACHED_WRITE_ON:begin
                if(wvalid && wready) 
                    state   <= `UNCACHED_WRITE_END;
                else begin
                    wstrb   <= w_b_s;
                    wvalid  <= 1;
                    wlast   <= 1;
                end
            end
            `UNCACHED_WRITE_END:
                if(bvalid) begin
                    state_small <= 1;
                    state       <= `HIT;
                end
            endcase
        end
    end
endmodule
