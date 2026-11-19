#!/usr/bin/env bash
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kuksa_root="${repo_root}/kuksa-databroker"
source "${repo_root}/sdv-hack-demo/patches/databroker-baseline.env"
patches=(
    "${repo_root}/sdv-hack-demo/patches/mw-com-provider-demo.patch"
    "${repo_root}/sdv-hack-demo/patches/databroker-mw-com-demo.patch"
)

if [[ ! -e "$kuksa_root" ]]; then
    git clone https://github.com/eclipse-kuksa/kuksa-databroker.git "$kuksa_root"
    git -C "$kuksa_root" checkout --detach "$KUKSA_DATABROKER_COMMIT"
    git -C "$kuksa_root" submodule update --init --recursive
fi

if [[ -e "$kuksa_root/.git" ]]; then
    if [[ "$(git -C "$kuksa_root" rev-parse HEAD)" != "$KUKSA_DATABROKER_COMMIT" ]]; then
        echo "ERROR: Databroker must be at $KUKSA_DATABROKER_COMMIT; existing checkout was not changed." >&2
        exit 1
    fi
    if [[ ! -f "$kuksa_root/proto/kuksa/val/v2/val.proto" ]] ||
        [[ "$(git -C "$kuksa_root/proto" rev-parse HEAD)" != "$KUKSA_PROTO_COMMIT" ]]; then
        echo "ERROR: Initialize the pinned proto submodule with: git -C \"$kuksa_root\" submodule update --init --recursive" >&2
        exit 1
    fi
fi

members=()
for folder in databroker-mw-com mw_com_provider; do
    if [[ ! -e "$kuksa_root/$folder" ]]; then
        members+=("kuksa-incubation-${KUKSA_INCUBATION_COMMIT}/mw-com-provider/$folder")
    fi
done

if (( ${#members[@]} )); then
    staging="$(mktemp -d)"
    trap 'rm -rf -- "$staging"' EXIT
    curl -fL "https://github.com/eclipse-kuksa/kuksa-incubation/archive/${KUKSA_INCUBATION_COMMIT}.tar.gz" |
        tar -xz --strip-components=2 -C "$staging" "${members[@]}"
    for member in "${members[@]}"; do
        folder="${member##*/}"
        mv -T "$staging/$folder" "$kuksa_root/$folder"
    done
fi

# Check both patches before modifying either set of sources.
pending=()
for patch in "${patches[@]}"; do
    if git -C "$kuksa_root" apply --reverse --check "$patch" 2>/dev/null; then
        printf 'Already applied: %s\n' "$patch"
    else
        git -C "$kuksa_root" apply --check "$patch"
        pending+=("$patch")
    fi
done

for patch in "${pending[@]}"; do
    git -C "$kuksa_root" apply "$patch"
    printf 'Applied: %s\n' "$patch"
done
