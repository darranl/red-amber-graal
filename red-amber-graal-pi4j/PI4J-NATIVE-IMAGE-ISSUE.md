# Pi4J v4 Native Image Issue - Investigation Notes

**Date:** 2026-03-07 (resolved 2026-04-11)
**Status:** JVM ✅ Working | Native Image ✅ Working (resolved via `pi4j-ffm-metadata-bookworm-graal25`)

## Summary

Successfully converted project from jextract-generated FFM bindings to Pi4J v4.0.0.
**JVM deployment works perfectly.** Native image builds successfully but fails at 
runtime with FFM registration error despite proper metadata configuration.

## What Works: JVM Mode

Tested on Raspberry Pi 4B (Raspberry Pi OS, aarch64):
- ✅ Shaded JAR (590 KB) deploys and runs
- ✅ GPIO pins BCM 5, 6, 13 controlled successfully  
- ✅ Traffic light sequence functional
- ✅ Pi4J v4 libgpiod integration working perfectly

## The Issue: Native Image Runtime Failure

**Build:** ✅ Succeeds (19 MB, ~47s cross-compile, "8 downcalls registered")  
**Runtime:** ❌ Fails immediately during Pi4J initialization

```
Exception in thread "main" org.graalvm.nativeimage.MissingForeignRegistrationError: 
Cannot perform downcall with leaf type (long,int)long.
```

- Fails at: `Pi4JNativeContext.<clinit>` line 38
- During: `Pi4J.newAutoContext()` initialization
- Before: Any GPIO operations

## Root Cause

**Pi4J v4.0.0 does NOT include GraalVM native-image metadata.**

We created manual FFM registration in `src/main/resources/META-INF/native-image/.../reachability-metadata.json`
with 8 downcall shapes including the failing `(long,int)→long`. Build confirms "8 downcalls registered"
but at runtime GraalVM still can't find the registration.

**Theories:**
1. GraalVM bug - metadata read at build but not embedded/applied at runtime
2. Pi4J static init timing - FFM calls happen before metadata is active
3. Cross-compilation complication - issue might be specific to cross-compile

## Investigation Done

✅ Created reachability-metadata.json with all needed FFM shapes  
✅ Verified metadata is in JAR (both shaded and original)  
✅ Confirmed build reads metadata ("8 downcalls registered")  
✅ Tested JVM version - works perfectly, proves code is correct  
❌ Tried native-image.properties - invalid approach  
❌ Tried explicit build flags - no such flags exist  
❌ Multiple clean rebuilds - consistent failure  

## Recommendation

**Use JVM version (shaded JAR) for deployment** - fully functional and tested.

For native image, options are:
1. File issue with Pi4J requesting native-image metadata
2. Try native build ON the Pi (not cross-compile) to isolate variables
3. Deep-dive into Pi4J FFM initialization with GraalVM team
4. Wait for Pi4J v4.1+ with potential native-image support

## Files

All documentation updated:
- `README.md` - Added Known Issues section with full details
- `CLAUDE.md` - Updated Status with JVM/Native breakdown
- `CONVERSION.md` - Added build verification results and current status
- This file - Detailed investigation notes

Manual FFM registration at:
- `src/main/resources/META-INF/native-image/dev.lofthouse/red-amber-graal-pi4j/reachability-metadata.json`
