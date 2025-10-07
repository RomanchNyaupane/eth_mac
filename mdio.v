module mdio(
    input wire clk,
    input wire rst,
    input wire mdio_init,
    
    output reg mdio_out,
    output reg mdc,
    output reg mdio_ready
);
reg [2:0] state,next_state;
localparam IDLE = 3'b000,
           PREAMBLE_STATE = 3'b001,
           START_STATE = 3'b010,
           OPCODE_STATE = 3'b011,
           PHY_ADDR_STATE = 3'b100,
           REG_ADDR_STATE = 3'b101,
           TA_STATE = 3'b110,
           DATA_STATE = 3'b111;

//mdio frame fields
localparam PREAMBLE = 32'hffff_ffff;
localparam START = 2'b01;
localparam OPCODE_WRITE = 2'b01;
localparam OPCODE_READ = 2'b10;
localparam TA = 2'b10;  //turn around field
localparam PHY_ADDR = 5'b00001; //example phy address
reg [4:0] REG_ADDR; //register address
reg [15:0] DATA; //data to write

//control signals
reg internal_mdio_init; //internal signal to start mdio transaction. if mdio_init is set when mdio
reg [5:0] bit_count; //counts bits sent/received
reg count_en, count_rst; //control signals for bit counter

//mdio output control
wire mdio_out_en;
reg mdio_data_out;
always @(*) begin
    mdc = clk;
    mdio_out = mdio_out_en ? mdio_data_out : 1'bz; //tri-state mdio line
    internal_mdio_init = ~mdio_ready & mdio_init; //latch mdio_init
end

always @ (posedge clk) begin
    if (rst) begin
        state <= IDLE;
        mdio_ready <= 1'b0;
        mdio_out_en <= 1'b0; //mdio line is input
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    //default values
    mdio_ready = 1'b0;
    next_state = state;
    count_en = 1'b0;
    count_rst = 1'b0;
    mdio_out_en = 1'b0; //default to input
    mdio_data_out = 1'b0;
    case(state)
        IDLE: begin
            if(internal_mdio_init) begin                 //mdio_init should not last the entire frame
                next_state = PREAMBLE_STATE;
                count_en = 1'b1;
                mdio_out_en = 1'b1;
            end else begin
                next_state = IDLE;
                mdio_ready = 1'b1;
                count_rst = 1'b1;
            end
        end
        PREAMBLE_STATE: begin
            //send preamble
            mdio_data_out = PREAMBLE[31 - bit_count];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd31) begin
                next_state = START_STATE;
                count_en = 1'b0;
            end else begin
                next_state = PREAMBLE_STATE;
            end
        end
        START_STATE: begin
            //send start bits
            mdio_data_out = START[bit_count-31];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd33) begin
                next_state = OPCODE_STATE;
                count_en = 1'b0;
            end else begin
                next_state = START_STATE;
            end
        end
        OPCODE_STATE: begin
            //send opcode bits
            mdio_data_out = OPCODE_WRITE[bit_count-33]; //example: always write
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd35) begin
                next_state = PHY_ADDR_STATE;
                count_en = 1'b0;
            end else begin
                next_state = OPCODE_STATE;
            end
        end
        PHY_ADDR_STATE: begin
            //send phy address bits
            mdio_data_out = PHY_ADDR[bit_count-35];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd40) begin
                next_state = REG_ADDR_STATE;
                count_en = 1'b0;
            end else begin
                next_state = PHY_ADDR_STATE;
            end
        end
        REG_ADDR_STATE: begin
            //send register address bits
            mdio_data_out = REG_ADDR[bit_count-40];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd45) begin
                next_state = TA_STATE;
                count_en = 1'b0;
            end else begin
                next_state = REG_ADDR_STATE;
            end
        end
        TA_STATE: begin
            //send turn around bits
            mdio_data_out = TA[bit_count-45];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd47) begin
                next_state = DATA_STATE;
                count_en = 1'b0;
            end else begin
                next_state = TA_STATE;
            end
        end
        DATA_STATE: begin
            //send data bits
            mdio_data_out = DATA[bit_count-47];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd62) begin
                next_state = IDLE;
                count_en = 1'b0;
            end else begin
                next_state = DATA_STATE;
            end
        end

    endcase
end


always @(posedge clk) begin
    if (rst | count_rst) begin
        bit_count <= 6'b0;
    end else begin
        bit_count <= (bit_count + count_en) & {6{~count_rst}}; //increment if count_en is high
    end
end
endmodule