#!/usr/bin/env bash
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}/patch"

if [[ ! -d sdv-runtime ]]; then
    git clone --recurse-submodules https://github.com/eclipse-autowrx/sdv-runtime.git
fi

cd sdv-runtime
apply_patch_once() {
    local patch="$1"
    if git apply --reverse --check "${patch}" 2>/dev/null; then
        printf 'Already applied: %s\n' "${patch}"
    else
        git apply --check "${patch}"
        git apply "${patch}"
    fi
}
apply_patch_once "${repo_root}/sdv-hack-demo/sdv-runtime/sdv-runtime-mw-com.patch"
cp "${repo_root}/sdv-hack-demo/sdv-runtime/sdk_extensions.vspec" overlays/sdk_extensions.vspec
apply_patch_once "${repo_root}/sdv-hack-demo/sdv-runtime/runtime-model.patch"
apply_patch_once "${repo_root}/sdv-hack-demo/sdv-runtime/velocitas-val2.patch"

builder_args=()
if [[ -n "${BUILDX_BUILDER:-}" ]]; then
    builder_args=(--builder "$BUILDX_BUILDER")
elif [[ "$(uname -m)" == x86_64 ]]; then
    # The docker-container driver supplies BuildKit's ARM64 emulator.
    builder=sdv-val2-builder
    if ! docker buildx inspect "$builder" >/dev/null 2>&1; then
        docker buildx create --name "$builder" --driver docker-container
    fi
    builder_args=(--builder "$builder")
fi

# Apply the download settings to a copy so existing runtime patches stay re-runnable.
build_dir="$(mktemp -d)"
trap 'rm -f -- "$build_dir/Dockerfile"; rmdir -- "$build_dir"' EXIT
cp Dockerfile "$build_dir/Dockerfile"
(cd "$build_dir" && git apply "${repo_root}/sdv-hack-demo/sdv-runtime/pip-downloads.patch")

docker buildx build "${builder_args[@]}" \
    --platform linux/arm64 \
    --load \
    -t sdv-runtime:mw-com \
    -f - . < "$build_dir/Dockerfile"

# Export the image for packaging and loading on the Pi.
docker save -o sdv-runtime-mw-com.tar sdv-runtime:mw-com
