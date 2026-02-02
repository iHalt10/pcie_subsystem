`timescale 1ns/1ps

module doorbell_register #(
  parameter [7:0] ADDRESS = 8'h0
) (
  doorbell_register_if.controller register,
  input register_controller_t request,
  input aclk,
  input areset
);

  typedef enum logic [0:0] {
    S_IDLE,
    S_WAIT
  } state_t;
  state_t state;

  always_ff @(posedge aclk) begin
    if (areset) begin
      state <= S_IDLE;
      register.data <= '0;
      register.update <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          if (request.enable && request.write_enable) begin
            case (request.address[7:0])
              ADDRESS: begin
                state <= S_WAIT;
                register.data <= request.data;
                register.update <= 1'b1;
              end
            endcase
          end
        end

        S_WAIT: begin
          if (register.update_done) begin
            state <= S_IDLE;
            register.update <= 1'b0;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule: doorbell_register
