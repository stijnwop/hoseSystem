-- Todo: credits

HoseSystemDockStrategy = {}

HoseSystemDockStrategy.type = 'dock'

local HoseSystemDockStrategy_mt = Class(HoseSystemDockStrategy)

---
-- @param object
-- @param mt
--
function HoseSystemDockStrategy:new(object, mt)
    local dockStrategy = {
        object = object
    }

    setmetatable(dockStrategy, mt == nil and HoseSystemDockStrategy_mt or mt)

    return dockStrategy
end

---
--
function HoseSystemDockStrategy:delete()
end

function HoseSystemDockStrategy:loadDock(type, xmlFile, base, entry)
    if type ~= HoseSystemConnector.getInitialType(HoseSystemDockStrategy.type) then
        return entry
    end

    print("Loading dock")
end