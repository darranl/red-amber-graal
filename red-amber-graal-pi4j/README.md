# red-amber-graal-pi4j

GraalVM native image build of the traffic light controller for BlackRaspberry
(Raspberry Pi 4B, aarch64) using **Pi4J v4**. This project cross-compiles from
an x86_64 Linux development machine to aarch64 using GraalVM CE 25, the
`aarch64-linux-gnu-gcc` toolchain, and a read-only mount of the `graalvm-pi-builder`
container image as the aarch64 sysroot.

**Status (2026-04-11):**
✅ JVM deployment fully functional and tested
✅ Native image builds and runs correctly (cross-compile via `deploy-native`)

The project produces two deployable artefacts that coexist on the Pi:

| Artefact | Status | Make target | Pi path |
|---|---|---|---|
| Shaded JVM JAR + wrapper | ✅ Working | `make deploy` | `~/.local/bin/red-amber-graal-pi4j` |
| Native binary | ✅ Working | `make deploy-native` | `~/.local/bin/red-amber-graal-pi4j-native` |

## Makefile quick-reference

Run `make help` to list all available targets:

```
Usage: make <target>

Setup:
  setup-podman         Install QEMU packages for arm64 Podman containers (Arch Linux)
  setup-libs           Symlink aarch64 static libs from container image into local GraalVM CE
  mount-sysroot        Mount graalvm-pi-builder image as aarch64 sysroot, print mount path
  unmount-sysroot      Unmount the graalvm-pi-builder image sysroot
  gen-native-config    Run native-image-agent on Pi to generate reachability-metadata.json

Deploy:
  deploy               Build shaded JAR and deploy to Pi
  deploy-native        Build aarch64 native binary (Maven cross-compile) and deploy to Pi

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

1. **GitHub Packages access** — `mvn package` downloads
   `dev.lofthouse.pi4j:pi4j-ffm-metadata-bookworm-graal25` from GitHub Packages, which
   requires authentication even for read access. Add a `<server>` entry to
   `~/.m2/settings.xml`:

   ```xml
   <settings>
     <servers>
       <server>
         <id>github</id>
         <username>YOUR_GITHUB_USERNAME</username>
         <password>YOUR_GITHUB_PAT</password>
       </server>
     </servers>
   </settings>
   ```

   The PAT needs the **`read:packages`** scope. Generate one at
   [github.com/settings/tokens](https://github.com/settings/tokens). If `settings.xml`
   already exists, add the `<server>` block inside the existing `<servers>` element.

2. **GraalVM CE 25.0.2** installed via sdkman and selected before building:
   ```bash
   sdk install java 25.0.2-graalce
   sdk use java 25.0.2-graalce
   ```

3. **aarch64 cross-compiler** from the system package manager:
   ```bash
   sudo apt install gcc-aarch64-linux-gnu
   ```

4. **Podman** — used to mount the `graalvm-pi-builder` container image as the aarch64
   sysroot and to auto-generate the CAP cache during native builds:
   ```bash
   # One-time: install QEMU binfmt support for CAP cache generation
   make setup-podman
   ```
   The `graalvm-pi-builder` image (`ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25`)
   must be present locally. Pull it with:
   ```bash
   podman pull ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25
   ```
   `make deploy-native` mounts the image automatically as the sysroot — no Pi connectivity
   or SSHFS mount required.

5. **aarch64 static library symlinks** — handled automatically by `make deploy-native`.
   To set up or refresh manually:
   ```bash
   make setup-libs
   ```
   This mounts the container image, creates two symlinks inside the local GraalVM CE
   installation pointing at the aarch64 GraalVM in the container (`/opt/graalvm`), and
   unmounts. The symlinks are refreshed on every `make deploy-native` run.

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
SYSROOT=$(./scripts/setup/mount-image-sysroot.sh)
mvn package -DskipTests -Dnative "-Dsysroot=$SYSROOT"
./scripts/setup/unmount-image-sysroot.sh
```

Or use `make deploy-native` which handles mount/unmount and deploy automatically.

Output: `target/red-amber-graal-pi4j-native` — a self-contained aarch64 ELF
binary ready to copy to the Pi.

---

## Deployment

```bash
make deploy          # build shaded JAR + scp JAR and wrapper script to Pi
make deploy-native   # mount container sysroot, build native binary, scp to Pi
```

`deploy-native` mounts the `graalvm-pi-builder` image automatically, runs the Maven
cross-compile with `-Dsysroot=<mount-path>`, deploys, and unmounts on completion or failure.

> **Note:** `make deploy-native-podman` (Podman/QEMU full native build) is not viable —
> it hung during testing with impractical build times. The target is preserved for
> debugging only and will print a warning before running.

## Running on the Pi

```bash
make run          # runs the JVM version via SSH
make run-native   # runs the native binary via SSH
make debug        # runs the JVM version with JDWP debugging (port 5005)
```

---

## CAP cache

