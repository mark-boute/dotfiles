# Shows what the synced Proton calendars actually contain, so you can see
# whether event colours survive the share-link export and what exact values to
# put in assistant/categories.conf. Prints only property names, counts and
# colour values: never titles, locations or descriptions.
#
# usage: assistant-calendar-check
# Runtime inputs: bash coreutils findutils gawk (see default.nix).
set -euo pipefail

cal_root="${ASSISTANT_CALENDARS:-$HOME/.local/share/resonate/calendars}"

if [[ ! -d "$cal_root" ]] || [[ -z "$(ls -A "$cal_root" 2>/dev/null)" ]]; then
  echo "No synced calendars in $cal_root. Add share links to ~/.config/resonate/calendars/<name>.url and run assistant-calendar-sync." >&2
  exit 1
fi

for dir in "$cal_root"/*/; do
  name=$(basename "$dir")
  count=$(find "$dir" -name '*.ics' | wc -l)
  printf '== %s: %s files\n' "$name" "$count"
  ((count)) || continue

  echo "  event properties present (name: number of events):"
  find "$dir" -name '*.ics' -print0 | xargs -0 gawk '
    /^BEGIN:VEVENT/ { inev = 1; next }
    /^END:VEVENT/ { inev = 0; next }
    inev && /^[A-Z][A-Z0-9-]*[;:]/ { p = $0; sub(/[;:].*/, "", p); seen[FILENAME SUBSEP p] = 1 }
    END { for (k in seen) { split(k, a, SUBSEP); n[a[2]]++ } for (p in n) printf "    %s: %d\n", p, n[p] }
  ' | sort

  echo "  colour values (value: number of events):"
  find "$dir" -name '*.ics' -print0 | xargs -0 gawk '
    /^BEGIN:VEVENT/ { inev = 1; next }
    /^END:VEVENT/ { inev = 0; next }
    inev && /^(COLOR|X-[A-Z0-9-]*COLOR[A-Z0-9-]*)[;:]/ {
      n = $0; sub(/[;:].*/, "", n); v = $0; sub(/^[^:]*:/, "", v); sub(/\r$/, "", v)
      c[n ": " v]++
    }
    END { for (k in c) printf "    %s  (%d)\n", k, c[k] }
  ' | sort | { grep . || echo "    (none: this calendar's events carry no colour)"; }
done
