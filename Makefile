JULIA = julia
JULIA_CMD = $(JULIA) --startup-file=no

PROJECT_ROOT = $(shell pwd)
JULIA_MAIN = JULIA_LOAD_PATH=@ $(JULIA_CMD) --project=$(PROJECT_ROOT)/test/environments/main

.PHONY: test* resolve environments

test-all: test test-debug test-extras
test: test-main

test-main test-debug: test-%: test/environments/%/Manifest.toml
	JULIA_LOAD_PATH=@:@stdlib $(JULIA_CMD) \
		--project=test/environments/$* --check-bounds=yes \
		test/runtests.jl

test-extras: test/environments/main/Manifest.toml
	$(JULIA_MAIN) examples/sweepsmallsize.jl
	$(JULIA_MAIN) examples/plot.jl

MANIFESTS = \
test/environments/debug/Manifest.toml \
test/environments/main/Manifest.toml

$(MANIFESTS): %/Manifest.toml: %/Project.toml
	rm -rf $*_tmp
	JULIA_LOAD_PATH=@:@stdlib $(JULIA_CMD) --project=$*_tmp -e 'using Pkg; \
		Pkg.develop(path = "."); \
		Pkg.develop(path = "benchmark/ToyStencilsBenchmarks"); \
		Pkg.develop(path = "test/ToyStencilsTests"); \
		Pkg.add(url = "https://github.com/tkf/BenchPerf.jl"); \
		'
	cp $*/Project.toml $*_tmp/Project.toml
	JULIA_LOAD_PATH=@:@stdlib $(JULIA_CMD) --project=$*_tmp -e 'using Pkg; \
		Pkg.resolve(); \
		'
	mv $*_tmp/Manifest.toml $*/Manifest.toml
	rm -rf $*_tmp

environments: $(MANIFESTS)

resolve:
	$(MAKE) --always-make environments
