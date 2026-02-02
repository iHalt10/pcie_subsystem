`timescale 1ns / 1ps

module cc_switcher #(
  parameter int NUM_SLAVES = 2
) (
  pcie_axis_cc_if.slave  s_axis_cc[NUM_SLAVES],
  pcie_axis_cc_if.master m_axis_cc,
  input aclk,
  input areset
);

  wire [511:0] axis_tdata;
  wire [96:0]  axis_tuser; // NOTE: axis_cc.user[81] + axis_cc.keep[16] = 97
  wire         axis_tlast;
  wire         axis_tvalid;
  wire         axis_tready;

  wire [512*NUM_SLAVES-1:0] s_axis_tdata;
  wire [97*NUM_SLAVES-1:0]  s_axis_tuser;
  wire [NUM_SLAVES-1:0]     s_axis_tlast;
  wire [NUM_SLAVES-1:0]     s_axis_tvalid;
  wire [NUM_SLAVES-1:0]     s_axis_tready;

  wire aresetn;

  assign aresetn = ~areset;

  generate
    for (genvar i = 0; i < NUM_SLAVES; i++) begin
      assign s_axis_tdata[i * 512 +: 512] = s_axis_cc[i].data;
      assign s_axis_tuser[i *  97 +:  97] = {s_axis_cc[i].user, s_axis_cc[i].keep};
      assign s_axis_tlast[i]              = s_axis_cc[i].last;
      assign s_axis_tvalid[i]             = s_axis_cc[i].valid;
      assign s_axis_cc[i].ready           = {4{s_axis_tready[i]}};
    end
  endgenerate

  cc_switch cc_switch_inst (
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

  assign m_axis_cc.data  = axis_tdata;
  assign m_axis_cc.keep  = axis_tuser[15:0];
  assign m_axis_cc.user  = axis_tuser[96:16];
  assign m_axis_cc.last  = axis_tlast;
  assign m_axis_cc.valid = axis_tvalid;
  assign axis_tready     = m_axis_cc.ready[0];

endmodule: cc_switcher
