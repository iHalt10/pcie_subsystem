
package pcie_pkg;

  typedef struct packed {
    logic pf3_intx_disabled;      // Bit 15: Function 3 INTx Disable
    logic pf3_bus_master_enabled; // Bit 14: Function 3 Bus Master Enable
    logic pf3_mem_space_enabled;  // Bit 13: Function 3 Memory Space Enable
    logic pf3_io_space_enabled;   // Bit 12: Function 3 I/O Space Enable
    logic pf2_intx_disabled;      // Bit 11: Function 2 INTx Disable
    logic pf2_bus_master_enabled; // Bit 10: Function 2 Bus Master Enable
    logic pf2_mem_space_enabled;  // Bit  9: Function 2 Memory Space Enable
    logic pf2_io_space_enabled;   // Bit  8: Function 2 I/O Space Enable
    logic pf1_intx_disabled;      // Bit  7: Function 1 INTx Disable
    logic pf1_bus_master_enabled; // Bit  6: Function 1 Bus Master Enable
    logic pf1_mem_space_enabled;  // Bit  5: Function 1 Memory Space Enable
    logic pf1_io_space_enabled;   // Bit  4: Function 1 I/O Space Enable
    logic pf0_intx_disabled;      // Bit  3: Function 0 INTx Disable
    logic pf0_bus_master_enabled; // Bit  2: Function 0 Bus Master Enable
    logic pf0_mem_space_enabled;  // Bit  1: Function 0 Memory Space Enable
    logic pf0_io_space_enabled;   // Bit  0: Function 0 I/O Space Enable
  } cfg_function_status_t;

  typedef struct packed {
    logic id_based_ordering;
    logic relaxed_ordering;
    logic no_snoop;
  } attributes_t;

  typedef struct packed {
    logic [7:0] bus_number;
    logic [4:0] device_number;
    logic [2:0] function_number;
  } legacy_id_t;

  typedef struct packed {
    logic [7:0] bus_number;
    logic [7:0] function_number;
  } ari_id_t;

  typedef union packed {
    logic [15:0] raw;
    legacy_id_t  legacy;
    ari_id_t     ari;
  } pcie_id_t;

  typedef enum logic [3:0] {
    REQUEST_MEM_READ      = 4'b0000, // Memory Read Request
    REQUEST_MEM_WRITE     = 4'b0001, // Memory Write Request
    REQUEST_IO_READ       = 4'b0010, // I/O Read Request
    REQUEST_IO_WRITE      = 4'b0011, // I/O Write Request
    REQUEST_MEM_FETCH_ADD = 4'b0100, // Memory Fetch and Add Request
    REQUEST_MEM_SWAP      = 4'b0101, // Memory Unconditional Swap Request
    REQUEST_MEM_CAS       = 4'b0110, // Memory Compare and Swap Request
    REQUEST_MEM_READ_LOCK = 4'b0111, // Locked Read Request (allowed only in Legacy Devices)
    REQUEST_CFG_READ_0    = 4'b1000, // Type 0 Configuration Read Request (on Requester side only)
    REQUEST_CFG_READ_1    = 4'b1001, // Type 1 Configuration Read Request (on Requester side only)
    REQUEST_CFG_WRITE_0   = 4'b1010, // Type 0 Configuration Write Request (on Requester side only)
    REQUEST_CFG_WRITE_1   = 4'b1011, // Type 1 Configuration Write Request (on Requester side only)
    REQUEST_MSG           = 4'b1100, // Any message, except ATS and Vendor-Defined Messages
    REQUEST_MSG_VENDOR    = 4'b1101, // Vendor-Defined Message
    REQUEST_MSG_ATS       = 4'b1110, // ATS Message
    REQUEST_RESERVED      = 4'b1111  // Reserved
  } request_type_t;

  typedef enum logic [2:0] {
    COMPLETION_STATUS_SC  = 3'b000, // Successful Completion
    COMPLETION_STATUS_UR  = 3'b001, // Unsupported Request
    COMPLETION_STATUS_CRS = 3'b010, // Configuration Request Retry Status
    COMPLETION_STATUS_CA  = 3'b100  // Completer Abort
  } completion_status_t;

  typedef enum logic [1:0] {
    ADDRESS_TYPE_UNTRANSLATED = 2'b00, // Address in the request is untranslated
    ADDRESS_TYPE_TRANSLATION  = 2'b01, // Transaction is a Translation Request
    ADDRESS_TYPE_TRANSLATED   = 2'b10, // Address in the request is a translated address
    ADDRESS_TYPE_RESERVED     = 2'b11  // Reserved
  } address_type_t;

  function automatic logic [10:0] calculate_max_payload_dwords(
    input logic [1:0] cfg_max_payload
  );
    case (cfg_max_payload)
      2'b00: return 11'd32;  // 128 bytes
      2'b01: return 11'd64;  // 256 bytes
      2'b10: return 11'd128; // 512 bytes
      2'b11: return 11'd256; // 1024 bytes
    endcase
  endfunction

  function automatic logic [63:0] calculate_address_by_max_payload(
    input logic [63:0] address,
    input logic [63:0] offset,
    input logic [1:0] cfg_max_payload
  );
    case (cfg_max_payload)
      2'b00: return {address[63:7]  + offset, address[6:0]}; // 128 bytes
      2'b01: return {address[63:8]  + offset, address[7:0]}; // 256 bytes
      2'b10: return {address[63:9]  + offset, address[8:0]}; // 512 bytes
      2'b11: return {address[63:10] + offset, address[9:0]}; // 1024 bytes
    endcase
  endfunction

  function automatic logic [63:0] calculate_address_by_max_read_req(
    input logic [63:0] address,
    input logic [63:0] offset,
    input logic [2:0] cfg_max_read_req
  );
    case (cfg_max_read_req)
      3'b000: return {address[63:7]  + offset, address[6:0]};  // 128 bytes
      3'b001: return {address[63:8]  + offset, address[7:0]};  // 256 bytes
      3'b010: return {address[63:9]  + offset, address[8:0]};  // 512 bytes
      3'b011: return {address[63:10] + offset, address[9:0]}; // 1024 bytes
      3'b100: return {address[63:11] + offset, address[10:0]}; // 2048 bytes
      3'b101: return {address[63:12] + offset, address[11:0]}; // 4096 bytes
    endcase
  endfunction

endpackage: pcie_pkg
