module mem(
    //to ex
    input  [31:0]  addr_ex,
    input          is_stall,
    input  [1:0]   ls,
    input  [3:0]   byte_select_ex,//w_b_s
    input  [31:0]  data_ex,
    input          sign,
    //to mmu(DCache)
    output reg [31:0]  d_addr,
    output reg [31:0]  d_wdata,
    output reg [2:0]   d_size,
    output reg [1:0]   d_en,
    output reg [3:0]   w_byte_select,
    input      [31:0]  d_rdata,
    // to wb
    output reg [31:0]  data_mem
);
    //
    reg [3:0] byte_select;
    always@(*) begin
        case(byte_select_ex) 
        //B
        4'b0001:begin
            case(addr_ex[1:0])
            2'b00: byte_select = 4'b0001;
            2'b01: byte_select = 4'b0010;
            2'b10: byte_select = 4'b0100;
            2'b11: byte_select = 4'b1000;
            endcase
        end
        //H
        4'b0011: begin
            case(addr_ex[1])
            1'b0: byte_select = 4'b0011;
            1'b1: byte_select = 4'b1100;
            endcase
        end
        //W
        4'b1111: byte_select = 4'b1111;
        default: byte_select = 4'b1111;
        endcase
    end
    //
    always@(byte_select) begin
        if(byte_select == 4'b1111) begin
            d_size   = 3'b010;
        end
        else if((byte_select == 4'b1100) || (byte_select == 4'b0011)) begin
            d_size   = 3'b001;
        end
        else if((byte_select == 4'b0001) || (byte_select == 4'b0010) || (byte_select == 4'b0100) || (byte_select == 4'b1000)) begin
            d_size   = 3'b000;
        end
        else begin
            d_size   = 3'b000;
        end
    end
    //
    always@(*) begin
        if(is_stall) begin
            data_mem = data_ex;//这个给他送过去应该也没事
            d_en     = 2'b00;
            w_byte_select    = 0;
            d_addr   = 0;
            d_wdata  = 0;
        end
        else begin
            case(ls)
            2'b00: begin
                data_mem = data_ex;
                d_en     = 2'b00;
                w_byte_select    = 0;
                d_addr   = 0;
                d_wdata  = 0;
            end
            //L
            2'b01: begin
                d_en     = 2'b01;
                w_byte_select     = 0;
                d_addr   = addr_ex;
                d_wdata  = 0;
                case(d_size)
                //LW
                3'b010: begin
                    data_mem = d_rdata;
                end
                //LHU、LH
                3'b001: begin
                    data_mem = sign ? (byte_select[0] ? {{16{d_rdata[15]}},d_rdata[15:0]} : {{16{d_rdata[31]}},d_rdata[31:16]}) : (byte_select[0] ? {16'b0,d_rdata[15:0]} : {16'b0,d_rdata[31:16]});
                end
                //LBU、LB
                3'b000: begin
                    case(byte_select)
                    4'b0001: begin
                        data_mem = sign ? {{24{d_rdata[7]}},d_rdata[7:0]} : {24'b0,d_rdata[7:0]};
                    end
                    4'b0010: begin
                        data_mem = sign ? {{24{d_rdata[15]}},d_rdata[15:8]} : {24'b0,d_rdata[15:8]};
                    end
                    4'b0100: begin
                        data_mem = sign ? {{24{d_rdata[23]}},d_rdata[23:16]} : {24'b0,d_rdata[23:16]};
                    end
                    4'b1000: begin
                        data_mem = sign ? {{24{d_rdata[31]}},d_rdata[31:24]} : {24'b0,d_rdata[31:24]};
                    end
                    endcase 
                end
                endcase
            end
            //S
            2'b10: begin
                d_en     = 2'b01;
                w_byte_select     = byte_select;
                d_addr   = addr_ex;
                d_wdata  = data_ex;
                data_mem = 0;
            end
            endcase
        end
    end
endmodule