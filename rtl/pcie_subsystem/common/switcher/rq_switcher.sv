`timescale 1ns / 1ps

module rq_switcher #(
  parameter int NUM_SLAVES = 2
) (
  pcie_axis_rq_if.slave  s_axis_rq[NUM_SLAVES],
  pcie_axis_rq_if.master m_axis_rq,
  input aclk,
  input areset
);

  wire [511:0] axis_tdata;
  wire [152:0] axis_tuser; // NOTE: axis_rq.user[137] + axis_rq.keep[16] = 153
  wire         axis_tlast;
  wire         axis_tvalid;
  wire         axis_tready;

  wire [512*NUM_SLAVES-1:0] s_axis_tdata;
  wire [153*NUM_SLAVES-1:0] s_axis_tuser;
  wire [NUM_SLAVES-1:0]     s_axis_tlast;
  wire [NUM_SLAVES-1:0]     s_axis_tvalid;
  wire [NUM_SLAVES-1:0]     s_axis_tready;

  wire aresetn;

  assign aresetn = ~areset;

  generate
    for (genvar i = 0; i < NUM_SLAVES; i++) begin
      assign s_axis_tdata[i * 512 +: 512]  = s_axis_rq[i].data;
      assign s_axis_tuser[i * 153 +: 153]  = {s_axis_rq[i].user, s_axis_rq[i].keep};
      assign s_axis_tlast[i]               = s_axis_rq[i].last;
      assign s_axis_tvalid[i]              = s_axis_rq[i].valid;
      assign s_axis_rq[i].ready            = {4{s_axis_tready[i]}};
    end
  endgenerate

  rq_switch rq_switch_inst (
    .s_axis_tdata  (s_axis_tdata),
    .s_axis_tuser  (s_axis_tuser),
    .s_axis_tlast  (s_axis_tlast),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready),

    .m_axis_tdata  (axis_tdata),
    .m_axis_tuser  (axis_tuser),
    .m_axis_tlast  (axis_tlast),
    .m_axis_tvalid (axis_tvalid),
    .m_axis_tready (axis_tready),

    .aclk          (aclk),
    .aresetn       (aresetn),

    .s_req_suppress('0),
    .s_decode_err()
  );

  assign m_axis_rq.data  = axis_tdata;
  assign m_axis_rq.keep  = axis_tuser[15:0];
  assign m_axis_rq.user  = axis_tuser[152:16];
  assign m_axis_rq.last  = axis_tlast;
  assign m_axis_rq.valid = axis_tvalid;
  assign axis_tready     = m_axis_rq.ready[0];

endmodule: rq_switcher
