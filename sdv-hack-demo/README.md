<!--
Copyright (c) 2026 Contributors to the Eclipse Foundation

SPDX-License-Identifier: Apache-2.0
-->

# SDV Demo Applications

This directory contains the vehicle menu, UDP bridge, remote application,
signal-route tester, and ARM64 build/deployment scripts.

Use the [main operator guide](../README.md) for the complete workflow:

- [Prerequisites and toolchain](../README.md#prepare-the-host-machine-and-rpi-hw)
- [Build and package](../README.md#build-and-package)
- [Deployment and network settings](../README.md#deploy-and-configure)
- [Native stack startup](../README.md#start-the-demo)
- [SDV Runtime container](../README.md#setup-and-run-the-sdv-runtime)
- [Playground use case and GPIO](../README.md#playground-use-case-and-gpio)
- [Stopping and replacing a deployment](../README.md#stop-or-replace-a-deployment)
- [Troubleshooting](../README.md#troubleshooting)
- [Signal configuration and development](../README.md#signal-configuration-and-development)
- [Supported signals](../README.md#supported-signals)

Builds require the full repository, not this directory alone.

## Databroker Composition Patch

The demo-specific composition changes are maintained in a
[separate patch](patches/README.md), with [external tests](tests/databroker-mw-com/).
The [ARM64 build script](scripts/build-aarch64.sh) calls the dedicated
[patch script](scripts/apply-patches.sh) before building.
Already-applied patches are skipped; conflicts stop the build.
The ARM64 helper uses a [plain Cargo wrapper](scripts/cargo-mw-com.sh) for
provider/composition builds. The wrapper only selects the KUKSA working directory
and forwards Cargo arguments; it does not patch broker sources or build temporary
modified copies. The provider uses standard broker APIs: actuator targets are
commands, and current values are state. The runtime routes writes by metadata;
rebuild its image together with the provider to avoid mixing command semantics.

## SDV Runtime Patches

The [runtime build script](scripts/build-runtime-aarch64.sh), called by the main
ARM64 build, clones the runtime if needed, applies the runtime and model patches,
copies the SDK overlay, and builds/exports the image. The container installs
the [Velocitas VAL2 fork](https://github.com/nsudhakar479/vehicle-app-python-sdk-fork/tree/vehicle-app-python-sdk-Kuksa-VAL2)
at the commit pinned in [velocitas-val2.patch](sdv-runtime/velocitas-val2.patch),
instead of the PyPI SDK. The patch also pins `wrapt==1.17.2`. Already-applied
patches are skipped. If the VAL2 patch was applied before this pin changed,
update `wrapt==1.16.0` to `wrapt==1.17.2` in the runtime checkout's
`requirements-docker.txt` before rebuilding.

## Source Map

| Location | Purpose |
| --- | --- |
| [scripts](scripts/) | ARM64 builds, packaging, and patch application |
| [scripts/build-rpi-aarch64.sh](scripts/build-rpi-aarch64.sh) | Communication and KUKSA ARM64 build helper, called by the main build |
| [scripts/cargo-mw-com.sh](scripts/cargo-mw-com.sh) | Plain Cargo launcher for the KUKSA workspace |
| [tools](tools/) | Signal/configuration generators and their Python tests |
| [docs](docs/) | Architecture diagram |
| [patches](patches/) | Demo-specific source patches and usage instructions |
| [tests](tests/) | External composition and build-script tests |
| [vehicle_app](vehicle_app/) | Vehicle menu and body-signal round-trip tester |
| [bridge](bridge/) | Bidirectional local SOME/IP / remote UDP relay |
| [remote_app](remote_app/) | Remote UDP state, menus, GPIO, and publication sweep |
| [include/high_beam_udp_protocol.h](include/high_beam_udp_protocol.h) | Shared 46-byte UDP frame with a 32-byte payload limit |
| [config/body_signals.json](config/body_signals.json) | Manifest for the 44 body/powertrain signal routes |
| [config/signal_routes.json](config/signal_routes.json) | Generated numeric routes, including vehicle dynamics |
| [tools/configure_signals.py](tools/configure_signals.py) | Signal configuration synchronizer |
| [tools/gateway_provider_codegen.py](tools/gateway_provider_codegen.py) | KUKSA mappings and typed mw::com binding generation |
| [serializer](serializer/) | Gateway serializer shim |
| [deploy](deploy/) | Device launchers and default network settings |
| [sdv-runtime](sdv-runtime/) | SDK overlay and separate model patch |

Remote menu option `4` publishes the test values for all 44 body signals,
with a 250 ms pause after each sample. It does not change the regular
high-beam update interval.
Option `5` prompts for `Vehicle.Powertrain.Transmission.PerformanceMode`
(`NORMAL`, `SPORT`, `ECONOMY`, `SNOW`, or `RAIN`) and publishes the selected
value once.

From the repository root:

```sh
bash sdv-hack-demo/scripts/build-aarch64.sh
bash sdv-hack-demo/scripts/package-aarch64.sh
```

Packaged deployments still use `signal_routes.json` beside the executables;
only its source location has changed.

See [ARCHITECTURE.md](../ARCHITECTURE.md) for service identifiers, payload
layouts, provider flow, and the separate standalone body-control profile.
