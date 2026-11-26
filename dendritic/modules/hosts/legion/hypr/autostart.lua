local commands = {
    "signal-desktop --start-in-tray",
}

hl.on("hyprland.start", function()
    for _, cmd in ipairs(commands) do
        hl.exec_cmd(cmd)
    end
end)
