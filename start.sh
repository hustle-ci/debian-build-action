#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Copyright You-Sheng Yang and others
# SPDX-License-Identifier: FSFAP
# Copying and distribution of this file, with or without modification, are
# permitted in any medium without royalty provided the copyright notice and
# this notice are preserved. This file is offered as-is, without any warranty.

set -eu

[ $# -ge 2 ] || { echo "Insufficient argument." >&2; exit 1; }

TASK="$1"
IMAGE="$2"
args=(--entrypoint="/usr/local/bin/${TASK}.sh")

while IFS='=' read -r -d '' name value; do
  case "${name}" in
  ACTIONS_*|CI|DEB_*|GITHUB_*|INPUT_*) args+=("--env" "${name}=${value}");;
  esac
done < <(env -0)

while read -r bind; do
  [ -n "${bind}" ] && args+=("--volume" "${bind}")
done < <(docker inspect "${HOSTNAME}" --format='{{ range .HostConfig.Binds }}{{printf "%s\n" .}}{{end}}')

echo "::group::docker run arguments"
echo "${args[@]}"
echo "::endgroup::"
exec docker run "${args[@]}" \
    "ghcr.io/hustle-ci/${IMAGE}:${INPUT_RELEASE}"
