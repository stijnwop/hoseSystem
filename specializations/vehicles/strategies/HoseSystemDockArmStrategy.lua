HoseSystemDockArmStrategy = {}

HoseSystemDockArmStrategy.TYPE = 'dock'

local HoseSystemDockArmStrategy_mt = Class(HoseSystemDockArmStrategy)

---
-- @param object
-- @param mt
--
function HoseSystemDockArmStrategy:new(object, mt)
    local dockArmStrategy = {
        object = object
    }

    setmetatable(dockArmStrategy, mt == nil and HoseSystemDockArmStrategy_mt or mt)

    return dockArmStrategy
end

function HoseSystemDockArmStrategy:load(xmlFile, key, entry)
    print("Loading a fillArm")

    return entry
end