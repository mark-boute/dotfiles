-- Startup commands. Per-host additions live in device.lua via additional
-- hl.on("hyprland.start", …) calls.

return function(qs_config)

    hl.on("hyprland.start", function()
        hl.dsp.focus({ workspace = 1 })
        hl.exec_cmd("hyprlauncher -d")
        
        if qs_config then
            hl.exec_cmd("qs -c " .. qs_config)
        end

    end)

    hl.on("config.reloaded", function()
        hl.dsp.focus({ workspace = 1 })
    end)
end


