# sml-semver build
#
#   make            build the test binary with MLton (default)
#   make test       build + run tests under MLton
#   make test-poly  run tests under Poly/ML (use-and-run; no link step)
#   make all-tests  run the suite under both compilers
#   make example    build + run the demo
#   make clean      remove build artifacts
#
# Layout B (dependent): own sources live in src/; sml-parsec is vendored under
# lib/ and loaded first (it brings `structure CharParsec` into scope, which the
# semver sources build their grammar on).

MLTON      ?= mlton
POLY       ?= poly
BIN        := bin
PARSECDIR  := lib/github.com/sjqtentacles/sml-parsec
TEST_MLB   := test/test.mlb
SRCS       := $(wildcard $(PARSECDIR)/* src/* test/*.sml) $(TEST_MLB)

.PHONY: all test poly test-poly all-tests example clean

all: $(BIN)/test-mlton

example: $(BIN)/demo
	./$(BIN)/demo

$(BIN)/demo: $(SRCS) examples/demo.sml examples/sources.mlb | $(BIN)
	$(MLTON) -output $@ examples/sources.mlb

$(BIN)/test-mlton: $(SRCS) | $(BIN)
	$(MLTON) -output $@ $(TEST_MLB)

test: $(BIN)/test-mlton
	$(BIN)/test-mlton

# Poly/ML has no native .mlb support; the suite runs at top level and exits on
# its own. Load the vendored sml-parsec sources (in parsec.mlb dependency
# order), then the semver sources, then the test driver.
poly test-poly:
	printf 'use "$(PARSECDIR)/stream.sig";\nuse "$(PARSECDIR)/parsec.sig";\nuse "$(PARSECDIR)/parsecfn.sml";\nuse "$(PARSECDIR)/charstream.sml";\nuse "$(PARSECDIR)/charparseccore.sml";\nuse "$(PARSECDIR)/charparsec.sig";\nuse "$(PARSECDIR)/charparsec.sml";\nuse "$(PARSECDIR)/expr.sig";\nuse "$(PARSECDIR)/exprfn.sml";\nuse "$(PARSECDIR)/charexpr.sml";\nuse "$(PARSECDIR)/tokenstream.sml";\nuse "src/semver.sig";\nuse "src/semver.sml";\nuse "test/harness.sml";\nuse "test/support.sml";\nuse "test/test_parse.sml";\nuse "test/test_compare.sml";\nuse "test/test_range.sml";\nuse "test/entry.sml";\nuse "test/main.sml";\n' | $(POLY) -q --error-exit

all-tests: test test-poly

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -f $(BIN)/test-mlton $(BIN)/demo
