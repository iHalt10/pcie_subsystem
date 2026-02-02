
interface configuration_space_manager_if;

  import configuration_space_pkg::configuration_space_t;

  logic       enable;
  logic [7:0] function_number;

  logic       done;
  configuration_space_t space;

  modport controller (
    input enable, function_number,
    output done, space
  );

  modport peripheral (
    output enable, function_number,
    input done, space
  );

endinterface: configuration_space_manager_if
