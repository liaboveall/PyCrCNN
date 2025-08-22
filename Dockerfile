FROM python:3.10-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies for Pyfhel/TenSEAL
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    git build-essential cmake ninja-build \
    libgmp-dev libboost-all-dev \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy current repository instead of cloning inside the image
COPY . /workspace

# Upgrade pip toolchain
RUN python -m pip install --upgrade pip setuptools wheel

# Install PyTorch CPU wheels only for torch family
RUN pip install --index-url https://download.pytorch.org/whl/cpu \
    torch torchvision torchaudio \
    --extra-index-url https://pypi.org/simple

# Clone and install Pyfhel (disable throw on transparent ciphertext)
RUN git clone --recursive https://github.com/ibarrond/Pyfhel.git /opt/Pyfhel \
    && sed -i "s/SEAL_THROW_ON_TRANSPARENT_CIPHERTEXT='ON'/SEAL_THROW_ON_TRANSPARENT_CIPHERTEXT='OFF'/" /opt/Pyfhel/pyproject.toml \
    && pip install -e /opt/Pyfhel

# TenSEAL
RUN pip install tenseal

# Optional: install other requirements, excluding local Pyfhel/pycrcnn entries
RUN if [ -f requirements.txt ]; then \
    grep -Ev "^(Pyfhel|pycrcnn)" requirements.txt > /tmp/req.txt || true; \
    if [ -s /tmp/req.txt ]; then pip install -r /tmp/req.txt; fi; \
    fi

# Install this project in editable mode
RUN pip install -e .

EXPOSE 8888 5000

# Default to bash; override with docker run ... if needed
CMD ["bash"]


