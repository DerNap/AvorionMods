package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

-- bridge assistance co-proc -- intelligence
    -- valuables detector
    -- adds scanner reach for HP on enemies
    -- long distance radar/scanner
    -- add pitch/roll/yaw boost
    -- hyperspace cooldown

local interestingEntities = {}
local baseCooldown = 10.0
local cooldown = 40.0
local remainingCooldown = 0.0 -- no initial cooldown

local highlightDuration = 120.0
local activeTime = nil
local highlightRange = 0

local permanentlyInstalled = false
local tooltipName = "Object Detection"%_t

local orig_thrusters_basePitch = -1
local orig_thrusters_baseRoll = -1
local orig_thrusters_baseYaw = -1

local highlightColor = ColorRGB(1.0, 1.0, 1.0)

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true
--PermanentInstallationOnly = true
Unique = true

function getHyperspaceBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local cdfactor = 0
    local cdbias = 0

    cdfactor = 5 -- base value, in percent

    -- add flat percentage based on rarity
    cdfactor = cdfactor + (rarity.value + 1) * 2.5 -- add 0% (worst rarity) to +15% (best rarity)

    if permanent then
        -- add extra percentage, span is based on rarity
        cdfactor = cdfactor * 2
    end
    cdfactor = -cdfactor / 100

    return cdfactor
end


function getThrusterBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local thrustboost = 0
    if permanent then
        thrustboost = ((((rarity.value + 2)) / 7) * 2.00) + (((rarity.value + 4) * 10) / 100)
    end

    return thrustboost
end

function getRadarBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local radar = 0
    local hiddenRadar = 0

    radar = math.max(0, getInt(rarity.value, rarity.value * 2.0)) + 1
    hiddenRadar = math.max(0, getInt(rarity.value, rarity.value * 1.5)) + 1

    -- probability for both of them being used
    -- when rarity.value >= 4, always both
    -- when rarity.value <= 0 always only one
    local probability = math.max(0, rarity.value * 0.25)
    if math.random() > probability then
        -- only 1 will be used
        if math.random() < 0.5 then
            radar = 0
        else
            hiddenRadar = 0
        end
    end

    if permanent then
        radar = radar * 1.5
        hiddenRadar = hiddenRadar * 2
    end

    return round(radar), round(hiddenRadar)
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

function getValueableScannerBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local highlightRange = 0
    local cooldown = baseCooldown

    if rarity.value >= RarityType.Legendary then
        if permanent then
            highlightRange = 8500 + math.random() * 1000
        end

        cooldown = baseCooldown

    elseif rarity.value >= RarityType.Exotic then
        if permanent then
            highlightRange = 7000 + math.random() * 1000
        end

        cooldown = baseCooldown

    elseif rarity.value >= RarityType.Exceptional then
        if permanent then
            highlightRange = 5500 + math.random() * 1000
        end

        cooldown = baseCooldown

    elseif rarity.value >= RarityType.Rare then
        if permanent then
            highlightRange = 4000 + math.random() * 1000
        end

        cooldown = baseCooldown

    elseif rarity.value >= RarityType.Uncommon then
        if permanent then
            highlightRange = 2500 + math.random() * 1000
        end

        cooldown = baseCooldown + highlightDuration * 0.5

    elseif rarity.value >= RarityType.Common then
        if permanent then
            highlightRange = 1000 + math.random() * 1000
        end

        cooldown = baseCooldown + highlightDuration

    elseif rarity.value >= RarityType.Petty then
        highlightRange = 0
        cooldown = baseCooldown + highlightDuration * 3
    end
	
	highlightRange = highlightRange * (rarity.value+2)
	--highlightRange = highlightRange * (((rarity.value+1)/2)+1)
	cooldown = math.floor(cooldown / 2)
	
    return highlightRange, cooldown
end

