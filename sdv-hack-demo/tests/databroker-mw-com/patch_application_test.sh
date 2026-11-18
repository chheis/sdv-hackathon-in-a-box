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
    "$fixture/sdv-hack-demo/patches/"
cp "$repo_root/kuksa-databroker/databroker-mw-com/build.rs" \
    "$fixture/kuksa-databroker/databroker-mw-com/"
cp "$repo_root/kuksa-databroker/databroker-mw-com/src/main.rs" \
    "$fixture/kuksa-databroker/databroker-mw-com/src/"
patch="$fixture/sdv-hack-demo/patches/databroker-mw-com-demo.patch"
if git -C "$fixture/kuksa-databroker" apply --reverse --check "$patch" 2>/dev/null; then
    git -C "$fixture/kuksa-databroker" apply --reverse "$patch"
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
[[ "$(wc -l < "$BUILD_TEST_TRACE")" -eq 5 ]]
PATH="$temp/bin:$PATH" bash "$fixture/sdv-hack-demo/scripts/build-aarch64.sh" > "$temp/repeat.log"
grep -q '^Already applied:' "$temp/repeat.log"
[[ "$(wc -l < "$BUILD_TEST_TRACE")" -eq 10 ]]

git -C "$fixture/kuksa-databroker" apply --reverse "$patch"
cp "$fixture/kuksa-databroker/databroker-mw-com/build.rs" "$temp/base-build.rs"
printf 'conflicting source\n' > "$fixture/kuksa-databroker/databroker-mw-com/src/main.rs"
if PATH="$temp/bin:$PATH" bash "$fixture/sdv-hack-demo/scripts/build-aarch64.sh" > "$temp/conflict.log" 2>&1; then
    echo "Expected a conflicting patch to stop the build" >&2
    exit 1
fi
[[ "$(wc -l < "$BUILD_TEST_TRACE")" -eq 10 ]]
cmp "$temp/base-build.rs" "$fixture/kuksa-databroker/databroker-mw-com/build.rs"
echo "Build-script patch application, repeated build, and conflict rejection: PASS"
