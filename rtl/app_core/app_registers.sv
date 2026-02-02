`timescale 1ns/1ps

import register_controller_pkg::register_controller_t;

module app_registers (
  input register_controller_t  request,
  output register_controller_t response,

  dma_register_if.controller      dma_address,
  doorbell_register_if.controller doorbell,

  input aclk,
  input areset
);

  localparam [7:0] ADDR_HEALTH_CHECK = 8'h00; // NOTE: RO
  localparam [7:0] ADDR_DMA_LOW      = 8'h04; // NOTE: RW
  localparam [7:0] ADDR_DMA_HIGH     = 8'h08; // NOTE: Rw
  localparam [7:0] ADDR_DOORBELL     = 8'h0C; // NOTE: WO

  always_comb begin
    response = '0;
    if (request.enable && ~request.write_enable) begin
      response = request;
      case (request.address[7:0])
        ADDR_HEALTH_CHECK: response.data = 32'h1234CAFE;
        ADDR_DMA_LOW:      response.data = dma_address.data[31:0];
        ADDR_DMA_HIGH:     response.data = dma_address.data[63:32];
        default: response.data = 32'hDEADBEEF;
      endcase
    end
  end

  dma_address_register #(
    .ADDRESS_LOW(ADDR_DMA_LOW),
    .ADDRESS_HIGH(ADDR_DMA_HIGH)
  ) dma_address_register_inst (
    .register (dma_address),
    .request  (request),
    .aclk     (aclk),
    .areset   (areset)
  );

  doorbell_register #(
    .ADDRESS(ADDR_DOORBELL)
  ) doorbell_register_inst (
    .register (doorbell),
    .request  (request),
    .aclk     (aclk),
    .areset   (areset)
  );

endmodule: app_registers
