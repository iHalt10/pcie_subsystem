
interface pcie_axis_cq_if;

  import pcie_cq_pkg::cq_user_t;

  logic [511:0] data;
  logic [15:0]  keep;
  logic         last;
  cq_user_t     user;
  logic         valid;
  logic         ready;

  modport master (
    output data, keep, last, user, valid,
    input  ready
  );

  modport slave (
    input  data, keep, last, user, valid,
    output ready
  );

endinterface: pcie_axis_cq_if


module pcie_axis_cq_if_terminal(
  pcie_axis_cq_if.slave s_axis_cq
);
  assign s_axis_cq.ready = '0;
endmodule: pcie_axis_cq_if_terminal


module pcie_axis_cq_if_forever(
  pcie_axis_cq_if.slave s_axis_cq,
  pcie_axis_cq_if.master m_axis_cq
);
  assign m_axis_cq.data = s_axis_cq.data;
  assign m_axis_cq.keep = s_axis_cq.keep;
  assign m_axis_cq.last = s_axis_cq.last;
  assign m_axis_cq.user = s_axis_cq.user;
  assign m_axis_cq.valid = s_axis_cq.valid;
  assign s_axis_cq.ready = 1'b1;
endmodule: pcie_axis_cq_if_forever
