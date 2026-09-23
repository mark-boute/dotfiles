{ config, lib, pkgs, ... }:

let
  cfg = config.modules.hyprland.resonate;
  home = config.home.homeDirectory;

  # Real, shellcheck-linted files under ./scripts, wrapped so each one carries
  # its own PATH (no reliance on what the systemd user manager or the Quickshell
  # process happens to have). See services/AssistantService.qml.
  script = name: runtimeInputs: pkgs.writeShellApplication {
    inherit name runtimeInputs;
    # SC2016: the awk/jq programs sit in single quotes on purpose.
    excludeShellChecks = [ "SC2016" ];
    text = builtins.readFile (./scripts + "/${name}.sh");
  };

  assistantOffers = script "assistant-offers" (with pkgs; [ coreutils curl jq ]);
  assistantWeek = script "assistant-week" (with pkgs; [ coreutils findutils gawk gnused khal ]);
  assistantCalendarSync = script "assistant-calendar-sync" (with pkgs; [ coreutils findutils vdirsyncer ]);
  assistantCalendarCheck = script "assistant-calendar-check" (with pkgs; [ coreutils findutils gawk ]);
  assistantContext = script "assistant-context" (with pkgs; [ coreutils gnused ] ++ [ assistantWeek ]);
  assistantClaude = script "assistant-claude" (with pkgs; [ coreutils claude-code ]);
  assistantMail = script "assistant-mail" (with pkgs; [ coreutils msmtp cmark-gfm ]);
  assistantChat = script "assistant-chat" (with pkgs; [ coreutils ] ++ [ assistantContext assistantClaude ]);
  assistantWeekly = script "assistant-weekly" (with pkgs; [
    coreutils findutils gawk gnused jq libnotify
  ] ++ [ assistantOffers assistantContext assistantClaude assistantMail ]);

  calendarUrlDir = "${home}/.config/resonate/calendars";
  calendarRoot = "${home}/.local/share/resonate/calendars";
  profileFile = "${home}/.config/resonate/assistant/profile.md";
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      assistantOffers
      assistantWeek
      assistantCalendarSync
      assistantCalendarCheck
      assistantContext
      assistantClaude
      assistantMail
      assistantChat
      assistantWeekly
      pkgs.claude-code
      pkgs.khal
      pkgs.vdirsyncer
    ];

    # Proton Calendar has no CalDAV/API. Each calendar's "share via link" gives
    # a read-only ICS URL (secret, up to ~4h stale). One file per calendar in
    # ${calendarUrlDir}/<name>.url; assistant-calendar-sync mirrors them into
    # ${calendarRoot}/<name>/ and khal discovers every subdirectory as a
    # calendar named after it. The URLs stay in hand-managed 0600 files so they
    # never land in the world-readable Nix store or in git. The calendar named
    # "personal" is the only one whose titles/locations reach the assistant
    # (see scripts/assistant-week.sh).
    xdg.configFile."khal/config".text = ''
      [calendars]
      [[all]]
      path = ${calendarRoot}/*
      type = discover

      [locale]
      timeformat = %H:%M
      dateformat = %Y-%m-%d
      longdateformat = %Y-%m-%d
      datetimeformat = %Y-%m-%d %H:%M
      longdatetimeformat = %Y-%m-%d %H:%M
      firstweekday = 0
    '';

    systemd.user.services.assistant-calendar-sync = {
      Unit = {
        Description = "Sync the Proton calendar share links for the assistant";
        ConditionDirectoryNotEmpty = calendarUrlDir;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${assistantCalendarSync}/bin/assistant-calendar-sync";
      };
    };
    systemd.user.timers.assistant-calendar-sync = {
      Unit.Description = "Sync the Proton calendars every 15 minutes";
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "15min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Local SMTP endpoint (127.0.0.1:1025) for assistant-mail. One-time setup:
    # stop the service, run `protonmail-bridge --cli`, `login`, then `info` for
    # the Bridge SMTP password (put it in ~/.config/resonate/assistant/
    # bridge-password, chmod 600), and start the service again. Bridge stores
    # its session in the secret service (gnome-keyring is already enabled).
    services.protonmail-bridge.enable = true;

    systemd.user.services.assistant-weekly = {
      Unit = {
        Description = "Weekly grocery plan (assistant)";
        # Skipped silently until a profile exists.
        ConditionPathExists = profileFile;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${assistantWeekly}/bin/assistant-weekly";
        TimeoutStartSec = "15min";
      };
    };
    systemd.user.timers.assistant-weekly = {
      Unit.Description = "Weekly grocery plan, Sunday evening";
      Timer = {
        OnCalendar = "Sun 18:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
