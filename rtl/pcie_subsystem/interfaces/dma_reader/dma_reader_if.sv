
interface dma_reader_if #(
  parameter int MAX_DATA_SIZE     = 1024,
  parameter int MAX_DWORD_COUNT   = MAX_DATA_SIZE / 4,
  parameter int DWORD_COUNT_WIDTH = $clog2(MAX_DWORD_COUNT) + 1,
  parameter int DATA_WIDTH        = MAX_DATA_SIZE * 8
);

  logic enable;
  logic [63:0] address;
  logic [DWORD_COUNT_WIDTH-1:0] dword_count;

  logic busy;
  logic done;
  logic error;
  logic [DATA_WIDTH-1:0] data;
  logic [MAX_DWORD_COUNT-1:0] keep;


  modport controller (
    input  enable, address, dword_count,
    output busy, done, error, data, keep
  );

  modport peripheral (
    output enable, address, dword_count,
    input  busy, done, error, data, keep
  );

endinterface: dma_reader_if
