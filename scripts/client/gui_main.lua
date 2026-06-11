function CDMP_GuiInit()
	client.cdmpDt = 0
	client.cdmpSettingsVisible = false
	client.cdmpSettingsSection = 1
	client.cdmpSettingsPage = 1
	client.cdmpSettingsSeeded = false
	client.cdmpSelectedToolIndex = nil
	client.cdmpResultsSkipped = false
	client.cdmpResultsTime = 0
	client.cdmpResultsBoardTime = 0
	client.cdmpCountdownSeconds = nil
	client.cdmpLastState = ""
end

function CDMP_ClientTick(dt)
	client.cdmpDt = dt
	hudTick(dt)
	SetLowHealthBlurThreshold(0.25)
end

function CDMP_DrawGui()
	local st = shared.cdmp
	if not st then return end
	if client.cdmpLastState ~= st.state then
		local previousState = client.cdmpLastState
		client.cdmpLastState = st.state
		client.cdmpResultsSkipped = false
		client.cdmpResultsTime = 0
		client.cdmpResultsBoardTime = 0
		_resultsAnimCamPos = nil
		_resultsAnimCamRot = nil
		_resultsAnimTime = nil
		endSoundPlayed = false
		if st.state ~= "waiting" and st.state ~= "ended" then
			client.cdmpSettingsVisible = false
			client.cdmpSelectedToolIndex = nil
		end
		if st.state == "countdown" then
			client.cdmpCountdownSeconds = nil
		elseif previousState == "countdown" and st.state == "playing" then
			client.cdmpCountdownSeconds = nil
			UiSound("timer/game-start.ogg")
		end
	end
	if st.state == "playing" then
		drawPlaying(st)
	elseif st.state == "countdown" then
		drawCountdown(st)
	elseif st.state == "ended" and not client.cdmpResultsSkipped then
		drawEnded(st)
	else
		drawSetup(st)
	end
end
