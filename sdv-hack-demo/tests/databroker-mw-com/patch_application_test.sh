#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$tests_dir/../../.." && pwd)"
temp="$(mktemp -d)"
trap 'rm -rf -- "$temp"' EXIT
fixture="$temp/repo"
mkdir -p "$fixture/sdv-hack-demo/patches" "$fixture/sdv-hack-demo/scripts" "$fixture/inc_someip_gateway" \
    "$fixture/kuksa-databroker/databroker-mw-com/src" "$temp/bin"
cp "$repo_root/sdv-hack-demo/scripts/build-aarch64.sh" \
    "$repo_root/sdv-hack-demo/scripts/apply-patches.sh" "$fixture/sdv-hack-demo/scripts/"
cp "$repo_root/sdv-hack-demo/patches/databroker-mw-com-demo.patch" \
    "$repo_root/sdv-hack-demo/patches/mw-com-provider-demo.patch" \
    "$repo_root/sdv-hack-demo/patches/databroker-baseline.env" \
    "$fixture/sdv-hack-demo/patches/"
cp -R "$repo_root/kuksa-databroker/mw_com_provider" "$fixture/kuksa-databroker/"
cp "$repo_root/kuksa-databroker/Cargo.toml" "$repo_root/kuksa-databroker/Cargo.lock" \
    "$fixture/kuksa-databroker/"
mkdir -p "$fixture/kuksa-databroker/databroker-cli/src" "$fixture/kuksa-databroker/databroker-proto"
cp "$repo_root/kuksa-databroker/databroker-cli/src/cli.rs" "$fixture/kuksa-databroker/databroker-cli/src/"
cp "$repo_root/kuksa-databroker/databroker-proto/build.rs" "$fixture/kuksa-databroker/databroker-proto/"
cp "$repo_root/kuksa-databroker/databroker-mw-com/build.rs" \
    "$fixture/kuksa-databroker/databroker-mw-com/"
cp "$repo_root/kuksa-databroker/databroker-mw-com/src/main.rs" \
    "$fixture/kuksa-databroker/databroker-mw-com/src/"
patch="$fixture/sdv-hack-demo/patches/databroker-mw-com-demo.patch"
if git -C "$fixture/kuksa-databroker" apply --reverse --check "$patch" 2>/dev/null; then
    git -C "$fixture/kuksa-databroker" apply --reverse "$patch"
fi
provider_patch="$fixture/sdv-hack-demo/patches/mw-com-provider-demo.patch"
if git -C "$fixture/kuksa-databroker" apply --reverse --check "$provider_patch" 2>/dev/null; then
    git -C "$fixture/kuksa-databroker" apply --reverse "$provider_patch"
fi

export BUILD_TEST_FIXTURE="$fixture"
export BUILD_TEST_TRACE="$temp/build.trace"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'grep -q GatewayScoreRuntimeAdapter "$BUILD_TEST_FIXTURE/kuksa-databroker/databroker-mw-com/src/main.rs"' \
    'echo invoked >> "$BUILD_TEST_TRACE"' > "$temp/bin/stub"
chmod +x "$temp/bin/stub"
for command in python3 bazel; do
    ln -s "$temp/bin/stub" "$temp/bin/$command"
done
cp "$temp/bin/stub" "$fixture/sdv-hack-demo/scripts/build-rpi-aarch64.sh"
cp "$temp/bin/stub" "$fixture/sdv-hack-demo/scripts/build-runtime-aarch64.sh"

PATH="$temp/bin:$PATH" bash "$fixture/sdv-hack-demo/scripts/build-aarch64.sh" > "$temp/first.log"
grep -q '^Applied:' "$temp/first.log"
git -C "$fixture/kuksa-databroker" apply --reverse --check "$patch"
git -C "$fixture/kuksa-databroker" apply --reverse --check "$provider_patch"
[[ "$(wc -l < "$BUILD_TEST_TRACE")" -eq 5 ]]
PATH="$temp/bin:$PATH" bash "$fixture/sdv-hack-demo/scripts/build-aarch64.sh" > "$temp/repeat.log"
grep -q '^Already applied:' "$temp/repeat.log"
[[ "$(wc -l < "$BUILD_TEST_TRACE")" -eq 10 ]]

git -C "$fixture/kuksa-databroker" apply --reverse "$patch"
git -C "$fixture/kuksa-databroker" apply --reverse "$provider_patch"
cp "$fixture/kuksa-databroker/databroker-mw-com/build.rs" "$temp/base-build.rs"
printf 'conflicting source\n' > "$fixture/kuksa-databroker/databroker-mw-com/src/main.rs"
if PATH="$temp/bin:$PATH" bash "$fixture/sdv-hack-demo/scripts/build-aarch64.sh" > "$temp/conflict.log" 2>&1; then
    echo "Expected a conflicting patch to stop the build" >&2
    exit 1
fi
[[ "$(wc -l < "$BUILD_TEST_TRACE")" -eq 10 ]]
cmp "$temp/base-build.rs" "$fixture/kuksa-databroker/databroker-mw-com/build.rs"
git -C "$fixture/kuksa-databroker" apply --check "$provider_patch"
echo "Both patches: initial/repeated build and conflict rejection before source modification: PASS"
