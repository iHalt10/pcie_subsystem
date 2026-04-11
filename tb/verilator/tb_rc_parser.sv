`timescale 1ns / 1ps

// ============================================================================
//  tb_rc_parser.sv  —  Comprehensive testbench for rc_parser
//
//  TIMING CONTRACT  (read this before adding tests):
//
//    start_beat()  drives inputs at @(negedge), then waits #1 so that
//                  combinational outputs settle.  CHECK OUTPUTS HERE,
//                  between start_beat() and end_beat().
//
//    end_beat()    advances to @(posedge) so the FF (c register) latches
//                  the new state, then deasserts valid at the next negedge.
//
//    Always pair every start_beat() with one end_beat().
//
//  DATA LAYOUT REMINDER:
//    Lane 0 = data[127:0]    eop_ptr 0-3
//    Lane 1 = data[255:128]  eop_ptr 4-7
//    Lane 2 = data[383:256]  eop_ptr 8-11
//    Lane 3 = data[511:384]  eop_ptr 12-15
//
//  ARRAY LITERAL ENCODING for make_user():
//    '{a, b, c, d}  means  [3]=a, [2]=b, [1]=c, [0]=d
//    Example: '{2'b11, 2'b10, 2'b01, 2'b00}
//             -> sop_ptr[3]=3, sop_ptr[2]=2, sop_ptr[1]=1, sop_ptr[0]=0
//
//  EOP SLOT RULES (ordinal, not physical lanes):
//    is_eop[N] = "Nth EOP event this beat"  (filled from 0 upward)
//    When c.enabled=1: is_eop[0] is taken by the finishing big TLP.
//                      New TLPs use is_eop[1], [2], [3] respectively.
//    When c.enabled=0: New TLPs start from is_eop[0].
//
//  make_data() USAGE:
//    Each lane argument is 128 bits 
//
// ### Single-beat completions (tlp_0/1/2/3 outputs)
// **G1** — SOP@lane0, all four `eop_ptr` boundaries (ptr=3, 7, 11, 15)
// **G2** — Maximum straddle: four TLPs in one beat (all four enable outputs assert simultaneously)
// **G9** — SOP at lane 3 only via `is_sop[3]` (exercises the `tlp_3` block directly)
// **G11** — Straddle: TLP0@lane0 + TLP1@lane1, both single-beat
// **G12** — `tlp_1` block: `sop_ptr[1]=01`, `is_eop[1]` direct path (no ternary branch)
// **G13** — G13 — TLP_0 at lane 1 (sop_ptr[0]=01), c.enabled=0
// **G14** — TLP_0@lane1 (`sop_ptr[0]=01`), `c.enabled=0`: ternary picks `is_eop[0]`
// **G15** — TLP_0@lane2 (`sop_ptr[0]=10`), `c.enabled=0`, ends at lane 2
// **G16** — TLP_0@lane3 (`sop_ptr[0]=11` in `tlp_0` block)
// **G18** — Three TLPs in one beat: TLP_0@L0 + TLP_1@L1 + TLP_2@L2
//
//			### Multi-beat TLP reassembly (tlp output + c register)
// **G3** — Two-beat TLP: `c.enabled` set on beat 0, cleared on beat 1
// **G4** — Three-beat TLP: `c.index` increments by 4 per middle beat, data verified at all offsets
// **G17** — TLP_0@lane1 continues: verifies `c` saves lanes 1–3, then reassembles correctly
// **G21** (task `test_g21`) — Four-beat TLP: `c.index` reaches 12 on the final beat
// **G22** (task `test_g22`) — Back-to-back multi-beat TLPs with no idle cycle between them

//			### c.enabled=1 straddle scenarios (big TLP ends + new TLPs start in same beat)
// **G5** — Continuing TLP ends + new TLP starts in the same beat
// **G19** — `c.enabled=1`: big ends@L0 + new TLP_0@L2 (ternary picks `is_eop[1]`)
// **G20** — `c.enabled=1`: big ends + TLP_0@L1 + TLP_1@L2 (B3 scenario)
// **G21** (task `test_g20`) — `c.enabled=1`: big ends + TLP_0@L1 + TLP_1@L2 + TLP_2@L3 (B4 max — 5 outputs fire simultaneously)

//			### Edge cases and protocol behavior
// **G6** — `areset` asserted mid-packet: verifies `c` flushes and no stale `tlp_enable` fires after reset
// **G7** — `valid` de-assertion (back-pressure) mid-packet: `c` state preserved across idle cycles
// **G8** — `discontinue` flag: documents that `rc_parser` does not clear `c.enabled` on discontinue (design gap noted in test output)
// **G10** — `valid=0`: verifies no spurious enable outputs fire when bus is idle

//			### Continuous assertion (SVA-style)
//  An `always @(posedge aclk)` block runs throughout the entire simulation and flags a `[SVA-FAIL]` error 	
//	if any `tlp_enable*` signal asserts while `s_axis_rc_valid=0`.

//          ### Design Notes 

// Timing contract:** `start_beat()` drives inputs at `@(negedge)` then waits `#1` for combinational outputs to settle.
//		 Checks are placed between `start_beat()` and `end_beat()`. `end_beat()` advances to `@(posedge)` so the `c` register latches	
//		 then deasserts `valid`.

//         ###  Data layout
//
//  Each lane argument to `make_data()` is 128 bits mapping directly to `data[127:0]`, `data[255:128]`, `data[383:256]`, `data[511:384]`.
//	Unique per-lane fill patterns (e.g. `{16{8'hA0}}` vs `{16{8'hA1}}`) are used 


////////////////////////////////// Design GAP //////////////////////////////////////////

//  G8 / discontinue:** `rc_parser` does not implement discontinue handling — the `c.enabled` register is not cleared when `discontinue` is asserted.
//	This is noted in the test output as a design gap, not a testbench failure.

