`timescale 1ns / 1ps

import pcie_pkg::REQUEST_MEM_READ;
import pcie_pkg::ADDRESS_TYPE_UNTRANSLATED;
import pcie_pkg::calculate_max_payload_dwords;
import pcie_pkg::calculate_address_by_max_read_req;
import pcie_rq_pkg::rq_mem_descriptor_t;
import pcie_rq_pkg::rq_user_t;
import pcie_rc_pkg::rc_tlp_t;
import pcie_rc_pkg::rc_descriptor_t;
import pcie_rc_pkg::calculate_index_by;
import pcie_rc_pkg::calculate_data_chunk_size;
import pcie_rc_pkg::calculate_max_dwords_per_rq_tlp;

module dma_reader #(
  parameter int MAX_DATA_SIZE     = 1024,
  parameter int MAX_DWORD_COUNT   = MAX_DATA_SIZE / 4,
  parameter int DWORD_COUNT_WIDTH = $clog2(MAX_DWORD_COUNT) + 1,
  parameter int DATA_WIDTH        = MAX_DATA_SIZE * 8,
  parameter int TAG_COUNT         = 1,
  parameter int TAG_INDEX         = 0
) (
  dma_reader_if.controller access_bus,

  pcie_axis_rq_if.master m_axis_rq,
  pcie_axis_rc_if.slave  s_axis_rc,

  input [1:0] cfg_max_payload,
  inout [2:0] cfg_max_read_req,

  input aclk,
  input areset
);

  localparam int RC_TLP_COUNT_WIDTH = $clog2(4096 / 128 * TAG_COUNT) + 1;
  localparam int RQ_TLP_COUNT_WIDTH = $clog2(MAX_DATA_SIZE / 128) + 1;
  localparam int BLOCK_COUNT_WIDTH  = $clog2(MAX_DATA_SIZE / 128) + 1;
  localparam int DATA_INDEX_WIDTH   = $clog2(MAX_DATA_SIZE / 128);
  localparam int RC_COUNT_WIDTH = BLOCK_COUNT_WIDTH;

  localparam int BLOCK_METADATA_WIDTH = BLOCK_COUNT_WIDTH + RC_TLP_COUNT_WIDTH;
  localparam int DYNAMIC_METADATA_WIDTH = BLOCK_METADATA_WIDTH + RQ_TLP_COUNT_WIDTH + 64 + 8;
  localparam int STATIC_METADATA_WIDTH = 2 + 11 + 11 + RC_TLP_COUNT_WIDTH + RC_TLP_COUNT_WIDTH;
  localparam int METADATA_ALL_WIDTH = DYNAMIC_METADATA_WIDTH + STATIC_METADATA_WIDTH;

  typedef struct packed {
    logic [1:0]  data_chunk_size;
    logic [10:0] max_dwords_per_rq_tlp;
    logic [10:0] last_dwords_per_rq_tlp;
    logic [RC_TLP_COUNT_WIDTH-1:0] rc_tlp_count_by_max_dwords;
    logic [RC_TLP_COUNT_WIDTH-1:0] rc_tlp_count_by_last_dwords;
  } static_metadata_t;

  typedef struct packed {
    logic [BLOCK_COUNT_WIDTH-1:0]  count;
    logic [RC_TLP_COUNT_WIDTH-1:0] rc_tlp_count;
  } block_metadata_t;

  typedef struct packed {
    block_metadata_t block;
    logic [RQ_TLP_COUNT_WIDTH-1:0] rq_tlp_count;
    logic [63:0]     address;
    logic [7:0]      tag;
  } dynamic_metadata_t;

  typedef enum logic [2:0] {
    S_IDLE,
    S_RQ_TLP_SEND_START,
    S_RQ_TLP_SEND_CONTINUE,
    S_RQ_TLP_SEND_END,
    S_RC_TLP_RECEIVE_WAIT,
    S_DONE
  } state_t;

  state_t state;
  dynamic_metadata_t metadata;
  dynamic_metadata_t next_metadata;
  static_metadata_t static_metadata;

  rc_tlp_t rc_tlp;
  logic rc_received;
  logic rc_received_all;

  pcie_axis_rq_if axis_rq ();

  data_buffer_if #(.DATA_SIZE(MAX_DATA_SIZE)) data_bus();
  assign data_bus.clear = (state == S_IDLE && access_bus.enable);
  assign data_bus.data_chunk_size = static_metadata.data_chunk_size;
  assign access_bus.data = data_bus.data;
  assign access_bus.keep = data_bus.keep;
  data_buffer #(
    .DATA_SIZE(MAX_DATA_SIZE)
  ) data_buffer_inst (
    .access_bus (data_bus),
    .aclk       (aclk),
    .areset     (areset)
  );

  always_ff @(posedge aclk) begin
    if (areset) begin
      data_bus.enable      <= '0;
      data_bus.index       <= '0;
      data_bus.payload     <= '0;
      data_bus.dword_count <= '0;
    end else begin
      if (rc_received) begin
        data_bus.enable      <= 1'b1;
        data_bus.index       <= calculate_data_index(rc_tlp.desc, metadata.block, static_metadata, cfg_max_payload, cfg_max_read_req);
        data_bus.payload     <= rc_tlp.payload[8191:0];
        data_bus.dword_count <= rc_tlp.desc.dword_count;
      end else begin
        data_bus.enable      <= '0;
        data_bus.index       <= '0;
        data_bus.payload     <= '0;
        data_bus.dword_count <= '0;
      end
    end
  end

  rc_counter_if #(.COUNT_WIDTH(RC_COUNT_WIDTH)) counter_bus();
  assign counter_bus.enable = (state == S_RQ_TLP_SEND_START);
  assign counter_bus.up = rc_received;
  assign counter_bus.max = metadata.block.rc_tlp_count;
  assign rc_received_all = counter_bus.is_max;
  rc_counter #(
    .COUNT_WIDTH(RC_COUNT_WIDTH)
  ) rc_counter_inst (
    .access_bus (counter_bus),
    .aclk       (aclk),
    .areset     (areset)
  );

  rc_receiver #(
    .TAG_COUNT(TAG_COUNT),
    .TAG_INDEX(TAG_INDEX)
  ) rc_receiver_inst (
    .s_axis_rc (s_axis_rc),
    .tlp       (rc_tlp),
    .received  (rc_received),
    .aclk      (aclk),
    .areset    (areset)
  );

  assign {
    axis_rq.data,
    axis_rq.keep,
    axis_rq.user,
    axis_rq.last,
    next_metadata
  } = (state == S_RQ_TLP_SEND_START || state == S_RQ_TLP_SEND_CONTINUE) ? generate_rq_packet_with_metadata(metadata, static_metadata, cfg_max_read_req) : '0;

  always_ff @(posedge aclk) begin
    if (areset) begin
      state <= S_IDLE;
      metadata <= '0;
      static_metadata <= '0;
      access_bus.busy <= '0;
      access_bus.done <= '0;
      access_bus.error <= '0;
      m_axis_rq.data <= '0;
      m_axis_rq.keep <= '0;
      m_axis_rq.last <= '0;
      m_axis_rq.user <= '0;
      m_axis_rq.valid <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          if (access_bus.enable) begin
            access_bus.busy <= 1'b1;
            if (access_bus.dword_count == '0 || access_bus.dword_count > MAX_DWORD_COUNT) begin
              state <= S_DONE;
              access_bus.done <= 1'b1;
              access_bus.error  <= 1'b1;
            end else begin
              state <= S_RQ_TLP_SEND_START;
              {static_metadata, metadata} <= initialize_metadata_all(access_bus.dword_count, access_bus.address, cfg_max_payload, cfg_max_read_req);
            end
          end
        end

        S_RQ_TLP_SEND_START: begin
          state <= (axis_rq.last) ? S_RQ_TLP_SEND_END : S_RQ_TLP_SEND_CONTINUE;
          metadata <= next_metadata;
          m_axis_rq.valid <= 1'b1;
          m_axis_rq.data <= axis_rq.data;
          m_axis_rq.keep <= axis_rq.keep;
          m_axis_rq.user <= axis_rq.user;
          m_axis_rq.last <= axis_rq.last;
        end

        S_RQ_TLP_SEND_CONTINUE: begin
          if (m_axis_rq.ready[0]) begin
            state <= (axis_rq.last) ? S_RQ_TLP_SEND_END : S_RQ_TLP_SEND_CONTINUE;
            metadata <= next_metadata;
            m_axis_rq.valid <= 1'b1;
            m_axis_rq.data <= axis_rq.data;
            m_axis_rq.keep <= axis_rq.keep;
            m_axis_rq.user <= axis_rq.user;
            m_axis_rq.last <= axis_rq.last;
          end
        end

        S_RQ_TLP_SEND_END: begin
          if (m_axis_rq.ready[0]) begin
            state <= S_RC_TLP_RECEIVE_WAIT;
            m_axis_rq.valid <= '0;
            m_axis_rq.data <= '0;
            m_axis_rq.keep <= '0;
            m_axis_rq.user <= '0;
            m_axis_rq.last <= '0;
          end
        end

        S_RC_TLP_RECEIVE_WAIT: begin
          if (rc_received_all) begin
            if (metadata.rq_tlp_count == 0) begin
              state <= S_DONE;
              access_bus.done <= 1'b1;
            end else begin
              state <= S_RQ_TLP_SEND_START;
              metadata <= next_block(metadata);
            end
          end
        end

        S_DONE: begin
          state <= S_IDLE;
          metadata <= '0;
          static_metadata  <= '0;
          access_bus.busy <= '0;
          access_bus.done <= '0;
          access_bus.error <= '0;
        end

        default: state <= S_IDLE;
      endcase
    end
  end


  function automatic logic [METADATA_ALL_WIDTH-1:0] initialize_metadata_all(
    input logic [DWORD_COUNT_WIDTH-1:0] dword_count,
    input logic [63:0] address,
    input logic [1:0] cfg_max_payload,
    input logic [2:0] cfg_max_read_req
  );
    dynamic_metadata_t metadata;
    static_metadata_t static_metadata;
    logic [10:0] max_payload_dwords = calculate_max_payload_dwords(cfg_max_payload);

    static_metadata.data_chunk_size             = calculate_data_chunk_size(cfg_max_payload, cfg_max_read_req);
    static_metadata.max_dwords_per_rq_tlp       = calculate_max_dwords_per_rq_tlp(cfg_max_read_req);
    static_metadata.last_dwords_per_rq_tlp      = calculate_last_dwords_per_rq_tlp(dword_count, static_metadata.max_dwords_per_rq_tlp);
    static_metadata.rc_tlp_count_by_max_dwords  = calculate_rc_tlp_count(static_metadata.max_dwords_per_rq_tlp, max_payload_dwords);
    static_metadata.rc_tlp_count_by_last_dwords = calculate_rc_tlp_count(static_metadata.last_dwords_per_rq_tlp, max_payload_dwords);

    metadata = '0;
    metadata.address = address;
    metadata.rq_tlp_count = calculate_rq_tlp_count(dword_count, static_metadata.max_dwords_per_rq_tlp);

    return {static_metadata, metadata};
  endfunction

  function automatic logic [10:0] calculate_last_dwords_per_rq_tlp(
    input logic [DWORD_COUNT_WIDTH-1:0] dword_count,
    input logic [10:0] max_dwords_per_rq_tlp
  );
    logic [10:0] remainder = dword_count % max_dwords_per_rq_tlp;
    if (remainder == 0) return max_dwords_per_rq_tlp;
    return remainder;
  endfunction

  function automatic logic [RC_TLP_COUNT_WIDTH-1:0] calculate_rc_tlp_count(
    input logic [10:0] dwords_per_rq_tlp,
    input logic [10:0] max_payload_dwords
  );
    logic [RC_TLP_COUNT_WIDTH-1:0] count = (dwords_per_rq_tlp + max_payload_dwords - 1) / max_payload_dwords;
    return count;
  endfunction

  function automatic logic [RQ_TLP_COUNT_WIDTH-1:0] calculate_rq_tlp_count(
    input logic [DWORD_COUNT_WIDTH-1:0] dword_count,
    input logic [10:0] max_dwords_per_rq_tlp
  );
    logic [RQ_TLP_COUNT_WIDTH-1:0] rq_tlp_count = (dword_count + max_dwords_per_rq_tlp - 1) / max_dwords_per_rq_tlp;
    return rq_tlp_count;
  endfunction


  function automatic logic [DATA_INDEX_WIDTH-1:0] calculate_data_index(
    input rc_descriptor_t desc,
    input block_metadata_t block,
    input static_metadata_t static_metadata,
    input logic [1:0] cfg_max_payload,
    input logic [2:0] cfg_max_read_req
  );
    logic [7:0] tag = desc.tag - TAG_INDEX;
    logic [DATA_INDEX_WIDTH-1:0] x = block.count * TAG_COUNT  * static_metadata.rc_tlp_count_by_max_dwords;
    logic [DATA_INDEX_WIDTH-1:0] y =            tag           * static_metadata.rc_tlp_count_by_max_dwords;
    logic [DATA_INDEX_WIDTH-1:0] z = calculate_index_by(desc.lower_address, cfg_max_payload, cfg_max_read_req);
    return x + y + z;
  endfunction


  function automatic dynamic_metadata_t next_block(
    input dynamic_metadata_t metadata
  );
    metadata.tag = '0;
    metadata.block.rc_tlp_count = '0;
    metadata.block.count = metadata.block.count + 1;
    return metadata;
  endfunction


  function automatic logic [(DYNAMIC_METADATA_WIDTH + 666) - 1:0] generate_rq_packet_with_metadata(
    input dynamic_metadata_t now_metadata,
    input static_metadata_t static_metadata,
    input logic [2:0] cfg_max_read_req
  );
    // rq_data[512] + rq_keep[16] + rq_user[137] + rq_last[1] + DYNAMIC_METADATA_WIDTH
    dynamic_metadata_t next_metadata;
    rq_mem_descriptor_t desc = '0;
    rq_user_t           user = '0;
    logic [511:0]       data = '0;
    logic [15:0]        keep = '0;
    logic               last = '0;

    next_metadata = now_metadata;

    for (int i = 0; i <= 1; i++) begin
      desc.request_type = REQUEST_MEM_READ;
      desc.address_type = ADDRESS_TYPE_UNTRANSLATED;
      desc.address      = now_metadata.address[63:2];
      desc.tag          = now_metadata.tag + TAG_INDEX;
  
      user.is_sop[i]     = 1'b1;
      user.is_sop_ptr[i] = {i, 1'b0};
      user.is_eop[i]     = 1'b1;
      user.is_eop_ptr[i] = {i, 3'b011};

      keep[i * 8 +: 8] = 8'h0F;

      user.first_be[i * 4 +: 4] = 4'b1111;

      if (now_metadata.rq_tlp_count == 1) begin
        user.last_be[i * 4 +: 4] = (static_metadata.last_dwords_per_rq_tlp == 1) ? 4'b0000 : 4'b1111;
        desc.dword_count = static_metadata.last_dwords_per_rq_tlp;
        next_metadata.block.rc_tlp_count = now_metadata.block.rc_tlp_count + static_metadata.rc_tlp_count_by_last_dwords;
      end else begin
        user.last_be[i * 4 +: 4] = 4'b1111;
        desc.dword_count = static_metadata.max_dwords_per_rq_tlp;
        next_metadata.block.rc_tlp_count = now_metadata.block.rc_tlp_count + static_metadata.rc_tlp_count_by_max_dwords;
      end

      next_metadata.tag          = now_metadata.tag + 1;
      next_metadata.rq_tlp_count = now_metadata.rq_tlp_count - 1;
      next_metadata.address      = calculate_address_by_max_read_req(now_metadata.address, 1, cfg_max_read_req);

      data[i * 256 +: 256] = {128'b0, desc};

      if (now_metadata.rq_tlp_count == 1 || now_metadata.tag == TAG_COUNT - 1) begin
        last = 1'b1;
        break;
      end

      now_metadata = next_metadata;
    end

    return {data, keep, user, last, next_metadata};
  endfunction

endmodule: dma_reader
