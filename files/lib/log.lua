local version = ModDoesFileExist("mods/synergis/files/version.lua")
                and dofile_once("mods/synergis/files/version.lua")
                or "unknown"

function logger(context, path)
    local L = {}
    L.context = context
    L.path = path

    function L.write(level, tag, msg)
        local f, err = io.open(L.path, "a")
        if f == nil then
            print("[SYNERGIS] log open failed: " .. tostring(err))
            return
        end
        local result = string.format("[%s] | %s/%s - %s\n", level, L.context, tag, msg)
        f:write(result)
        f:close()
    end

    function L.debug(tag, msg)
        L.write("DEBUG", tag, msg)
    end

    function L.info(tag, msg)
        L.write("INFO", tag, msg)
    end

    function L.warn(tag, msg)
        L.write("WARN", tag, msg)
    end

    function L.error(tag, msg)
        L.write("ERROR", tag, msg)
    end

    function L.reset()
        local f, err = io.open(L.path, "w")
        if f == nil then
            print("[SYNERGIS] log open failed: " .. tostring(err))
            return
        end
        if os and os.date then
            f:write("Start time - " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        end
        f:write("Synergis version " .. version .. "\n")
        f:write("Modding API version - " .. ModGetAPIVersion() .. "\n")
        if DebugGetIsDevBuild() then
            f:write("Dev build\n")
        end
        f:write("Active mods - " .. table.concat(ModGetActiveModIDs(), ", ") .. "\n")
        f:close()
    end

    return L
end

return logger