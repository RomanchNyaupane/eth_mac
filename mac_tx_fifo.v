module mac_tx_fifo(
    input wire clk,
    input wire rst,

    input wire [7:0] tx_fifo_wr_data,   //tx_data contains destination mac, frame type and payload to be imported to this module
    input wire tx_fifo_wr_en, //to write to tx_fifo
    input wire tx_fifo_rd_en, //to read from tx_fifo

    output reg tx_fifo_full, //output flag to indicate fifo is full
    output reg tx_fifo_empty, //output flag to indicate fifo is empty
    output reg [7:0] tx_fifo_rd_data //output data read from tx_fifo
);

//counters and buffers
reg [6:0] rd_count, wr_count; //pointers to read and write locations
reg [7:0] fifo_mem [0:128];

//assign tx_fifo_full = (wr_count == 127) ? 1'b1 : 1'b0;
//assign tx_fifo_empty = (rd_count == wr_count) ? 1'b1 : 1'b0;

always @(*) begin
    tx_fifo_full = (wr_count == 127) ? 1'b1 : 1'b0;
    tx_fifo_empty = (rd_count == wr_count) ? 1'b1 : 1'b0;
end

//write logic
always @(posedge clk) begin
    if(rst) begin
        tx_fifo_rd_data <= 8'b0;
    end else begin
        if(tx_fifo_wr_en) begin
            fifo_mem[wr_count] <= tx_fifo_wr_data;
        end else begin
            fifo_mem[wr_count] <= fifo_mem[wr_count]; //hold last value if not writing
        end
    end
end

//read logic
always @(posedge clk) begin
    if(rst) begin
        rd_count <= 7'b0;
        wr_count <= 7'b0;
        //tx_fifo_rd_data <= fifo_mem[0];
    end else begin
        if(tx_fifo_rd_en | tx_fifo_wr_en) begin
            tx_fifo_rd_data <= fifo_mem[rd_count];
        end
    end
end

//the fifo is a sliding window. we need to move the data in the fifo to the front when we read data from it. this is done by maintaining read and write counters

//counters
always @(posedge clk) begin
    if(rst) begin
        rd_count <= 7'b0;
        wr_count <= 7'b0;
    end else begin
        rd_count <= rd_count + tx_fifo_rd_en;
        wr_count <= wr_count + tx_fifo_wr_en;
    end
end

endmodule