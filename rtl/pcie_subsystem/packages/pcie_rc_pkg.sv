
package pcie_rc_pkg;

  import pcie_pkg::attributes_t;
  import pcie_pkg::pcie_id_t;
  import pcie_pkg::request_type_t;
  import pcie_pkg::address_type_t;
  import pcie_pkg::completion_status_t;

  typedef enum logic [3:0] {
    ERR_NORMAL_TERMINATION     = 4'b0000, // Normal termination (all data received)
    ERR_POISONED_COMPLETION    = 4'b0001, // The Completion TLP is Poisoned
    ERR_TERMINATED_WITH_STATUS = 4'b0010, // Request terminated by a Completion with UR, CA, or CRS status
    ERR_TERMINATED_NO_DATA     = 4'b0011, // Request terminated by a Completion with no data, or byte count higher than expected
    ERR_MISMATCH_ID_TC_ATTR    = 4'b0100, // Completion has same tag as outstanding request, but Requester ID, TC, or Attr field does not match
    ERR_INVALID_START_ADDRESS  = 4'b0101, // Error in starting address. Low address bits did not match expected byte for the request
    ERR_INVALID_TAG            = 4'b0110, // Invalid tag. Completion does not match the tags of any outstanding request
    ERR_FUNCTION_LEVEL_RESET   = 4'b1000, // Request terminated by a Function-Level Reset (FLR)
    ERR_COMPLETION_TIMEOUT     = 4'b1001  // Request terminated by a Completion timeout
  } error_code_t;

  typedef struct packed {
    logic               reserved_3;             // [95]
    attributes_t        attributes;             // [94:92]
    logic [2:0]         transaction_class;      // [91:89]
    logic               reserved_2;             // [88]
    pcie_id_t           completer_id;           // [87:72]
    logic [7:0]         tag;                    // [71:64]
    pcie_id_t           requester_id;           // [63:48]
    logic               reserved_1;             // [47]
    logic               poisoned_completion;    // [46]
    completion_status_t completion_status;      // [45:43]
    logic [10:0]        dword_count;            // [42:32]
    logic               reserved_0;             // [31]
    logic               request_completed;      // [30]
    logic               locked_read_completion; // [29]
    logic [12:0]        byte_count;             // [28:16]
    error_code_t        error_code;             // [15:12]
    logic [11:0]        lower_address;          // [11:0]
  } rc_descriptor_t;

  typedef struct packed {
    logic [63:0]     parity;      // [160:97]
    logic            discontinue; // [96]
    logic [3:0][3:0] is_eop_ptr;  // [95:80]
    logic [3:0]      is_eop;      // [79:76]
    logic [3:0][1:0] is_sop_ptr;  // [75:68]
    logic [3:0]      is_sop;      // [67:64]
    logic [63:0]     byte_en;     // [63:0]
  } rc_user_t;

  typedef struct packed {
    logic [8607:0]  payload;
    rc_descriptor_t desc;
  } rc_tlp_t;

  typedef struct packed {
    logic [415:0]   payload;
    rc_descriptor_t desc;
  } rc_tlp_0_t;

  typedef struct packed {
    logic [287:0]   payload;
    rc_descriptor_t desc;
  } rc_tlp_1_t;

  typedef struct packed {
    logic [159:0]   payload;
    rc_descriptor_t desc;
  } rc_tlp_2_t;

  typedef struct packed {
    logic [31:0]    payload;
    rc_descriptor_t desc;
  } rc_tlp_3_t;

  function automatic logic [10:0] calculate_max_dwords_per_rq_tlp(
    input logic [2:0] cfg_max_read_req
  );
    case (cfg_max_read_req)
      3'b000: return 11'd32;   // 128 bytes
      3'b001: return 11'd64;   // 256 bytes
      3'b010: return 11'd128;  // 512 bytes
      3'b011: return 11'd256;  // 1024 bytes
      3'b100: return 11'd512;  // 2048 bytes
      3'b101: return 11'd1024; // 4096 bytes
    endcase
  endfunction

  function automatic logic [1:0] calculate_data_chunk_size(
    input logic [1:0] cfg_max_payload,
    input logic [2:0] cfg_max_read_req
  );
    case (cfg_max_read_req)
      3'b000: begin // 128 bytes
        case (cfg_max_payload)
          2'b00: return 2'b00; // 128 bytes
          2'b01: return 2'b00; // 256 bytes
          2'b10: return 2'b00; // 512 bytes
          2'b11: return 2'b00; // 1024 bytes
        endcase
      end
      3'b001: begin // 256 bytes
        case (cfg_max_payload)
          2'b00: return 2'b00; // 128 bytes
          2'b01: return 2'b01; // 256 bytes
          2'b10: return 2'b01; // 512 bytes
          2'b11: return 2'b01; // 1024 bytes
        endcase
      end
      3'b010: begin // 512 bytes
        case (cfg_max_payload)
          2'b00: return 2'b00; // 128 bytes
          2'b01: return 2'b01; // 256 bytes
          2'b10: return 2'b10; // 512 bytes
          2'b11: return 2'b10; // 1024 bytes
        endcase
      end
      3'b011: begin // 1024 bytes
        case (cfg_max_payload)
          2'b00: return 2'b00; // 128 bytes
          2'b01: return 2'b01; // 256 bytes
          2'b10: return 2'b10; // 512 bytes
          2'b11: return 2'b11; // 1024 bytes
        endcase
      end
      3'b100: begin // 2048 bytes
        case (cfg_max_payload)
          2'b00: return 2'b00; // 128 bytes
          2'b01: return 2'b01; // 256 bytes
          2'b10: return 2'b10; // 512 bytes
          2'b11: return 2'b11; // 1024 bytes
        endcase
      end
      3'b101: begin // 4096 bytes
        case (cfg_max_payload)
          2'b00: return 2'b00; // 128 bytes
          2'b01: return 2'b01; // 256 bytes
          2'b10: return 2'b10; // 512 bytes
          2'b11: return 2'b11; // 1024 bytes
        endcase
      end
    endcase
  endfunction

  function automatic [4:0] calculate_index_by(
    input logic [11:0] lower_address,
    input logic [1:0] cfg_max_payload,
    input logic [2:0] cfg_max_read_req
  );
    case (cfg_max_read_req)
      3'b000: return '0;
      3'b001: begin
        case (cfg_max_payload)
          2'b00: return {4'b0000, lower_address[7]};
          default: return '0;
        endcase
      end
      3'b010: begin
        case (cfg_max_payload)
          2'b00: return {3'b000, lower_address[8:7]};
          2'b01: return {4'b0000, lower_address[8]};
          default: return '0;
        endcase
      end
      3'b011: begin
        case (cfg_max_payload)
          2'b00: return {2'b00, lower_address[9:7]};
          2'b01: return {3'b000, lower_address[9:8]};
          2'b10: return {4'b0000, lower_address[9]};
          default: return '0;
        endcase
      end
      3'b100: begin
        case (cfg_max_payload)
          2'b00: return {1'b0, lower_address[10:7]};
          2'b01: return {2'b00, lower_address[10:8]};
          2'b10: return {3'b000, lower_address[10:9]};
          2'b11: return {4'b0000, lower_address[10]};
        endcase
      end
      3'b101: begin
        case (cfg_max_payload)
          2'b00: return lower_address[11:7];
          2'b01: return {1'b0, lower_address[11:8]};
          2'b10: return {2'b00, lower_address[11:9]};
          2'b11: return {3'b000, lower_address[11:10]};
        endcase
      end
    endcase
  endfunction

endpackage: pcie_rc_pkg
