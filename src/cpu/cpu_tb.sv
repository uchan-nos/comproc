`include "common.sv"

module cpu_tb;

logic rst, clk, wr_mem, byt, load_insn, irq;
logic [`ADDR_WIDTH-1:0] mem_addr, last_wr_addr;
logic [15:0] rd_data, wr_data, stack0, stack1, insn, last_wr_data;
logic [5:0] alu_sel;

cpu#(.CLOCK_HZ(1000)) cpu(.*);

initial begin
  $monitor("%d: insn=%04x alu[%02x]=%04x rd_data=%04x pop/sh=%d%d",
           $time, cpu.insn, alu_sel, cpu.alu_out, rd_data, cpu.pop, cpu.push,
           " stk=[%04x %04x] fp=%04x ip=%04x last_wr[%02x]=%04x",
           stack0, stack1, cpu.fp, cpu.ip, last_wr_addr, last_wr_data,
           " phase=%d%d%d%d",
           cpu.signals.phase_decode, cpu.signals.phase_exec,
           cpu.signals.phase_rdmem, cpu.signals.phase_fetch,
           " irq=%d",
           cpu.irq
           );

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
    rd_data <= 16'h0FFE; // JMP IP-2

  #11 // decode
  #10 // exec
    if (cpu.alu_out !== 16'h306) $error("alu_out must be 0x306");
  #10 // rdmem
    rd_data <= 16'h1020; // JZ 0x20
  @(posedge cpu.load_insn)
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
    rd_data <= 16'h2103; // LD.1 0x103
  @(posedge cpu.load_insn)

  #11 // decode
  #10 // exec
    if (mem_addr !== 16'h0103) $error("mem_addr must be 0x0103");
  #10 // rdmem
    rd_data <= 16'hDEAD;
  @(posedge cpu.load_insn)
    rd_data <= 16'h7001; // INC
    if (cpu.stack0 !== 16'h00DE) $error("stack0 must be 0x00DE");

  @(posedge cpu.load_insn)
    rd_data <= 16'h4005; // ST 0+4
    if (cpu.stack0 !== 16'h00DF) $error("stack0 must be 0x00DF");

  @(posedge cpu.load_insn)
    if (last_wr_addr !== 16'h0004) $error("last_wr_addr must be 0x0004");
    if (last_wr_data !== 16'h00DF) $error("last_wr_data must be 0x00DF");

  @(posedge cpu.load_insn)
    rd_data <= 16'h8012; // PUSH 0x12

  @(posedge cpu.load_insn)
    rd_data <= 16'h8081; // PUSH 0x81

  @(posedge cpu.load_insn)
    rd_data <= 16'h780D; // STA.1

  @(posedge cpu.load_insn)
    rd_data <= 16'h7809; // LDD.1
    if (cpu.stack0 !== 16'h0081) $error("stack0 must be 0x0081");
    if (last_wr_addr !== 16'h0081) $error("last_wr_addr must be 0x0081");
    if (last_wr_data !== 16'h1200) $error("last_wr_data must be 0x1200");

  #11 // decode
  #10 // exec
    if (mem_addr !== 16'h0081) $error("mem_addr must be 0x0081");
  #10 // rdmem
    rd_data <= 16'h1200;
  @(posedge cpu.load_insn)
    rd_data <= 16'h80FF; // PUSH 0xFF
    if (cpu.stack0 !== 16'h0012) $error("stack0 must be 0x0012");

  @(posedge cpu.load_insn)
    rd_data <= 16'h8900; // PUSH 0x900

  @(posedge cpu.load_insn)
    rd_data <= 16'h7811; // ISR

  /*
  @(posedge cpu.load_insn)
    rd_data <= 16'h8002; // PUSH 2

  @(posedge cpu.load_insn)
    rd_data <= 16'h4005; // ST 4  (mem[4] <= 2: enable interrupt of cdtimer)

  @(posedge cpu.load_insn)
    rd_data <= 16'h8001; // PUSH 1

  @(posedge cpu.load_insn)
    rd_data <= 16'h4003; // ST 2  (mem[2] <= 1: write 1 to counter of cdtimer)

  #11 // decode
  #10 // exec
  #10 // rdmem
    if (cpu.cdtimer_to !== 1'b0) $error("cdtimer must NOT be timed out");

  @(posedge cpu.load_insn)
    rd_data <= 16'h80FE; // PUSH 0xFE
    if (cpu.cdtimer_to !== 1'b1) $error("cdtimer must be timed out");
    if (cpu.irq !== 1'b1) $error("IRQ must be 1");
    if (cpu.ien !== 1'b1) $error("IEN must be 1");
    if (mem_addr !== `ADDR_WIDTH'h358) $error("mem_addr must be 0x358");
  */

  #11 // decode
  #10 // exec
  #10 // rdmem
    rd_data <= 16'h7812; // IRET
    if (~cpu.signals.phase_rdmem) $error("phase_rdmem must be 1");
    if (cpu.ien !== 1'b0) $error("IEN must be 0");
    if (mem_addr !== `ADDR_WIDTH'h900) $error("mem_addr must be 0x900");
    if (stack0 !== 16'h00FF) $error("stack0 must be 0x00FF");

  @(posedge cpu.load_insn)
  #11 // decode
  #10 // exec
  #10 // rdmem
    rd_data <= 16'h80FE; // PUSH 0xFE
    if (cpu.ien !== 1'b1) $error("IEN must be 1");
    if (mem_addr !== `ADDR_WIDTH'h358) $error("mem_addr must be 0x358");

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