function onInstalled(seed, rarity, permanent)
    -- valuable scanner range will be added in onClient()
	if onClient() then
		local player = Player()
        if valid(player) then
            player:registerCallback("onPreRenderHud", "onPreRenderHud")
            player:registerCallback("onShipChanged", "sendMessageForValuables")
        end
	end

    highlightRange, cooldown = getValueableScannerBonuses(seed, rarity, permanent)
    permanentlyInstalled = permanent

    if onClient() then
        sendMessageForValuables()
    end

    -- add additional scanner range
    local scanner, _, _ = getScannerBonuses(seed, rarity, permanent)
    addBaseMultiplier(StatsBonuses.ScannerReach, scanner)

    -- add additional radar range
    local radar, hiddenRadar = getRadarBonuses(seed, rarity, permanent)
    addMultiplyableBias(StatsBonuses.RadarReach, radar)
    addMultiplyableBias(StatsBonuses.HiddenSectorRadarReach, hiddenRadar)

    -- thruster boost
    local thrusterboost = getThrusterBonuses(seed, rarity, permanent)
	if thrusterboost ~= 0 then
        local thrusters = Thrusters()
		if thrusters ~= nil then
			orig_thrusters_basePitch = thrusters.basePitch
			orig_thrusters_baseRoll = thrusters.baseRoll
			orig_thrusters_baseYaw = thrusters.baseYaw
			thrusters.fixedStats = true
			thrusters.basePitch = thrusterboost
			thrusters.baseRoll = thrusterboost
			thrusters.baseYaw = thrusterboost
		end
	end

    -- add processing power
    if permanent then
        addMultiplyableBias(StatsBonuses.ExcessProcessingPowerSteps, 1)
    end

    -- add hyperspace cooldown
    local cdfactor = getHyperspaceBonuses(seed, rarity, permanent)
    addBaseMultiplier(StatsBonuses.HyperspaceCooldown, cdfactor)
end

function onUninstalled(seed, rarity, permanent)
    local thrusters = Thrusters()
	if thrusters ~= nil then
		if orig_thrusters_basePitch ~= -1 then
			thrusters.basePitch = orig_thrusters_basePitch
		end
		if orig_thrusters_baseRoll ~= -1 then
			thrusters.baseRoll = orig_thrusters_baseRoll
		end
		if orig_thrusters_baseYaw ~= -1 then
			thrusters.baseYaw = orig_thrusters_baseYaw
		end
		thrusters.fixedStats = false
	end
end


function updateClient(timeStep)
    if remainingCooldown > 0.0 then
        remainingCooldown = math.max(0, remainingCooldown - timeStep)
    end

    if activeTime then
        activeTime = activeTime - timeStep
        if activeTime <= 0.0 then
            activeTime = nil
            interestingEntities = {}
        end
    end
    sendMessageForValuables()
end

function onDetectorButtonPressed()
    -- set cooldown and activeTime on both client and server
    remainingCooldown = cooldown
    activeTime = highlightDuration

    interestingEntities = collectHighlightableObjects()

    playSound("scifi-sonar", SoundType.UI, 0.5)

    -- notify player that entities were found
    if tablelength(interestingEntities) > 0 then
        deferredCallback(3, "showNotification", "Valuable objects detected."%_t)
    else
        deferredCallback(3, "showNotification", "Nothing found here."%_t)
    end

    interestingEntities = filterHighlightableObjects(interestingEntities)
end

function showNotification(text)
    displayChatMessage(text, "Object Detector"%_t, ChatMessageType.Information)
end

function onSectorChanged()
    if onClient() then
        sendMessageForValuables()
    end
end

function interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    if not player then return false, "" end

    local craftId = player.craftIndex
    if not craftId then return false, "" end

    if craftId ~= Entity().index then
        return false, ""
    end

    if remainingCooldown > 0.0 then
        return false, ""
    end

    return true
end

function initUI()
    ScriptUI():registerInteraction(tooltipName, "onDetectorButtonPressed", -1);
end

