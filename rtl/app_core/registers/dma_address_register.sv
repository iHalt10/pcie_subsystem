`timescale 1ns/1ps

module dma_address_register #(
  parameter [7:0] ADDRESS_LOW  = 8'h0,
  parameter [7:0] ADDRESS_HIGH = 8'h0
) (
  dma_register_if.controller register,
  input register_controller_t request,
  input aclk,
  input areset
);

  always_ff @(posedge aclk) begin
    if (areset) begin
      register.data <= '0;
    end
    else begin
      if (request.enable && request.write_enable) begin
        case (request.address[7:0])
          ADDRESS_LOW:  register.data[31:0]  <= request.data;
          ADDRESS_HIGH: register.data[63:32] <= request.data;
        endcase
      end
    end
  end

endmodule: dma_address_register
