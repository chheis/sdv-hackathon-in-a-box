<!-- SPDX-License-Identifier: Apache-2.0 -->

# Reproducing the demo Databroker integration

Use the exact revisions in [databroker-baseline.env](databroker-baseline.env):

| Source | Pinned commit |
| --- | --- |
| [KUKSA Databroker](https://github.com/eclipse-kuksa/kuksa-databroker) | `4cb080eecee2ea5033d34b5f1f0f6ca2c8b76424` (`0.7.2-dev.0`) |
| [Incubation provider/composition](https://github.com/eclipse-kuksa/kuksa-incubation/tree/34d0f759645392cc14dc1f5426e9ad6089f27491/mw-com-provider) | `34d0f759645392cc14dc1f5426e9ad6089f27491` |
| [KUKSA proto submodule](https://github.com/eclipse-kuksa/kuksa-proto) | `28bf76ae57085dad425eedd95bc7bd442e1314a7` |

The demo's `databroker/` core matches the pinned Databroker commit byte for
byte. This is not current upstream `main` (`0.7.3-dev.0` at
`fce05ac2cabca7db68ef454bcd81ac5b948fb2c4` when compared). In particular,
the pinned `SignalProvider` read callback takes `&mut self`; current upstream
uses `&self`. Do not substitute newer branches without rebasing and testing.

The incubation source is also pinned: it is not the newer draft ZIP shared
during review. Both patches below are generated against the public incubation
revision, not against that ZIP.

## Two patches

1. [mw-com-provider-demo.patch](mw-com-provider-demo.patch) reproduces the demo's
   complete `mw_com_provider/` source tree from incubation. It includes the BCM
   model/generated files, separate body/high-beam services, private vehicle-app
   command ingress, datapoint-versus-target classification, datatype handling,
   native Cargo shims, tests, and code-generation templates. It also removes
   obsolete vehicle-dynamics model/configuration files.
2. [databroker-mw-com-demo.patch](databroker-mw-com-demo.patch) adds the
   composition's `Int16`/`FloatArray` support, gateway adapter selection, BCM
   defaults, optional direct-mode command policy, and native archive handling.
   It also includes the required **workspace integration**: Cargo members and
   exclusions, the matching lockfile, shared proto build paths, and removal
   of the unsupported legacy CLI protocol option.

The old composition-only patch did not apply completely to public incubation:
it assumed the draft already supplied `Int16` and `FloatArray`. It has been
replaced with the complete patch above.

Neither patch changes files under `databroker/`. A real Git clone preserves
the upstream `databroker-proto/proto` symlink; the demo's flattened copy had
lost that symlink. The integration patch uses `../proto` explicitly, so both
layouts compile from the same pinned protocol sources.

## Fresh checkout

Run from the SDV repository root. The script creates `kuksa-databroker/` when
absent, checks out the pinned commit, initializes the pinned proto submodule,
and downloads the missing provider/composition folders.
The sibling `communication/` and `baselibs/` sources from this SDV workspace
remain required for native builds.
The incubation archive download extracts only the two required folders into
Databroker; it does not create a separate incubation checkout.

```bash
bash sdv-hack-demo/scripts/apply-patches.sh
```

The patch script checks **both** patches before changing sources, skips patches
already applied, and fails on conflicting or partially applied sources.
An existing Git checkout must match the pinned Databroker and proto revisions;
the script does not reset or overwrite an unrelated checkout.
The normal [ARM64 build](../scripts/build-aarch64.sh) invokes it before
signal generation and compilation. Do not copy the already-patched provider
over a partially patched baseline.

`KUKSA_HIGH_BEAM_ACTUATION=0` makes mappings with a separate
`/body_control_module_tx` binding receive-only. The combined vehicle launcher
leaves actuation enabled. The [Cargo wrapper](../scripts/cargo-mw-com.sh)
only forwards Cargo arguments; it does not modify broker sources.

This reconstructs the demo's provider, patched composition, Cargo integration,
and broker core. It does not duplicate unrelated documentation, Git metadata,
build output, or deployment state from the old bundled checkout.
Matching source is necessary but does not replace rebuilding and deploying
matching gateway, communication, provider, configuration, and runtime artifacts.

## Verification

With local clones containing the pinned commits:

```sh
bash sdv-hack-demo/tests/databroker-mw-com/upstream_reconstruction_test.sh \
  /path/to/kuksa-databroker-git \
  /path/to/kuksa-incubation-git \
  /path/to/kuksa-proto-git
```

This reconstructs sources in a temporary directory, applies both patches twice,
compares source contents with this demo, and checks that broker core is unchanged.

Other focused checks:

```sh
bash sdv-hack-demo/tests/databroker-mw-com/run.sh build
bash sdv-hack-demo/tests/databroker-mw-com/patch_application_test.sh
bash sdv-hack-demo/tests/databroker-mw-com/cargo_wrapper_test.sh
cd kuksa-databroker
cargo test --offline --locked -p mw_com_provider --lib --tests
```

The composition main tests (`run.sh main`) require native libraries matching the
host architecture. ARM64 native libraries cannot be linked into an x86-64 test.
Host/mock tests do not establish Pi-to-Pi end-to-end operation.
