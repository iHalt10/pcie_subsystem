
package register_controller_pkg;

  import pcie_pkg::attributes_t;
  import pcie_pkg::pcie_id_t;

  typedef struct packed {
    attributes_t   attributes;
    pcie_id_t      requester_id;
    logic [2:0]    transaction_class;
    logic [6:0]    lower_address;
    logic [7:0]    tag;
  } metadata_t;

  typedef struct packed {
    metadata_t   metadata;
    logic [2:0]  bar_id;
    logic [7:0]  function_id;
    logic [31:0] data;
    logic [63:0] address;
    logic        write_enable;
    logic        enable;
  } register_controller_t;

endpackage: register_controller_pkg
