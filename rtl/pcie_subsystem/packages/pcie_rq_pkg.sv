
package pcie_rq_pkg;

  import pcie_pkg::attributes_t;
  import pcie_pkg::pcie_id_t;
  import pcie_pkg::request_type_t;
  import pcie_pkg::address_type_t;

  typedef struct packed {
    logic          force_ecrc;          // [127]
    attributes_t   attributes;          // [126:124]
    logic [2:0]    transaction_class;   // [123:121]
    logic          requester_id_enable; // [120]
    pcie_id_t      completer_id;        // [119:104]
    logic [7:0]    tag;                 // [103:96]
    pcie_id_t      requester_id;        // [95:80]
    logic          poisoned_request;    // [79]
    request_type_t request_type;        // [78:75]
    logic [10:0]   dword_count;         // [74:64]
    logic [61:0]   address;             // [63:2]
    address_type_t address_type;        // [1:0]
  } rq_mem_descriptor_t;

  typedef union packed {
    logic [127:0]       raw;
    rq_mem_descriptor_t mem;
  } rq_descriptor_t;

  typedef struct packed {
    logic [63:0]     parity;              // [136:73]
    logic [5:0]      seq_num1;            // [72:67]
    logic [5:0]      seq_num0;            // [66:61]
    logic [15:0]     tph_st_tag;          // [60:45]
    logic [1:0]      tph_indirect_tag_en; // [44:43]
    logic [3:0]      tph_type;            // [42:39]
    logic [1:0]      tph_present;         // [38:37]
    logic            discontinue;         // [36]
    logic [1:0][3:0] is_eop_ptr;          // [35:28]
    logic [1:0]      is_eop;              // [27:26]
    logic [1:0][1:0] is_sop_ptr;          // [25:22]
    logic [1:0]      is_sop;              // [21:20]
    logic [3:0]      addr_offset;         // [19:16]
    logic [7:0]      last_be;             // [15:8]
    logic [7:0]      first_be;            // [7:0]
  } rq_user_t;

endpackage: pcie_rq_pkg
