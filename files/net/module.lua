print("module.lua loaded")
print("io " .. tostring(io))

local logger = dofile_once("mods/synergis/files/lib/log.lua")
local log = logger("ew", "mods/synergis/logs/ew.log")
log.reset()

local module = {
    on_world_initialized = function()
        print("My id - " .. tostring(ctx.my_id))
        print("Host id - " .. tostring(ctx.host_id))
        print("Is host - " .. tostring(ctx.is_host))
    end,

    on_local_player_spawn = function(my_player)
        print(string.format("You [%s] joined", my_player.name))
        log.info("players", string.format("You [%s] joined", my_player.name))

        local player_list = "Players:"

        for peer_id, player in pairs(ctx.players) do
            player_list = player_list .. string.format("\n\t[%s] %s", peer_id, player.name)
        end
        
        print(player_list)
        log.info("players", player_list)
    end,

    on_client_spawned = function(peer_id, player_data)
        print(string.format("Player [%d] %s joined", peer_id, player_data.name))
    end
}

return module