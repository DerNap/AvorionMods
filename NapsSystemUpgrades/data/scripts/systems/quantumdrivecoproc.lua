package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true
Unique = true

-- dynamic stats
local rechargeReady = 0
local recharging = 0
local rechargeSpeed = 0

-- static stats
rechargeDelay = 300
rechargeTime = 5
rechargeAmount = 0.60

function getUpdateInterval()
    return 0.25
end

function updateServer(timePassed)
    rechargeReady = math.max(0, rechargeReady - timePassed)

    if recharging > 0 then
        recharging = recharging - timePassed
        Entity():healShield(rechargeSpeed * timePassed)
    end

end

function startCharging()

    if rechargeReady == 0 then
        local shield = Entity().shieldMaxDurability
        if shield > 0 then
            rechargeReady = rechargeDelay
            recharging = rechargeTime
            rechargeSpeed = shield * rechargeAmount / rechargeTime
        end
    end

end



function getGeneratorBonuses(seed, rarity, permanent)
	math.randomseed(seed)

    local generated = (rarity.value + 1) * 0.5
	local recharged = (rarity.value + 1) * 0.125

	if not permanent then
		generated = generated * 0.2
		recharged = recharged * 0.2
	end

    return 1.0 + generated, 1.0 + recharged
end

function getSpeedBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local energy = (6.0 - (rarity.value + 1)) * 8
	if energy <= 0 then
		energy = 1
	end
    energy = energy / 100

	local afactor = 6 -- base value, in percent
    -- add flat percentage based on rarity
    afactor = afactor + (rarity.value + 1) * 5 -- add 0% (worst rarity) to +30% (best rarity)

    -- add randomized percentage, span is based on rarity
    afactor = afactor + math.random() * ((rarity.value + 1) * 4) -- add random value between 0% (worst rarity) and +24% (best rarity)
    afactor = afactor * 0.8
    afactor = afactor / 100

    if permanent then
        afactor = afactor * 1.5
    end

    return energy, afactor
end

function getShieldBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local durability = 5000 -- add base 5.000 hp to shield
    durability = durability + (rarity.value + 1) * 10000 -- add 0 hp (worst rarity) to 65.000 hp (best rarity) to shield
    durability = durability + round((math.random(0, 5000)) / 500) * 500 -- add random 0 hp to 6000 hp to add some variability

    local recharge = 4 -- base value, in percent
    -- add flat percentage based on rarity
	-- adds 5% (worst rarity) to +40% (best rarity)
    recharge = (rarity.value+1) *  (rarity.value+1) 
    recharge = recharge / 100

    local emergencyRecharge = 0

    if permanent then
        durability = durability * 3
        recharge = recharge * 1.5

        if rarity.value >= 2 then
            emergencyRecharge = 1
        end
    end

    return durability, recharge, emergencyRecharge
end

function onInstalled(seed, rarity, permanent)

	-- Generator bonus
	local genEnergy, genCharge = getGeneratorBonuses(seed, rarity, permanent)
    addBaseMultiplier(StatsBonuses.GeneratedEnergy, genEnergy)
    addBaseMultiplier(StatsBonuses.BatteryRecharge, genCharge)
	
	-- Velocity bonus
	local veloEnergy, afactor = getSpeedBonuses(seed, rarity, permanent)
	if rarity.value > 0 then 
		addAbsoluteBias(StatsBonuses.Velocity, 10000000.0)
		addBaseMultiplier(StatsBonuses.GeneratedEnergy, -veloEnergy)	
	end
	addBaseMultiplier(StatsBonuses.Acceleration, afactor)
	
	-- Shield bonus
	local _, shieldRecharge, shieldEmergencyRecharge = getShieldBonuses(seed, rarity, permanent)
	
	--addMultiplyableBias(StatsBonuses.ShieldDurability, durability)
    addBaseMultiplier(StatsBonuses.ShieldRecharge, shieldRecharge)

    if emergencyRecharge == 1 then
        Entity():registerCallback("onShieldDeactivate", "startCharging")
    else
        -- delete this function so it won't be called by the game
        -- -> saves performance
        updateServer = nil
    end
end


function onUninstalled(seed, rarity, permanent)
end

function getName(seed, rarity)
    return "AA-Tech Quantum Engine Coprocessor Upgrade MK ${mark}"%_t % {mark = toRomanLiterals(rarity.value + 2)}
end

