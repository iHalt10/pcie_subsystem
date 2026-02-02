
interface pcie_axis_rq_seq_if;
  logic [5:0] num0;
  logic [5:0] num1;
  logic       valid0;
  logic       valid1;

  modport master (
    output num0, num1, valid0, valid1
  );

  modport slave (
    input  num0, num1, valid0, valid1
  );

endinterface: pcie_axis_rq_seq_if
