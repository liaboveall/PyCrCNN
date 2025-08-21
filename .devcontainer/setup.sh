#!/usr/bin/env bash
set -euo pipefail

# This script runs inside the dev container once after creation.
# It installs Pyfhel (with required SEAL flag change), TenSEAL, PyTorch CPU, and this repo in editable mode.

: "${WORKSPACE:-/workspaces/PyCrCNN}" # VS Code mounts workspace at /workspaces/<name>

# Ensure we're in the workspace root
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT_DIR="$(pwd)"

# Use the virtual env created in Dockerfile
if [[ -d "/workspaces/.venv" ]]; then
  source /workspaces/.venv/bin/activate
fi

python -V
pip -V

# Install PyTorch CPU wheels and common scientific stack
pip install --upgrade pip setuptools wheel
pip install --index-url https://download.pytorch.org/whl/cpu \
  torch torchvision torchaudio --extra-index-url https://pypi.org/simple

# Clone Pyfhel if not present, initialize submodules
if [[ ! -d "${ROOT_DIR}/Pyfhel" ]]; then
  git clone --recursive https://github.com/ibarrond/Pyfhel.git "${ROOT_DIR}/Pyfhel"
else
  echo "Pyfhel already cloned; pulling latest..."
  git -C "${ROOT_DIR}/Pyfhel" pull --rebase || true
  git -C "${ROOT_DIR}/Pyfhel" submodule update --init --recursive || true
fi

# Apply required change: disable SEAL throw on transparent ciphertext
if grep -q "SEAL_THROW_ON_TRANSPARENT_CIPHERTEXT='ON'" "${ROOT_DIR}/Pyfhel/pyproject.toml"; then
  sed -i "s/SEAL_THROW_ON_TRANSPARENT_CIPHERTEXT='ON'/SEAL_THROW_ON_TRANSPARENT_CIPHERTEXT='OFF'/" "${ROOT_DIR}/Pyfhel/pyproject.toml"
fi

# Build and install Pyfhel
pip install -e "${ROOT_DIR}/Pyfhel"

# Install TenSEAL
pip install tenseal

# Install dev dependencies and this package
if [[ -f "${ROOT_DIR}/requirements.txt" ]]; then
  # Avoid reinstalling Pyfhel from local path in requirements; ignore that line if present
  grep -v "^Pyfhel" "${ROOT_DIR}/requirements.txt" > /tmp/req.txt || true
  pip install -r /tmp/req.txt || true
fi

# Install current project in editable mode
pip install -e "${ROOT_DIR}"

# Optional: pytest discovery sanity check
python - <<'PY'
import sys, subprocess
try:
    subprocess.run([sys.executable, '-m', 'pytest', '-q', '--collect-only'], check=True)
    print("[setup] pytest collection succeeded")
except subprocess.CalledProcessError as e:
    print("[setup] pytest collection failed (non-fatal):", e)
PY

echo "[setup] Dev container setup complete."
