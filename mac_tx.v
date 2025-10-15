module mac_tx(
    input wire clk,
    input wire rst,
    input wire [7:0] tx_data,   //tx_data contains destination mac, frame type and payload to be imported to this module
    input wire init, //the tx_data is sampled by this module at every clock high until init is high.
    input wire frame_end,
    
    input wire config_ready,    //always set this to 1 for simulation

    output reg tx_fifo_wr_en, //to write to tx_fifo
    output reg tx_fifo_rd_en, //to read from tx_fifo
    output reg [7:0] tx_fifo_wr_data, //data to be written to tx_fifo

    output wire [7:0] mac_out,
    output reg frame_over
);

//output logic
assign mac_out = crc_out_en? crc_buffer[crc_counter] : mac_txd;

wire [31:0] crc_out;
mac_crc_tx crc_inst(
    .data_in(mac_txd),
    .crc_en(crc_en),
    .crc_init(crc_init),
    .crc_out(crc_out),
    .rst(rst),
    .clk(clk)
);

wire [7:0] tx_fifo_rd_data;
wire tx_fifo_empty;
wire tx_fifo_full;
mac_tx_fifo tx_fifo_inst(
    .clk(clk),
    .rst(rst),
    .tx_fifo_wr_data(tx_fifo_wr_data),
    .tx_fifo_wr_en(tx_fifo_wr_en),
    .tx_fifo_rd_en(tx_fifo_rd_en),
    .tx_fifo_full(tx_fifo_full),
    .tx_fifo_empty(tx_fifo_empty),
    .tx_fifo_rd_data(tx_fifo_rd_data)
);
//mdio mdio_inst(
//    .config_ready(config_ready)
//);

localparam _PREAMBLE = 8'hbc;
reg [7:0] _SRC_MAC [0:5]; //source mac address
initial begin
    _SRC_MAC[0] = 8'hde;
    _SRC_MAC[1] = 8'had;
    _SRC_MAC[2] = 8'hbe;
    _SRC_MAC[3] = 8'hef;
    _SRC_MAC[4] = 8'hca;
    _SRC_MAC[5] = 8'hfe;
end

//constants
localparam COUNTER_WIDTH = 11;

//control and status signals
reg count_en, count_rst;
reg crc_count_en, crc_count_rst;
reg runtime_count_en, runtime_count_rst;
reg crc_init;
reg tx_busy;
reg preamble_en;
reg dest_mac_en;
reg src_mac_en;
reg frame_type_en;
reg payload_en;
reg crc_en;
reg crc_out_en;
reg frame_sent;

//counters and buffers
reg [COUNTER_WIDTH - 1 : 0] byte_counter;
reg [7:0] crc_buffer [0:3]; //to hold the crc value from crc module
reg [3:0] runtime_counter; //a general counter to be used in various states
reg [1:0] crc_counter;
reg counting; //to latch frame_end stimulus
reg [13:0] end_reg; //to shift frame_end signal 14 times to compensate for 14 cycle pipeline delay;
reg [7:0] mac_txd; //to hold transmit value

//state machine parameters
reg [2:0] state, next_state;
parameter IDLE = 3'b000,
            PREAMBLE = 3'b001,
            SFD = 3'b010,         //although there is no SFD field in ethernet frame, we will still use this state to count 8 bytes of preamble haha
            DEST_MAC = 3'b011,
            SRC_MAC = 3'b100,
            FRAME_TYPE = 3'b101,
            DATA = 3'b110,
            CRC = 3'b111;

//state transition
always @(posedge clk) begin
    if(rst) begin
        state <= IDLE;
        mac_txd <= 8'b0;
        end_reg <= 14'b0;
    end else begin
        state <= next_state;
        tx_fifo_wr_data <= tx_data;
        end_reg <= (end_reg << 1) | frame_end;
    end
end

