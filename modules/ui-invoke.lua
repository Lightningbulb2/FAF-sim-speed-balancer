--NOTE: running a solo, afk, empty setons clutch for 46:21 resulted in 1:23 of lost time. (97% the speed of realtime)
local options = SessionGetScenarioInfo().Options

----------MODIFY CONSTANTS HERE---------------
----------------------------------------------

-- max length the slow time buffer can hold (ex: =5 means freezing for 10 seconds will only fast forward until 5 seconds is recovered)
local maxRecoveryLength = tonumber(options.SSB_MaxRecovery) or 3.0


local targetTickrate = tonumber(options.SSB_TargetTickrate) or 1


----------------------------------------------
----------------------------------------------

-- TODO: make the debug toggle silently set everyone's game (for performance testing)

local lastRealTime = nil
local lastSimTime = nil

local timeOffset = nil
local tickOffset = nil

local currentDivergence = 0.0

local totalSlowdown = 0.0 -- yellow clock
local totalSpeedup = 0.0 -- green clock



-------------------------------------
-- used for keeping track of the player's set game speed for overriding the mod when cheats are on, or in a replay
local playerSetSpeed = 0

local decreaseSpeed = false
local increaseSpeed = false

local lastSetModSpeed = 0
local gameSpeed = 0

local modEnabled = true
-------------------------------------



---@type boolean
local wasPaused = false

local gameSpeedOption = SessionGetScenarioInfo().Options.GameSpeed or 0


function OnBeat()
	local a, b = pcall(function()
		
		local currentRealTime = CurrentTime()

		local currentSimTime = GetGameTimeSeconds()


		-- Offset the times to be the same (makes comparisons easier)
		if not tickOffset and not timeOffset and currentRealTime and currentSimTime then
			timeOffset = currentRealTime
			tickOffset = currentSimTime
		end

		if timeOffset then
			currentRealTime = (currentRealTime - timeOffset)
		end

		if  tickOffset and currentSimTime then
			currentSimTime = currentSimTime - tickOffset
		end


		SimCallback({Func = "setSystemTime", Args = {time = currentRealTime}})


		--non-working warning
		if currentSimTime < 5 and gameSpeedOption ~= 'adjustable' and not CheatsEnabled() then
			print(LOCF("WARNING: Sim Speed Balancer requires Game Speed set to Adjustable! (Readouts still work without that though)"))
		end


		if playerSetSpeed ~= 0 and playerSetSpeed ~= GetGameSpeed() and not increaseSpeed and not decreaseSpeed then
			playerSetSpeed = GetGameSpeed()
			if SessionIsReplay() then
				import('/lua/ui/game/score.lua').ChangeSlider(GetGameSpeed())
			end
		end


		if lastRealTime and lastSimTime and not wasPaused and not SessionIsPaused() then

			local realDelta = (currentRealTime) - lastRealTime
			local realDelta = realDelta*targetTickrate
			local simDelta = (currentSimTime - lastSimTime)

			
			local divergenceDelta = (realDelta)-simDelta
		
			
			
				
				-- SLOW TICKS
	
				local maximumAmount = maxRecoveryLength - currentDivergence

				--  accumulate slow and fast ticks (current divergence of real time and sim time)
				if  divergenceDelta < maximumAmount and playerSetSpeed == 0 then
					currentDivergence = currentDivergence + divergenceDelta
					
				elseif divergenceDelta >=maximumAmount and playerSetSpeed == 0 then
					currentDivergence = currentDivergence + maximumAmount
				end

					

				--accumulate slowticks for readouts (time lost)
				if realDelta > simDelta and not currentDivergence <= 0.1 and playerSetSpeed == 0 then
					-- +=
					totalSlowdown = totalSlowdown + divergenceDelta
				
				-- accumulate fast ticks (time saved)
				elseif realDelta < simDelta and not currentDivergence <= 0.1 and playerSetSpeed == 0 then
					-- -=
					totalSpeedup = totalSpeedup + divergenceDelta
				end

				if currentDivergence <= 0.1 then
					gameSpeed = 0
				end
				
				if currentDivergence > 0.1 then

					gameSpeed = 1
					
					-- go a little faster for the tick immediately following a slow tick why not
					if divergenceDelta > 0.035 then
						gameSpeed = 2
					end
					if divergenceDelta > 0.05 then
						gameSpeed = 3
					end
					
				end

				if increaseSpeed and (lastSetModSpeed == 1 or lastSetModSpeed == 2 or lastSetModSpeed == 3) then
					SetGameSpeed(1)
					playerSetSpeed = 1
					increaseSpeed = false
				end
				if decreaseSpeed and (lastSetModSpeed == 1 or lastSetModSpeed == 2 or lastSetModSpeed == 3) then
					SetGameSpeed(-1)
					playerSetSpeed = -1
					decreaseSpeed = false
				end


				if playerSetSpeed == 0 and modEnabled then
					SetGameSpeed(gameSpeed)
				end

		end


		if playerSetSpeed == 0 then
			lastSetModSpeed = gameSpeed
		else
			lastSetModSpeed = -100
		end

		decreaseSpeed = false
		increaseSpeed = false

		lastRealTime = currentRealTime
		lastSimTime = currentSimTime
		wasPaused = false
		
	end)

	if not a then LOG2(b) end
end

function toggleEnabled()
	if modEnabled then
		modEnabled = false
		print(LOCF("Sim Speed Balancer: disabled"))
		SetGameSpeed(0)
	else
		modEnabled = true
		print(LOCF("Sim Speed Balancer: enabled"))
	end
	
end

function ModSetGamePaused(bool)
	wasPaused = bool
end

function getTotalSlowdown()
	return FormatTime(totalSlowdown)
end
function getTotalSpeedup()
	return FormatTime(math.abs(totalSpeedup))
end

function FormatTime(seconds)
    local h = math.floor(seconds / 3600)
	local m = math.floor(math.mod(seconds, 3600) / 60)
	local s = math.floor(math.mod(seconds, 60))
    return string.format(" %02d:%02d:%02d", h, m, s)
end

function IncreasePlayerSpeed()
	increaseSpeed = true
	--LOG("IncreasePlayerSpeed")
	playerSetSpeed = playerSetSpeed + 1
end

function SetPlayerSpeed(speed)
	--LOG("SetPlayerSpeed")
	playerSetSpeed = speed
end

function DecreasePlayerSpeed()
	--LOG("DecreasePlayerSpeed")
	decreaseSpeed = true

	playerSetSpeed = playerSetSpeed - 1
end

function GetPlayerSpeed()
	return playerSetSpeed
end


function CheatsEnabled()
	if SessionIsActive() then
		local cheatStatus = SessionGetScenarioInfo().Options.CheatsEnabled
		if cheatStatus == "true" then
			return true
		else
			return false
		end
	end
end
