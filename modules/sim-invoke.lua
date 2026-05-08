

local tickTimeHistory = {}
local tickNumHistory = {}
local tickHistoryMaxSize = 100

local totalTPS = 0


local firstTickTime = 0
local firstTickNumber = 0



-- On the SIM side, OnTick() is run every tick. OnBeat() is the UI side equivalent
function OnTick()
	local a, b = pcall(function()


		if not SessionIsReplay() and GetGameTick() and GetGameTimeSeconds() and rawget(_G, 'systemTime') then

			if firstTickTime then

				--get time since beginning
				local deltaTime = systemTime - firstTickTime

				--time divided by tick distance
				--because deltaTime is called AT THE CURRENT TICK RATE, we need to adjust the delta by how many ticks have ACTUALLY passed or else it's assumed the game is running at 10tps
				realDelta = deltaTime/(GetGameTick() - firstTickNumber)

				totalTPS = 1/realDelta

			end

			Sync.timePerTick = {
				avgTimePerTick10 = getTicksPerSecond(100),
			}


			--LOG2(string.format("TPS (5s): %015.12f  TPS (10s): %015.12f TPS (TOTAL): %015.12f", getTicksPerSecond(50),getTicksPerSecond(100), totalTPS ))


			arrayQueuePush(tickTimeHistory, systemTime, tickHistoryMaxSize)
			arrayQueuePush(tickNumHistory, GetGameTick(), tickHistoryMaxSize)


			if not firstTickTime or not firstTickNumber and GetGameTimeSeconds() > 5 then
				firstTickTime = systemTime
				firstTickNumber = GetGameTick()
			end



		end


	end)


	-- output Stacktrace errors to the Debug Console (F9)
	if not a then LOG2(b) end
end

---@param tickWindow integer
function getTicksPerSecond(tickWindow)

	local ticksPerSecond  = 0

	local currentArraySize = table.getn(tickTimeHistory)

	if currentArraySize >= tickWindow and tickWindow <= tickHistoryMaxSize then

		local deltaTime = systemTime - tickTimeHistory[tickWindow]


		--time divided by tick distance
		--(this code is called AT THE CURRENT TICK RATE, so we need to make sure we have actually progressed a tick) or else it's assumed the game is running at 10tps
		realDelta = deltaTime/(GetGameTick() - tickNumHistory[tickWindow])


		ticksPerSecond = 1/realDelta
	end

	if tickWindow > tickHistoryMaxSize then
		LOG2("Tick window too large, increase the tickHistoryMaxSize")
	end


	return ticksPerSecond

end


---@param array table
---@param element any
---@param limit integer
function arrayQueuePush(array, element, limit)
	
	local length = table.getn(array)

	if length >= limit then
		table.remove(array, length)
	end
	table.insert(array, 1, element)

end
