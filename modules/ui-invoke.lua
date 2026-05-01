--NOTE: running a solo, afk, empty setons clutch for 46:21 resulted in 1:23 of lost time. (97% the speed of realtime)
local options = SessionGetScenarioInfo().Options

----------MODIFY CONSTANTS HERE---------------
----------------------------------------------

-- max length the slow time buffer can hold (ex: =5 means freezing for 10 seconds will only fast forward until 5 seconds is recovered)
local maxRecoveryLength = tonumber(options.SSB_MaxRecovery) or 3.0


----------------------------------------------
----------------------------------------------


local lastTickTime = nil

local lastRealTime = nil
local lastSimTime = nil

local currentDivergence = 0

local totalSlowdown = 0 -- yellow clock
local totalSpeedup = 0 -- green clock

-- used for keeping track of the player's set game speed for overriding the mod when cheats are on
local playerSetSpeed = 0


---@type boolean
local wasPaused = false

local gameSpeed = SessionGetScenarioInfo().Options.GameSpeed


function OnBeat()
	local a, b = pcall(function()
		
		local currentRealTime = CurrentTime()
		local currentSimTime = GetGameTimeSeconds()


		--non-working warning
		if currentSimTime < 5 and gameSpeed ~= 'adjustable' and not CheatsEnabled() then
			print(LOCF("WARNING: Sim Speed Balancer requires Game Speed set to Adjustable! (Readouts still work without that though)"))
		end


		if playerSetSpeed ~= 0 and playerSetSpeed ~= GetGameSpeed() then
			playerSetSpeed = GetGameSpeed()
		end

		if lastRealTime and lastSimTime and not wasPaused then

			local realDelta = currentRealTime - lastRealTime
			local simDelta = currentSimTime - lastSimTime

			local divergenceDelta = realDelta-simDelta
		


				
				-- SLOW TICKS
	
				local maximumAmount = maxRecoveryLength - currentDivergence

				--  accumulate slow and fast ticks (current divergence of real time and sim time)
				if  divergenceDelta < maximumAmount and playerSetSpeed == 0 then
					currentDivergence = currentDivergence + divergenceDelta
					
				elseif divergenceDelta >=maximumAmount and playerSetSpeed == 0 then
					currentDivergence = currentDivergence + maximumAmount
				end

					

				--accumulate slowticks for readouts (time lost)
				if realDelta > simDelta and playerSetSpeed == 0 then
					-- +=
					totalSlowdown = totalSlowdown + divergenceDelta
				
				-- accumulate fast ticks (time saved)
				elseif realDelta < simDelta and playerSetSpeed == 0 then
					-- -=
					totalSpeedup = totalSpeedup + divergenceDelta
				end


				--Final set
				local gameSpeed = 0

				if currentDivergence <= 0.1  then
					gameSpeed = 0
				end
				if currentDivergence > 0.1 then

					gameSpeed = 1

					-- go a little faster for the tick immediately following a slow tick why not
					if divergenceDelta > 0.02 then
						gameSpeed = 2
					end
					if divergenceDelta > 0.035 then
						gameSpeed = 3
					end
				end

				if playerSetSpeed == 0 then
					SetGameSpeed(gameSpeed)
				end

			
		end

		lastRealTime = currentRealTime
		lastSimTime = currentSimTime
		wasPaused = false
		
	end)

	if not a then LOG2(b) end
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
	playerSetSpeed = playerSetSpeed + 1
end

function DecreasePlayerSpeed()
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
