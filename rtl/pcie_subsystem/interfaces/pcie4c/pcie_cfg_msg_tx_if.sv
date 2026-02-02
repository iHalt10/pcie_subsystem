
interface pcie_cfg_msg_tx_if;
  logic        transmit;
  logic [31:0] transmit_data;
  logic [2:0]  transmit_type;
  logic        transmit_done;

  modport master (
    output transmit, transmit_data, transmit_type,
    input  transmit_done
  );

  modport slave (
    input  transmit, transmit_data, transmit_type,
    output transmit_done
  );

endinterface: pcie_cfg_msg_tx_if


module pcie_cfg_msg_tx_if_terminal(
  pcie_cfg_msg_tx_if.master cfg_msg_tx
);
  assign cfg_msg_tx.transmit      = '0;
  assign cfg_msg_tx.transmit_data = '0;
  assign cfg_msg_tx.transmit_type = '0;
endmodule: pcie_cfg_msg_tx_if_terminal
