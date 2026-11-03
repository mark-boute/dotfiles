#!/usr/bin/env bash
# Update flake inputs, build the system as the user, then switch to it via
# nixos-switch-to@.service (polkit asks for the password). Progress goes to
# stdout as "PHASE <name> [detail]" / "COUNT <done> <total>" lines for
# services/UpdateService.qml; the full log and the last result live in
# $XDG_STATE_HOME/resonate/.

flake="${1:-$HOME/dotfiles}"
host="${2:-$(hostname)}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/resonate"
log="$state/update.log"
result="$state/update.json"
mkdir -p "$state"
: >"$log"

started=$(date +%s)
backup=$(mktemp)
cp "$flake/flake.lock" "$backup"
changed=""

finish() {  # status phase message
  local changed_json
  changed_json=$(printf '%s\n' $changed | sed '/^$/d; s/.*/"&"/' | paste -sd, -)
  printf '{"status":"%s","phase":"%s","message":"%s","changed":[%s],"started":%s,"finished":%s}\n' \
    "$1" "$2" "$3" "$changed_json" "$started" "$(date +%s)" >"$result"
  echo "RESULT $1 $2"
  rm -f "$backup"
  exit 0
}

fail() {  # phase message
  cp "$backup" "$flake/flake.lock"
  finish failed "$1" "$2"
}

echo "PHASE inputs"
if ! nix flake update --flake "$flake" >>"$log" 2>&1; then
  fail inputs "flake update failed"
fi
changed=$(sed -n "s/.*Updated input '\([^']*\)'.*/\1/p" "$log" | sort -u)

echo "PHASE build"
outfile=$(mktemp)
nix build "$flake#nixosConfigurations.$host.config.system.build.toplevel" \
  --no-link --print-out-paths 2>&1 >"$outfile" | {
  total=0 n=0
  while IFS= read -r line; do
    printf '%s\n' "$line" >>"$log"
    case "$line" in
      "this derivation will be built:"*) total=$((total + 1)); echo "COUNT $n $total" ;;
      "these "*" derivations will be built:"*)
        total=$((total + $(grep -o '[0-9]\+' <<<"$line" | head -n1))); echo "COUNT $n $total" ;;
      "building '/nix/store/"*)
        n=$((n + 1))
        echo "COUNT $n $total"
        echo "PHASE build $(sed "s|building '/nix/store/[a-z0-9]*-\(.*\)\.drv'.*|\1|" <<<"$line")" ;;
      "copying path '/nix/store/"*)
        echo "PHASE fetch $(sed "s|copying path '/nix/store/[a-z0-9]*-\([^']*\)'.*|\1|" <<<"$line")" ;;
    esac
  done
}
status=${PIPESTATUS[0]}
out=$(tail -n1 "$outfile")
rm -f "$outfile"
if [ "$status" -ne 0 ] || [ -z "$out" ]; then
  fail build "build failed"
fi

if [ "$(readlink -f /run/current-system)" = "$out" ]; then
  finish uptodate done "already running this system"
fi

echo "PHASE auth"
unit="nixos-switch-to@$(systemd-escape --path "$out").service"
# the polkit prompt happens inside the StartUnit call; systemctl's default
# 25s D-Bus timeout would give up on a password typed later than that
if ! SYSTEMD_BUS_TIMEOUT=300 systemctl start "$unit" >>"$log" 2>&1; then
  journalctl -u "$unit" -n 50 --no-pager >>"$log" 2>&1
  if [ "$(readlink -f /run/current-system)" != "$out" ]; then
    fail switch "switch failed or was cancelled"
  fi
  finish failed switch "activation reported errors"
fi
journalctl -u "$unit" -n 200 --no-pager >>"$log" 2>&1
finish updated done "switched"
