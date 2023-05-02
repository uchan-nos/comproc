.PHONY: sim
sim: sim.exe
	TARGET=sim ./test.sh

sim.exe: sim.sv cpu.sv mem.sv
	iverilog -g2012 -o $@ $^

stack_tb.exe: stack_tb.sv stack.sv
	iverilog -g2012 -o $@ $^

alu_tb.exe: alu_tb.sv alu.sv
	iverilog -g2012 -o $@ $^

decoder_tb.exe: decoder_tb.sv decoder.sv
	iverilog -g2012 -o $@ $^

signalizer_tb.exe: signalizer_tb.sv signalizer.sv
	iverilog -g2012 -o $@ $^

.PHONY: uart
uart:
	TARGET=uart ./test.sh

.PHONY: clean
clean:
	rm -f sim.exe
