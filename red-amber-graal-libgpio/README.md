# red-amber-graal-libgpio

GraalVM native image build of the traffic light controller for BlackRaspberry
(Raspberry Pi 4B, aarch64). This project cross-compiles from an x86_64 Linux
development machine to aarch64 using GraalVM CE 25, the `aarch64-linux-gnu-gcc`
toolchain, and an SSHFS mount of the Pi's root filesystem as the sysroot.

The project produces two deployable artefacts that coexist on the Pi:

| Artefact | Script | Pi path |
|---|---|---|
| JVM JAR + wrapper | `deploy-pi.sh` | `~/.local/bin/red-amber-graal-libgpio` |
| Native binary | `deploy-pi-native.sh` | `~/.local/bin/red-amber-graal-libgpio-native` |

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
   ./setup-aarch64-libs.sh
   ```
   This creates two symlinks inside the local GraalVM CE installation that point
   at the aarch64 static libraries from the Pi's GraalVM CE installation (via the
   sysroot mount). Requires the sysroot to be mounted and GraalVM CE 25.0.2 to be
   installed on BlackRaspberry.

5. **CAP cache** — must exist at `cap-cache/` before the native build. Generate
   it once (see [CAP cache](#cap-cache) below):
   ```bash
   ./generate-cap-cache.sh
   ```

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

---

## Deployment

```bash
./deploy-pi.sh          # build JAR + scp JAR and wrapper script to Pi
./deploy-pi-native.sh   # build native binary + scp to Pi
```

Both scripts check their prerequisites and print clear errors if anything is
missing (sysroot not mounted, native-image not found, etc.).

## Running on the Pi

```bash
./run-on-pi.sh          # runs the JVM version via SSH
./run-on-pi-native.sh   # runs the native binary via SSH
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
./generate-cap-cache.sh
```

The script builds the JAR, deploys it to BlackRaspberry, runs native-image
there with `+NewCAPCache +ExitAfterCAPCache` (which generates the cache and
exits without building a full image), then scps the `.cap` files back to
`cap-cache/`. Commit the updated `cap-cache/` directory.

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

The two symlinks created by `setup-aarch64-libs.sh` slot the Pi's aarch64
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
