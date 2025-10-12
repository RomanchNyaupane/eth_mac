module tb_mac_rx();
    reg mac_clk;
    reg phy_rx_clk;
    reg rst;
    reg phy_rx_ctl;
    reg [3:0] phy_rxd;
    reg config_ready;
    
    wire [3:0] phy_txd;
    wire phy_tx_en;


mac_rx mac_rx_inst(
    .clk(mac_clk),
    .phy_rx_clk(phy_rx_clk),
    .rst(rst),
    .phy_rx_ctl(phy_rx_ctl),
    .config_ready(config_ready),
    .phy_rxd(phy_rxd)
);



//phy chip behavioral description

//clock
initial begin
    forever #5 mac_clk = ~mac_clk; //100MHz
end
initial begin
    #2.5;
    forever #5 phy_rx_clk = ~phy_rx_clk; //100MHz, 90 degree phase shift
end

reg [3:0] frame_data[0:1000];
reg [13:0] data_index;
integer i;
initial begin
    for(i=0; i<128; i=i+1) begin
        frame_data[i] = 4'hf;
    end
    for(i=128; i<256; i=i+1) begin
        frame_data[i] = 4'he;
    end
    for(i=256; i<384; i=i+1) begin
        frame_data[i] = 4'hd;
    end
    for(i=384; i<512; i=i+1) begin
        frame_data[i] = 4'hc;
    end
    for(i=512; i<640; i=i+1) begin
        frame_data[i] = 4'hb;
    end
    for(i=640; i<768; i=i+1) begin
        frame_data[i] = 4'ha;
    end
    for(i=768; i<896; i=i+1) begin
        frame_data[i] = 4'h9;
    end
end

initial begin
    mac_clk = 1'b0;
    phy_rx_clk = 1'b0;
    rst = 1'b1;
    phy_rx_ctl = 1'b0;
    phy_rxd = 4'b0;
    data_index = 14'b0;
    config_ready = 1'b1;
    #20;
    config_ready = 1'b1;
    rst = 1'b0;
    //send a frame
    //preamble
    for(i=0; i<32; i=i+1) begin
        @(posedge phy_rx_clk);
        phy_rx_ctl = 1'b1;
        phy_rxd = frame_data[i];
    end
    //data
    for(i=0; i<512; i=i+1) begin
        @(posedge phy_rx_clk);
        phy_rx_ctl = 1'b1;
        phy_rxd = frame_data[i];
    end
    //end of frame
    @(posedge phy_rx_clk);
    phy_rx_ctl = 1'b0;
    phy_rxd = 4'b0;
end

endmodule