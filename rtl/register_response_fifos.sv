`timescale 1ns / 1ps

import register_controller_pkg::register_controller_t;

module register_response_fifos (
  pcie_axis_cc_if.master m_axis_cc[2],
  input register_controller_t response[2],
  input aclk,
  input areset
);

  register_response_fifo #(
    .DEPTH(4)
  ) register_response_fifo_inst_0 (
    .response (response[0]),
    .m_axis_cc (m_axis_cc[0]),

    .error (),

    .aclk   (aclk),
    .areset (areset)
  );

  register_response_fifo #(
    .DEPTH(2)
  ) register_response_fifo_inst_1 (
    .response (response[1]),
    .m_axis_cc (m_axis_cc[1]),

    .error (),

    .aclk   (aclk),
    .areset (areset)
  );

endmodule: register_response_fifos
