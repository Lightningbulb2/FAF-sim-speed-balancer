--NOTE: running a solo, afk, empty setons clutch for 46:21 resulted in 1:23 of lost time. (97% the speed of realtime)
local options = SessionGetScenarioInfo().Options

----------MODIFY CONSTANTS HERE---------------
----------------------------------------------

--number of ticks that can be zoomed forward after a freeze
local zoopTickLengthLimit = tonumber(options.SSB_ZoopTickLimit) or 15

-- max length the slow time buffer can hold (ex: =5 means freezing for 10 seconds will only fast forward until 5 seconds is recovered)
local maxRecoveryLength = tonumber(options.SSB_MaxRecovery) or 5.0

--minimum delay between ticks until it zoops
local haltCuttoff = tonumber(options.SSB_HaltCutoff) or 0.3

----------------------------------------------
----------------------------------------------


local lastRealTime = nil
local lastSimTime = nil

local slowdownAccumulator = 0

local totalSlowdownRegainedAccumulator = 0
local totalSlowdownAccumulator = 0
local totalHaltAccumulator = 0
local totalPauseAccumulator = 0

local playerSetSpeed = 0



local zoop = 0
local zoopDivergence = 0
local zoopAccumulator = 0


---@type boolean
local wasPaused = false

local gameSpeed = SessionGetScenarioInfo().Options.GameSpeed


function OnBeat()
	local a, b = pcall(function()
		
		local currentRealTimestamp = CurrentTime()
		local currentSimTimestamp = GetGameTimeSeconds()

		--non-working warning
		if currentSimTimestamp < 5 and gameSpeed ~= 'adjustable' and not CheatsEnabled() then
			print(LOCF("WARNING: Sim Speed Balancer requires Game Speed set to Adjustable!"))
		end

		--LOG2("player set speed: " .. playerSetSpeed)


		if playerSetSpeed ~= 0 and playerSetSpeed ~= GetGameSpeed() then
			playerSetSpeed = GetGameSpeed()
		end

		if lastRealTime and lastSimTime then

			local realDelta = currentRealTimestamp - lastRealTime
			local simDelta = currentSimTimestamp - lastSimTime

			local divergenceAmountSinceLastBeat = realDelta-simDelta

			-- Last tick length = 1 + divergenceAmountSinceLastBeat

			--LOG2("DIVERGENCE: " .. divergenceAmountSinceLastBeat)
		
			if not wasPaused then


				-- HALTS -- handle long pauses by "zooping"
				if divergenceAmountSinceLastBeat >= haltCuttoff then

					if divergenceAmountSinceLastBeat < 10 then
						zoop = zoopTickLengthLimit --game speed applied that will count down over the equivalent number of ticks
						zoopDivergence = divergenceAmountSinceLastBeat
						zoopAccumulator = 0
					end
					--LOG2("halted")

					if divergenceAmountSinceLastBeat <= 5 then
						totalHaltAccumulator = totalHaltAccumulator + divergenceAmountSinceLastBeat
					else
						totalHaltAccumulator = totalHaltAccumulator + 5
					end

				end


				
				-- SLOW TICKS
				--  accumulate slow and fast ticks (current divergence of real time and sim time)
				local maximumAmount = maxRecoveryLength - slowdownAccumulator

				if  divergenceAmountSinceLastBeat < maximumAmount and playerSetSpeed == 0 then
					slowdownAccumulator = slowdownAccumulator + divergenceAmountSinceLastBeat
					
				elseif divergenceAmountSinceLastBeat >=maximumAmount and playerSetSpeed == 0 then
					slowdownAccumulator = slowdownAccumulator + maximumAmount
				end

					

				--accumulate slowticks for readouts (time lost)
				if realDelta > simDelta and playerSetSpeed == 0 then
					-- +=
					totalSlowdownAccumulator = totalSlowdownAccumulator + divergenceAmountSinceLastBeat
				
				-- accumulate fast ticks (time saved)
				elseif realDelta < simDelta and playerSetSpeed == 0 then
					-- -=
					totalSlowdownRegainedAccumulator = totalSlowdownRegainedAccumulator + divergenceAmountSinceLastBeat
				end


				if slowdownAccumulator <= 0.1 and playerSetSpeed == 0 then
					SetGameSpeed(0)
				end
				if slowdownAccumulator > 0.1 and playerSetSpeed == 0 then
					SetGameSpeed(1)
				end

				if slowdownAccumulator > 0.1 and divergenceAmountSinceLastBeat > 0.12 and playerSetSpeed == 0 then
					SetGameSpeed(2)
				end
				
				
				-- after halt zoom forward 10..9..8 .... 2.. 1.. 0 ticks and set the game speed to the same
				if zoop > 0 then

					if zoop < zoopTickLengthLimit then

						zoopAccumulator = zoopAccumulator + divergenceAmountSinceLastBeat
					end

					--LOG2("ZOOPING: " .. zoop)
					zoop = zoop - 1
					if slowdownAccumulator <= 0.1 or zoopAccumulator >= zoopDivergence then
						zoop = 0
					end

					local cappedZoop = zoop

					if cappedZoop > 10 then
						cappedZoop = 10
					end
					if cappedZoop < 3 then
						cappedZoop = 3
					end

					if playerSetSpeed == 0 then
						SetGameSpeed(cappedZoop)
					end

				end

			end

			if wasPaused then
				totalPauseAccumulator = totalPauseAccumulator + divergenceAmountSinceLastBeat
			end
		end



		lastRealTime = currentRealTimestamp
		lastSimTime = currentSimTimestamp
		wasPaused = false

		--LOG2("REAL: " .. currentRealTimestamp)
		--LOG2("SIM: " .. currentSimTimestamp)
		LOG2("BEHIND: " .. slowdownAccumulator)
		
		
	end)

	if not a then LOG2(b) end
end

--[[
---@param speed number
function ModSetGameSpeed(speed)
    if not WorldIsLoading() and (import("/lua/ui/game/gamemain.lua").supressExitDialog != true) then
        ConExecute('WLD_GameSpeed' .. speed)
    end    
end
]]

function ModSetGamePaused(bool)
	wasPaused = bool
end

function getTotalSlowdown()
	return FormatTime(totalSlowdownAccumulator)
end
function getTotalSpeedup()
	return FormatTime(math.abs(totalSlowdownRegainedAccumulator))
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


-- requires /enablediskwatch flag to work, therefore is handy during development but dont expect this to work more than once in a real game
function OnChangeDetected()
	local a, b = pcall(function()

		LOG2("UI-OnChangeDetected")

	end)

	if not a then LOG2(b) end
end

OnChangeDetected()

