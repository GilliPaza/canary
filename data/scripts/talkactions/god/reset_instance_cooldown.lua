local resetInstanceCooldown = TalkAction("/resetinstance")

function resetInstanceCooldown.onSay(player, words, param)
	-- create log
	logCommand(player, words, param)

	local target = player
	if param ~= "" then
		local targetPlayer = Player(param)
		if not targetPlayer then
			player:sendCancelMessage("Player not found.")
			return true
		end
		target = targetPlayer
	end

	InstancedHunts.resetCooldown(target)

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Reset instanced hunt cooldown/budget for %s.", target:getName()))
	return true
end

resetInstanceCooldown:separator(" ")
resetInstanceCooldown:groupType("god")
resetInstanceCooldown:register()
