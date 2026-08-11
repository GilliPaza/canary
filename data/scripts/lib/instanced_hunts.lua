-- Generic engine for lever-triggered private hunt instances.
-- A hunt config describes N pre-built physical copies of a hunting ground; when a
-- player pulls the entrance lever, they get teleported into whichever copy is free
-- and it's populated with fresh monsters. See instanced_hunts_config.lua for the
-- Bashmu pilot configuration.
--
-- Time budget model (2026-08-08): hunting time is a single GLOBAL 2-hour budget per
-- player, shared across every instanced hunt (Bashmu, Cobra Bastion, Marapur
-- Turtles, Antrum, ...) - not a separate 2h per hunt. It only ticks down while the
-- player is physically standing inside any instanced-hunt zone copy; stepping out
-- pauses it, with no limit on how long they can be away, and re-entering (the same
-- hunt or a different one) resumes counting from wherever it stopped. The 20-hour
-- cooldown is also global, and starts the moment a fresh session begins (first
-- entry after the previous cooldown has expired) - it does not reset on exit, and
-- a fresh session always starts with the full 2h budget (never carries over or
-- accumulates unused time from before).
--
-- Physical zone copies are separate bookkeeping from a player's budget: when every
-- occupant of a copy has left (individually or as a group), the copy itself resets
-- immediately (monsters cleared) so a different group can use it right away - see
-- checkExpired for the per-occupant departure handling.

InstancedHunts = {}

local GLOBAL_MAX_TIME = 2 * 60 * 60 -- 2 hours, shared across all instanced hunts
local GLOBAL_COOLDOWN = 20 * 60 * 60 -- 20 hours, shared across all instanced hunts

-- Short anti-exploit cooldown: without this, a player could leave the moment they
-- enter (freeing the copy) and immediately re-enter (any copy, any hunt) to force a
-- brand new monster spawn, over and over, without it costing them anything besides
-- their already-ticking budget. 3 minutes is enough friction to kill that loop
-- without meaningfully affecting a legitimate re-entry.
local SHORT_COOLDOWN_SECONDS = 3 * 60

local function kvRoot()
	return kv.scoped("instanced_hunts")
end

local function zoneKV(huntId, zoneIndex)
	return kvRoot():scoped(huntId):scoped("zone" .. zoneIndex)
end

-- Guid-scoped (not player:kv()) on purpose: this must be readable/writable even
-- after the player has logged out (e.g. disconnected mid-hunt). One record per
-- player, shared across every hunt - NOT scoped by hunt id anymore.
local function playerKV(guid)
	return kvRoot():scoped("players"):scoped(tostring(guid))
end

-- Registers the Zones described by a hunt config. Must run once, after the map is
-- loaded (see instanced_hunts_setup.lua, GlobalEvent:onStartup).
function InstancedHunts.setup(config)
	for index, zoneDef in ipairs(config.zones) do
		local zone = Zone(config.id .. index)
		zone:addArea(zoneDef.from, zoneDef.to)
		zone:setMonsterVariant(config.variant) -- cosmetic/for the native spawn path only, see populateZone()
		zone:setRemoveDestination(config.exitPosition)
	end
end

function InstancedHunts.getCooldownRemaining(player)
	local until_ = playerKV(player:getGuid()):get("cooldownUntil")
	if not until_ then
		return 0
	end
	return math.max(0, until_ - os.time())
end

function InstancedHunts.getShortCooldownRemaining(player)
	local until_ = playerKV(player:getGuid()):get("shortCooldownUntil")
	if not until_ then
		return 0
	end
	return math.max(0, until_ - os.time())
end

-- How much of the global 2h budget the player has left in their current (possibly
-- paused) session. 0 if they have no active/paused session at all.
function InstancedHunts.getBudgetRemaining(player)
	return playerKV(player:getGuid()):get("budgetRemaining") or 0
end

