`timescale 1ns / 1ps

import pcie_pkg::REQUEST_MEM_READ;
import pcie_pkg::REQUEST_MEM_WRITE;
import pcie_pkg::REQUEST_IO_READ;
import pcie_pkg::REQUEST_IO_WRITE;
import pcie_pkg::ADDRESS_TYPE_UNTRANSLATED;
import pcie_cq_pkg::cq_tlp_t;
import pcie_cq_pkg::cq_user_t;
import register_controller_pkg::register_controller_t;

module register_requester (
  pcie_axis_cq_if.slave s_axis_cq,
  output register_controller_t request,
  input aclk,
  input areset
);

  cq_tlp_t cq_tlp;
  logic    cq_tlp_enable;
  register_controller_t request_internal;

  assign s_axis_cq.ready = 1'b1;

  cq_parser_non_straddle cq_parser_inst (
    .s_axis_cq_data  (s_axis_cq.data),
    .s_axis_cq_user  (s_axis_cq.user),
    .s_axis_cq_last  (s_axis_cq.last),
    .s_axis_cq_valid (s_axis_cq.valid),

    .tlp        (cq_tlp),
    .tlp_enable (cq_tlp_enable),

    .aclk   (aclk),
    .areset (areset)
  );

  always_comb begin
    request_internal = '0;
    if (cq_tlp_enable) begin
      case (cq_tlp.desc.raw[78:75])
        REQUEST_MEM_READ, REQUEST_IO_READ: begin
          if (cq_tlp.desc.mem.address_type == ADDRESS_TYPE_UNTRANSLATED && cq_tlp.desc.mem.dword_count == 11'b1) begin
            request_internal.enable                     = 1'b1;
            request_internal.write_enable               = 1'b0;
            request_internal.address                    = {cq_tlp.desc.mem.address, 2'b00};
            request_internal.data                       = '0;
            request_internal.function_id                = cq_tlp.desc.mem.function_id;
            request_internal.bar_id                     = cq_tlp.desc.mem.bar_id;
            request_internal.metadata.attributes        = cq_tlp.desc.mem.attributes;
            request_internal.metadata.requester_id      = cq_tlp.desc.mem.requester_id;
            request_internal.metadata.transaction_class = cq_tlp.desc.mem.transaction_class;
            request_internal.metadata.lower_address     = {cq_tlp.desc.mem.address[4:0], 2'b00};
            request_internal.metadata.tag               = cq_tlp.desc.mem.tag;
          end
        end
        REQUEST_MEM_WRITE, REQUEST_IO_WRITE: begin
          if (cq_tlp.desc.mem.address_type == ADDRESS_TYPE_UNTRANSLATED && cq_tlp.desc.mem.dword_count == 11'b1) begin
            request_internal.enable                     = 1'b1;
            request_internal.write_enable               = 1'b1;
            request_internal.address                    = {cq_tlp.desc.mem.address, 2'b00};
            request_internal.data                       = cq_tlp.payload[31:0];;
            request_internal.function_id                = cq_tlp.desc.mem.function_id;
            request_internal.bar_id                     = cq_tlp.desc.mem.bar_id;
            request_internal.metadata.attributes        = cq_tlp.desc.mem.attributes;
            request_internal.metadata.requester_id      = cq_tlp.desc.mem.requester_id;
            request_internal.metadata.transaction_class = cq_tlp.desc.mem.transaction_class;
            request_internal.metadata.lower_address     = {cq_tlp.desc.mem.address[4:0], 2'b00};
            request_internal.metadata.tag               = cq_tlp.desc.mem.tag;
          end
        end
      endcase
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      request <= '0;
    end else begin
      request <= request_internal;
    end
  end

endmodule: register_requester
