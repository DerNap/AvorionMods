package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

-- military turret-systems co-processor
    -- adds scanner reach for HP on enemies
    -- adds military combat slots turrets+defense turrets
    -- adds auto aim slots
    -- increases turret fire rate
    -- adds loot range extender
    -- TODO? damage booosters?

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

function getScannerBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local scanner = 1

    scanner = 25 -- base value, in percent
    -- add flat percentage based on rarity
    scanner = scanner + (rarity.value + 2) * 30 -- add +30% (worst rarity) to +210% (best rarity)
    scanner = scanner / 100

    if permanent then
        scanner = scanner * 3
    end

    return scanner
end

function getNumBonusTurrets(seed, rarity, permanent)
    if permanent then
        return math.max(1, (rarity.value + 1) * (rarity.value + 1) * (rarity.value + 1))
    end

    return 0
end

function getNumTurrets(seed, rarity, permanent)
    math.randomseed(seed)

    -- base of 1-6 base turrets
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
        autos = turrets + 10
    end

    return turrets, pdcs, autos
end


function onInstalled(seed, rarity, permanent)
    local turrets, pdcs, autos = getNumTurrets(seed, rarity, permanent)
    local scanner = getScannerBonuses(seed, rarity, permanent)

    -- add turrets
    addMultiplyableBias(StatsBonuses.ArmedTurrets, turrets)
    addMultiplyableBias(StatsBonuses.PointDefenseTurrets, pdcs)
    addMultiplyableBias(StatsBonuses.AutomaticTurrets, autos)

    -- add additional scanner range
    addBaseMultiplier(StatsBonuses.ScannerReach, scanner)

    -- add loot range
    addAbsoluteBias(StatsBonuses.LootCollectionRange, getLootCollectionRange(seed, rarity, permanent))

    -- add processing power
    if permanent then
        addMultiplyableBias(StatsBonuses.ExcessProcessingPowerSteps, 1)
    end

    if permanent then
        addBaseMultiplier(StatsBonuses.FireRate, 0.5)
    end
end

function onUninstalled(seed, rarity, permanent)
end

function getName(seed, rarity)
    return "AA-Tech Improved Combat Coprocessor Upgrade MK ${mark}"%_t % {mark = toRomanLiterals(rarity.value + 2)}
end

function getBasicName()
    return "Combat Coprocessor /* generic name for 'AA-Tech Improved Combat Coprocessor Upgrade MK ${mark}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/turret_processor.png"
end

function getEnergy(seed, rarity, permanent)
    local energy = 0

    -- add loot range energy consumption
    local lootRange = getLootCollectionRange(seed, rarity, true)
    energy = energy + lootRange * 20 * 1000 * 1000 / (1.1 ^ rarity.value)

    -- add scanner energy consumption
    local scanner = getScannerBonuses(seed, rarity, permanent)
    energy = energy + scanner * 150 * 1000 * 1000

    -- add turret energy consumption
    local turrets, pdcs, autos = getNumTurrets(seed, rarity, permanent)
    energy = energy + turrets * 100 * 1000 * 1000 / (1.3 ^ rarity.value)

    return energy
end

