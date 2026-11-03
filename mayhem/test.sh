#!/usr/bin/env bash
#
# mayhem/test.sh — RUN libplacebo's own test suite (the non-GPU meson tests built by build.sh into
# build-tests/) and a known-answer oracle whose printed values are diffed against
# mayhem/oracle/expected.txt. The oracle diff is what fails a neutered/no-op program: a binary
# that just exits 0 prints nothing and no longer matches.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

[ -x build-tests/oracle ] || { echo "build-tests/oracle missing: mayhem/build.sh did not run" >&2; emit_ctrf libplacebo 0 1; exit 1; }

passed=0 ; failed=0

# Known-answer oracle: one test per section, output diffed against oracle/expected/<section>.txt.
for sec in lut_1d lut_domain lut_3d lut_truncated lut_badrange options color filter; do
  if [ -s "mayhem/oracle/expected/$sec.txt" ] && build-tests/oracle "$sec" 2>/dev/null | diff -u "mayhem/oracle/expected/$sec.txt" - >&2; then
    passed=$((passed+1))
  else
    failed=$((failed+1)); echo "ORACLE MISMATCH: $sec" >&2
  fi
done

# libplacebo's own meson tests (assertion-based; REQUIRE() aborts on failure).
out="$(cd build-tests && meson test --no-rebuild 2>&1)"; rc=$?
echo "$out" | tail -n 30
p="$(echo "$out" | sed -n 's/^Ok: *\([0-9]*\).*/\1/p')" ; f="$(echo "$out" | sed -n 's/^Fail: *\([0-9]*\).*/\1/p')"
t="$(echo "$out" | sed -n 's/^Timeout: *\([0-9]*\).*/\1/p')"
passed=$((passed + ${p:-0})) ; failed=$((failed + ${f:-0} + ${t:-0}))
[ "$rc" -eq 0 ] || [ "$failed" -gt 0 ] || failed=$((failed+1))

emit_ctrf "meson-test+oracle" "$passed" "$failed"
