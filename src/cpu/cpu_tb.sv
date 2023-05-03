`include "common.sv"

module cpu_tb;

logic rst, clk, wr_mem, byt;
logic [`ADDR_WIDTH-1:0] mem_addr, last_wr_addr;
logic [15:0] rd_data, wr_data, stack0, stack1, last_wr_data;
logic [5:0] alu_sel;

cpu#(.CLOCK_HZ(1000)) cpu(.*);

initial begin
  $monitor("%d: insn=%04x alu[%02x]=%04x rd_data=%04x pop/sh=%d%d",
           $time, cpu.insn, alu_sel, cpu.alu_out, rd_data, cpu.pop, cpu.push,
           " stk=[%04x %04x] fp=%04x ip=%04x last_wr[%02x]=%04x",
           stack0, stack1, cpu.fp, cpu.ip, last_wr_addr, last_wr_data,
           " phase=%d%d%d%d",
           cpu.signals.phase_decode, cpu.signals.phase_exec,
           cpu.signals.phase_rdmem, cpu.signals.phase_fetch);

  rst <= 1;
  clk <= 1;
  rd_data <= 16'h80A5; // PUSH 0xA5

  #1 rst <= 0;

  if (~cpu.signals.phase_rdmem) $error("CPU must start from rdmem phase");
  if (cpu.ip !== 16'h0300) $error("ip must be 0x0300");

  @(posedge clk)
  @(negedge clk)
    if (~cpu.load_insn) $error("load_insn must be 1");

  @(posedge cpu.load_insn)
    rd_data <= 16'h7004; // NOT
    if (cpu.stack0 !== 16'h00A5) $error("stack0 must be 0x00A5");

  @(posedge cpu.load_insn)
    rd_data <= 16'h8001; // PUSH 0x01
    if (cpu.stack0 !== 16'hFF5A) $error("stack0 must be 0xFF5A");

  @(posedge cpu.load_insn)
    rd_data <= 16'h1020; // JZ 0x20
    if (cpu.stack0 !== 16'h0001) $error("stack0 must be 0x0001");
    if (cpu.stack1 !== 16'hFF5A) $error("stack1 must be 0xFF5A");

  #11 // decode
  #10 // exec
    if (cpu.stack0 !== 16'h0001) $error("stack0 must be 0x0001");
  #10 // rdmem
    if (~cpu.signals.phase_rdmem) $error("phase_rdmem must be 1");
    if (mem_addr !== `ADDR_WIDTH'h308) $error("mem_addr must be 0x308");
    rd_data <= 16'h1030; // JZ 0x30
  @(posedge cpu.load_insn)

  #11 // decode
  #10 // exec
    if (cpu.stack0 !== 16'hFF5A) $error("stack0 must be 0xFF5A");
  #10 // rdmem
    if (~cpu.signals.phase_rdmem) $error("phase_rdmem must be 1");
    if (mem_addr !== `ADDR_WIDTH'h33A) $error("mem_addr must be 0x33A");
    rd_data <= 16'h8003; // PUSH 0x03
  @(posedge cpu.load_insn)

  @(posedge cpu.load_insn)
    rd_data <= 16'h7809; // LDD.1
    if (cpu.stack0 !== 16'h0003) $error("stack0 must be 0x0003");

  #11 // decode
  #10 // exec
    if (mem_addr !== 16'h0003) $error("mem_addr must be 0x0003");
  #10 // rdmem
    rd_data <= 16'hDEAD;
  @(posedge cpu.load_insn)
    rd_data <= 16'h7001; // INC
    if (cpu.stack0 !== 16'h00DE) $error("stack0 must be 0x00DE");

  @(posedge cpu.load_insn)
    rd_data <= 16'h2005; // ST 0+4
    if (cpu.stack0 !== 16'h00DF) $error("stack0 must be 0x00DF");

  @(posedge cpu.load_insn)
    if (last_wr_addr !== 16'h0004) $error("last_wr_addr must be 0x0004");
    if (last_wr_data !== 16'h00DF) $error("last_wr_data must be 0x00DF");

  $finish;
end

// 10 単位時間周期のクロックを生成
always #5 begin
  clk <= ~clk;
end

always @(posedge clk, posedge rst) begin
  if (rst) begin
    last_wr_addr <= `ADDR_WIDTH'd0;
    last_wr_data <= 16'hFFFF;
  end
  else if (wr_mem) begin
    last_wr_addr <= mem_addr;
    last_wr_data <= wr_data;
  end
end

endmodule
