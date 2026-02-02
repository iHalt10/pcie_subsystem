
interface pcie_transmit_fc_if;
  logic [3:0] nph_av; // Non-Posted Header Available Credits
  logic [3:0] npd_av; // Non-Posted Data Available Credits

  modport master (
    output nph_av, npd_av
  );

  modport slave (
    input nph_av, npd_av
  );

endinterface: pcie_transmit_fc_if

// interface pcie_transmit_fc_if;
//   logic [3:0] non_posted_header_available_credits; // Non-Posted Header Available Credits
//   logic [3:0] non_posted_data_available_credits; // Non-Posted Data Available Credits

//   modport master (
//     output non_posted_header_available_credits,
//     output non_posted_data_available_credits
//   );

//   modport slave (
//     input non_posted_header_available_credits,
//     input non_posted_data_available_credits
//   );

// endinterface: pcie_transmit_fc_if

// completion_data_credits
// completion_header_credits
// cpld
// cplh

// non_posted_data_credits
// non_posted_header_credits

// npd
// nph

// posted_data_credits
// posted_header_credits
// pd
// ph
