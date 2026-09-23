# Runs Claude headless as the assistant: no tools, our own system prompt, a
# dedicated working directory (so the dotfiles repo's CLAUDE.md is never
# loaded and sessions stay in one place), prompt on stdin.
#
# usage: assistant-claude [--stream] [--resume SESSION_ID] < prompt
#   default:  one JSON object at the end (.result, .session_id, .is_error)
#   --stream: stream-json events for a live UI
# Runtime inputs: bash coreutils claude-code (see default.nix).
set -euo pipefail

home="${ASSISTANT_HOME:-$HOME/.config/resonate/assistant}"
system_prompt="${ASSISTANT_SYSTEM_PROMPT:-$HOME/.config/quickshell/resonate/assistant/system-prompt.md}"
model="${ASSISTANT_MODEL:-sonnet}"

stream=0
resume=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stream) stream=1 ;;
    --resume) resume="$2"; shift ;;
    *) echo "assistant-claude: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

[[ -r "$system_prompt" ]] || { echo "assistant-claude: cannot read $system_prompt" >&2; exit 1; }
mkdir -p "$home"
cd "$home"

args=(-p --tools "" --system-prompt "$(<"$system_prompt")" --model "$model")
if ((stream)); then
  args+=(--output-format stream-json --include-partial-messages --verbose)
else
  args+=(--output-format json)
fi
[[ -n "$resume" ]] && args+=(--resume "$resume")

exec claude "${args[@]}"
