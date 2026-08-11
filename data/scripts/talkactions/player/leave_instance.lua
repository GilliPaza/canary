-- Lets any occupant end a private hunt instance early for the whole group at
-- once - everyone inside gets removed together. See InstancedHunts.leaveEarly().
local leaveInstance = TalkAction("!exit")

function leaveInstance.onSay(player, words, param)
	for _, config in pairs(InstancedHuntsConfigs) do
		local ok = InstancedHunts.leaveEarly(config, player)
		if ok then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have left the instance.")
			return true
		end
	end

	player:sendCancelMessage("You are not currently inside a private hunt instance.")
	return true
end

leaveInstance:groupType("normal")
leaveInstance:register()
