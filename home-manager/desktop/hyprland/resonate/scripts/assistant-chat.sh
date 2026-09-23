# One chat turn for the Resonate assistant page (services/AssistantService.qml).
# Streams Claude's stream-json events on stdout.
#
# usage: assistant-chat [--session ID] [--offers] MESSAGE
#   no --session: new conversation, so MESSAGE is preceded by the context
#                 bundle (profile, calendar, and offers with --offers)
#   --session:    resumes it; MESSAGE only gets the current time. With
#                 --offers the fresh bundle (including offers) is sent again.
#
# The message is an argument, not stdin, so the caller never needs a pipe.
# Runtime inputs: bash coreutils assistant-context assistant-claude (see default.nix).
set -euo pipefail

session=""
context_args=()
while [[ $# -gt 1 ]]; do
  case "$1" in
    --session) session="$2"; shift ;;
    --offers) context_args+=(--offers) ;;
    *) echo "assistant-chat: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
message="${1:?assistant-chat: missing message}"

if [[ -z "$session" ]]; then
  {
    assistant-context "${context_args[@]}"
    printf '\n# Request\n\n%s\n' "$message"
  } | assistant-claude --stream
elif ((${#context_args[@]})); then
  {
    assistant-context "${context_args[@]}"
    printf '\n# Request\n\n%s\n' "$message"
  } | assistant-claude --stream --resume "$session"
else
  printf 'Now: %s\n\n%s\n' "$(date '+%A %Y-%m-%d %H:%M %Z')" "$message" |
    assistant-claude --stream --resume "$session"
fi
