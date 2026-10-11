print("module.lua loaded")
print("io " .. tostring(io))

local module = {
    on_world_initialized = function()
        print("My id - " .. tostring(ctx.my_id))
        print("Host id - " .. tostring(ctx.host_id))
        print("Is host - " .. tostring(ctx.is_host))

        local count = 0
        for k, v in pairs(ctx.players) do
            count = count + 1
        end
        print("Players - " .. string.format("%d", count))
    end
}

return module