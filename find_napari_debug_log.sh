#!/usr/bin/env zsh
# find_napari_debug_log.sh - locate and print the napariViewLightsheet debug
# log written by ndi.test.cloud.lightsheet_blob_cloud_roundtrip.
#
# The demo defaults DebugLogFile to fullfile(tempdir, 'NapariLightSheetDebugging.txt')
# which on macOS resolves under $TMPDIR (typically /var/folders/xx/yyy/T/),
# not /tmp. This script looks in the usual spots, picks the newest match,
# and cats it.

set -u
setopt NULL_GLOB EXTENDED_GLOB

name="NapariLightSheetDebugging.txt"

# Places to check, ordered by likelihood on macOS.
locations=(
    "${TMPDIR:-}/$name"                 # matches MATLAB's tempdir
    "/tmp/$name"                        # a user who set DebugLogFile explicitly
    "$HOME/$name"                       # or dropped it in their home
    "/private/tmp/$name"                # macOS's real /tmp target
)

# De-duplicate, drop empties, and keep only paths that actually exist.
typeset -a found
for p in "${locations[@]}"; do
    [[ -n "$p" && -f "$p" ]] && found+=("$p")
done

# Wider net if the shortlist misses: recurse under /var/folders and $TMPDIR
# (macOS parks per-user tempdirs there). Prune common noise; keep the
# recent ones.
if (( ${#found} == 0 )); then
    for root in "${TMPDIR:-}" /var/folders /private/var/folders /tmp; do
        [[ -n "$root" && -d "$root" ]] || continue
        while IFS= read -r hit; do
            [[ -n "$hit" ]] && found+=("$hit")
        done < <(find "$root" -maxdepth 6 -type f -name "$name" 2>/dev/null)
    done
fi

if (( ${#found} == 0 )); then
    print -u2 "No $name found. If your demo ran with a custom DebugLogFile,"
    print -u2 "point me at it:  $0  /full/path/to/logfile"
    print -u2 "Or check the value of tempdir in MATLAB (>> tempdir)."
    exit 1
fi

# Pick the newest match if multiple.
newest="$found[1]"
newest_mtime=$(stat -f %m "$newest" 2>/dev/null || stat -c %Y "$newest" 2>/dev/null)
for f in "$found[@]"; do
    m=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)
    if [[ -n "$m" && "$m" -gt "$newest_mtime" ]]; then
        newest="$f"
        newest_mtime="$m"
    fi
done

print -u2 "=== Reading: $newest ==="
if (( ${#found} > 1 )); then
    print -u2 "(also found: ${(j:, :)found[2,-1]})"
fi
print -u2 ""

cat -- "$newest"
