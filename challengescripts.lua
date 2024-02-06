--[[
    Setup Functions up top :)
--]]

function ErebussySetup()
    for _, encounterData in pairs(EncounterData) do
        if type(encounterData.ObjectiveSets) == "nil" then
            encounterData.ObjectiveSets = "PerfectClear"
        end
    end
    -- Force erebus gate in any room that can normally spawn one, and allow it to spawn regardless of time since last one.
    for _, roomData in pairs(RoomData) do
        roomData.ShrinePointDoorSpawnChance = 1.0
        if roomData.ShrinePointDoorRequirements then
            roomData.ShrinePointDoorRequirements.RequiredMinRoomsSinceShrinePointDoor = 0
        end
    end
end

function ChaosTimeSetup()
    -- Set the room count on chaos curses to 999
    for k,v in pairs(TraitData) do
        if k:find("ChaosCurse") then
            v.RemainingUses = 
            {
                BaseMin = 999,
                BaseMax = 999,
                AsInt = true
            }
            v.UsesAsEncounters = nil
        end
    end
    -- Force chaos gate in any room that can normally spawn one, and allow it to spawn regardless of time since last one.
    for _, roomData in pairs(RoomData) do
        roomData.SecretSpawnChance = 1.0
        if roomData.SecretDoorRequirements then
            roomData.SecretDoorRequirements.RequiredMinRoomsSinceSecretDoor = 0
        end
    end
end

function LightsOutSetup()
  -- Don't need to do anything special here, just using this because the example has it :)
end

--[[
    General helper/wrapped/overwritten functions down below
--]]

function GetPreviousRoomSet( currentRun )
    -- Default to Tartarus (just to always have a valid return value)
    local roomSetName = "Tartarus"
    -- loop through RoomHistory table in reverse 
    for i=#currentRun.RoomHistory, 1, -1 do
        -- If we're at a room where "UsePreviousRoomSet" is nil or false
        if not currentRun.RoomHistory[i].UsePreviousRoomSet then
            -- Use the RoomSetName from that room
            roomSetName = currentRun.RoomHistory[i].RoomSetName
            -- And stop looping (no need to keep checking anymore)
            break
        end
    end
    -- Return our most recent RoomSetName where we weren't told to use the previous room's name.
    return roomSetName
end

--[[
    This function just manually creates an Erebus Gate at the "HeroStart" location.

    TODO: Replace NORMAL exits with 3 erebussy, add a single "REAL" exit on hero start instead.
--]]
function SpawnHeroStartErebus( currentRun )
    local currentRoom = currentRun.CurrentRoom
    -- Get the ID for where zag starts
    local gateSpawnIds = GetIdsByType({ Name = "HeroStart" })
    -- force the room to spawn a erebus gate (though we're doing that in just a moment)
    currentRoom.ForceShrinePointDoor = true
    -- shrinePointRoomOptions are just the available erebus maps, base is RoomChallenge01,02,03, and 04.
    local shrinePointRoomOptions = currentRoom.ShrinePointRoomOptions or RoomSetData.Base.BaseRoom.ShrinePointRoomOptions
    local shrinePointRoomName = GetRandomValue(shrinePointRoomOptions)
    -- Get the actual data for the room from RoomSetData.Base (RoomData.lua)
    local shrinePointRoomData = RoomSetData.Base[shrinePointRoomName]
    if shrinePointRoomData ~= nil then
        local gateSpawnId = RemoveRandomValue( gateSpawnIds )
        local shrinePointDoor = DeepCopyTable( ObstacleData.ShrinePointDoor )
        shrinePointDoor.ObjectId = SpawnObstacle({ Name = "ShrinePointDoor", Group = "FX_Terrain", DestinationId = gateSpawnId, AttachedTable = shrinePointDoor })
        SetupObstacle( shrinePointDoor )
        --[[
            Make our forced gate cost 0 heat to enter. If you had enough heat to get into the Erebus Gate, you should be allowed to continue.
            I don't wanna go through room history again just to set the ShrinePointDoorCost (even though we could...)
        --]]
        shrinePointDoor.ShrinePointReq = 0
        -- 0 is always affordable :)
        local costFontColor = Color.CostAffordable
        -- Create the room that the gate will lead to (but not the reward for it yet)
        local shrinePointRoom = CreateRoom( shrinePointRoomData, { SkipChooseReward = true } )
        shrinePointRoom.NeedsReward = true
        -- Set the room we created to the gate we created
        AssignRoomToExitDoor( shrinePointDoor, shrinePointRoom )
        shrinePointDoor.OnUsedPresentationFunctionName = "ShrinePointDoorUsedPresentation"
        currentRun.LastShrinePointDoorDepth = GetRunDepth( currentRun )
    end
