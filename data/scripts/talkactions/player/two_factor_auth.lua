-- !2fa enable            - generates a new secret and shows it to set up in an authenticator app
-- !2fa confirm <code>     - confirms the secret generated above with a real code, activating 2FA
-- !2fa disable            - turns 2FA off for the account
-- !2fa status             - shows whether 2FA is currently on
local twoFactorAuth = TalkAction("!2fa")

function twoFactorAuth.onSay(player, words, param)
	local subCommand, arg = param:match("^(%S*)%s*(.-)$")
	subCommand = subCommand:lower()

	if subCommand == "enable" then
		if player:isTotpEnabled() then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Two-factor authentication is already enabled on this account.")
			return true
		end

		local secret = player:setupTotp()
		if not secret then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Could not generate a 2FA secret. Try again later.")
			return true
		end

		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Add this key to Google Authenticator (or similar app) manually: " .. secret)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Then type !2fa confirm <the 6-digit code from the app> to finish.")
		return true
	end

	if subCommand == "confirm" then
		if arg == "" then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Usage: !2fa confirm <code>")
			return true
		end

		if player:confirmTotp(arg) then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Two-factor authentication is now enabled. You'll need a code from your app to log in from now on.")
		else
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Wrong code, or no setup in progress. Run !2fa enable first if you haven't.")
		end
		return true
	end

	if subCommand == "disable" then
		if player:disableTotp() then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Two-factor authentication has been disabled.")
		else
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Could not disable 2FA. Try again later.")
		end
		return true
	end

	if subCommand == "status" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Two-factor authentication is currently " .. (player:isTotpEnabled() and "ENABLED" or "disabled") .. ".")
		return true
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Usage: !2fa enable | !2fa confirm <code> | !2fa disable | !2fa status")
	return true
end

twoFactorAuth:groupType("normal")
twoFactorAuth:register()
