module mac_rx(
    input wire clk,
    input wire rst,
    
    input wire phy_rx_clk,
    input wire phy_rx_ctl,
    input wire config_ready, //declared for testbench purpose. this signal is generated in mdio module
    
    input wire [3:0] phy_rxd,
    
    input wire frame_received_ack,  //ack from master once it knows frame is received
    input wire read_en,     //master asserts read_en as long as data is to be read
    
    output reg frame_received, //let master know frame is received
    output reg [7:0] mac_rx_data_out, 
    output reg read_complete //let master know read is complete
);

// module instantiation
wire [31:0] crc_out;

mac_crc_rx crc_inst(
    .data_input(pipeline_4_stage[31:24]),
    .crc_en(crc_en),
    .crc_init(crc_init),
    .crc_out(crc_out),
    .rst(rst),
    .clk(clk)
);


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
reg [7:0] payload2 [0:1520];

//internal counters/buffer registers
reg [10:0] byte_count; //to count number of bytes received, max 1520 bytes
reg [10:0] payload_count; //to separately payload
reg [10:0] read_count; //to read the received data

reg [7:0] byte_drop_reg;   //to drop bytes like preamble and sfd
reg [47:0] dest_mac_reg;
reg [47:0] dest_mac_reg2;
reg [47:0] src_mac_reg;
reg [47:0] src_mac_reg2;
reg [15:0] frame_type_reg;
reg [15:0] frame_type_reg2;
reg [31:0] payload_temp_reg; //temporarily store 4 bytes of payload by shifting. at end, there will be crc sent in packet in this register
reg [31:0] payload_temp_reg2; //temporarily store 4 bytes of payload by shifting. at end, there will be crc sent in packet in this register
reg [10:0] payload_length_reg;
reg [10:0] payload_length_reg2;
reg [31:0] crc_reg; //received crc
reg [31:0] crc_reg2; //received crc
reg [31:0] crc_calculated;
reg [31:0] crc_calculated2;

reg [31:0] pipeline_4_stage;
reg [31:0] pipeline_4_stage2;

//control signals
reg count_en, count_rst;
reg payload_count_en, payload_count_rst;
reg read_count_en, read_count_rst;
reg frame_drop_en;  //to enable dropping of frames
reg dest_mac_en, src_mac_en, type_len_en, data_en, crc_en;
reg crc_init;
reg crc_mismatch;
reg dest_mac_mismatch;
reg frame_rx;

reg read_mode;
reg fifo_select; //cycle between payload fifos, one will be written while other is being read and vice versaf\

reg [2:0] state, next_state;

//state transition
always @(posedge clk) begin
    if (rst | !config_ready) begin
        state <= IDLE;
        fifo_select <= 0;
    end else begin
        state <= next_state;
        if(state == FCS) fifo_select <= read_mode;
        else fifo_select <= fifo_select;
        
        if(frame_rx) frame_received <= 1'b1;
        else if(frame_received_ack) frame_received <= 1'b0;
        
        pipeline_4_stage <= (pipeline_4_stage << BYTE_SHIFT) | rx_data;
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
    crc_en = 1'b0;
    crc_init = 1'b0;
    crc_mismatch = 1'b0;
    frame_rx = 1'b0;
    read_mode = 1'b0;
    case(state)
        IDLE: begin
            if(rx_dv & !read_mode) begin
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
            if(byte_count == 6) next_state = SFD; else next_state = PREAMBLE;
        end
        SFD: begin
            frame_drop_en = 1'b1;
            count_en = 1'b1;
            if(byte_count == 7)
                next_state = DEST_MAC;
            else
                next_state = SFD;
        end
        // we may have to stop the packet receiving at this point if the packet has destination mac address that is not for us. this logic is yet to be added
        DEST_MAC: begin
