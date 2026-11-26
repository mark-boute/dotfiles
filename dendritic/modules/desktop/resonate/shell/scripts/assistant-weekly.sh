# Weekly grocery run: fetch offers, ask Claude to plan the coming week around
# the evenings the calendar says are spent at home, then either email the plan
# or (when an evening is ambiguous) park the questions for the chat page.
#
# The chat page (SUPER+A) picks up $state/pending.json, resumes the same
# Claude session, and the user's answers lead to the final plan.
#
# Runtime inputs: bash coreutils gawk jq libnotify assistant-* (see default.nix).
set -euo pipefail

home="${ASSISTANT_HOME:-$HOME/.config/resonate/assistant}"
state="${ASSISTANT_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/resonate/assistant}"
mkdir -p "$state"

notify() { notify-send -a Assistant -i emblem-shared "$1" "${2:-}" || true; }
fail() { notify "Weekly grocery plan failed" "$1"; echo "assistant-weekly: $1" >&2; exit 1; }

[[ -f "$home/profile.md" ]] || fail "No profile at $home/profile.md (see profile.example.md)"

if assistant-offers >"$state/offers.jsonl.new"; then
  mv "$state/offers.jsonl.new" "$state/offers.jsonl"
else
  rm -f "$state/offers.jsonl.new"
  # Yesterday's offers are still useful; three-day-old ones are not.
  if [[ -z "$(find "$state/offers.jsonl" -mtime -3 2>/dev/null)" ]]; then
    fail "Could not fetch supermarket offers"
  fi
fi

start=$(date -d tomorrow +%F)
prompt=$(
  cat <<EOF
This is the weekly grocery planning run. Plan the groceries for the seven days
starting $start. Follow the grocery rules in your instructions: decide which
evenings are at home from the calendar, ask me (questions only) if any evening
is genuinely unclear, otherwise reply with the final email block.

$(assistant-context --offers --start "$start" --days 7)
EOF
)

response=$(printf '%s' "$prompt" | assistant-claude) || fail "Claude call failed"
[[ "$(jq -r '.is_error' <<<"$response")" == false ]] || fail "$(jq -r '.result' <<<"$response" | head -c 200)"

reply=$(jq -r '.result' <<<"$response")
session=$(jq -r '.session_id' <<<"$response")

email=$(awk '/^```email[[:space:]]*$/ {f=1; next} /^```[[:space:]]*$/ {if (f) exit} f' <<<"$reply")

if [[ -n "$email" ]]; then
  printf '%s\n' "$email" | assistant-mail || fail "Could not send the email (is Proton Bridge running and logged in?)"
  printf '%s\n' "$email" >"$state/last-plan.md"
  rm -f "$state/pending.json"
  notify "Grocery plan sent" "$(head -n1 <<<"$email" | sed 's/^Subject: //')"
else
  jq -n --arg session "$session" --arg text "$reply" --arg created "$(date -Is)" \
    '{session_id: $session, created: $created, text: $text}' >"$state/pending.json"
  notify "Assistant has questions about your week" "Press SUPER+A to answer"
fi
