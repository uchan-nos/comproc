.PHONY: sim
sim: sim.exe
	TARGET=sim ./test.sh

sim.exe: sim.sv cpu.sv
	iverilog -g2012 -o $@ $^

.PHONY: uart
uart:
	TARGET=uart ./test.sh

.PHONY: clean
clean:
	rm -f sim.exe
