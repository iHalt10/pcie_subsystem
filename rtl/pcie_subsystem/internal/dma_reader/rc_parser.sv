`timescale 1ns / 1ps

import pcie_rc_pkg::rc_tlp_t;
import pcie_rc_pkg::rc_tlp_0_t;
import pcie_rc_pkg::rc_tlp_1_t;
import pcie_rc_pkg::rc_tlp_2_t;
import pcie_rc_pkg::rc_tlp_3_t;
import pcie_rc_pkg::rc_user_t;

module rc_parser (
  input [511:0]   s_axis_rc_data,
  input rc_user_t s_axis_rc_user,
  input           s_axis_rc_last,
  input           s_axis_rc_valid,

  output rc_tlp_t   tlp,
  output rc_tlp_0_t tlp_0,
  output rc_tlp_1_t tlp_1,
  output rc_tlp_2_t tlp_2,
  output rc_tlp_3_t tlp_3,
  output logic      tlp_enable,
  output logic      tlp_enable_0,
  output logic      tlp_enable_1,
  output logic      tlp_enable_2,
  output logic      tlp_enable_3,

  input aclk,
  input areset
);

  typedef struct packed {
    logic          enabled;
    logic [6:0]    index;
    logic [8703:0] data;
  } continue_t;
  continue_t c;

  logic [3:0] tlp_continue_0;
  logic [2:0] tlp_continue_1;
  logic [1:0] tlp_continue_2;
  logic [0:0] tlp_continue_3;

  always_comb begin
    tlp_0 = '0;
    tlp_enable_0 = 1'b0;
    tlp_continue_0 = '0;
    if (s_axis_rc_valid && s_axis_rc_user.is_sop[0]) begin
      case (s_axis_rc_user.is_sop_ptr[0])
        2'b00: begin
          if (s_axis_rc_user.is_eop[0]) begin
            if      (s_axis_rc_user.is_eop_ptr[0] <= 4'b0011) tlp_0[127:0] = s_axis_rc_data[127:0];
            else if (s_axis_rc_user.is_eop_ptr[0] <= 4'b0111) tlp_0[255:0] = s_axis_rc_data[255:0];
            else if (s_axis_rc_user.is_eop_ptr[0] <= 4'b1011) tlp_0[383:0] = s_axis_rc_data[383:0];
            else                                              tlp_0[511:0] = s_axis_rc_data[511:0];
            tlp_enable_0 = 1'b1;
          end else begin
            tlp_continue_0 = 4'b0001;
          end
        end
        2'b01: begin
          automatic logic       is_eop     = c.enabled ? s_axis_rc_user.is_eop[1]     : s_axis_rc_user.is_eop[0];
          automatic logic [3:0] is_eop_ptr = c.enabled ? s_axis_rc_user.is_eop_ptr[1] : s_axis_rc_user.is_eop_ptr[0];
          if (is_eop) begin
            if      (is_eop_ptr <= 4'b0111) tlp_0[127:0] = s_axis_rc_data[255:128];
            else if (is_eop_ptr <= 4'b1011) tlp_0[255:0] = s_axis_rc_data[383:128];
            else                            tlp_0[383:0] = s_axis_rc_data[511:128];
            tlp_enable_0 = 1'b1;
          end else begin
            tlp_continue_0 = 4'b0010;
          end
        end
        2'b10: begin
          automatic logic       is_eop     = c.enabled ? s_axis_rc_user.is_eop[1]     : s_axis_rc_user.is_eop[0];
          automatic logic [3:0] is_eop_ptr = c.enabled ? s_axis_rc_user.is_eop_ptr[1] : s_axis_rc_user.is_eop_ptr[0];
          if (is_eop) begin
            if (is_eop_ptr <= 4'b1011) tlp_0[127:0] = s_axis_rc_data[383:256];
            else                       tlp_0[255:0] = s_axis_rc_data[511:256];
            tlp_enable_0 = 1'b1;
          end else begin
            tlp_continue_0 = 4'b0100;
          end
        end
        2'b11: begin
          automatic logic is_eop = c.enabled ? s_axis_rc_user.is_eop[1] : s_axis_rc_user.is_eop[0];
          if (is_eop) begin
            tlp_0[127:0] = s_axis_rc_data[511:384];
            tlp_enable_0 = 1'b1;
          end else begin
            tlp_continue_0 = 4'b1000;
          end
        end
      endcase
    end
  end


  always_comb begin
    tlp_1 = '0;
    tlp_enable_1 = 1'b0;
    tlp_continue_1 = '0;
    if (s_axis_rc_valid && s_axis_rc_user.is_sop[1]) begin
      case (s_axis_rc_user.is_sop_ptr[1])
        2'b01: begin
          if (s_axis_rc_user.is_eop[1]) begin
            if      (s_axis_rc_user.is_eop_ptr[1] <= 4'b0111) tlp_1[127:0] = s_axis_rc_data[255:128];
            else if (s_axis_rc_user.is_eop_ptr[1] <= 4'b1011) tlp_1[255:0] = s_axis_rc_data[383:128];
            else                                              tlp_1[383:0] = s_axis_rc_data[511:128];
            tlp_enable_1 = 1'b1;
          end else begin
            tlp_continue_1 = 3'b001;
          end
        end
        2'b10: begin
          automatic logic       is_eop     = c.enabled ? s_axis_rc_user.is_eop[2]     : s_axis_rc_user.is_eop[1];
          automatic logic [3:0] is_eop_ptr = c.enabled ? s_axis_rc_user.is_eop_ptr[2] : s_axis_rc_user.is_eop_ptr[1];
          if (is_eop) begin
            if (is_eop_ptr <= 4'b1011) tlp_1[127:0] = s_axis_rc_data[383:256];
            else                       tlp_1[255:0] = s_axis_rc_data[511:256];
            tlp_enable_1 = 1'b1;
          end else begin
            tlp_continue_1 = 3'b010;
          end
        end
        2'b11: begin
          automatic logic is_eop = c.enabled ? s_axis_rc_user.is_eop[2] : s_axis_rc_user.is_eop[1];
          if (is_eop) begin
            tlp_1[127:0] = s_axis_rc_data[511:384];
            tlp_enable_1  = 1'b1;
          end else begin
            tlp_continue_1 = 3'b100;
          end
        end
      endcase
    end
  end


  always_comb begin
    tlp_2 = '0;
    tlp_enable_2 = 1'b0;
    tlp_continue_2 = '0;
    
    if (s_axis_rc_valid && s_axis_rc_user.is_sop[2]) begin
      case (s_axis_rc_user.is_sop_ptr[2])
        2'b10: begin
          if (s_axis_rc_user.is_eop[2]) begin
            if (s_axis_rc_user.is_eop_ptr[2] <= 4'b1011) tlp_2[127:0] = s_axis_rc_data[383:256];
            else                                         tlp_2[255:0] = s_axis_rc_data[511:256];
            tlp_enable_2 = 1'b1;
          end else begin
            tlp_continue_2 = 2'b01;
          end
        end
        2'b11: begin
          automatic logic is_eop = c.enabled ? s_axis_rc_user.is_eop[3] : s_axis_rc_user.is_eop[2];
          if (is_eop) begin
            tlp_2[127:0] = s_axis_rc_data[511:384];
            tlp_enable_2  = 1'b1;
          end else begin
            tlp_continue_2 = 2'b10;
          end
        end
      endcase
    end
  end


  always_comb begin
    tlp_3 = '0;
    tlp_enable_3 = 1'b0;
    tlp_continue_3 = '0;
    if (s_axis_rc_valid && s_axis_rc_user.is_sop[3]) begin
      if (s_axis_rc_user.is_eop[3]) begin
        tlp_3[127:0] = s_axis_rc_data[511:384];
        tlp_enable_3  = 1'b1;
      end else begin
        tlp_continue_3 = 1'b1;
      end
    end
  end

  always_comb begin
    tlp = '0;
    tlp_enable = 1'b0;
    if (s_axis_rc_valid) begin
      if (c.enabled && s_axis_rc_user.is_eop[0]) begin
        tlp = c.data;
        tlp[(c.index+0)*128 +: 128] = s_axis_rc_data[127:0];
        if (s_axis_rc_user.is_eop_ptr[0] >= 4'b0100) tlp[(c.index+1)*128 +: 128] = s_axis_rc_data[255:128];
        if (s_axis_rc_user.is_eop_ptr[0] >= 4'b1000) tlp[(c.index+2)*128 +: 128] = s_axis_rc_data[383:256];
        if (s_axis_rc_user.is_eop_ptr[0] >= 4'b1100) tlp[(c.index+3)*128 +: 128] = s_axis_rc_data[511:384];
        tlp_enable = 1'b1;
      end
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      c <= '0;
    end else begin
      if (s_axis_rc_valid) begin
        c <= parse_for_continue(
          c, tlp_continue_0, tlp_continue_1, tlp_continue_2, tlp_continue_3,
          s_axis_rc_data, s_axis_rc_user
        );
      end
    end
  end

  function automatic logic [8711:0] parse_for_continue(
    input continue_t    now_continue,
    input logic [3:0]   tlp_continue_0,
    input logic [2:0]   tlp_continue_1,
    input logic [1:0]   tlp_continue_2,
    input logic [0:0]   tlp_continue_3,
    input logic [511:0] data,
    input rc_user_t     user
  );
    continue_t next_continue = '0;

    if (now_continue.enabled && !user.is_eop[0]) begin
      next_continue.data = now_continue.data;
      next_continue.data[(now_continue.index+0)*128 +: 128] = data[127:0];
      next_continue.data[(now_continue.index+1)*128 +: 128] = data[255:128];
      next_continue.data[(now_continue.index+2)*128 +: 128] = data[383:256];
      next_continue.data[(now_continue.index+3)*128 +: 128] = data[511:384];
      next_continue.index = now_continue.index + 4;
      next_continue.enabled = 1'b1;
      return next_continue;
    end

    if (tlp_continue_0[0]) begin
      next_continue.data[511:0] = data[511:0];
      next_continue.index       = 4;
      next_continue.enabled     = 1'b1;
      return next_continue;
    end

    if (tlp_continue_0[1] || tlp_continue_1[0]) begin
      next_continue.data[383:0] = data[511:128];
      next_continue.index       = 3;
      next_continue.enabled     = 1'b1;
      return next_continue;
    end

    if (tlp_continue_0[2] || tlp_continue_1[1] || tlp_continue_2[0]) begin
      next_continue.data[255:0] = data[511:256];
      next_continue.index       = 2;
      next_continue.enabled     = 1'b1;
      return next_continue;
    end

    if (tlp_continue_0[3] || tlp_continue_1[2] || tlp_continue_2[1] || tlp_continue_3[0]) begin
      next_continue.data[127:0] = data[511:384];
      next_continue.index       = 1;
      next_continue.enabled     = 1'b1;
      return next_continue;
    end

    return next_continue;
  endfunction

endmodule: rc_parser
