return function(qs_config)

    hl.on("hyprland.start", function()

        hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
        -- hyprsunset + hypridle come up as systemd user services (services.*
        -- in default.nix), pulled in by graphical-session.target. Launching
        -- them here too made a second hyprsunset fight the service for CTM
        -- control, crash-looping the service and breaking its IPC socket.
        hl.exec_cmd("systemctl --user start hyprland-session.target")

        if qs_config then
            hl.exec_cmd("qs -c " .. qs_config)
        end

        -- Proton VPN: starts minimised to tray and auto-connects to NL
        -- (both set in ~/.config/Proton/VPN/app-config.json). --start-minimized
        -- is passed too so it never flashes a window on a config reset.
        hl.exec_cmd("systemd-run --user --scope --slice=app.slice protonvpn-app --start-minimized")

    end)

    hl.on("config.reloaded", function()
        hl.exec_cmd("notify-send -i preferences-system 'Hyprland' 'Config reloaded'")
        -- hl.dsp.focus({ workspace = 1 })
    end)
end


