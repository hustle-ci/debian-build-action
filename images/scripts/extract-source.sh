#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Copyright salsa-ci-team and others
# SPDX-License-Identifier: FSFAP
# Copying and distribution of this file, with or without modification, are
# permitted in any medium without royalty provided the copyright notice and
# this notice are preserved. This file is offered as-is, without any warranty.

source /usr/local/bin/lib.sh

set -eux

apt-get update && eatmydata apt-get upgrade -y

cd "${WORKING_DIR}" || exit 1
create_user_for .

SUDO gbp pull --ignore-branch --pristine-tar --track-missing

# gbp setup-gitattributes needs to be called after gbp pull to avoid having
# staging commits (See #322)
if echo "${INPUT_SETUP_GITATTRIBUTES}" | grep -qvE '^(1|yes|true)$'; then
  test -r .gitattributes && SUDO gbp setup-gitattributes
fi

SUDO mkdir -vp "${OUTPUT_DIR}"

read -r -a BUILD_ARGS <<< "${INPUT_SOURCE_ARGS}"
if find . -maxdepth 3 -wholename "*/debian/source/format" -exec cat {} \; | \
    grep -q '3.0 (gitarchive)'; then
  eatmydata apt-get install --no-install-recommends -y \
    dpkg-source-gitarchive

  SUDO dpkg-source --build . | tee /tmp/build.out
  DSC="$(sed -n 's/.* \(\S*.dsc$\)/\1/p' /tmp/build.out)"
  SUDO dpkg-source --extract --no-check "../$DSC" "${OUTPUT_DIR}/${DSC%.dsc}"
else
  # Check if we can obtain the orig from the git branches

  if ! SUDO gbp export-orig --tarball-dir="${OUTPUT_DIR}"; then
    # Fallback using origtargz
    SUDO origtargz -dt
    SUDO cp -v ../*orig*tar* "${OUTPUT_DIR}"
    BUILD_ARGS=(--git-overlay "${BUILD_ARGS[@]}")
  fi

  # As of 2020-09-09, gbp doesn't have a simpler method to extract the
  # debianized source package. Use --git-pbuilder=`/bin/true` for the moment:
  # https://bugs.debian.org/969952

  SUDO gbp buildpackage \
    --git-ignore-branch \
    --git-ignore-new \
    --git-no-create-orig \
    --git-export-dir="${OUTPUT_DIR}" \
    --no-check-builddeps \
    --git-builder=/bin/true \
    --git-no-pbuilder \
    --git-no-hooks \
    --git-no-purge \
    "${BUILD_ARGS[@]}"
fi

ls -lh "${OUTPUT_DIR}"

cd "${OUTPUT_DIR}" || exit 1
DEBIANIZED_SOURCE=$(find . -maxdepth 3 -wholename "*/debian/changelog" | sed -e 's%/\w*/\w*$%%')
if [ ! "${DEBIANIZED_SOURCE}" ] ; then
  echo "Error: No valid debianized source tree found."
  exit 1
fi

SUDO mv -v "${DEBIANIZED_SOURCE}" "${BUILT_SOURCE_DIR}"

# Print size of artifacts
du -sh

echo "output-path=${INPUT_OUTPUT_PATH}" >> "${GITHUB_OUTPUT}"
