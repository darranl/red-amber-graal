# red-amber-graal-libgpio — CLAUDE.md

See `README.md` for the full human-readable setup guide, build instructions,
and cross-compilation notes. This file records AI-assistant-relevant context.

## What this project is

Java 25 traffic light controller skeleton. Currently prints "Hello from the
traffic light controller." FFM / libgpiod bindings are the next step (Task 3.x).

## Build modes

| Command | Output | Runs on |
|---|---|---|
| `mvn package` | JVM JAR in `target/` | Pi via `run-on-pi.sh` |
| `mvn package -Dnative` | aarch64 native binary in `target/` | Pi via `run-on-pi-native.sh` |

The native build cross-compiles from x86_64 to aarch64. All execution is on
the Pi; local run scripts (`run-app.sh`, `run-app-native.sh`) are not updated.

## Key files

| File | Purpose |
|---|---|
| `pom.xml` | Native profile contains all cross-compilation flags |
| `setup-aarch64-libs.sh` | One-time: symlinks Pi's aarch64 static libs into local GraalVM CE |
| `generate-cap-cache.sh` | Generates `cap-cache/` on the Pi, fetches back — see README |
| `cap-cache/` | Committed CAP cache — do not delete, regenerate via script |
| `deploy-pi.sh` | Build JAR → scp to Pi |
| `deploy-pi-native.sh` | Build native binary → scp to Pi (requires sysroot mounted + GraalVM CE active) |
| `run-on-pi.sh` / `run-on-pi-native.sh` | SSH and run the respective binary |

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
  (see `generate-cap-cache.sh`). The cache lives in `cap-cache/` at the project
  root (not `target/`) so it survives `mvn clean` and is committed to git.

## CAP cache — when to regenerate

Run `./generate-cap-cache.sh` and commit the result when:
1. GraalVM CE version changes (version determines which C types are queried).
2. Pi OS or glibc is updated (struct layouts may change).
3. New `@CStruct` / `@CField` annotations are added to the project.

Not needed when only Java code changes.

## aarch64 static library symlinks

`setup-aarch64-libs.sh` creates two symlinks inside the local GraalVM CE
installation pointing at the Pi's GraalVM CE installation via the SSHFS sysroot
mount. native-image's JDK static lib search path is hardcoded to
`$JAVA_HOME/lib/static/{target}/{libc}/` and cannot be redirected via any
native-image flag. Symlinks are the only mechanism that avoids copying files.

The symlinks depend on:
- Sysroot being mounted (`~/mnt/pios12_root`)
- GraalVM CE 25.0.2 installed on BlackRaspberry

Re-run `setup-aarch64-libs.sh` after upgrading GraalVM on either machine.

## Native image option names — GraalVM CE 25 reference

These were discovered by trial and error and verified against `native-image --help`:

| Wrong (from online docs / EE) | Correct (CE 25) |
|---|---|
| `--target-platform=linux-aarch64` | `--target=linux-aarch64` |
| `-H:CCompilerPath=...` | `--native-compiler-path=...` |
| `-H:CCompilerOption=...` | `--native-compiler-options=...` |

The `-H:` variants still exist as experimental aliases but emit warnings.

## Next steps

When jextract FFM bindings for libgpiod are added:
1. Remove `-H:-ForeignAPISupport` from pom.xml native profile.
2. Add `--enable-native-access=ALL-UNNAMED` to pom.xml native profile.
3. Add `RuntimeForeignAccess.registerForDowncall()` calls in a `Feature`
   implementation (AOT requirement).
4. Regenerate the CAP cache (`./generate-cap-cache.sh`) — new C types will be
   queried.
