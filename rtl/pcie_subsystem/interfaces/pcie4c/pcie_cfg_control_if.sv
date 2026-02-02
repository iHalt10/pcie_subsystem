
interface pcie_cfg_control_if;
  logic [7:0]   bus_number;
  logic         config_space_enable;
  logic [7:0]   ds_bus_number;
  logic [4:0]   ds_device_number;
  logic [7:0]   ds_port_number;
  logic [63:0]  dsn;
  logic         err_cor_in;
  logic         err_uncor_in;
  logic [3:0]   flr_done;
  logic [3:0]   flr_in_process;
  logic         hot_reset_in;
  logic         hot_reset_out;
  logic         link_training_enable;
  logic         power_state_change_ack;
  logic         power_state_change_interrupt;
  logic         req_pm_transition_l23_ready;
  logic [0:0]   vf_flr_done;
  logic [7:0]   vf_flr_func_num;
  logic [251:0] vf_flr_in_process;

  modport master (
    output config_space_enable, ds_bus_number, ds_device_number, ds_port_number, dsn, err_cor_in,
           err_uncor_in, flr_done, hot_reset_in, link_training_enable, power_state_change_ack,
           req_pm_transition_l23_ready, vf_flr_done, vf_flr_func_num,
    input  bus_number, flr_in_process, hot_reset_out, power_state_change_interrupt, vf_flr_in_process
  );

  modport slave (
    input  config_space_enable, ds_bus_number, ds_device_number, ds_port_number, dsn, err_cor_in,
           err_uncor_in, flr_done, hot_reset_in, link_training_enable, power_state_change_ack,
           req_pm_transition_l23_ready, vf_flr_done, vf_flr_func_num,
    output bus_number, flr_in_process, hot_reset_out, power_state_change_interrupt, vf_flr_in_process
  );

endinterface: pcie_cfg_control_if


module pcie_cfg_control_if_terminal(
  pcie_cfg_control_if.master cfg_control
);
  assign cfg_control.config_space_enable         = 1'b1;
  assign cfg_control.ds_bus_number               = '0;
  assign cfg_control.ds_device_number            = '0;
  assign cfg_control.ds_port_number              = '0;
  assign cfg_control.dsn                         = '0;
  assign cfg_control.err_cor_in                  = '0;
  assign cfg_control.err_uncor_in                = '0;
  assign cfg_control.flr_done                    = '0;
  assign cfg_control.hot_reset_in                = '0;
  assign cfg_control.link_training_enable        = 1'b1;
  assign cfg_control.power_state_change_ack      = 1'b1;
  assign cfg_control.req_pm_transition_l23_ready = '0;
  assign cfg_control.vf_flr_done                 = '0;
  assign cfg_control.vf_flr_func_num             = '0;
endmodule: pcie_cfg_control_if_terminal
