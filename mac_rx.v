// the ethernet type frame is decoded in this module. this module does not decode 802.3x frames
module mac_rx(
//    input wire clk,
//    input wire rst
    //input wire [7:0] rx_data,

    //output reg [7:0] mac_rxd,
    input wire clk,
    input wire rst,
    
    input wire phy_rx_clk,
    input wire phy_rx_ctl,
    input wire config_ready, //declared for testbench purpose. this signal is generated in mdio module
    
    input wire [3:0] phy_rxd
);

// module instantiation
wire rx_dv, rx_err;
wire [7:0] rx_data;
phy_rx phy_rx_inst(
    .clk(clk),
    .rst(rst),
    
    .phy_rx_clk(phy_rx_clk),
    .phy_rx_ctl(phy_rx_ctl),
    .config_ready(config_ready),
    .phy_rxd(phy_rxd),

    .mac_rxd(rx_data),
    .mac_rx_dv(rx_dv),
    .mac_rx_err(rx_err)
);
wire config_ready;
//mdio mdio_inst(
//    mdio_ready(config_ready)
//);

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
reg [31:0] payload_temp_reg; //temporarily store 4 bytes of payload by shifting. at end, there will be crc sent in packet in this register
reg [10:0] payload_length_reg;
reg [31:0] crc_reg;


//control signals
reg count_en, count_rst;
reg payload_count_en, payload_count_rst;
reg frame_drop_en;  //to enable dropping of frames
reg dest_mac_en, src_mac_en, type_len_en, data_en, fcs_en;
reg [2:0] state, next_state;

//state transition
always @(posedge clk) begin
    if (rst | !config_ready) begin
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
//                count_en = 1'b1;
                count_rst = 1'b0;
            end else begin
                next_state = IDLE;
                count_en = 1'b0;
                count_rst = 1'b1;
                payload_count_rst = 1'b1;
            end
        end
        //although there is no SFD field in ethernet frame, we will still use this state to count 8 bytes of preamble haha
        PREAMBLE: begin
            frame_drop_en = 1'b1;
            count_en = 1'b1;
            if(byte_count == 55) next_state = SFD; else next_state = PREAMBLE;
        end
        SFD: begin
            frame_drop_en = 1'b1;
            count_en = 1'b1;
            if(byte_count == 63)
                next_state = DEST_MAC;
            else
                next_state = SFD;
        end
        // we may have to stop the packet receiving at this point if the packet has destination mac address that is not for us. this logic is yet to be added
        DEST_MAC: begin
            dest_mac_en = 1'b1;
            count_en = 1'b1;
            if(byte_count == 111)
                next_state = SRC_MAC;
            else
                next_state = DEST_MAC;
        end
        SRC_MAC: begin
            src_mac_en = 1'b1;
            count_en = 1'b1;
            if(byte_count == 159) 
                next_state = TYPE;
            else
                next_state = SRC_MAC;
        end
        TYPE: begin
            type_len_en = 1'b1;
            count_en = 1'b1;
            if(byte_count == 161) 
                next_state = DATA; 
            else 
                next_state = TYPE;
        end
        DATA: begin
            payload_count_en = 1'b1;
            
            if(!rx_dv) begin
                next_state = IDLE;
                payload_count_en = 1'b0;
                data_en = 1'b0;
                fcs_en = 1'b1;
            end else begin
                data_en = 1'b1;
                next_state = DATA;
            end
        end
    endcase
end

//buffer write logic 
always @(posedge clk) begin
    if(rst) begin
        byte_drop_reg <= 8'b0;
        payload_temp_reg <= 32'b0;
        dest_mac_reg <= 8'b0;
        src_mac_reg <= 8'b0;
        frame_type_reg <= 8'b0;
    end else begin
        case({frame_drop_en, dest_mac_en, src_mac_en, type_len_en, data_en, fcs_en})
            6'b100000: byte_drop_reg <= rx_data;
            6'b010000: dest_mac_reg <= (dest_mac_reg << BYTE_SHIFT) | (rx_data);
            6'b001000: src_mac_reg <= (src_mac_reg << BYTE_SHIFT) | (rx_data);
            6'b000100: frame_type_reg <= (frame_type_reg << BYTE_SHIFT) | rx_data;
            6'b000010: begin
                payload[payload_count] <= rx_data;
                payload_temp_reg <= (payload_temp_reg << BYTE_SHIFT) | rx_data; //shift in new byte
            end
            6'b000001: begin
                crc_reg <= payload_temp_reg;
                payload_length_reg <= payload_count;    //store payload count when crc is stored. this reduces no. of control signals
            end
            default : begin
                byte_drop_reg <= byte_drop_reg;
                dest_mac_reg <= dest_mac_reg;
                src_mac_reg <= src_mac_reg;
                frame_type_reg <= frame_type_reg;
                payload_temp_reg <= payload_temp_reg;
            end
        endcase
    end
end

//byte counter
always @(posedge clk) begin
    if(rst) begin
        byte_count <= 11'b11111111111;
    end else begin
        byte_count <= byte_count + count_en & {11{~count_rst}};
    end
end

//payload counter
always @(posedge clk) begin
    if(rst) begin
        payload_count <= 11'b11111111111;
    end else begin
        payload_count <= payload_count + payload_count_en & {11{~payload_count_rst}};
    end
end

endmodule