end
--[[
    This function just manually creates a Chaos Gate at the "HeroStart" location.
--]]
function SpawnHeroStartSecret( currentRun )
    local currentRoom = currentRun.CurrentRoom
    -- Get the ID for where zag starts
    local gateSpawnIds = GetIdsByType({ Name = "HeroStart" })
    -- force the room to spawn a erebus gate (though we're doing that in just a moment)
    currentRoom.ForceSecretDoor = true
    UseHeroTraitsWithValue("ForceSecretDoor", true)
    local secretRoomData = ChooseNextRoomData( currentRun, { RoomDataSet = RoomSetData.Secrets } )
    if secretRoomData ~= nil then
        local gateSpawnId = RemoveRandomValue( gateSpawnIds )
        local secretDoor = DeepCopyTable( ObstacleData.SecretDoor )
        secretDoor.ObjectId = SpawnObstacle({ Name = "SecretDoor", Group = "FX_Terrain", DestinationId = gateSpawnId, AttachedTable = secretDoor })
        SetupObstacle( secretDoor )
        secretDoor.HealthCost = GetSecretDoorCost()
        local secretRoom = CreateRoom( secretRoomData )
        AssignRoomToExitDoor( secretDoor, secretRoom )
        secretDoor.OnUsedPresentationFunctionName = "SecretDoorUsedPresentation"
        currentRun.LastSecretDepth = GetRunDepth( currentRun )
    end
end

ModUtil.Path.Wrap("HandleSecretSpawns", function(baseFunc, currentRun)
    local currentRoom = currentRun.CurrentRoom
    if ChallengeMod.ActiveChallenge == ChallengeMod.ChallengeData.Erebussy.Name then
        if currentRoom.Name:find("RoomChallenge") then
            SpawnHeroStartErebus(currentRun)
        end
        return baseFunc(currentRun)
    elseif ChallengeMod.ActiveChallenge == ChallengeMod.ChallengeData.ChaosTime.Name then
        if currentRoom.Name:find("RoomSecret") then
            SpawnHeroStartSecret(currentRun)
        end
        return baseFunc(currentRun)
    else
        return baseFunc(currentRun)
    end
end, ChallengeMod)

--[[ Try to set this up to automagically give us the chaos reward, but also make the curse never expire. ]]
ModUtil.Path.Wrap("AddTraitData", function(baseFunc, unit, traitData, args)
    if ChallengeMod.ActiveChallenge == ChallengeMod.ChallengeData.ChaosTime.Name then
        if traitData.Name:find("ChaosCurse") then
            baseFunc(unit, traitData.OnExpire.TraitData)
        end
        return baseFunc(unit, traitData, args)
    else
        return baseFunc(unit, traitData, args)
    end
end, ChallengeMod)

--[[ set this up to reset the remaining uses on our curses to 999 after they get decremented ]]
ModUtil.Path.Wrap("EndEncounterEffects", function(baseFunc, currentRun, currentRoom, currentEncounter)
    if ChallengeMod.ActiveChallenge == ChallengeMod.ChallengeData.ChaosTime.Name then
        if currentEncounter == nil or currentEncounter.EncounterType == "NonCombat" then
            return baseFunc(currentRun, currentRoom, currentEncounter)
        end
        for k,v in pairs(currentRun.Hero.Traits) do
            if v.Name:find("ChaosCurse") then
                v.RemainingUses = 1000
            end
        end
        return baseFunc(currentRun, currentRoom, currentEncounter)
    else
        return baseFunc(currentRun, currentRoom, currentEncounter)
    end
end, ChallengeMod)

--[[
    I'm setting the "RoomSetName" for the Erebus rooms to whatever the "RoomSetName" was for the
    most recent room that doesn't tell the rest of the code to "UsePreviousRoomSet". Once we set
    the value, exits should just work and give us exits to the right biome (just like a normal 
    erebus gate would do) and let us jump out to get to the boss fight.
--]]
ModUtil.Path.Wrap("StartRoom", function(baseFunc, currentRun, currentRoom)
    if ChallengeMod.ActiveChallenge == ChallengeMod.ChallengeData.Erebussy.Name then
        -- If we're in an erebus room
        if currentRoom.Name:find("RoomChallenge") then
            -- set the RoomSetName to whatever our most recent RoomSetName was
            currentRoom.RoomSetName = GetPreviousRoomSet(currentRun)
        end
        return baseFunc(currentRun, currentRoom)
    elseif ChallengeMod.ActiveChallenge == ChallengeMod.ChallengeData.ChaosTime.Name then
        -- If we're in an erebus room
        if currentRoom.Name:find("RoomSecret") then
            -- set the RoomSetName to whatever our most recent RoomSetName was
            currentRoom.RoomSetName = GetPreviousRoomSet(currentRun)
        end
        return baseFunc(currentRun, currentRoom)
    else
        return baseFunc(currentRun, currentRoom)
    end
end, ChallengeMod)

--[[
    All rooms can give onions, currently just changes the reward if you take damage,
    there's no indication/noise/notification when it happens, just wanted to make this work.
--]]
ModUtil.Path.Wrap("SpawnRoomReward", function(baseFunc, eventSource, args)
    if ChallengeMod.ActiveChallenge == ChallengeMod.ChallengeData.Erebussy.Name then
        if CurrentRun.CurrentRoom.Encounter.PlayerTookDamage then
            CurrentRun.CurrentRoom.ChangeReward = "RoomRewardConsolationPrize"
        end
        return baseFunc(eventSource, args)
    else
        return baseFunc(eventSource, args)
    end
end, ChallengeMod)

--[[
    Went through all the .map_text files, got a unique list of all "lighting" groups, and disabling them. LIGHTS OUT.
--]]

OnAnyLoad{
    function (triggerargs)
        if ChallengeMod.ActiveChallenge == ChallengeMod.ChallengeData.LightsOut.Name then
            CreateAnimation({Name = "DarkModeBig", DestinationId = CurrentRun.Hero.ObjectId}) -- Bigger version that stretches out farther from zag
            CreateAnimation({Name = "DarkMode", DestinationId = CurrentRun.Hero.ObjectId}) -- smaller version to keep the light area tight on zag
            SetAlpha({ Ids = GetIds ({ Name =  "Background_Lighting_01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "FG_Lighting_01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "FG_Lighting_02" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Foreground_Lighting_01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Foreground_Lighting_02" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Foreground_Lighting" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "ForegroundLighting_01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Lava_Lighting" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Lighting_01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Lighting_02" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Lighting_Phase2" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Lighting" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Lighting01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Lighting02" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Overlook_Lighting_01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "River_Lighting_01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Terrain_Beneath_Lighting" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Terrain_Lighting_01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Terrain_Lighting_02" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Terrain_Lighting_03" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Terrain_Lighting" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Terrain_Lighting01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "Terrain01_Lighting01" }), Fraction = 0, Duration = 0.1 })
            SetAlpha({ Ids = GetIds ({ Name =  "TerrainLighting_01" }), Fraction = 0, Duration = 0.1 })
        end
    end
}