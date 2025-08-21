rtl = code/rtl/*  code/Ahb-Rtl/*
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
	vlog -work test/work  $(rtl) $(verif);

simulate: compile
	vsim -c test/work.Ahb_Dmac_tb -do "run -all; quit;"

wave: compile
	vsim test/work.Ahb_Dmac_tb -do "add wave *; run -all;"