//            s //initialize crc calculation at start of dest mac address
            dest_mac_en = 1'b1;
            count_en = 1'b1;
            
            if(byte_count > 11) crc_init = 1'b1;
            else crc_init = 1'b0;
            
            if(byte_count == 13 )
                next_state = SRC_MAC;
            else
                next_state = DEST_MAC;
        end
        SRC_MAC: begin
            crc_init = 1'b1;
            src_mac_en = 1'b1;
            count_en = 1'b1;
            if(byte_count == 19) 
                next_state = TYPE;
            else
                next_state = SRC_MAC;
        end
        TYPE: begin
            crc_init = 1'b1;
            type_len_en = 1'b1;
            count_en = 1'b1;
            if(byte_count == 21) 
                next_state = DATA; 
            else 
                next_state = TYPE;
        end
        DATA: begin
            payload_count_en = 1'b1;
            crc_init = 1'b1;
            if(!rx_dv) begin
                crc_init = 1'b0;
                crc_en = 1'b1; //enable crc for last byte of data
                next_state = FCS;
                payload_count_en = 1'b0;
                data_en = 1'b0;
                crc_en = 1'b1;
            end else begin
                data_en = 1'b1;
                next_state = DATA;
            end
        end
        FCS: begin
            if(crc_reg == crc_calculated) begin
                //crc matched, frame received correctly
                read_mode = 1'b1;
                frame_rx = 1'b1;
                next_state = IDLE;
                count_rst = 1'b1;
                payload_count_rst = 1'b1;
            end else begin
                //crc did not match, frame error
                read_mode = 1'b0;
                crc_mismatch = 1'b1;
                next_state = IDLE;
                count_rst = 1'b1;
                payload_count_rst = 1'b1;
                //error handling to be added
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
        payload_temp_reg <= 32'b0;
        payload_length_reg <= 11'b0;
        crc_reg <= 32'b0;
        crc_calculated <= 32'b0;
        
        payload_temp_reg2 <= 32'b0;
        dest_mac_reg2 <= 8'b0;
        src_mac_reg2 <= 8'b0;
        frame_type_reg2 <= 8'b0;
        payload_temp_reg2 <= 32'b0;
        payload_length_reg2 <= 11'b0;
        crc_reg2 <= 32'b0;
        crc_calculated2 <= 32'b0;
    end else begin
        
        if(!fifo_select) begin
            case({frame_drop_en, dest_mac_en, src_mac_en, type_len_en, data_en, crc_en})
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
                    crc_calculated <= crc_out;
                    payload_length_reg <= payload_count - 4;    //store payload count when crc is stored. this reduces no. of control signals
                end
                default : begin
                    byte_drop_reg <= byte_drop_reg;
                    dest_mac_reg <= dest_mac_reg;
                    src_mac_reg <= src_mac_reg;
                    frame_type_reg <= frame_type_reg;
                    payload_temp_reg <= payload_temp_reg;
                    payload_length_reg <= payload_length_reg;
                    crc_reg <= crc_reg;
                end
            endcase
        end else begin
             case({frame_drop_en, dest_mac_en, src_mac_en, type_len_en, data_en, crc_en})
                6'b100000: byte_drop_reg <= rx_data;
                6'b010000: dest_mac_reg2 <= (dest_mac_reg << BYTE_SHIFT) | (rx_data);
                6'b001000: src_mac_reg2 <= (src_mac_reg << BYTE_SHIFT) | (rx_data);
                6'b000100: frame_type_reg2 <= (frame_type_reg << BYTE_SHIFT) | rx_data;
                6'b000010: begin
                    payload2[payload_count] <= rx_data;
                    payload_temp_reg2 <= (payload_temp_reg2 << BYTE_SHIFT) | rx_data; //shift in new byte
                end
                6'b000001: begin
                    crc_reg2 <= payload_temp_reg2;
                    crc_calculated2 <= crc_out;
                    payload_length_reg2 <= payload_count - 4;    //reduce number of crc
                end
                default : begin
                    byte_drop_reg <= byte_drop_reg;
                    dest_mac_reg2 <= dest_mac_reg2;
                    src_mac_reg2 <= src_mac_reg2;
                    frame_type_reg2 <= frame_type_reg2;
                    payload_temp_reg2 <= payload_temp_reg2;
                    payload_length_reg2 <= payload_length_reg2;
                    crc_reg2 <= crc_reg2;
                end
            endcase
        end
        
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

//read module
//when read_mode is asserted upon receiving of valid frame(crc check), the controller shifts to next fifo. but we need to read from fifo that was previously written. so we should invert fifo_select signal
always @(*) begin
    if(!fifo_select) begin
        if(read_en & (read_count == (payload_length_reg2 + 8))) begin read_complete = 1; read_count_rst = 1; end else begin read_count_rst = 0; read_complete = 0; end
    end else begin
        if(read_en & (read_count == (payload_length_reg + 8))) begin read_complete = 1; read_count_rst = 1; end else begin read_count_rst = 0; read_complete = 0; end
    end
   
end
always @(posedge clk) begin
    if(rst) begin
        read_count <= 11'b0;
    end else begin
        
        if(read_en) begin
            read_count <= (read_count + read_en) & {11{~read_count_rst}};
            
            case(read_count[10:0])
                11'd0: mac_rx_data_out <= !fifo_select? dest_mac_reg2[47:40] : dest_mac_reg[47:40];
                11'd1: mac_rx_data_out <= !fifo_select? dest_mac_reg2[39:32] : dest_mac_reg[39:32];
                11'd2: mac_rx_data_out <= !fifo_select? dest_mac_reg2[31:24] : dest_mac_reg[31:24];
                11'd3: mac_rx_data_out <= !fifo_select? dest_mac_reg2[23:16] : dest_mac_reg[23:16];
                11'd4: mac_rx_data_out <= !fifo_select? dest_mac_reg2[15:08] : dest_mac_reg[15:08];
                11'd5: mac_rx_data_out <= !fifo_select? dest_mac_reg2[07:00] : dest_mac_reg[07:00];
                11'd6: mac_rx_data_out <= !fifo_select? frame_type_reg2[15:08] : frame_type_reg[15:08];
                11'd7: mac_rx_data_out <= !fifo_select? frame_type_reg2[07:00] : frame_type_reg[07:00];
                default: begin
                    if(|read_count[10:3]) begin
                        mac_rx_data_out <= !fifo_select? payload2[read_count - 8] : payload[read_count - 8];
                    end else begin
                        mac_rx_data_out <= mac_rx_data_out;
                    end
                
                end
            endcase
        end
    end
end

endmodule