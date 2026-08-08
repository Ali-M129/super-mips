SHELL := /bin/bash

.PHONY: help regression smoke benchmarks results waveforms all clean
help:
	@echo "make regression  - run RTL regression tests"
	@echo "make smoke       - run smoke benchmark"
	@echo "make benchmarks  - run four official benchmarks"
	@echo "make results     - same as benchmarks, including tables/charts"
	@echo "make waveforms   - run benchmarks and generate report waveforms"
	@echo "make all         - regression + waveforms"
	@echo "make clean       - remove generated outputs"
regression:
	./scripts/run_all.sh
smoke:
	./scripts/run_benchmark.sh benchmarks/00_smoke/smoke.asm
benchmarks results:
	./scripts/run_stage7.sh
waveforms:
	./scripts/run_stage8.sh
all: regression waveforms
clean:
	./scripts/clean_generated.sh
