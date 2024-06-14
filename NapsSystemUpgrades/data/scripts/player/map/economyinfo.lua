
local orig_getBestEconomyOverviewRange = EconomyInfo.getBestEconomyOverviewRange
function EconomyInfo.getBestEconomyOverviewRange()

    local player = Player()
    if not player then return 0 end

    local craft = player.craft
    if not craft then return 0 end

    local scripts = craft:getScripts()
    if not scripts then return 0 end

    local best = 0
    best = orig_getBestEconomyOverviewRange()

    for i, file in pairs(scripts) do
		--printlog("economyinfo.lua: " .. file)
        if string.match(file, "/systems/civtravelcoproc.lua") then
            local ok, r = craft:invokeFunction(i, "getEconomyRange")
			--printlog("economyinfo.lua: ok=" .. tostring(ok))
			--printlog("economyinfo.lua: r=" .. tostring(r))

            if ok == 0 and r > best then
                best = r
            end
        end
    end

    --printlog("economyinfo.lua: EconomyInfo.getBestEconomyOverviewRange() returns " .. tostring(best))
    return best
end