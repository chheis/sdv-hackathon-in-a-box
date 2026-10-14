#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gateway_root="${repo_root}/inc_someip_gateway"
gateway_bazel_bin="${gateway_root}/bazel-out/aarch64-fastbuild/bin"
demo_bazel_bin="${repo_root}/bazel-out/aarch64-fastbuild/bin"
dist_dir="${repo_root}/sdv-hack-demo/dist"
kuksa_release_dir="${repo_root}/kuksa-databroker/target/aarch64-unknown-linux-gnu/release"
staging_dir="$(mktemp -d)"
trap 'rm -rf "${staging_dir}"' EXIT

vehicle_dir="${staging_dir}/vehicle"
remote_dir="${staging_dir}/remote"
mkdir -p "${vehicle_dir}/run" "${remote_dir}/run"
mkdir -p "${vehicle_dir}/mw_com_provider/generated"

copy_target() {
    local target_dir="$1"
    local binary="$2"
    local runfiles="$3"

    if [[ ! -f "${binary}" ]]; then
        printf 'ERROR: Required build artifact not found: %s\nRun sdv-hack-demo/build-aarch64.sh first.\n' \
            "${binary}" >&2
        return 1
    fi
    if [[ ! -d "${runfiles}" ]]; then
        printf 'ERROR: Required Bazel runfiles directory not found: %s\nRun sdv-hack-demo/build-aarch64.sh first.\n' \
            "${runfiles}" >&2
        return 1
    fi

    cp -a "${binary}" "${target_dir}/"
    cp -aL "${runfiles}" "${target_dir}/"
}

copy_target "${vehicle_dir}" \
    "${gateway_bazel_bin}/score/someipd/someipd" \
    "${gateway_bazel_bin}/score/someipd/someipd.runfiles"
copy_target "${vehicle_dir}" \
    "${gateway_bazel_bin}/score/gatewayd/gatewayd" \
    "${gateway_bazel_bin}/score/gatewayd/gatewayd.runfiles"
copy_target "${vehicle_dir}" \
    "${demo_bazel_bin}/sdv-hack-demo/bridge/vehicle_high_beam_bridge" \
    "${demo_bazel_bin}/sdv-hack-demo/bridge/vehicle_high_beam_bridge.runfiles"
copy_target "${vehicle_dir}" \
    "${demo_bazel_bin}/sdv-hack-demo/vehicle_app/vehicle_high_beam_mw_com" \
    "${demo_bazel_bin}/sdv-hack-demo/vehicle_app/vehicle_high_beam_mw_com.runfiles"
cp -a "${kuksa_release_dir}/databroker-mw-com-demo" "${vehicle_dir}/"
cp -a "${kuksa_release_dir}/databroker-cli" "${vehicle_dir}/"
cp -a "${repo_root}/kuksa-databroker/mw_com_provider/generated/mw_com_provider_config.json" \
    "${vehicle_dir}/mw_com_provider/generated/"
cp -a "${repo_root}/kuksa-databroker/mw_com_provider/generated/vehicle_dynamics_lola_config.json" \
    "${vehicle_dir}/mw_com_provider/generated/"
copy_target "${remote_dir}" \
    "${demo_bazel_bin}/sdv-hack-demo/remote_app/vehicle_high_beam_remote_app" \
    "${demo_bazel_bin}/sdv-hack-demo/remote_app/vehicle_high_beam_remote_app.runfiles"

cp -a "${demo_bazel_bin}/sdv-hack-demo/mw_someip_config.bin" "${vehicle_dir}/"
cp -a "${gateway_root}/score/gatewayd/etc/mw_com_config.json" "${vehicle_dir}/"
cp -a "${gateway_root}/tests/integration/vsomeip-gateway-services.json" "${vehicle_dir}/"
# gatewayd loads score_com_serializer.so; the demo plugin forwards to the gateway's own
# serializer, shipped next to it as score_com_serializer_base.so.
cp -a "${demo_bazel_bin}/sdv-hack-demo/serializer/score_com_serializer.so" "${vehicle_dir}/"
cp -a "${demo_bazel_bin}/sdv-hack-demo/serializer/score_com_serializer_base.so" "${vehicle_dir}/"
cp -a "${repo_root}/sdv-hack-demo/deploy/start-vehicle.sh" "${vehicle_dir}/run/"
cp -a "${repo_root}/sdv-hack-demo/deploy/start-remote.sh" "${remote_dir}/run/"
cp -a "${repo_root}/sdv-hack-demo/deploy/network.env" "${vehicle_dir}/"
cp -a "${repo_root}/sdv-hack-demo/deploy/network.env" "${remote_dir}/"
cp -a "${repo_root}/sdv-hack-demo/signal_routes.json" "${vehicle_dir}/"
cp -a "${repo_root}/sdv-hack-demo/signal_routes.json" "${remote_dir}/"
chmod +x "${vehicle_dir}/run/start-vehicle.sh" "${remote_dir}/run/start-remote.sh"

mkdir -p "${dist_dir}"
tar -chzf "${dist_dir}/vehicle-aarch64.tar.gz" -C "${vehicle_dir}" .
tar -chzf "${dist_dir}/remote-aarch64.tar.gz" -C "${remote_dir}" .

printf 'Created:\n  %s\n  %s\n' \
    "${dist_dir}/vehicle-aarch64.tar.gz" \
    "${dist_dir}/remote-aarch64.tar.gz"
cd 