function getPrice(seed, rarity)
    local price = 0

    -- add loot range price
    local lootRange = getLootCollectionRange(seed, rarity, true)
    price = price + lootRange * 500 * 2.5 ^ (rarity.value + 1)

    -- add scanner price
    local scanner = getScannerBonuses(seed, rarity, permanent)
    price = price + scanner * 100 * 250 * 2.5 ^ (rarity.value + 1)

    -- add turret prices
    local turrets, _, _ = getNumTurrets(seed, rarity, false)
    local _, _, autos = getNumTurrets(seed, rarity, true)
    price = price + (6000 * (turrets + autos * 0.5)) * 1.5 ^ (rarity.value+1)

    return price
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    local bonuses = {}

    local turrets, _ = getNumTurrets(seed, rarity, permanent)
    local _, pdcs, autos = getNumTurrets(seed, rarity, true)
    table.insert(texts, {ltext = "Armed Turret Slots"%_t, rtext = "+" .. turrets, icon = "data/textures/icons/turret.png", boosted = permanent})
    if permanent then
        if pdcs > 0 then
            table.insert(texts, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png", boosted = permanent})
        end

        if autos > 0 then
            table.insert(texts, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png", boosted = permanent})
        end
    end

    table.insert(bonuses, {ltext = "Armed Turret Slots"%_t, rtext = "+" .. getNumBonusTurrets(seed, rarity, true), icon = "data/textures/icons/turret.png"})
    if pdcs > 0 then
        table.insert(bonuses, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png"})
    end
    if autos > 0 then
        table.insert(bonuses, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png"})
    end

    local scanner = getScannerBonuses(seed, rarity, permanent)
    local baseScanner = getScannerBonuses(seed, rarity, false)
    if scanner ~= 0 then
        table.insert(texts, {ltext = "Scanner Range"%_t, rtext = string.format("%+i%%", round(scanner * 100)), icon = "data/textures/icons/signal-range.png", boosted = permanent})
        table.insert(bonuses, {ltext = "Scanner Range"%_t, rtext = string.format("%+i%%", round(baseScanner * 100)), icon = "data/textures/icons/signal-range.png"})
    end

    local range = getLootCollectionRange(seed, rarity, permanent)
    local baseRange = getLootCollectionRange(seed, rarity, false)
    table.insert(texts, {ltext = "Loot Collection Range"%_t, rtext = "+${distance} km"%_t % {distance = round(range / 100, 2)}, icon = "data/textures/icons/tractor.png", boosted = permanent})
    table.insert(bonuses, {ltext = "Loot Collection Range"%_t, rtext = "+${distance} km"%_t % {distance = round(baseRange * 2 / 100, 2)}, icon = "data/textures/icons/tractor.png"})

    if permanent then
        table.insert(texts, {ltext = "Turret Fire Rate"%_t, rtext = "+${firerateboost}%"%_t % {firerateboost = 50}, icon = "data/textures/icons/bullets.png", boosted = permanent})
    else
        table.insert(bonuses, {ltext = "Turret Fire Rate"%_t, rtext = "+${firerateboost}%"%_t % {firerateboost = 50}, icon = "data/textures/icons/bullets.png"})
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
    local texts = {}

    table.insert(texts, {ltext = "AA-Tech Military Combat Coprocessor"%_t})
	table.insert(texts, {ltext = "Adds slots for armed turrets"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "Adds slots for auto-fire turrets"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "Prevents damage from subspace distortions"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
	--table.insert(texts, {ltext = "", boosted = permanent})

    return texts
end

--function secure()
--end

--function restore()
--end

function getComparableValues(seed, rarity)
    local base = {}
    local bonus = {}

    local scanner = getScannerBonuses(seed, rarity, false)
    table.insert(base, {name = "Scanner Range"%_t, key = "range", value = round(scanner * 100), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Scanner Range"%_t, key = "range", value = round(scanner * 100), comp = UpgradeComparison.MoreIsBetter})

    local turrets = getNumTurrets(seed, rarity, false)
    local bonusTurrets = getNumBonusTurrets(seed, rarity, true)
    local _, pdcs, autos = getNumTurrets(seed, rarity, true)
    table.insert(base, {name = "Armed Turret Slots"%_t, key = "armed_slots", value = turrets, comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Defensive Turret Slots"%_t, key = "pdc_slots", value = 0, comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = 0, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Armed Turret Slots"%_t, key = "armed_slots", value = bonusTurrets, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Defensive Turret Slots"%_t, key = "pdc_slots", value = pdcs, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = autos, comp = UpgradeComparison.MoreIsBetter})

    local lootRange = getLootCollectionRange(seed, rarity, false)
    table.insert(base, {name = "Loot Collection Range"%_t, key = "range", value = round(lootRange / 100, 2), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Loot Collection Range"%_t, key = "range", value = round(lootRange * 0.5 / 100, 2), comp = UpgradeComparison.MoreIsBetter})

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