//state machine
always @(*) begin
    count_en = 1'b0;
    count_rst = 1'b0;
    tx_busy = 1'b0;
    crc_init = 1'b0;
    preamble_en = 1'b0;
    dest_mac_en = 1'b0;
    src_mac_en = 1'b0;
    frame_type_en = 1'b0;
    payload_en = 1'b0;
    crc_en = 1'b0;
    tx_fifo_wr_en = 1'b0;
    tx_fifo_rd_en = 1'b0;
    runtime_count_en = 1'b0;
    runtime_count_rst = 1'b0;
    crc_count_en = 1'b0;
    crc_count_rst = 1'b0;
    crc_out_en = 1'b0;
    frame_sent = 1'b0;
    
    counting = |(end_reg);
    case(state) 
        IDLE: begin
            if(init & !tx_busy & config_ready) begin
                next_state = PREAMBLE;
                tx_busy = 1'b1;
                count_en = 1'b1;
            end else next_state = IDLE;
        end
        PREAMBLE: begin
            count_en = 1'b1;
            tx_busy = 1'b1;
            preamble_en = 1'b1;
            tx_fifo_wr_en = 1'b1;
            if(byte_counter == 11'd6) begin
                next_state = SFD;
            end else next_state = PREAMBLE;
        end
        SFD: begin  //preamble and sfd are not separate but we will still use this state to count 8 bytes of preamble. haha
            count_en = 1'b1;
            preamble_en = 1'b1;
            tx_busy = 1'b1;
            if(byte_counter == 11'd7) begin
                next_state = DEST_MAC;
                tx_fifo_wr_en = 1'b1;
            end else next_state = SFD;
        end
        DEST_MAC: begin
            crc_init = 1'b1;
            count_en = 1'b1;
            tx_busy = 1'b1;
            dest_mac_en = 1'b1;
            tx_fifo_wr_en = 1'b1;
            tx_fifo_rd_en = 1'b1;
            if(byte_counter == 11'd13) begin
                next_state = SRC_MAC;
                tx_fifo_rd_en = 1'b0;
            end else next_state = DEST_MAC;
        end
        SRC_MAC: begin
            tx_busy = 1'b1;
            crc_init = 1'b1;
            count_en = 1'b1;
            src_mac_en = 1'b1;
            runtime_count_en = 1'b1;
            tx_fifo_wr_en = 1'b1;
            if(runtime_counter == 4'b0101 & byte_counter == 11'd19) begin
                next_state = FRAME_TYPE;
                tx_fifo_rd_en = 1'b1; //since read data appears after one cycle of asserting, we are asserting one cycle before state transition
                runtime_count_en = 1'b0;
                runtime_count_rst = 1'b1;
            end else next_state = SRC_MAC;
        end
        FRAME_TYPE: begin
            tx_fifo_wr_en = 1'b1;
            crc_init = 1'b1;
            count_en = 1'b1;
            tx_busy = 1'b1;
            frame_type_en = 1'b1;
            tx_fifo_rd_en = 1'b1;
            if(byte_counter == 11'd21) begin
                next_state = DATA;
            end else next_state = FRAME_TYPE;
        end
        DATA: begin
            if(counting) begin
                runtime_count_en = 1'b1;      
            end else runtime_count_en = 1'b0;
            
            if(runtime_counter == 4'd14) begin
                next_state = CRC;
                runtime_count_rst = 1'b1;
                runtime_count_en = 1'b1;
            end else begin
                next_state = DATA;
                crc_count_en = 1'b0;
                crc_init = 1'b1;
                count_en = 1'b1;
                tx_busy = 1'b1;
                payload_en = 1'b1;
                tx_fifo_rd_en = 1'b1;
                tx_fifo_wr_en = 1'b1;
            end
        end
        CRC: begin
            crc_count_en = 1'b1;
            crc_out_en = 1'b1;
            tx_busy = 1'b1;
            crc_en = 1'b1;
            //crc calculation was initialized at the start of DEST_MAC state. now time to output the crc value
            runtime_count_en = 1'b1;
            crc_buffer[0] = crc_out[7:0];
            crc_buffer[1] = crc_out[15:8];
            crc_buffer[2] = crc_out[23:16];
            crc_buffer[3] = crc_out[31:24];
            if(crc_counter == 2'b11) begin
                next_state = IDLE;
                runtime_count_en = 1'b0;
                runtime_count_rst = 1'b1;
                count_rst = 1'b1;
                frame_sent = 1'b1;
            end else next_state = CRC;
        end
    endcase
end

//sender block
always @(posedge clk) begin
    case({preamble_en, dest_mac_en, src_mac_en, frame_type_en, payload_en, frame_sent})
        6'b100000: mac_txd <= _PREAMBLE; //preamble and sfd
        6'b010000: mac_txd <= tx_fifo_rd_data;  //destination mac from fifo
        6'b001000: mac_txd <= _SRC_MAC[runtime_counter]; //source mac from register
        6'b000100: mac_txd <= tx_fifo_rd_data;  //frame type from fifo
        6'b000010: mac_txd <= tx_fifo_rd_data;  //payload from fifo
        6'b000001: frame_over <= frame_sent; //crc from crc module
        default: mac_txd <= mac_txd; //hold last value
    endcase
end

//counter
always @(posedge clk) begin
    if(rst) begin
        byte_counter <= 11'b11111111111;
        runtime_counter <= 4'b000;
        crc_counter <= 2'b0;
    end else begin
        byte_counter <= (byte_counter + count_en) & {COUNTER_WIDTH{~count_rst}};
        runtime_counter <= (runtime_counter + runtime_count_en) & {4{~runtime_count_rst}};
        crc_counter <= (crc_counter + crc_count_en) & {2{~crc_count_rst}};
    end
end

endmodule