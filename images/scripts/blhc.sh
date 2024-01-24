#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Copyright salsa-ci-team and others
# SPDX-License-Identifier: FSFAP
# Copying and distribution of this file, with or without modification, are
# permitted in any medium without royalty provided the copyright notice and
# this notice are preserved. This file is offered as-is, without any warranty.

# shellcheck disable=SC1091
source /usr/local/bin/lib.sh

set -eu -o pipefail

# Relative path calculcating must be done before chdir().
INPUT_OUTPUT_PATH="$(realpath -m "${INPUT_OUTPUT_PATH:-${INPUT_SOURCE_PATH}}")"

cd "${INPUT_SOURCE_PATH}" || exit 1
create_user_for .

echo "::group::Fixup INPUT_* variables"
# Fixup INPUT_OUTPUT_PATH
SUDO mkdir -vp "${INPUT_OUTPUT_PATH}"
# Fixup INPUT_ARGS
INPUT_ARGS="${INPUT_ARGS:-}"

while IFS='=' read -r -d '' name value; do
  case "${name}" in
  INPUT_*) echo "${name}=${value}";;
  esac
done < <(env -0)
echo "::endgroup::"

# Do not use glob directly here.
# See: https://unix.stackexchange.com/questions/528361/dash-not-expanding-glob-wildcards-in-chroot
build="$(find . -maxdepth 1 -name \*.build)"

echo "::group::blhc arguments"
IFS=" " read -r -a args <<< "${INPUT_ARGS}"
args=(--debian --line-numbers --color ${args[@]+"${args[@]}"})
echo "::endgroup::"

echo "::group::Generate report"
SUDO blhc "${args[@]}" "${build}" || [ $? -eq 1 ]
echo "::endgroup::"

echo "::group::Outputs"
{ \
  echo "output_path=$(realpath --relative-to="${GITHUB_WORKSPACE}" "${INPUT_OUTPUT_PATH}")"; \
} | tee -a "${GITHUB_OUTPUT}"
echo "::endgroup::"
