local logger = dofile_once("mods/synergis/files/lib/log.lua")
local log = logger("init", "mods/synergis/logs/init.log")


function OnModPreInit()
	print("Synergis - OnModPreInit()")
	log.reset()
end

function OnModInit()
	print("Synergis - OnModInit()")
end

function OnModPostInit()
	print("Synergis - OnModPostInit()")
end



function OnWorldInitialized()
	GamePrint( "OnWorldInitialized() " .. tostring(GameGetFrameNum()) )
end

function OnPlayerSpawned()
    GamePrint( "OnPlayerSpawned()" )
end
