module mem(
    //to ex
    input  [31:0]  addr_ex,
    input          is_stall,
    input  [1:0]   ls,
    input  [3:0]   b_s,
    input  [31:0]  data_ex,
    input          sign,
    //to DCache
    output [31:0]  d_addr,
    output [31:0]  d_wdata,
    input  [31:0]  d_rdata,
    output [2:0]   d_size,
    // to wb
    output [31:0]  data_mem
);

    always@(*) begin
        data_mem = data_ex;
        
        case()
    end
endmodule