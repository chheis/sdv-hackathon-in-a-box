#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$tests_dir/../../.." && pwd)"
source_root="$repo_root/kuksa-databroker"
patch_file="$repo_root/sdv-hack-demo/patches/databroker-mw-com-demo.patch"
mode="${1:-all}"
case "$mode" in
    all|build|main) ;;
    *) echo "Usage: bash $0 [all|build|main]" >&2; exit 2 ;;
esac

temp="$(mktemp -d)"
trap 'rm -rf -- "$temp"' EXIT
work="$temp/kuksa-databroker"
mkdir -p "$work/databroker-mw-com/src"
cp "$source_root/databroker-mw-com/build.rs" "$work/databroker-mw-com/"
cp "$source_root/databroker-mw-com/src/main.rs" "$work/databroker-mw-com/src/"
git -C "$work" apply --check "$patch_file"
git -C "$work" apply "$patch_file"
git -C "$work" apply --reverse --check "$patch_file"
mkdir "$work/roundtrip"
cp -R "$work/databroker-mw-com" "$work/roundtrip/"
git -C "$work/roundtrip" apply --reverse "$patch_file"
cmp "$source_root/databroker-mw-com/build.rs" "$work/roundtrip/databroker-mw-com/build.rs"
cmp "$source_root/databroker-mw-com/src/main.rs" "$work/roundtrip/databroker-mw-com/src/main.rs"
echo "Patch application and reversal: PASS"

if [[ "$mode" != main ]]; then
    COMPOSITION_BUILD_RS="$work/databroker-mw-com/build.rs" \
        rustc --edition=2021 --test "$tests_dir/build_tests.rs" -o "$work/build-tests"
    mkdir "$work/build-test-work"
    (cd "$work/build-test-work" && "$work/build-tests")
fi

if [[ "$mode" != build ]]; then
    for member in baselibs communication; do
        ln -s "$repo_root/$member" "$temp/$member"
    done
    cp "$source_root/Cargo.toml" "$source_root/Cargo.lock" "$work/"
    for member in databroker databroker-proto databroker-cli mw_com_provider lib .cargo; do
        if [[ -e "$source_root/$member" ]]; then
            ln -s "$source_root/$member" "$work/$member"
        fi
    done
    cp "$source_root/databroker-mw-com/Cargo.toml" "$work/databroker-mw-com/"
    mv "$work/databroker-mw-com/src/main.rs" "$work/databroker-mw-com/src/composition_main.rs"
    cp "$tests_dir/main_tests.rs" "$work/databroker-mw-com/src/main.rs"
    COMPOSITION_MAIN_RS="$work/databroker-mw-com/src/composition_main.rs" \
    COMPOSITION_PROVIDER_CONFIG="$source_root/mw_com_provider/generated/mw_com_provider_config.json" \
    CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$source_root/target}" \
        cargo test --offline --locked --manifest-path "$work/Cargo.toml" \
            -p databroker-mw-com --bin databroker-mw-com demo_tests::
fi
