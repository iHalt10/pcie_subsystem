
interface pcie_cfg_msg_rx_if;
  logic       received;
  logic [7:0] received_data;
  logic [4:0] received_type;

  modport master (
    output received, received_data, received_type
  );

  modport slave (
    input received, received_data, received_type
  );

endinterface: pcie_cfg_msg_rx_if
