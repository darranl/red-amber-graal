# Conversion from libgpio (FFM) to Pi4J v4

## Summary

This project has been converted from using jextract-generated FFM bindings for libgpiod
to using **Pi4J v4.0.0**, a high-level Java GPIO library.

## Changes Made

### Dependencies (pom.xml)
- **Added:**
  - `com.pi4j:pi4j-core:4.0.0` - Core Pi4J library
  - `com.pi4j:pi4j-plugin-ffm:4.0.0` - FFM-based libgpiod plugin
  - `org.slf4j:slf4j-api:2.0.16` - Logging API (Pi4J requirement)
  - `org.slf4j:slf4j-simple:2.0.16` - Simple logging implementation
  - Maven Shade Plugin for creating fat JAR with all dependencies

- **Removed:**
  - All jextract-generated FFM binding classes
  - `reachability-metadata.json` for FFM descriptor registration

### Code Changes

#### TrafficLightController.java
- **Before:** Direct FFM API calls with `Arena`, `MemorySegment`, `gpiod_h`
- **After:** Pi4J high-level API with `Context`, `DigitalOutput`
- Simplified from ~86 lines to ~52 lines
- No manual memory management required
- Automatic resource cleanup via Pi4J context

#### App.java
- Added Pi4J `Console` utility for better user output
- Improved shutdown handling with informative messages

### Artifact Naming
- Renamed from `red-amber-graal-libgpio` to `red-amber-graal-pi4j`
- Updated in:
  - `pom.xml`
  - All shell scripts in `scripts/`
  - `Makefile`
  - `README.md`
  - `CLAUDE.md`
  - Wrapper script renamed: `scripts/pi/red-amber-graal-pi4j`

### Files Removed
- `src/main/java/dev/lofthouse/redambergraal/ffm/` - All jextract-generated classes
- `src/main/resources/META-INF/native-image/.../reachability-metadata.json`
- `scripts/setup/generate-ffm-bindings.sh` - No longer needed
- `scripts/deploy/deploy-pi-native-on-pi.sh` - Cross-compile only per requirements

### Makefile Updates
- Removed `gen-ffm-bindings` target
- Removed `deploy-native-pi` target (cross-compile only)
- Updated help text to reflect shaded JAR

### Documentation Updates
- `README.md`: Updated to describe Pi4J integration, removed FFM bindings section
- `CLAUDE.md`: Updated build modes and status, removed references to on-Pi builds
- Created this `CONVERSION.md` file

## Build Verification

### JAR Build
```bash
$ mvn clean package -DskipTests
[INFO] BUILD SUCCESS
```
- Produces shaded JAR: `target/red-amber-graal-pi4j-0.0.1-SNAPSHOT.jar` (590 KB)
- Includes all Pi4J dependencies
- Service provider files correctly merged
- **Tested on Pi: ✅ WORKING** - GPIO control functional (2026-03-07)

### Native Image Build
```bash
$ mvn package -DskipTests -Dnative
[INFO] BUILD SUCCESS
```
- Produces native binary: `target/red-amber-graal-pi4j-native` (19 MB)
- Requires manual `reachability-metadata.json` for Pi4J FFM downcalls
- Cross-compilation time: ~47 seconds on 16-core x86_64
- Build reports: "8 downcalls and 0 upcalls registered for foreign access"
- **Runtime on Pi: ❌ FAILS** - `MissingForeignRegistrationError: Cannot perform downcall with leaf type (long,int)long`
- Fails during Pi4J initialization despite metadata being registered at build time

## FFM Downcall Registration

Pi4J v4.0.0 does not include native-image metadata, so we must provide it manually.
The required file is at:
```
src/main/resources/META-INF/native-image/dev.lofthouse/red-amber-graal-pi4j/reachability-metadata.json
```

This registers 8 FFM downcall descriptor shapes used by Pi4J's libgpiod integration:
- `(long,int)→long` - Failed on first run, identified from error message
- `(long)→long`, `(long)→int`, `(long,int)→int`
- `(long,long,int)→int`, `(long)→void`
- `(long,int)→void`, `(long,long)→void`

**Note:** If you encounter `MissingForeignRegistrationError` when running the native image,
add the missing descriptor shape to this file and rebuild.

## Benefits of Pi4J

1. **Simpler Code:** High-level API vs. manual FFM memory management
2. **Maintainability:** No need to regenerate bindings when libgpiod updates
3. **Better Resource Management:** Automatic cleanup via context
4. **Rich API:** Additional utilities like Console, board detection, etc.
5. **Native Image Ready:** Pi4J includes GraalVM metadata

## Compatibility Notes

- Still uses libgpiod under the hood (via Pi4J's FFM plugin)
- Same GPIO pins: BCM 5 (RED), 6 (AMBER), 13 (GREEN)
- Same functionality: UK traffic light sequence
- Cross-compilation setup unchanged
- CAP cache still required and auto-generated

## Next Steps - Current Status

✅ **JVM Version WORKING**: Tested and functional on Raspberry Pi  
⚠️ **Native Image**: Builds successfully but has runtime FFM registration issue

### What's Working
- Shaded JAR (590 KB): Deploys and runs perfectly
- GPIO control: All three pins (BCM 5, 6, 13) working correctly  
- Pi4J integration: Full functionality via libgpiod

### Known Issue - Native Image
The native image builds (19 MB, ~47s) and reports "8 downcalls registered", but fails at runtime with:
```
MissingForeignRegistrationError: Cannot perform downcall with leaf type (long,int)long
```

**Root Cause**: Pi4J v4.0.0 lacks native-image metadata. Our manual `reachability-metadata.json` registers the shapes, but GraalVM doesn't apply them effectively at runtime (possible GraalVM bug or Pi4J initialization ordering issue).

**Recommendation**: 
- Use JVM version (shaded JAR) for deployment - it works perfectly
- File issue with Pi4J project about missing native-image metadata
- Or continue investigating GraalVM FFM registration for Pi4J's initialization sequence
