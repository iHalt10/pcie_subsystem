
package pcie_cc_pkg;

  import pcie_pkg::attributes_t;
  import pcie_pkg::pcie_id_t;
  import pcie_pkg::completion_status_t;
  import pcie_pkg::address_type_t;

  typedef struct packed {
    logic               force_ecrc;          // [95]
    attributes_t        attributes;          // [94:92]
    logic [2:0]         transaction_class;   // [91:89]
    logic               completer_id_enable; // [88]
    pcie_id_t           completer_id;        // [87:72]
    logic [7:0]         tag;                 // [71:64]
    pcie_id_t           requester_id;        // [63:48]
    logic               reserved_3;          // [47]
    logic               poisoned;            // [46]
    completion_status_t completion_status;   // [45:43]
    logic [10:0]        dword_count;         // [42:32]
    logic [1:0]         reserved_2;          // [31:30]
    logic               locked_read;         // [29]
    logic [12:0]        byte_count;          // [28:16]
    logic [5:0]         reserved_1;          // [15:10]
    address_type_t      address_type;        // [9:8]
    logic               reserved_0;          // [7]
    logic [6:0]         lower_address;       // [6:0]
  } cc_descriptor_t;

  typedef struct packed {
    logic [63:0] parity;      // [80:17]
    logic        discontinue; // [16]
    logic [3:0]  is_eop1_ptr; // [15:12]
    logic [3:0]  is_eop0_ptr; // [11:8]
    logic [1:0]  is_eop;      // [7:6]
    logic [1:0]  is_sop1_ptr; // [5:4]
    logic [1:0]  is_sop0_ptr; // [3:2]
    logic [1:0]  is_sop;      // [1:0]
  } cc_user_t;

endpackage: pcie_cc_pkg
