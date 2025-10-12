module mac_tx(
    input wire clk,
    input wire rst,
    input wire [7:0] tx_data,   //tx_data contains destination mac, frame type and payload to be imported to this module
    input wire init, //the tx_data is sampled by this module at every clock high until init is high.
    
    output wire tx_fifo_wr_en, //to write to tx_fifo
    output wire tx_fifo_rd_en, //to read from tx_fifo
    output wire [7:0] tx_fifo_wr_data, //data to be written to tx_fifo
    input wire [7:0] tx_fifo_rd_data, //data read from tx_fifo
    input wire tx_fifo_empty, //tx_fifo empty flag
    input wire tx_fifo_full, //tx_fifo full flag

    output wire [7:0] mac_txd
);
localparam PREAMBLE = 64'hffff_ffff_ffff_ffff;
localparam SRC_MAC =  48'hffff_ffff_ffff;

//constants
localparam COUNTER_WIDTH = 11;

//control and status signals
reg count_en, count_rst;
reg crc_init;
reg tx_busy;
reg preamble_en;
reg dest_mac_en;
reg src_mac_en;
reg frame_type_en;
reg payload_en;
reg crc_en;

//counters and buffers
reg [COUNTER_WIDTH - 1 : 0] byte_counter;

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
    end else begin
        state <= next_state;
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
    case(state) 
        IDLE: begin
            if(init & !tx_busy) begin
                next_state = PREAMBLE;
                tx_busy = 1'b1;
                count_en = 1'b1;
            end else next_state = IDLE;
        end
        PREAMBLE: begin
            count_en = 1'b1;
            preamble_en = 1'b1;
        end
    endcase
end

//sender block
always @(posedge clk) begin
    case({preamble_en,dest_mac_en, src_mac_en,frame_type_en,payload_en,crc_en})
        6'b100000: mac_txd <= 
    endcase
end

//counter
always @(posedge clk) begin
    if(rst) begin
        byte_counter <= 11'b1;
    end else begin
        byte_counter <= (byte_counter + count_en) & {COUNTER_WIDTH{~count_rst}};
    end
end

endmodule