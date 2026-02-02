
interface pcie_axis_rq_if;

  import pcie_rq_pkg::rq_user_t;

  logic [511:0] data;
  logic [15:0]  keep;
  logic         last;
  rq_user_t     user;
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

endinterface: pcie_axis_rq_if


module pcie_axis_rq_if_terminal(
  pcie_axis_rq_if.master m_axis_rq
);
  assign m_axis_rq.data  = '0;
  assign m_axis_rq.keep  = '0;
  assign m_axis_rq.last  = '0;
  assign m_axis_rq.user  = '0;
  assign m_axis_rq.valid = '0;
endmodule: pcie_axis_rq_if_terminal
