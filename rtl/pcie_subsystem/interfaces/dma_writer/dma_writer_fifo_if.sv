
interface dma_writer_fifo_if;

  logic clear;

  logic         write_enable;
  logic [511:0] write_data;
  logic [15:0]  write_keep;

  logic         read_enable;
  logic [3:0]   read_index;
  logic [511:0] read_data;

  logic [6:0] status_length;

  modport controller (
    input clear,
    input write_enable, write_data, write_keep,
    input read_enable, read_index,
    output read_data,
    output status_length
  );

  modport peripheral (
    output clear,
    output write_enable, write_data, write_keep,
    output read_enable, read_index,
    input read_data,
    input status_length
  );

endinterface: dma_writer_fifo_if
