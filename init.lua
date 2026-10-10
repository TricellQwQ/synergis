function OnModPreInit()
	print("Synergis - OnModPreInit()")
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
