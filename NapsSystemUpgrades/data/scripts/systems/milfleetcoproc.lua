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
	-- TODO? Add AI for fighters like xsotan module?
	-- TODO? Reduce training/build time for fighters like behemoth?

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true
--PermanentInstallationOnly = true
Unique = true

function getTransporterBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local range = ((rarity.value + 1) / 2 + 1) * 100

    local fighterCargoPickup = 0
    if rarity.value >= RarityType.Rare then
        -- fighterCargoPickup = 1
    end

    return range, fighterCargoPickup
end

function getScannerBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local scanner = 1
    local scannerBase = 1
    local scannerBonus = 0

    scanner = 25 -- base value, in percent
    -- add flat percentage based on rarity
    scanner = scanner + (rarity.value + 2) * 20 -- add +20% (worst rarity) to +140% (best rarity)
    scanner = scanner / 100

    scannerBase = scanner

    if permanent then
        scannerBonus = scanner * 1.5
        scanner = scanner + scannerBonus
    end

    return scanner, scannerBase, scannerBonus
end

function getNumSquads(seed, rarity, permanent)
    math.randomseed(seed)

    local base = math.max(1, math.ceil((rarity.value + 1) / 2))
    local bonus = base * 2
    local total = base + bonus
    
    if permanent then
        return total, bonus
    else
        return base, bonus
    end
end


function getNumTurrets(seed, rarity, permanent)
    math.randomseed(seed)
    -- base of (1-6)^2 base turrets
    -- since the size of the turrest increase with tech levels, being in e.g. 
    -- trinium area the size of the turrets is already like 4, just giving 4 slots 
    -- still would mean you can still only add one turret of that type
    -- therefore we multiply the turret slots with the rarity also
    local baseTurrets = math.max(1, (rarity.value + 1) * (rarity.value + 1))
    local pdcs = math.floor(baseTurrets / 2)
    if not permanent then
        pdcs = 0
    end

    return pdcs
end

function onInstalled(seed, rarity, permanent)
    -- additional fiter squads
    local squads, _ = getNumSquads(seed, rarity, permanent)
    addMultiplyableBias(StatsBonuses.FighterSquads, squads)

    -- add def turrets
    local pdcs = getNumTurrets(seed, rarity, permanent)
    if permanent then
        addMultiplyableBias(StatsBonuses.PointDefenseTurrets, pdcs)
    end

    -- transporter range
    local tpRange, fighterCargoPickup = getTransporterBonuses(seed, rarity, permanent)
    if permanent then
        addAbsoluteBias(StatsBonuses.TransporterRange, tpRange)
        addAbsoluteBias(StatsBonuses.FighterCargoPickup, fighterCargoPickup)
    end

    -- add additional scanner range
    local scanner, _, _ = getScannerBonuses(seed, rarity, permanent)
    addBaseMultiplier(StatsBonuses.ScannerReach, scanner)

    -- add processing power
    if permanent then
        addMultiplyableBias(StatsBonuses.ExcessProcessingPowerSteps, 1)
    end
end

--function onUninstalled(seed, rarity, permanent)
-- TODO: Bonusses are not taken away obviously. need to check where needed. otherwise, next restart will resolve the issue
--       maybe already sector change...
--end

function getName(seed, rarity)
    return "AA-Tech Fleet Coordinator Coprocessor MK ${mark}"%_t % {mark = toRomanLiterals(rarity.value + 2)}
end

function getBasicName()
    return "Fleet Coordinator Coprocessor /* generic name for 'AA-Tech Fleet Coordinator Coprocessor MK ${mark}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/fighter_processor.png"
end

function getEnergy(seed, rarity, permanent)
    local energy = 0

    local pdcs = getNumTurrets(seed, rarity, permanent)
    energy = energy + pdcs * 2 * 1000 * 1000 / (1.2 ^ rarity.value)

    local squads, _ = getNumSquads(seed, rarity, permanent)
    energy = energy + squads * 600 * 1000 * 1000 / (1.1 ^ rarity.value)

    -- no energy change for transporter system

    local scanner, _, _ = getScannerBonuses(seed, rarity, permanent)
    energy = energy + scanner * 550 * 1000 * 1000

    return energy
end

