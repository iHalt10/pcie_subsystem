
interface pcie_cfg_interrupt_if;
  logic [3:0] interrupt;
  logic [3:0] pending;
  logic       sent;

  modport master (
    output interrupt, pending,
    input  sent
  );

  modport slave (
    input  interrupt, pending,
    output sent
  );

endinterface: pcie_cfg_interrupt_if


module pcie_cfg_interrupt_if_terminal(
  pcie_cfg_interrupt_if.master cfg_interrupt
);
  assign cfg_interrupt.interrupt = '0;
  assign cfg_interrupt.pending   = '0;
endmodule: pcie_cfg_interrupt_if_terminal
