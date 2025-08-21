FROM mcr.microsoft.com/devcontainers/python:3.10-bookworm

# System dependencies required for building Pyfhel (SEAL) and TenSEAL
USER root
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git build-essential cmake ninja-build \
    libgmp-dev libboost-all-dev \
    python3-dev python3-venv \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user if not provided by base image (devcontainers already has 'vscode')
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
RUN if ! id -u ${USERNAME} > /dev/null 2>&1; then \
    groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}; \
    fi

USER ${USERNAME}

# Create a virtualenv path for the workspace to isolate packages
ENV VENV_PATH=/workspaces/.venv
RUN python -m venv ${VENV_PATH}
ENV PATH=${VENV_PATH}/bin:${PATH}

# Pre-upgrade pip/setuptools/wheel
RUN python -m pip install --upgrade pip setuptools wheel