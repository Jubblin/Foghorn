#!/usr/bin/env bash
# Resolve release architecture labels for DMG builds.
# Usage: source this file, then: resolve_release_arch [arm64|amd64]
# Sets ARCH_LABEL (arm64|amd64) and XCODE_ARCH (arm64|x86_64) for the caller.
# shellcheck shell=bash

resolve_release_arch() {
  local input="${1:-}"
  case "$input" in
    arm64|aarch64)
      ARCH_LABEL="arm64"
      XCODE_ARCH="arm64"
      ;;
    amd64|x86_64|x64)
      ARCH_LABEL="amd64"
      XCODE_ARCH="x86_64"
      ;;
    "")
      case "$(uname -m)" in
        arm64|aarch64)
          ARCH_LABEL="arm64"
          XCODE_ARCH="arm64"
          ;;
        x86_64)
          ARCH_LABEL="amd64"
          XCODE_ARCH="x86_64"
          ;;
        *)
          echo "error: unsupported host architecture: $(uname -m)" >&2
          return 1
          ;;
      esac
      ;;
    *)
      echo "error: unsupported architecture '$input' (use arm64 or amd64)" >&2
      return 1
      ;;
  esac
  # Assigned for scripts that source this helper.
  : "${ARCH_LABEL:?}" "${XCODE_ARCH:?}"
}
