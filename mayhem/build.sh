#!/usr/bin/env bash
#
# mayhem/build.sh — build libplacebo's fuzz harnesses (sanitized) and its functional test suite
# (normal flags). Runs in the commit image as `mayhem` in /mayhem; re-runnable and offline: meson
# is installed in the image and every dependency (3rdparty/ submodules) is already in the tree.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# Optional GPU backends/codecs are off: the harnesses and tests only need the core library plus
# the dummy GPU, and this keeps the build free of system deps beyond meson.
MESON_OPTS=(-Dvulkan=disabled -Dopengl=disabled -Dd3d11=disabled -Dglslang=disabled
            -Dshaderc=disabled -Dlcms=disabled -Ddovi=disabled -Dlibdovi=disabled
            -Dunwind=disabled -Dxxhash=disabled -Ddemos=false -Ddefault_library=static)

# 1) Sanitized static library for the harnesses.
rm -rf build-fuzz
CFLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link" CXXFLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link" \
LDFLAGS="$SANITIZER_FLAGS" \
    meson setup build-fuzz "${MESON_OPTS[@]}" -Dtests=false -Db_ndebug=false
ninja -C build-fuzz -j"$MAYHEM_JOBS" src/libplacebo.a

# 2) Harnesses: libFuzzer binary + standalone reproducer, each linked with the leak-sanitizer
#    opt-out. The harnesses include internal headers (tests/utils.h, shaders.h), hence -Isrc.
INCS=(-DPL_STATIC -I"$SRC/src" -I"$SRC/src/include" -I"$SRC/build-fuzz/src" -I"$SRC/build-fuzz/src/include")
LIBS=("$SRC/build-fuzz/src/libplacebo.a" -lstdc++ -lm -lpthread)

$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o /tmp/lsan_off.o
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o

for t in fuzz_lut fuzz_options fuzz_shaders fuzz_user_shaders; do
    $CC $SANITIZER_FLAGS $DEBUG_FLAGS -std=gnu11 "${INCS[@]}" -c "$SRC/mayhem/$t/harness.c" -o "/tmp/$t.o"
    $CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE "/tmp/$t.o" /tmp/lsan_off.o "${LIBS[@]}" -o "/mayhem/$t"
    $CC $SANITIZER_FLAGS $DEBUG_FLAGS /tmp/standalone_main.o "/tmp/$t.o" /tmp/lsan_off.o "${LIBS[@]}" -o "/mayhem/$t-standalone"
done

# 3) The project's own test suite (non-GPU tests) plus the known-answer oracle, built with the
#    project's NORMAL flags and no sanitizers, for mayhem/test.sh to run.
rm -rf build-tests
env -u CFLAGS -u CXXFLAGS -u LDFLAGS \
    CFLAGS="$COVERAGE_FLAGS" CXXFLAGS="$COVERAGE_FLAGS" LDFLAGS="$COVERAGE_FLAGS" \
    meson setup build-tests "${MESON_OPTS[@]}" -Dtests=true
ninja -C build-tests -j"$MAYHEM_JOBS"
$CC -O1 $COVERAGE_FLAGS -std=gnu11 -DPL_STATIC -I"$SRC/src/include" -I"$SRC/build-tests/src/include" \
    "$SRC/mayhem/oracle/oracle.c" "$SRC/build-tests/src/libplacebo.a" -lstdc++ -lm -lpthread \
    -o "$SRC/build-tests/oracle"