function getBasicName()
    return "Quantum Engine Coprocessor /* generic name for 'AA-Tech Quantum Engine Coprocessor Upgrade MK ${mark}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/thruster_processor.png"
end

function getPrice(seed, rarity)
    return 10000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
	local bonuses = {}
	
	-- Generator bonus
	if permanent then
		local genEnergy, genCharge = getGeneratorBonuses(seed, rarity, permanent)
		table.insert(texts, {ltext = "Generated Energy"%_t, rtext = string.format("%+i%%", genEnergy * 100), icon = "data/textures/icons/electric.png", boosted = permanent})
		table.insert(texts, {ltext = "Recharge Rate"%_t, rtext = string.format("%+i%%", genCharge * 100), icon = "data/textures/icons/power-unit.png", boosted = permanent})
	else
		local genEnergy, genCharge = getGeneratorBonuses(seed, rarity, true)
		table.insert(texts, {ltext = "Generated Energy"%_t, rtext = string.format("%+i%%", genEnergy * 0.2 * 100), icon = "data/textures/icons/electric.png", boosted = permanent})
		table.insert(texts, {ltext = "Recharge Rate"%_t, rtext = string.format("%+i%%", genCharge * 0.2 * 100), icon = "data/textures/icons/power-unit.png", boosted = permanent})

		table.insert(bonuses, {ltext = "Generated Energy"%_t, rtext = string.format("%+i%%", (genEnergy - genEnergy * 0.2) * 100), icon = "data/textures/icons/electric.png", boosted = permanent})
		table.insert(bonuses, {ltext = "Recharge Rate"%_t, rtext = string.format("%+i%%", (genEnergy - genCharge * 0.2) * 100), icon = "data/textures/icons/power-unit.png", boosted = permanent})
	end

	-- Velocity/Acceleration bonus
	local veloEnergy, afactor = getSpeedBonuses(seed, rarity, permanent)
	local _, afactorBase = getSpeedBonuses(seed, rarity, false)
	local _, afactorPerm = getSpeedBonuses(seed, rarity, true)

	if rarity.value > 0 then 
		table.insert(texts, {ltext = "Velocity"%_t, rtext = "+?", icon = "data/textures/icons/speedometer.png", boosted = permanent})
		table.insert(texts, {ltext = "Generated Energy"%_t, rtext = string.format("%+i%%", round(-veloEnergy * 100)), icon = "data/textures/icons/power-lightning.png", boosted = permanent})
	end
	if afactor ~= 0 then
        table.insert(texts, {ltext = "Acceleration"%_t, rtext = string.format("%+i%%", round(afactor * 100)), icon = "data/textures/icons/acceleration.png", boosted = permanent})
        table.insert(bonuses, {ltext = "Acceleration"%_t, rtext = string.format("%+i%%", round((afactorPerm - afactorBase)*100)), icon = "data/textures/icons/acceleration.png"})
    end

	-- Shield bonus	
	local _, shieldRechargePerm, shieldEmergencyRechargePerm = getShieldBonuses(seed, rarity, true)
	local _, shieldRechargeBase, shieldEmergencyRechargeBase = getShieldBonuses(seed, rarity, false)
    if permanent then
        table.insert(texts, {ltext = "Shield Recharge Rate"%_t, rtext = string.format("%+i%%", round(shieldRechargePerm * 100)), icon = "data/textures/icons/shield-charge.png", boosted = permanent})
		if shieldEmergencyRechargePerm ~= 0 then
			table.insert(texts, {ltext = "Emergency Recharge"%_t, rtext = string.format("%i%%", round(rechargeAmount * 100)), icon = "data/textures/icons/shield-charge.png", boosted = permanent})
		end
	else
		if shieldEmergencyRechargePerm > 0 then
			table.insert(texts, {ltext = "Shield Recharge Rate"%_t, rtext = string.format("%+i%%", round(shieldRechargeBase * 100)), icon = "data/textures/icons/shield-charge.png", boosted = permanent})
			table.insert(bonuses, {ltext = "Shield Recharge Rate"%_t, rtext = string.format("%+i%%", round((shieldRechargePerm-shieldRechargeBase) * 100)), icon = "data/textures/icons/shield-charge.png"})
			if shieldEmergencyRechargeBase ~= shieldEmergencyRechargePerm then
				table.insert(bonuses, {ltext = "Recharge Upon Depletion"%_t, rtext = string.format("%i%%", round(rechargeAmount * 100)), icon = "data/textures/icons/shield-charge.png", })
			end
		end
    end

    local subdisprot = getSubspaceDistortionProtectionBonus(rarity)
    table.insert(texts, {ltext = "Subspace Distortion Protection"%_t, rtext = string.format("%+i", subdisprot), icon = "data/textures/icons/subspace-distortion-protection.png", boosted = permanent})
    
	return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    local texts = {}

    table.insert(texts, {ltext = "AA-Tech Improved Quantum Engine Coprocessor"%_t})
    table.insert(texts, {ltext = "Replaces traditional vessel engine with a quantum drive"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "The excess power is used to improve shield recharge and vessel acceleration"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
	table.insert(texts, {ltext = "Prevents damage from subspace distortions"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "", boosted = permanent})
	table.insert(texts, {ltext = "Bypasses the velocity security control, /* continues with 'but leaks energy from the generators.' */" .. " " .. "but leaks energy from the generators. /* continued from 'Bypasses the velocity security control,' */"%_t})

    return texts
end

function getComparableValues(seed, rarity)
    local base = {}
    local bonus = {}


	-- Generator bonus
	local genEnergy, genCharge = getGeneratorBonuses(seed, rarity, false)
	local genEnergyPerm, genChargePerm = getGeneratorBonuses(seed, rarity, true)
	local genEnergyBonus =genEnergyPerm - genEnergy
	local genChargeBonus = genChargePerm - genCharge

    if energy ~= 0 or genEnergyBonus ~= 0 then
        table.insert(base, {name = "Generated Energy"%_t, key = "generated_energy", value = round(genEnergy * 100), comp = UpgradeComparison.MoreIsBetter})
        table.insert(bonus, {name = "Generated Energy"%_t, key = "generated_energy", value = round(genEnergyBonus * 100), comp = UpgradeComparison.MoreIsBetter})
    end

    if charge ~= 0 or genChargeBonus ~= 0 then
        table.insert(base, {name = "Recharge Rate"%_t, key = "recharge_rate", value = round(genCharge * 100), comp = UpgradeComparison.MoreIsBetter})
        table.insert(bonus, {name = "Recharge Rate"%_t, key = "recharge_rate", value = round(genChargeBonus * 100), comp = UpgradeComparison.MoreIsBetter})
    end

	-- Velocity/Acceleration bonus
	local veloEnergy, afactor = getSpeedBonuses(seed, rarity, false)
	local veloEnergyPerm, afactorPerm = getSpeedBonuses(seed, rarity, true)
	local veloEnergyBonus = veloEnergyPerm - veloEnergy
	local afactorBonus = afactorPerm - afactor

	table.insert(base, {name = "Generated Energy"%_t, key = "generated_energy", value = round(-veloEnergy * 100), comp = UpgradeComparison.MoreIsBetter})
	table.insert(bonus, {name = "Generated Energy"%_t, key = "generated_energy", value = round(-veloEnergyBonus * 100), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Velocity"%_t, key = "velocity", value = 1, comp = UpgradeComparison.MoreIsBetter})
    if afactor ~= 0 or afactorBonus ~= 0 then
        table.insert(base, {name = "Acceleration"%_t, key = "acceleration", value = round(afactor * 100), comp = UpgradeComparison.MoreIsBetter})
        table.insert(bonus, {name = "Acceleration"%_t, key = "acceleration", value = round(afactorBonus * 100), comp = UpgradeComparison.MoreIsBetter})
    end
	
	-- Shield bonus	
	local _, shieldRechargeBase, shieldEmergencyRechargeBase = getShieldBonuses(seed, rarity, false)
	local _, shieldRechargePerm, shieldEmergencyRechargePerm = getShieldBonuses(seed, rarity, true)
	local shieldRechargeBonus = shieldRechargePerm - shieldRechargeBase
	local shieldEmergencyRechargeBonus = shieldEmergencyRechargePerm - shieldEmergencyRechargeBase

    table.insert(base, {name = "Shield Recharge Rate"%_t, key = "recharge_rate", value = round(shieldRechargeBase * 100), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Shield Recharge Rate"%_t, key = "recharge_rate", value = round(shieldRechargeBonus * 100), comp = UpgradeComparison.MoreIsBetter})

    table.insert(base, {name = "Recharge Upon Depletion"%_t, key = "recharge_on_depletion", value = shieldEmergencyRechargeBase, comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Recharge Upon Depletion"%_t, key = "recharge_on_depletion", value = shieldEmergencyRechargeBonus, comp = UpgradeComparison.MoreIsBetter})

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