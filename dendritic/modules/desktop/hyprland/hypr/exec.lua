return function(qs_config)

    hl.on("hyprland.start", function()

        hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")

        -- id_ed25519 has no passphrase, so gcr-ssh-agent (the active
        -- SSH_AUTH_SOCK provider) never persists it across logins on its
        -- own; re-add it here every start instead of doing it by hand.
        hl.exec_cmd("ssh-add $HOME/.ssh/id_ed25519")

        -- hyprsunset + hypridle come up as systemd user services (services.*
        -- in default.nix), pulled in by graphical-session.target. Launching
        -- them here too made a second hyprsunset fight the service for CTM
        -- control, crash-looping the service and breaking its IPC socket.
        hl.exec_cmd("systemctl --user start hyprland-session.target")

        if qs_config then
            hl.exec_cmd("qs -c " .. qs_config)
        end

    end)

    hl.on("config.reloaded", function()
        hl.exec_cmd("notify-send -i preferences-system 'Hyprland' 'Config reloaded'")
        -- hl.dsp.focus({ workspace = 1 })
    end)
end


