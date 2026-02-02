`timescale 1ns/1ps

import configuration_space_pkg::configuration_space_t;
import register_controller_pkg::register_controller_t;

module app_core (
  input configuration_space_t configuration_space,
  input register_controller_t register_request,
  output register_controller_t register_response[2],

  pcie_axis_rq_if.master m_axis_rq[2],
  pcie_axis_rc_if.slave  s_axis_rc,
  pcie_cfg_status_if.slave cfg_status,

  input aclk,
  input areset
);

  localparam NUM_REQUESTS = 1;
  register_controller_t [NUM_REQUESTS-1:0] register_requests;

  dma_register_if dma_address();
  doorbell_register_if doorbell();

  register_router #(
    .NUM_REQUESTS(NUM_REQUESTS),
    .FUNCTION_ID(8'b00000000),
    .BAR_ID(3'b000),
    .BASE_ADDR('{
      0: 64'h0000_0000_0000_0000
    }),
    .HIGH_ADDR('{
      0: 64'h0000_0000_0000_00FF
    })
  ) register_router_inst (
    .request  (register_request),
    .requests (register_requests),
    .outside_response (register_response[1]),
    .base_address ({32'b0, configuration_space.bar[0]}),
    .aclk (aclk),
    .areset (areset)
  );

  app_registers app_registers_inst (
    .request  (register_requests[0]),
    .response (register_response[0]),

    .dma_address (dma_address),
    .doorbell    (doorbell),

    .aclk (aclk),
    .areset (areset)
  );

  app_controller app_controller_inst (
    .m_axis_rq  (m_axis_rq),
    .s_axis_rc  (s_axis_rc),
    .cfg_status (cfg_status),

    .dma_address (dma_address),
    .doorbell    (doorbell),

    .aclk   (aclk),
    .areset (areset)
  );

endmodule: app_core
