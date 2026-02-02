
interface data_buffer_if #(
  parameter DATA_SIZE = 1024,
  parameter DEPTH = DATA_SIZE / 4,
  parameter DATA_WIDTH = DATA_SIZE * 8,
  parameter INDEX_WIDTH = $clog2(DATA_SIZE / 128)
);

  logic clear;

  logic                   enable;
  logic [INDEX_WIDTH-1:0] index;
  logic [8191:0]          payload;
  logic [10:0]            dword_count;

  logic [1:0]             data_chunk_size;

  logic [DATA_WIDTH-1:0]  data;
  logic [DEPTH-1:0]       keep;

  modport controller (
    input  clear,
    input  enable, index, payload, dword_count,
    input  data_chunk_size,
    output data, keep
  );

  modport peripheral (
    output clear,
    output enable, index, payload, dword_count,
    output data_chunk_size,
    input  data, keep
  );

endinterface: data_buffer_if
