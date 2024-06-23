package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true

function getNumDefenseWeapons(seed, rarity, permanent)
    math.randomseed(seed)

    if permanent then
        if rarity.value <= 2 then
            return (rarity.value + 2) * 5 + getInt(0, 3)
        else
            return rarity.value * 10 + getInt(0, 8)
        end
    end

    return 0
end

function onInstalled(seed, rarity, permanent)
    local numWeapons = getNumDefenseWeapons(seed, rarity, permanent)

    addAbsoluteBias(StatsBonuses.DefenseWeapons, numWeapons)
end

function onUninstalled(seed, rarity, permanent)

end

function getName(seed, rarity)
    return "AA-Tech Coordinated Defense Weaponsystems Coprocessor Upgrade MK ${mark}"%_t % {mark = toRomanLiterals(rarity.value + 2)}
end

function getBasicName()
    return "Coordinated Defense Weaponsystems Coprocessor /* generic name for 'AA-Tech Coordinated Defense Weaponsystems Coprocessor Upgrade MK ${mark}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/defense_processor.png"
end

function getEnergy(seed, rarity, permanent)
    local energy = 0

    -- add defense system energy consumption
    local defsys = getNumDefenseWeapons(seed, rarity, true)
	energy = energy + defsys * 75 * 1000 * 1000 / (1.2 ^ rarity.value)
    
	return energy
end

function getPrice(seed, rarity)
    local price = 0

    -- add defense system price
    local defsys = 500 * getNumDefenseWeapons(seed, rarity, true)
    price = price + defsys * 2 ^ rarity.value
	
	return price
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    local bonuses = {}


    local text = 
	{ltext = "Internal Defense Weapons"%_t, rtext = "+" .. getNumDefenseWeapons(seed, rarity, true), boosted = permanent, icon = "data/textures/icons/shotgun.png"}
    if permanent then
		table.insert(texts, {ltext = "Internal Defense Weapons"%_t, rtext = "+" .. getNumDefenseWeapons(seed, rarity, true), boosted = permanent, icon = "data/textures/icons/shotgun.png"})
		table.insert(bonuses, {ltext = "Internal Defense Weapons"%_t, rtext = "+" .. getNumDefenseWeapons(seed, rarity, true), boosted = permanent, icon = "data/textures/icons/shotgun.png"})
    else
		table.insert(bonuses, {ltext = "Internal Defense Weapons"%_t, rtext = "+" .. getNumDefenseWeapons(seed, rarity, true), boosted = permanent, icon = "data/textures/icons/shotgun.png"})
    end
	
	return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    local texts = {}

    table.insert(texts, {ltext = "AA-Tech Military Combat Coprocessor"%_t})
	table.insert(texts, {ltext = "Adds slots for armed turrets"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
	
        --{ltext = "Internal Defense Weapons System"%_t, rtext = "", icon = ""},
        --{ltext = "Adds internal defense weapons to fight off enemy boarders"%_t, rtext = "", icon = ""}
    --}
end

function getComparableValues(seed, rarity)
    local defense = getNumDefenseWeapons(seed, rarity, true)

    return
    {
        {name = "Internal Defense Weapons"%_t, key = "defense_weapons", value = defense, comp = UpgradeComparison.MoreIsBetter},
    },
    {
        {name = "Internal Defense Weapons"%_t, key = "defense_weapons", value = defense, comp = UpgradeComparison.MoreIsBetter},
    }
end
