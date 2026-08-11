-- Lets a player check their instanced-hunt status without having to walk to a
-- lever and get denied: the 20h cooldown (if active) and how much of their 2h
-- hunting budget is left in the current/paused session (if any).
local huntCooldown = TalkAction("!huntcooldown")

function huntCooldown.onSay(player, words, param)
	local cooldownRemaining = InstancedHunts.getCooldownRemaining(player)
	if cooldownRemaining > 0 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Instanced hunts: on cooldown, " .. InstancedHunts.formatDuration(cooldownRemaining) .. " remaining.")
		return true
	end

	local budgetRemaining = InstancedHunts.getBudgetRemaining(player)
	if budgetRemaining > 0 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Instanced hunts: " .. InstancedHunts.formatDuration(budgetRemaining) .. " of hunting time left in your current session.")
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Instanced hunts: no active cooldown, full 2h available on your next entry.")
	end

	return true
end

huntCooldown:groupType("normal")
huntCooldown:register()
