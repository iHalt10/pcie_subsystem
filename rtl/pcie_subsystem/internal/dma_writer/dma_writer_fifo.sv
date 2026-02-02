`timescale 1ns / 1ps

module dma_writer_fifo (
  dma_writer_fifo_if.controller access_bus,
  input aclk,
  input areset
);

  reg [63:0][31:0] mem;
  reg [5:0] head;
  reg [5:0] tail;

  assign access_bus.status_length = (tail >= head) ? (tail - head) : (64 + tail - head);

  generate
    for (genvar i = 0; i < 16; i++) begin
      wire [5:0] index;
      assign index = head + i;
      assign access_bus.read_data[i * 32 +: 32] = mem[index];
    end
  endgenerate

  always_ff @(posedge aclk) begin
    if (areset || access_bus.clear) begin
      mem <= '0;
      head <= '0;
      tail <= '0;
    end else begin
      if (access_bus.write_enable) begin
        for (int i = 0; i < 16; i++) begin
          mem[tail + i] <= access_bus.write_data[i * 32 +: 32];
        end
        tail <= tail + $countones(access_bus.write_keep);
      end

      if (access_bus.read_enable) begin
        head <= head + access_bus.read_index + 1;
      end

    end
  end

endmodule: dma_writer_fifo
