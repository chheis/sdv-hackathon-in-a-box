#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$tests_dir/../../.." && pwd)"
temp="$(mktemp -d)"
trap 'rm -rf -- "$temp"' EXIT
fixture="$temp/repo"
mkdir -p "$fixture/sdv-hack-demo/scripts" "$fixture/kuksa-databroker" "$temp/bin"
cp "$repo_root/sdv-hack-demo/scripts/cargo-mw-com.sh" "$fixture/sdv-hack-demo/scripts/"
cat > "$temp/bin/cargo" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$PWD" "${SCORE_COM_LINK_OWNER:-}" "$@" > "$CARGO_TEST_LOG"
exit "${CARGO_TEST_EXIT:-0}"
STUB
chmod +x "$temp/bin/cargo"
export CARGO_TEST_LOG="$temp/cargo.log"
cd "$temp"

PATH="$temp/bin:$PATH" SCORE_COM_LINK_OWNER=databroker-mw-com \
    bash "$fixture/sdv-hack-demo/scripts/cargo-mw-com.sh" \
        +stable check --manifest-path "path with spaces/Cargo.toml"
mapfile -t invocation < "$CARGO_TEST_LOG"
[[ "${#invocation[@]}" -eq 6 ]]
[[ "${invocation[0]}" == "$fixture/kuksa-databroker" ]]
[[ "${invocation[1]}" == databroker-mw-com ]]
[[ "${invocation[2]}" == +stable ]]
[[ "${invocation[3]}" == check ]]
[[ "${invocation[4]}" == --manifest-path ]]
[[ "${invocation[5]}" == "path with spaces/Cargo.toml" ]]

if PATH="$temp/bin:$PATH" CARGO_TEST_EXIT=17 \
    bash "$fixture/sdv-hack-demo/scripts/cargo-mw-com.sh" +stable build; then
    echo "Expected the Cargo failure to propagate" >&2
    exit 1
else
    [[ "$?" -eq 17 ]]
fi
echo "Plain Cargo wrapper working directory, arguments, environment, and failure propagation: PASS"
