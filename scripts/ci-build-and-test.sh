#!/usr/bin/env bash
set -euo pipefail

project="Fuji.xcodeproj"
scheme="Fuji"
destination="platform=macOS"
derived_data_path="${DERIVED_DATA_PATH:-$PWD/.derivedData}"
require_test_target="${REQUIRE_TEST_TARGET:-0}"
test_target_name="${TEST_TARGET_NAME:-FujiTests}"
allow_test_skip_for_os_mismatch="${ALLOW_TEST_SKIP_FOR_OS_MISMATCH:-1}"

version_le() {
  [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

detect_test_target_deployment_target() {
  xcodebuild \
    -project "$project" \
    -target "$test_target_name" \
    -configuration Debug \
    -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/MACOSX_DEPLOYMENT_TARGET =/ { print $2; exit }'
}

echo "==> Debug build (unsigned)"
xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -configuration Debug \
  -destination "$destination" \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Release build (unsigned)"
xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -configuration Release \
  -destination "$destination" \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO \
  build

if xcodebuild -list -project "$project" | grep -Eq "^[[:space:]]*$test_target_name$"; then
  runner_macos_version="$(sw_vers -productVersion)"
  test_target_macos_target="$(detect_test_target_deployment_target || true)"

  if [[ -n "$test_target_macos_target" ]] && ! version_le "$test_target_macos_target" "$runner_macos_version"; then
    if [[ "$allow_test_skip_for_os_mismatch" == "1" ]]; then
      echo "==> Skipping tests: runner macOS $runner_macos_version is lower than $test_target_name deployment target $test_target_macos_target."
      exit 0
    fi

    echo "Error: runner macOS $runner_macos_version is lower than $test_target_name deployment target $test_target_macos_target." >&2
    exit 1
  fi

  echo "==> Unit tests"
  xcodebuild \
    -project "$project" \
    -scheme "$scheme" \
    -destination "$destination" \
    -derivedDataPath "$derived_data_path" \
    CODE_SIGNING_ALLOWED=NO \
    test
else
  if [[ "$require_test_target" == "1" ]]; then
    echo "Error: expected test target '$test_target_name' but none was found." >&2
    exit 1
  fi
  echo "==> Skipping tests: no '$test_target_name' target exists yet."
fi
