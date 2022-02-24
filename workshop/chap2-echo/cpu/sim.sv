module Simulation;

/*******************
* 回路への信号入力 *
*******************/

localparam STDIN  = 'h8000_0000;
localparam STDERR = 'h8000_0002;

logic [7:0] sim_input;

initial begin
  // stdin からテストデータを読む
  if ($fscanf(STDIN, "%x", sim_input) == 1)
    ;

  $display("%x", sim_input);
  $finish;
end

endmodule
