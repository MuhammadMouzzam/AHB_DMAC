rtl = code/rtl/* code/Ahb-Rtl/*
verif = code/verif/*

all: simulate

work:
	@if [ ! -d test ]; then \
		echo "\033[0;36mCreating 'test' directory......\033[0m"; \
		mkdir test; \
	fi
	@if [ ! -d test/work ]; then \
		echo "\033[0;36mCreating Library named 'work'.....\033[0m"; \
		vlib test/work; \
	fi

compile: work
	vlog -suppress vopt-7061 -work test/work  $(rtl) $(verif);

simulate: compile
	vsim -suppress vopt-7061 -c test/work.Ahb_Dmac_tb -do "run -all; quit;"

wave: compile
	vsim test/work.Dmac_Top_tb -do "add wave *; run -all;"