function getUIButtonCooldown()
    local tooltipText = ""

    if remainingCooldown > 0 then
        local duration = math.max(0.0, remainingCooldown)
        local minutes = math.floor(duration / 60)
        local seconds = duration - minutes * 60
        tooltipText = tooltipName .. ": " .. string.format("%02d:%02d", math.max(0, minutes), math.max(0.01, seconds))
    else
        tooltipText = tooltipName
    end

    return remainingCooldown / cooldown, tooltipText
end

function collectHighlightableObjects()
    local player = Player()
    if not valid(player) then return end

    local self = Entity()
    if player.craftIndex ~= self.index then return end

    local objects = {}

    -- normal entities
    for _, entity in pairs({Sector():getEntitiesByScriptValue("valuable_object")}) do
        local value = entity:getValue("highlight_color") or entity:getValue("valuable_object")

        -- docked objects are not available for the player
        if not entity.dockingParent then
            if type(value) == "string" then
                objects[entity.id] = {entity = entity, color = Color(value)}
            else
                objects[entity.id] = {entity = entity, color = Rarity(value).color}
            end
        end
    end

    -- wreckages with black boxes
    -- black box wreckages are always tagged as Petty
    for _, entity in pairs({Sector():getEntitiesByScriptValue("blackbox_wreckage")}) do
        -- docked objects are not available for the player
        if not entity.dockingParent then
            objects[entity.id] = {entity = entity, color = ColorRGB(0.3, 0.9, 0.9)}
        end
    end

    return objects
end

function filterHighlightableObjects(objects)
    -- no need to sort out if none of the found entities will be marked
    if highlightRange == 0 then
        return {}
    end

    -- remove all entities that are too far away and shouldn't be marked
    local range2 = highlightRange * highlightRange
    local center = Entity().translationf
    for id, entry in pairs(objects) do
        if valid(entry.entity) then
            if distance2(center, entry.entity.translationf) > range2 then
                objects[id] = nil
            end
        end
    end

    return objects
end

local automaticMessageDisplayed
function sendMessageForValuables()
    if not permanentlyInstalled then return end

    local player = Player()
    if not valid(player) then return end

    local self = Entity()
    if player.craftIndex ~= self.index then return end

    local objects = collectHighlightableObjects()
    if tablelength(objects) == 0 then
        removeShipProblem("ValuablesDetector", self.id)
    end    
    if automaticMessageDisplayed then return end

    -- notify player that entities were found
    if tablelength(objects) > 0 then
        displayChatMessage("Valuable objects detected."%_t, "Object Detector"%_t, ChatMessageType.Information)
        addShipProblem("ValuablesDetector", self.id, "Valuable objects detected."%_t, "data/textures/icons/valuables-detected.png", highlightColor)
        automaticMessageDisplayed = true
    end
end

function onPreRenderHud()
    if not highlightRange or highlightRange == 0 then return end
    if not permanentlyInstalled then return end

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local self = Entity()
    if player.craftIndex ~= self.index then return end

    if tablelength(interestingEntities) == 0 then return end

    -- detect all objects in range
    local renderer = UIRenderer()

    local range = lerp(activeTime, highlightDuration, highlightDuration - 5, 0, 100000, true)
    local range2 = range * range
    local center = self.translationf

    local timeFactor = 1.25 * math.sin(activeTime * 10)
    for id, object in pairs(interestingEntities) do
        if not valid(object.entity) then
            interestingEntities[id] = nil
            goto continue
        end

        if distance2(object.entity.translationf, center) < range2 then
            local _, size = renderer:calculateEntityTargeter(object.entity)
            local c = lerp(math.sin(activeTime * 10), 0, 1.5, vec3(object.color.r, object.color.g, object.color.b), vec3(1, 1, 1))
            renderer:renderEntityTargeter(object.entity, ColorRGB(c.x, c.y, c.z), size + 1.5 * timeFactor);
        end

        ::continue::
    end

    renderer:display()
end


function getName(seed, rarity)
    return "AA-Tech Bridge Intelligence Assistance Coprocessor Upgrade MK ${mark}"%_t % {mark = toRomanLiterals(rarity.value + 2)}
end

