.PHONY: sim
sim: sim.exe
	TARGET=sim ./test.sh

sim.exe: sim.sv
	iverilog -o $@ $^

.PHONY: uart
uart:
	TARGET=uart ./test.sh

.PHONY: clean
clean:
	rm -f sim.exe
