
interface dma_register_if;
  logic [63:0] data;
  modport controller (output data);
  modport peripheral (input data);
endinterface: dma_register_if

interface doorbell_register_if;
  logic [31:0] data;
  logic update;
  logic update_done;
  modport controller (output data, update, input update_done);
  modport peripheral (input data, update, output update_done);
endinterface: doorbell_register_if
