// the ethernet type frame is decoded in this module. this module does not decode 802.3x frames
module mac_rx(
    input wire clk,
    input wire rst,
    input wire config_ready,    //indicates completion of mdio and phy configuration
    input wire rx_dv,
    input wire [7:0] rx_data,

    output reg [7:0] mac_rxd,
);
parameter   IDLE = 3'b000,
            PREAMBLE = 3'b001,
            SFD = 3'b010,
            DEST_MAC = 3'b011,
            SRC_MAC = 3'b100,
            TYPE = 3'b101,
            DATA = 3'b110,
            FCS = 3'b111;


localparam BYTE_SHIFT = 8;
//large buffers
reg [7:0] payload [0:1520]; //buffer to store incoming data, max ethernet frame size is 1518 bytes

//internal counters/buffer registers
reg [10:0] byte_count; //to count number of bytes received, max 1520 bytes
reg [10:0] payload_count; //to separately payload

reg [7:0] byte_drop_reg;   //to drop bytes like preamble and sfd
reg [47:0] dest_mac_reg;
reg [47:0] src_mac_reg;
reg [15:0] frame_type_reg;
reg [31:0] crc_reg;


//control signals
reg count_en, count_rst;
reg payload_count_en, payload_count_rst;
reg frame_drop_en;  //to enable dropping of frames
reg dest_mac_en, src_mac_en, type_len_en, data_en, fcs_en;
reg [2:0] state, next_state;

//state transition
always @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//state machine
always @(*) begin
    frame_drop_en = 1'b0;
    count_en = 1'b0;
    payload_count_en = 1'b0;
    count_rst = 1'b0;
    payload_count_rst = 1'b0;
    dest_mac_en = 1'b0;
    src_mac_en = 1'b0;
    type_len_en = 1'b0;
    data_en = 1'b0;
    fcs_en = 1'b0;
    case(state)
        IDLE: begin
            if(rx_dv) begin
                next_state = PREAMBLE;
                count_en = 1'b1;
                count_rst = 1'b0;
            end else begin
                next_state = IDLE;
                count_en = 1'b0;
                count_rst = 1'b0;
            end
        end
        PREAMBLE: begin
            frame_drop_en = 1'b1;
            count_en = 1'b1;
            if(byte_counter == 31) next_state = SFD; else next_state = PREAMBLE;
        end
        SFD: begin
            frame_drop_en = 1'b1;
            count_en = 1'b1;
            if(byte_counter == 48)
                next_state = DEST_MAC;
            else
                next_state = SFD;
        end
        // we may have to stop the packet receiving at this point if the packet has destination mac address that is not for us. this logic is yet to be added
        DEST_MAC: begin
            dest_mac_en = 1'b1;
            if(byte_counter == 96)
                next_state = SRC_MAC;
            else
                next_state = DEST_MAC;
        end
        SRC_MAC: begin
            src_mac_en = 1'b1;
            if(byte_counter == 142) 
                next_state = TYPE;
            else
                next_state = SRC_MAC;
        end
        TYPE: begin
            type_len_en = 1'b1;
            if(byte_couter == 144) 
                next_state = DATA; 
            else 
                next_state = TYPE;
        end
        DATA: begin
            payload_count_en = 1'b1;
            data_en = 1'b1;
            if(!rx_dv) 
                next_state = IDLE; 
            else 
                next_state = DATA;
        end
    endcase
end

//buffer write logic
always @(posedge clk) begin
    if(rst) begin
        
    end else begin
        case({frame_drop_en, dest_mac_en, src_mac_en, type_len_en, data_en, fcs_en})
            6'b100000: byte_drop_reg <= rx_data;
            6'b010000: dest_mac_reg <= (dest_mac_reg << BYTE_SHIFT) | (rx_data);
            6'b001000: src_mac_reg <= (src_mac_reg << BYTE_SHIFT) | (rx_data);
            6'b000100: frame_type_reg <= (frame_type_reg << BYTE_SHIFT) | rx_data;
            6'b000010: payload[payload_count] <= rx_data;
            default : ;
        endcase
    end
end

//byte counter
always @(posedge clk) begin
    if(rst) begin
        byte_count <= 11'b1;
    end else begin
        byte_count <= byte_count + count_en & {11{~count_rst}};
    end
end

//payload counter
always @(posedge clk) begin
    if(rst) begin
        payload_count <= 11'b1;
    end else begin
        payload_count <= payload_count + payload_count_en & {11{~payload_count_rst}};
    end
end

endmodule