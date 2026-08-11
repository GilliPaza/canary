-- Lets players check the server's stage-based rates in-game instead of having
-- to alt-tab to the website. Mirrors data/stages.lua, data/stages_skill.lua and
-- data/stages_magic.lua - keep this in sync if those tables ever change.
local ratesInfo = TalkAction("!rates")

local EXPERIENCE_STAGES = {
	{ 1, 8, "50x" }, { 9, 50, "80x" }, { 51, 100, "60x" }, { 101, 150, "40x" },
	{ 151, 200, "30x" }, { 201, 300, "15x" }, { 301, 400, "12x" }, { 401, 500, "10x" },
	{ 501, 600, "7x" }, { 601, 700, "6x" }, { 701, 800, "5x" }, { 801, 900, "4x" },
	{ 901, 1000, "3x" }, { 1001, 1200, "2x" }, { 1201, 1400, "1.5x" }, { 1401, nil, "1.2x" },
}

local MAGIC_STAGES = {
	{ 0, 80, "10x" }, { 81, 100, "7x" }, { 101, 120, "4x" }, { 121, 130, "3x" }, { 131, nil, "2x" },
}

local function findStage(stages, level)
	for _, stage in ipairs(stages) do
		if level >= stage[1] and (stage[2] == nil or level <= stage[2]) then
			return stage[3]
		end
	end
	return "1x"
end

function ratesInfo.onSay(player, words, param)
	local level = player:getLevel()
	local magicLevel = player:getBaseMagicLevel()

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
		"Your experience rate right now: %s (level %d) | Loot: 2.5x | Bestiary: 2x",
		findStage(EXPERIENCE_STAGES, level), level
	))
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
		"Your magic rate right now: %s (magic level %d). Skills (sword/axe/club/etc): 10x up to 80, 7x 81-100, 4x 101-120, 2x above 120.",
		findStage(MAGIC_STAGES, magicLevel), magicLevel
	))
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Rates are stage-based (higher level/skill = lower multiplier). Full table: http://179.198.116.60:9080/?subtopic=ots-info")

	return true
end

ratesInfo:groupType("normal")
ratesInfo:register()
