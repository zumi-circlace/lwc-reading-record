#!/usr/bin/env bash
# Developer Edition から書誌と読書記録を CSV で書き出す。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/data"
mkdir -p "$OUT"

sf data query \
  --query "SELECT Id, Title__c, ISBN__c, Author__c, Publisher__c, PublishedYear__c, CoverUrl__c, Category__c FROM Book__c" \
  --result-format csv > "$OUT/books.csv"

sf data query \
  --query "SELECT Id, Book__c, Book__r.ISBN__c, ReadDate__c, Description__c FROM ReadingLog__c" \
  --result-format csv > "$OUT/reading_logs.csv"

echo "exported: $OUT/books.csv"
echo "exported: $OUT/reading_logs.csv"
