RELBIN:=target/release/cairo-vm-run
DBGBIN:=target/debug/cairo-vm-run

STARKNET_COMPILE_CAIRO_1:=cairo1/bin/starknet-compile
STARKNET_SIERRA_COMPILE_CAIRO_1:=cairo1/bin/starknet-sierra-compile

STARKNET_COMPILE_CAIRO_2:=cairo2/bin/starknet-compile
STARKNET_SIERRA_COMPILE_CAIRO_2:=cairo2/bin/starknet-sierra-compile

.PHONY: build-cairo-1-compiler build-cairo-1-compiler-macos build-cairo-2-compiler build-cairo-2-compiler-macos \
	deps deps-macos cargo-deps build run check test clippy coverage benchmark flamegraph \
	compare_benchmarks_deps compare_benchmarks docs clean \
	compare_vm_output compare_trace_memory compare_trace compare_memory \
	compare_trace_memory_proof  compare_all_proof compare_trace_proof compare_memory_proof compare_air_public_input \
	cairo_bench_programs cairo_proof_programs cairo_test_programs cairo_1_test_contracts cairo_2_test_contracts \
	cairo_trace cairo-vm_trace cairo_proof_trace cairo-vm_proof_trace \
	fuzzer-deps fuzzer-run-cairo-compiled fuzzer-run-hint-diff build-cairo-lang hint-accountant \
	$(RELBIN) $(DBGBIN)

# Proof mode consumes too much memory with cairo-lang to execute
# two instances at the same time in the CI without getting killed
.NOTPARALLEL: $(CAIRO_TRACE_PROOF) $(CAIRO_MEM_PROOF)

# ===================
# Run with proof mode
# ===================

