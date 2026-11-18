#!/usr/bin/env bash
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kuksa_root="${repo_root}/kuksa-databroker"
composition_patch="${repo_root}/sdv-hack-demo/patches/databroker-mw-com-demo.patch"

if git -C "$kuksa_root" apply --reverse --check "$composition_patch" 2>/dev/null; then
    printf 'Already applied: %s\n' "$composition_patch"
else
    git -C "$kuksa_root" apply --check "$composition_patch"
    git -C "$kuksa_root" apply "$composition_patch"
    printf 'Applied: %s\n' "$composition_patch"
fi
