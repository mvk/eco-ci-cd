# =============================================================================
# Builder stage - heavy operations and build dependencies
FROM registry.access.redhat.com/ubi9/ubi AS builder

WORKDIR /eco-ci-cd

# Install required packages (including any build dependencies)
RUN dnf -y install --setopt=install_weak_deps=False --setopt=tsdocs=False \
    git \
    python3.11 \
    python3.11-pip \
    sshpass \
    && dnf clean all

# Install ansible and ansible-lint to a target directory
RUN mkdir -p /opt/python-packages && \
    python3.11 -m pip install \
        --upgrade \
        --prefer-binary \
        --no-cache-dir \
        --prefix /opt/python-packages \
        pip && \
    python3.11 -m pip install \
        --prefer-binary \
        --no-cache-dir \
        --prefix /opt/python-packages \
            ansible \
            jira \
            jmespath \
            ncclient \
            netaddr \
            paramiko \
            requests

# Copy application files to eco-ci-cd folder
COPY . .

# Install requirements to a specific directory
RUN mkdir -p /opt/ansible-collections && \
    export PATH="/opt/python-packages/bin:$PATH" && \
    export PYTHONPATH="/opt/python-packages/lib64/python3.11/site-packages:/opt/python-packages/lib/python3.11/site-packages:$PYTHONPATH" && \
    export ANSIBLE_COLLECTIONS_PATH="/opt/ansible-collections" && \
    echo "Installing collections" && \
    ansible-galaxy \
        collection install \
            --no-cache \
            --force \
            --pre \
            -r requirements.yml

# =============================================================================
# Runtime stage - minimal final image
FROM registry.access.redhat.com/ubi9/ubi AS runtime

# Set up Python path for installed packages
ENV PYTHONPATH="/opt/python-packages/lib64/python3.11/site-packages:/opt/python-packages/lib/python3.11/site-packages:${PYTHONPATH}"
ENV PATH="/opt/python-packages/bin:${PATH}"

WORKDIR /eco-ci-cd

# Install only runtime dependencies
RUN dnf -y install --setopt=install_weak_deps=False --setopt=tsdocs=False \
    git \
    sshpass \
    python3.11 \
    python3.11-pip \
    && dnf clean all

# Copy Python packages from builder stage
COPY --from=builder /opt/python-packages /opt/python-packages

# Copy Ansible collections from builder stage
COPY --from=builder /opt/ansible-collections /usr/share/ansible/collections

# Copy application files from builder stage
COPY --from=builder /eco-ci-cd /eco-ci-cd

# Set entrypoint to bash
ENTRYPOINT ["/bin/bash"]