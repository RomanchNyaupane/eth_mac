`timescale 1ns/1ps

module tb_mac_rx_simple();
    // Inputs
    reg clk;
    reg rst;
    reg phy_rx_clk;
    reg phy_rx_ctl;
    reg config_ready;
    reg [3:0] phy_rxd;
    reg frame_received_ack;
    reg read_en;
    
    // Outputs
    wire frame_received;
    wire [7:0] mac_rx_data_out;
    wire read_complete;
    
    // Instantiate DUT
    mac_rx uut (
        .clk(clk),
        .rst(rst),
        .phy_rx_clk(phy_rx_clk),
        .phy_rx_ctl(phy_rx_ctl),
        .config_ready(config_ready),
        .phy_rxd(phy_rxd),
        .frame_received_ack(frame_received_ack),
        .read_en(read_en),
        .frame_received(frame_received),
        .mac_rx_data_out(mac_rx_data_out),
        .read_complete(read_complete)
    );
    
initial begin
    forever #5 clk = ~clk; //100MHz
end
initial begin
    #2.5;
    forever #5 phy_rx_clk = ~phy_rx_clk; //100MHz, 90 degree phase shift
end
    
    // Simple test
    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        phy_rx_clk = 0;
        phy_rx_ctl = 0;
        config_ready = 0;
        phy_rxd = 0;
        frame_received_ack = 0;
        read_en = 0;
        
        // Reset
        #100;
        rst = 0;
        config_ready = 1;
        
        // Send simple frame
        #100;
        
        // Preamble + SFD (simplified)
        phy_rx_ctl = 1;
        send_byte(8'h55); send_byte(8'h55); send_byte(8'h55);
        send_byte(8'h55); send_byte(8'h55); send_byte(8'h55);
        send_byte(8'h55); send_byte(8'hD5);
        
        // MAC addresses
        send_byte(8'h11); send_byte(8'h22); send_byte(8'h33);
        send_byte(8'h44); send_byte(8'h55); send_byte(8'h66);  // Dest
        send_byte(8'h77); send_byte(8'h88); send_byte(8'h99);
        send_byte(8'hAA); send_byte(8'hBB); send_byte(8'hCC);  // Src
        
        // Type
        send_byte(8'h08); send_byte(8'h00);
        
        // Data
        send_byte(8'h01); send_byte(8'h02); send_byte(8'h03);
        send_byte(8'h04);
        
        // FCS
        send_byte(8'h74); send_byte(8'h70); send_byte(8'h29); send_byte(8'hfc);
        
        @(posedge phy_rx_clk);
        phy_rx_ctl = 0;
        
        // Wait and read
        #200;
        read_en = 1;
        wait(read_complete);
        #10;
        read_en = 0;
        frame_received_ack = 1;
        #10;
        frame_received_ack = 0;
        
        #100;
        $finish;
    end
    
    task send_byte;
        input [7:0] data;
    begin
        @(posedge phy_rx_clk);
        phy_rxd = data[3:0];
        @(negedge phy_rx_clk);
        phy_rxd = data[7:4];
    end
    endtask
    
    initial begin
        $dumpfile("mac_rx_simple.vcd");
        $dumpvars(0, tb_mac_rx_simple);
    end
    
endmodule