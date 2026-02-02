
interface pcie_cfg_status_if;

  import pcie_pkg::cfg_function_status_t;

  logic [1:0]   cfg_current_speed;
  logic         cfg_err_cor_out;
  logic         cfg_err_nonfatal_out;
  logic         cfg_err_fatal_out;
  logic [11:0]  cfg_function_power_state;
  logic [1:0]   cfg_link_power_state;
  logic [4:0]   cfg_local_error_out;
  logic         cfg_local_error_valid;
  logic [5:0]   cfg_ltssm_state;
  logic [1:0]   cfg_max_payload;
  logic [2:0]   cfg_max_read_req;
  logic [2:0]   cfg_negotiated_width;
  logic [1:0]   cfg_obff_enable;
  logic         cfg_phy_link_down;
  logic [1:0]   cfg_phy_link_status;
  logic         cfg_pl_status_change;
  logic [3:0]   cfg_rcb_status;
  logic [1:0]   cfg_rx_pm_state;
  logic [3:0]   cfg_tph_requester_enable;
  logic [11:0]  cfg_tph_st_mode;
  logic [1:0]   cfg_tx_pm_state;
  logic [755:0] cfg_vf_power_state;
  logic [503:0] cfg_vf_status;
  logic [251:0] cfg_vf_tph_requester_enable;
  logic [755:0] cfg_vf_tph_st_mode;
  cfg_function_status_t cfg_function_status;

  modport master (
    output cfg_current_speed, cfg_err_cor_out, cfg_err_nonfatal_out, cfg_err_fatal_out, cfg_function_power_state,
           cfg_link_power_state, cfg_local_error_out, cfg_local_error_valid, cfg_ltssm_state, cfg_max_payload,
           cfg_max_read_req, cfg_negotiated_width, cfg_obff_enable, cfg_phy_link_down,cfg_phy_link_status,
           cfg_pl_status_change, cfg_rcb_status, cfg_rx_pm_state, cfg_tph_requester_enable, cfg_tph_st_mode,
           cfg_tx_pm_state, cfg_vf_power_state, cfg_vf_status, cfg_vf_tph_requester_enable,cfg_vf_tph_st_mode,
           cfg_function_status
  );

  modport slave (
    input cfg_current_speed, cfg_err_cor_out, cfg_err_nonfatal_out, cfg_err_fatal_out, cfg_function_power_state,
          cfg_link_power_state, cfg_local_error_out, cfg_local_error_valid, cfg_ltssm_state, cfg_max_payload,
          cfg_max_read_req, cfg_negotiated_width, cfg_obff_enable, cfg_phy_link_down,cfg_phy_link_status,
          cfg_pl_status_change, cfg_rcb_status, cfg_rx_pm_state, cfg_tph_requester_enable, cfg_tph_st_mode,
          cfg_tx_pm_state, cfg_vf_power_state, cfg_vf_status, cfg_vf_tph_requester_enable,cfg_vf_tph_st_mode,
          cfg_function_status
  );

endinterface: pcie_cfg_status_if
