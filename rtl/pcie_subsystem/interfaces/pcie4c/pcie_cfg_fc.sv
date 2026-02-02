
interface pcie_cfg_fc_if;
  logic [11:0] cpld;
  logic [7:0]  cplh;
  logic [11:0] npd;
  logic [7:0]  nph;
  logic [11:0] pd;
  logic [7:0]  ph;
  logic [2:0]  sel;

  modport master (
    output cpld, cplh, npd, nph, pd, ph,
    input  sel
  );

  modport slave (
    input  cpld, cplh, npd, nph, pd, ph,
    output sel
  );

endinterface: pcie_cfg_fc_if


module pcie_cfg_fc_if_terminal(
  pcie_cfg_fc_if.slave cfg_fc
);
  assign cfg_fc.sel = '0;
endmodule: pcie_cfg_fc_if_terminal
