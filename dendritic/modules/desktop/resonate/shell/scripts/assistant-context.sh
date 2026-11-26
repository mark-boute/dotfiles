# Context bundle prepended to a conversation: current time, the user's
# profile, their calendar and (on request) the supermarket offers.
#
# usage: assistant-context [--offers] [--start DATE] [--days N]
# Runtime inputs: bash coreutils assistant-week (see default.nix).
set -euo pipefail

home="${ASSISTANT_HOME:-$HOME/.config/resonate/assistant}"
state="${ASSISTANT_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/resonate/assistant}"

with_offers=0
start=$(date +%F)
days=8
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offers) with_offers=1 ;;
    --start) start=$(date -d "$2" +%F); shift ;;
    --days) days="$2"; shift ;;
    *) echo "assistant-context: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

printf '# Context\n\nNow: %s\n\n' "$(date '+%A %Y-%m-%d %H:%M %Z')"

printf '## Profile\n\n'
if [[ -f "$home/profile.md" ]]; then
  # HTML comments in the template hold instructions for the user, not data.
  sed '/<!--/,/-->/d' "$home/profile.md"
else
  printf '(no profile.md yet: ask the user for diet, budget and household size before planning groceries)\n'
fi

printf '\n## Calendar from %s, %s days\n\n' "$start" "$days"
assistant-week "$start" "$days"

if ((with_offers)); then
  printf '\n## Supermarket offers (one JSON object per line)\n\n'
  if [[ -s "$state/offers.jsonl" ]]; then
    printf 'Fetched: %s. Fields: store, name, price (offer price), was (regular price), size, unit_price (per unit), type, multi_buy, from/until (validity), category, diet, house_brand.\n\n' \
      "$(date -r "$state/offers.jsonl" '+%Y-%m-%d %H:%M')"
    cat "$state/offers.jsonl"
  else
    printf '(offers have not been fetched yet)\n'
  fi
fi
