`timescale 1ns / 1ps

import pcie_pkg::ADDRESS_TYPE_UNTRANSLATED;
import pcie_pkg::COMPLETION_STATUS_SC;
import pcie_cc_pkg::cc_descriptor_t;
import register_controller_pkg::register_controller_t;

module register_response_fifo #(
  parameter int DEPTH = 4
) (
  input register_controller_t response,
  pcie_axis_cc_if.master m_axis_cc,

  output reg error,

  input aclk,
  input areset
);

  initial begin
    if ((DEPTH & (DEPTH - 1)) != 0 || DEPTH == 0 || DEPTH == 1) begin
      $fatal("Parameter DEPTH (%d) must be a power of 2 and greater than 0", DEPTH);
    end
  end

  localparam int WIDTH = $clog2(DEPTH);

  register_controller_t [DEPTH-1:0] mem;
  reg [WIDTH-1:0] head;
  reg [WIDTH-1:0] tail;
  wire is_full;

  assign is_full = (head == ((tail + 1) & (DEPTH - 1)));

  always_comb begin
    m_axis_cc.data = '0;
    m_axis_cc.keep = '0;
    m_axis_cc.last = '0;
    m_axis_cc.user = '0;
    m_axis_cc.valid = '0;
    if (mem[head].enable) begin
      m_axis_cc.data  = generate_cc_data(mem[head]);
      m_axis_cc.keep  = 16'h000F;
      m_axis_cc.last  = 1'b1;
      m_axis_cc.valid = 1'b1;
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      mem <= '0;
      head <= '0;
      tail <= '0;
      error <= '0;
    end else begin
      if (response.enable && !is_full) begin
        mem[tail] <= response;
        tail <= tail + 1;
      end

      if (m_axis_cc.ready[0] && m_axis_cc.valid) begin
        mem[head] <= '0;
        head <= head + 1;
      end

      if (is_full && response.enable) begin
        error <= 1'b1;
      end
    end
  end

  function automatic logic [511:0] generate_cc_data(
    input register_controller_t response
  );
    logic [511:0] data;
    cc_descriptor_t desc;

    data = '0;
    desc = '0;

    desc.lower_address     = response.metadata.lower_address;
    desc.address_type      = ADDRESS_TYPE_UNTRANSLATED;
    desc.byte_count        = 13'd4;
    desc.dword_count       = 11'd1;
    desc.completion_status = COMPLETION_STATUS_SC;
    desc.requester_id      = response.metadata.requester_id;
    desc.tag               = response.metadata.tag;
    desc.transaction_class = response.metadata.transaction_class;
    desc.attributes        = response.metadata.attributes;

    data[127:96] = response.data;
    data[95:0]   = desc;

    return data;
  endfunction

endmodule: register_response_fifo
