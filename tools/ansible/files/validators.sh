#!/usr/bin/env bash
set -euo pipefail
kustomize build "$1" | kubeval --strict - && kubelinter lint - || true
