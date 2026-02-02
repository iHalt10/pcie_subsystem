`timescale 1ns / 1ps

import pcie_pkg::REQUEST_MEM_WRITE;
import pcie_pkg::ADDRESS_TYPE_UNTRANSLATED;
import pcie_pkg::calculate_max_payload_dwords;
import pcie_pkg::calculate_address_by_max_payload;
import pcie_rq_pkg::rq_mem_descriptor_t;
import pcie_rq_pkg::rq_user_t;

module dma_writer #(
  parameter int MAX_DATA_SIZE     = 1024,
  parameter int DWORD_COUNT_WIDTH = $clog2(MAX_DATA_SIZE / 4) + 1
) (
  dma_writer_if.controller access_bus,
  pcie_axis_rq_if.master m_axis_rq,
  input [1:0] cfg_max_payload,
  input aclk,
  input areset
);

  localparam int RQ_TLP_COUNT_WIDTH = $clog2(MAX_DATA_SIZE / 128) + 1; // NOTE: Smallest　Max Read Request (128 bytes)

  typedef enum logic [2:0] {
    S_IDLE,
    S_INIT,
    S_RQ_TLP_SEND_START,
    S_RQ_TLP_SEND_CONTINUE,
    S_RQ_TLP_SEND_END,
    S_DONE
  } state_t;

  typedef struct packed {
    logic [RQ_TLP_COUNT_WIDTH-1:0] now_rq_tlp_count;
    logic [4:0] now_clocks_count_per_rq_tlp;
    logic [63:0] address;
  } dynamic_metadata_t;

  typedef struct packed {
    logic [RQ_TLP_COUNT_WIDTH-1:0] request_rq_tlp_count;
    logic [4:0]   request_clocks_last_rq_tlp;
    logic [4:0]   maximum_clocks_per_rq_tlp;

    logic [10:0]  rq_desc_dwords_by_last_rq_tlp;

    logic [511:0] rq_data_mask_by_last_clock;
    logic [15:0]  rq_data_keep_by_last_clock;
    logic [7:0]   rq_user_last_be_by_last_clock;
    logic [3:0]   rq_user_is_eop0_ptr_by_last_clock;
    logic [3:0]   fifo_index_by_last_clock;
  } static_metadata_t;

  state_t state;
  dynamic_metadata_t metadata;
  dynamic_metadata_t next_metadata;
  static_metadata_t static_metadata;
  static_metadata_t static_metadata_internal;
  pcie_axis_rq_if axis_rq ();
  dma_writer_fifo_if fifo_bus();

  assign {
    axis_rq.data,
    axis_rq.keep,
    axis_rq.user,
    axis_rq.last,
    next_metadata,
    fifo_bus.read_index
  } = (state == S_RQ_TLP_SEND_START || state == S_RQ_TLP_SEND_CONTINUE) ? generate_rq_packet_with_metadata(fifo_bus.read_data, metadata, static_metadata, cfg_max_payload) : '0;

  assign static_metadata_internal = (access_bus.dword_count == '0) ? '0 : calculate_static_metadata(access_bus.dword_count, cfg_max_payload);

  assign access_bus.ready = (fifo_bus.status_length < 7'd32);
  assign fifo_bus.write_enable = access_bus.ready && access_bus.valid;
  assign fifo_bus.write_data = access_bus.data;
  assign fifo_bus.write_keep = access_bus.keep;
  assign fifo_bus.read_enable = (state == S_RQ_TLP_SEND_START || (state == S_RQ_TLP_SEND_CONTINUE && m_axis_rq.ready[0]));

  dma_writer_fifo dma_writer_fifo_inst (
    .access_bus (fifo_bus),
    .aclk   (aclk),
    .areset (areset)
  );

  always_ff @(posedge aclk) begin
    if (areset) begin
      state <= S_IDLE;
      access_bus.busy <= '0;
      access_bus.error <= '0;
      m_axis_rq.valid <= '0;
      m_axis_rq.data <= '0;
      m_axis_rq.keep <= '0;
      m_axis_rq.user <= '0;
      m_axis_rq.last <= '0;
      metadata <= '0;
      static_metadata <= '0;
      fifo_bus.clear <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          if (access_bus.valid) begin
            if (access_bus.dword_count == '0) begin
              state <= S_DONE;
              access_bus.error <= 1'b1;
            end else begin
              state <= S_INIT;
            end
            access_bus.busy <= 1'b1;
          end
        end

        S_INIT: begin
          state <= S_RQ_TLP_SEND_START;
          metadata <= initialize_metadata(access_bus.address);
          static_metadata <= static_metadata_internal;
        end

        S_RQ_TLP_SEND_START: begin
          state <= (axis_rq.last) ? S_RQ_TLP_SEND_END : S_RQ_TLP_SEND_CONTINUE;
          m_axis_rq.valid <= 1'b1;
          m_axis_rq.data <= axis_rq.data;
          m_axis_rq.keep <= axis_rq.keep;
          m_axis_rq.user <= axis_rq.user;
          m_axis_rq.last <= axis_rq.last;
          metadata <= next_metadata;
        end

        S_RQ_TLP_SEND_CONTINUE: begin
          if (m_axis_rq.ready[0]) begin
            state <= (axis_rq.last) ? S_RQ_TLP_SEND_END : S_RQ_TLP_SEND_CONTINUE;
            m_axis_rq.data <= axis_rq.data;
            m_axis_rq.keep <= axis_rq.keep;
            m_axis_rq.user <= axis_rq.user;
            m_axis_rq.last <= axis_rq.last;
            metadata <= next_metadata;
          end
        end

        S_RQ_TLP_SEND_END: begin
          if (m_axis_rq.ready[0]) begin
            state <= S_DONE;
            m_axis_rq.data <= '0;
            m_axis_rq.keep <= '0;
            m_axis_rq.last <= '0;
            m_axis_rq.user <= '0;
            m_axis_rq.valid <= '0;
            metadata <= '0;
            static_metadata <= '0;
            fifo_bus.clear <= 1'b1;
          end
        end

        S_DONE: begin
          state <= S_IDLE;
          fifo_bus.clear <= 1'b0;
          access_bus.busy <= 1'b0;
          access_bus.error <= 1'b0;
        end

        default: state <= S_IDLE;
      endcase
    end
  end


  function automatic dynamic_metadata_t initialize_metadata(
    input logic [63:0] address
  );
    dynamic_metadata_t metadata;
    metadata.address = address;
    metadata.now_rq_tlp_count = 'd1;
    metadata.now_clocks_count_per_rq_tlp = 5'd1;
    return metadata;
  endfunction


  function automatic logic [10:0] calculate_dword_count_by_last_rq_tlp(
    input logic [DWORD_COUNT_WIDTH-1:0] dword_count,
    input logic [10:0] max_payload_dwords
  );
    logic [10:0] remainder = dword_count % max_payload_dwords;
    if (remainder == 0) return max_payload_dwords;
    return remainder;
  endfunction


  function automatic logic [RQ_TLP_COUNT_WIDTH-1:0] calculate_rq_tlp_count(
    input logic [DWORD_COUNT_WIDTH-1:0] dword_count,
    input logic [10:0] max_payload_dwords
  );
    logic [RQ_TLP_COUNT_WIDTH-1:0] rq_tlp_count = (dword_count + max_payload_dwords - 1) / max_payload_dwords;
    return rq_tlp_count;
  endfunction


  function automatic logic [4:0] calculate_clocks_last_rq_tlp(
    input logic [10:0] dword_count,
    input logic parity
  );
    logic [4:0] clocks;
    logic [10:0] offset;
    if (parity) begin // NOTE: Odd
      offset = 11'd4;
    end else begin // NOTE: Even
      offset = 11'd12;
    end
    clocks = ((dword_count + offset) + 11'd16 - 11'd1) / 11'd16;
    return clocks;
  endfunction


  function automatic logic [4:0] calculate_maximum_clocks_per_rq_tlp(
    input logic [1:0] cfg_max_payload
  );
    case (cfg_max_payload)
      2'b00: return 5'd3;  // 128 bytes
      2'b01: return 5'd5;  // 256 bytes
      2'b10: return 5'd9;  // 512 bytes
      2'b11: return 5'd17; // 1024 bytes
    endcase
  endfunction


  function automatic logic [14:0] calculate_dword_count_by_last_clock_with_eop_ptr(
    input logic [10:0] dword_count,
    input logic parity
  );
    // dword_count[11] + eop_ptr[4] = 15
    logic [10:0] remainder;
    logic [10:0] offset_dwords;
    logic [10:0] end_dwords;
    logic [3:0] eop_ptr;

    if (parity) begin // NOTE: Odd
      offset_dwords = 11'd4;
      end_dwords = 11'd12;
    end else begin // NOTE: Even
      offset_dwords = 11'd12;
      end_dwords = 11'd4;
    end

    if (dword_count <= end_dwords) begin
      if (parity) begin
        eop_ptr = (dword_count + offset_dwords) - 4'b0001;
        return {dword_count, eop_ptr};
      end
      eop_ptr = (dword_count + offset_dwords) - 4'b0001;
      return {dword_count + 11'd4, eop_ptr};
    end

    remainder = (dword_count + offset_dwords) % 11'd16;
    if (remainder == 0) begin
      return {11'd16, 4'b1111};
    end else begin
      eop_ptr = remainder[3:0] - 4'b0001;
      return {remainder, eop_ptr};
    end
  endfunction


  function automatic static_metadata_t calculate_static_metadata(
    input logic [DWORD_COUNT_WIDTH-1:0] dword_count,
    input logic [1:0] cfg_max_payload
  );
    static_metadata_t static_metadata;
    logic [10:0] max_payload_dwords;
    logic [10:0] dword_count_by_last_rq_tlp;
    logic [10:0] dword_count_by_last_clock;
    logic [3:0]  eop_ptr;

    max_payload_dwords = calculate_max_payload_dwords(cfg_max_payload);
    dword_count_by_last_rq_tlp = calculate_dword_count_by_last_rq_tlp(dword_count, max_payload_dwords);

    static_metadata.request_rq_tlp_count       = calculate_rq_tlp_count(dword_count, max_payload_dwords);
    static_metadata.request_clocks_last_rq_tlp = calculate_clocks_last_rq_tlp(dword_count_by_last_rq_tlp, static_metadata.request_rq_tlp_count[0]);
    static_metadata.maximum_clocks_per_rq_tlp  = calculate_maximum_clocks_per_rq_tlp(cfg_max_payload);

    static_metadata.rq_desc_dwords_by_last_rq_tlp = dword_count_by_last_rq_tlp;

    {dword_count_by_last_clock, eop_ptr} = calculate_dword_count_by_last_clock_with_eop_ptr(dword_count_by_last_rq_tlp, static_metadata.request_rq_tlp_count[0]);
    static_metadata.rq_data_keep_by_last_clock = (16'h1 << dword_count_by_last_clock[4:0]) - 16'h1;
    for (int i = 0; i < 16; i++) begin
      static_metadata.rq_data_mask_by_last_clock[i*32 +: 32] = {32{static_metadata.rq_data_keep_by_last_clock[i]}};
    end

    if (static_metadata.rq_desc_dwords_by_last_rq_tlp == 1) begin
      static_metadata.rq_user_last_be_by_last_clock = 8'b00000000;
    end else begin
      static_metadata.rq_user_last_be_by_last_clock = 8'b00001111;
    end

    static_metadata.rq_user_is_eop0_ptr_by_last_clock = eop_ptr;
    static_metadata.fifo_index_by_last_clock = dword_count_by_last_clock[4:0] - 5'b1;

    return static_metadata;
  endfunction


  function automatic logic [(DWORD_COUNT_WIDTH + 739) - 1:0] generate_rq_packet_with_metadata(
    input [511:0] data,
    input dynamic_metadata_t now_metadata,
    input static_metadata_t static_metadata,
    input logic [1:0] cfg_max_payload
  );
    // 512 + 16 + 137 + 1 + (RQ_TLP_COUNT_WIDTH + 5 + 64) + 4 = (DWORD_COUNT_WIDTH + 739)
    rq_mem_descriptor_t rq_desc;
    rq_user_t           rq_user;
    logic               rq_last;
    logic [511:0]       rq_data;
    logic [15:0]        rq_keep;
    logic [3:0]         fifo_index;
    logic [63:0]        next_address;
    logic [511:0]       masked_data;
    logic [15:0]        masked_keep;
    logic [10:0]        max_payload_dwords;
    dynamic_metadata_t  next_metadata;

    rq_desc              = '0;
    rq_desc.address_type = ADDRESS_TYPE_UNTRANSLATED;
    rq_desc.request_type = REQUEST_MEM_WRITE;
    rq_desc.tag          = 8'b0;
    rq_data              = '0;
    rq_keep              = '0;
    rq_user              = '0;
    rq_last              = '0;
    fifo_index           = '0;
    next_metadata        = '0;

    max_payload_dwords = calculate_max_payload_dwords(cfg_max_payload);
    next_address = calculate_address_by_max_payload(now_metadata.address, 1, cfg_max_payload);
    next_metadata.address = now_metadata.address;

    if (now_metadata.now_rq_tlp_count[0]) begin // NOTE: Odd
      if (now_metadata.now_clocks_count_per_rq_tlp == static_metadata.maximum_clocks_per_rq_tlp) begin
        next_metadata.now_rq_tlp_count = now_metadata.now_rq_tlp_count + 'b1;
        next_metadata.now_clocks_count_per_rq_tlp = 5'd2;
      end else begin
        next_metadata.now_rq_tlp_count = now_metadata.now_rq_tlp_count;
        next_metadata.now_clocks_count_per_rq_tlp = now_metadata.now_clocks_count_per_rq_tlp + 5'b1;
      end
    end else begin // NOTE: Even
      if (now_metadata.now_clocks_count_per_rq_tlp == static_metadata.maximum_clocks_per_rq_tlp) begin
        next_metadata.now_rq_tlp_count = now_metadata.now_rq_tlp_count + 'b1;
        next_metadata.now_clocks_count_per_rq_tlp = 5'd1;
      end else begin
        next_metadata.now_rq_tlp_count = now_metadata.now_rq_tlp_count;
        next_metadata.now_clocks_count_per_rq_tlp = now_metadata.now_clocks_count_per_rq_tlp + 5'b1;
      end
    end

    if (now_metadata.now_rq_tlp_count[0]) begin // NOTE: Odd
      if (now_metadata.now_rq_tlp_count == static_metadata.request_rq_tlp_count) begin
        if (now_metadata.now_clocks_count_per_rq_tlp == 1) begin
          rq_desc.dword_count = static_metadata.rq_desc_dwords_by_last_rq_tlp;
          rq_desc.address = now_metadata.address[63:2];
          next_metadata.address = next_address;
          rq_user.is_sop = 2'b01;
          rq_user.first_be = 8'b00001111;

          if (static_metadata.request_clocks_last_rq_tlp == 1) begin // NOTE: clock last
            rq_last = 1'b1;
            rq_user.is_eop      = 2'b01;
            rq_user.is_eop_ptr[0] = static_metadata.rq_user_is_eop0_ptr_by_last_clock;
            rq_user.last_be     = static_metadata.rq_user_last_be_by_last_clock;

            masked_data = data & static_metadata.rq_data_mask_by_last_clock;
            masked_keep = static_metadata.rq_data_keep_by_last_clock;
            rq_data = {masked_data[383:0], rq_desc};
            rq_keep = {masked_keep[11:0], 4'b1111};
            fifo_index = static_metadata.fifo_index_by_last_clock;
            return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
          end else begin // NOTE: clock continue
            rq_user.last_be  = 8'b00001111;
            rq_data = {data[383:0], rq_desc};
            rq_keep = {4'b1111, 4'b1111, 4'b1111, 4'b1111};
            fifo_index = 11;
            return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
          end
        end else if (now_metadata.now_clocks_count_per_rq_tlp == static_metadata.request_clocks_last_rq_tlp) begin // NOTE: clock last // packet[128,128,128,128], packet[128,xxxx,xxxx,xxxx]
          rq_last = 1'b1;
          rq_user.is_eop      = 2'b01;
          rq_user.is_eop_ptr[0] = static_metadata.rq_user_is_eop0_ptr_by_last_clock;
          masked_data = data & static_metadata.rq_data_mask_by_last_clock;
          masked_keep = static_metadata.rq_data_keep_by_last_clock;
          rq_data = masked_data;
          rq_keep = masked_keep;
          fifo_index = static_metadata.fifo_index_by_last_clock;
          return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
        end
      end else if (now_metadata.now_rq_tlp_count == static_metadata.request_rq_tlp_count - 1 && now_metadata.now_clocks_count_per_rq_tlp == static_metadata.maximum_clocks_per_rq_tlp) begin
        rq_desc.dword_count = static_metadata.rq_desc_dwords_by_last_rq_tlp;
        rq_desc.address = now_metadata.address[63:2];
        next_metadata.address = next_address;
        rq_user.is_sop = 2'b01;
        rq_user.is_sop_ptr[0] = 2'b10;
        rq_user.first_be = 8'b00001111;

        if (static_metadata.request_clocks_last_rq_tlp == 1) begin // NOTE: clock last
          rq_last = 1'b1;
          rq_user.is_eop      = 2'b11;
          rq_user.is_eop_ptr[0] = 4'b0011;
          rq_user.is_eop_ptr[1] = static_metadata.rq_user_is_eop0_ptr_by_last_clock;
          rq_user.last_be     = static_metadata.rq_user_last_be_by_last_clock;

          masked_data = data & static_metadata.rq_data_mask_by_last_clock;
          masked_keep = static_metadata.rq_data_keep_by_last_clock;
          rq_data = {masked_data[255:128], rq_desc, {4{32'h00000000}}, masked_data[127:0]};
          rq_keep = {masked_keep[7:4], 4'b1111, 4'b0000, 4'b1111};
          fifo_index = static_metadata.fifo_index_by_last_clock;
          return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
        end else begin // NOTE: clock continue
          rq_user.is_eop      = 2'b01;
          rq_user.is_eop_ptr[0] = 4'b0011;
          rq_user.last_be  = 8'b00001111;
          rq_data = {data[255:128], rq_desc, {4{32'h00000000}}, data[127:0]};
          rq_keep = {4'b1111, 4'b1111, 4'b0000, 4'b1111};
          fifo_index = 7;
          return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
        end
      end

      if (now_metadata.now_clocks_count_per_rq_tlp == 1) begin
        rq_desc.address = now_metadata.address[63:2];
        next_metadata.address = next_address;
        rq_desc.dword_count = max_payload_dwords;
        rq_user.is_sop      = 2'b01;
        rq_user.first_be = 8'b00001111;
        rq_user.last_be  = 8'b00001111;
        fifo_index = 11;
        rq_data = {data[383:0], rq_desc};
        rq_keep = {12'b111111111111, 4'b1111};
        return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
      end else if (now_metadata.now_clocks_count_per_rq_tlp == static_metadata.maximum_clocks_per_rq_tlp) begin
        rq_desc.address = now_metadata.address[63:2];
        next_metadata.address = next_address;
        rq_desc.dword_count = max_payload_dwords;
        rq_user.is_sop      = 2'b01;
        rq_user.is_sop_ptr[0] = 2'b10;
        rq_user.is_eop      = 2'b01;
        rq_user.is_eop_ptr[0] = 4'b0011;
        rq_user.first_be = 8'b00001111;
        rq_user.last_be  = 8'b00001111;
        fifo_index = 7;
        rq_data = {data[255:128], rq_desc, {4{32'h00000000}}, data[127:0]};
        rq_keep = {4'b1111, 4'b1111, 4'b0000, 4'b1111};
        return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
      end else begin
        fifo_index = 15;
        rq_data = data[511:0];
        rq_keep = {4'b1111, 4'b1111, 4'b1111, 4'b1111};
        return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
      end
    end begin // NOTE: Even
      if (now_metadata.now_rq_tlp_count == static_metadata.request_rq_tlp_count && now_metadata.now_clocks_count_per_rq_tlp == static_metadata.request_clocks_last_rq_tlp) begin
        rq_last = 1'b1;
        rq_user.is_eop      = 2'b01;
        rq_user.is_eop_ptr[0] = static_metadata.rq_user_is_eop0_ptr_by_last_clock;
        masked_data = data & static_metadata.rq_data_mask_by_last_clock;
        masked_keep = static_metadata.rq_data_keep_by_last_clock;
        rq_data = masked_data;
        rq_keep = masked_keep;
        fifo_index = static_metadata.fifo_index_by_last_clock;
        return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
      end

      if (now_metadata.now_clocks_count_per_rq_tlp == static_metadata.maximum_clocks_per_rq_tlp) begin
        rq_user.is_eop      = 2'b01;
        rq_user.is_eop_ptr[0] = 4'b1011;
        rq_data = {{4{32'h00000000}}, data[383:0]};
        rq_keep = {4'b0000, 4'b1111, 4'b1111, 4'b1111};
        fifo_index = 11;
        return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
      end else begin
        rq_data = data[511:0];
        rq_keep = {4'b1111, 4'b1111, 4'b1111, 4'b1111};
        fifo_index = 15;
        return {rq_data, rq_keep, rq_user, rq_last, next_metadata, fifo_index};
      end
    end

  endfunction

endmodule: dma_writer