The C Annotation Processor (CAP) cache lives in `target/cap-cache/` and is
**not** committed to version control — it is auto-generated during each native
build (`mvn package -Dnative`) and wiped by `mvn clean`. It contains precomputed
C type layout information — struct field offsets and type sizes — for the
aarch64/Linux/glibc target. This information is recorded by running small C
programs natively on aarch64 and cannot be generated locally on x86_64 without QEMU.

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
- The container image is updated (the GraalVM version is what matters, not the image content).
- The sysroot is remounted (the cache is local in `target/cap-cache/`).

### Regenerating

The cache is regenerated automatically by `mvn package -Dnative`. To force
regeneration without a full image build (e.g. after `mvn clean`), run the
native build — the exec-maven-plugin binding will invoke
`scripts/setup/generate-cap-cache.sh` before native-image runs.

The script runs native-image inside an arm64 Podman container (QEMU user-mode
emulation) with `+NewCAPCache +ExitAfterCAPCache`, which generates the cache and
exits without building a full image. The cache is written to `target/cap-cache/`.

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
**Native Image:** ✅ Working (metadata provided by `pi4j-ffm-metadata-bookworm-graal25`)

Pi4J v4.0.0 ships **no** GraalVM native-image metadata of its own. The FFM reachability
metadata is provided by a separate artifact in this repository:

```
dev.lofthouse.pi4j:pi4j-ffm-metadata-bookworm-graal25:4.0.0-3
```

This is declared as a dependency in `pom.xml`. native-image discovers the metadata
automatically from the classpath (`META-INF/native-image/`). The artifact is built from
the `pi4j-graalvm-metadata/` project in this repository.

#### When to update the FFM metadata

**Update when Pi4J is upgraded** (`pi4j.version` in `pom.xml`). Pi4J creates all its
FFM downcall stubs in static initialisers, so upgrading Pi4J may add, remove, or change
the `FunctionDescriptor` shapes registered in the metadata artifact.

To regenerate:

```bash
# Bump pi4j.version in pom.xml first, then:
make gen-native-config
# Review target/agent-config/reachability-metadata.json
# Update pi4j-graalvm-metadata/ project and publish a new artifact version
# Bump the artifact version in pom.xml to the newly published version
make deploy-native     # verify the new binary works
```

You do **not** need to update when:
- Java application code changes (no new Pi4J calls are added/removed)
- GraalVM CE version changes (Pi4J's downcall signatures are not GraalVM-version-specific)
- The sysroot is remounted or CAP cache is refreshed

See [`notes/pi4j-graalvm-ffm-registration.md`](../../notes/pi4j-graalvm-ffm-registration.md)
for a detailed explanation of why this metadata is needed and how it was derived.

---

## Cross-compilation notes

The native profile in `pom.xml` encodes several workarounds discovered during
the initial cross-compilation setup:

| Flag | Reason |
|---|---|
| `--target=linux-aarch64` | Tells native-image to generate aarch64 code |
| `--native-compiler-path=/usr/bin/aarch64-linux-gnu-gcc` | Use the cross-compiler for C compilation and linking |
| `--native-compiler-options=--sysroot=${sysroot}` | Point the cross-compiler at the aarch64 sysroot for headers and libraries; `${sysroot}` is the container image mount path passed via `-Dsysroot=` |
| `-H:CAPCacheDir=...` | Required by native-image when cross-compiling; see [CAP cache](#cap-cache) |
| `-H:CLibraryPath=${sysroot}/usr/lib/aarch64-linux-gnu` | The cross-compiler's sysroot support does not automatically add the Debian multiarch library path, so `-lz` and other system libraries are not found without this |

The sysroot is provided by mounting the `graalvm-pi-builder` container image
(`ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25`) via `podman image mount`.
This is a read-only filesystem view of a Debian bookworm arm64 image — the same
OS and glibc as Pi OS 12. No QEMU, no emulation overhead.

Rootless Podman requires `podman image mount` to run inside a `podman unshare` user
namespace. `deploy-pi-native.sh` handles this automatically via a self-reinvocation
pattern: it re-executes itself inside `podman unshare` for the mount/build/unmount
phase, then returns to the outer shell for the scp deploy.

The two symlinks created by `make setup-libs` (or automatically by `make deploy-native`)
slot the aarch64 GraalVM static libraries from the container into the expected locations
inside the local GraalVM CE installation:

```
~/.sdkman/candidates/java/25.0.2-graalce/lib/static/linux-aarch64/
  → <container-mount>/opt/graalvm/lib/static/linux-aarch64/

~/.sdkman/candidates/java/25.0.2-graalce/lib/svm/clibraries/linux-aarch64/
  → <container-mount>/opt/graalvm/lib/svm/clibraries/linux-aarch64/
```

native-image derives the JDK static library search path directly from
`JAVA_HOME` and cannot be redirected via any build argument; the symlinks are
the only way to provide these files without copying them locally. The symlinks
are dangling when the image is not mounted — this is expected and harmless.
