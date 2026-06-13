#!/usr/bin/env bash
# import_gl_cache.sh — copy GL cache .json.zip fixtures from a source
# project's data/gl_cache into this repo's precision-first,
# npts-thousand-bucketed layout.
#
#   SRC=/path/to/project/data/gl_cache bash import_gl_cache.sh
#
# Idempotent: re-importing the same file overwrites in place (identical
# content for a given (npts,prec), so this is a no-op dedup).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST_ROOT="$REPO_ROOT/gl_cache"
SRC="${SRC:?set SRC to the source data/gl_cache dir}"

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: SRC=$SRC not found" >&2
  exit 1
fi

copied=0
skipped=0
for f in "$SRC"/*.json.zip; do
  [[ -e "$f" ]] || continue
  base="$(basename "$f")"                       # prec{P}_npts{N}.json.zip
  # Parse P and N from the canonical filename.
  if [[ "$base" =~ ^prec([0-9]+)_npts([0-9]+)\.json\.zip$ ]]; then
    P="${BASH_REMATCH[1]}"
    N="${BASH_REMATCH[2]}"
  else
    echo "  SKIP (unrecognized name): $base" >&2
    skipped=$((skipped+1))
    continue
  fi
  bucket=$(( (N / 1000) * 1000 ))
  dir="$DEST_ROOT/prec${P}/npts${bucket}-$((bucket+999))"
  mkdir -p "$dir"
  cp -n "$f" "$dir/$base" 2>/dev/null && copied=$((copied+1)) || {
    # cp -n returns nonzero if it skipped an existing file; treat as dedup.
    if [[ -e "$dir/$base" ]]; then skipped=$((skipped+1)); else
      cp "$f" "$dir/$base"; copied=$((copied+1)); fi
  }
done

echo "imported: $copied new, $skipped skipped (already present / unrecognized)"
echo "dest tree summary:"
find "$DEST_ROOT" -maxdepth 2 -type d | sort | sed "s|$DEST_ROOT|gl_cache|"
