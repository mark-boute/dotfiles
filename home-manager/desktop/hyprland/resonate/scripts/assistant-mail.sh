# Sends the user a markdown email through Proton Bridge's local SMTP server.
# stdin: "Subject: ..." line, blank line, markdown body (the `email` block the
# assistant produces). Delivered as multipart/alternative (plain + HTML).
#
# Config, all optional, in ~/.config/resonate/assistant/config.env:
#   EMAIL_TO             recipient (required)
#   BRIDGE_USER          Bridge login, usually your Proton address (default EMAIL_TO)
#   EMAIL_FROM           default BRIDGE_USER
#   BRIDGE_PASSWORD_FILE Bridge-generated SMTP password (default $home/bridge-password)
#   BRIDGE_HOST/PORT     default 127.0.0.1 / 1025
# ASSISTANT_MAIL_DRY_RUN=1 prints the message instead of sending it.
#
# Bridge's certificate is self-signed and the connection never leaves
# loopback, so certificate checking is off (only ever against BRIDGE_HOST).
#
# Runtime inputs: bash coreutils msmtp cmark-gfm (see default.nix).
set -euo pipefail

home="${ASSISTANT_HOME:-$HOME/.config/resonate/assistant}"
# shellcheck disable=SC1091
[[ -f "$home/config.env" ]] && source "$home/config.env"

EMAIL_TO="${EMAIL_TO:-}"
BRIDGE_USER="${BRIDGE_USER:-$EMAIL_TO}"
EMAIL_FROM="${EMAIL_FROM:-$BRIDGE_USER}"
BRIDGE_PASSWORD_FILE="${BRIDGE_PASSWORD_FILE:-$home/bridge-password}"
BRIDGE_HOST="${BRIDGE_HOST:-127.0.0.1}"
BRIDGE_PORT="${BRIDGE_PORT:-1025}"

[[ -n "$EMAIL_TO" ]] || { echo "assistant-mail: set EMAIL_TO in $home/config.env" >&2; exit 1; }

input=$(cat)
subject_line=${input%%$'\n'*}
if [[ "$subject_line" != Subject:* ]]; then
  echo "assistant-mail: first line must be 'Subject: ...'" >&2
  exit 1
fi
subject=${subject_line#Subject:}
subject=${subject# }
body=${input#*$'\n'}
body=${body#$'\n'}

b64() { base64 -w 76; }
# RFC 2047 so accents and the euro sign survive in the subject.
encoded_subject="=?UTF-8?B?$(printf '%s' "$subject" | base64 -w 0)?="
html=$(printf '%s\n' "$body" | cmark-gfm --extension table --unsafe)
boundary="resonate-$(date +%s)-$$"

message() {
  printf 'From: %s\r\n' "$EMAIL_FROM"
  printf 'To: %s\r\n' "$EMAIL_TO"
  printf 'Subject: %s\r\n' "$encoded_subject"
  printf 'Date: %s\r\n' "$(date -R)"
  printf 'MIME-Version: 1.0\r\n'
  printf 'Content-Type: multipart/alternative; boundary="%s"\r\n\r\n' "$boundary"
  printf -- '--%s\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n' "$boundary"
  printf '%s\n' "$body" | b64
  printf -- '--%s\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n' "$boundary"
  printf '<html><body style="font-family:sans-serif">%s</body></html>\n' "$html" | b64
  printf -- '--%s--\r\n' "$boundary"
}

if [[ "${ASSISTANT_MAIL_DRY_RUN:-0}" == 1 ]]; then
  message
  exit 0
fi

[[ -r "$BRIDGE_PASSWORD_FILE" ]] || { echo "assistant-mail: cannot read $BRIDGE_PASSWORD_FILE" >&2; exit 1; }

message | msmtp --file=/dev/null \
  --host="$BRIDGE_HOST" --port="$BRIDGE_PORT" \
  --auth=on --user="$BRIDGE_USER" --passwordeval="cat '$BRIDGE_PASSWORD_FILE'" \
  --tls=on --tls-starttls=on --tls-certcheck=off \
  --from="$EMAIL_FROM" -- "$EMAIL_TO"
