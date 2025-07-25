# Copyright salsa-ci-team and others
# SPDX-License-Identifier: FSFAP
# Copying and distribution of this file, with or without modification, are
# permitted in any medium without royalty provided the copyright notice and
# this notice are preserved. This file is offered as-is, without any warranty.

#checkov:skip=CKV_DOCKER_2:Don't need HEALTHCHECK in these images
#checkov:skip=CKV_DOCKER_3:Running as root so far

ARG BASE_IMAGE=debian

################################################################################

FROM bash:5.3 AS dummy

################################################################################

#checkov:skip=CKV_DOCKER_7:It's a build argument
FROM ${BASE_IMAGE} AS base

ARG VENDOR
ARG RELEASE

ENV DEBIAN_FRONTEND noninteractive

RUN set -eux; \
	echo "Acquire::Retries 5;" > /etc/apt/apt.conf.d/hustle-ci; \
	apt-get update --quiet; \
	apt-get upgrade -y; \
	apt-get install --no-install-recommends -y \
		apt \
		ca-certificates \
		eatmydata \
		$(which realpath >/dev/null 2>&1 || echo realpath) \
		sudo \
	; \
	apt-get autoremove --purge -y; \
	apt-get clean; \
	rm -rf /var/lib/apt

COPY scripts/lib.sh /usr/local/bin/lib.sh
COPY scripts/gbp.sh /usr/local/bin/gbp.sh

################################################################################

FROM base AS gbp

# Add deb-src entries
RUN set -eux; \
	if [ -f /etc/apt/sources.list ]; then \
		sed -n '/^deb\s/s//deb-src /p' /etc/apt/sources.list > /etc/apt/sources.list.d/deb-src.list; \
	fi; \
	if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
		sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources; \
	fi; \
	:

RUN set -eux; \
	apt-get update --quiet; \
	apt-get upgrade -y; \
	eatmydata apt-get install --no-install-recommends -y \
		curl \
		git-buildpackage \
		pristine-tar \
		unzip \
	; \
	rm -rf /var/lib/apt

COPY scripts/extract-source.sh /usr/local/bin/extract-source.sh

################################################################################

FROM base AS generic-tests

# install dependencies for check rc bugs
RUN set -eux; \
	apt-get update --quiet; \
	if [ -n "$(apt-cache search --names-only ^python3-junit\\.xml\$)" ]; then \
		eatmydata apt-get install --no-install-recommends -y \
			python3-debianbts \
			python3-junit.xml \
		; \
	fi; \
	:

# install dependencies for check for missing replaces
RUN set -eux; \
	eatmydata apt-get install -y apt-file python3-debian; \
	if [ -z "$(apt-cache search --names-only ^python3-junit\\.xml\$)" ]; then \
		eatmydata apt-get install --no-install-recommends -y \
			python3-pip \
		; \
		pip3 install junit-xml; \
	else \
		eatmydata apt-get install --no-install-recommends -y \
			python3-junit.xml \
		; \
	fi; \
	:

COPY scripts/check_rc_bugs.py /usr/local/bin/check_rc_bugs.py
COPY scripts/rc-bugs.sh /usr/local/bin/rc-bugs.sh
COPY scripts/check_for_missing_breaks_replaces.py /usr/local/bin/check_for_missing_breaks_replaces.py
COPY scripts/missing-breaks.sh /usr/local/bin/missing-breaks.sh

################################################################################

FROM base AS lintian

RUN set -eux; \
	printf 'Package: *\nPin: release a=%s\nPin-Priority: 900\n' "$RELEASE" \
		| tee /etc/apt/preferences.d/salsa-ci; \
	apt-get update --quiet; \
	apt-get upgrade -y; \
	eatmydata apt-get install --no-install-recommends -y \
		git \
		lintian \
		xz-utils \
	; \
	if [ -z "$(apt-cache search --names-only ^python3-junit\\.xml\$)" ]; then \
		eatmydata apt-get install --no-install-recommends -y \
			python3-pip \
		; \
		pip3 install junit-xml; \
	else \
		eatmydata apt-get install --no-install-recommends -y \
			python3-junit.xml \
		; \
	fi; \
	rm -rf /var/lib/apt; \
	:

COPY scripts/lintian2junit.py /usr/local/bin/lintian2junit.py
COPY scripts/lintian.sh /usr/local/bin/lintian.sh

################################################################################

FROM base AS blhc

RUN set -eux; \
	apt-get update --quiet; \
	apt-get upgrade -y; \
	eatmydata apt-get install --no-install-recommends -y \
		blhc \
	; \
	rm -rf /var/lib/apt; \
	:

COPY scripts/blhc.sh /usr/local/bin/blhc.sh

################################################################################

FROM base AS autopkgtest

RUN set -eux; \
	apt-get update --quiet; \
	apt-get upgrade -y; \
	eatmydata apt-get install --no-install-recommends -y \
		autodep8 \
		autopkgtest \
		docker.io \
	; \
	rm -rf /var/lib/apt; \
	:

COPY scripts/autopkgtest.sh /usr/local/bin/autopkgtest.sh
