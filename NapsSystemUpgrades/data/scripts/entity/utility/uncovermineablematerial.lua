-- due to bad modding integration, we just cant add our mining system to the list of known mining systems
-- so we have to copy the code here. In general that's bad design since we need to keep track of any change
-- here in the future

function UncoverMineableMaterial.updateServer()
    local entity = Entity()

    -- miner captains uncover all hidden asteroid materials
    local captain = entity:getCaptain()
    if captain and captain:hasClass(CaptainUtility.ClassType.Miner) then
        entity:setValue("uncovered_mineable_material", MaterialType.Avorion)
        return
    end

    local highestMaterialLevel

    local miningScripts = {
        "data/scripts/systems/miningsystem.lua",
        "internal/dlc/rift/systems/miningcarrierhybrid.lua",
        "data/scripts/systems/civturretcoproc.lua",
    }

    local system = ShipSystem()
    for upgrade, permanent in pairs(system:getUpgrades()) do
        for _, miningScript in pairs(miningScripts) do
            if upgrade.script == miningScript then
                local ret, materialLevel = entity:invokeFunction(miningScript, "getBonuses", upgrade.seed, upgrade.rarity, permanent)
                if ret == 0 then
                    if highestMaterialLevel == nil or materialLevel > highestMaterialLevel then
                        highestMaterialLevel = materialLevel
                    end
                else
                    local ret, materialLevel = entity:invokeFunction(miningScript, "getMiningSystemBonuses", upgrade.seed, upgrade.rarity, permanent)
                    if ret == 0 then
                        if highestMaterialLevel == nil or materialLevel > highestMaterialLevel then
                            highestMaterialLevel = materialLevel
                        end
                    end
                end
            end
        end
    end

    entity:setValue("uncovered_mineable_material", highestMaterialLevel)

    if not highestMaterialLevel then
        terminate()
    end
end