`timescale 1ns / 1ps

import pcie_rc_pkg::rc_tlp_t;
import pcie_rc_pkg::rc_tlp_0_t;
import pcie_rc_pkg::rc_tlp_1_t;
import pcie_rc_pkg::rc_tlp_2_t;
import pcie_rc_pkg::rc_tlp_3_t;
import pcie_rc_pkg::rc_descriptor_t;

module rc_receiver #(
  parameter int TAG_COUNT = 1,
  parameter int TAG_INDEX = 0
) (
  pcie_axis_rc_if.slave s_axis_rc,
  output rc_tlp_t tlp,
  output logic received,
  input aclk,
  input areset
);

  assign s_axis_rc.ready = 1'b1;

  rc_tlp_t   rc_tlp[2];
  rc_tlp_0_t rc_tlp_0[2];
  rc_tlp_1_t rc_tlp_1[2];
  rc_tlp_2_t rc_tlp_2[2];
  rc_tlp_3_t rc_tlp_3[2];
  logic rc_tlp_enable[2];
  logic rc_tlp_enable_0[2];
  logic rc_tlp_enable_1[2];
  logic rc_tlp_enable_2[2];
  logic rc_tlp_enable_3[2];

  rc_tlp_0_t rc_short_tlp;
  logic      rc_short_tlp_received;

  logic rc_tlp_received;
  logic rc_tlp_received_0;
  logic rc_tlp_received_1;
  logic rc_tlp_received_2;
  logic rc_tlp_received_3;

  rc_parser rc_parser_inst (
    .s_axis_rc_data  (s_axis_rc.data),
    .s_axis_rc_user  (s_axis_rc.user),
    .s_axis_rc_last  (s_axis_rc.last),
    .s_axis_rc_valid (s_axis_rc.valid),
    .tlp             (rc_tlp[0]),
    .tlp_0           (rc_tlp_0[0]),
    .tlp_1           (rc_tlp_1[0]),
    .tlp_2           (rc_tlp_2[0]),
    .tlp_3           (rc_tlp_3[0]),
    .tlp_enable      (rc_tlp_enable[0]),
    .tlp_enable_0    (rc_tlp_enable_0[0]),
    .tlp_enable_1    (rc_tlp_enable_1[0]),
    .tlp_enable_2    (rc_tlp_enable_2[0]),
    .tlp_enable_3    (rc_tlp_enable_3[0]),
    .aclk            (aclk),
    .areset          (areset)
  );

  always_ff @(posedge aclk) begin
    if (areset) begin
      rc_tlp[1] <= '0;
      rc_tlp_0[1] <= '0;
      rc_tlp_1[1] <= '0;
      rc_tlp_2[1] <= '0;
      rc_tlp_3[1] <= '0;
      rc_tlp_enable[1] <= '0;
      rc_tlp_enable_0[1] <= '0;
      rc_tlp_enable_1[1] <= '0;
      rc_tlp_enable_2[1] <= '0;
      rc_tlp_enable_3[1] <= '0;
    end else begin
      rc_tlp[1] <= rc_tlp[0];
      rc_tlp_0[1] <= rc_tlp_0[0];
      rc_tlp_1[1] <= rc_tlp_1[0];
      rc_tlp_2[1] <= rc_tlp_2[0];
      rc_tlp_3[1] <= rc_tlp_3[0];
      rc_tlp_enable[1] <= rc_tlp_enable[0];
      rc_tlp_enable_0[1] <= rc_tlp_enable_0[0];
      rc_tlp_enable_1[1] <= rc_tlp_enable_1[0];
      rc_tlp_enable_2[1] <= rc_tlp_enable_2[0];
      rc_tlp_enable_3[1] <= rc_tlp_enable_3[0];
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      rc_short_tlp <= '0;
      rc_short_tlp_received <= '0;
    end else begin
      if (rc_tlp_received_0) begin
        rc_short_tlp <= rc_tlp_0[1];
        rc_short_tlp_received <= 1'b1;
      end else if (rc_tlp_received_1) begin
        rc_short_tlp <= {'0, rc_tlp_1[1]};
        rc_short_tlp_received <= 1'b1;
      end else if (rc_tlp_received_2) begin
        rc_short_tlp <= {'0, rc_tlp_2[1]};
        rc_short_tlp_received <= 1'b1;
      end else if (rc_tlp_received_3) begin
        rc_short_tlp <= {'0, rc_tlp_3[1]};
        rc_short_tlp_received <= 1'b1;
      end else begin
        rc_short_tlp <= '0;
        rc_short_tlp_received <= '0;
      end
    end
  end

  assign rc_tlp_received   = is_received(rc_tlp_enable[1],   rc_tlp[1].desc);
  assign rc_tlp_received_0 = is_received(rc_tlp_enable_0[1], rc_tlp_0[1].desc);
  assign rc_tlp_received_1 = is_received(rc_tlp_enable_1[1], rc_tlp_1[1].desc);
  assign rc_tlp_received_2 = is_received(rc_tlp_enable_2[1], rc_tlp_2[1].desc);
  assign rc_tlp_received_3 = is_received(rc_tlp_enable_3[1], rc_tlp_3[1].desc);

  always_comb begin
    tlp = '0;
    received = '0;
    if (rc_tlp_received) begin
      tlp = rc_tlp[1];
      received = 1'b1;
    end else if (rc_short_tlp_received) begin
      tlp = {'0, rc_short_tlp};
      received = 1'b1;
    end
  end

  function automatic logic is_received(
    input logic enable,
    input rc_descriptor_t desc
  );
    logic received = (enable && !desc.poisoned_completion && (desc.tag >= TAG_INDEX && desc.tag < TAG_INDEX + TAG_COUNT));
    return received;
  endfunction

endmodule: rc_receiver
