module pc(
        input                    clk,
        input                    resetn,
        input                    en,
        input                    i_ready_1,
        input                    i_ready_2,
        input                    full,

        input                    is_branch,
        input  [31:0]            addr_branch,
        input                    is_exception,
        input  [31:0]            addr_exception,

        output reg [31:0]        pc,
        output [1:0]             i_en
);

    reg     [31:0] npc;
    

    always@(posedge clk) begin
        if(!resetn) begin
            pc   <= 32'h0000_0000;
        end
        else begin
            pc   <= npc;
        end
    end
    assign i_en = {0,en};
    always@(*) begin
        if(!resetn)
            npc = 32'hBFC0_0000; 
        else if(en) begin
            if(is_exception)
                npc = addr_exception;
            else if(is_branch)
                npc = addr_branch;
            else if(full)
                npc = pc;
            else if(i_ready_1 && i_ready_2)
                npc = pc + 8;
            else if(i_ready_1 && !i_ready_2)
                npc = pc + 4;
            else
                npc = pc;
        end
        else begin
            npc = pc; 
        end
    end
endmodule