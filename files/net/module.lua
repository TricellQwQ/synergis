local logger = dofile_once("mods/synergis/files/lib/log.lua")
local log = logger("ew", "mods/synergis/logs/ew.log")

log.reset()

local ew_api = dofile_once("mods/quant.ew/files/api/ew_api.lua")

local rpc = ew_api.new_rpc_namespace("synergis")

rpc.opts_everywhere()
function rpc.hello()
    local player = ew_api.rpc_player_data()
    if ctx.rpc_peer_id ~= ctx.my_id then
        log.info("rpc", string.format("Hello from player %s [%s]", player.name, ctx.rpc_peer_id))
        return
    end
    log.debug("rpc", "self hello (ignored)")
end

local function shared_frame()
    if ctx.is_host then return tostring(GameGetFrameNum()) end
    return tostring(ctx.host_frame_num)
end

local roster = {}

local function refresh_roster(silent)
    local seen = {}

    for peer_id, p in pairs(ctx.players) do
        seen[peer_id] = true
        local known = roster[peer_id]

        if known == nil then
            roster[peer_id] = {name = p.name, entity = p.entity, dc = p.dc}
            if not silent then
                log.info("players", string.format("%s [%s] joined, frame=%s", tostring(p.name), peer_id, shared_frame()))
            end
            rpc.hello()
        else
            known.name = p.name
            known.entity = p.entity
            if p.dc ~= known.dc then
                known.dc = p.dc
                if known.dc then
                    log.info("players", tostring(p.name) .. " disconnected, frame=" .. shared_frame())
                else
                    log.info("players", tostring(p.name) .. " reconnected, frame=" .. shared_frame())
                end
            end
        end
    end

    for peer_id, p in pairs(roster) do
        if not seen[peer_id] then
            log.info("players", string.format("%s [%s] left, frame=%s", p.name, peer_id, tostring(shared_frame())))
            roster[peer_id] = nil
        end
    end
end
            

local module = {
    on_world_initialized = function()
        print("My id - " .. tostring(ctx.my_id))
        print("Host id - " .. tostring(ctx.host_id))
        print("Is host - " .. tostring(ctx.is_host))
    end,

    on_local_player_spawn = function(my_player)
        log.info("players", string.format("You [%s] joined", my_player.name))

        local player_list = "Players:"

        for peer_id, player in pairs(ctx.players) do
            player_list = player_list .. string.format("\n\t[%s] %s", peer_id, player.name)
        end
        
        log.info("players", player_list)

        refresh_roster(true)
    end,

    on_client_spawned = function(peer_id, player_data)
        refresh_roster()
    end,

    on_world_update = function()
        if GameGetFrameNum() % 30 == 0 then
            refresh_roster()
        end
    end
}

return module