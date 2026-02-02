`timescale 1ns/1ps

module pcie4c_wrapper (
  input  [15:0] pcie_rxn,
  input  [15:0] pcie_rxp,
  output [15:0] pcie_txn,
  output [15:0] pcie_txp,
  input         pcie_refclk,
  input         pcie_refclk_gt,
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

  pcie_axis_rq_seq_if    axis_rq_seq   ();
  pcie_axis_rq_tag_if    axis_rq_tag   ();
  pcie_transmit_fc_if    transmit_fc   ();
  pcie_axis_cq_np_req_if axis_cq_np    ();
  pcie_cfg_control_if    cfg_control   ();
  pcie_cfg_fc_if         cfg_fc        ();
  pcie_cfg_interrupt_if  cfg_interrupt ();
  pcie_cfg_msg_rx_if     cfg_msg_rx    ();
  pcie_cfg_msg_tx_if     cfg_msg_tx    ();
  pcie_cfg_pm_if         cfg_pm        ();

  pcie_axis_cq_np_req_if_terminal pcie_axis_cq_np_req_if_terminal_inst (axis_cq_np);
  pcie_cfg_control_if_terminal    pcie_cfg_control_if_terminal_inst    (cfg_control);
  pcie_cfg_fc_if_terminal         pcie_cfg_fc_if_terminal_inst         (cfg_fc);
  pcie_cfg_interrupt_if_terminal  pcie_cfg_interrupt_if_terminal_inst  (cfg_interrupt);
  pcie_cfg_msg_tx_if_terminal     pcie_cfg_msg_tx_if_terminal_inst     (cfg_msg_tx);
  pcie_cfg_pm_if_terminal         pcie_cfg_pm_if_terminal_inst         (cfg_pm);

  pcie4c_uscale_plus_core pcie4c_uscale_plus_core_inst (
    .m_axis_cq_tdata  (m_axis_cq.data),
    .m_axis_cq_tkeep  (m_axis_cq.keep),
    .m_axis_cq_tlast  (m_axis_cq.last),
    .m_axis_cq_tuser  (m_axis_cq.user),
    .m_axis_cq_tvalid (m_axis_cq.valid),
    .m_axis_cq_tready (m_axis_cq.ready),

    .s_axis_cc_tdata  (s_axis_cc.data),
    .s_axis_cc_tkeep  (s_axis_cc.keep),
    .s_axis_cc_tlast  (s_axis_cc.last),
    .s_axis_cc_tuser  (s_axis_cc.user),
    .s_axis_cc_tvalid (s_axis_cc.valid),
    .s_axis_cc_tready (s_axis_cc.ready),

    .s_axis_rq_tdata  (s_axis_rq.data),
    .s_axis_rq_tkeep  (s_axis_rq.keep),
    .s_axis_rq_tlast  (s_axis_rq.last),
    .s_axis_rq_tuser  (s_axis_rq.user),
    .s_axis_rq_tvalid (s_axis_rq.valid),
    .s_axis_rq_tready (s_axis_rq.ready),

    .m_axis_rc_tdata  (m_axis_rc.data),
    .m_axis_rc_tkeep  (m_axis_rc.keep),
    .m_axis_rc_tlast  (m_axis_rc.last),
    .m_axis_rc_tuser  (m_axis_rc.user),
    .m_axis_rc_tvalid (m_axis_rc.valid),
    .m_axis_rc_tready (m_axis_rc.ready),

    .pcie_cq_np_req       (axis_cq_np.credit_increment),
    .pcie_cq_np_req_count (axis_cq_np.credit_count),
    .pcie_rq_seq_num0     (axis_rq_seq.num0),
    .pcie_rq_seq_num1     (axis_rq_seq.num1),
    .pcie_rq_seq_num_vld0 (axis_rq_seq.valid0),
    .pcie_rq_seq_num_vld1 (axis_rq_seq.valid1),
    .pcie_rq_tag0         (axis_rq_tag.tag0),
    .pcie_rq_tag1         (axis_rq_tag.tag1),
    .pcie_rq_tag_av       (axis_rq_tag.available),
    .pcie_rq_tag_vld0     (axis_rq_tag.valid0),
    .pcie_rq_tag_vld1     (axis_rq_tag.valid1),

    .cfg_bus_number                   (cfg_control.bus_number),
    .cfg_config_space_enable          (cfg_control.config_space_enable),
    .cfg_ds_bus_number                (cfg_control.ds_bus_number),
    .cfg_ds_device_number             (cfg_control.ds_device_number),
    .cfg_ds_port_number               (cfg_control.ds_port_number),
    .cfg_dsn                          (cfg_control.dsn),
    .cfg_err_cor_in                   (cfg_control.err_cor_in),
    .cfg_err_uncor_in                 (cfg_control.err_uncor_in),
    .cfg_flr_done                     (cfg_control.flr_done),
    .cfg_flr_in_process               (cfg_control.flr_in_process),
    .cfg_hot_reset_in                 (cfg_control.hot_reset_in),
    .cfg_hot_reset_out                (cfg_control.hot_reset_out),
    .cfg_link_training_enable         (cfg_control.link_training_enable),
    .cfg_power_state_change_ack       (cfg_control.power_state_change_ack),
    .cfg_power_state_change_interrupt (cfg_control.power_state_change_interrupt),
    .cfg_req_pm_transition_l23_ready  (cfg_control.req_pm_transition_l23_ready),
    .cfg_vf_flr_done                  (cfg_control.vf_flr_done),
    .cfg_vf_flr_func_num              (cfg_control.vf_flr_func_num),
    .cfg_vf_flr_in_process            (cfg_control.vf_flr_in_process),

    .cfg_fc_cpld (cfg_fc.cpld),
    .cfg_fc_cplh (cfg_fc.cplh),
    .cfg_fc_npd  (cfg_fc.npd),
    .cfg_fc_nph  (cfg_fc.nph),
    .cfg_fc_pd   (cfg_fc.pd),
    .cfg_fc_ph   (cfg_fc.ph),
    .cfg_fc_sel  (cfg_fc.sel),

    .cfg_interrupt_int     (cfg_interrupt.interrupt),
    .cfg_interrupt_pending (cfg_interrupt.pending),
    .cfg_interrupt_sent    (cfg_interrupt.sent),

    .cfg_mgmt_addr            (cfg_mgmt.address),
    .cfg_mgmt_byte_enable     (cfg_mgmt.byte_enable),
    .cfg_mgmt_function_number (cfg_mgmt.function_number),
    .cfg_mgmt_debug_access    (cfg_mgmt.debug_access),
    .cfg_mgmt_write           (cfg_mgmt.write),
    .cfg_mgmt_write_data      (cfg_mgmt.write_data),
    .cfg_mgmt_read            (cfg_mgmt.read),
    .cfg_mgmt_read_data       (cfg_mgmt.read_data),
    .cfg_mgmt_read_write_done (cfg_mgmt.done),

    .cfg_msg_received      (cfg_msg_rx.received),
    .cfg_msg_received_data (cfg_msg_rx.received_data),
    .cfg_msg_received_type (cfg_msg_rx.received_type),

    .cfg_msg_transmit      (cfg_msg_tx.transmit),
    .cfg_msg_transmit_data (cfg_msg_tx.transmit_data),
    .cfg_msg_transmit_type (cfg_msg_tx.transmit_type),
    .cfg_msg_transmit_done (cfg_msg_tx.transmit_done),

    .cfg_pm_aspm_l1_entry_reject      (cfg_pm.aspm_l1_entry_reject),
    .cfg_pm_aspm_tx_l0s_entry_disable (cfg_pm.aspm_tx_l0s_entry_disable),

    .cfg_current_speed           (cfg_status.cfg_current_speed),
    .cfg_err_cor_out             (cfg_status.cfg_err_cor_out),
    .cfg_err_nonfatal_out        (cfg_status.cfg_err_nonfatal_out),
    .cfg_err_fatal_out           (cfg_status.cfg_err_fatal_out),
    .cfg_function_power_state    (cfg_status.cfg_function_power_state),
    .cfg_function_status         (cfg_status.cfg_function_status),
    .cfg_link_power_state        (cfg_status.cfg_link_power_state),
    .cfg_local_error_out         (cfg_status.cfg_local_error_out),
    .cfg_local_error_valid       (cfg_status.cfg_local_error_valid),
    .cfg_ltssm_state             (cfg_status.cfg_ltssm_state),
    .cfg_max_payload             (cfg_status.cfg_max_payload),
    .cfg_max_read_req            (cfg_status.cfg_max_read_req),
    .cfg_negotiated_width        (cfg_status.cfg_negotiated_width),
    .cfg_obff_enable             (cfg_status.cfg_obff_enable),
    .cfg_phy_link_down           (cfg_status.cfg_phy_link_down),
    .cfg_phy_link_status         (cfg_status.cfg_phy_link_status),
    .cfg_pl_status_change        (cfg_status.cfg_pl_status_change),
    .cfg_rcb_status              (cfg_status.cfg_rcb_status),
    .cfg_rx_pm_state             (cfg_status.cfg_rx_pm_state),
    .cfg_tph_requester_enable    (cfg_status.cfg_tph_requester_enable),
    .cfg_tph_st_mode             (cfg_status.cfg_tph_st_mode),
    .cfg_tx_pm_state             (cfg_status.cfg_tx_pm_state),
    .cfg_vf_power_state          (cfg_status.cfg_vf_power_state),
    .cfg_vf_status               (cfg_status.cfg_vf_status),
    .cfg_vf_tph_requester_enable (cfg_status.cfg_vf_tph_requester_enable),
    .cfg_vf_tph_st_mode          (cfg_status.cfg_vf_tph_st_mode),

    .pcie_tfc_npd_av (transmit_fc.npd_av),
    .pcie_tfc_nph_av (transmit_fc.nph_av),

    .pci_exp_rxn (pcie_rxn),
    .pci_exp_rxp (pcie_rxp),
    .pci_exp_txn (pcie_txn),
    .pci_exp_txp (pcie_txp),

    .sys_clk     (pcie_refclk),
    .sys_clk_gt  (pcie_refclk_gt),
    .sys_reset   (pcie_rstn),
    .user_clk    (aclk_250mhz),
    .user_reset  (areset_250mhz),
    .user_lnk_up (user_lnk_up),
    .phy_rdy_out (phy_ready)
  );


endmodule: pcie4c_wrapper
