
interface pcie_axis_rq_tag_if;
  logic [7:0] tag0;
  logic [7:0] tag1;
  logic [3:0] available;
  logic       valid0;
  logic       valid1;

  modport master (
    output tag0, tag1, available, valid0, valid1
  );

  modport slave (
    input  tag0, tag1, available, valid0, valid1
  );

endinterface: pcie_axis_rq_tag_if
