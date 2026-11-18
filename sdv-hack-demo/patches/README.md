<!-- SPDX-License-Identifier: Apache-2.0 -->

# Databroker composition demo patch

The base composition follows the supplied incubation workspace. Its `main.rs`
retains the generic `Int16` and `FloatArray` datatype/bound handling.

[`databroker-mw-com-demo.patch`](databroker-mw-com-demo.patch) contains:

- BCM configuration and native link-parameter defaults.
- Gateway-versus-LoLa adapter selection.
- Optional receive-only mode: `KUKSA_HIGH_BEAM_ACTUATION=0` makes mappings
  with a separate `/body_control_module_tx` binding receive-only. The combined
  vehicle launcher leaves actuation enabled so the provider can forward
  `databroker-cli` and external KUKSA actuator requests. The policy is extracted
  into a private helper so it can be tested without changing process-wide
  environment variables.
- Explicit `OUT_DIR` passing and replacement of read-only staged archives.

The [demo ARM64 build script](../scripts/build-aarch64.sh) calls
[`apply-patches.sh`](../scripts/apply-patches.sh) before signal generation and
compilation. Repeated builds skip an already-applied
patch; a missing or conflicting patch stops the build. Application modifies the
checked-out composition sources and leaves them patched.

For builds that bypass that entry point, run the patch script from the repository root:

```sh
bash sdv-hack-demo/scripts/apply-patches.sh
```

The patch covers only the composition. The provider uses standard broker
updates for feedback and forwards only actuator targets or actuation callbacks.
The ARM64 helper uses the demo-owned
[`cargo-mw-com.sh`](../scripts/cargo-mw-com.sh), a plain Cargo launcher with no
broker patching or isolated modified sources.

## External tests

Run against the **unpatched base** from the repository root:

```sh
bash sdv-hack-demo/tests/databroker-mw-com/run.sh build
bash sdv-hack-demo/tests/databroker-mw-com/run.sh main
bash sdv-hack-demo/tests/databroker-mw-com/patch_application_test.sh
bash sdv-hack-demo/tests/databroker-mw-com/cargo_wrapper_test.sh
```

The runner applies the patch to temporary sources, checks exact reversal, and
leaves the checked-in composition unchanged. With no argument it runs both.
The archive regression uses `rustc` and GNU `ar` on Unix, without broker/native
dependencies. Temporary files are cleaned on exit.
The build-script test checks initial application, repeated application, and
conflict rejection in an isolated fixture with compilation commands stubbed.

The main test includes the real patched composition and uses its Cargo
dependencies. It checks direct-mode binding isolation and normal-mode
preservation. It requires the same native libraries/toolchain as the composition.
A passing archive test does not imply a successful full composition build;
native test execution still requires libraries matching the host architecture.
