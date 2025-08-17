# Get the inventory path for a given playbook file., assuming convention
# If calculated inventory doesn't exist, fall back to INVENTORY variable
define resolve_inventory
$(strip \
  $(eval __inventory_file := $(subst playbooks,inventories,$(1))) \
  $(if $(wildcard $(__inventory_file)),$(__inventory_file),$(INVENTORY)) \
)
endef

# Get the extra vars file for a given playbook file, assuming convention
define resolve_extra_vars_file
$(strip \
  $(eval __extra_vars_file := vars/$(notdir $(1))) \
  $(if $(wildcard $(__extra_vars_file)),-e @$(__extra_vars_file),) \
)
endef

# Function to activate venv and run commands
define activate_venv_and_run
if [ ! -d "$(VENV_NAME)" ] || [ "$(FORCE)" -eq 1 ]; then \
	if [ -d "$(VENV_NAME)" ]; then \
		rm -rf "$(VENV_NAME)" && echo "Removed existing venv $(VENV_NAME) [REASON: FORCE=$(FORCE)]"; \
	fi; \
	$(PY_EXEC) -m venv "$(VENV_NAME)"; \
fi && \
source "$(VENV_NAME)/bin/activate" && \
$(1)
endef
