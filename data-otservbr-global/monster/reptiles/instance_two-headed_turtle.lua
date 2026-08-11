local mType = Game.createMonsterType("instance|Two-Headed Turtle")
local monster = {}

monster.description = "a two-headed turtle"
monster.experience = 2930
monster.outfit = {
	lookType = 1535,
}

monster.raceId = 2258
monster.Bestiary = {
	class = "Reptile",
	race = BESTY_RACE_REPTILE,
	toKill = 2500,
	FirstUnlock = 100,
	SecondUnlock = 1000,
	CharmsPoints = 50,
	Stars = 4,
	Occurrence = 0,
	Locations = "Great Pearl Fan Reef",
}

monster.health = 5010
monster.maxHealth = 5010
monster.race = "blood"
monster.corpse = 39212
monster.speed = 170
monster.manaCost = 0

monster.changeTarget = {
	interval = 2000,
	chance = 0,
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
	canPushCreatures = false,
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
	level = 0,
	color = 0,
}

monster.voices = {
	interval = 5000,
	chance = 10,
	{ text = "Krk! Krk!", yell = false },
	{ text = "BONK!", yell = true },
}

monster.loot = {
	{ name = "platinum coin", chance = 75000, maxCount = 8 },
	{ name = "great health potion", chance = 11775 },
	{ name = "two-headed turtle heads", chance = 6525 },
	{ name = "strong mana potion", chance = 10029 },
	{ name = "hydrophytes", chance = 8250 },
	{ id = 3115, chance = 4791 }, -- bone
	{ name = "glacier shoes", chance = 3487 },
	{ id = 281, chance = 2686 }, -- giant shimmering pearl (green)
	{ name = "small tropical fish", chance = 2686 },
	{ name = "coral brooch", chance = 1950 },
	{ name = "silver brooch", chance = 1880 },
	{ name = "lightning headband", chance = 1582 },
	{ name = "knight legs", chance = 1500 },
	{ name = "gemmed figurine", chance = 1567 },
	{ name = "emerald bangle", chance = 1029 },
	{ name = "terra amulet", chance = 1029 },
	{ id = 3040, chance = 984 }, -- "gold nugget"
	{ name = "spellbook of enlightenment", chance = 975 },
	{ id = 3565, chance = 761 }, -- "cape"
	{ id = 10422, chance = 492 }, -- "clay lump"
	{ name = "white gem", chance = 313 },
}

monster.attacks = {
	{ name = "melee", interval = 2000, chance = 100, minDamage = -100, maxDamage = -300 },
	{ name = "combat", interval = 2500, chance = 35, type = COMBAT_ENERGYDAMAGE, minDamage = -100, maxDamage = -300, radius = 4, target = false, effect = CONST_ME_ENERGYHIT },
	{ name = "combat", interval = 2000, chance = 35, type = COMBAT_LIFEDRAIN, minDamage = -100, maxDamage = -300, radius = 3, target = true, effect = CONST_ME_GHOSTLY_BITE },
	{ name = "combat", interval = 3000, chance = 45, type = COMBAT_PHYSICALDAMAGE, minDamage = -100, maxDamage = -300, range = 1, radius = 1, target = true, effect = CONST_ME_EXPLOSIONAREA },
}

monster.defenses = {
	defense = 72,
	armor = 72,
	mitigation = 2.02,
}

monster.elements = {
	{ type = COMBAT_PHYSICALDAMAGE, percent = 0 },
	{ type = COMBAT_ENERGYDAMAGE, percent = 10 },
	{ type = COMBAT_EARTHDAMAGE, percent = -20 },
	{ type = COMBAT_FIREDAMAGE, percent = 50 },
	{ type = COMBAT_LIFEDRAIN, percent = 0 },
	{ type = COMBAT_MANADRAIN, percent = 0 },
	{ type = COMBAT_DROWNDAMAGE, percent = 0 },
	{ type = COMBAT_ICEDAMAGE, percent = 50 },
	{ type = COMBAT_HOLYDAMAGE, percent = 0 },
	{ type = COMBAT_DEATHDAMAGE, percent = -10 },
}

monster.immunities = {
	{ type = "paralyze", condition = true },
	{ type = "outfit", condition = false },
	{ type = "invisible", condition = true },
	{ type = "bleed", condition = false },
}

mType:register(monster)
