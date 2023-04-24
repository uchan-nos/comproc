.PHONY: sim
sim: sim.exe
	TARGET=sim ./test.sh

sim.exe: sim.sv cpu.sv mem.sv
	iverilog -g2012 -o $@ $^

stack_tb.exe: stack_tb.sv stack.sv
	iverilog -g2012 -o $@ $^

.PHONY: uart
uart:
	TARGET=uart ./test.sh

.PHONY: clean
clean:
	rm -f sim.exe
