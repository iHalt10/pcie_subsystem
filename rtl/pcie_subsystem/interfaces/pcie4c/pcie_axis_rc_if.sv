
interface pcie_axis_rc_if;

  import pcie_rc_pkg::rc_user_t;

  logic [511:0] data;
  logic [15:0]  keep;
  logic         last;
  rc_user_t     user;
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

endinterface: pcie_axis_rc_if


module pcie_axis_rc_if_terminal(
  pcie_axis_rc_if.slave s_axis_rc
);
  assign s_axis_rc.ready = '0;
endmodule: pcie_axis_rc_if_terminal


module pcie_axis_rc_if_forever(
  pcie_axis_rc_if.slave s_axis_rc,
  pcie_axis_rc_if.master m_axis_rc
);
  assign m_axis_rc.data = s_axis_rc.data;
  assign m_axis_rc.keep = s_axis_rc.keep;
  assign m_axis_rc.last = s_axis_rc.last;
  assign m_axis_rc.user = s_axis_rc.user;
  assign m_axis_rc.valid = s_axis_rc.valid;
  assign s_axis_rc.ready = 1'b1;
endmodule: pcie_axis_rc_if_forever
