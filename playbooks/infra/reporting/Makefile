# Simplified Makefile for infra/reporting
# This now defers to the root Makefile for most operations

REPO_ROOT := $(shell git rev-parse --show-toplevel)
TARGET_DIR := $(CURDIR)

# Default CI type
CI_TYPE ?= dci

# Backward compatibility targets - defer to root Makefile
bootstrap:
	@cd $(REPO_ROOT) && $(MAKE) bootstrap

test:
	@cd $(REPO_ROOT) && $(MAKE) test TARGET_DIR=$(TARGET_DIR) CI_TYPE=$(CI_TYPE)

test-verify:
	@cd $(REPO_ROOT) && $(MAKE) test-verify TARGET_DIR=$(TARGET_DIR) CI_TYPE=$(CI_TYPE)

retest:
	@cd $(REPO_ROOT) && $(MAKE) retest TARGET_DIR=$(TARGET_DIR) CI_TYPE=$(CI_TYPE)

ansible-lint:
	@cd $(REPO_ROOT) && $(MAKE) ansible-lint TARGET_DIR=$(TARGET_DIR)

# Python testing (pytest) for local tools
pytest:
	@cd $(REPO_ROOT) && source .venv/bin/activate && pytest -v $(TARGET_DIR)/tools

# Legacy targets that are now obsolete
gendata render run-playbook reset-collections-reqs clean-caches:
	@echo "⚠️  Target '$@' is obsolete. Use simplified targets: bootstrap, test, test-verify, retest"
	@echo "💡 For CI_TYPE specific tests: make test CI_TYPE=jenkins"

# Show available targets
help:
	@echo "Available targets:"
	@echo "  bootstrap     - Set up environment (venv + ansible collections)"
	@echo "  test          - Run tests (auto-discover python + ansible)"
	@echo "  test-verify   - Verify test results against expected output"
	@echo "  retest        - Clean rebuild + test + verify"
	@echo "  ansible-lint  - Run ansible-lint on this directory"
	@echo "  pytest        - Run pytest on tools/ directory"
	@echo ""
	@echo "Variables:"
	@echo "  CI_TYPE       - Set CI type for testing (default: dci)"
	@echo "                  Available: $(shell find fixtures -maxdepth 1 -type d -exec basename {} \\; 2>/dev/null | grep -v fixtures | tr '\\n' ' ')"
	@echo ""
	@echo "Examples:"
	@echo "  make test                    # Test with default CI_TYPE=dci"
	@echo "  make test CI_TYPE=jenkins    # Test with jenkins fixtures"
	@echo "  make retest CI_TYPE=github   # Full clean test cycle"

.PHONY: bootstrap test test-verify retest ansible-lint pytest help gendata render run-playbook reset-collections-reqs clean-caches