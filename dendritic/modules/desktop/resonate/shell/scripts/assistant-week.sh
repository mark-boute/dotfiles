# Day-by-day event list for the assistant, with the privacy rule enforced HERE
# (in code, before anything reaches Claude), not left to the prompt:
#
#   - the "personal" calendar shows title, location and a category derived from
#     the event's colour (see assistant/categories.conf);
#   - every other calendar is reduced to bare times: "busy". No title, no
#     location, no calendar name.
#
# Every day is listed even when empty so "no events" is explicit.
#
# usage: assistant-week [START_DATE] [DAYS]   (default: today, 8)
# Env:   ASSISTANT_PERSONAL_CALENDAR (default: personal)
#        ASSISTANT_CATEGORIES  colour -> category file
#        ASSISTANT_CALENDARS   root of the synced calendars
# Runtime inputs: bash coreutils findutils gawk khal (see default.nix).
set -euo pipefail

start="${1:-$(date +%F)}"
days="${2:-8}"
personal="${ASSISTANT_PERSONAL_CALENDAR:-personal}"
categories_file="${ASSISTANT_CATEGORIES:-$HOME/.config/quickshell/resonate/assistant/categories.conf}"
cal_root="${ASSISTANT_CALENDARS:-$HOME/.local/share/resonate/calendars}"
sep=$'\x1f'

# Every synced calendar other than the personal one (khal names them after
# their directory).
others=()
for dir in "$cal_root"/*/; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")
  [[ "$name" == "$personal" ]] || others+=(-a "$name")
done

# uid<TAB>colour for each personal event that carries one. Only colours set
# inside a VEVENT count; calendar-wide colours (X-APPLE-CALENDAR-COLOR and
# friends sit above the VEVENT) would otherwise tag every event the same.
colours=$(mktemp)
trap 'rm -f "$colours"' EXIT
if [[ -d "$cal_root/$personal" ]]; then
  find "$cal_root/$personal" -name '*.ics' -print0 |
    xargs -0 -r gawk '
      BEGINFILE { uid = ""; colour = ""; inev = 0 }
      /^BEGIN:VEVENT/ { inev = 1 }
      /^END:VEVENT/ { inev = 0 }
      inev && /^UID[;:]/ && uid == "" { uid = $0; sub(/^[^:]*:/, "", uid); sub(/\r$/, "", uid) }
      inev && /^(COLOR|X-[A-Z0-9-]*COLOR[A-Z0-9-]*)[;:]/ && colour == "" {
        colour = $0; sub(/^[^:]*:/, "", colour); sub(/\r$/, "", colour)
      }
      ENDFILE { if (uid != "" && colour != "") print uid "\t" colour }
    ' >"$colours"
fi

category_of() {
  local uid="$1" colour key
  colour=$(gawk -F'\t' -v u="$uid" '$1 == u { print $2; exit }' "$colours")
  [[ -z "$colour" ]] && return 0
  key=$(tr '[:upper:]' '[:lower:]' <<<"$colour" | tr -d '[:space:]')
  gawk -F'=' -v k="$key" '
    # A comment is "# " or a bare "#"; "#3366cc = uni" is a hex colour entry.
    /^[[:space:]]*#([[:space:]]|$)/ || NF < 2 { next }
    { a = $1; b = $2; gsub(/[[:space:]]/, "", a); gsub(/^[[:space:]]+|[[:space:]]+$/, "", b) }
    tolower(a) == k { print b; found = 1; exit }
    END { if (!found) print "colour " k }
  ' "$categories_file" 2>/dev/null || printf 'colour %s' "$key"
}

for ((i = 0; i < days; i++)); do
  day=$(date -d "$start + $i days" +%F)
  printf '%s\n' "$(date -d "$day" '+%a %Y-%m-%d')"

  lines=""

  personal_events=$(khal list -a "$personal" --day-format '' \
    --format "{start-time}$sep{end-time}$sep{end-date}$sep{all-day}$sep{title}$sep{location}$sep{uid}" \
    "$day" 1d 2>/dev/null || true)
  while IFS="$sep" read -r st et ed allday title location uid; do
    [[ -z "${title:-}" ]] && continue
    if [[ "$allday" == "True" ]]; then
      when="all day"; sortkey="0"
      [[ "$ed" != "$day" ]] && when="all day (until $ed)"
    else
      when="$st-$et"; sortkey="1 $st"
    fi
    tag=$(category_of "$uid")
    [[ -n "$tag" ]] && tag="[$tag] "
    entry="$when  $tag$title"
    [[ -n "$location" ]] && entry="$entry @ $location"
    lines+="$sortkey"$'\t'"$entry"$'\n'
  done <<<"$personal_events"

  # Named explicitly: with `-d personal` and no other calendar left, khal
  # treats the empty selection as "everything" and would list personal events
  # a second time.
  other_events=""
  if ((${#others[@]})); then
    other_events=$(khal list "${others[@]}" --day-format '' \
      --format "{start-time}$sep{end-time}$sep{end-date}$sep{all-day}" \
      "$day" 1d 2>/dev/null || true)
  fi
  while IFS="$sep" read -r st et ed allday; do
    [[ -z "${allday:-}" ]] && continue
    if [[ "$allday" == "True" ]]; then
      when="all day"; sortkey="0"
      [[ "$ed" != "$day" ]] && when="all day (until $ed)"
    else
      when="$st-$et"; sortkey="1 $st"
    fi
    lines+="$sortkey"$'\t'"$when  busy"$'\n'
  done <<<"$other_events"

  if [[ -z "${lines//[[:space:]]/}" ]]; then
    printf '  (no events)\n'
  else
    printf '%s' "$lines" | sort -t$'\t' -k1,1 | cut -f2- | sed 's/^/  /'
  fi
done
