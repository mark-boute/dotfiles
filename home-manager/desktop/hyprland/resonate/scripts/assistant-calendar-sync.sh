# Mirrors every Proton calendar share link into a local vdir that khal reads.
#
# Proton has no CalDAV/API; each calendar can be shared as a read-only ICS
# link. Put one link per file in ~/.config/resonate/calendars/<name>.url
# (chmod 600, the URL is a secret). The calendar called "personal" is the one
# whose titles and locations the assistant may see; everything else is reduced
# to bare times by assistant-week.
#
# The vdirsyncer config is generated here so adding a calendar is just adding a
# file, and the URLs are read by vdirsyncer straight from those files (never
# written into a config, the Nix store or git).
#
# Runtime inputs: bash coreutils findutils vdirsyncer (see default.nix).
set -euo pipefail

urls="${ASSISTANT_CALENDAR_URLS:-$HOME/.config/resonate/calendars}"
cal_root="${ASSISTANT_CALENDARS:-$HOME/.local/share/resonate/calendars}"
status="${XDG_STATE_HOME:-$HOME/.local/state}/resonate/vdirsyncer"

shopt -s nullglob
files=("$urls"/*.url)
if ((${#files[@]} == 0)); then
  echo "assistant-calendar-sync: no *.url files in $urls" >&2
  exit 1
fi

mkdir -p "$cal_root" "$status"
config=$(mktemp)
trap 'rm -f "$config"' EXIT
printf '[general]\nstatus_path = "%s/"\n' "$status" >"$config"

names=()
for file in "${files[@]}"; do
  name=$(basename "$file" .url)
  if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "assistant-calendar-sync: skipping '$name' (use letters, digits, - and _ only)" >&2
    continue
  fi
  names+=("$name")
  # vdirsyncer would otherwise ask (interactively) to create a missing directory.
  mkdir -p "$cal_root/$name"
  cat >>"$config" <<EOF

[pair $name]
a = "${name}_remote"
b = "${name}_local"
collections = null
conflict_resolution = "a wins"

[storage ${name}_remote]
type = "http"
url.fetch = ["command", "cat", "$file"]

[storage ${name}_local]
type = "filesystem"
path = "$cal_root/$name"
fileext = ".ics"
EOF
done

# vdirsyncer insists on a discover before a pair's first sync (even with
# collections = null); for pairs it already knows this is a no-op.
vdirsyncer --config "$config" discover
vdirsyncer --config "$config" sync

# Drop mirrors of calendars whose link file was removed, so a calendar you
# stopped sharing does not linger in the assistant's view. Only ever touches
# directories under our own mirror root (and that calendar's own status files).
for dir in "$cal_root"/*/; do
  name=$(basename "$dir")
  keep=0
  for n in "${names[@]}"; do [[ "$n" == "$name" ]] && keep=1; done
  if ((!keep)); then
    rm -rf -- "${dir%/}"
    # Its sync state too, or re-adding the calendar later looks to vdirsyncer
    # like someone emptied the local copy and it refuses to sync.
    rm -f -- "$status/$name.collections" "$status/$name.items"
  fi
done
