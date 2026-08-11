-- Entrance lever for the Cobra Bastion instanced hunt, next to the real quest's
-- own exit tile (Position(33395, 32665, 6)). Group entry: whoever is standing on
-- config.leverPlatformTiles when the lever is used enters together (up to
-- config.groupSize). See instanced_hunts_config_cobra_bastion.lua.

local config = InstancedHuntsConfigs.CobraBastion
local cobraBastionLever = Action()

local function playersOnPlatform()
	local players = {}
	local seen = {}
	for _, pos in ipairs(config.leverPlatformTiles) do
		local tile = Tile(pos)
		local creature = tile and tile:getTopCreature()
		local player = creature and creature:getPlayer()
		if player and not seen[player:getId()] then
			seen[player:getId()] = true
			table.insert(players, player)
			if #players >= config.groupSize then
				break
			end
		end
	end
	return players
end

function cobraBastionLever.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local group = playersOnPlatform()
	if #group == 0 then
		player:sendCancelMessage("Stand on the marked floor tiles before using this lever (up to " .. config.groupSize .. " players).")
		return true
	end

	local ok, reason, extra1, extra2, cooldownType = InstancedHunts.enter(config, group)
	if not ok then
		if reason == "cooldown" then
			local blockedPlayer, remaining = extra1, extra2
			if cooldownType == "short" then
				player:sendCancelMessage(blockedPlayer:getName() .. " left this hunt recently and needs to wait " .. InstancedHunts.formatDuration(remaining) .. " before entering again.")
			else
				player:sendCancelMessage(blockedPlayer:getName() .. " needs to wait " .. InstancedHunts.formatDuration(remaining) .. " before entering this hunt again.")
			end
		else
			player:sendCancelMessage("All instances of this hunt are currently occupied. Try again later.")
		end
		return true
	end

	for _, p in ipairs(group) do
		p:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have entered a private Cobra Bastion hunt. You have " .. InstancedHunts.formatDuration(InstancedHunts.getBudgetRemaining(p)) .. " of hunting time left.")
	end

	if item:getId() == 8911 then
		item:transform(8914)
	elseif item:getId() == 8914 then
		item:transform(8911)
	end

	return true
end

cobraBastionLever:id(8911, 8912, 8913, 8914)
cobraBastionLever:aid(config.leverActionId)
cobraBastionLever:register()
