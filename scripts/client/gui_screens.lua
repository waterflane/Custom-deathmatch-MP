function drawHostMenu(st)
	navigationBeginGroup("cdmpHostMenu")
	UiMakeInteractive()
	UiPush()
	UiTranslate(UiCenter(), UiMiddle() + 300)
	UiAlign("center top")
	local width = 330
	local height = 166
	uiDrawPanel(width, height, 16)
	UiTranslate(0, 14)
	UiColor(COLOR_WHITE)
	UiFont(FONT_BOLD, FONT_SIZE_30)
	UiText("loc@UI_TEXT_HOST_MENU")
	UiTranslate(0, 36)
	if uiDrawSecondaryButton("loc@UI_BUTTON_GAME_MODE_SETTINGS", 290) then
		client.cdmpSettingsVisible = not client.cdmpSettingsVisible
		client.cdmpSettingsPage = 1
	end
	UiTranslate(0, 50)
	if uiDrawPrimaryButton("loc@UI_BUTTON_START", 290) then
		applySettingsAndStart(st)
	end
	UiPop()
	navigationEndGroup()
end

function drawWaitingForHost()
	UiPush()
	UiTranslate(UiCenter(), UiMiddle() + 300)
	uiDrawTextPanel("loc@UI_TEXT_WAITING_FOR_HOST", 1)
	UiPop()
end

function drawSetup(st)
	SetBool("game.disablemap", true)
	initializeAllSettings(st)
	hudDrawTitle(client.cdmpDt or 0, "DEATHMATCH", true)
	hudDrawPlayerList()
	hudDrawGameModeHelpText("Deathmatch", "Eliminate opponents. Stay alive, score kills, and climb to the top.")
	if IsPlayerHost(GetLocalPlayer()) then
		drawHostMenu(st)
		drawSettingsPanel(st)
	else
		drawWaitingForHost()
	end
end

function drawCountdown(st)
	SetBool("game.disablemap", true)
	local seconds = math.max(1, math.ceil(st.countdown or 0))
	if client.cdmpCountdownSeconds == nil then
		client.cdmpCountdownSeconds = seconds
	elseif seconds < client.cdmpCountdownSeconds then
		UiSound("timer/1-s-countdown.ogg")
		client.cdmpCountdownSeconds = seconds
	end

	UiPush()
	local width = 260
	local height = 150
	UiTranslate(UiCenter() - width / 2, UiMiddle() - height / 2)
	UiAlign("left top")
	uiDrawPanel(width, height, 16)
	UiTranslate(width / 2, 56)
	UiAlign("center middle")
	UiColor(COLOR_WHITE)
	UiFont(FONT_BOLD, 76)
	UiText(tostring(seconds))
	UiTranslate(0, 52)
	UiFont(FONT_BOLD, FONT_SIZE_22)
	UiText("Starting")
	UiPop()
end

function drawPlaying(st)
	hudDrawTimer(st.timer, 1.0)
	hudDrawDamageIndicators(client.cdmpDt or 0)
	hudDrawPlayerWorldMarkers(GetAllPlayers(), true, 40.0)

	local rows = rowsFromState(st)
	local groups = {{name = "Players", color = {0.52, 0.52, 0.52}, outline = false, rows = rows}}
	local columns = {{name = "Kills", align = "center"}, {name = "Deaths", align = "center"}}
	hudDrawScoreboard(hudIsScoreboardRequested(), "", columns, groups)
	drawKillfeed(st)
	drawHitMarkers(st)
	drawDamageNumbers(st)
	drawDeathOverlay(st)
	hudDrawFade(client.cdmpDt or 0)
end

function drawEnded(st)
	SetBool("game.disablemap", true)
	local rows = rowsFromState(st)
	local groups = {{name = "Players", color = {0.52, 0.52, 0.52}, outline = true, rows = rows}}
	local columns = {{name = "Kills", align = "center"}, {name = "Deaths", align = "center"}}
	local winner = "Match ended"
	if #rows > 0 then winner = GetPlayerName(rows[1].player) .. " wins" end

	local dt = client.cdmpDt or GetTimeStep()
	client.cdmpResultsTime = (client.cdmpResultsTime or 0) + dt
	local bannerDone = hudDrawResultsAnimation(client.cdmpResultsTime, winner, {0.0, 0.0, 0.0, 0.75})
	if not bannerDone then return end

	client.cdmpResultsBoardTime = (client.cdmpResultsBoardTime or 0) + dt
	local delay = CDMP.RESULTS_SCOREBOARD_DELAY or 2.0
	if client.cdmpResultsBoardTime < delay then return end

	local fade = CDMP.Clamp((client.cdmpResultsBoardTime - delay) / (CDMP.RESULTS_SCOREBOARD_FADE or 0.35), 0.0, 1.0)
	local boardWidth = 0
	local boardHeight = 0
	for i = 1, #groups do groups[i].dim = false end

	UiPush()
	UiColorFilter(1, 1, 1, fade)
	UiTranslate(UiCenter(), UiMiddle())
	boardWidth, boardHeight = _drawBoard("Results", columns, groups, true, false, true)
	UiPop()

	navigationBeginGroup("cdmpResults")
	UiPush()
	UiMakeInteractive()
	UiTranslate(UiCenter(), UiMiddle() + boardHeight / 2 + 34)
	UiAlign("center middle")
	UiColorFilter(1, 1, 1, fade)
	if uiDrawPrimaryButton("Deathmatch Menu", 260) then client.cdmpResultsSkipped = true end
	UiPop()
	navigationEndGroup()
end
