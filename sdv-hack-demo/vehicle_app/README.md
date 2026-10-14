# Vehicle High-Beam mw::com Showcase

This application publishes and consumes only the VSS signal
`Vehicle.Body.Lights.Beam.High.IsOn` through the SOME/IP gateway. Service,
instance, and member identifiers are transport configuration owned by `mw::com`
and the gateway; they are not part of the application signal interface.

The wire payload is exactly one byte: `0x00` for `false` and `0x01` for `true`.
The application rejects every other payload length or value.

The two directions use separate services so a received network state is never
republished back to the network:

| Direction | Service | Event | Instance |
| --- | --- | --- | --- |
| Vehicle app to network | `vehicle_high_beam_tx` (`0x4300`) | `0x8430` | `0x1000` |
| Network to Vehicle app | `vehicle_high_beam_rx` (`0x4300`) | `0x8431` | `0x1001` |

`gatewayd` consumes the Tx service through a `mw::com::GenericProxy` and exposes
the Rx service through a `mw::com::GenericSkeleton`. `someipd` owns the local
vSomeIP network stack.

The shared-memory binding is resolved as `service / instance / member`:
`/vehicle_high_beam_tx` or `/vehicle_high_beam_rx` / their configured instance
specifier / `high_beam_state`.

## Build

```bash
cd sdv-hack-demo
bash build-aarch64.sh
```

## Deployment

Use the packaged two-RPi workflow in the parent [SDV High-Beam Demo README](../README.md).
It builds the gateway components, creates both deployment archives, and starts
the vehicle and remote applications with the correct library paths and IP
configuration.

The Vehicle app publishes either boolean value. The bridge forwards it to the
remote sensor over UDP, and the sensor sends its latest value back through the
bridge, SOME/IP, and mw::com.

## Local host testing (no RPi required)

You can run the bridge and apps on your PC for fast iteration using localhost
UDP ports.

1. Create a local copy of the network config and set both IPs to `127.0.0.1`:

```bash
cp sdv-hack-demo/deploy/network.env sdv-hack-demo/deploy/network.env.local
# Edit values inside to:
# HIGH_BEAM_VEHICLE_IP=127.0.0.1
# HIGH_BEAM_REMOTE_IP=127.0.0.1
# HIGH_BEAM_BRIDGE_UDP_PORT=35000
# HIGH_BEAM_REMOTE_UDP_PORT=35001
nano sdv-hack-demo/deploy/network.env.local
source sdv-hack-demo/deploy/network.env.local
```

2. Build host binaries (x86_64):

```bash
bazel build --host_copt=-std=gnu11 //sdv-hack-demo/...
```

3. Run components in separate terminals (or background jobs):

Terminal A — bridge (vehicle-side):

```bash
bazel run //sdv-hack-demo:vehicle_high_beam_bridge
```

Terminal B — remote sensor (simulated remote):

```bash
bazel run //sdv-hack-demo:vehicle_high_beam_remote_app
```

Terminal C — vehicle app (foreground):

```bash
bazel run //sdv-hack-demo:vehicle_app
```

If `bazel run` target names differ, locate the binaries under `bazel-bin/`
and run them directly.

When the vehicle application is running, select a signal from its menu:

```text
1   High-beam; enter true or false
2   Speed; enter a numeric value
q   Quit
```

Speed uses the vehicle-dynamics example payload: an 8-byte `double` followed by
the 1-byte quality value `3`. The remote endpoint returns the same payload as
`Vehicle.speedAck`.

## TODO (local development)
- Add `sdv-hack-demo/run-local.sh` to launch bridge + remote + vehicle and
	capture logs.
- Provide `remote_app/README.md` with host-run instructions.
- Add a lightweight host-only integration test asserting message exchange.