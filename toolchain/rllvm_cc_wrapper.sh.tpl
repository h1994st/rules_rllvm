#!/bin/bash

if [[ -f %{rllvm_dist_path_prefix}rllvm-cc ]]; then
  execroot_path=""
elif [[ ${BASH_SOURCE[0]} == "/"* ]]; then
  # Some consumers of `CcToolchainConfigInfo` (e.g. `cmake` from rules_foreign_cc)
  # change CWD and call $CC (this script) with its absolute path.
  # For cases like this, we'll try to find `clang` through an absolute path.
  # This script is at _execroot_/external/_repo_name_/bin/cc_wrapper.sh
  execroot_path="${BASH_SOURCE[0]%/*/*/*/*}/"
else
  echo >&2 "ERROR: could not find rllvm-cc; PWD=\"${PWD}\"; PATH=\"${PATH}\"."
  exit 5
fi

RLLVM_CONFIG=${execroot_path}%{llvm_dist_path_prefix}bin/rllvm_config.yml exec ${execroot_path}%{rllvm_dist_path_prefix}rllvm-cc "$@"
