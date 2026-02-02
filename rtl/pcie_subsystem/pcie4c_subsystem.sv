`timescale 1ns/1ps

module pcie4c_subsystem (
  input  [15:0] pcie_rxp,
  input  [15:0] pcie_rxn,
  output [15:0] pcie_txp,
  output [15:0] pcie_txn,
  input         pcie_refclk_p,
  input         pcie_refclk_n,
  input         pcie_rstn,

  pcie_axis_cc_if.slave  s_axis_cc,
  pcie_axis_cq_if.master m_axis_cq,
  pcie_axis_rq_if.slave  s_axis_rq,
  pcie_axis_rc_if.master m_axis_rc,

  pcie_cfg_mgmt_if.slave    cfg_mgmt,
  pcie_cfg_status_if.master cfg_status,

  output user_lnk_up,
  output phy_ready,

  output aclk_250mhz,
  output areset_250mhz
);

  wire pcie_rstn_int;
  wire pcie_refclk_gt;
  wire pcie_refclk;
  IBUF pcie_rstn_ibuf_inst (.I(pcie_rstn), .O(pcie_rstn_int));
  IBUFDS_GTE4 pcie_refclk_buf (
    .CEB   (1'b0),
    .I     (pcie_refclk_p),
    .IB    (pcie_refclk_n),
    .O     (pcie_refclk_gt),
    .ODIV2 (pcie_refclk)
  );

  pcie4c_wrapper pcie4c_wrapper_inst (
    .pcie_rxp       (pcie_rxp),
    .pcie_rxn       (pcie_rxn),
    .pcie_txp       (pcie_txp),
    .pcie_txn       (pcie_txn),
    .pcie_refclk    (pcie_refclk),
    .pcie_refclk_gt (pcie_refclk_gt),
    .pcie_rstn      (pcie_rstn_int),

    .s_axis_cc (s_axis_cc),
    .m_axis_cq (m_axis_cq),
    .s_axis_rq (s_axis_rq),
    .m_axis_rc (m_axis_rc),

    .cfg_status (cfg_status),
    .cfg_mgmt   (cfg_mgmt),

    .user_lnk_up (user_lnk_up),
    .phy_ready   (phy_ready),

    .aclk_250mhz   (aclk_250mhz),
    .areset_250mhz (areset_250mhz)
  );

endmodule: pcie4c_subsystem
