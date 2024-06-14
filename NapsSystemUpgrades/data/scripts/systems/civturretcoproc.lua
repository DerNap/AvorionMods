package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

-- civil turret-system co-processor
    -- adds mining system
    -- adds civil turret slots
    -- adds auto aim slots
    -- adds loot range extender
    -- adds teleport system for distant docking

gMatRange = 0
gMatLevel = 0
gMatAmount = 0

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true
--PermanentInstallationOnly = true
Unique = true

function getLootCollectionRange(seed, rarity, permanent)
    math.randomseed(seed)

    local range = (rarity.value + 2) * 2 * (1.3 ^ rarity.value) * 10 -- one unit is 10 meters;

    if permanent then
        range = range * 2 -- changed
    end

    range = round(range)

    return range
end

function getMiningSystemBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local range = 400 -- base value
    -- add flat range based on rarity
    range = range + (rarity.value + 1) * 200 -- add 0 (worst rarity) to +1200 (best rarity)

    local material = rarity.value + 1
    if math.random() < 0.25 then
        material = material + 1
    end

    local amount = 3
    -- add flat amount based on rarity
    amount = amount + (rarity.value + 1) * 2 -- add 0 (worst rarity) to +120 (best rarity)
    -- add randomized amount, span is based on rarity
    amount = amount + math.random() * ((rarity.value + 1) * 5) -- add random value between 0 (worst rarity) and 60 (best rarity)

    if permanent then
        range = range * 1.5
        amount = amount * 1.5
        material = material + 1
    end

    return material, range, amount
end

function sort(a, b)
    return a.distance < b.distance
end

