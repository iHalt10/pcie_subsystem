`timescale 1ns / 1ps

module rc_counter #(
  parameter int COUNT_WIDTH = 6
) (
  rc_counter_if.controller access_bus,
  input aclk,
  input areset
);

  typedef enum logic [1:0] {
    S_IDLE,
    S_COUNT,
    S_DONE
  } state_t;

  state_t state;
  wire is_max;
  reg [COUNT_WIDTH-1:0] count;

  assign is_max = (state != S_IDLE) ? count == access_bus.max : 1'b0;
  assign access_bus.is_max = is_max;

  always_ff @(posedge aclk) begin
    if (areset) begin
      state <= S_IDLE;
      count <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          if (access_bus.enable) begin
            state <= S_COUNT;
          end
        end

        S_COUNT: begin
          if (is_max) begin
            state <= S_DONE;
          end else begin
            if (access_bus.up) begin
              count <= count + 1;
            end
          end
        end

        S_DONE: begin
          state <= S_IDLE;
          count <= '0;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule: rc_counter
