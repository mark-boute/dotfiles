local monitors = {
    { 
        -- laptop panel (internal)
        output = "desc:California Institute of Technology 0x1637 0x00006000",
        mode = "2560x1600@240",
        position = "0x0",
        scale = 1.25,
    },
    {
        -- HDMI ultrawide external monitor
        output = "desc:Philips Consumer Electronics Company 34M2C3500L UK02514050797",
        mode = "3440x1440@100",
        position = "2048x-160",
        scale = 1,
    },
    { output = "", mode = "preferred", position = "auto", scale = 1, mirror = "desc:California Institute of Technology 0x1637 0x00006000" },
}

for _, monitor in ipairs(monitors) do
    hl.monitor(monitor)
end