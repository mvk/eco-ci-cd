# =============================================================================
# Single-stage build for eco-ci-cd optimized for size
FROM registry.redhat.io/ubi9/ubi-minimal:latest

ARG ANSIBLE_COLLECTIONS_PATH=${ANSIBLE_COLLECTIONS_PATH:-"/usr/share/ansible/collections"}
ARG PY_EXEC=${PY_EXEC:-"python3.11"}
ARG WORKDIR=${WORKDIR:-"/eco-ci-cd"}
ARG VENV_DIR=${VENV_DIR:-"${WORKDIR}/.venv"}
ARG USE_VENV=${USE_VENV:-1}
# settings for dnf:
# ARG OPTS_DNF=${OPTS_DNF:-"--setopt=install_weak_deps=False --setopt=tsdocs=False"}
# settings for microdnf:
ARG OPTS_DNF=${OPTS_DNF:-" --nodocs --setopt=install_weak_deps=0"}
ARG OPTS_PIP=${OPTS_PIP:-"--prefer-binary --no-cache-dir --no-compile"}
ARG OPTS_GALAXY=${OPTS_GALAXY:-"--no-cache --force --pre"}
ARG DEV_MODE=${DEV_MODE:-0}
ARG DEV_DNF_PACKAGES=${DEV_DNF_PACKAGES:-""}
ARG DEV_PIP_PACKAGES=${DEV_PIP_PACKAGES:-""}
ARG PIP_REQS=${PIP_REQS:-"requirements.txt"}

# Set up environment variables
ENV ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR "${WORKDIR}"

# Install packages with microdnf
RUN microdnf -y update $OPTS_DNF && \
    # Install only essential runtime packages
    microdnf -y install $OPTS_DNF \
        alternatives \
        findutils \
        git-core \
        ${PY_EXEC} \
        ${PY_EXEC}-pip \
        openssh-clients \
        which && \
    # Install dev mode optional packages
    if [ "${DEV_MODE}" != "0" ]; then \
        if [ -n "${DEV_DNF_PACKAGES}" ]; then \
            microdnf -y install $OPTS_DNF $DEV_DNF_PACKAGES; \
        fi; \
    fi && \
    # set PY_EXEC to be the python3 alternative
    alternatives --install /usr/bin/python3 python3 /usr/bin/${PY_EXEC} 10 && \
    alternatives --auto python3 && \
    # Clean package manager cache immediately
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Copy all essential files (controlled by .dockerignore negative patterns)
COPY . .

# Clean up venv directory if .dockerignore/.containerignore accidentally included ${VENV_DIR}
RUN test -d "${VENV_DIR}" && (rm -rf "${VENV_DIR}" && echo "Deleted pre-existing ${VENV_DIR}") || true && \
    # Create venv and install Python packages in one layer
    if [ "${USE_VENV}" -eq 1 ]; then \
        "${PY_EXEC}" -m venv "${VENV_DIR}" && \
        source "${VENV_DIR}/bin/activate" && \
        echo "Installing into Python of venv: ${VENV_DIR}"; \
    else \
        echo "Installing into system Python (no venv/virtualenv)"; \
    fi && \
    ${PY_EXEC} -m pip install $OPTS_PIP --upgrade pip setuptools && \
    echo "Installing packages...from ${PIP_REQS}" && \
    ${PY_EXEC} -m pip install $OPTS_PIP -r ${PIP_REQS} && \
    echo "Verifying ansible installation..." && \
    ${PY_EXEC} -c "import ansible; print(f'Ansible {ansible.__version__} installed successfully')" && \
    if [ "${DEV_MODE}" -gt 0 ] && [ -n "${DEV_PIP_PACKAGES}" ]; then \
        ${PY_EXEC} -m pip install $OPTS_PIP $DEV_PIP_PACKAGES; \
    fi && \
    # Clean pip cache
    ${PY_EXEC} -m pip cache purge

# Install Ansible collections requirements
RUN mkdir -p "${ANSIBLE_COLLECTIONS_PATH}" && \
    export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH}" && \
    echo "Installing collections" && \
    if [ "${USE_VENV}" -eq 1 ]; then \
        source "${VENV_DIR}/bin/activate"; \
    fi && \
    ansible-galaxy collection install $OPTS_GALAXY -r requirements.yml && \
    # Clean up galaxy cache
    rm -rf ~/.ansible/tmp/ && \
    # Remove unnecessary files
    find "${WORKDIR}" -name "*.pyc" -delete && \
    find "${WORKDIR}" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true && \
    # Setup entrypoint
    chmod +x "${WORKDIR}/entrypoint.sh" && \
    echo "Created entrypoint"

# Set entrypoint (when USE_VENV=1, it activates venv)
ENTRYPOINT ["/eco-ci-cd/entrypoint.sh"]
CMD ["/bin/bash"]
