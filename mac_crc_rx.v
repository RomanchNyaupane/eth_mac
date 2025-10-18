//-----------------------------------------------------------------------------
// CRC module for data[7:0] ,   crc[31:0]=1+x^1+x^2+x^4+x^5+x^7+x^8+x^10+x^11+x^12+x^16+x^22+x^23+x^26+x^32;
//-----------------------------------------------------------------------------

module mac_crc_rx(
    input [7:0] data_input,
    input crc_en,   //enable reading of crc value
    input crc_init, //start crc calculation
    output [31:0] crc_out,
    input rst,
    input clk
);
    wire [7:0] data_in;
    assign data_in[0] = data_input[7]; //reversing the bit order of the input values of data to reflect the input for crc calculation 
    assign data_in[1] = data_input[6];
    assign data_in[2] = data_input[5];
    assign data_in[3] = data_input[4];
    assign data_in[4] = data_input[3];
    assign data_in[5] = data_input[2];
    assign data_in[6] = data_input[1];
    assign data_in[7] = data_input[0];
    
    reg [31:0] lfsr_q,lfsr_c;

    reg [31:0] data_out;
    assign crc_out = crc_en? ~data_out : 32'b0;
    
    integer i;
    always @(*) begin //reversing the bit order of the output values of crc to reflect the output for crc calculation
        data_out[00] = lfsr_q[31];
        data_out[01] = lfsr_q[30];
        data_out[02] = lfsr_q[29];
        data_out[03] = lfsr_q[28];
        data_out[04] = lfsr_q[27];
        data_out[05] = lfsr_q[26];
        data_out[06] = lfsr_q[25];
        data_out[07] = lfsr_q[24];
        data_out[08] = lfsr_q[23];
        data_out[09] = lfsr_q[22];
        data_out[10] = lfsr_q[21];
        data_out[11] = lfsr_q[20];
        data_out[12] = lfsr_q[19];
        data_out[13] = lfsr_q[18];
        data_out[14] = lfsr_q[17];
        data_out[15] = lfsr_q[16];
        data_out[16] = lfsr_q[15];
        data_out[17] = lfsr_q[14];
        data_out[18] = lfsr_q[13];
        data_out[19] = lfsr_q[12];
        data_out[20] = lfsr_q[11];
        data_out[21] = lfsr_q[10];
        data_out[22] = lfsr_q[09];
        data_out[23] = lfsr_q[08];
        data_out[24] = lfsr_q[07];
        data_out[25] = lfsr_q[06];
        data_out[26] = lfsr_q[05];
        data_out[27] = lfsr_q[04];
        data_out[28] = lfsr_q[03];
        data_out[29] = lfsr_q[02];
        data_out[30] = lfsr_q[01];
        data_out[31] = lfsr_q[00];
    end


