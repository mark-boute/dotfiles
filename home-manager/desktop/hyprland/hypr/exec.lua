return function(qs_config)

    hl.on("hyprland.start", function()

        hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
        hl.exec_cmd("systemctl --user start hyprland-session.target")
        hl.exec_cmd("hyprsunset")
        hl.exec_cmd("hypridle")
        
        if qs_config then
            hl.exec_cmd("qs -c " .. qs_config)
        end

    end)

    hl.on("config.reloaded", function()
        hl.exec_cmd("notify-send -i preferences-system 'Hyprland' 'Config reloaded'")
        -- hl.dsp.focus({ workspace = 1 })
    end)
end


