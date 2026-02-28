# red-amber-graal-libgpio

GraalVM native image build of the traffic light controller for BlackRaspberry
(Raspberry Pi 4B, aarch64). This project cross-compiles from an x86_64 Linux
development machine to aarch64 using GraalVM CE 25, the `aarch64-linux-gnu-gcc`
toolchain, and an SSHFS mount of the Pi's root filesystem as the sysroot.

The project produces two deployable artefacts that coexist on the Pi:

| Artefact | Make target | Pi path |
|---|---|---|
| JVM JAR + wrapper | `make deploy` | `~/.local/bin/red-amber-graal-libgpio` |
| Native binary | `make deploy-native` | `~/.local/bin/red-amber-graal-libgpio-native` |

## Makefile quick-reference

Run `make help` to list all available targets:

```
Usage: make <target>

Setup (one-time):
  setup-libs           Symlink aarch64 static libs from Pi into local GraalVM CE
  gen-cap-cache        Generate CAP cache on Pi and fetch result back
  gen-ffm-bindings     Generate FFM Java bindings for libgpiod via jextract

Deploy:
  deploy               Build JVM JAR and deploy to Pi
  deploy-native        Build aarch64 native binary and deploy to Pi
  deploy-native-pi     Build aarch64 native binary on BlackRaspberry and install in place
  deploy-native-podman Build aarch64 native binary (Podman/QEMU arm64) and deploy to Pi

Run:
  run                  Run JVM version on Pi via SSH
  run-native           Run native binary on Pi via SSH
  debug                Run JVM version on Pi with JDWP debugging (port 5005)
  run-local            Run JVM JAR locally
  run-local-native     Run native binary locally
```

## Why cross-compile?

GraalVM `native-image` is memory- and CPU-intensive. Building locally on a
16-core x86_64 machine is dramatically faster than building on the Pi itself,
and is the only practical option for the Pi Zero 2 W (512 MB RAM).

| Machine | Cores / RAM | `native-image` wall time |
|---|---|---|
| x86_64 dev machine | 16 cores / ample RAM | ~50 s |
| Raspberry Pi 4B | 4 cores / 4 GB RAM | ~5 min 22 s |
| Raspberry Pi Zero 2 W | 4 cores / 512 MB RAM | not viable |

---

## Prerequisites

### Local machine (x86_64)

1. **GraalVM CE 25.0.2** installed via sdkman and selected before building:
   ```bash
   sdk install java 25.0.2-graalce
   sdk use java 25.0.2-graalce
   ```

2. **aarch64 cross-compiler** from the system package manager:
   ```bash
   sudo apt install gcc-aarch64-linux-gnu
   ```

3. **Sysroot** — SSHFS mount of BlackRaspberry's root filesystem:
   ```bash
   systemctl --user start home-darranl-mnt-pios12_root.mount
   ```
   See the top-level `CLAUDE.md` for mount unit details.

4. **aarch64 static library symlinks** — one-time setup, run once per machine:
   ```bash
   make setup-libs
   ```
   This creates two symlinks inside the local GraalVM CE installation that point
   at the aarch64 static libraries from the Pi's GraalVM CE installation (via the
   sysroot mount). Requires the sysroot to be mounted and GraalVM CE 25.0.2 to be
   installed on BlackRaspberry.

