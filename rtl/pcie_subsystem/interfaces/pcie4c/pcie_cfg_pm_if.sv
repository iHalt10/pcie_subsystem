
interface pcie_cfg_pm_if;
  logic aspm_l1_entry_reject;
  logic aspm_tx_l0s_entry_disable;

  modport master (
    output aspm_l1_entry_reject, aspm_tx_l0s_entry_disable
  );

  modport slave (
    input aspm_l1_entry_reject, aspm_tx_l0s_entry_disable
  );

endinterface: pcie_cfg_pm_if


module pcie_cfg_pm_if_terminal(
  pcie_cfg_pm_if.master cfg_pm
);
  assign cfg_pm.aspm_l1_entry_reject      = '0;
  assign cfg_pm.aspm_tx_l0s_entry_disable = '0;
endmodule: pcie_cfg_pm_if_terminal
