#!/usr/bin/env bash
set -euo pipefail

# This script runs inside the dev container once after creation.
# It installs Pyfhel (with required SEAL flag change), TenSEAL, PyTorch CPU, and this repo in editable mode.

# Determine workspace root
if [[ -d "/workspaces/PyCrCNN" ]]; then
  ROOT_DIR="/workspaces/PyCrCNN"
else
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  ROOT_DIR="$(pwd)"
fi
cd "${ROOT_DIR}"

# Create and use a virtualenv inside the workspace (postCreate has proper permissions)
VENV_CANDIDATE="/workspaces/.venv"
if [[ -d "/workspaces" ]] && [[ ! -d "${VENV_CANDIDATE}" ]]; then
  python -m venv "${VENV_CANDIDATE}" || true
fi

# Fallback to home directory venv if workspace venv couldn't be created
if [[ ! -d "${VENV_CANDIDATE}" ]]; then
  VENV_CANDIDATE="$HOME/.venvs/pycrcnn"
  mkdir -p "$(dirname "${VENV_CANDIDATE}")"
  if [[ ! -d "${VENV_CANDIDATE}" ]]; then
    python -m venv "${VENV_CANDIDATE}" || true
  fi
fi

if [[ -d "${VENV_CANDIDATE}" ]]; then
  # shellcheck disable=SC1091
  source "${VENV_CANDIDATE}/bin/activate"
fi


python -V
pip -V

# 升级 numpy 和 sympy 到最新版，避免依赖冲突
pip install --upgrade numpy sympy

# Install PyTorch CPU wheels and common scientific stack
pip install --upgrade pip setuptools wheel
pip install --index-url https://download.pytorch.org/whl/cpu \
  torch torchvision torchaudio --extra-index-url https://pypi.org/simple || true

PYFHEL_DIR="${HOME}/Pyfhel"
# If Pyfhel exists in workspace (old behavior), move it out to avoid import shadowing
if [[ -d "${ROOT_DIR}/Pyfhel" && "${ROOT_DIR}/Pyfhel" != "${PYFHEL_DIR}" ]]; then
  echo "[setup] Detected Pyfhel in workspace. Moving it to ${PYFHEL_DIR} to avoid import shadowing..."
  if [[ ! -d "${PYFHEL_DIR}" ]]; then
    mkdir -p "${HOME}"
    mv "${ROOT_DIR}/Pyfhel" "${PYFHEL_DIR}" || true
  else
    echo "[setup] ${PYFHEL_DIR} already exists; removing workspace copy."
    rm -rf "${ROOT_DIR}/Pyfhel" || true
  fi
fi

# Clone Pyfhel if not present, initialize submodules
if [[ ! -d "${PYFHEL_DIR}" ]]; then
  git clone --recursive https://github.com/ibarrond/Pyfhel.git "${PYFHEL_DIR}"
else
  echo "[setup] Pyfhel already present at ${PYFHEL_DIR}; pulling latest..."
  git -C "${PYFHEL_DIR}" pull --rebase || true
  git -C "${PYFHEL_DIR}" submodule update --init --recursive || true
fi

# Apply required change: disable SEAL throw on transparent ciphertext
if grep -q "SEAL_THROW_ON_TRANSPARENT_CIPHERTEXT='ON'" "${PYFHEL_DIR}/pyproject.toml"; then
  sed -i "s/SEAL_THROW_ON_TRANSPARENT_CIPHERTEXT='ON'/SEAL_THROW_ON_TRANSPARENT_CIPHERTEXT='OFF'/" "${PYFHEL_DIR}/pyproject.toml"
fi

# Build and install Pyfhel
pip install -e "${PYFHEL_DIR}"

# Install TenSEAL
pip install tenseal

# Install dev dependencies and this package
if [[ -f "${ROOT_DIR}/requirements.txt" ]]; then
  # Avoid reinstalling Pyfhel/pycrcnn and torch family (installed separately above); also skip pytest
  grep -Ev "^(Pyfhel|pycrcnn|torch|torchaudio|torchvision|pytest)" "${ROOT_DIR}/requirements.txt" > /tmp/req.txt || true
  if [[ -s "/tmp/req.txt" ]]; then
    pip install -r /tmp/req.txt || true
  fi
fi

# Install current project in editable mode (PEP 660 if pyproject.toml exists)
if [[ -f "${ROOT_DIR}/pyproject.toml" ]]; then
  pip install --editable "${ROOT_DIR}"
else
  pip install -e "${ROOT_DIR}"
fi

echo "[setup] Dev container setup complete."
