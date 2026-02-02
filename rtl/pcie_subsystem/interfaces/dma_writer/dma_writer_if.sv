
interface dma_writer_if #(
  parameter int MAX_DATA_SIZE     = 1024,
  parameter int DWORD_COUNT_WIDTH = $clog2(MAX_DATA_SIZE / 4) + 1
);

  logic ready;
  logic valid;
  logic [63:0]  address;
  logic [511:0] data;
  logic [15:0]  keep;
  logic [DWORD_COUNT_WIDTH-1:0] dword_count;

  logic busy;
  logic error;

  modport controller (
    output ready,
    input valid, address, data, keep, dword_count,
    output busy, error
  );

  modport peripheral (
    input  ready,
    output valid, address, data, keep, dword_count,
    input  busy, error
  );

endinterface: dma_writer_if
