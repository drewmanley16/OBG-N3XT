#!/usr/bin/env bash
# A second emulated Ledger for the school, with its own seed (so its own address).
# Device screen: http://localhost:5006
NAME=speculos-school PORT=5006 \
SEED="${SEED:-abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about}" \
  exec "$(dirname "$0")/speculos.sh"
