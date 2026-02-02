
interface pcie_cfg_mgmt_if;
  logic [9:0]  address;
  logic [3:0]  byte_enable;
  logic [7:0]  function_number;
  logic        debug_access;

  logic        write;
  logic [31:0] write_data;

  logic        read;
  logic [31:0] read_data;

  logic        done;

  modport master (
    output address, byte_enable, function_number, debug_access, write, write_data, read,
    input  read_data, done
  );

  modport slave (
    input  address, byte_enable, function_number, debug_access, write, write_data, read,
    output read_data, done
  );

endinterface: pcie_cfg_mgmt_if


module pcie_cfg_mgmt_if_terminal(
  pcie_cfg_mgmt_if.master cfg_mgmt
);
  assign cfg_mgmt.address         = '0;
  assign cfg_mgmt.byte_enable     = '0;
  assign cfg_mgmt.function_number = '0;
  assign cfg_mgmt.debug_access    = '0;
  assign cfg_mgmt.write           = '0;
  assign cfg_mgmt.write_data      = '0;
  assign cfg_mgmt.read            = '0;
endmodule: pcie_cfg_mgmt_if_terminal
