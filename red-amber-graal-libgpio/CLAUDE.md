# red-amber-graal-libgpio — CLAUDE.md

See `README.md` for the full human-readable setup guide, build instructions,
and cross-compilation notes. This file records AI-assistant-relevant context.

## What this project is

Java 25 traffic light controller using the FFM API + libgpiod. Runs the UK
traffic light sequence (RED→RED_AMBER→GREEN→AMBER) on BCM pins 5/6/13 of
BlackRaspberry. Supports both JVM and GraalVM native image deployment.

## Build modes

| Command | Output | Runs on |
|---|---|---|
| `mvn package` | JVM JAR in `target/` | Pi via `make run` |
| `mvn package -Dnative` | aarch64 native binary in `target/` | Pi via `make run-native` |
| `make deploy-native-pi` | aarch64 native binary built on BlackRaspberry | Pi via `make run-native` |
| `make deploy-native-podman` | aarch64 native binary via Podman/QEMU arm64 | Pi via `make run-native` |

There is currently no working local native build path:

- **Maven cross-compile** (`mvn package -Dnative`) — blocked by a GraalVM CE 25.0.2
  `ClassCastException` in `ForeignFunctionsFeature` when FFM is enabled with `--target=linux-aarch64`.
- **Podman/QEMU** (`make deploy-native-podman`) — hangs; did not complete after running overnight.

See `notes/graalvm-ffm-cross-compile-bug.md` for full details and current status.

Local run scripts (`scripts/run/run-local.sh`, `scripts/run/run-local-native.sh`) are not updated.

## Key files

| File | Purpose |
|---|---|
| `pom.xml` | Native profile contains all cross-compilation flags |
| `Makefile` | Convenience targets for all operations; run `make help` |
| `Containerfile` | arm64 Debian bookworm image with GraalVM CE 25.0.2 + gcc for Podman builds |
| `scripts/setup/setup-aarch64-libs.sh` | One-time: symlinks Pi's aarch64 static libs into local GraalVM CE |
| `scripts/setup/setup-podman.sh` | One-time: install QEMU packages on Arch Linux, verify binfmt handler |
| `scripts/setup/generate-cap-cache.sh` | Generates `cap-cache/` on the Pi, fetches back — see README |
| `scripts/setup/generate-ffm-bindings.sh` | Generate FFM bindings from gpiod.h via jextract — see README |
| `cap-cache/` | Committed CAP cache — do not delete, regenerate via `make gen-cap-cache` |
| `scripts/build/build-native-podman.sh` | Build native binary via arm64 Podman container (workaround for GraalVM cross-compile bug) |
| `scripts/deploy/deploy-pi.sh` | Build JAR → scp to Pi |
| `scripts/deploy/deploy-pi-native.sh` | Build native binary via Maven cross-compile → scp to Pi (requires sysroot + GraalVM CE) |
| `scripts/deploy/deploy-pi-native-on-pi.sh` | Build native binary on BlackRaspberry via SSH → installs in place |
| `scripts/deploy/deploy-pi-native-podman.sh` | Build native binary via Podman/QEMU → scp to Pi |
| `scripts/run/run-on-pi.sh` / `scripts/run/run-on-pi-native.sh` | SSH and run the respective binary |
| `scripts/pi/red-amber-graal-libgpio` | JVM wrapper deployed to Pi |
| `src/main/resources/META-INF/native-image/dev.lofthouse/red-amber-graal-libgpio/reachability-metadata.json` | FFM downcall descriptor shapes for GraalVM native-image registration |
| `notes/graalvm-ffm-cross-compile-bug.md` | Bug report: GraalVM CE 25.0.2 FFM cross-compile ClassCastException |
| `notes/graalvm-ffm-static-discovery-bug.md` | Bug report: GraalVM CE 25.0.2 FFM static discovery failure (Arena.ofAuto() forces runtime init) |

## Script/Makefile inventory

When adding, removing, or renaming a script, update `Makefile`, `README.md`,
and `CLAUDE.md` in the same commit to keep them in sync.

## Cross-compilation flags in pom.xml (native profile)

All flags and their reasons are documented in `README.md` § Cross-compilation
notes. Key things to know when modifying the native profile:

- `--target=linux-aarch64` — correct spelling; `--target-platform` does not
  exist in GraalVM CE 25.
- `--native-compiler-path` / `--native-compiler-options` — stable replacements
  for the experimental `-H:CCompilerPath` / `-H:CCompilerOption`.
- `-H:-ForeignAPISupport` — **must stay until FFM bindings are added**. When
  removed, also add `--enable-native-access=ALL-UNNAMED`. The underlying bug:
  `ForeignFunctionsFeature` (always active from `svm-foreign.jar`) calls
  `ABIs$X86_64.generateTrampolineTemplate` regardless of `--target`, which
  tries to instantiate `AMD64Assembler` and fails with `ClassCastException`
  because the target architecture object is `AArch64` not `AMD64`. This is a
  GraalVM CE 25.0.2 bug.
- `-H:CLibraryPath` adds to the linker search path (accumulating option, does
  not replace the driver-supplied paths). The Debian multiarch lib directory
  (`/usr/lib/aarch64-linux-gnu`) is not added automatically by the sysroot
  mechanism, so `-lz` and other system libs are not found without it.
