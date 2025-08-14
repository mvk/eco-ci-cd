# =============================================================================
# Single-stage build for eco-ci-cd
FROM registry.redhat.io/ubi9/ubi-minimal:latest

ARG ANSIBLE_COLLECTIONS_PATH=${ANSIBLE_COLLECTIONS_PATH:-"/usr/share/ansible/collections"}
ARG PY_EXEC=${PY_EXEC:-"python3.11"}
ARG WORKDIR=${WORKDIR:-"/eco-ci-cd"}
ARG VENV_DIR=${VENV_DIR:-"${WORKDIR}/.venv"}
ARG USE_VENV=${USE_VENV:-1}
# dnf settings
# ARG OPTS_DNF=${OPTS_DNF:-"--setopt=install_weak_deps=False --setopt=tsdocs=False"}
# microdnf settings (does not support --setopt=tsdocs=False)
ARG OPTS_DNF=${OPTS_DNF:-" --nodocs --setopt=install_weak_deps=0"}
ARG OPTS_PIP=${OPTS_PIP:-"--prefer-binary --no-cache-dir"}
ARG OPTS_GALAXY=${OPTS_GALAXY:-"--no-cache --force --pre"}
ARG DEV_MODE=${DEV_MODE:-0}
ARG DEV_DNF_PACKAGES=${DEV_DNF_PACKAGES:-""}
ARG DEV_PIP_PACKAGES=${DEV_PIP_PACKAGES:-""}

# Set up environment variables
ENV ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH}"

WORKDIR "${WORKDIR}"

RUN microdnf -y update $OPTS_DNF && \
    # Install only essential runtime packages
    microdnf -y install $OPTS_DNF \
        ${PY_EXEC} \
        ${PY_EXEC}-pip \
        git-core \
        sshpass \
        which && \
    if [ "${DEV_MODE}" != "0" ]; then \
        if [ -n "${DEV_DNF_PACKAGES}" ]; then \
            microdnf -y install $OPTS_DNF $DEV_DNF_PACKAGES; \
        fi; \
    fi && \
    microdnf clean all

# Copy application files to eco-ci-cd folder
COPY . .

# Install ansible and ansible-lint to a target directory
RUN if [ "${USE_VENV}" -eq 1 ]; then \
        "${PY_EXEC}" -m venv "${VENV_DIR}" && \
        source "${VENV_DIR}/bin/activate"; \
    fi && \
    ${PY_EXEC} -m pip install $OPTS_PIP --upgrade pip setuptools && \
    ${PY_EXEC} -m pip install $OPTS_PIP -r ./requirements.txt && \
    if [ "${DEV_MODE}" != "0" ]; then \
        if [ -n "${DEV_PIP_PACKAGES}" ]; then \
            ${PY_EXEC} -m pip install $OPTS_PIP $DEV_PIP_PACKAGES; \
        fi; \
    fi

# Install requirements to a specific directory
RUN mkdir -p "${ANSIBLE_COLLECTIONS_PATH}" && \
    export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH}" && \
    echo "Installing collections" && \
    if [ "${USE_VENV}" -eq 1 ]; then \
        source "${VENV_DIR}/bin/activate"; \
    fi && \
    ansible-galaxy collection install $OPTS_GALAXY -r requirements.yml

# Create activation script for the virtual environment
RUN { \
        echo '#!/usr/bin/env bash'; \
        echo 'set -euo pipefail'; \
        if [ "${USE_VENV}" -eq 1 ]; then \
            echo "source ${VENV_DIR}/bin/activate"; \
        fi; \
        echo 'exec "$@"'; \
    } > "${WORKDIR}/entrypoint.sh" && \
    chmod +x "${WORKDIR}/entrypoint.sh"

# Set entrypoint
ENTRYPOINT ["/eco-ci-cd/entrypoint.sh"]
CMD ["/bin/bash"]
