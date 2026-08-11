-- Lets players check their stamina and how offline-regen actually works,
-- instead of having to ask staff or guess at the classic Tibia formula.
local staminaInfo = TalkAction("!stamina")

local FULL_STAMINA = 2520 -- 42h
local NORMAL_CAP = 2340 -- 39h, regen is twice as fast below this

local function formatHoursMinutes(totalMinutes)
	local hours = math.floor(totalMinutes / 60)
	local minutes = totalMinutes % 60
	return string.format("%dh%02dmin", hours, minutes)
end

function staminaInfo.onSay(player, words, param)
	local stamina = player:getStamina()

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
		"Stamina: %s of %s.",
		formatHoursMinutes(stamina), formatHoursMinutes(FULL_STAMINA)
	))

	if stamina >= FULL_STAMINA then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your stamina is already full.")
		return true
	end

	-- Regen only happens while offline: 1 minute of stamina per 3 minutes
	-- offline up to 39h, then 1 minute per 6 minutes offline from 39h to 42h.
	local missingToNormalCap = math.max(0, NORMAL_CAP - stamina)
	local missingToFull = FULL_STAMINA - stamina
	local missingAboveCap = missingToFull - missingToNormalCap

	local offlineSecondsNeeded = (missingToNormalCap * 180) + (missingAboveCap * 360)
	local offlineMinutesNeeded = math.ceil(offlineSecondsNeeded / 60)

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
		"Stamina regenerates only while you are offline: 1 min per 3 min offline up to 39h, then 1 min per 6 min offline up to the 42h cap. If you logged out now, it would take about %s offline to refill.",
		formatHoursMinutes(offlineMinutesNeeded)
	))

	return true
end

staminaInfo:groupType("normal")
staminaInfo:register()