function getPrice(seed, rarity)
    local price = 0

    local squads, _ = getNumSquads(seed, rarity, true)
    price = price + 25000 * squads * 2.5 ^ rarity.value

    local tpRange, fighterCargoPickup = getTransporterBonuses(seed, rarity, true)
    price = price + tpRange * 250 * 2.5 ^ rarity.value

    local scanner, _, _ = getScannerBonuses(seed, rarity, permanent)
    price = price + scanner * 100 * 350 * 2.5 ^ rarity.value

    local pdcs = getNumTurrets(seed, rarity, true)
    price = price + 16000 * (pdcs * 0.5) * 2.5 ^ rarity.value

    price = price * 2.2
    return price     
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    local bonuses = {}

    -- additional squads
    local squads, squadBonus = getNumSquads(seed, rarity, permanent)
    table.insert(texts, {ltext = "Fighter Squadrons"%_t, rtext = "+" .. squads, icon = "data/textures/icons/fighter.png", boosted = permanent})
    if not permanent then
        table.insert(bonuses, {ltext = "Fighter Squadrons"%_t, rtext = "+" .. squadBonus, icon = "data/textures/icons/fighter.png"})
    end

    -- defense turrets
    local pdcs = getNumTurrets(seed, rarity, true)
    if permanent then
        if pdcs > 0 then
            table.insert(texts, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png", boosted = permanent})
        end
    else
        if pdcs > 0 then
            table.insert(bonuses, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png"})
        end
    end

    -- add scanner tooltips
    local scanner, scannerBase, scannerBonus = getScannerBonuses(seed, rarity, permanent)
    if scanner ~= 0 then
        table.insert(texts, {ltext = "Scanner Range"%_t, rtext = string.format("%+i%%", round(scanner * 100)), icon = "data/textures/icons/signal-range.png", boosted = permanent})
        if not permanent then
            table.insert(bonuses, {ltext = "Scanner Range"%_t, rtext = string.format("%+i%%", round(scannerBonus * 100)), icon = "data/textures/icons/signal-range.png"})
        end    
    end
    
    local toYesNo = function(line, value)
        if value then
            line.rtext = "Yes"%_t
            line.rcolor = ColorRGB(0.3, 1.0, 0.3)
        else
            line.rtext = "No"%_t
            line.rcolor = ColorRGB(1.0, 0.3, 0.3)
        end
    end
    
    -- transporter
    local tpRange, fighterCargoPickup = getTransporterBonuses(seed, rarity, permanent)
    if permanent then
        table.insert(texts, {ltext = "Docking Distance"%_t, rtext = "+${distance} km"%_t % {distance = tpRange / 100}, icon = "data/textures/icons/solar-system.png", boosted = permanent})
        table.insert(texts, {ltext = "Fighter Cargo Pickup"%_t, icon = "data/textures/icons/fighter.png"})
        toYesNo(texts[#texts], fighterCargoPickup ~= 0)
    else
        table.insert(bonuses, {ltext = "Docking Distance"%_t, rtext = "+${distance} km"%_t % {distance = tpRange / 100}, icon = "data/textures/icons/solar-system.png", boosted = permanent})
        table.insert(bonuses, {ltext = "Fighter Cargo Pickup"%_t, icon = "data/textures/icons/fighter.png"})
        toYesNo(bonuses[#bonuses], fighterCargoPickup ~= 0)
    end

    -- extra processing power
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

    table.insert(texts, {ltext = "AA-Tech Fleet Coordinator System Coprocessor"%_t})
	
    table.insert(texts, {ltext = "Slightly improves sensor systems"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "Adds transporter system with increased range"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "Controls additional fighter squadrons (10 max)"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
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

    local squads, squadBonus = getNumSquads(seed, rarity, false)
    table.insert(base, {name = "Fighter Squadrons"%_t, key = "fighter_squads", value = squads, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Fighter Squadrons"%_t, key = "fighter_squads", value = squadBonus, comp = UpgradeComparison.MoreIsBetter})

    local pdcs = getNumTurrets(seed, rarity, true)
    table.insert(base, {name = "Defensive Turret Slots"%_t, key = "pdc_slots", value = 0, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Defensive Turret Slots"%_t, key = "pdc_slots", value = pdcs, comp = UpgradeComparison.MoreIsBetter})

   -- add scanner compare values
   local scanner, scannerBase, scannerBonus = getScannerBonuses(seed, rarity, false)
   table.insert(base, {name = "Scanner Range"%_t, key = "range", value = round(scannerBase * 100), comp = UpgradeComparison.MoreIsBetter})
   table.insert(bonus, {name = "Scanner Range"%_t, key = "range", value = round(scannerBonus * 100), comp = UpgradeComparison.MoreIsBetter})

    local tpRange, fighterCargoPickup = getTransporterBonuses(seed, rarity, true)
    table.insert(bonus, {name = "Docking Distance"%_t, key = "docking_distance", value = tpRange / 100, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Fighter Cargo Pickup"%_t, key = "fighter_cargo_pickup", value = fighterCargoPickup, comp = UpgradeComparison.MoreIsBetter})

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