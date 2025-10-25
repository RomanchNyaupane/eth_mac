//upper nibble at negative edge, lower nibble at positive edge
module phy_tx(
    input wire clk,
    input wire rst,
    
    input wire config_ready, //declared for testbench purpose. this signal is generated in mdio module

    input wire [7:0] mac_txd,
    input wire phy_tx_ctl,

    output reg [3:0] phy_txd,
    output reg phy_tx_dv
);

// wire config_ready;  //indicates completion of mdio and phy configuration
// mdio mdio_inst(
//     mdio_ready(config_ready)
// );

reg [7:0] mac_tx_data;
reg mac_tx_valid;
reg mac_tx_error;

always @(posedge clk) begin
    if(config_ready & phy_tx_ctl) begin
        phy_txd <= mac_txd[3:0];
        phy_tx_dv <= 1;;
    end else begin
        phy_tx_dv <= 0;
        phy_txd <= phy_txd;
    end
end

always @(negedge clk) begin
    if(config_ready & phy_tx_ctl) begin
        phy_txd <= mac_txd[7:4];
        phy_tx_dv <= 1;
    end else begin
        phy_tx_dv <= 0;
        phy_txd <= phy_txd;
    end
end
endmodule