function getBasicName()
    return "Bridge Intelligence Assistance Coprocessor /* generic name for 'AA-Tech Bridge Intelligence Assistance Coprocessor Upgrade MK ${mark}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/scanner_processor_magnifying_glass.png"
end

function getControlAction()
    return ControlAction.ScriptQuickAccess2
end

function getEnergy(seed, rarity, permanent)
    local energy = 0

    -- add scanner energy consumption
    local scanner, _, _ = getScannerBonuses(seed, rarity, permanent)
    energy = energy + scanner * 550 * 1000 * 1000

    -- add radar energy consumption
    local radar, hiddenRadar = getRadarBonuses(seed, rarity, permanent)
    energy = energy + radar * 75 * 1000 * 1000 + hiddenRadar * 150 * 1000 * 1000

    -- add valuable scanner energy consumption
    local highlightRange = getValueableScannerBonuses(seed, rarity)
    highlightRange = math.min(highlightRange, 1500)
    energy = energy + (highlightRange * 0.0005 * 1000 * 1000 * 1000)
    
    -- add thruster boost energy consumption
    local thrusterboost = getThrusterBonuses(seed, rarity, permanent)
    energy = energy + 3 * thrusterboost * 1000 * 1000 * 123

    -- add hyperspace cooldown energy consumption
    local cdfactor = getHyperspaceBonuses(seed, rarity, permanent)
    energy = energy + math.abs(cdfactor) * 2.5 * 1000 * 1000 * 1000

    return energy
end

