`timescale 1ns/1ps

import configuration_space_pkg::configuration_space_t;
import register_controller_pkg::register_controller_t;

module fpga_au50 (
  output hbm_cattrip,

  input  [15:0] pcie_rxp,
  input  [15:0] pcie_rxn,
  output [15:0] pcie_txp,
  output [15:0] pcie_txn,

  input pcie_refclk_p,
  input pcie_refclk_n,
  input pcie_rstn
);

  OBUF hbm_cattrip_obuf_inst (.I(1'b0), .O(hbm_cattrip));

  wire aclk_250mhz;
  wire areset_250mhz;

  pcie_axis_cc_if s_axis_cc [2] ();
  pcie_axis_cc_if m_axis_cc ();
  pcie_axis_cq_if s_axis_cq ();
  pcie_axis_cq_if m_axis_cq ();

  pcie_axis_rq_if s_axis_rq [2] ();
  pcie_axis_rq_if m_axis_rq ();
  pcie_axis_rc_if axis_rc ();

  pcie_cfg_mgmt_if   cfg_mgmt ();
  pcie_cfg_status_if cfg_status ();

  register_controller_t register_request;
  register_controller_t register_response[2];
  configuration_space_t configuration_space;

  pcie4c_subsystem pcie4c_subsystem_inst (
    .pcie_rxp       (pcie_rxp),
    .pcie_rxn       (pcie_rxn),
    .pcie_txp       (pcie_txp),
    .pcie_txn       (pcie_txn),
    .pcie_refclk_p  (pcie_refclk_p),
    .pcie_refclk_n  (pcie_refclk_n),
    .pcie_rstn      (pcie_rstn),

    .s_axis_cc (m_axis_cc),
    .m_axis_cq (m_axis_cq),
    .s_axis_rq (m_axis_rq),
    .m_axis_rc (axis_rc),

    .cfg_mgmt   (cfg_mgmt),
    .cfg_status (cfg_status),

    .user_lnk_up (),
    .phy_ready   (),

    .aclk_250mhz   (aclk_250mhz),
    .areset_250mhz (areset_250mhz)
  );

  configuration_space_runner configuration_space_runner_inst (
    .cfg_mgmt (cfg_mgmt),
    .configuration_space (configuration_space),
    .aclk (aclk_250mhz),
    .areset (areset_250mhz)
  );

  pcie_axis_cq_if_forever pcie_axis_cq_if_forever_inst (
    .s_axis_cq (m_axis_cq),
    .m_axis_cq (s_axis_cq)
  );

  register_requester register_requester_inst (
    .s_axis_cq (s_axis_cq),
    .request (register_request),
    .aclk   (aclk_250mhz),
    .areset (areset_250mhz)
  );

  cc_switcher #(
    .NUM_SLAVES(2)
  ) cc_switcher_inst (
    .s_axis_cc (s_axis_cc),
    .m_axis_cc (m_axis_cc),
    .aclk (aclk_250mhz),
    .areset (areset_250mhz)
  );

  register_response_fifos register_response_fifos_inst (
    .m_axis_cc (s_axis_cc),
    .response (register_response),
    .aclk (aclk_250mhz),
    .areset (areset_250mhz)
  );

  rq_switcher #(
    .NUM_SLAVES(2)
  ) rq_switcher_inst (
    .s_axis_rq (s_axis_rq),
    .m_axis_rq (m_axis_rq),
    .aclk (aclk_250mhz),
    .areset (areset_250mhz)
  );

  app_core app_core_inst (
    .configuration_space (configuration_space),
    .register_request    (register_request),
    .register_response   (register_response),

    .m_axis_rq  (s_axis_rq),
    .s_axis_rc  (axis_rc),
    .cfg_status (cfg_status),

    .aclk   (aclk_250mhz),
    .areset (areset_250mhz)
  );

endmodule: fpga_au50
