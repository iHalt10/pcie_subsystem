`timescale 1ns/1ps

module register_router #(
  parameter int NUM_REQUESTS = 1,
  parameter bit [7:0] FUNCTION_ID = 8'b00000000,
  parameter bit [2:0] BAR_ID = 3'b000,
  parameter bit [63:0] BASE_ADDR [NUM_REQUESTS] = '{
    0: 64'hDEAD_BEEF_DEAD_BEEF
  },
  parameter bit [63:0] HIGH_ADDR [NUM_REQUESTS] = '{
    0: 64'hDEAD_BEEF_DEAD_BEEF
  }
) (
  input  register_controller_t request,
  output register_controller_t [NUM_REQUESTS-1:0] requests,
  output register_controller_t outside_response,

  input [63:0] base_address,

  input aclk,
  input areset
);

  logic [NUM_REQUESTS-1:0] selector;
  register_controller_t request_internal;
  register_controller_t outside_response_internal;

  logic [63:0] adjusted_address;

  always_comb begin
    selector = '0;
    request_internal = '0;
    if (request.enable && request.function_id == FUNCTION_ID && request.bar_id == BAR_ID) begin
      automatic logic [63:0] adjusted_address;
      request_internal = request;
      adjusted_address = request.address - base_address;
      for (int i = 0; i < NUM_REQUESTS; i++) begin
        if (adjusted_address >= BASE_ADDR[i] && adjusted_address <= HIGH_ADDR[i]) begin
          selector[i] = 1'b1;
          request_internal.address = adjusted_address - BASE_ADDR[i];
        end
      end
    end
  end

  always_comb begin
    outside_response_internal = '0;
    if (request_internal.enable && ~request_internal.write_enable && selector == '0) begin
      outside_response_internal = request_internal;
      outside_response_internal.data = 32'hDEADBEEF;
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      requests <= '0;
      outside_response <= '0;
    end else begin
      for (int i = 0; i < NUM_REQUESTS; i++) begin
        if (selector[i]) begin
          requests[i] <= request_internal;
        end else begin
          requests[i] <= '0;
        end
      end
      outside_response <= outside_response_internal;
    end
  end

endmodule: register_router
