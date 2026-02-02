`timescale 1ns/1ps

module app_controller (
  pcie_axis_rq_if.master m_axis_rq[2],
  pcie_axis_rc_if.slave  s_axis_rc,

  pcie_cfg_status_if.slave cfg_status,

  dma_register_if.peripheral dma_address,
  doorbell_register_if.peripheral doorbell,

  input aclk,
  input areset
);

  // NOTE: 512 / 8 = 64 bytes = 16 dwords => 128 dwords => 8 clocks

  localparam int MAX_DATA_SIZE = 1024;
  localparam int TAG_COUNT = 1;
  localparam int TAG_INDEX = 0;

  typedef enum logic [2:0] {
    S_IDLE,
    S_READ,
    S_READ_CLEAR,
    S_READ_WAIT,
    S_WRITE,
    S_WRITING,
    S_WRITE_WAIT,
    S_DONE
  } state_t;

  state_t state;
  reg [3:0] count;
  reg [4095:0] data;

  dma_reader_if #(.MAX_DATA_SIZE(MAX_DATA_SIZE)) reader_bus();
  dma_reader #(
    .MAX_DATA_SIZE(MAX_DATA_SIZE),
    .TAG_COUNT(TAG_COUNT),
    .TAG_INDEX(TAG_INDEX)
  ) dma_reader_inst (
    .access_bus (reader_bus),
  
    .m_axis_rq (m_axis_rq[0]),
    .s_axis_rc (s_axis_rc),

    .cfg_max_payload  (cfg_status.cfg_max_payload),
    .cfg_max_read_req (cfg_status.cfg_max_read_req),

    .aclk   (aclk),
    .areset (areset)
  );

  dma_writer_if #(.MAX_DATA_SIZE(MAX_DATA_SIZE)) writer_bus();
  dma_writer #(
    .MAX_DATA_SIZE(MAX_DATA_SIZE)
  ) dma_writer_inst (
    .access_bus (writer_bus),

    .m_axis_rq (m_axis_rq[1]),

    .cfg_max_payload (cfg_status.cfg_max_payload),

    .aclk   (aclk),
    .areset (areset)
  );

  always_ff @(posedge aclk) begin
    if (areset) begin
      state <= S_IDLE;
      count <= '0;
      reader_bus.enable      <= '0;
      reader_bus.address     <= '0;
      reader_bus.dword_count <= '0;
      writer_bus.valid       <= '0;
      writer_bus.address     <= '0;
      writer_bus.data        <= '0;
      writer_bus.keep        <= '0;
      writer_bus.dword_count <= '0;
      doorbell.update_done <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          if (doorbell.update) begin
            state <= S_READ;
          end
        end

        S_READ: begin
          state <= S_READ_CLEAR;
          reader_bus.enable      <= 1'b1;
          reader_bus.address     <= dma_address.data;
          reader_bus.dword_count <= 'd128;
        end

        S_READ_CLEAR: begin
          state <= S_READ_WAIT;
          reader_bus.enable      <= '0;
          reader_bus.address     <= '0;
          reader_bus.dword_count <= '0;
        end

        S_READ_WAIT: begin
          if (reader_bus.done) begin
            state <= S_WRITE;
            data <= reader_bus.data[4095:0];
          end
        end

        S_WRITE: begin
          state <= S_WRITING;
          count <= 4'b1;
          writer_bus.valid       <= 1'b1;
          writer_bus.address     <= dma_address.data;
          writer_bus.data        <= calculate_data(data[count * 512 +: 512]);
          writer_bus.keep        <= 16'hFFFF;
          writer_bus.dword_count <= 'd128;
        end

        S_WRITING: begin
          if (writer_bus.ready) begin
            if (count == 4'b1000) begin
              state <= S_WRITE_WAIT;
              count <= '0;
              writer_bus.valid       <= '0;
              writer_bus.address     <= '0;
              writer_bus.data        <= '0;
              writer_bus.keep        <= '0;
              writer_bus.dword_count <= '0;
            end else begin
              count <= count + 4'b0001;
              writer_bus.data <= calculate_data(data[count * 512 +: 512]);
            end
          end
        end

        S_WRITE_WAIT: begin
          if (!writer_bus.busy) begin
            state <= S_DONE;
            doorbell.update_done <= 1'b1;
          end
        end

        S_DONE: begin
          state <= S_IDLE;
          doorbell.update_done <= 1'b0;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  function automatic logic [511:0] calculate_data(
    input logic [511:0] data
  );
    logic [511:0] new_data;
    for (int i = 0; i < 16; i++) begin
      new_data[i * 32 +: 32] = data[i * 32 +: 32] + 1;
    end
    return new_data;
  endfunction

endmodule: app_controller
