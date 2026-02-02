
interface pcie_axis_cc_if;

  import pcie_cc_pkg::cc_user_t;

  logic [511:0] data;
  logic [15:0]  keep;
  logic         last;
  cc_user_t     user;
  logic         valid;
  logic [3:0]   ready;

  modport master (
    output data, keep, last, user, valid,
    input  ready
  );

  modport slave (
    input  data, keep, last, user, valid,
    output ready
  );

endinterface: pcie_axis_cc_if


module pcie_axis_cc_if_terminal(
  pcie_axis_cc_if.master m_axis_cc
);
  assign m_axis_cc.data  = '0;
  assign m_axis_cc.keep  = '0;
  assign m_axis_cc.last  = '0;
  assign m_axis_cc.user  = '0;
  assign m_axis_cc.valid = '0;
endmodule: pcie_axis_cc_if_terminal
