# Copyright 2016 The Bazel Go Rules Authors. All rights reserved.
# Copyright 2016 The Closure Rules Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
load("@rules_shell//shell:sh_test.bzl", "sh_test")

"""Tests that two files contain the same data."""

def files_equal_test(name, golden, actual, error_message = None, **kwargs):
    # This genrule creates a Bash script: the source of the actual test.
    # The script:
    #   1. Initializes the Bash runfiles library (see
    #      @bazel_tools//tools/bash/runfiles/runfiles.bash).
    #   2. Stores command line arguments into variables.
    #   3. Computes runfile paths for the GOLDEN and ACTUAL files.
    #   4. Calls "rlocation" from runfiles.bash to locates the runfiles.
    #   5. Computes and compares checksums.
    native.genrule(
        name = name + "_src",
        outs = [name + "-src.sh"],
        executable = True,
        visibility = ["//visibility:private"],
        cmd = r"""cat >$@ <<'eof'
#!/usr/bin/env bash
# sh_test() source, generated by @io_bazel_rules_go//go/private/tools/files_equal_test.bzl

### 1. initialize the Bash runfiles library

# --- begin runfiles.bash initialization ---
# Copy-pasted from Bazel's Bash runfiles library (tools/bash/runfiles/runfiles.bash).
set -euo pipefail
if [[ ! -d "$${RUNFILES_DIR:-/dev/null}" && ! -f "$${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  if [[ -f "$$0.runfiles_manifest" ]]; then
    export RUNFILES_MANIFEST_FILE="$$0.runfiles_manifest"
  elif [[ -f "$$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$$0.runfiles/MANIFEST"
  elif [[ -f "$$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
    export RUNFILES_DIR="$$0.runfiles"
  fi
fi
if [[ -f "$${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "$${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "$${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  source "$$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \
            "$$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

### 2. Store command line arguments into variables.

declare -r GOLDEN="$${1}"
declare -r ACTUAL="$${2}"
declare -r ERROR_MSG="$${3:-FILES DO NOT HAVE EQUAL CONTENTS}"

### 3. Compute runfile paths.

# Strip "external/" prefix OR prepend workspace name and strip "./" prefix.
[[ "$$GOLDEN" =~ external/* ]] && F1="$${GOLDEN#external/}" || F1="$$TEST_WORKSPACE/$${GOLDEN#./}"
[[ "$$ACTUAL" =~ external/* ]] && F2="$${ACTUAL#external/}" || F2="$$TEST_WORKSPACE/$${ACTUAL#./}"

### 4. Locate the runfiles.

F1="$$(rlocation "$$F1")"
F2="$$(rlocation "$$F2")"

if [[ "$$F1" == "$$F2" ]]; then
  echo >&2 "GOLDEN and ACTUAL should be different files"
  exit 1
fi

### 5. Compute and compare checksums.

function checksum() {
  if command -v openssl >/dev/null; then
    openssl sha1 $$1 | cut -f 2 -d ' '
  elif command -v sha256sum >/dev/null; then
    sha256sum $$1 | cut -f 1 -d ' '
  elif command -v shasum >/dev/null; then
    cat $$1 | shasum -a 256 | cut -f 1 -d ' '
  else
    echo please install openssl >&2
    exit 1
  fi
}
SUM1=$$(checksum "$$F1")
SUM2=$$(checksum "$$F2")
if [[ $${SUM1} != $${SUM2} ]]; then
  echo "ERROR: $$ERROR_MSG" >&2
  echo "$$GOLDEN $${SUM1}" >&2
  echo "$$ACTUAL $${SUM2}" >&2
  exit 1
fi
eof""",
    )

    sh_test(
        name = name,
        srcs = [name + "-src.sh"],
        data = [
            "@bazel_tools//tools/bash/runfiles",
            actual,
            golden,
        ],
        args = [
            "$(location %s)" % golden,
            "$(location %s)" % actual,
            error_message,
        ],
        **kwargs
    )
