-include vars.mk

# Check if make supports .ONESHELL (GNU Make 3.82+)
ifeq ($(filter oneshell,$(.FEATURES)),)
$(error This Makefile requires GNU Make 3.82+ with .ONESHELL support. Current make version: $(MAKE_VERSION))
endif

.ONESHELL:
## Constants
DEBUG					?= 0
FORCE					?= 0
VENV_NAME				?= .venv
PY_EXEC					?= python3.11
GIT_COMMIT_HASH 		?= $(shell git rev-parse HEAD || true)
GIT_COMMIT_TAG			?= $(shell git tag --points-at=HEAD || true)
TS_FMT					?= %Y-%m-%dT%H:%M:%SZ%Z
TS_FMT_TAG				?= on-%Y-%m-%d-at-%H-%M-%S-tz-%Z
TIMESTAMP				?= $(shell date +$(TS_FMT) || true)
TIMESTAMP_TAG			?= $(shell date +$(TS_FMT_TAG) || true)
REPO_ROOT_DIR 			?= $(shell git rev-parse --show-toplevel || true)
PLAYBOOK_PY_REQS		?= playbooks/infra/generate_py_requirements.yml
PLAYBOOK_IMAGE			?= playbooks/infra/build-container.yml
CONTAINER_REGISTRY		?= quay.io/telcov10n
CONTAINERFILE			?= Containerfile
ENV_FILE				?= 
ANSIBLE_ARGS			?=
TBL_PRINT_SCRIPT		?= ./scripts/print_vars_as_table.py
INVENTORY				?= inventories/infra/build-container.yml
EXTRA_VARS				?=

# Requirements files
REQUIREMENTS_FILE		?= requirements.txt
REQUIREMENTS_IN_FILES	?= requirements.in requirements-dev.in

include functions.mk
## Variables calculated from functions
IMAGE					?= $(notdir $(REPO_ROOT_DIR))
PLAYBOOK				?= $(PLAYBOOK_IMAGE)
INVENTORY				:= $(call resolve_inventory,$(PLAYBOOK))
ANSIBLE_VERBOSITY		?= -v
# ANSIBLE_ARGS += $(ANSIBLE_VERBOSITY)
ifeq ($(DEBUG),1)
	ANSIBLE_VERBOSITY	:= -vvv
endif

## Targets
.PHONY: setup setup-dev print_vars run-ansible-playbook image-build


# Setup with existing requirements file
setup:
	@echo "Setting up development environment with $(REQUIREMENTS_FILE)"
	@test -f "$(REQUIREMENTS_FILE)" || (echo "ERROR: $(REQUIREMENTS_FILE) not found. Run 'make setup-dev' first." && exit 1)
	@$(call activate_venv_and_run, \
		python -m pip install --upgrade pip && \
		pip install -r $(REQUIREMENTS_FILE) && \
		echo "Dependencies installed successfully")
	@echo "Setup complete"

# Generate requirements from .in files and setup
setup-dev:
	@echo "Setting up development environment with pip-compile"
	@$(call activate_venv_and_run, \
		python -m pip install --upgrade pip && \
		pip install pip-tools && \
		echo "Compiling requirements from: $(REQUIREMENTS_IN_FILES)" && \
		pip-compile --quiet --strip-extras -o $(REQUIREMENTS_FILE) $(REQUIREMENTS_IN_FILES) && \
		echo "Requirements compiled to $(REQUIREMENTS_FILE)")
	@echo "Running setup with compiled requirements..."
	@$(MAKE) setup REQUIREMENTS_FILE=$(REQUIREMENTS_FILE) FORCE=0


print_vars:
	echo "Printing variables:"; \
	source "$(VENV_NAME)/bin/activate" || (echo "Venv $(VENV_NAME) not found. run setup/setup-dev first" && exit 1) && \
	export GIT_COMMIT_HASH="$(GIT_COMMIT_HASH)" && \
	export GIT_COMMIT_TAG="$(GIT_COMMIT_TAG)" && \
	export TIMESTAMP="$(TIMESTAMP)" && \
	export TIMESTAMP_TAG="$(TIMESTAMP_TAG)" && \
	export REPO_ROOT_DIR="$(REPO_ROOT_DIR)" && \
	export PLAYBOOK_PY_REQS="$(PLAYBOOK_PY_REQS)" && \
	export PLAYBOOK_IMAGE="$(PLAYBOOK_IMAGE)" && \
	export CONTAINER_REGISTRY="$(CONTAINER_REGISTRY)" && \
	export CONTAINERFILE="$(CONTAINERFILE)" && \
	export ENV_FILE="$(ENV_FILE)" && \
	export IMAGE="$(IMAGE)" && \
	export PLAYBOOK="$(PLAYBOOK)" && \
	export INVENTORY="$(INVENTORY)" && \
	export ANSIBLE_ARGS="$(ANSIBLE_ARGS)" && \
	export ANSIBLE_VERBOSITY="$(ANSIBLE_VERBOSITY)" && \
	export EXTRA_VARS="$(call resolve_extra_vars_file,$(PLAYBOOK))" && \
	$(PY_EXEC) $(TBL_PRINT_SCRIPT) \
		GIT_COMMIT_HASH \
		GIT_COMMIT_TAG \
		TIMESTAMP \
		TIMESTAMP_TAG \
		REPO_ROOT_DIR \
		PLAYBOOK_PY_REQS \
		PLAYBOOK_IMAGE \
		CONTAINER_REGISTRY \
		CONTAINERFILE \
		ENV_FILE \
		IMAGE \
		PLAYBOOK \
		INVENTORY \
		ANSIBLE_ARGS \
		ANSIBLE_VERBOSITY \
		EXTRA_VARS

run-ansible-playbook:
	source "$(VENV_NAME)/bin/activate" || (echo "Venv $(VENV_NAME) not found. run setup/setup-dev first" && exit 1) && \
	export EXTRA_VARS="$(if $(call resolve_extra_vars_file,$(PLAYBOOK)),$(call resolve_extra_vars_file,$(PLAYBOOK)),) $(EXTRA_VARS)" && \
	export ANSIBLE_ARGS="$${EXTRA_VARS} $(ANSIBLE_VERBOSITY) $(ANSIBLE_ARGS)" && \
	export GIT_COMMIT_HASH="$(GIT_COMMIT_HASH)" && \
	export GIT_COMMIT_TAG="$(GIT_COMMIT_TAG)" && \
	export TIMESTAMP="$(TIMESTAMP)" && \
	export TIMESTAMP_TAG="$(TIMESTAMP_TAG)" && \
	$(PY_EXEC) $(TBL_PRINT_SCRIPT) \
		EXTRA_VARS \
		ANSIBLE_ARGS \
		GIT_COMMIT_HASH \
		GIT_COMMIT_TAG \
		TIMESTAMP \
		TIMESTAMP_TAG && \
	echo "================ ansible-playbook command ==================" && \
	echo "Running: ansible-playbook -i $(INVENTORY) $(PLAYBOOK) $${ANSIBLE_ARGS}"; \
	ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" $${ANSIBLE_ARGS}


image-build:
	$(MAKE) run-ansible-playbook PLAYBOOK=playbooks/infra/build-container.yml
