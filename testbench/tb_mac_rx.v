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
    
    // Testbench variables
    reg [7:0] received_data [0:100];
    integer i, j;
    
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
        
        // Fork to run frame transmission and reading concurrently
        fork
            // Send first frame
            send_frame_1();
            
            // Start reading first frame after some delay
            begin
                #500; // Wait for first frame to be partially received
                read_frame_1();
            end
            
            // Send second frame while reading first
            begin
                #800; // Wait a bit before sending second frame
                send_frame_2();
            end
            
            // Read second frame
            begin
                #1300; // Wait for second frame to be received
                read_frame_2();
            end
        join
        
        #100;
        $finish;
    end
    
    // Task to send first frame
    task send_frame_1;
    begin
        $display("Sending Frame 1 at time %0t", $time);
        
        // Preamble + SFD
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
        
        // Data - Frame 1
        send_byte(8'hF1); send_byte(8'h01); send_byte(8'hF1); send_byte(8'h02);
        send_byte(8'hF1); send_byte(8'h03); send_byte(8'hF1); send_byte(8'h04);
        send_byte(8'hF1); send_byte(8'h05); send_byte(8'hF1); send_byte(8'h06);
        
        // FCS for Frame 1
        send_byte(8'h2b); send_byte(8'hb4); send_byte(8'hc3); send_byte(8'hff);
        
        @(posedge phy_rx_clk);
        phy_rx_ctl = 0;
        
        $display("Frame 1 sent at time %0t", $time);
    end
    endtask
    
    // Task to send second frame
    task send_frame_2;
    begin
        $display("Sending Frame 2 at time %0t", $time);
        
        // Preamble + SFD
        phy_rx_ctl = 1;
        send_byte(8'h55); send_byte(8'h55); send_byte(8'h55);
        send_byte(8'h55); send_byte(8'h55); send_byte(8'h55);
        send_byte(8'h55); send_byte(8'hD5);
        
        // MAC addresses
        send_byte(8'hAA); send_byte(8'hBB); send_byte(8'hCC);
        send_byte(8'hDD); send_byte(8'hEE); send_byte(8'hFF);  // Dest
        send_byte(8'h01); send_byte(8'h02); send_byte(8'h03);
        send_byte(8'h04); send_byte(8'h05); send_byte(8'h06);  // Src
        
        // Type
        send_byte(8'h08); send_byte(8'h06); // ARP type
        
        // Data - Frame 2 (different from frame 1)
        send_byte(8'hF2); send_byte(8'h11); send_byte(8'hF2); send_byte(8'h12);
        send_byte(8'hF2); send_byte(8'h13); send_byte(8'hF2); send_byte(8'h14);
        send_byte(8'hF2); send_byte(8'h15); send_byte(8'hF2); send_byte(8'h16);
        send_byte(8'hF2); send_byte(8'h17); send_byte(8'hF2); send_byte(8'h18);
        
        // FCS for Frame 2
        send_byte(8'h87); send_byte(8'h65); send_byte(8'h43); send_byte(8'h21);
        
        @(posedge phy_rx_clk);
        phy_rx_ctl = 0;
        
        $display("Frame 2 sent at time %0t", $time);
    end
    endtask
    
    // Task to read first frame
    task read_frame_1;
    begin
        $display("Reading Frame 1 at time %0t", $time);
        
        // Wait for frame received signal
        wait(frame_received);
        frame_received_ack = 1;
        #20;
        frame_received_ack = 0;
        
        // Read the frame data
        read_en = 1;
        i = 0;
        
        while (!read_complete && i < 100) begin
            @(posedge clk);
            if (read_en) begin
                received_data[i] = mac_rx_data_out;
                $display("Frame 1 Data[%0d] = 0x%h", i, mac_rx_data_out);
                i = i + 1;
            end
        end
        
        read_en = 0;
        $display("Frame 1 reading completed at time %0t", $time);
    end
    endtask
    
    // Task to read second frame
    task read_frame_2;
    begin
        $display("Reading Frame 2 at time %0t", $time);
        
        // Wait for frame received signal
        wait(frame_received);
        frame_received_ack = 1;
        #20;
        frame_received_ack = 0;
        
        // Read the frame data
        read_en = 1;
        j = 0;
        
        while (!read_complete && j < 100) begin
            @(posedge clk);
            if (read_en) begin
                received_data[j] = mac_rx_data_out;
                $display("Frame 2 Data[%0d] = 0x%h", j, mac_rx_data_out);
                j = j + 1;
            end
        end
        
        read_en = 0;
        $display("Frame 2 reading completed at time %0t", $time);
    end
    endtask
    
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
    
    // Monitor to track state changes
    initial begin
        $monitor("Time %0t: State=%b, Frame_Received=%b, Read_Complete=%b", 
                 $time, uut.state, frame_received, read_complete);
    end
    
endmodule