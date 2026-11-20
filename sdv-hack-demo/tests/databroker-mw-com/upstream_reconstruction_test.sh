#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
    echo "Usage: bash $0 <databroker-git> <incubation-git> <proto-git>" >&2
    exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${repo_root}/sdv-hack-demo/patches/databroker-baseline.env"
temp="$(mktemp -d)"
trap 'rm -rf -- "$temp"' EXIT
fixture="$temp/repo"
broker="$fixture/kuksa-databroker"
mkdir -p "$broker" "$fixture/sdv-hack-demo/scripts" "$fixture/sdv-hack-demo/patches" \
    "$temp/incubation" "$temp/core"

git -C "$1" archive "$KUKSA_DATABROKER_COMMIT" | tar -x -C "$broker"
git -C "$1" archive "$KUKSA_DATABROKER_COMMIT" databroker | tar -x -C "$temp/core"
git -C "$2" archive "$KUKSA_INCUBATION_COMMIT" mw-com-provider | tar -x -C "$temp/incubation"
mkdir -p "$broker/proto"
git -C "$3" archive "$KUKSA_PROTO_COMMIT" | tar -x -C "$broker/proto"
cp -a "$temp/incubation/mw-com-provider/databroker-mw-com" "$broker/"
cp -a "$temp/incubation/mw-com-provider/mw_com_provider" "$broker/"
cp "$repo_root/sdv-hack-demo/scripts/apply-patches.sh" "$fixture/sdv-hack-demo/scripts/"
cp "$repo_root/sdv-hack-demo/patches/databroker-baseline.env" "$fixture/sdv-hack-demo/patches/"
cp "$repo_root/sdv-hack-demo/patches/"{mw-com-provider-demo,databroker-mw-com-demo}.patch \
    "$fixture/sdv-hack-demo/patches/"

bash "$fixture/sdv-hack-demo/scripts/apply-patches.sh"
bash "$fixture/sdv-hack-demo/scripts/apply-patches.sh" > "$temp/repeat.log"
[[ "$(grep -c '^Already applied:' "$temp/repeat.log")" -eq 2 ]]
diff -qr "$temp/core/databroker" "$broker/databroker"
(
    cd "$broker"
    {
        find databroker-mw-com mw_com_provider ! -type d -print0
        printf '%s\0' Cargo.toml Cargo.lock databroker-cli/src/cli.rs databroker-proto/build.rs \
            proto/kuksa/val/{v1,v2}/{types,val}.proto
    } | LC_ALL=C sort -z | xargs -0 sha256sum
) > "$temp/reconstructed.sha256"
diff -u "$repo_root/sdv-hack-demo/tests/databroker-mw-com/upstream_reconstruction.sha256" \
    "$temp/reconstructed.sha256"
echo "Pinned upstream reconstruction, exact integration/core contents, and repeated application: PASS"