- `-H:CAPCacheDir` — native-image auto-enables `+UseCAPCache` when
  `--target` specifies a cross-compilation target. The cache must be pre-built
  (see `make gen-cap-cache`). The cache lives in `cap-cache/` at the project
  root (not `target/`) so it survives `mvn clean` and is committed to git.

## CAP cache — when to regenerate

The CAP cache captures C type layout information for GraalVM's annotation-based
C interop (`@CStruct`, `@CField`, `@CFunction`). It is **not** used by
jextract-generated FFM bindings, which resolve layouts via `MemoryLayout` /
`FunctionDescriptor` through a separate mechanism.

Run `make gen-cap-cache` and commit the result when:
1. GraalVM CE version changes (version determines which C types are queried).
2. Pi OS or glibc is updated (struct layouts may change).
3. New `@CStruct` / `@CField` annotations are added to the project.

Adding new jextract FFM bindings does **not** require regenerating the cache.

## FFM downcall registration — when to update

The file `src/main/resources/META-INF/native-image/dev.lofthouse/red-amber-graal-libgpio/reachability-metadata.json`
registers **shapes** (unique return+parameter type combinations), not individual functions. The
native-image runtime requires a pre-compiled stub for each unique shape used in a downcall.

The JSON needs updating when:
1. A new `gpiod_h` function is called from `TrafficLightController.java` whose descriptor shape
   is not already in the JSON. Check the existing 5 shapes (see "Key files" above) — if the new
   function's `(returnType, parameterTypes)` combination already appears, no change is needed.
2. FFM bindings are regenerated (via `make gen-ffm-bindings`) and new functions are added to
   `TrafficLightController.java` with novel descriptor shapes.

You do NOT need to update when:
- Adding new calls to existing shapes (e.g., a second function with `void*(void*)` signature).
- Regenerating FFM bindings without adding new calls in `TrafficLightController.java`.

**Alternative:** The GraalVM Tracing Agent can auto-generate this metadata from a live run:

```bash
# On BlackRaspberry, with the JAR deployed:
java -agentlib:native-image-agent=config-output-dir=META-INF/native-image \
     --enable-native-access=ALL-UNNAMED \
     -jar ~/.local/bin/red-amber-graal-libgpio.jar
```

This requires libgpiod at runtime and GPIO hardware access, so it must run on the Pi, not locally.

Doc reference:
https://www.graalvm.org/jdk25/reference-manual/native-image/native-code-interoperability/ffm-api/#downcalls

## aarch64 static library symlinks

`make setup-libs` creates two symlinks inside the local GraalVM CE
installation pointing at the Pi's GraalVM CE installation via the SSHFS sysroot
mount. native-image's JDK static lib search path is hardcoded to
`$JAVA_HOME/lib/static/{target}/{libc}/` and cannot be redirected via any
native-image flag. Symlinks are the only mechanism that avoids copying files.

The symlinks depend on:
- Sysroot being mounted (`~/mnt/pios12_root`)
- GraalVM CE 25.0.2 installed on BlackRaspberry

Re-run `make setup-libs` after upgrading GraalVM on either machine.

## Native image option names — GraalVM CE 25 reference

These were discovered by trial and error and verified against `native-image --help`:

| Wrong (from online docs / EE) | Correct (CE 25) |
|---|---|
| `--target-platform=linux-aarch64` | `--target=linux-aarch64` |
| `-H:CCompilerPath=...` | `--native-compiler-path=...` |
| `-H:CCompilerOption=...` | `--native-compiler-options=...` |

The `-H:` variants still exist as experimental aliases but emit warnings.

## Status

libgpiod FFM bindings are integrated and the UK traffic light sequence runs
on the Pi in JVM mode (`make deploy && make run`). There is currently **no
working local path to build a native binary with FFM enabled** — both the
Maven cross-compile and Podman/QEMU paths are blocked (see
`notes/graalvm-ffm-cross-compile-bug.md`). Both paths are retained for future
testing.

Notes on completed integration work:
- `-H:-ForeignAPISupport` has been removed; `--enable-native-access=ALL-UNNAMED`
  is in both pom.xml (native profile) and the Pi JVM wrapper.
- `RuntimeForeignAccess.registerForDowncall()` is **not** needed (and was not used):
  instead, `reachability-metadata.json` registers the required downcall descriptor shapes.
  jextract generates `FunctionDescriptor` constants as `static final` fields intended for
  automatic static analysis discovery, but `Arena.ofAuto()` in the generated code forces
  `gpiod_h` to be runtime-initialized, breaking that mechanism in GraalVM CE 25.0.2. See
  `notes/graalvm-ffm-static-discovery-bug.md` for the full root-cause chain.
  Doc: https://www.graalvm.org/jdk25/reference-manual/native-image/native-code-interoperability/ffm-api/#downcalls
- CAP cache regeneration was **not** needed when adding FFM bindings (see
  "CAP cache — when to regenerate" above).
- Maven cross-compile (`mvn package -Dnative`) crashes in GraalVM CE 25.0.2 with
  a `ClassCastException` in `ForeignFunctionsFeature` when FFM is enabled; see
  `notes/graalvm-ffm-cross-compile-bug.md`.
- Podman/QEMU arm64 build (`make deploy-native-podman`) hung overnight without
  completing — likely stalled during native-image analysis or compilation under
  QEMU emulation.
- The Podman build does **not** need libgpiod in the container — `gpiod_h`
  defers to runtime `dlopen` on the Pi.
