
interface pcie_axis_cq_np_req_if;

  logic [1:0] credit_increment;
  logic [5:0] credit_count;

  modport requester (
    output credit_increment,
    input  credit_count
  );

  modport core (
    input  credit_increment,
    output credit_count
  );

endinterface : pcie_axis_cq_np_req_if


module pcie_axis_cq_np_req_if_terminal(
  pcie_axis_cq_np_req_if.requester r_axis_cq_np
);
  assign r_axis_cq_np.credit_increment = 1'b1;
endmodule: pcie_axis_cq_np_req_if_terminal
