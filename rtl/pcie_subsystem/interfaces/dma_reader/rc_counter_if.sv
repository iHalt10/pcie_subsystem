
interface rc_counter_if #(
  parameter int COUNT_WIDTH = 6
);

  logic enable;
  logic up;
  logic [COUNT_WIDTH-1:0] max;

  logic is_max;

  modport controller (
    input  enable, up, max,
    output is_max
  );

  modport peripheral (
    output enable, up, max,
    input  is_max
  );

endinterface: rc_counter_if