always @(*) begin
    if(crc_init) begin
        lfsr_c[00] = lfsr_q[24] ^ lfsr_q[30] ^ data_in[0] ^ data_in[6];
        lfsr_c[01] = lfsr_q[24] ^ lfsr_q[25] ^ lfsr_q[30] ^ lfsr_q[31] ^ data_in[0] ^ data_in[1] ^ data_in[6] ^ data_in[7];
        lfsr_c[02] = lfsr_q[24] ^ lfsr_q[25] ^ lfsr_q[26] ^ lfsr_q[30] ^ lfsr_q[31] ^ data_in[0] ^ data_in[1] ^ data_in[2] ^ data_in[6] ^ data_in[7];
        lfsr_c[03] = lfsr_q[25] ^ lfsr_q[26] ^ lfsr_q[27] ^ lfsr_q[31] ^ data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[7];
        lfsr_c[04] = lfsr_q[24] ^ lfsr_q[26] ^ lfsr_q[27] ^ lfsr_q[28] ^ lfsr_q[30] ^ data_in[0] ^ data_in[2] ^ data_in[3] ^ data_in[4] ^ data_in[6];
        lfsr_c[05] = lfsr_q[24] ^ lfsr_q[25] ^ lfsr_q[27] ^ lfsr_q[28] ^ lfsr_q[29] ^ lfsr_q[30] ^ lfsr_q[31] ^ data_in[0] ^ data_in[1] ^ data_in[3] ^ data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7];
        lfsr_c[06] = lfsr_q[25] ^ lfsr_q[26] ^ lfsr_q[28] ^ lfsr_q[29] ^ lfsr_q[30] ^ lfsr_q[31] ^ data_in[1] ^ data_in[2] ^ data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7];
        lfsr_c[07] = lfsr_q[24] ^ lfsr_q[26] ^ lfsr_q[27] ^ lfsr_q[29] ^ lfsr_q[31] ^ data_in[0] ^ data_in[2] ^ data_in[3] ^ data_in[5] ^ data_in[7];
        lfsr_c[08] = lfsr_q[00] ^ lfsr_q[24] ^ lfsr_q[25] ^ lfsr_q[27] ^ lfsr_q[28] ^ data_in[0] ^ data_in[1] ^ data_in[3] ^ data_in[4];
        lfsr_c[09] = lfsr_q[01] ^ lfsr_q[25] ^ lfsr_q[26] ^ lfsr_q[28] ^ lfsr_q[29] ^ data_in[1] ^ data_in[2] ^ data_in[4] ^ data_in[5];
        lfsr_c[10] = lfsr_q[02] ^ lfsr_q[24] ^ lfsr_q[26] ^ lfsr_q[27] ^ lfsr_q[29] ^ data_in[0] ^ data_in[2] ^ data_in[3] ^ data_in[5];
        lfsr_c[11] = lfsr_q[03] ^ lfsr_q[24] ^ lfsr_q[25] ^ lfsr_q[27] ^ lfsr_q[28] ^ data_in[0] ^ data_in[1] ^ data_in[3] ^ data_in[4];
        lfsr_c[12] = lfsr_q[04] ^ lfsr_q[24] ^ lfsr_q[25] ^ lfsr_q[26] ^ lfsr_q[28] ^ lfsr_q[29] ^ lfsr_q[30] ^ data_in[0] ^ data_in[1] ^ data_in[2] ^ data_in[4] ^ data_in[5] ^ data_in[6];
        lfsr_c[13] = lfsr_q[05] ^ lfsr_q[25] ^ lfsr_q[26] ^ lfsr_q[27] ^ lfsr_q[29] ^ lfsr_q[30] ^ lfsr_q[31] ^ data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[5] ^ data_in[6] ^ data_in[7];
        lfsr_c[14] = lfsr_q[06] ^ lfsr_q[26] ^ lfsr_q[27] ^ lfsr_q[28] ^ lfsr_q[30] ^ lfsr_q[31] ^ data_in[2] ^ data_in[3] ^ data_in[4] ^ data_in[6] ^ data_in[7];
        lfsr_c[15] = lfsr_q[07] ^ lfsr_q[27] ^ lfsr_q[28] ^ lfsr_q[29] ^ lfsr_q[31] ^ data_in[3] ^ data_in[4] ^ data_in[5] ^ data_in[7];
        lfsr_c[16] = lfsr_q[08] ^ lfsr_q[24] ^ lfsr_q[28] ^ lfsr_q[29] ^ data_in[0] ^ data_in[4] ^ data_in[5];
        lfsr_c[17] = lfsr_q[09] ^ lfsr_q[25] ^ lfsr_q[29] ^ lfsr_q[30] ^ data_in[1] ^ data_in[5] ^ data_in[6];
        lfsr_c[18] = lfsr_q[10] ^ lfsr_q[26] ^ lfsr_q[30] ^ lfsr_q[31] ^ data_in[2] ^ data_in[6] ^ data_in[7];
        lfsr_c[19] = lfsr_q[11] ^ lfsr_q[27] ^ lfsr_q[31] ^ data_in[3] ^ data_in[7];
        lfsr_c[20] = lfsr_q[12] ^ lfsr_q[28] ^ data_in[4];
        lfsr_c[21] = lfsr_q[13] ^ lfsr_q[29] ^ data_in[5];
        lfsr_c[22] = lfsr_q[14] ^ lfsr_q[24] ^ data_in[0];
        lfsr_c[23] = lfsr_q[15] ^ lfsr_q[24] ^ lfsr_q[25] ^ lfsr_q[30] ^ data_in[0] ^ data_in[1] ^ data_in[6];
        lfsr_c[24] = lfsr_q[16] ^ lfsr_q[25] ^ lfsr_q[26] ^ lfsr_q[31] ^ data_in[1] ^ data_in[2] ^ data_in[7];
        lfsr_c[25] = lfsr_q[17] ^ lfsr_q[26] ^ lfsr_q[27] ^ data_in[2] ^ data_in[3];
        lfsr_c[26] = lfsr_q[18] ^ lfsr_q[24] ^ lfsr_q[27] ^ lfsr_q[28] ^ lfsr_q[30] ^ data_in[0] ^ data_in[3] ^ data_in[4] ^ data_in[6];
        lfsr_c[27] = lfsr_q[19] ^ lfsr_q[25] ^ lfsr_q[28] ^ lfsr_q[29] ^ lfsr_q[31] ^ data_in[1] ^ data_in[4] ^ data_in[5] ^ data_in[7];
        lfsr_c[28] = lfsr_q[20] ^ lfsr_q[26] ^ lfsr_q[29] ^ lfsr_q[30] ^ data_in[2] ^ data_in[5] ^ data_in[6];
        lfsr_c[29] = lfsr_q[21] ^ lfsr_q[27] ^ lfsr_q[30] ^ lfsr_q[31] ^ data_in[3] ^ data_in[6] ^ data_in[7];
        lfsr_c[30] = lfsr_q[22] ^ lfsr_q[28] ^ lfsr_q[31] ^ data_in[4] ^ data_in[7];
        lfsr_c[31] = lfsr_q[23] ^ lfsr_q[29] ^ data_in[5];
    end
end

always @(posedge clk) begin
    if(rst) begin
        lfsr_q <= {32{1'b1}};
    end
    else begin
        lfsr_q <= crc_init ? lfsr_c : lfsr_q;
    end
end
endmodule