5. **CAP cache** — must exist at `cap-cache/` before the native build. Generate
   it once (see [CAP cache](#cap-cache) below):
   ```bash
   make gen-cap-cache
   ```

6. **jextract** — required to regenerate the FFM bindings. Install via sdkman:
   ```bash
   sdk install jextract
   ```
   The generated sources are already committed; only re-run if libgpiod changes
   (see [FFM bindings](#ffm-bindings) below).

### BlackRaspberry (aarch64)

- **GraalVM CE 25.0.2** installed via sdkman — needed to generate the CAP cache
  and to run `deploy-pi.sh`'s JVM wrapper:
  ```bash
  sdk install java 25.0.2-graalce
  ```

---

## Building

### JVM JAR

```bash
sdk use java 25.0.2-graalce   # or any Java 25
mvn package
```

### Native image (aarch64 cross-compile)

Ensure all prerequisites above are satisfied, then:

```bash
sdk use java 25.0.2-graalce
mvn package -DskipTests -Dnative
```

Output: `target/red-amber-graal-libgpio-native` — a self-contained aarch64 ELF
binary ready to copy to the Pi.

### Native image (build on BlackRaspberry)

When cross-compilation is not available, build the native image directly on BlackRaspberry.
Requires GraalVM CE installed on both machines at the same path:

    make deploy-native-pi

This SSHes to BlackRaspberry, runs `native-image` there (no cross-compiler or sysroot needed),
and installs the binary to `~/.local/bin/red-amber-graal-libgpio-native`. Note: BlackRaspberry
4B has 4 GB RAM and can complete the build in ~5 minutes; this path is not viable on the Pi
Zero 2 W (512 MB RAM).

---

## Deployment

```bash
make deploy                # build JAR + scp JAR and wrapper script to Pi
make deploy-native         # build native binary (Maven cross-compile) + scp to Pi
make deploy-native-pi      # build native binary on BlackRaspberry directly
make deploy-native-podman  # build native binary (Podman/QEMU arm64) + scp to Pi
```

Both scripts check their prerequisites and print clear errors if anything is
missing (sysroot not mounted, native-image not found, etc.).

## Running on the Pi

```bash
make run          # runs the JVM version via SSH
make run-native   # runs the native binary via SSH
make debug        # runs the JVM version with JDWP debugging (port 5005)
```

---

## CAP cache

The C Annotation Processor (CAP) cache lives in `cap-cache/` and is committed
to version control. It contains precomputed C type layout information — struct
field offsets and type sizes — for the aarch64/Linux/glibc target. This
information is recorded by running small C programs natively on the Pi and
cannot be generated locally on x86_64 without QEMU.

### What it is

GraalVM's SubstrateVM substrate uses `@CStruct` / `@CField` annotations to
describe C types (e.g. `pthread_t`, `sigaction`, `struct timespec`). During a
native image build, native-image needs the actual byte offsets and sizes for
these types on the target platform. On a native (non-cross) build it compiles
and runs small query programs to measure them. When cross-compiling, it instead
reads them from the CAP cache.

### When to regenerate

Regenerate by running `./generate-cap-cache.sh` when:

- **GraalVM CE version changes** — the set of C types queried changes between
  versions; the cache records which GraalVM version produced it.
- **Pi OS or glibc is updated** — struct layouts can change between libc
  versions (rare in practice for the types GraalVM uses, but possible).
- **New `@CStruct` / `@CField` annotations are added** to the project — new
  C types are queried that are not yet in the cache.

You do NOT need to regenerate when:
- Java application code changes (no new C annotations).
- The Pi's GraalVM installation is updated *and* the version matches the local
  GraalVM CE version (the GraalVM version is what matters, not the Pi binary).
- The sysroot is remounted (the cache is already local in `cap-cache/`).

### Regenerating

```bash
make gen-cap-cache
```

The script builds the JAR, deploys it to BlackRaspberry, runs native-image
there with `+NewCAPCache +ExitAfterCAPCache` (which generates the cache and
exits without building a full image), then scps the `.cap` files back to
`cap-cache/`. Commit the updated `cap-cache/` directory.

---

## FFM bindings

The FFM (Foreign Function & Memory) Java bindings for libgpiod are generated
from `gpiod.h` on the Pi's sysroot using
[jextract](https://jdk.java.net/jextract/). The generated `.java` sources live
in `src/main/java/dev/lofthouse/redambergraal/ffm/` and are committed to
version control so a normal `mvn package` does not require jextract.

### Prerequisites

- **jextract** installed via sdkman: `sdk install jextract`
- **Sysroot mounted** at `~/mnt/pios12_root`

### Generating

```bash
make gen-ffm-bindings
```

This runs `scripts/setup/generate-ffm-bindings.sh`, which:

1. Deletes any previously generated sources under the package directory.
2. Runs `jextract --source` against `gpiod.h` from the sysroot.
3. Places the generated `.java` files in
   `src/main/java/dev/lofthouse/redambergraal/ffm/`.

Commit the generated sources after running.

### When to regenerate

- **libgpiod version changes** on the Pi — ABI changes may add or remove
  symbols.
- **Additional gpiod symbols are needed** — e.g. chip iteration, line events.

You do NOT need to regenerate when only Java application code changes.

---

## FFM native-image registration

### Why registration is needed

jextract generates `static final FunctionDescriptor DESC` fields in each inner class (e.g.
`gpiod_chip_open_by_name.DESC`) so that native-image's closed-world static analysis can
discover them automatically and pre-compile the required downcall stubs. In this project,
that mechanism fails because of a class-initialization chain:

1. `gpiod_h.java` line 21: `static final Arena LIBRARY_ARENA = Arena.ofAuto()` —
   `Arena.ofAuto()` is GC-managed; native-image cannot store it in the image heap, so
   `gpiod_h` is deferred to runtime initialization.
2. Every inner class (e.g. `gpiod_chip_open_by_name`) calls `gpiod_h.findOrThrow(...)`,
   making it also runtime-initialized.
3. `Linker.nativeLinker().downcallHandle(ADDR, DESC)` therefore runs at runtime, after
   build-time analysis is complete — so no stubs are pre-compiled.
4. At runtime, the first libgpiod call hits an unregistered descriptor shape and throws
   `MissingForeignRegistrationError: Cannot perform downcall with leaf type (long,long)long`.

See `notes/graalvm-ffm-static-discovery-bug.md` for the full root-cause chain.

### Approaches considered

| | JSON `reachability-metadata.json` | Java `Feature` + `RuntimeForeignAccess` |
|---|---|---|
| New Java source? | No | Yes (+ `native-image.properties` to register it) |
| GraalVM SDK compile dependency? | No | Yes |
| Auto-discovered from JAR? | Yes | Requires explicit `--features=` flag in build invocation |
| Type-safe? | No (C type strings) | Yes (ValueLayout constants) |
| Works for both Maven + on-Pi builds? | Yes, no script changes | Needs `--features=` added to `deploy-pi-native-on-pi.sh` |

### Decision: JSON `reachability-metadata.json`

The JSON approach was chosen because:
- No new Java source files or additional dependencies.
- Automatically picked up by native-image from `META-INF/native-image/` in the JAR classpath —
  works for both `mvn package -Dnative` and the direct `native-image` invocation on BlackRaspberry
  without any script changes.
- The descriptor shapes for this project are simple (`void*` and `int` only) — no risk of
  platform-specific ambiguity in the type strings.
- The error message itself (`MissingForeignRegistrationError`) points directly at this mechanism.

File location (packaged into the JAR by Maven automatically):

```
src/main/resources/META-INF/native-image/dev.lofthouse/red-amber-graal-libgpio/reachability-metadata.json
```

The JSON registers **shapes** (unique return+parameter type combinations), not individual
functions. The 6 libgpiod calls in `TrafficLightController.java` map to 5 unique shapes:

| Function | Descriptor | Registered shape |
|---|---|---|
| `gpiod_chip_open_by_name` | `void*(void*)` | `void*` ← `[void*]` |
| `gpiod_chip_get_line` | `void*(void*, int)` | `void*` ← `[void*, int]` |
| `gpiod_line_request_output` | `int(void*, void*, int)` | `int` ← `[void*, void*, int]` |
| `gpiod_line_set_value` | `int(void*, int)` | `int` ← `[void*, int]` |
| `gpiod_line_release` | `void(void*)` | `void` ← `[void*]` |
| `gpiod_chip_close` | `void(void*)` | `void` ← `[void*]` (same shape as above) |

### Doc reference

GraalVM JDK 25 — FFM API in Native Image, "Downcalls" section:
https://www.graalvm.org/jdk25/reference-manual/native-image/native-code-interoperability/ffm-api/#downcalls

---

## Cross-compilation notes

The native profile in `pom.xml` encodes several workarounds discovered during
the initial cross-compilation setup:

| Flag | Reason |
|---|---|
| `--target=linux-aarch64` | Tells native-image to generate aarch64 code |
| `--native-compiler-path=/usr/bin/aarch64-linux-gnu-gcc` | Use the cross-compiler for C compilation and linking |
| `--native-compiler-options=--sysroot=...` | Point the cross-compiler at the Pi's root filesystem for headers and libraries |
| `-H:-ForeignAPISupport` | Disables `ForeignFunctionsFeature`: when cross-compiling to aarch64, GraalVM CE 25 always initialises the x86_64 ABI trampoline generator (`ABIs$X86_64`) regardless of target, causing a `ClassCastException`. Re-enable (with `--enable-native-access=ALL-UNNAMED`) when FFM bindings are added. |
| `-H:CAPCacheDir=...` | Required by native-image when cross-compiling; see [CAP cache](#cap-cache) |
| `-H:CLibraryPath=.../usr/lib/aarch64-linux-gnu` | The cross-compiler's sysroot support does not automatically add the Debian multiarch library path, so `-lz` and other system libraries are not found without this |

The two symlinks created by `make setup-libs` slot the Pi's aarch64
static libraries into the expected locations inside the local GraalVM CE
installation:

```
~/.sdkman/candidates/java/25.0.2-graalce/lib/static/linux-aarch64/
  → $SYSROOT/home/darranl/.sdkman/candidates/java/25.0.2-graalce/lib/static/linux-aarch64/

~/.sdkman/candidates/java/25.0.2-graalce/lib/svm/clibraries/linux-aarch64/
  → $SYSROOT/home/darranl/.sdkman/candidates/java/25.0.2-graalce/lib/svm/clibraries/linux-aarch64/
```

native-image derives the JDK static library search path directly from
`JAVA_HOME` and cannot be redirected via any build argument; the symlinks are
the only way to provide these files without copying them locally.
