`timescale 1ns/1ps

module mac_tx_tb;

// Clock and Reset
reg clk;
reg rst;

// Input signals
reg [7:0] tx_data;
reg init;
reg config_ready;
reg frame_end;

// Output signals
wire tx_fifo_wr_en;
wire tx_fifo_rd_en;
wire [7:0] tx_fifo_wr_data;
wire [7:0] mac_txd;

integer i;

// DUT instantiation (FIFO is now internal to mac_tx)
mac_tx dut (
    .clk(clk),
    .rst(rst),
    .tx_data(tx_data),
    .init(init),
    .config_ready(config_ready),
    .frame_end(frame_end),
    .tx_fifo_wr_en(tx_fifo_wr_en),
    .tx_fifo_rd_en(tx_fifo_rd_en),
    .tx_fifo_wr_data(tx_fifo_wr_data)
    
);

// Clock generation - 125 MHz (8ns period)
initial begin
    clk = 0;
    forever #4 clk = ~clk;
end

// Test stimulus
initial begin
    // Initialize signals
    rst = 1;
    init = 0;
    tx_data = 0;
    config_ready = 1;
    
    // Reset
    #20 rst = 0;
    #20;
    
    $display("=== Starting MAC TX Test ===");
    $display("Time\t\tState\tByte_Cnt\tMAC_TXD\tFIFO_WR\tFIFO_RD");
    
    // Start transmission and provide data in sequence:
    // 1. Destination MAC
    // 2. Frame Type
    // 3. Payload
    
    @(posedge clk) init = 1;
    
    // 1. Send destination MAC (6 bytes): AA:BB:CC:DD:EE:FF
    @(posedge clk) tx_data = 8'hAA;
    @(posedge clk) tx_data = 8'hBB;
    @(posedge clk) tx_data = 8'hCC;
    @(posedge clk) tx_data = 8'hDD;
    @(posedge clk) tx_data = 8'hEE;
    @(posedge clk) tx_data = 8'hFF;
    
    // 2. Send frame type (2 bytes): 0x0800 (IPv4)
    @(posedge clk) tx_data = 8'h08;
    @(posedge clk) tx_data = 8'h00;
    
    // 3. Send payload (10 bytes of test data)
    for (i = 0; i < 100; i = i + 1) begin
        @(posedge clk) tx_data = 8'h30 + i; // ASCII '0' to '9'
    end
    
    @(posedge clk) init = 0; frame_end = 1;
    @(posedge clk) frame_end = 0;
    
    // Wait for transmission to complete
    #3000;
    
    $display("\n=== Test Complete ===");
    $display("Total simulation time: %0t ns", $time);
    $finish;
end

// Monitor outputs
always @(posedge clk) begin
    if (dut.preamble_en || dut.dest_mac_en || dut.src_mac_en || 
        dut.frame_type_en || dut.payload_en || dut.crc_en) begin
        $display("%0t\t%d\t%d\t\t%h\t%b\t%b", 
                 $time, dut.state, dut.byte_counter, mac_txd, 
                 tx_fifo_wr_en, tx_fifo_rd_en);
    end
end

// Optional: Dump waveforms
initial begin
    $dumpfile("mac_tx_tb.vcd");
    $dumpvars(0, mac_tx_tb);
end

endmodule