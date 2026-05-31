return function(qs_config)

    hl.on("hyprland.start", function()
        hl.dsp.focus({ workspace = 1 })
        hl.exec_cmd("hyprlauncher -d")
        hl.exec_cmd("hyprsunset")
        hl.exec_cmd("hypridle")
        
        if qs_config then
            hl.exec_cmd("qs -c " .. qs_config)
        end

    end)

    hl.on("config.reloaded", function()
        hl.dsp.focus({ workspace = 1 })
    end)
end


