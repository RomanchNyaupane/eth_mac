module mdio(
    input wire clk,
    input wire rst,
    input wire mdio_init,
    input wire [4:0] reg_addr,
    input wire [15:0] data,
    input wire status_req,

    inout wire mdio_out,
    
    output reg mdc,
    output reg write_over,  //indiates write to a given register is over.
    output reg mdio_ready
);
reg [2:0] state,next_state;
localparam IDLE = 3'b000,
           PREAMBLE_STATE = 3'b001,
           START_STATE = 2'b010,
           OPCODE_STATE = 3'b011,
           PHY_ADDR_STATE = 3'b100,
           REG_ADDR_STATE = 3'b101,
           TA_STATE = 3'b110,
           DATA_STATE = 3'b111;

//mdio frame fields
localparam PREAMBLE = 32'hffff_ffff;
localparam START = 2'b00;
localparam OPCODE_WRITE = 2'b01;
localparam OPCODE_READ = 2'b10;
localparam TA = 2'b10;  //turn around field
localparam PHY_ADDR = 5'b00001; //example phy address
reg [4:0] REG_ADDR; //register address
reg [15:0] DATA; //data to write
reg [15:0] DATA_READ; //data read from phy

//control signals
reg internal_mdio_init; //internal signal to start mdio transaction. if mdio_init is set when mdio
reg [5:0] bit_count; //counts bits sent/received
reg count_en, count_rst; //control signals for bit counter
reg data_addr_load;
reg status_check;
reg status;

//mdio output control
reg mdio_out_en;
reg mdio_data_out;
always @(*) begin
    mdc = clk;
    internal_mdio_init = ~mdio_ready & mdio_init; //latch mdio_init
end
assign mdio_out = mdio_out_en ? mdio_data_out : 1'bz; //tri-state mdio line

always @(posedge clk) begin
    if (data_addr_load) begin
        REG_ADDR <= reg_addr;
        DATA <= data;
    end else begin
        REG_ADDR <= REG_ADDR;
        DATA <= DATA;
    end
end

always @ (posedge clk) begin
    if (rst) begin
        state <= IDLE;
        mdio_ready <= 1'b0;
        mdio_out_en <= 1'b0; //mdio line is input
    end else begin
        state <= next_state;
        if(status_req) begin
            mdio_ready <= DATA_READ[0]; //return lsb of status register to indicate if phy is ready
        end else begin
            mdio_ready <= mdio_ready;
        end
    end
end

//to configure the phy registers, assert mdio_init, place reg_addr and data on the bus. do not deassert mdio_init until all registers are configured.
//after entering address and data for each register, place another register's address and data before previous writing gets completed. mdio_init should not be deasserted during this period
//to read the status register, deassert mdio_init and assert status_req. the lsb of the status register will be returned on mdio_ready.
always @(*) begin
    //default values
    next_state = state;
    count_en = 1'b0;
    count_rst = 1'b0;
    mdio_out_en = 1'b0; //default to input
    //mdio_data_out = 1'b0;
    data_addr_load = 1'b0;
    status_check = 1'b0;
    write_over = 1'b0;
    case(state)
        IDLE: begin
            if(internal_mdio_init) begin                 //mdio_init should not last the entire frame
                next_state = PREAMBLE_STATE;
                count_en = 1'b1;
                mdio_out_en = 1'b1;
                data_addr_load = 1'b1;
            end else begin
                // if internal_mdio_init is not set(and state is about to be IDLE), check if phy register is ready by checking the status register
                if(status_req) begin
                    status_check = 1'b1;
                    next_state = PREAMBLE_STATE;
                    count_en = 1'b1;
                    count_rst = 1'b0;
                end else begin
                    status_check = 1'b0;
                    next_state = IDLE;
                    count_rst = 1'b1;
                end
            end
        end
        PREAMBLE_STATE: begin
            //send preamble
            mdio_data_out = PREAMBLE[31 - bit_count];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd31) begin
                next_state = START_STATE;
                //count_en = 1'b0;
            end else begin
                next_state = PREAMBLE_STATE;
            end
        end
        START_STATE: begin
            //send start bits
            mdio_data_out = START[bit_count-32];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd33) begin
                next_state = OPCODE_STATE;
                //count_en = 1'b0;
            end else begin
                next_state = START_STATE;
            end
        end
        OPCODE_STATE: begin
            //send opcode bits
            mdio_data_out = status_check ? OPCODE_READ[bit_count-34] : OPCODE_WRITE[bit_count-34];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd35) begin
                next_state = PHY_ADDR_STATE;
                //count_en = 1'b0;
            end else begin
                next_state = OPCODE_STATE;
            end
        end
        PHY_ADDR_STATE: begin
            //send phy address bits
            mdio_data_out = PHY_ADDR[bit_count-36];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd40) begin
                next_state = REG_ADDR_STATE;
                //count_en = 1'b0;
            end else begin
                next_state = PHY_ADDR_STATE;
            end
        end
        REG_ADDR_STATE: begin
            //send register address bits
            mdio_data_out = REG_ADDR[bit_count-41];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd45) begin
                next_state = TA_STATE;
                //count_en = 1'b0;
            end else begin
                next_state = REG_ADDR_STATE;
            end
        end
        TA_STATE: begin
            //send turn around bits
            mdio_data_out = TA[bit_count-46];
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd47) begin
                next_state = DATA_STATE;
                //count_en = 1'b0;
            end else begin
                next_state = TA_STATE;
            end
        end
        DATA_STATE: begin
            //send data bits
            if(status_check) begin
                //read data from phy
                mdio_out_en = 1'b0; //release mdio line for reading
                if(bit_count >= 6'd48 && bit_count <= 6'd63) begin
                    DATA_READ[bit_count-48] = mdio_out; //sample mdio line
                end
            end else begin
                //write data to phy
                mdio_data_out = DATA[bit_count-48];
            end
            mdio_out_en = 1'b1;
            count_en = 1'b1;
            if(bit_count == 6'd63) begin
                next_state = IDLE;
                mdio_out_en = 1'b0; //release mdio line
                count_en = 1'b0;
                count_rst = 1'b1;
                write_over = 1'b1;
            end else begin
                next_state = DATA_STATE;
            end
        end

    endcase
end


always @(posedge clk) begin
    if (rst | count_rst) begin
        bit_count <= 6'b111111;
    end else begin
        bit_count <= (bit_count + count_en) & {6{~count_rst}}; //increment if count_en is high
    end
end
endmodule