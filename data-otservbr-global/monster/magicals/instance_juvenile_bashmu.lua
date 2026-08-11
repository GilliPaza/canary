local mType = Game.createMonsterType("instance|Juvenile Bashmu")
local monster = {}

monster.description = "a juvenile bashmu"
monster.experience = 4500
monster.outfit = {
	lookType = 1408,
	lookHead = 0,
	lookBody = 112,
	lookLegs = 3,
	lookFeet = 79,
	lookAddons = 0,
	lookMount = 0,
}

monster.raceId = 2101
monster.Bestiary = {
	class = "Magical",
	race = BESTY_RACE_MAGICAL,
	toKill = 2500,
	FirstUnlock = 100,
	SecondUnlock = 1000,
	CharmsPoints = 50,
	Stars = 4,
	Occurrence = 1,
	Locations = "Salt Caves",
}

monster.health = 7500
monster.maxHealth = 7500
monster.race = "blood"
monster.corpse = 36967
monster.speed = 195
monster.manaCost = 0

monster.changeTarget = {
	interval = 2000,
	chance = 20,
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
	staticAttackChance = 90,
	targetDistance = 1,
	runHealth = 0,
	healthHidden = false,
	isBlockable = false,
	canWalkOnEnergy = true,
	canWalkOnFire = true,
	canWalkOnPoison = true,
}

monster.light = {
	level = 1,
	color = 0,
}

monster.voices = {
	interval = 5000,
	chance = 10,
}

-- Same drop list as the regular Juvenile Bashmu, chance reduced to 75% (instanced-hunt economy penalty)
monster.loot = {
	{ name = "platinum coin", chance = 52500, maxCount = 19 },
	{ name = "great spirit potion", chance = 11025, maxCount = 4 },
	{ name = "ultimate health potion", chance = 975, maxCount = 4 },
	{ name = "blue crystal shard", chance = 4620, maxCount = 3 },
	{ name = "bashmu tongue", chance = 4380, maxCount = 3 },
	{ name = "bashmu feather", chance = 3465, maxCount = 2 },
	{ name = "green crystal shard", chance = 2750 },
	{ name = "cyan crystal fragment", chance = 2505 },
	{ id = 3039, chance = 1793, maxCount = 1 }, -- red gem
	{ name = "violet gem", chance = 1755, maxCount = 1 },
	{ name = "lightning legs", chance = 1673 },
	{ name = "diamond sceptre", chance = 1635 },
	{ name = "lightning pendant", chance = 1635 },
	{ name = "bashmu fang", chance = 1590 },
	{ name = "yellow gem", chance = 1553 },
	{ name = "war hammer", chance = 1155 },
	{ name = "violet crystal shard", chance = 1118 },
	{ name = "dragonbone staff", chance = 1073 },
	{ name = "amber staff", chance = 953 },
	{ name = "lightning boots", chance = 953 },
	{ name = "green gem", chance = 915 },
	{ name = "spellweaver's robe", chance = 833 },
	{ name = "pair of iron fists", chance = 758 },
	{ name = "skull staff", chance = 720 },
	{ name = "crystal mace", chance = 600 },
	{ name = "chaos mace", chance = 398 },
}

monster.attacks = {
	{ name = "melee", interval = 2000, chance = 100, minDamage = 0, maxDamage = -400 },
	{ name = "combat", interval = 2000, chance = 50, type = COMBAT_ENERGYDAMAGE, minDamage = -300, maxDamage = -400, length = 4, spread = 0, effect = CONST_ME_ENERGYAREA, target = false },
	{ name = "combat", interval = 2000, chance = 40, type = COMBAT_ENERGYDAMAGE, minDamage = -400, maxDamage = -500, range = 3, radius = 3, effect = CONST_ME_ENERGYHIT, target = false },
	{ name = "combat", interval = 2000, chance = 20, type = COMBAT_EARTHDAMAGE, minDamage = -400, maxDamage = -500, range = 7, shootEffect = CONST_ANI_EARTHARROW, target = true },
}

monster.defenses = {
	defense = 75,
	armor = 75,
	{ name = "combat", interval = 2000, chance = 20, type = COMBAT_HEALING, minDamage = 100, maxDamage = 150, effect = CONST_ME_MAGIC_BLUE, target = false },
}

monster.elements = {
	{ type = COMBAT_PHYSICALDAMAGE, percent = 0 },
	{ type = COMBAT_ENERGYDAMAGE, percent = 5 },
	{ type = COMBAT_EARTHDAMAGE, percent = 5 },
	{ type = COMBAT_FIREDAMAGE, percent = 0 },
	{ type = COMBAT_LIFEDRAIN, percent = 0 },
	{ type = COMBAT_MANADRAIN, percent = 0 },
	{ type = COMBAT_DROWNDAMAGE, percent = 0 },
	{ type = COMBAT_ICEDAMAGE, percent = -10 },
	{ type = COMBAT_HOLYDAMAGE, percent = -20 },
	{ type = COMBAT_DEATHDAMAGE, percent = 5 },
}

monster.immunities = {
	{ type = "paralyze", condition = true },
	{ type = "outfit", condition = false },
	{ type = "invisible", condition = true },
	{ type = "bleed", condition = false },
}

mType:register(monster)
