-- Lightweight bot-activity heuristic: flags (does not punish) players who have
-- been near-continuously active for hours with no real break. Real players
-- naturally go idle for a few minutes now and then (reading chat, AFK, etc);
-- a script/bot farming 24/7 with zero idle gaps is the signal we watch for.
-- Staff gets a chat notification and decides what to do - this never auto-kicks
-- or auto-bans, since reaction-time heuristics alone are too easy to false-positive.
local antiBotMonitor = GlobalEvent("AntiBotMonitor")

local CHECK_INTERVAL_MS = 5 * 60 * 1000
local IDLE_BREAK_MS = 5 * 60 * 1000
local SUSPICIOUS_STREAK_MS = 4 * 60 * 60 * 1000
local RENOTIFY_INTERVAL_MS = 2 * 60 * 60 * 1000

local function kvRoot()
	return kv.scoped("anti_bot")
end

local function playerKV(guid)
	return kvRoot():scoped(tostring(guid))
end

local function notifyStaff(message)
	for _, player in ipairs(Game.getPlayers()) do
		if player:getAccountType() >= ACCOUNT_TYPE_GAMEMASTER then
			player:sendTextMessage(MESSAGE_ADMINISTRATOR, message)
		end
	end
end

function antiBotMonitor.onThink(interval)
	local now = os.time() * 1000
	for _, player in ipairs(Game.getPlayers()) do
		if player:getAccountType() < ACCOUNT_TYPE_GAMEMASTER then
			local pKV = playerKV(player:getGuid())

			if player:getIdleTime() >= IDLE_BREAK_MS then
				pKV:remove("streakStart")
				pKV:remove("lastNotifiedAt")
			else
				local streakStart = pKV:get("streakStart")
				if not streakStart then
					pKV:set("streakStart", now)
				else
					local streakDuration = now - streakStart
					if streakDuration >= SUSPICIOUS_STREAK_MS then
						local lastNotifiedAt = pKV:get("lastNotifiedAt")
						if not lastNotifiedAt or (now - lastNotifiedAt) >= RENOTIFY_INTERVAL_MS then
							pKV:set("lastNotifiedAt", now)
							local hours = math.floor(streakDuration / (60 * 60 * 1000))
							notifyStaff(string.format(
								"[AntiBot] %s esta ativo ha %d+ horas seguidas sem nenhuma pausa real (possivel bot/script). Recomenda-se revisar.",
								player:getName(), hours
							))
						end
					end
				end
			end
		end
	end
	return true
end

antiBotMonitor:interval(CHECK_INTERVAL_MS)
antiBotMonitor:register()
