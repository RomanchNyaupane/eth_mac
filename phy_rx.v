//this module will receive the 4 bits of data from phy during both high and low clock edge and combine them to form a 8-bit data.
//the 8 bit data will be sent to mac_rx module at each clock high

module phy_rx(
input wire clk,
input wire rst,
input wire config_ready,    //indicates completion of mdio and phy configuration

input wire phy_rx_clk,
input wire phy_rx_ctl,

input wire [3:0] phy_rxd,

output reg [7:0] mac_rxd,
output reg mac_rx_dv,
output reg mac_rx_err
);

reg [7:0] mac_rx_data;
reg mac_rx_valid;
reg mac_rx_error;

//since there are two clocks (one clock from phy chip and another mac system clock), we will use a buffer to store rx_data and rx_dv signal
always @(*) begin
    if(phy_rx_clk & phy_rx_ctl) begin mac_rx_valid = 1'b1; mac_rx_error = 1'b0; end
    else if(!phy_rx_clk & !phy_rx_ctl) begin mac_rx_error = 1'b1; mac_rx_valid = 1'b0; end
end
always @(*/*posedge phy_rx_clk | negedge phy_rx_clk*/) begin
    if(config_ready) begin    
        if(phy_rx_ctl) begin
            if (!phy_rx_clk) begin
                mac_rx_data[3:0] <= phy_rxd;
            end else begin
                mac_rx_data[7:4] <= phy_rxd;
            end
        end
        else begin
            mac_rx_data <= mac_rx_data;
        end
    end else begin
        mac_rxd <= 8'b0;
    end
end
always @(posedge clk) begin
if(rst) begin
    mac_rxd <= 8'b0;
    mac_rx_dv <= 1'b0;
    mac_rx_err <= 1'b0;
end else begin
    mac_rxd <= mac_rx_data;
    mac_rx_dv <= mac_rx_valid;
    mac_rx_err <= mac_rx_error;
end
end

endmodule