function onPreRenderHud()

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local ship = Entity()
    if player.craftIndex ~= ship.index then return end

    local shipPos = ship.translationf

    local sphere = Sphere(shipPos, gMatRange)
    local nearby = {Sector():getEntitiesByLocation(sphere)}
    local displayed = {}

    -- detect all asteroids in range
    for _, entity in pairs(nearby) do

        if entity.type == EntityType.Asteroid then
            local resources = entity:getMineableResources()
            if resources ~= nil and resources > 0 then
                local material = entity:getMineableMaterial()

                if material.value <= gMatLevel then

                    local d = distance2(entity.translationf, shipPos)

                    table.insert(displayed, {material = material, asteroid = entity, distance = d})
                end
            end
        end

    end

    -- sort by distance
    table.sort(displayed, sort)

    -- display nearest x
    local renderer = UIRenderer()

    for i = 1, math.min(#displayed, gMatAmount) do
        local tuple = displayed[i]
        renderer:renderEntityTargeter(tuple.asteroid, tuple.material.color);
        renderer:renderEntityArrow(tuple.asteroid, 30, 10, 250, tuple.material.color);
    end

    renderer:display()
end

function getNumBonusTurrets(seed, rarity, permanent)
    if permanent then
        return math.max(1, (rarity.value + 1) * (rarity.value + 1) * (rarity.value + 1))
    end

    return 0
end

function getNumTurrets(seed, rarity, permanent)
    math.randomseed(seed)
    -- base of (1-6)^2 base turrets
    -- since the size of the turrest increase with tech levels, being in e.g. 
    -- trinium area the size of the turrets is already like 4, just giving 4 slots 
    -- still would mean you can still only add one turret of that type
    -- therefore we multiply the turret slots with the rarity also
    local baseTurrets = math.max(1, (rarity.value + 1) * (rarity.value + 1))
    -- bonus turrets are also multiplied by rarity
    local turrets = baseTurrets + getNumBonusTurrets(seed, rarity, permanent)

    local pdcs = math.floor(baseTurrets / 2)
    if not permanent then
        pdcs = turrets
    end

    local autos = 0
    if permanent then
        autos = turrets
    end

    return turrets, pdcs, autos
end


function getTransporterBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    -- rarity -1 is -1 / 2 + 1 * 50 = 0.5 * 100 = 50
    -- rarity 5 is 5 / 2 + 1 * 50 = 3.5 * 100 = 350
    local range = (rarity.value / 2 + 1 + round(getFloat(0.0, 0.4), 1)) * 100

    local fighterCargoPickup = 0
    if rarity.value >= RarityType.Rare then
        fighterCargoPickup = 1
    end

    return range, fighterCargoPickup
end


function onInstalled(seed, rarity, permanent)
    -- add mining systems
    if onClient() and valid(Player()) then
        Player():registerCallback("onPreRenderHud", "onPreRenderHud")
    end
    gMatLevel, gMatRange, gMatAmount = getMiningSystemBonuses(seed, rarity, permanent)
    addAbsoluteBias(StatsBonuses.ScannerMaterialReach, gMatRange)

    -- add loot range
    addAbsoluteBias(StatsBonuses.LootCollectionRange, getLootCollectionRange(seed, rarity, permanent))

    -- transporter range
    local tpRange, fighterCargoPickup = getTransporterBonuses(seed, rarity, permanent)
    addAbsoluteBias(StatsBonuses.TransporterRange, tpRange)

    -- add turrets
    local turrets, pdcs, autos = getNumTurrets(seed, rarity, permanent)
    -- for higher quality, turrets will be added as arbitary instead of unarmed to give more flexibility
	-- especially since there are now multi-functional turrets for attack AND mining, but they count as
	-- armed
	if rarity.value > 3 then
		addMultiplyableBias(StatsBonuses.ArbitraryTurrets, turrets)
	elseif rarity.value == 3 then
		addMultiplyableBias(StatsBonuses.UnarmedTurrets, math.floor((turrets+1)/2))
		addMultiplyableBias(StatsBonuses.ArbitraryTurrets, math.floor(turrets/2))
	else
		addMultiplyableBias(StatsBonuses.UnarmedTurrets, turrets)
	end
	addMultiplyableBias(StatsBonuses.AutomaticTurrets, autos)
	
    -- add processing power
    if permanent then
        addMultiplyableBias(StatsBonuses.ExcessProcessingPowerSteps, 1)
    end
end

function onUninstalled(seed, rarity, permanent)
end

function getName(seed, rarity)
    return "AA-Tech Improved Civil Systems Coprocessor Upgrade MK ${mark}"%_t % {mark = toRomanLiterals(rarity.value + 2)}
end

function getBasicName()
    return "Civil Systems Coprocessor /* generic name for 'AA-Tech Improved Civil Systems Coprocessor Upgrade MK ${mark}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/mining_processor.png"
end

function getEnergy(seed, rarity, permanent)
    local energy = 0

    -- add mining system energy consumption
    local matLevel, matRange, matAmount = getMiningSystemBonuses(seed, rarity, true)
    energy = energy + (matRange * 0.0005 * matLevel * 1000 * 100) + (matAmount * 5 * 1000 * 100)

    -- add loot range energy consumption
    local lootRange = getLootCollectionRange(seed, rarity, true)
    energy = energy + lootRange * 20 * 1000 * 100 / (1.1 ^ rarity.value)

    -- transporter range energy consumption
    -- no energy change for transporter system

    -- add turret energy consumption
    local turrets, pdcs, autos = getNumTurrets(seed, rarity, permanent)
    energy = energy + turrets * 300 * 1000 * 100 / (1.2 ^ rarity.value)

    return energy
end

function getPrice(seed, rarity)
    local price = 0

    -- add mining system price
    local matLevel, matRange, matAmount = getMiningSystemBonuses(seed, rarity, true)
    price = price + (matLevel * 5000 + matAmount * 750 + matRange * 1.5) * 2.5 ^ rarity.value;

    -- add loot range price
    local lootRange = getLootCollectionRange(seed, rarity, true)
    price = price + lootRange * 500 * 2.5 ^ rarity.value

    -- transporter range price
    local tpRange, _ = getTransporterBonuses(seed, rarity, true)
    price = price + tpRange * 250 * 2.5 ^ rarity.value

    -- add turret prices
    local turrets, _, _ = getNumTurrets(seed, rarity, false)
    local _, _, autos = getNumTurrets(seed, rarity, true)
    price = price + (6000 * (turrets + autos * 0.5)) * 2.5 ^ rarity.value

    return price
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    local bonuses = {}

	-- material scanner
    local matLevel, matRange, matAmount = getMiningSystemBonuses(seed, rarity, permanent)
    matLevel = math.max(0, math.min(matLevel, NumMaterials() - 1))
    local matMaterial = Material(matLevel)
    local _, matBaseRange, matBaseAmount = getMiningSystemBonuses(seed, rarity, false)
    table.insert(texts, {ltext = "Material"%_t, rtext = matMaterial.name%_t, rcolor = matMaterial.color, icon = "data/textures/icons/metal-bar.png", boosted = permanent})
    table.insert(texts, {ltext = "Material Scanner Range"%_t, rtext = string.format("%g", round(matRange / 100, 2)), icon = "data/textures/icons/rss.png", boosted = permanent})
    table.insert(texts, {ltext = "Asteroids"%_t, rtext = string.format("%i", matAmount), icon = "data/textures/icons/rock.png", boosted = permanent})

    table.insert(bonuses, {ltext = "Material Level"%_t, rtext = "+1", icon = "data/textures/icons/metal-bar.png"})
    table.insert(bonuses, {ltext = "Material Scanner Range"%_t, rtext = string.format("+%g", round(matBaseRange * 0.5 / 100, 2)), icon = "data/textures/icons/rss.png"})
    table.insert(bonuses, {ltext = "Asteroids"%_t, rtext = string.format("+%i", round(matAmount * 0.5)), icon = "data/textures/icons/rock.png"})

	-- turrets
    local turrets, _ = getNumTurrets(seed, rarity, permanent)
    local _, pdcs, autos = getNumTurrets(seed, rarity, true)
	local bonusTurrets = getNumBonusTurrets(seed, rarity, true)
	
	if rarity.value > 3 then
		table.insert(texts, {ltext = "Arbitrary Turret Slots"%_t, rtext = "+" .. turrets, icon = "data/textures/icons/turret.png", boosted = permanent})
	elseif rarity.value == 3 then
		table.insert(texts, {ltext = "Unarmed Turret Slots"%_t, rtext = "+" .. math.floor((turrets+1)/2), icon = "data/textures/icons/turret.png", boosted = permanent})
		table.insert(texts, {ltext = "Arbitrary Turret Slots"%_t, rtext = "+" .. math.floor(turrets/2), icon = "data/textures/icons/turret.png", boosted = permanent})
	else
		table.insert(texts, {ltext = "Unarmed Turret Slots"%_t, rtext = "+" .. turrets, icon = "data/textures/icons/turret.png", boosted = permanent})
	end
	
    if permanent then
        if pdcs > 0 then
            table.insert(texts, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png", boosted = permanent})
        end

        if autos > 0 then
            table.insert(texts, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png", boosted = permanent})
        end
    else
		if rarity.value > 3 then
			table.insert(bonuses, {ltext = "Arbitrary Turret Slots"%_t, rtext = "+" .. bonusTurrets, icon = "data/textures/icons/turret.png", boosted = permanent})
		elseif rarity.value == 3 then
			table.insert(bonuses, {ltext = "Unarmed Turret Slots"%_t, rtext = "+" .. math.floor((bonusTurrets+1)/2), icon = "data/textures/icons/turret.png", boosted = permanent})
			table.insert(bonuses, {ltext = "Arbitrary Turret Slots"%_t, rtext = "+" .. math.floor(bonusTurrets/2), icon = "data/textures/icons/turret.png", boosted = permanent})
		else
			table.insert(bonuses, {ltext = "Unarmed Turret Slots"%_t, rtext = "+" .. bonusTurrets, icon = "data/textures/icons/turret.png", boosted = permanent})
        end

		if pdcs > 0 then
			table.insert(bonuses, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png"})
		end
		if autos > 0 then
			table.insert(bonuses, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png"})
		end
	end

    -- loot collection
    local lootRange = getLootCollectionRange(seed, rarity, permanent)
    local lootBaseRange = getLootCollectionRange(seed, rarity, false)
    table.insert(texts, {ltext = "Loot Collection Range"%_t, rtext = "+${distance} km"%_t % {distance = round(lootRange / 100, 2)}, icon = "data/textures/icons/tractor.png", boosted = permanent})
    table.insert(bonuses, {ltext = "Loot Collection Range"%_t, rtext = "+${distance} km"%_t % {distance = round(lootBaseRange * 2 / 100, 2)}, icon = "data/textures/icons/tractor.png"})

    -- transporter
    local tpRange, fighterCargoPickup = getTransporterBonuses(seed, rarity, permanent)
    if permanent then
        table.insert(texts, {ltext = "Docking Distance"%_t, rtext = "+${distance} km"%_t % {distance = tpRange / 100}, icon = "data/textures/icons/solar-system.png", boosted = permanent})
    else
        table.insert(bonuses, {ltext = "Docking Distance"%_t, rtext = "+${distance} km"%_t % {distance = tpRange / 100}, icon = "data/textures/icons/solar-system.png", boosted = permanent})
    end

    if permanent then
        table.insert(texts, {ltext = "Excess Processing Power"%_t, rtext = "+117.2k", icon = "data/textures/icons/star-cycle.png", boosted = permanent})
        table.insert(texts, {ltext = "Socket Equivalent"%_t, rtext = "+1", icon = "data/textures/icons/star-cycle.png", boosted = permanent})
    else
        table.insert(bonuses, {ltext = "Excess Processing Power"%_t, rtext = "+117.2k", icon = "data/textures/icons/star-cycle.png"})
        table.insert(bonuses, {ltext = "Socket Equivalent"%_t, rtext = "+1", icon = "data/textures/icons/star-cycle.png"})
    end

    local subdisprot = getSubspaceDistortionProtectionBonus(rarity)
    table.insert(texts, {ltext = "Subspace Distortion Protection"%_t, rtext = string.format("%+i", subdisprot), icon = "data/textures/icons/subspace-distortion-protection.png", boosted = permanent})

    return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    local lines = {}

    table.insert(lines, {ltext = "AA-Tech Civil Systems Coprocessor"%_t})
	table.insert(lines, {ltext = "Adds slots for unarmed turrets"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
	table.insert(lines, {ltext = "Unarmed turrets are replaced by arbitary slots in higher rarities"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(lines, {ltext = "Adds slots for auto-fire turrets"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(lines, {ltext = "Prevents damage from subspace distortions"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(lines, {ltext = "Displays amount of resources in objects"%_t, icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(lines, {ltext = "Highlights nearby mineable objects"%_t, icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})

--    table.insert(lines, {ltext = "", boosted = permanent})
	
    return lines
end

function getComparableValues(seed, rarity)
    local base = {}
    local bonus = {}

    local turrets = getNumTurrets(seed, rarity, false)
    local bonusTurrets = getNumBonusTurrets(seed, rarity, true)
    local _, pdcs, autos = getNumTurrets(seed, rarity, true)
	local aturrets, bonusArbTurrets = 0
	if rarity.value > 3 then
		aturrets = turrets
		turrets = 0
		bonusArbTurrets = bonusTurrets
		bonusTurrets = 0
	elseif rarity.value == 3 then
		aturrets = math.floor(turrets/2)
		turrets = math.floor((turrets+1)/2)
		bonusArbTurrets = math.floor(bonusTurrets/2)
		bonusTurrets = math.floor((bonusTurrets+1)/2)
	else
		aturrets = 0
		bonusArbTurrets = 0
	end
	
    table.insert(base, {name = "Unarmed Turret Slots"%_t, key = "armed_slots", value = turrets, comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Arbitrary Turret Slots"%_t, key = "arbitrary_slots", value = aturrets, comp = UpgradeComparison.MoreIsBetter})	
    table.insert(base, {name = "Defensive Turret Slots"%_t, key = "pdc_slots", value = 0, comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = 0, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Unarmed Turret Slots"%_t, key = "armed_slots", value = bonusTurrets, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Arbitrary Turret Slots"%_t, key = "arbitrary_slots", value = bonusArbTurrets, comp = UpgradeComparison.MoreIsBetter})	
    table.insert(bonus, {name = "Defensive Turret Slots"%_t, key = "pdc_slots", value = pdcs, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = autos, comp = UpgradeComparison.MoreIsBetter})

    local lootRange = getLootCollectionRange(seed, rarity, false)
    table.insert(base, {name = "Loot Collection Range"%_t, key = "range", value = round(lootRange / 100, 2), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Loot Collection Range"%_t, key = "range", value = round(lootRange * 0.5 / 100, 2), comp = UpgradeComparison.MoreIsBetter})

    local materialLevel, matRange, matAmount = getMiningSystemBonuses(seed, rarity, permanent)
    materialLevel = math.max(0, math.min(materialLevel, NumMaterials() - 1))
    local _, matBaseRange, matBaseAmount = getMiningSystemBonuses(seed, rarity, false)
    table.insert(base, {name = "Material"%_t, key = "material", value = materialLevel, comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Range"%_t, key = "range", value = round(matRange / 100, 2), comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Asteroids"%_t, key = "asteroids", value = round(matAmount), comp = UpgradeComparison.MoreIsBetter})

    table.insert(bonus, {name = "Material Level"%_t, key = "material", value = 1, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Range"%_t, key = "range", value = round(matBaseRange * 0.5 / 100, 2), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Asteroids"%_t, key = "asteroids", value = round(matAmount * 0.5), comp = UpgradeComparison.MoreIsBetter})

    local tpRange, fighterCargoPickup = getTransporterBonuses(seed, rarity, permanent)
    table.insert(bonus, {name = "Docking Distance"%_t, key = "docking_distance", value = tpRange / 100, comp = UpgradeComparison.MoreIsBetter})

    local subdisprot = getSubspaceDistortionProtectionBonus(rarity)
    table.insert(base, {name = "Subspace Distortion Protection"%_t, key = "subspace_distortion_protection", value = subdisprot, comp = UpgradeComparison.MoreIsBetter})

    return base, bonus
end

function getSubspaceDistortionProtectionBonus(rarity)
    return math.floor((rarity.value + 1) * 2.5);
end

function getSubspaceDistortionProtection()
    local rarity = getRarity()
    return getSubspaceDistortionProtectionBonus(rarity)
end