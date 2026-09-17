#!/usr/bin/env bash
# デモ用の親子 JSON を投入する。本番バックアップの再投入は README を参照。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

sf data import tree --files "$ROOT/data/sample/books-with-logs.json"
echo "imported sample tree: data/sample/books-with-logs.json"
