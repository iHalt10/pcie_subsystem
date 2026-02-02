
package pcie_cq_pkg;

  import pcie_pkg::attributes_t;
  import pcie_pkg::pcie_id_t;
  import pcie_pkg::request_type_t;
  import pcie_pkg::address_type_t;

  typedef struct packed {
    logic          reserved_1;        // [127]
    attributes_t   attributes;        // [126:124]
    logic [2:0]    transaction_class; // [123:121]
    logic [5:0]    bar_aperture;      // [120:115]
    logic [2:0]    bar_id;            // [114:112]
    logic [7:0]    function_id;       // [111:104]
    logic [7:0]    tag;               // [103:96]
    pcie_id_t      requester_id;      // [95:80]
    logic          reserved_0;        // [79]
    request_type_t request_type;      // [78:75]
    logic [10:0]   dword_count;       // [74:64]
    logic [61:0]   address;           // [63:2]
    address_type_t address_type;      // [1:0]
  } cq_mem_descriptor_t;

  typedef union packed {
    logic [127:0]       raw;
    cq_mem_descriptor_t mem;
  } cq_descriptor_t;

  typedef struct packed {
    logic [8575:0]  payload;
    cq_descriptor_t desc;
  } cq_tlp_t;

  typedef struct packed {
    logic [383:0]   payload;
    cq_descriptor_t desc;
  } cq_tlp_0_t;

  typedef struct packed {
    logic [127:0]   payload;
    cq_descriptor_t desc;
  } cq_tlp_1_t;

  typedef struct packed {
    logic [63:0]     parity;      // [182:119]
    logic [15:0]     tph_st_tag;  // [118:103]
    logic [3:0]      tph_type;    // [102:99]
    logic [1:0]      tph_present; // [98:97]
    logic            discontinue; // [96]
    logic [1:0][3:0] is_eop_ptr;  // [95:88]
    logic [1:0]      is_eop;      // [87:86]
    logic [1:0][1:0] is_sop_ptr;  // [85:82]
    logic [1:0]      is_sop;      // [81:80]
    logic [63:0]     byte_en;     // [79:16]
    logic [7:0]      last_be;     // [15:8]
    logic [7:0]      first_be;    // [7:0]
  } cq_user_t;

endpackage: pcie_cq_pkg
