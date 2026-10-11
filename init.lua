local logger = dofile_once("mods/synergis/files/lib/log.lua")
local log = logger("init", "mods/synergis/logs/init.log")

if ModIsEnabled("quant.ew") then
	ModLuaFileAppend("mods/quant.ew/files/api/extra_modules.lua", "mods/synergis/files/net/module.lua")
end


function OnModPreInit()
	print("Synergis - OnModPreInit()")
	log.reset()
	log.info("preinit", "frame=" .. GameGetFrameNum() .. " time=" .. string.format("%.2f", GameGetRealWorldTimeSinceStarted()))
end

function OnModInit()
	print("Synergis - OnModInit()")
end

function OnModPostInit()
	print("Synergis - OnModPostInit()")
end



function OnWorldInitialized()
	log.info("world", "frame=" .. GameGetFrameNum() .. " time=" .. string.format("%.2f", GameGetRealWorldTimeSinceStarted()))
end

function OnMagicNumbersAndWorldSeedInitialized()
	log.info("world", "seed=" .. StatsGetValue("world_seed"))
end