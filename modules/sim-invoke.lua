
function OnTick()
	--local a, b = pcall(function()
 
		---LOG2("SIM-OnTick")
		--LOG2(GetGameSpeed())

		--SetGameSpeed(10)
		




	--end)
	
	--if not a then LOG2("SIM-OnTick RESULT: ", a, b) end
end


-- requires /enablediskwatch flag to work, therefore is handy during development but dont expect this to work more than once in a real game
function OnChangeDetected()
	local a, b = pcall(function()
		
		LOG2("SIM-OnChangeDetected")

	end)

	if not a then LOG2("SIM-OnChangeDetected RESULT: ", a, b) end
end

OnChangeDetected()

