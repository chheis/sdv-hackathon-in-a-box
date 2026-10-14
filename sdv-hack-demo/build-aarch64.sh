#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gateway_root="${repo_root}/inc_someip_gateway"

cd "${gateway_root}"
bazel build --config=aarch64-linux \
  //score/gatewayd \
  //score/someipd

cd "${repo_root}"
bazel build --config=aarch64-linux --host_copt=-std=gnu11 \
  //sdv-hack-demo:gateway_config \
  //sdv-hack-demo/serializer:serializer_shim \
  //sdv-hack-demo/serializer:base_serializer \
  //sdv-hack-demo/vehicle_app:vehicle_high_beam_mw_com \
  //sdv-hack-demo/bridge:vehicle_high_beam_bridge \
  //sdv-hack-demo/remote_app:vehicle_high_beam_remote_app

"${repo_root}/kuksa-databroker/scripts/build-rpi-aarch64.sh"
