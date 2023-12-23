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

platform=
case "${INPUT_BUILD_ARCH:-}" in
amd64)    platform=linux/amd64;;
i386)     platform=linux/386;;
arm64)    platform=linux/arm64/v8;;
armhf)    platform=linux/arm/v7;;
armel)    platform=linux/arm/v5;;
mips64el) platform=linux/mips64le;;
riscv64)  platform=linux/riscv64;;
ppc64el)  platform=linux/ppc64le;;
s390x)    platform=linux/s390x;;
esac
[ -n "${platform}" ] && args+=(--platform="${platform}")

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
    "ghcr.io/hustle-ci/${IMAGE}:${INPUT_RELEASE:-latest}"
