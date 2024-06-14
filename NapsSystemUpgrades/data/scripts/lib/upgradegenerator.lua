-- Starting with version 0.29, the upgradegenerator.lua was changed
if GameVersion() >= Version(0, 29, 0) then
    add("data/scripts/systems/civturretcoproc.lua", 0.01, 75)
    add("data/scripts/systems/civtravelcoproc.lua", 0.01, 75)
    add("data/scripts/systems/intelcoproc.lua", 0.01, 75)
    add("data/scripts/systems/milfleetcoproc.lua", 0.01, 75)
    add("data/scripts/systems/milturretcoproc.lua", 0.01, 75)
    add("data/scripts/systems/quantumdrivecoproc.lua", 0.01, 75)	
else
    -- use this for version 0.28 and below
    UpgradeGenerator.add("data/scripts/systems/civturretcoproc.lua", 0.01, 75)
    UpgradeGenerator.add("data/scripts/systems/civtravelcoproc.lua", 0.01, 75)
    UpgradeGenerator.add("data/scripts/systems/intelcoproc.lua", 0.01, 75)
    UpgradeGenerator.add("data/scripts/systems/milfleetcoproc.lua", 0.01, 75)
    UpgradeGenerator.add("data/scripts/systems/milturretcoproc.lua", 0.01, 75)
    UpgradeGenerator.add("data/scripts/systems/quantumdrivecoproc.lua", 0.01, 75)
end
