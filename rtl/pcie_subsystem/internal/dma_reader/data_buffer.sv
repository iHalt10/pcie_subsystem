`timescale 1ns / 1ps

module data_buffer #(
  parameter DATA_SIZE = 1024,
  parameter DEPTH = DATA_SIZE / 4,
  parameter DATA_WIDTH = DATA_SIZE * 8,
  parameter INDEX_WIDTH = $clog2(DATA_SIZE / 128)
) (
  data_buffer_if.controller access_bus,
  input aclk,
  input areset
);

  wire [255:0] keep;
  wire [8191:0] mask;
  wire [8191:0] masked_payload;

  assign keep = calculate_keep(access_bus.dword_count);
  assign masked_payload = access_bus.payload & mask;

  generate
    for (genvar i = 0; i < 256; i++) begin
      assign mask[i*32 +: 32] = {32{keep[i]}};
    end
  endgenerate

  always_ff @(posedge aclk) begin
    if (areset || access_bus.clear) begin
      access_bus.data <= '0;
      access_bus.keep <= '0;
    end else begin
      if (access_bus.enable) begin
        case (access_bus.data_chunk_size)
          2'b00: begin
            access_bus.data[access_bus.index * 1024 +: 1024] <= masked_payload[1023:0];
            access_bus.keep[access_bus.index * 32 +: 32]     <= keep[31:0];
          end
          2'b01: begin
            access_bus.data[access_bus.index * 2048 +: 2048] <= masked_payload[2047:0];
            access_bus.keep[access_bus.index * 64 +: 64]     <= keep[63:0];
          end
          2'b10: begin
            access_bus.data[access_bus.index * 4096 +: 4096] <= masked_payload[4095:0];
            access_bus.keep[access_bus.index * 128 +: 128]   <= keep[127:0];
          end
          2'b11: begin
            access_bus.data[access_bus.index * 8192 +: 8192] <= masked_payload[8191:0];
            access_bus.keep[access_bus.index * 256 +: 256]   <= keep[255:0];
          end
        endcase
      end
    end
  end

  function automatic logic [255:0] calculate_keep(
    input logic [10:0] dword_count
  );
    logic [256:0] keep = (257'h1 << dword_count[8:0]) - 257'h1;
    return keep[255:0];
  endfunction

endmodule: data_buffer
