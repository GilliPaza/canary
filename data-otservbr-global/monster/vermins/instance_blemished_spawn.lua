local mType = Game.createMonsterType("instance|Blemished Spawn")
local monster = {}

monster.description = "a blemished spawn"
monster.experience = 5300
monster.outfit = {
	lookType = 1401,
	lookHead = 0,
	lookBody = 0,
	lookLegs = 0,
	lookFeet = 0,
	lookAddons = 0,
	lookMount = 0,
}

monster.raceId = 2093
monster.Bestiary = {
	class = "Vermin",
	race = BESTY_RACE_VERMIN,
	toKill = 2500,
	FirstUnlock = 100,
	SecondUnlock = 1000,
	CharmsPoints = 50,
	Stars = 4,
	Occurrence = 0,
	Locations = "Antrum of the Fallen.",
}

monster.health = 9000
monster.maxHealth = 9000
monster.race = "blood"
monster.corpse = 36701
monster.speed = 140
monster.manaCost = 0

monster.changeTarget = {
	interval = 4000,
	chance = 15,
}

monster.strategiesTarget = {
	nearest = 70,
	health = 10,
	damage = 10,
	random = 10,
}

monster.flags = {
	summonable = false,
	attackable = true,
	hostile = true,
	convinceable = false,
	pushable = false,
	rewardBoss = false,
	illusionable = false,
	canPushItems = true,
	canPushCreatures = true,
	staticAttackChance = 80,
	targetDistance = 4,
	runHealth = 0,
	healthHidden = false,
	isBlockable = false,
	canWalkOnEnergy = true,
	canWalkOnFire = false,
	canWalkOnPoison = true,
}

monster.light = {
	level = 3,
	color = 66,
}

monster.voices = {
	interval = 5000,
	chance = 10,
}

monster.loot = {
	{ name = "platinum coin", chance = 52500, maxCount = 25 },
	{ name = "terra rod", chance = 19897 },
	{ name = "blemished spawn abdomen", chance = 7267, maxCount = 1 },
	{ name = "cyan crystal fragment", chance = 6315, maxCount = 3 },
	{ name = "violet crystal shard", chance = 5535, maxCount = 3 },
	{ name = "hailstorm rod", chance = 4162 },
	{ name = "blue crystal shard", chance = 4725, maxCount = 3 },
	{ name = "knight axe", chance = 3562 },
	{ name = "dragonbone staff", chance = 2962 },
	{ name = "violet gem", chance = 3495 },
	{ name = "yellow gem", chance = 3420 },
	{ name = "wand of starstorm", chance = 3142 },
	{ name = "northwind rod", chance = 3990 },
	{ name = "blemished spawn head", chance = 3630 },
	{ name = "sacred tree amulet", chance = 3000 },
	{ name = "springsprout rod", chance = 3457 },
	{ name = "diamond sceptre", chance = 2962 },
	{ id = 281, chance = 2677 }, -- giant shimmering pearl (green)
	{ name = "ice rapier", chance = 2962 },
	{ id = 3289, chance = 2820 }, -- staff
	{ name = "wand of cosmic energy", chance = 2715 },
	{ name = "blemished spawn tail", chance = 2647 },
	{ name = "fur armor", chance = 1020 },
}

monster.attacks = {
	{ name = "melee", interval = 2000, chance = 100, minDamage = 0, maxDamage = -300, condition = { type = CONDITION_POISON, totalDamage = 340, interval = 4000 } },
	{ name = "combat", interval = 2000, chance = 30, type = COMBAT_EARTHDAMAGE, minDamage = -510, maxDamage = -610, range = 7, radius = 3, shootEffect = CONST_ANI_POISON, effect = CONST_ME_HITBYPOISON, target = true },
	{ name = "combat", interval = 2000, chance = 40, type = COMBAT_EARTHDAMAGE, minDamage = -700, maxDamage = -750, radius = 4, effect = CONST_ME_HITBYPOISON, target = false },
}

monster.defenses = {
	defense = 61,
	armor = 61,
	mitigation = 1.60,
	{ name = "combat", interval = 2000, chance = 10, type = COMBAT_HEALING, minDamage = 225, maxDamage = 380, effect = CONST_ME_MAGIC_BLUE, target = false },
}

monster.elements = {
	{ type = COMBAT_PHYSICALDAMAGE, percent = 0 },
	{ type = COMBAT_ENERGYDAMAGE, percent = 0 },
	{ type = COMBAT_EARTHDAMAGE, percent = 10 },
	{ type = COMBAT_FIREDAMAGE, percent = -15 },
	{ type = COMBAT_LIFEDRAIN, percent = 0 },
	{ type = COMBAT_MANADRAIN, percent = 0 },
	{ type = COMBAT_DROWNDAMAGE, percent = 0 },
	{ type = COMBAT_ICEDAMAGE, percent = 0 },
	{ type = COMBAT_HOLYDAMAGE, percent = 0 },
	{ type = COMBAT_DEATHDAMAGE, percent = 10 },
}

monster.immunities = {
	{ type = "paralyze", condition = true },
	{ type = "outfit", condition = false },
	{ type = "invisible", condition = true },
	{ type = "bleed", condition = false },
}

mType:register(monster)
