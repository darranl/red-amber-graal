# red-amber-graal-pi4j

GraalVM native image build of the traffic light controller for BlackRaspberry
(Raspberry Pi 4B, aarch64) using **Pi4J v4**. This project cross-compiles from 
an x86_64 Linux development machine to aarch64 using GraalVM CE 25, the 
`aarch64-linux-gnu-gcc` toolchain, and an SSHFS mount of the Pi's root filesystem 
as the sysroot.

**Status (2026-03-07):**  
✅ JVM deployment fully functional and tested  
⚠️ Native image builds but has runtime FFM registration issue - see [Known Issues](#known-issues)

The project produces two deployable artefacts that coexist on the Pi:

| Artefact | Status | Make target | Pi path |
|---|---|---|---|
| Shaded JVM JAR + wrapper | ✅ Working | `make deploy` | `~/.local/bin/red-amber-graal-pi4j` |
| Native binary | ⚠️ Runtime issue | `make deploy-native` | `~/.local/bin/red-amber-graal-pi4j-native` |

## Makefile quick-reference

Run `make help` to list all available targets:

```
Usage: make <target>

Setup (one-time):
  setup-libs           Symlink aarch64 static libs from Pi into local GraalVM CE
  gen-cap-cache        Generate CAP cache on Pi and fetch result back

Deploy:
  deploy               Build shaded JAR and deploy to Pi
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

5. **CAP cache** — must exist before the native build. The cache is auto-generated
   during the native build; regenerate only if the GraalVM CE version changes 
   (see [CAP cache](#cap-cache)):
   ```bash
   make gen-cap-cache   # requires Podman + QEMU (make setup-podman)
   ```

### BlackRaspberry (aarch64)

- **GraalVM CE 25.0.2** installed via sdkman — needed to run the JVM wrapper:
  ```bash
  sdk install java 25.0.2-graalce
  ```

---

## Building

### Shaded JAR

```bash
sdk use java 25.0.2-graalce   # or any Java 25
mvn package
```

Produces a shaded JAR at `target/red-amber-graal-pi4j-0.0.1-SNAPSHOT.jar` containing
all Pi4J dependencies.

### Native image (aarch64 cross-compile)

Ensure all prerequisites above are satisfied, then:

```bash
sdk use java 25.0.2-graalce
mvn package -DskipTests -Dnative
```

Output: `target/red-amber-graal-pi4j-native` — a self-contained aarch64 ELF
binary ready to copy to the Pi.

### Native image (build on BlackRaspberry)

When cross-compilation is not available, build the native image directly on BlackRaspberry.
Requires GraalVM CE installed on both machines at the same path:

    make deploy-native-pi

This SSHes to BlackRaspberry, runs `native-image` there (no cross-compiler or sysroot needed),
and installs the binary to `~/.local/bin/red-amber-graal-pi4j-native`. Note: BlackRaspberry
4B has 4 GB RAM and can complete the build in ~5 minutes; this path is not viable on the Pi
Zero 2 W (512 MB RAM).

---

## Deployment

```bash
make deploy                # build shaded JAR + scp JAR and wrapper script to Pi
make deploy-native         # build native binary (Maven cross-compile) + scp to Pi
make deploy-native-podman  # build native binary (Podman/QEMU arm64) + scp to Pi
```

Note: `deploy-native-pi` target has been removed - cross-compilation only.

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
information is recorded by running small C programs natively on aarch64
and cannot be generated locally on x86_64 without QEMU.

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

The script builds the JAR, then runs native-image inside an arm64 Podman
container (QEMU user-mode emulation) with `+NewCAPCache +ExitAfterCAPCache`,
which generates the cache and exits without building a full image. The cache
is written directly to `cap-cache/`. Commit the updated `cap-cache/` directory.

Prerequisites: Podman installed and QEMU aarch64 binfmt registered
(`make setup-podman`). No Pi connectivity required.

---

## Pi4J Integration

This project uses **Pi4J v4.0.0** for GPIO control via libgpiod. Pi4J provides a
high-level Java API that abstracts the FFM (Foreign Function & Memory) bindings to
libgpiod, making the code simpler and more maintainable than direct FFM calls.

### Key Benefits

- **No manual FFM binding generation** — Pi4J handles all native library integration
- **Simplified GPIO API** — `digitalOutput().create(pin)` vs manual memory management
- **Better resource management** — Context handles cleanup automatically
- **Cross-platform support** — Pi4J works across different Raspberry Pi models

### Native Image Compatibility

Pi4J v4's `pi4j-plugin-ffm` uses the FFM API internally to communicate with libgpiod.

**JVM Mode:** ✅ Fully functional  
**Native Image:** ⚠️ Partial - Pi4J v4.0.0 does not include GraalVM native-image metadata

We've created manual FFM registration in `src/main/resources/META-INF/native-image/.../reachability-metadata.json`,
but GraalVM doesn't apply it effectively at runtime (see [Known Issues](#known-issues)).
The native binary builds but fails during Pi4J initialization with FFM registration errors.

---

## Known Issues

### Native Image Runtime Error (2026-03-07)

**Issue:** Native image builds successfully but fails at runtime with:
```
MissingForeignRegistrationError: Cannot perform downcall with leaf type (long,int)long
```

**Details:**
- Build completes: 19 MB binary, ~47 seconds, reports "8 downcalls registered"
- Fails during Pi4J initialization: `Pi4JNativeContext.<clinit>` line 38
- JVM version works perfectly, proving code and Pi4J are correct
- Created manual `reachability-metadata.json` with 8 FFM downcall shapes
- GraalVM appears to read metadata at build time but doesn't apply it at runtime

**Root Cause:**
Pi4J v4.0.0 does not include GraalVM native-image metadata. Manual registration was
created but GraalVM doesn't apply FFM metadata effectively at runtime. This may be:
- GraalVM bug in FFM metadata handling for cross-compiled binaries
- Pi4J initialization creating FFM calls before metadata is loaded
- Subtle mismatch in registration format vs Pi4J's usage

**Workaround:**
Use the JVM version (shaded JAR) which is fully functional and tested.

**Further Investigation:**
- File issue with Pi4J project requesting native-image metadata
- Deep-dive into Pi4J's FFM initialization sequence
- Test with GraalVM native build (not cross-compile) to isolate cross-compilation issues

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
