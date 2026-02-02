`timescale 1ns/1ps

import configuration_space_pkg::configuration_space_t;

module configuration_space_runner (
  pcie_cfg_mgmt_if.master cfg_mgmt,
  output configuration_space_t configuration_space,
  input aclk,
  input areset
);

  configuration_space_manager_if access_bus ();
  configuration_space_manager manager_inst (
    .cfg_mgmt (cfg_mgmt),
    .access_bus (access_bus),
    .aclk (aclk),
    .areset (areset)
  );

  assign access_bus.enable = 1'b1;
  assign access_bus.function_number = 8'b00000000;

  always_ff @(posedge aclk) begin
    if (areset) begin
      configuration_space <= '0;
    end else begin
      if (access_bus.done) begin
        configuration_space <= access_bus.space;
      end
    end
  end

endmodule: configuration_space_runner
