module mmu(
    //to pc
    input [31:0]      addr_pc,
    output            i_ready_1_pc,
    output            i_ready_2_pc,
    input  [1:0]      i_en_pc,
    //to ICache
    input             i_ready_1_ICache,
    input             i_ready_2_ICache,
    input  [31:0]     i_data_1_ICache,
    input  [31:0]     i_data_2_ICache,
    input             i_stall,
    output reg        cached_ICache,
    output reg [31:0] i_addr,
    output [1:0]      i_en,
    //to DCache
    input             d_stall,
    input  [31:0]     d_rdata,
    output reg [31:0] d_addr,
    output [3:0]      w_b_s,
    output [1:0]      d_en,
    output [31:0]     d_wdata,
    output [2:0]      d_size,
    output reg        cached_DCache,
    //to mem
    output [31:0]     d_rdata_mem,
    input  [31:0]     d_addr_mem,
    input  [3:0]      w_b_s_mem,
    input  [1:0]      d_en_mem,
    input  [31:0]     d_wdata_mem,
    input  [2:0]      d_size_mem,
    //to others
    output [31:0]     i_data_1_if,
    output [31:0]     i_data_2_if,
    output            i_stall_cpu,
    output            d_stall_cpu
);
    assign i_ready_1_pc = i_ready_1_ICache;
    assign i_ready_2_pc = i_ready_2_ICache;
    assign i_data_1_if  = i_data_1_ICache;
    assign i_data_2_if  = i_data_2_ICache;
    assign i_stall_cpu  = i_stall;
    assign i_en         = i_en_pc;

    assign d_stall_cpu  = d_stall;
    assign d_rdata_mem  = d_rdata;
    assign w_b_s        = w_b_s_mem;
    assign d_en_mem     = d_en;
    assign d_wdata      = d_wdata_mem;
    assign d_size       = d_size_mem;

    always@(addr_pc) begin
        if(addr_pc < 32'hC000_0000 && addr_pc > 32'h9FFF_FFFF) begin
            i_addr        = addr_pc - 32'hA000_0000;
            cached_ICache = 0;
        end
        else if(addr_pc < 32'hA000_0000 && addr_pc > 32'h7FFF_FFFF) begin
            i_addr        = addr_pc - 32'h8000_0000;
            cached_ICache = 1;
        end
        else begin
            i_addr        = addr_pc;
            cached_ICache = 1;
        end
    end

    always@(d_addr_mem) begin
        if(d_addr_mem < 32'hC000_0000 && d_addr_mem > 32'h9FFF_FFFF) begin
            d_addr        = d_addr_mem - 32'hA000_0000;
            cached_DCache = 0;
        end
        else if(d_addr_mem < 32'hA000_0000 && d_addr_mem > 32'h7FFF_FFFF) begin
            d_addr        = d_addr_mem - 32'h8000_0000;
            cached_DCache = 1;
        end
        else begin
            d_addr        = d_addr_mem;
            cached_DCache = 1;
        end
    end

endmodule