-- Shared duration formatter, used by every lever script's cancel message and by
-- the !huntcooldown talkaction.
function InstancedHunts.formatDuration(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return string.format("%dh%02dmin", hours, minutes)
	end
	return string.format("%dmin", math.max(1, minutes))
end

-- Clears a player's cooldowns and budget entirely, as if they'd never hunted. Used
-- by the /resetinstance god command.
function InstancedHunts.resetCooldown(player)
	local pKV = playerKV(player:getGuid())
	pKV:remove("cooldownUntil")
	pKV:remove("shortCooldownUntil")
	pKV:remove("budgetRemaining")
	pKV:remove("activeSince")
end

local function findFreeZoneIndex(config)
	for index in ipairs(config.zones) do
		if not zoneKV(config.id, index):get("occupantGuids") then
			return index
		end
	end
	return nil
end

-- Spawns the hunt's monsters into the given zone copy (fresh, only called on entry).
--
-- NOTE: this deliberately does NOT use the Lua `Spawn()` helper (data/libs/functions/spawn.lua)
-- or Zone:setMonsterVariant(). Both of those only affect the native spawn.xml-driven
-- respawn path (SpawnMonster::addMonster, C++); a Lua-triggered Game.createMonster()
-- never goes through that resolution. So the reduced-loot variant is spawned directly
-- by its qualified name ("<variant>|<name>", e.g. "instance|Bashmu").
local function populateZone(config, zoneIndex)
	local zoneDef = config.zones[zoneIndex]
	for _, monsterDef in ipairs(zoneDef.monsters) do
		local variantName = config.variant .. "|" .. monsterDef.name
		local monster = Game.createMonster(variantName, monsterDef.pos, false, true)
		if not monster then
			logger.error("[InstancedHunts] Failed to spawn {} at {} (zone {}{})", variantName, monsterDef.pos:toString(), config.id, zoneIndex)
		end
	end
end

-- Attempts to place `players` (a list of 1 to config.groupSize Player objects)
-- into a free copy of the hunt. Returns true on success, or false plus a reason
-- ("cooldown", "full") that the caller can turn into a message. On a cooldown
-- rejection, the 3rd return value is the blocking player, the 4th is the
-- remaining seconds, and the 5th is which cooldown blocked them ("long" for the
-- global 20h cooldown, "short" for the anti-exploit one) - the whole group is
-- denied if even one member is blocked.
function InstancedHunts.enter(config, players)
	for _, player in ipairs(players) do
		local remaining = InstancedHunts.getCooldownRemaining(player)
		if remaining > 0 then
			return false, "cooldown", player, remaining, "long"
		end
		local shortRemaining = InstancedHunts.getShortCooldownRemaining(player)
		if shortRemaining > 0 then
			return false, "cooldown", player, shortRemaining, "short"
		end
	end

	local zoneIndex = findFreeZoneIndex(config)
	if not zoneIndex then
		return false, "full"
	end

	local guids = {}
	local now = os.time()
	for _, player in ipairs(players) do
		local guid = player:getGuid()
		table.insert(guids, guid)

		local pKV = playerKV(guid)
		local budget = pKV:get("budgetRemaining")
		if not budget or budget <= 0 then
			-- Fresh session: full 2h budget, and the 20h cooldown starts now (never
			-- resets again until it naturally expires - see resetCooldown()).
			pKV:set("budgetRemaining", GLOBAL_MAX_TIME)
			pKV:set("cooldownUntil", now + GLOBAL_COOLDOWN)
		end
		pKV:set("activeSince", now)
	end

	zoneKV(config.id, zoneIndex):set("occupantGuids", guids)

	populateZone(config, zoneIndex)

	local zoneDef = config.zones[zoneIndex]
	for _, player in ipairs(players) do
		player:teleportTo(zoneDef.entrancePosition)
	end
	zoneDef.entrancePosition:sendMagicEffect(CONST_ME_TELEPORT)

	return true, zoneIndex
end

-- Banks whatever time a player spent actively hunting since their last resume into
-- their remaining budget, pauses them (clears activeSince), and starts their short
-- anti-exploit cooldown. Does NOT touch the long 20h cooldown or the zone itself -
-- callers handle those. Safe to call on a guid with no active session (no-op on
-- the budget side, still sets the short cooldown).
local function pauseAndCooldownGuid(guid)
	local pKV = playerKV(guid)
	local activeSince = pKV:get("activeSince")
	if activeSince then
		local budget = pKV:get("budgetRemaining") or 0
		pKV:set("budgetRemaining", math.max(0, budget - (os.time() - activeSince)))
		pKV:remove("activeSince")
	end
	pKV:set("shortCooldownUntil", os.time() + SHORT_COOLDOWN_SECONDS)
end

-- Kicks everyone currently in the copy out, clears the monsters and frees the copy
-- for reuse right away (so another group can take it immediately). Pauses and
-- starts the short cooldown for every occupant. Safe to call even if the zone is
-- already empty.
function InstancedHunts.release(config, zoneIndex)
	local zoneName = config.id .. zoneIndex
	local zone = Zone.getByName(zoneName)
	if not zone then
		return
	end

	local occupantGuids = zoneKV(config.id, zoneIndex):get("occupantGuids") or {}
	for _, guid in ipairs(occupantGuids) do
		pauseAndCooldownGuid(guid)
	end

	zone:removePlayers()
	zone:removeMonsters()

	zoneKV(config.id, zoneIndex):remove("occupantGuids")
end

-- Finds which (if any) zone of this hunt the player is currently occupying, by
-- position - used by an in-instance "leave early" command.
function InstancedHunts.findZoneIndexForPlayer(config, player)
	local pos = player:getPosition()
	for index, zoneDef in ipairs(config.zones) do
		if pos:isInRange(zoneDef.from, zoneDef.to) then
			return index
		end
	end
	return nil
end

-- Lets ONE occupant leave early without disturbing the rest of the group: only the
-- caller is pulled out, pauses/cooldowns just them, and the copy keeps running for
-- whoever's left. If they were the last one in, the copy is fully released instead
-- (see release()).
-- Returns true on success, or false plus a reason ("not-in-instance").
function InstancedHunts.leaveEarly(config, player)
	local zoneIndex = InstancedHunts.findZoneIndexForPlayer(config, player)
	if not zoneIndex then
		return false, "not-in-instance"
	end

	local guid = player:getGuid()
	local zKV = zoneKV(config.id, zoneIndex)
	local guids = zKV:get("occupantGuids") or {}
	local remaining = {}
	for _, g in ipairs(guids) do
		if g ~= guid then
			table.insert(remaining, g)
		end
	end

	if #remaining == 0 then
		InstancedHunts.release(config, zoneIndex)
	else
		pauseAndCooldownGuid(guid)
		zKV:set("occupantGuids", remaining)
		player:teleportTo(config.exitPosition)

		local zone = Zone.getByName(config.id .. zoneIndex)
		if zone then
			for _, p in ipairs(zone:getPlayers()) do
				p:sendTextMessage(MESSAGE_EVENT_ADVANCE, player:getName() .. " has left the instance.")
			end
		end
	end

	return true
end

-- Called from the periodic monitor GlobalEvent (every 60s), once per hunt config.
-- For every occupied copy, checks each individual occupant:
--   - still physically inside -> if their global budget just ran out, kick that
--     ONE player out (teleport to the exit position) and pause/cooldown them;
--     everyone else stays and keeps hunting.
--   - no longer physically inside (walked out, logged out, etc., without using
--     !exit) -> pause/cooldown that player, drop them from the copy's occupant
--     list.
-- Once a copy's occupant list is empty, it's fully released (monsters cleared) so
-- another group can use it immediately.
function InstancedHunts.checkExpired(config)
	for index, _ in ipairs(config.zones) do
		local zKV = zoneKV(config.id, index)
		local guids = zKV:get("occupantGuids")
		if guids then
			local zone = Zone.getByName(config.id .. index)
			local presentByGuid = {}
			if zone then
				for _, p in ipairs(zone:getPlayers()) do
					presentByGuid[p:getGuid()] = p
				end
			end

			local stillHere = {}
			for _, guid in ipairs(guids) do
				local player = presentByGuid[guid]
				if player then
					local pKV = playerKV(guid)
					local activeSince = pKV:get("activeSince")
					local budget = pKV:get("budgetRemaining") or 0
					if activeSince and os.time() - activeSince >= budget then
						-- Ran out of time while still hunting: remove just this player.
						pauseAndCooldownGuid(guid)
						player:teleportTo(config.exitPosition)
						player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your hunting time is up. You have been removed from the instance.")
					else
						table.insert(stillHere, guid)
					end
				else
					-- Left individually (walked out, logged out, died and got sent
					-- away, etc.) without using !exit.
					pauseAndCooldownGuid(guid)
				end
			end

			if #stillHere == 0 then
				InstancedHunts.release(config, index)
			elseif #stillHere ~= #guids then
				zKV:set("occupantGuids", stillHere)
			end
		end
	end
end
