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

        output  reg [31:0]       pc
);

    reg     [31:0] npc;
    

    always@(posedge clk) begin
        pc <= npc;
    end
    always@(*) begin
        if(!resetn)
            npc = 32'hbfc00000; 
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