function getPrice(seed, rarity)
    local price = 0

    -- add scanner price
    local scanner, _, _ = getScannerBonuses(seed, rarity, true)
    price = price + scanner * 100 * 250 * 2.5 ^ (rarity.value + 1)

    -- add radar price
    local radar, hiddenRadar = getRadarBonuses(seed, rarity)
    price = price + (radar * 3000 + hiddenRadar * 5000) * 2.5 ^ (rarity.value + 1)
    
    -- add valuable scanner price
    local range = getValueableScannerBonuses(seed, rarity)
    range = math.min(range, 1500)
    price = price + ((rarity.value + 2) * 750 + range * 1.5)  * 2.5 ^ (rarity.value + 1)

    -- add thruster boost price
    local thrusterboost = getThrusterBonuses(seed, rarity, true)
    price = price + (rarity.value + 2) * 750 * thrusterboost * 5000 * 2.5 ^ (rarity.value + 1)

    -- add hyperspace cooldown energy price
    local cdfactor = getHyperspaceBonuses(seed, rarity, true)
    price = price + math.abs(cdfactor) * 100 * 350 * 2.5 ^ rarity.value

    return price
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    local bonuses = {}

    -- add scanner tooltips
    local scanner, scannerBase, scannerBonus = getScannerBonuses(seed, rarity, permanent)
    if scanner ~= 0 then
        table.insert(texts, {ltext = "Scanner Range"%_t, rtext = string.format("%+i%%", round(scanner * 100)), icon = "data/textures/icons/signal-range.png", boosted = permanent})
        if not permanent then
            table.insert(bonuses, {ltext = "Scanner Range"%_t, rtext = string.format("%+i%%", round(scannerBonus * 100)), icon = "data/textures/icons/signal-range.png"})
        end    
    end

    -- add radar tooltips
    local radar, hiddenRadar = getRadarBonuses(seed, rarity, permanent)
    local baseRadar, baseHidden = getRadarBonuses(seed, rarity, false)
    local bonusRadar, bonusHiddenRadar = getRadarBonuses(seed, rarity, true)
    bonusRadar = bonusRadar - baseRadar
    bonusHiddenRadar = bonusHiddenRadar - baseHidden
    if radar ~= 0 then
        table.insert(texts, {ltext = "Radar Range"%_t, rtext = string.format("%+i", radar), icon = "data/textures/icons/radar-sweep.png", boosted = permanent})
        if not permanent then
            table.insert(bonuses, {ltext = "Radar Range"%_t, rtext = string.format("%+i", bonusRadar), icon = "data/textures/icons/radar-sweep.png"})
        end
    end
    if hiddenRadar ~= 0 then
        table.insert(texts, {ltext = "Deep Scan Range"%_t, rtext = string.format("%+i", hiddenRadar), icon = "data/textures/icons/radar-sweep.png", boosted = permanent})
        if not permanent then
            table.insert(bonuses, {ltext = "Deep Scan Range"%_t, rtext = string.format("%+i", bonusHiddenRadar), icon = "data/textures/icons/radar-sweep.png"})
        end
    end

    -- add valuable scanner tooltip
    local range, cooldown = getValueableScannerBonuses(seed, rarity, true)

    local toYesNo = function(line, value)
        if value then
            line.rtext = "Yes"%_t
            line.rcolor = ColorRGB(0.3, 1.0, 0.3)
        else
            line.rtext = "No"%_t
            line.rcolor = ColorRGB(1.0, 0.3, 0.3)
        end
    end

    table.insert(texts, {ltext = "Claimable Asteroids"%_t, icon = "data/textures/icons/asteroid.png"})
    toYesNo(texts[#texts], true)

    table.insert(texts, {ltext = "Flight Recorders"%_t, icon = "data/textures/icons/ship.png"})
    toYesNo(texts[#texts], true)

    table.insert(texts, {ltext = "Treasures"%_t, icon = "data/textures/icons/crate.png"})
    toYesNo(texts[#texts], true)

    table.insert(texts, {}) -- empty line

    if permanent then
        table.insert(texts, {ltext = "Automatic Notification"%_t, rtext = "", icon = "data/textures/icons/mission-item.png", boosted = permanent})
        toYesNo(texts[#texts], permanent)
    end

    table.insert(bonuses, {ltext = "Automatic Notification"%_t, rtext = "Yes", icon = "data/textures/icons/mission-item.png"})

    if range > 0 then
        rangeText = string.format("%g km"%_t, round(range / 100, 2))
        if permanent then
            table.insert(texts, {ltext = "Highlight Range"%_t, rtext = rangeText, icon = "data/textures/icons/rss.png", boosted = permanent})
        end

        table.insert(bonuses, {ltext = "Highlight Range"%_t, rtext = rangeText, icon = "data/textures/icons/rss.png"})
    end

    table.insert(texts, {ltext = "Detection Range"%_t, rtext = "Sector"%_t, icon = "data/textures/icons/rss.png"})

    if range > 0 then
        if permanent then
            table.insert(texts, {ltext = "Highlight Duration"%_t, rtext = string.format("%s", createReadableShortTimeString(highlightDuration)), icon = "data/textures/icons/hourglass.png", boosted = permanent})
        end

        table.insert(bonuses, {ltext = "Highlight Duration"%_t, rtext = string.format("%s", createReadableShortTimeString(highlightDuration)), icon = "data/textures/icons/hourglass.png"})
    end

    table.insert(texts, {ltext = "Cooldown"%_t, rtext = string.format("%s", createReadableShortTimeString(cooldown)), icon = "data/textures/icons/hourglass.png"})
	
    -- add thruster boost tooltips
    local thrusterboost = getThrusterBonuses(seed, rarity, true)
    if thrusterboost ~= 0 then
        if permanent then
            table.insert(texts, {ltext = "Pitch/Roll/Yaw (Fixed)"%_t, rtext = string.format("%.2f", thrusterboost), icon = "data/textures/icons/gyroscope.png", boosted = permanent})
        else
            table.insert(bonuses, {ltext = "Pitch/Roll/Yaw (Fixed)"%_t, rtext = string.format("%.2f", thrusterboost), icon = "data/textures/icons/gyroscope.png"})
        end
    end

    -- add hyperspace cooldown tooltips
    local cdfactor = getHyperspaceBonuses(seed, rarity, true)
    if cdfactor ~= 0 then
        if permanent then
            table.insert(texts, {ltext = "Hyperspace Cooldown"%_t, rtext = string.format("%+i%%", round(cdfactor * 100)), icon = "data/textures/icons/hourglass.png", boosted = permanent})
        end
        table.insert(bonuses, {ltext = "Hyperspace Cooldown"%_t, rtext = string.format("%+i%%", round(cdfactor * 100)), icon = "data/textures/icons/hourglass.png", boosted = permanent})
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

    table.insert(texts, {ltext = "AA-Tech Bridge Intelligence Assistance Coprocessor"%_t})
    table.insert(texts, {ltext = "Improves various information gathering systems"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "Scans your surroundings for objects of interest"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "Bridges orientation sensors to engine control for more precise movement"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "Prevents damage from subspace distortions"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)})
    table.insert(texts, {ltext = "", boosted = permanent})
    table.insert(texts, {ltext = "Detects interesting objects in the sector."%_t})

    if rarity > Rarity(RarityType.Petty) then
        table.insert(texts, {ltext = "Highlights objects when permanently installed."%_t})
    end

    return texts
end


function getComparableValues(seed, rarity)
    local base = {}
    local bonus = {}

    -- add scanner compare values
    local scanner, scannerBase, scannerBonus = getScannerBonuses(seed, rarity, false)
    table.insert(base, {name = "Scanner Range"%_t, key = "range", value = round(scannerBase * 100), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Scanner Range"%_t, key = "range", value = round(scannerBonus * 100), comp = UpgradeComparison.MoreIsBetter})

    -- add valuable scanner compare values
    local range, cooldown = getValueableScannerBonuses(seed, rarity, false)
	table.insert(bonus, {name = "Highlight Range"%_t, key = "highlight_range", value = round(range / 100), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Highlight Duration"%_t, key = "highlight_duration", value = round(highlightDuration), comp = UpgradeComparison.MoreIsBetter})

    table.insert(base, {name = "Detection Range"%_t, key = "detection_range", value = 1, comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Cooldown"%_t, key = "cooldown", value = cooldown, comp = UpgradeComparison.LessIsBetter})

    -- add radar compare values
    local radar, hiddenRadar = getRadarBonuses(seed, rarity, true)
    local baseRadar, baseHidden = getRadarBonuses(seed, rarity, false)
    if radar ~= 0 then
        table.insert(base, {name = "Radar Range"%_t, key = "radar_range", value = baseRadar, comp = UpgradeComparison.MoreIsBetter})
        table.insert(bonus, {name = "Radar Range"%_t, key = "radar_range", value = radar-baseRadar, comp = UpgradeComparison.MoreIsBetter})
    end
    if hiddenRadar ~= 0 then
        table.insert(base, {name = "Deep Scan Range"%_t, key = "deep_range", value = baseHidden, comp = UpgradeComparison.MoreIsBetter})
        table.insert(bonus, {name = "Deep Scan Range"%_t, key = "deep_range", value = hiddenRadar-baseHidden, comp = UpgradeComparison.MoreIsBetter})
    end

    -- add thruster boost compare values
    local thrusterboost = getThrusterBonuses(seed, rarity, true)
    if thrusterboost ~= 0 then
        table.insert(base, {name = "Thruster boost"%_t, key = "thruster_boost", value = thrusterboost, comp = UpgradeComparison.MoreIsBetter})
    end

    -- add hyperspace cooldown compare values
    local cdfactorbase = getHyperspaceBonuses(seed, rarity, false)
    local cdfactor = getHyperspaceBonuses(seed, rarity, true)
    if cdfactorbase ~= 0 then
        table.insert(base, {name = "Hyperspace Cooldown"%_t, key = "hs_cooldown", value = round(cdfactorbase * 100), comp = UpgradeComparison.LessIsBetter})
    end
    if cdfactor ~= 0 then
        table.insert(bonus, {name = "Hyperspace Cooldown"%_t, key = "hs_cooldown", value = round((cdfactor-cdfactorbase) * 100), comp = UpgradeComparison.LessIsBetter})
    end

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