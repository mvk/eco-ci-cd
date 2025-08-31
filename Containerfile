ARG BASE_IMAGE=${BASE_IMAGE:-"registry.access.redhat.com/ubi9/ubi"}
ARG BASE_TAG=${BASE_TAG:-"latest"}

# Base image
FROM ${BASE_IMAGE}:${BASE_TAG}

## Build-time variables
ARG BUILD_DATE
ARG DEV_MODE=${DEV_MODE:-0}
ARG WORKDIR=${WORKDIR:-"/eco-ci-cd"}
ARG PYTHON_VERSION=${PYTHON_VERSION:-"3.12"}
ARG PY_EXEC=${PY_EXEC:-"python${PYTHON_VERSION}"}
ARG PKG_MANAGER=${PKG_MANAGER:-"dnf"}
ARG PKG_MANAGER_OPTS=${PKG_MANAGER_OPTS:-"--setopt=install_weak_deps=False --setopt=tsdocs=False"}
# on image ubi-minimal, use (uncomment or pass build-arg) the following 2 lines:
#ARG PKG_MANAGER=${PKG_MANAGER:-"microdnf"}
#ARG PKG_MANAGER_OPTS=${PKG_MANAGER_OPTS:-"--nodocs --setopt=install_weak_deps=0"}
ARG VENV_ENABLE=${VENV_ENABLE:-1}
ARG VENV_DIR=${VENV_DIR:-".venv"}
ARG PIP_OPTS=${PIP_OPTS:-"--prefer-binary --no-cache-dir --no-compile"}
ARG GALAXY_OPTS=${GALAXY_OPTS:-"--no-cache --pre --force"}
# User and group configuration
ARG USER=${USER:-"runner"}
ARG GROUP=${GROUP:-${USER}}
ARG UID=${UID:-1001}
ARG GID=${GID:-${UID}}

## Run-time variables
ARG ANSIBLE_COLLECTIONS_PATH=${ANSIBLE_COLLECTIONS_PATH:-"/usr/share/ansible/collections"}
ARG PYTHONDONTWRITEBYTECODE=${PYTHONDONTWRITEBYTECODE:-1}
ARG PYTHONUNBUFFERED=${PYTHONUNBUFFERED:-1}

# Set up environment variables
ENV ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH}" \
    PYTHONDONTWRITEBYTECODE="${PYTHONDONTWRITEBYTECODE}" \
    PYTHONUNBUFFERED="${PYTHONUNBUFFERED}" \
    VENV_DIR="${VENV_DIR}"

WORKDIR "${WORKDIR}"

USER root
# Ensure group and user
RUN grep "^${GROUP}:x:${GID}:" /etc/group || \
    (groupadd -g ${GID} ${GROUP} && \
    echo "Created missing group ${GROUP} (gid=${GID})")
RUN grep "^${USER}:x:${UID}:${GID}:" /etc/passwd || \
    (useradd -u ${UID} -g ${GID} -m ${USER} && \
    echo "Created user ${USER} (uid=${UID}, gid=${GID})")
# Install packages using PKG_MANAGER
RUN ${PKG_MANAGER} -y update ${PKG_MANAGER_OPTS} && \
    ${PKG_MANAGER} -y install ${PKG_MANAGER_OPTS} \
        alternatives \
        findutils \
        git-core \
        openssh-clients \
        which \
        ${PY_EXEC} \
        ${PY_EXEC}-lxml \
        ${PY_EXEC}-pip && \
    # Set alternatives for PY_EXEC to be the highest priority (10)
    alternatives --install /usr/bin/python3 python3 /usr/bin/${PY_EXEC} 10 && \
    alternatives --auto python3 && \
    # Clean package manager cache immediately
    ${PKG_MANAGER} clean all && \
    rm -rf /var/cache/yum /var/cache/dnf && \
    # Clean up venv directory if .dockerignore/.containerignore accidentally included ${VENV_DIR}
    rm -fr "${VENV_DIR}"

# Copy all essential files (controlled by .dockerignore negative patterns)
COPY . .
# Setup entrypoint
RUN \
    chown -R "${UID}:${GID}" "${WORKDIR}" && \
    chmod +x "./entrypoint.sh" && \
    mkdir -p "${ANSIBLE_COLLECTIONS_PATH}" && \
    chown -R "${UID}:${GID}" "${ANSIBLE_COLLECTIONS_PATH}"

# Run as user
USER "${USER}"
# Install Python packages in one layer
## When VENV_ENABLE, setup venv + activate it
RUN test "${VENV_ENABLE}" -eq 1 && ${PY_EXEC} -m venv "${VENV_DIR}" || true && \
    test "${VENV_ENABLE}" -eq 1 && source "${VENV_DIR}/bin/activate" || true && \
    ${PY_EXEC} -m pip install ${PIP_OPTS} --upgrade pip && \
    test "${VENV_ENABLE}" -eq 1 || PIP_OPTS="--user ${PIP_OPTS}" && \
    test "${VENV_ENABLE}" -eq 1 || export PATH="${HOME}/.local/bin:${PATH}" && \
    ${PY_EXEC} -m pip install ${PIP_OPTS} -r requirements.txt && \
    # Remove unnecessary files
    find "${WORKDIR}" -name "*.pyc" -delete && \
    find "${WORKDIR}" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true && \
    # Clean pip cache
    ${PY_EXEC} -m pip cache purge

# Install Ansible collections requirements
RUN export PATH="${HOME}/.local/bin:${PATH}" && \
    export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH}" && \
    test "${VENV_ENABLE}" -eq 1 && source "${VENV_DIR}/bin/activate" || true && \
    ansible-galaxy collection install ${GALAXY_OPTS} -r requirements.yml && \
    # Clean up galaxy cache
    rm -rf ~/.ansible/tmp
ENTRYPOINT ["./entrypoint.sh"]
CMD ["/bin/bash"]
