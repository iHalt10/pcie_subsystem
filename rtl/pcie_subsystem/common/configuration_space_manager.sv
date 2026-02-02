`timescale 1ns / 1ps

module configuration_space_manager (
  pcie_cfg_mgmt_if.master cfg_mgmt,
  configuration_space_manager_if.controller access_bus,
  input aclk,
  input areset
);

  typedef enum logic [1:0] {
    S_IDLE,
    S_READ_BAR,
    S_READ_END
  } state_t;

  state_t state;
  reg [2:0] bar_index;

  assign cfg_mgmt.write        = '0;
  assign cfg_mgmt.write_data   = '0;
  assign cfg_mgmt.debug_access = '0;

  always_ff @(posedge aclk) begin
    if (areset) begin
      state <= S_IDLE;
      access_bus.done <= '0;
      access_bus.space <= '0;
      cfg_mgmt.read <= '0;
      cfg_mgmt.address <= '0;
      cfg_mgmt.byte_enable <= '0;
      cfg_mgmt.function_number <= '0;
      bar_index <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          if (access_bus.enable) begin
            state <= S_READ_BAR;
            cfg_mgmt.read <= 1'b1;
            cfg_mgmt.address <= 10'd4;
            cfg_mgmt.byte_enable <= 4'b1111;
            cfg_mgmt.function_number <= access_bus.function_number;
            bar_index <= 3'd0;
          end
        end

        S_READ_BAR: begin
          if (cfg_mgmt.done) begin
            access_bus.space.bar[bar_index] <= cfg_mgmt.read_data;
            if (bar_index == 3'd5) begin
              state <= S_READ_END;
              access_bus.done <= 1'b1;
              cfg_mgmt.read <= '0;
              cfg_mgmt.address <= '0;
              cfg_mgmt.byte_enable <= '0;
              cfg_mgmt.function_number <= '0;
              bar_index <= '0;
            end else begin
              cfg_mgmt.address <= bar_index + 10'd1 + 10'd4;
              bar_index <= bar_index + 1;
            end
          end
        end

        S_READ_END: begin
          state <= S_IDLE;
          access_bus.done <= '0;
          access_bus.space <= '0;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule: configuration_space_manager
