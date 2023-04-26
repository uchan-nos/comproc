module stack_tb;

localparam DEPTH = 3;

logic rst, clk, pop, push, load;
logic [15:0] data_in, data_out;
logic [15:0] data_raw[0:DEPTH-1];

stack#(.DEPTH(DEPTH)) stk(.*);

// 10 単位時間周期のクロックを生成
always #5 begin
  clk <= ~clk;
end

initial begin
  $monitor("%d: rst=%d pop=%d push=%d in=%04x out=%04x",
           $time, rst, pop, push, data_in, data_out);

  rst <= 1;
  clk <= 1;
  pop <= 0;
  push <= 1;
  load <= 1;
  data_in <= 16'hCAFE;

  #13
    rst <= 0;
    if (data_out !== 16'h0000) $error("data_out must be 0x0000");

  @(posedge clk)
    push <= 0;
    load <= 0;
    data_in <= 16'hDEAD;
  @(negedge clk)
    if (data_out !== 16'hCAFE) $error("data_out must be 0xCAFE");

  @(posedge clk)
    push <= 1;
    load <= 1;
  @(negedge clk)
    if (data_out !== 16'hCAFE) $error("data_out must be 0xCAFE");

  @(posedge clk)
    data_in <= 16'hBEEF;
  @(negedge clk)
    if (data_out !== 16'hDEAD) $error("data_out must be 0xDEAD");

  @(posedge clk)
    push <= 0;
    pop <= 1;
    load <= 1;
    data_in <= 16'hFACE;
  @(negedge clk)
    if (data_out !== 16'hBEEF) $error("data_out must be 0xBEEF");

  @(posedge clk)
    load <= 0;

  @(negedge clk)
    if (data_out !== 16'hFACE) $error("data_out must be 0xFACE");

  @(posedge clk)
    pop <= 0;
  @(negedge clk)
    if (data_out !== 16'hCAFE) $error("data_out must be 0xCAFE");

  @(posedge clk)
    push <= 1;
    load <= 1;
    data_in <= 16'h0001;
  @(negedge clk)
    if (data_out !== 16'hCAFE) $error("data_out must be 0xCAFE");

  @(posedge clk)
    data_in <= 16'h0002;
  @(negedge clk)
    if (data_out !== 16'h0001) $error("data_out must be 0x0001");

  @(posedge clk)
    data_in <= 16'h0003;
  @(negedge clk)
    if (data_out !== 16'h0002) $error("data_out must be 0x0002");

  @(posedge clk)
    push <= 0;
    pop <= 1;
    load <= 0;
  @(negedge clk)
    if (data_out !== 16'h0003) $error("data_out must be 0x0003");

  @(negedge clk)
    if (data_out !== 16'h0002) $error("data_out must be 0x0002");

  @(negedge clk)
    if (data_out !== 16'h0001) $error("data_out must be 0x0001");

  @(negedge clk)
    if (data_out !== 16'h0000) $error("data_out must be 0x0000");

  @(negedge clk)
    if (data_out !== 16'h0000) $error("data_out must be 0x0000");

  @(posedge clk)
    push <= 1;
    pop <= 0;
    load <= 1;
    data_in <= 16'hFACE;

  @(posedge clk)
    push <= 0;
    data_in <= 16'hAAAA;
  @(negedge clk)
    if (data_out !== 16'hFACE) $error("data_out must be 0xFACE");

  @(posedge clk)
    push <= 0;
    pop <= 1;
    load <= 0;
  @(negedge clk)
    if (data_out !== 16'hAAAA) $error("data_out must be 0xAAAA");

  @(negedge clk)
    if (data_out !== 16'h0000) $error("data_out must be 0x0000");

  $finish;
end

endmodule
