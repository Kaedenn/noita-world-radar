#!/bin/bash

SELF="$(dirname "$0")"
BASE="$(readlink -f "$SELF/..")"

if [[ -z "${DATA_PATH:-}" ]]; then
  DATA_PATH="${1:-"$(readlink -f "$BASE/../../ref/data")"}"
fi
if [[ ! -d "$DATA_PATH" ]]; then
  echo "error: DATA_PATH '$DATA_PATH' not a directory" >&2
  exit 1
fi

$SELF/build_items.lua "$DATA_PATH" -o $BASE/files/generated/item_list.lua
$SELF/build_entities.lua "$DATA_PATH" -o $BASE/files/generated/entity_list.lua