TEST_PROOF_DIR=cairo_programs/proof_programs
TEST_PROOF_FILES:=$(wildcard $(TEST_PROOF_DIR)/*.cairo)
COMPILED_PROOF_TESTS:=$(patsubst $(TEST_PROOF_DIR)/%.cairo, $(TEST_PROOF_DIR)/%.json, $(TEST_PROOF_FILES))

CAIRO_MEM_PROOF:=$(patsubst $(TEST_PROOF_DIR)/%.json, $(TEST_PROOF_DIR)/%.memory, $(COMPILED_PROOF_TESTS))
CAIRO_TRACE_PROOF:=$(patsubst $(TEST_PROOF_DIR)/%.json, $(TEST_PROOF_DIR)/%.trace, $(COMPILED_PROOF_TESTS))
CAIRO_AIR_PUBLIC_INPUT:=$(patsubst $(TEST_PROOF_DIR)/%.json, $(TEST_PROOF_DIR)/%.air_public_input, $(COMPILED_PROOF_TESTS))

CAIRO_RS_MEM_PROOF:=$(patsubst $(TEST_PROOF_DIR)/%.json, $(TEST_PROOF_DIR)/%.rs.memory, $(COMPILED_PROOF_TESTS))
CAIRO_RS_TRACE_PROOF:=$(patsubst $(TEST_PROOF_DIR)/%.json, $(TEST_PROOF_DIR)/%.rs.trace, $(COMPILED_PROOF_TESTS))
CAIRO_RS_AIR_PUBLIC_INPUT:=$(patsubst $(TEST_PROOF_DIR)/%.json, $(TEST_PROOF_DIR)/%.rs.air_public_input, $(COMPILED_PROOF_TESTS))

PROOF_BENCH_DIR=cairo_programs/benchmarks
PROOF_BENCH_FILES:=$(wildcard $(PROOF_BENCH_DIR)/*.cairo)
PROOF_COMPILED_BENCHES:=$(patsubst $(PROOF_BENCH_DIR)/%.cairo, $(PROOF_BENCH_DIR)/%.json, $(PROOF_BENCH_FILES))

$(TEST_PROOF_DIR)/%.json: $(TEST_PROOF_DIR)/%.cairo
	cairo-compile --cairo_path="$(TEST_PROOF_DIR):$(PROOF_BENCH_DIR)" $< --output $@ --proof_mode

$(TEST_PROOF_DIR)/%.rs.trace $(TEST_PROOF_DIR)/%.rs.memory $(TEST_PROOF_DIR)/%.rs.air_public_input: $(TEST_PROOF_DIR)/%.json $(RELBIN)
	cargo llvm-cov run -p cairo-vm-cli --release --no-report -- --layout starknet_with_keccak --proof_mode $< --trace_file $@ --memory_file $(@D)/$(*F).rs.memory --air_public_input $(@D)/$(*F).rs.air_public_input

$(TEST_PROOF_DIR)/%.trace $(TEST_PROOF_DIR)/%.memory $(TEST_PROOF_DIR)/%.air_public_input: $(TEST_PROOF_DIR)/%.json
	cairo-run --layout starknet_with_keccak --proof_mode --program $< --trace_file $(@D)/$(*F).trace  --air_public_input $(@D)/$(*F).air_public_input --memory_file $(@D)/$(*F).memory

$(PROOF_BENCH_DIR)/%.json: $(PROOF_BENCH_DIR)/%.cairo
	cairo-compile --cairo_path="$(TEST_PROOF_DIR):$(PROOF_BENCH_DIR)" $< --output $@ --proof_mode

# ======================
# Run without proof mode
# ======================

TEST_DIR=cairo_programs
TEST_FILES:=$(wildcard $(TEST_DIR)/*.cairo)
COMPILED_TESTS:=$(patsubst $(TEST_DIR)/%.cairo, $(TEST_DIR)/%.json, $(TEST_FILES))
CAIRO_MEM:=$(patsubst $(TEST_DIR)/%.json, $(TEST_DIR)/%.memory, $(COMPILED_TESTS))
CAIRO_TRACE:=$(patsubst $(TEST_DIR)/%.json, $(TEST_DIR)/%.trace, $(COMPILED_TESTS))
CAIRO_RS_MEM:=$(patsubst $(TEST_DIR)/%.json, $(TEST_DIR)/%.rs.memory, $(COMPILED_TESTS))
CAIRO_RS_TRACE:=$(patsubst $(TEST_DIR)/%.json, $(TEST_DIR)/%.rs.trace, $(COMPILED_TESTS))

BENCH_DIR=cairo_programs/benchmarks
BENCH_FILES:=$(wildcard $(BENCH_DIR)/*.cairo)
COMPILED_BENCHES:=$(patsubst $(BENCH_DIR)/%.cairo, $(BENCH_DIR)/%.json, $(BENCH_FILES))

BAD_TEST_DIR=cairo_programs/bad_programs
BAD_TEST_FILES:=$(wildcard $(BAD_TEST_DIR)/*.cairo)
COMPILED_BAD_TESTS:=$(patsubst $(BAD_TEST_DIR)/%.cairo, $(BAD_TEST_DIR)/%.json, $(BAD_TEST_FILES))

PRINT_TEST_DIR=cairo_programs/print_feature
PRINT_TEST_FILES:=$(wildcard $(PRINT_TEST_DIR)/*.cairo)
COMPILED_PRINT_TESTS:=$(patsubst $(PRINT_TEST_DIR)/%.cairo, $(PRINT_TEST_DIR)/%.json, $(PRINT_TEST_FILES))

NORETROCOMPAT_DIR:=cairo_programs/noretrocompat
NORETROCOMPAT_FILES:=$(wildcard $(NORETROCOMPAT_DIR)/*.cairo)
COMPILED_NORETROCOMPAT_TESTS:=$(patsubst $(NORETROCOMPAT_DIR)/%.cairo, $(NORETROCOMPAT_DIR)/%.json, $(NORETROCOMPAT_FILES))

$(BENCH_DIR)/%.json: $(BENCH_DIR)/%.cairo
	cairo-compile --cairo_path="$(TEST_DIR):$(BENCH_DIR)" $< --output $@ --proof_mode

$(TEST_DIR)/%.json: $(TEST_DIR)/%.cairo
	cairo-compile --cairo_path="$(TEST_DIR):$(BENCH_DIR)" $< --output $@

$(TEST_DIR)/%.rs.trace $(TEST_DIR)/%.rs.memory: $(TEST_DIR)/%.json $(RELBIN)
	cargo llvm-cov run -p cairo-vm-cli --release --no-report -- --layout all_cairo $< --trace_file $@ --memory_file $(@D)/$(*F).rs.memory

$(TEST_DIR)/%.trace $(TEST_DIR)/%.memory: $(TEST_DIR)/%.json
	cairo-run --layout starknet_with_keccak --program $< --trace_file $@ --memory_file $(@D)/$(*F).memory

$(NORETROCOMPAT_DIR)/%.json: $(NORETROCOMPAT_DIR)/%.cairo
	cairo-compile --cairo_path="$(TEST_DIR):$(BENCH_DIR):$(NORETROCOMPAT_DIR)" $< --output $@

$(BAD_TEST_DIR)/%.json: $(BAD_TEST_DIR)/%.cairo
	cairo-compile $< --output $@

$(PRINT_TEST_DIR)/%.json: $(PRINT_TEST_DIR)/%.cairo
	cairo-compile $< --output $@

# ======================
# Test Cairo 1 Contracts
# ======================

CAIRO_1_CONTRACTS_TEST_DIR=cairo_programs/cairo-1-contracts
CAIRO_1_CONTRACTS_TEST_CAIRO_FILES:=$(wildcard $(CAIRO_1_CONTRACTS_TEST_DIR)/*.cairo)
CAIRO_1_COMPILED_SIERRA_CONTRACTS:=$(patsubst $(CAIRO_1_CONTRACTS_TEST_DIR)/%.cairo, $(CAIRO_1_CONTRACTS_TEST_DIR)/%.sierra, $(CAIRO_1_CONTRACTS_TEST_CAIRO_FILES))
CAIRO_1_COMPILED_CASM_CONTRACTS:= $(patsubst $(CAIRO_1_CONTRACTS_TEST_DIR)/%.sierra, $(CAIRO_1_CONTRACTS_TEST_DIR)/%.casm, $(CAIRO_1_COMPILED_SIERRA_CONTRACTS))

$(CAIRO_1_CONTRACTS_TEST_DIR)/%.sierra: $(CAIRO_1_CONTRACTS_TEST_DIR)/%.cairo
	$(STARKNET_COMPILE_CAIRO_1) --allowed-libfuncs-list-name experimental_v0.1.0 $< $@

$(CAIRO_1_CONTRACTS_TEST_DIR)/%.casm: $(CAIRO_1_CONTRACTS_TEST_DIR)/%.sierra
	$(STARKNET_SIERRA_COMPILE_CAIRO_1) --allowed-libfuncs-list-name experimental_v0.1.0 $< $@

# ======================
# Setup Cairo 1 Compiler
# ======================

CAIRO_1_REPO_DIR = cairo1
CAIRO_1_VERSION = 1.1.1

build-cairo-1-compiler-macos:
	@if [ ! -d "$(CAIRO_1_REPO_DIR)" ]; then \
        	curl -L -o cairo-$(CAIRO_1_VERSION).tar https://github.com/starkware-libs/cairo/releases/download/v$(CAIRO_1_VERSION)/release-aarch64-apple-darwin.tar \
		&& tar -xzvf cairo-$(CAIRO_1_VERSION).tar \
		&& mv cairo/ cairo1/; \
    	fi

build-cairo-1-compiler:
	@if [ ! -d "$(CAIRO_1_REPO_DIR)" ]; then \
		curl -L -o cairo-$(CAIRO_1_VERSION).tar https://github.com/starkware-libs/cairo/releases/download/v$(CAIRO_1_VERSION)/release-x86_64-unknown-linux-musl.tar.gz \
		&& tar -xzvf cairo-$(CAIRO_1_VERSION).tar \
		&& mv cairo/ cairo1/; \
	fi

# ======================
# Test Cairo 2 Contracts
# ======================

CAIRO_2_CONTRACTS_TEST_DIR=cairo_programs/cairo-2-contracts
CAIRO_2_CONTRACTS_TEST_CAIRO_FILES:=$(wildcard $(CAIRO_2_CONTRACTS_TEST_DIR)/*.cairo)
CAIRO_2_COMPILED_SIERRA_CONTRACTS:=$(patsubst $(CAIRO_2_CONTRACTS_TEST_DIR)/%.cairo, $(CAIRO_2_CONTRACTS_TEST_DIR)/%.sierra, $(CAIRO_2_CONTRACTS_TEST_CAIRO_FILES))
CAIRO_2_COMPILED_CASM_CONTRACTS:= $(patsubst $(CAIRO_2_CONTRACTS_TEST_DIR)/%.sierra, $(CAIRO_2_CONTRACTS_TEST_DIR)/%.casm, $(CAIRO_2_COMPILED_SIERRA_CONTRACTS))

$(CAIRO_2_CONTRACTS_TEST_DIR)/%.sierra: $(CAIRO_2_CONTRACTS_TEST_DIR)/%.cairo
	$(STARKNET_COMPILE_CAIRO_2) --single-file $< $@

$(CAIRO_2_CONTRACTS_TEST_DIR)/%.casm: $(CAIRO_2_CONTRACTS_TEST_DIR)/%.sierra
	$(STARKNET_SIERRA_COMPILE_CAIRO_2) $< $@


# ======================
# Setup Cairo 2 Compiler
# ======================

CAIRO_2_REPO_DIR = cairo2
CAIRO_2_VERSION = 2.1.0-rc1

build-cairo-2-compiler-macos:
	@if [ ! -d "$(CAIRO_2_REPO_DIR)" ]; then \
        	curl -L -o cairo-${CAIRO_2_VERSION}.tar https://github.com/starkware-libs/cairo/releases/download/v${CAIRO_2_VERSION}/release-aarch64-apple-darwin.tar \
	 	&& tar -xzvf cairo-${CAIRO_2_VERSION}.tar \
	 	&& mv cairo/ cairo2/; \
	fi

build-cairo-2-compiler:
	@if [ ! -d "$(CAIRO_2_REPO_DIR)" ]; then \
		curl -L -o cairo-${CAIRO_2_VERSION}.tar https://github.com/starkware-libs/cairo/releases/download/v${CAIRO_2_VERSION}/release-x86_64-unknown-linux-musl.tar.gz \
		&& tar -xzvf cairo-${CAIRO_2_VERSION}.tar \
		&& mv cairo/ cairo2/; \
	fi

cargo-deps:
	cargo install --version 0.3.1 iai-callgrind-runner
	cargo install --version 1.1.0 cargo-criterion
	cargo install --version 0.6.1 flamegraph
	cargo install --version 1.14.0 hyperfine
	cargo install --version 0.9.49 cargo-nextest
	cargo install --version 0.5.9 cargo-llvm-cov
	cargo install --version 0.12.1 wasm-pack

cairo1-run-deps:
	cd cairo1-run; make deps

deps: cargo-deps build-cairo-1-compiler build-cairo-2-compiler cairo1-run-deps
	pyenv install -s pypy3.9-7.3.9
	PYENV_VERSION=pypy3.9-7.3.9 python -m venv cairo-vm-pypy-env
	. cairo-vm-pypy-env/bin/activate ; \
	pip install -r requirements.txt ; \
	pyenv install -s 3.9.15
	PYENV_VERSION=3.9.15 python -m venv cairo-vm-env
	. cairo-vm-env/bin/activate ; \
	pip install -r requirements.txt ; \

deps-macos: cargo-deps build-cairo-1-compiler-macos build-cairo-2-compiler-macos cairo1-run-deps
	arch -x86_64 pyenv install -s pypy3.9-7.3.9
	PYENV_VERSION=pypy3.9-7.3.9 python -m venv cairo-vm-pypy-env
	. cairo-vm-pypy-env/bin/activate ; \
	CFLAGS=-I/opt/homebrew/opt/gmp/include LDFLAGS=-L/opt/homebrew/opt/gmp/lib pip install -r requirements.txt ; \
	pyenv install -s 3.9.15
	PYENV_VERSION=3.9.15 python -m venv cairo-vm-env
	. cairo-vm-env/bin/activate ; \
	CFLAGS=-I/opt/homebrew/opt/gmp/include LDFLAGS=-L/opt/homebrew/opt/gmp/lib pip install -r requirements.txt ; \

$(RELBIN):
	cargo build --release

build: $(RELBIN)

run:
	cargo run -p cairo-vm-cli

check:
	cargo check

cairo_test_programs: $(COMPILED_TESTS) $(COMPILED_BAD_TESTS) $(COMPILED_NORETROCOMPAT_TESTS) $(COMPILED_PRINT_TESTS)
cairo_proof_programs: $(COMPILED_PROOF_TESTS)
cairo_bench_programs: $(COMPILED_BENCHES)
cairo_1_test_contracts: $(CAIRO_1_COMPILED_CASM_CONTRACTS)
cairo_2_test_contracts: $(CAIRO_2_COMPILED_CASM_CONTRACTS)

cairo_proof_trace: $(CAIRO_TRACE_PROOF) $(CAIRO_MEM_PROOF) $(CAIRO_AIR_PUBLIC_INPUT)
cairo-vm_proof_trace: $(CAIRO_RS_TRACE_PROOF) $(CAIRO_RS_MEM_PROOF) $(CAIRO_RS_AIR_PUBLIC_INPUT)

cairo_trace: $(CAIRO_TRACE) $(CAIRO_MEM)
cairo-vm_trace: $(CAIRO_RS_TRACE) $(CAIRO_RS_MEM)

test: cairo_proof_programs cairo_test_programs cairo_1_test_contracts cairo_2_test_contracts
	cargo llvm-cov nextest --no-report --workspace --features "test_utils, cairo-1-hints"
test-no_std: cairo_proof_programs cairo_test_programs
	cargo llvm-cov nextest --no-report --workspace --features test_utils --no-default-features
test-wasm: cairo_proof_programs cairo_test_programs
	# NOTE: release mode is needed to avoid "too many locals" error
	wasm-pack test --release --node vm --no-default-features

check-fmt:
	cargo fmt --all -- --check
	cargo fmt --manifest-path fuzzer/Cargo.toml --all -- --check

clippy:
	cargo clippy --workspace --all-features --benches --examples --tests -- -D warnings
	cargo clippy --manifest-path fuzzer/Cargo.toml --all-targets

coverage:
	cargo llvm-cov report --lcov --output-path lcov.info

coverage-clean:
	cargo llvm-cov clean

benchmark: cairo_bench_programs
	cargo criterion --bench criterion_benchmark
	@echo 'Report: target/criterion/reports/index.html'

benchmark-action: cairo_bench_programs
	cargo bench --bench criterion_benchmark -- --output-format bencher |sed 1d | tee output.txt

iai-benchmark-action: cairo_bench_programs
	cargo bench --bench iai_benchmark

flamegraph:
	cargo flamegraph --root --bench criterion_benchmark -- --bench

compare_benchmarks: cairo_bench_programs
	cd bench && ./run_benchmarks.sh

compare_trace_memory: $(CAIRO_RS_TRACE) $(CAIRO_TRACE) $(CAIRO_RS_MEM) $(CAIRO_MEM)
	cd vm/src/tests; ./compare_vm_state.sh trace memory

compare_trace: $(CAIRO_RS_TRACE) $(CAIRO_TRACE)
	cd vm/src/tests; ./compare_vm_state.sh trace

compare_memory: $(CAIRO_RS_MEM) $(CAIRO_MEM)
	cd vm/src/tests; ./compare_vm_state.sh memory

compare_trace_memory_proof: $(COMPILED_PROOF_TESTS) $(CAIRO_RS_TRACE_PROOF) $(CAIRO_TRACE_PROOF) $(CAIRO_RS_MEM_PROOF) $(CAIRO_MEM_PROOF)
	cd vm/src/tests; ./compare_vm_state.sh trace memory proof_mode

compare_all_proof: $(COMPILED_PROOF_TESTS) $(CAIRO_RS_TRACE_PROOF) $(CAIRO_TRACE_PROOF) $(CAIRO_RS_MEM_PROOF) $(CAIRO_MEM_PROOF) $(CAIRO_RS_AIR_PUBLIC_INPUT) $(CAIRO_AIR_PUBLIC_INPUT)
	cd vm/src/tests; ./compare_vm_state.sh trace memory proof_mode air_public_input

compare_trace_proof: $(CAIRO_RS_TRACE_PROOF) $(CAIRO_TRACE_PROOF)
	cd vm/src/tests; ./compare_vm_state.sh trace proof_mode

compare_memory_proof: $(CAIRO_RS_MEM_PROOF) $(CAIRO_MEM_PROOF)
	cd vm/src/tests; ./compare_vm_state.sh memory proof_mode

compare_air_public_input: $(CAIRO_RS_AIR_PUBLIC_INPUT) $(CAIRO_AIR_PUBLIC_INPUT)
	cd vm/src/tests; ./compare_vm_state.sh memory proof_mode air_public_input

# Run with nightly enable the `doc_cfg` feature wich let us provide clear explaination about which parts of the code are behind a feature flag
docs:
	RUSTDOCFLAGS="--cfg docsrs" cargo +nightly doc --verbose --release --locked --no-deps --all-features --open

clean:
	rm -f $(TEST_DIR)/*.json
	rm -f $(TEST_DIR)/*.memory
	rm -f $(TEST_DIR)/*.trace
	rm -f $(BENCH_DIR)/*.json
	rm -f $(BAD_TEST_DIR)/*.json
	rm -f $(PRINT_TEST_DIR)/*.json
	rm -f $(CAIRO_1_CONTRACTS_TEST_DIR)/*.sierra
	rm -f $(CAIRO_1_CONTRACTS_TEST_DIR)/*.casm
	rm -f $(TEST_PROOF_DIR)/*.json
	rm -f $(TEST_PROOF_DIR)/*.memory
	rm -f $(TEST_PROOF_DIR)/*.trace
	rm -f $(TEST_PROOF_DIR)/*.air_public_input
	rm -rf cairo-vm-env
	rm -rf cairo-vm-pypy-env
	rm -rf cairo
	rm -rf cairo1
	rm -rf cairo2
	rm -rf cairo-lang
	cd cairo1-run; make clean

fuzzer-deps: build
	cargo +nightly install cargo-fuzz
	. cairo-vm-env/bin/activate; \
		pip install atheris==2.2.2 maturin==1.2.3; \
		cd fuzzer/; \
		maturin develop

fuzzer-run-cairo-compiled:
	cd fuzzer
	cargo +nightly fuzz run --fuzz-dir . cairo_compiled_programs_fuzzer

fuzzer-run-hint-diff:
	. cairo-vm-env/bin/activate ; \
	cd fuzzer/diff_fuzzer/; \
	../../cairo-vm-env/bin/python random_hint_fuzzer.py -len_control=0

CAIRO_LANG_REPO_DIR=cairo-lang

$(CAIRO_LANG_REPO_DIR):
	git clone --depth=1 https://github.com/starkware-libs/cairo-lang

build-cairo-lang: | $(CAIRO_LANG_REPO_DIR)

hint-accountant: build-cairo-lang
	cargo r -p hint_accountant

