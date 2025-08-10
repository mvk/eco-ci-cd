FROM registry.access.redhat.com/ubi9/ubi:latest

# Automatic build arguments - these will be populated by podman
ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETOS
# Dynamic build arguments - these will be populated from Makefile
ARG GIT_WEB_URL
ARG GIT_COMMIT_HASH
ARG GIT_TAG
ARG IMAGE_VENDOR="Red Hat Inc."
ARG IMAGE_MAINTAINER="Telcov10n CI/CD Team"
ARG IMAGE_LICENSE="GPL-3.0"
ARG BUILD_DATE
ARG OC_MIRROR_URL
ARG OC_RELEASE
ARG OC_VERSION
ARG OC_ROOT_URL="${OC_MIRROR_URL}/openshift-v${OC_RELEASE}/clients/ocp/${OC_VERSION}"
ARG OC_PACKAGE="openshift-client-${TARGETOS}-${TARGETARCH}-rhel9-${OC_VERSION}.tar.gz"
ARG CHECKSUM="sha256sum"
# Configurable environment variables
# based on ARGs for the ability to override them by the caller (the Makefile)
ARG ANSIBLE_HOST_KEY_CHECKING=False
ARG ANSIBLE_STDOUT_CALLBACK=yaml
ARG ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections
ARG ANSIBLE_ROLES_PATH=/usr/share/ansible/roles
ARG PYTHONUNBUFFERED=1
ARG PYTHONDONTWRITEBYTECODE=1

# Set environment variables from ARGs
ENV ANSIBLE_HOST_KEY_CHECKING="${ANSIBLE_HOST_KEY_CHECKING}"
ENV ANSIBLE_STDOUT_CALLBACK="${ANSIBLE_STDOUT_CALLBACK}"
ENV ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_COLLECTIONS_PATH}"
ENV ANSIBLE_ROLES_PATH="${ANSIBLE_ROLES_PATH}"
ENV PYTHONUNBUFFERED="${PYTHONUNBUFFERED}"
ENV PYTHONDONTWRITEBYTECODE="${PYTHONDONTWRITEBYTECODE}"

# Essential labels for security/compliance and operational workflows
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="${IMAGE_MAINTAINER}" \
      org.opencontainers.image.vendor="${IMAGE_VENDOR}" \
      org.opencontainers.image.licenses="${IMAGE_LICENSE}" \
      org.opencontainers.image.source="${GIT_WEB_URL}.git" \
      org.opencontainers.image.revision="${GIT_COMMIT_HASH}" \
      org.opencontainers.image.version="${GIT_TAG}"


WORKDIR /eco-ci-cd

# Update system and install required packages
RUN dnf -y update && \
    dnf -y install --setopt=install_weak_deps=False --setopt=tsdocs=False \
        git \
        gzip \
        krb5-devel \
        krb5-libs \
        openssh-clients \
        python3.11 \
        python3.11-pip \
        python3.11-setuptools \
        python3.11-wheel \
        sshpass \
        tar \
    && \
    dnf clean all

# Download, extract, and clean up the OpenShift client binary (oc)
RUN if ! curl -LO -f "${OC_ROOT_URL}/${OC_PACKAGE}"; then rc=$?; echo "Failed to download ${OC_ROOT_URL}/${OC_PACKAGE} rc=${rc}"; exit "${rc}"; fi
RUN if ! curl -LO -f "${OC_ROOT_URL}/${CHECKSUM}.txt"; then rc=$?; echo "Failed to download ${OC_ROOT_URL}/${CHECKSUM}.txt rc=${rc}"; exit "${rc}"; fi
RUN if ! grep "${OC_PACKAGE}" "${CHECKSUM}.txt" | "${CHECKSUM}" -c -; then rc=$?; echo "Failed ${CHECKSUM} on ${OC_PACKAGE} rc=${rc}"; exit "${rc}"; fi

RUN tar -zxvf "${OC_PACKAGE}" && \
    mv oc /usr/local/bin/oc && \
    mv kubectl /usr/local/bin/kubectl && \
    rm "${OC_PACKAGE}" README.md "${CHECKSUM}.txt"
# Create directories and set permissions like AWX EE
### TODO: Remove this once we have a proper python version
RUN alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1 && \
    alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2

# Copy application files to eco-ci-cd folder
COPY . .

# Update pip, wheel, etc.
RUN python3.11 -m pip \
        install \
            --no-cache-dir \
            --upgrade \
            -r requirements-base.txt

# Install ansible and ansible-lint
RUN python3.11 -m pip \
        install \
            --no-cache-dir \
            -r requirements-container.txt

# Install requirements
RUN ansible-galaxy collection install --force -r requirements.yml

# Set entrypoint to bash
ENTRYPOINT ["/bin/bash"]
