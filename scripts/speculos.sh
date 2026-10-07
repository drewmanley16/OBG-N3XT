#!/usr/bin/env bash
# Runs Ledger's official device emulator (Speculos) with the Ethereum app,
# so the app can be built and demoed without a physical Ledger.
#   Device screen: http://localhost:5005  (click or hold the buttons there)
set -euo pipefail
MODEL="${MODEL:-flex}"            # flex | stax | nanox | nanosp | apex_p (nanosp file is named nanos2)
ETH_APP_VERSION="${ETH_APP_VERSION:-1.22.3}"
DIR="$(cd "$(dirname "$0")/.." && pwd)/speculos/apps"
FILE="eth-$MODEL-$ETH_APP_VERSION.elf"
ASSET_MODEL="$MODEL"; [ "$MODEL" = "nanosp" ] && ASSET_MODEL="nanos2"

mkdir -p "$DIR"
if [ ! -f "$DIR/$FILE" ]; then
  echo "Downloading Ledger Ethereum app $ETH_APP_VERSION for $MODEL..."
  curl -fsSL -o "$DIR/$FILE" \
    "https://github.com/LedgerHQ/app-ethereum/releases/download/$ETH_APP_VERSION/app-$ETH_APP_VERSION-$ASSET_MODEL.elf"
fi

docker rm -f speculos >/dev/null 2>&1 || true
# Port 5000 is taken by AirPlay on macOS, so the API is exposed on 5005.
docker run -d --name speculos -p 5005:5000 -p 9999:9999 -v "$DIR:/apps" \
  ghcr.io/ledgerhq/speculos:latest \
  --model "$MODEL" --display headless --api-port 5000 --apdu-port 9999 "/apps/$FILE" >/dev/null
echo "Speculos ($MODEL) running. Device screen: http://localhost:5005"