//  Clock: 100 MHz (period = 10 ns)
// ============================================================================


import pcie_rc_pkg::*;
import pcie_pkg::*;

module tb_rc_parser;

  // ==========================================================================
  // Clock / Reset
  // ==========================================================================
  logic aclk  = 0;
  logic areset = 1;
  always #5 aclk = ~aclk;

  // ==========================================================================
  // DUT ports
  // ==========================================================================
  logic [511:0] s_axis_rc_data  = '0;
  rc_user_t     s_axis_rc_user  = '0;
  logic         s_axis_rc_last  = '0;
  logic         s_axis_rc_valid = '0;

  rc_tlp_t   tlp;
  rc_tlp_0_t tlp_0;
  rc_tlp_1_t tlp_1;
  rc_tlp_2_t tlp_2;
  rc_tlp_3_t tlp_3;
  logic tlp_enable, tlp_enable_0, tlp_enable_1, tlp_enable_2, tlp_enable_3;

  // ==========================================================================
  // DUT
  // ==========================================================================
  rc_parser dut (.*);

  // ==========================================================================
  // Scoreboard
  // ==========================================================================
  int pass_count = 0;
  int fail_count = 0;

  task automatic chk(input string name, input logic cond);
    if (cond) begin
      $display("    [PASS] %s", name);
      pass_count++;
    end else begin
      $error("    [FAIL] %s  (time=%0t)", name, $time);
      fail_count++;
    end
  endtask

  // ==========================================================================
  // do_reset — holds areset for 4 cycles then releases
  // ==========================================================================
  task automatic do_reset();
    areset = 1;
    repeat(4) @(posedge aclk);
    @(negedge aclk); areset = 0;
    @(posedge aclk); // settle
  endtask

  // ==========================================================================
  // idle — inserts quiet cycles between tests (keeps waveforms readable)
  // ==========================================================================
  task automatic idle(int n = 2);
    repeat(n) @(posedge aclk);
  endtask

  // ==========================================================================
  // make_user — builds the rc_user_t sideband struct
  // ==========================================================================
  function automatic rc_user_t make_user(
    input logic [3:0]      is_sop,
    input logic [3:0][1:0] is_sop_ptr,
    input logic [3:0]      is_eop,
    input logic [3:0][3:0] is_eop_ptr,
    input logic            disc = 0
  );
    rc_user_t u = '0;
    u.is_sop      = is_sop;
    u.is_sop_ptr  = is_sop_ptr;
    u.is_eop      = is_eop;
    u.is_eop_ptr  = is_eop_ptr;
    u.discontinue = disc;
    return u;
  endfunction

  // ==========================================================================
  // make_data — assembles a 512-bit bus from four 128-bit lane values.
  //
  //   Each argument directly provides the 128-bit content for that lane:
  //     Lane 0 -> data[127:0]
  //     Lane 1 -> data[255:128]
  //     Lane 2 -> data[383:256]
  //     Lane 3 -> data[511:384]
  //
  // ==========================================================================
  function automatic logic [511:0] make_data(
    input logic [127:0] lane0,
    input logic [127:0] lane1,
    input logic [127:0] lane2,
    input logic [127:0] lane3
  );
    logic [511:0] d;
    d[127:0]   = lane0;
    d[255:128] = lane1;
    d[383:256] = lane2;
    d[511:384] = lane3;
    return d;
  endfunction


  // ==========================================================================
  // start_beat — drives the bus, waits 1ns for combinational to settle
  //              CHECK OUTPUT SIGNALS after this call returns
  // ==========================================================================
  task automatic start_beat(
    input logic [511:0] data,
    input rc_user_t     user,
    input logic         last = 0
  );
    @(negedge aclk);
    s_axis_rc_valid = 1;
    s_axis_rc_data  = data;
    s_axis_rc_user  = user;
    s_axis_rc_last  = last;
    #1; // combinational outputs settle here
  endtask

  // ==========================================================================
  // end_beat — clocks the FF (c register updates), then deasserts valid
  // ==========================================================================
  task automatic end_beat();
    @(posedge aclk);  // c register latches here
    @(negedge aclk);
    s_axis_rc_valid =  0;
    s_axis_rc_user  = '0;
    s_axis_rc_data  = '0;
    s_axis_rc_last  =  0;
  endtask


  // ============================================================================
  //  G1 — Single-beat TLP at lane 0, all four eop_ptr boundaries
  // ============================================================================
  task automatic test_g1();
    logic [511:0]   data;
    rc_user_t       user;

    $display("\n  [G1] Single-beat TLP at lane 0 — all eop_ptr boundaries");

   
    // Lane 0 holds the descriptor; other lanes carry distinct fill so cross-wiring is visible
    data = make_data(
      {16{8'hB0}},   		   // lane 0: 0xB0 fill
      {16{8'hB1}},             // lane 1: 0xB1 fill
      {16{8'hB2}},             // lane 2: 0xB2 fill
      {16{8'hB3}}              // lane 3: 0xB3 fill
    );

    user = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b00},
      4'b0001, '{4'd0,  4'd0,  4'd0,  4'd3}
    );

    // eop_ptr=3: only lane 0 valid
    start_beat(data, user);
    chk("G1.1 eop_ptr= 3  enable_0 asserts",   tlp_enable_0);
    chk("G1.1 eop_ptr= 3  enable silent",      !tlp_enable);
    end_beat();

    // eop_ptr=7: lanes 0-1 valid
    user.is_eop_ptr[0] = 4'd7;
    start_beat(data, user);
    chk("G1.2 eop_ptr= 7  enable_0 asserts",   tlp_enable_0);
    chk("G1.2 eop_ptr= 7  lane1 copied",        tlp_0[255:128] === data[255:128]);
    end_beat();

    // eop_ptr=11: lanes 0-2 valid
    user.is_eop_ptr[0] = 4'd11;
    start_beat(data, user);
    chk("G1.3 eop_ptr=11  enable_0 asserts",   tlp_enable_0);
    end_beat();

    // eop_ptr=15: full beat, all 4 lanes
    user.is_eop_ptr[0] = 4'd15;
    start_beat(data, user);
    chk("G1.4 eop_ptr=15  enable_0 asserts",   tlp_enable_0);
    chk("G1.4 eop_ptr=15  full data matches",   tlp_0[511:0] === data[511:0]);
    chk("G1.4 eop_ptr=15  no spurious 1/2/3",
        !(tlp_enable_1 | tlp_enable_2 | tlp_enable_3));
    end_beat();
  endtask


  // ============================================================================
  //  G2 — Four TLPs in one beat (maximum straddle, c.enabled=0)
  // ============================================================================
  task automatic test_g2();
    rc_user_t       user;
    logic [511:0]   data;

    $display("\n  [G2] Four TLPs in one beat — maximum straddle");

    data = make_data(
      {16{8'hA0}},   		 // lane 0: 0xA0 fill
      {16{8'hA1}},   		 // lane 1: 0xA1 fill
      {16{8'hA2}},  		 // lane 2: 0xA2 fill
      {16{8'hA3}}   		 // lane 3: 0xA3 fill
    );

    user = make_user(
      4'b1111,
      '{2'b11, 2'b10, 2'b01, 2'b00},
      4'b1111,
      '{4'd15, 4'd11, 4'd7,  4'd3}
    );

    start_beat(data, user);
    chk("G2  enable_0 asserts",    tlp_enable_0);
    chk("G2  enable_1 asserts",    tlp_enable_1);
    chk("G2  enable_2 asserts",    tlp_enable_2);
    chk("G2  enable_3 asserts",    tlp_enable_3);
    chk("G2  no multi-beat tlp",  !tlp_enable);
    end_beat();
  endtask


  // ============================================================================
  //  G3 — Two-beat TLP (c.enabled set then cleared)
  // ============================================================================
  task automatic test_g3();
    logic [511:0]   data0, data1;
    rc_user_t       u0, u1;
  

    $display("\n  [G3] Two-beat TLP — c.enabled set then cleared");

    data0 = make_data(
      {16{8'hC0}},   		   // lane 0
      {16{8'hC1}},             // lane 1
      {16{8'hC2}},             // lane 2
      {16{8'hC3}}              // lane 3
    );
    // Beat 1: entirely new payload, all lanes distinct
    data1 = make_data(
      {16{8'hD0}},
      {16{8'hD1}},
      {16{8'hD2}},
      {16{8'hD3}}
    );

    u0 = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b00},
      4'b0000, '{4'd0,  4'd0,  4'd0,  4'd0}
    );
    u1 = make_user(
      4'b0000, '{2'b00, 2'b00, 2'b00, 2'b00},
      4'b0001, '{4'd0,  4'd0,  4'd0,  4'd7}
    );

    start_beat(data0, u0);
    chk("G3  beat0: no tlp_enable",    !tlp_enable);
    chk("G3  beat0: no tlp_enable_0",  !tlp_enable_0);
    end_beat();

    start_beat(data1, u1);
    chk("G3  beat1: tlp_enable asserts",      tlp_enable);
    chk("G3  beat1: no tlp_enable_0",        !tlp_enable_0);
    chk("G3  beat0 data lives in tlp[511:0]", tlp[511:0] === data0);
    end_beat();
  endtask


  // ============================================================================
  //  G4 — Three-beat TLP (c.index increments by 4 each middle beat)
  // ============================================================================
  task automatic test_g4();
    logic [511:0] data[3];
    rc_user_t     u[3];

    $display("\n  [G4] Three-beat TLP — c.index increments per beat");

    // Each beat has a unique fill pattern per lane so index bugs are obvious
    data[0] = make_data({16{8'h10}}, {16{8'h11}}, {16{8'h12}}, {16{8'h13}});
    data[1] = make_data({16{8'h20}}, {16{8'h21}}, {16{8'h22}}, {16{8'h23}});
    data[2] = make_data({16{8'h30}}, {16{8'h31}}, {16{8'h32}}, {16{8'h33}});

    u[0] = make_user(4'b0001, '{2'b00,2'b00,2'b00,2'b00},
                     4'b0000, '{4'd0, 4'd0, 4'd0, 4'd0});
    u[1] = make_user(4'b0000, '{2'b00,2'b00,2'b00,2'b00},
                     4'b0000, '{4'd0, 4'd0, 4'd0, 4'd0});
    u[2] = make_user(4'b0000, '{2'b00,2'b00,2'b00,2'b00},
                     4'b0001, '{4'd0, 4'd0, 4'd0, 4'd15});

    start_beat(data[0], u[0]);
    chk("G4  beat0: no output", !tlp_enable);
    end_beat();

    start_beat(data[1], u[1]);
    chk("G4  beat1: no output", !tlp_enable);
    end_beat();

    start_beat(data[2], u[2]);
    chk("G4  beat2: tlp_enable asserts",        tlp_enable);
    chk("G4  beat0 data at tlp[511:0]",         tlp[511:0]     === data[0]);
    chk("G4  beat1 data at tlp[1023:512]",      tlp[1023:512]  === data[1]);
    chk("G4  beat2 data at tlp[1535:1024]",     tlp[1535:1024] === data[2]);
    end_beat();
  endtask


  // ============================================================================
  //  G5 — Continuing TLP ends + new TLP starts in the SAME beat
  // ============================================================================
  task automatic test_g5();
    logic [511:0] data[2];
    rc_user_t     u[2];

    $display("\n  [G5] Continuing TLP ends + new TLP starts in same beat");

    data[0] = make_data({16{8'hA0}}, {16{8'hA1}}, {16{8'hA2}}, {16{8'hA3}});
    data[1] = make_data({16{8'hB0}}, {16{8'hB1}}, {16{8'hB2}}, {16{8'hB3}});

    u[0] = make_user(4'b0001, '{2'b00,2'b00,2'b00,2'b00},
                     4'b0000, '{4'd0, 4'd0, 4'd0, 4'd0});

    u[1] = make_user(
      4'b0010,
      '{2'b00, 2'b00, 2'b01, 2'b00},
      4'b0011,
      '{4'd0,  4'd0,  4'd7,  4'd3}
    );

    start_beat(data[0], u[0]);
    chk("G5  beat0: no output",  !tlp_enable & !tlp_enable_1);
    end_beat();

    start_beat(data[1], u[1]);
    chk("G5  beat1: tlp_enable   (TLP-A done)",   tlp_enable);
    chk("G5  beat1: tlp_enable_1 (TLP-B done)",   tlp_enable_1);
    chk("G5  beat1: no spurious tlp_enable_0",   !tlp_enable_0);
    chk("G5  beat1: no spurious tlp_enable_2",   !tlp_enable_2);
    end_beat();
  endtask


  // ============================================================================
  //  G6 — areset asserted mid-packet
  // ============================================================================
  task automatic test_g6();
    rc_user_t     u;
    logic [511:0] data;

    $display("\n  [G6] areset asserted mid-packet — c must flush");

    data = make_data({16{8'hCC}}, {16{8'hCD}}, {16{8'hCE}}, {16{8'hCF}});

    u = make_user(4'b0001, '{2'b00,2'b00,2'b00,2'b00},
                  4'b0000, '{4'd0, 4'd0, 4'd0, 4'd0});
    start_beat(data, u);
    end_beat();

    @(negedge aclk); areset = 1;
    repeat(3) @(posedge aclk);
    @(negedge aclk); areset = 0;
    @(posedge aclk);

    u = make_user(4'b0000, '{2'b00,2'b00,2'b00,2'b00},
                  4'b0001, '{4'd0, 4'd0, 4'd0, 4'd7});
    start_beat(data, u);
    chk("G6  no stale tlp_enable after reset", !tlp_enable);
    end_beat();
  endtask


  // ============================================================================
  //  G7 — valid de-assertion (back-pressure) mid-packet
  // ============================================================================
  task automatic test_g7();
    rc_user_t     u;
    logic [511:0] d0, d1;

    $display("\n  [G7] valid gap (back-pressure) mid-packet");

    d0 = make_data({16{8'hD0}}, {16{8'hD1}}, {16{8'hD2}}, {16{8'hD3}});
    d1 = make_data({16{8'hE0}}, {16{8'hE1}}, {16{8'hE2}}, {16{8'hE3}});

    u = make_user(4'b0001, '{2'b00,2'b00,2'b00,2'b00},
                  4'b0000, '{4'd0, 4'd0, 4'd0, 4'd0});
    start_beat(d0, u); end_beat();

    idle(3);

    u = make_user(4'b0000, '{2'b00,2'b00,2'b00,2'b00},
                  4'b0001, '{4'd0, 4'd0, 4'd0, 4'd3});
    start_beat(d1, u);
    chk("G7  tlp_enable asserts after gap", tlp_enable);
    chk("G7  beat0 data preserved",         tlp[511:0] === d0);
    end_beat();
  endtask


  // ============================================================================
  //  G8 — discontinue flag (behavior documentation)
  // ============================================================================
  task automatic test_g8();
    rc_user_t     u;
    logic [511:0] data;

    $display("\n  [G8] discontinue flag — behavior documentation");

    data = make_data({16{8'hFF}}, {16{8'hFE}}, {16{8'hFD}}, {16{8'hFC}});

    u = make_user(4'b0001, '{2'b00,2'b00,2'b00,2'b00},
                  4'b0000, '{4'd0, 4'd0, 4'd0, 4'd0});
    start_beat(data, u); end_beat();

    u            = '0;
    u.discontinue = 1;
    start_beat(data, u);
    chk("G8  no tlp_enable when only discontinue set", !tlp_enable);
    $display("    [NOTE] c.enabled is NOT cleared by discontinue (design gap)");
    end_beat();
	do_reset();
  endtask


  // ============================================================================
  //  G9 — SOP at lane 3 only (tlp_3 block, is_sop[3]=1)
  // ============================================================================
  task automatic test_g9();
    rc_user_t       u;
    logic [511:0]   data;
 

    $display("\n  [G9] SOP at lane 3 via is_sop[3] — tlp_3 block");

    data = make_data(
      {16{8'h90}},             // lane 0: distinct, must not appear in tlp_3
      {16{8'h91}},             // lane 1
      {16{8'h92}},             // lane 2
      {16{8'h93}}    		   // lane 3
    );

    u = make_user(
      4'b1000, '{2'b11, 2'b00, 2'b00, 2'b00},
      4'b1000, '{4'd15, 4'd0,  4'd0,  4'd0}
    );

    start_beat(data, u);
    chk("G9  enable_3 asserts",              tlp_enable_3);
    chk("G9  no enable_0/1/2",              !(tlp_enable_0|tlp_enable_1|tlp_enable_2));
    chk("G9  no multi-beat tlp",            !tlp_enable);
    chk("G9  tlp_3 data from lane 3",        tlp_3[127:0]   === data[511:384]);
    end_beat();
  endtask


  // ============================================================================
  //  G10 — valid=0: no spurious enables
  // ============================================================================
  task automatic test_g10();
    $display("\n  [G10] valid=0 — all enables must stay silent");

    @(negedge aclk);
    s_axis_rc_valid = 0;
    s_axis_rc_data  = make_data({16{8'hFF}}, {16{8'hEE}}, {16{8'hDD}}, {16{8'hCC}});
    s_axis_rc_user = make_user(
      4'b0001, '{2'b00,2'b00,2'b00,2'b00},
      4'b0001, '{4'd0, 4'd0, 4'd0, 4'd3}
    );
    #1;

    chk("G10  no enable_0 when valid=0",  !tlp_enable_0);
    chk("G10  no enable   when valid=0",  !tlp_enable);

    @(negedge aclk);
    s_axis_rc_user = '0;
    s_axis_rc_data = '0;
  endtask


  // ============================================================================
  //  G11 — Straddle: TLP0@lane0 + TLP1@lane1, both single-beat
  // ============================================================================
  task automatic test_g11();
    rc_user_t       u;
    logic [511:0]   data;
  

    $display("\n  [G11] Straddle: TLP0@lane0 + TLP1@lane1, single-beat each");

   
    data = make_data(
      {16{8'hAA}},   		 // lane 0
      {16{8'hBB}},   		 // lane 1
      {16{8'hEE}},           // lane 2: 
      {16{8'hFF}}            // lane 3: 
    );

    u = make_user(
      4'b0011, '{2'b00, 2'b00, 2'b01, 2'b00},
      4'b0011, '{4'd0,  4'd0,  4'd7,  4'd3}
    );

    start_beat(data, u);
    chk("G11  enable_0 asserts",      tlp_enable_0);
    chk("G11  enable_1 asserts",      tlp_enable_1);
    chk("G11  no enable_2/3",        !(tlp_enable_2|tlp_enable_3));
    end_beat();
  endtask


  // ============================================================================
  //  G12 — tlp_1 block: sop_ptr[1]=01, is_eop[1] direct (no ternary)
  // ============================================================================
  task automatic test_g12();
    rc_user_t       u;
    logic [511:0]   data;
  

    $display("\n  [G12] tlp_1 block: sop_ptr=01, is_eop[1] direct (no ternary)");

    data = make_data(
      {16{8'h1A}},           // lane 0: no SOP here, filler
      {16{8'h1B}},   		 // lane 1
      {16{8'h1C}},           // lane 2
      {16{8'h1D}}            // lane 3
    );

    u = make_user(
      4'b0010, '{2'b00,2'b00,2'b01,2'b00},
      4'b0010, '{4'd0, 4'd0, 4'd7, 4'd0}
    );

    start_beat(data, u);
    chk("G12  enable_1 asserts",      tlp_enable_1);
    chk("G12  no enable_0",          !tlp_enable_0);
    end_beat();
  endtask




  // ============================================================================
  //  G13 — TLP_0 at lane 1 (sop_ptr[0]=01), c.enabled=0
  // ============================================================================
  task automatic test_g13();
    rc_user_t       u;
    logic [511:0]   data;
    
    $display("\n  [G13] TLP_0@lane1 (sop_ptr[0]=01), c.enabled=0 — ternary picks is_eop[0]");

    data = make_data(
      {16{8'hAA}},             // lane 0: no SOP
      {16{8'hBB}},    		   // lane 1
      {16{8'hCC}},             // lane 2
      {16{8'hDD}}              // lane 3
    );

    u = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b01},
      4'b0001, '{4'd0,  4'd0,  4'd0,  4'd7}
    );

    start_beat(data, u);
    chk("G13  tlp_enable_0 asserts",          tlp_enable_0);
    chk("G13  no other enables",
        !(tlp_enable | tlp_enable_1 | tlp_enable_2 | tlp_enable_3));
    chk("G13  tlp_0 data pulled from lane 1",  tlp_0[127:0] === data[255:128]);
    end_beat();
  endtask


  // ============================================================================
  //  G14 — TLP_0 at lane 2 (sop_ptr[0]=10), c.enabled=0, ends at lane 2
  // ============================================================================
  task automatic test_g14();
    rc_user_t       u;
    logic [511:0]   data;
  

    $display("\n  [G14] TLP_0@lane2 (sop_ptr[0]=10), c.enabled=0, ends at lane 2");

    data = make_data(
      {16{8'h15}},             // lane 0
      {16{8'h25}},             // lane 1
      {16{8'h35}},   		   // lane 2
      {16{8'h45}}              // lane 3
    );

    u = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b10},
      4'b0001, '{4'd0,  4'd0,  4'd0,  4'd11}
    );

    start_beat(data, u);
    chk("G14  tlp_enable_0 asserts",          tlp_enable_0);
    chk("G14  no other enables",
        !(tlp_enable | tlp_enable_1 | tlp_enable_2 | tlp_enable_3));
    chk("G14  tlp_0 data pulled from lane 2",  tlp_0[127:0] === data[383:256]);
    end_beat();
  endtask


  // ============================================================================
  //  G15 — TLP_0 at lane 3 via sop_ptr[0]=11 in the tlp_0 block
  // ============================================================================
  task automatic test_g15();
    rc_user_t       u;
    logic [511:0]   data;
   

    $display("\n  [G15] TLP_0@lane3 via sop_ptr[0]=11 (tlp_0 block) ");

    data = make_data(
      {16{8'h60}},             // lane 0
      {16{8'h61}},             // lane 1
      {16{8'h62}},             // lane 2
      {16{8'h63}}     		   // lane 3
    );

    u = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b11},
      4'b0001, '{4'd0,  4'd0,  4'd0,  4'd15}
    );

    start_beat(data, u);
    chk("G15  tlp_enable_0 asserts",          tlp_enable_0);
    chk("G15  no other enables",
        !(tlp_enable | tlp_enable_1 | tlp_enable_2 | tlp_enable_3));
		
    chk("G15  tlp_0 data pulled from lane 3",  tlp_0[127:0] === data[511:384]);
    end_beat();
  endtask


  // ============================================================================
  //  G16 — TLP_0 at lane 1, does NOT end beat 0 — verify c save & reassembly
  // ============================================================================
  task automatic test_g16();
    logic [511:0]   data0, data1;
	rc_user_t       u0, u1;

    $display("\n  [G16] TLP_0@lane1 continues — verify c save (lanes 1-3) then reassembly");


    data0 = make_data(
      {16{8'hAA}},             // lane 0: no SOP, not saved into c
      {16{8'hBB}},   		   // lane 1: 				   -> saved as c.data[127:0]
      {128{1'b1}},             // lane 2: all-1s           -> saved as c.data[255:128]
      128'h0                   // lane 3: all-0s           -> saved as c.data[383:256]
    );
    data1 = make_data(
      {16{8'hBE}},   // lane 0 of beat 1: appended at c.index=3 -> tlp[511:384]
      {16{8'hBF}},
      {16{8'hC0}},
      {16{8'hC1}}
    );

    u0 = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b01},
      4'b0000, '{4'd0,  4'd0,  4'd0,  4'd0}
    );
    u1 = make_user(
      4'b0000, '{2'b00, 2'b00, 2'b00, 2'b00},
      4'b0001, '{4'd0,  4'd0,  4'd0,  4'd3}
    );

    start_beat(data0, u0);
    chk("G16  beat0: no tlp_enable",    !tlp_enable);
    chk("G16  beat0: no tlp_enable_0",  !tlp_enable_0);
    end_beat();

    start_beat(data1, u1);
    chk("G16  beat1: tlp_enable asserts",       tlp_enable);
    chk("G16  beat1: no spurious enable_0",    !tlp_enable_0);
    chk("G16  beat0 lane1 -> tlp[127:0]",       tlp[127:0]   === data0[255:128]);
    chk("G16  beat0 lane2 -> tlp[255:128]",     tlp[255:128] === data0[383:256]);
    chk("G16  beat0 lane3 -> tlp[383:256]",     tlp[383:256] === data0[511:384]);
    chk("G16  beat1 lane0 -> tlp[511:384]",     tlp[511:384] === data1[127:0]);
    end_beat();
  endtask


  // ============================================================================
  //  G17 — Three TLPs in one beat (A3 scenario), c.enabled=0
  // ============================================================================
  task automatic test_g17();
    rc_user_t       u;
    logic [511:0]   data;


    $display("\n  [G17] Three TLPs in one beat: TLP_0@L0 + TLP_1@L1 + TLP_2@L2");


    data = make_data(
      {16{8'h1A}},    		 // lane 0
      {16{8'h2A}},    		 // lane 1
      {16{8'h3A}},    		 // lane 2
      {16{8'h4A}}            // lane 3
    );

    u = make_user(
      4'b0111,
      '{2'b00, 2'b10, 2'b01, 2'b00},
      4'b0111,
      '{4'd0,  4'd11, 4'd7,  4'd3}
    );

    start_beat(data, u);
    chk("G17  tlp_enable_0 asserts",    tlp_enable_0);
    chk("G17  tlp_enable_1 asserts",    tlp_enable_1);
    chk("G17  tlp_enable_2 asserts",    tlp_enable_2);
    chk("G17  no tlp_enable_3",        !tlp_enable_3);
    chk("G17  no multi-beat tlp",      !tlp_enable);
	chk("G17  First TLP data from lane 0",   tlp_0[127:0] === data[127:0]);
	chk("G17  Second TLP data from lane 1",   tlp_1[127:0] === data[255:128]);
	chk("G17  Third TLP data from lane 2",   tlp_2[127:0] === data[383:256]);
    end_beat();
  endtask


  // ============================================================================
  //  G18 — c.enabled=1: big TLP ends at lane 0, new TLP_0 starts and ends at lane 2
  // ============================================================================
  task automatic test_g18();
    logic [511:0]   data0, data1;
    rc_user_t       u0, u1;

    $display("\n  [G18] c.enabled=1: big ends@L0 + new TLP_0@L2 — ternary picks is_eop[1]");

    data0 = make_data(
      {16{8'h11}},
      {16{8'h22}},
      {16{8'h33}},
      {16{8'h44}}
    );

    u0 = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b00},
      4'b0000, '{4'd0,  4'd0,  4'd0,  4'd0}
    );

    data1 = make_data(
      {16{8'hA0}},             // lane 0: big TLP's last chunk
      {16{8'hA1}},             // lane 1: gap between big end and new SOP
      {16{8'hA2}}, 		       // lane 2: 
      {16{8'hA3}}              // lane 3
    );

    u1 = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b10},
      4'b0011, '{4'd0,  4'd0,  4'd11, 4'd3}
    );

    start_beat(data0, u0);
    chk("G18  beat0: no output",  !tlp_enable & !tlp_enable_0);
    end_beat();

    start_beat(data1, u1);
    chk("G18  beat1: tlp_enable   (big TLP done)",   tlp_enable);
	chk("G18  big TLP data from lane previous 0,1,2,3 and current 0",tlp[639:0] === {data1[127:0], data0});
    chk("G18  beat1: tlp_enable_0 (new TLP done)",   tlp_enable_0);
    chk("G18  beat1: no spurious enable_1/2/3"   ,   !(tlp_enable_1 | tlp_enable_2 | tlp_enable_3));
    chk("G18  new TLP data from lane 2"			 ,   tlp_0[127:0] === data1[383:256]);
    end_beat();
  endtask


  // ============================================================================
  //  G19 — c.enabled=1: big ends + TLP_0@L1 + TLP_1@L2  (B3 scenario)
  // ============================================================================
  task automatic test_g19();
    logic [511:0]   data0, data1;
    rc_user_t       u0, u1;


    $display("\n  [G19] c.enabled=1: big ends + TLP_0@L1 + TLP_1@L2 (B3 scenario)");

    data0 = make_data({16{8'h20}}, {16{8'h21}}, {16{8'h22}}, {16{8'h23}});

    data1 = make_data(
      {16{8'h3A}},             // lane 0: big TLP's tail
      {16{8'h3B}},    		   // lane 1: 
      {16{8'h3C}},    		   // lane 2: 
      {16{8'h3D}}              // lane 3: unused
    );

    u0 = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b00},
      4'b0000, '{4'd0,  4'd0,  4'd0,  4'd0}
    );

    u1 = make_user(
      4'b0011, '{2'b00, 2'b00, 2'b10, 2'b01},
      4'b0111, '{4'd0,  4'd11, 4'd7,  4'd3}
    );

    start_beat(data0, u0);
    chk("G19  beat0: no output",  !tlp_enable & !tlp_enable_0);
    end_beat();

    start_beat(data1, u1);
    chk("G19  beat1: tlp_enable   (big done)",    tlp_enable);
	chk("G19  big TLP data from lane previous 0,1,2,3 and current 0",tlp[639:0] === {data1[127:0], data0});
	
    chk("G19  beat1: tlp_enable_0 (TLP_0 done)",  tlp_enable_0);
    chk("G19  beat1: tlp_enable_1 (TLP_1 done)",  tlp_enable_1);
    chk("G19  beat1: no spurious enable_2/3",
        !(tlp_enable_2 | tlp_enable_3));
    chk("G19  TLP_0 data from lane 1",             tlp_0[127:0] === data1[255:128]);
    chk("G19  TLP_1 data from lane 2",             tlp_1[127:0] === data1[383:256]);
    end_beat();
  endtask


  // ============================================================================
  //  G20 — c.enabled=1: big ends + TLP_0@L1 + TLP_1@L2 + TLP_2@L3  (B4 max)
  // ============================================================================
  task automatic test_g20();
    logic [511:0]   data0, data1;
    rc_user_t       u0, u1;

    
    $display("\n  [G20] c.enabled=1: big+TLP_0@L1+TLP_1@L2+TLP_2@L3 (B4 max — 5 outputs)");

    data0 = make_data({16{8'h21}}, {16{8'h21}}, {16{8'h21}}, {16{8'h21}});

    data1 = make_data(
      {16{8'h4F}},             // lane 0: big TLP's tail (eop_ptr=3)
      {16{8'h5F}},     		   // lane 1: 
      {16{8'h6F}},     	       // lane 2: 
      {16{8'h7F}}      		   // lane 3: 
    );

    u0 = make_user(
      4'b0001, '{2'b00, 2'b00, 2'b00, 2'b00},
      4'b0000, '{4'd0,  4'd0,  4'd0,  4'd0}
    );

    u1 = make_user(
      4'b0111, '{2'b00, 2'b11, 2'b10, 2'b01},
      4'b1111, '{4'd15, 4'd11, 4'd7,  4'd3}
    );

    start_beat(data0, u0);
    chk("G20  beat0: no output",  !tlp_enable & !tlp_enable_0);
    end_beat();

    start_beat(data1, u1);
    chk("G20  beat1: tlp_enable   asserts",  tlp_enable);
    chk("G20  beat1: tlp_enable_0 asserts",  tlp_enable_0);
    chk("G20  beat1: tlp_enable_1 asserts",  tlp_enable_1);
    chk("G20  beat1: tlp_enable_2 asserts",  tlp_enable_2);
    chk("G20  beat1: no tlp_enable_3",      !tlp_enable_3);
    chk("G20  TLP_0 data from L1",  tlp_0[127:0] === data1[255:128]);
    chk("G20  TLP_1 data from L2",  tlp_1[127:0] === data1[383:256]);
    chk("G20  TLP_2 data from L3",  tlp_2[127:0] === data1[511:384]);
    end_beat();
  endtask

  
  // ============================================================================
  //  G21 Four-beat TLP  (c.index reaches 12 on the final beat)
  // ============================================================================
  
  task automatic test_g21();
    logic [511:0] data[4];
    rc_user_t     u[4];

    $display("\n  [G21] Four-beat TLP — c.index reaches 12 on final beat");

    // Unique per-lane fill per beat: any index mis-wiring is immediately visible
    data[0] = make_data({16{8'h10}}, {16{8'h11}}, {16{8'h12}}, {16{8'h13}});
    data[1] = make_data({16{8'h20}}, {16{8'h21}}, {16{8'h22}}, {16{8'h23}});
    data[2] = make_data({16{8'h30}}, {16{8'h31}}, {16{8'h32}}, {16{8'h33}});
    data[3] = make_data({16{8'h40}}, {16{8'h41}}, {16{8'h42}}, {16{8'h43}});

    // Beat 0: SOP@L0, no EOP
    u[0] = make_user(4'b0001, '{2'b00,2'b00,2'b00,2'b00},
                     4'b0000, '{4'd0, 4'd0, 4'd0, 4'd0});
    // Beats 1 & 2: pure middle beats (no SOP, no EOP)
    u[1] = make_user(4'b0000, '{2'b00,2'b00,2'b00,2'b00},
                   4'b0000, '{4'd0, 4'd0, 4'd0, 4'd0});
    u[2] = u[1];
    // Beat 3: EOP full beat (eop_ptr=15)
    u[3] = make_user(4'b0000, '{2'b00,2'b00,2'b00,2'b00},
                     4'b0001, '{4'd0, 4'd0, 4'd0, 4'd15});

    start_beat(data[0], u[0]);
    chk("G21  beat0: no tlp_enable",    !tlp_enable);
    chk("G21  beat0: no tlp_enable_0",  !tlp_enable_0);
    end_beat();   // c: data[511:0]=data[0], index=4, enabled=1

    start_beat(data[1], u[1]);
    chk("G21  beat1: no tlp_enable", !tlp_enable);
    end_beat();   // c: index=8

    start_beat(data[2], u[2]);
    chk("G21  beat2: no tlp_enable", !tlp_enable);
    end_beat();   // c: index=12

    start_beat(data[3], u[3]);
    chk("G21  beat3: tlp_enable asserts",        tlp_enable);
    chk("G21  beat3: no spurious enable_0",     !tlp_enable_0);
    chk("G21  beat3: no spurious enable_1/2/3",
        !(tlp_enable_1 | tlp_enable_2 | tlp_enable_3));
    chk("G21  data[0] at tlp[511:0]",     tlp[511:0]    === data[0]);
    chk("G21  data[1] at tlp[1023:512]",  tlp[1023:512] === data[1]);
    chk("G21  data[2] at tlp[1535:1024]", tlp[1535:1024]=== data[2]);
    chk("G21  data[3] at tlp[2047:1536]", tlp[2047:1536]=== data[3]);
    end_beat();
  endtask


  // ============================================================================
  //  G22 Back-to-back multi-beat TLPs (no bubble between them)
  // ============================================================================
  
  task automatic test_g22();
    logic [511:0] data[3];
    rc_user_t     u[3];

    $display("\n  [G22] Back-to-back multi-beat TLPs — no bubble between TLP-A and TLP-B");

    data[0] = make_data({16{8'hA0}}, {16{8'hA1}}, {16{8'hA2}}, {16{8'hA3}});
    data[1] = make_data({16{8'hB0}}, {16{8'hB1}}, {16{8'hB2}}, {16{8'hB3}});
    data[2] = make_data({16{8'hC0}}, {16{8'hC1}}, {16{8'hC2}}, {16{8'hC3}});

    // Beat 0: TLP-A SOP@L0, no EOP
    u[0] = make_user(4'b0001, '{2'b00,2'b00,2'b00,2'b00},
                     4'b0000, '{4'd0, 4'd0, 4'd0, 4'd0});

    // Beat 1: TLP-A ends (eop[0]=ptr3); TLP-B starts@L1 (no EOP for TLP-B)
    u[1] = make_user(
      4'b0001, '{2'b00,2'b00,2'b00,2'b01},   // sop_ptr[0]=01 (lane 1)
      4'b0001, '{4'd0, 4'd0, 4'd0, 4'd3}     // eop[0]=1, ptr=3 (TLP-A ends)
    );

    // Beat 2: TLP-B ends (c.enabled=1, eop[0]=ptr3)
    u[2] = make_user(4'b0000, '{2'b00,2'b00,2'b00,2'b00},
                     4'b0001, '{4'd0, 4'd0, 4'd0, 4'd3});

    start_beat(data[0], u[0]);
    chk("G22  beat0: no tlp_enable",    !tlp_enable);
    chk("G22  beat0: no tlp_enable_0",  !tlp_enable_0);
    end_beat();   // c: data[511:0]=data[0], index=4, enabled=1

    start_beat(data[1], u[1]);
    chk("G22  beat1: tlp_enable asserts (TLP-A done)",      tlp_enable);
    chk("G22  beat1: no tlp_enable_0 (TLP-B continuing)",  !tlp_enable_0);
    chk("G22  beat1: no spurious enable_1/2/3",
        !(tlp_enable_1 | tlp_enable_2 | tlp_enable_3));
    chk("G22  beat1: TLP-A beat-0 data in tlp[511:0]",   tlp[511:0]   === data[0]);
    chk("G22  beat1: TLP-A tail (beat-1 L0) at tlp[639:512]",
        tlp[639:512] === data[1][127:0]);
    end_beat();   // c: data[383:0]=data[1][511:128], index=3, enabled=1
  
    start_beat(data[2], u[2]);
    chk("G22  beat2: tlp_enable asserts (TLP-B done)",    tlp_enable);
    chk("G22  beat2: no spurious enable_0/1/2/3",
        !(tlp_enable_0 | tlp_enable_1 | tlp_enable_2 | tlp_enable_3));
    chk("G22  beat2: TLP-B tlp[127:0]   = beat-1 L1", tlp[127:0]   === data[1][255:128]);
    chk("G22  beat2: TLP-B tlp[255:128] = beat-1 L2", tlp[255:128] === data[1][383:256]);
    chk("G22  beat2: TLP-B tlp[383:256] = beat-1 L3", tlp[383:256] === data[1][511:384]);
    chk("G22  beat2: TLP-B tlp[511:384] = beat-2 L0", tlp[511:384] === data[2][127:0]);
    end_beat();
  endtask



  // ============================================================================
  //  Continuous assertion: tlp_enable* must never fire when valid=0
  // ============================================================================
  always @(posedge aclk) begin
    #1;
    if (!s_axis_rc_valid) begin
      if (tlp_enable|tlp_enable_0|tlp_enable_1|tlp_enable_2|tlp_enable_3) begin
        $error("  [SVA-FAIL] enable fired while valid=0  (time=%0t)", $time);
        fail_count++;
      end
    end
  end


  // ============================================================================
  //  MAIN
  // ============================================================================
  initial begin
    $display("==========================================================");
    $display("  tb_rc_parser — Comprehensive Testbench");
    $display("==========================================================");

    do_reset();

    test_g1();   idle();
    test_g2();   idle();
    test_g3();   idle();
    test_g4();   idle();
    test_g5();   idle();
    test_g6();   idle();
    test_g7();   idle();
    test_g8();   idle();
    test_g9();   idle();
    test_g10();  idle();
    test_g11();  idle();
    test_g12();  idle();
    test_g13();  idle();
    test_g14();  idle();
    test_g15();  idle();
    test_g16();  idle();
    test_g17();  idle();
    test_g18();  idle();
    test_g19();  idle();
    test_g20();  idle();
	test_g21();  idle();
	test_g22();  idle();
    #100;

    $display("\n==========================================================");
    $display("  TOTAL PASS : %0d", pass_count);
    $display("  TOTAL FAIL : %0d", fail_count);
    $display("  STATUS     : %s",
             (fail_count == 0) ? "ALL TESTS PASSED" : "FAILURES DETECTED");
    $display("==========================================================\n");
    $stop;
  end

endmodule
