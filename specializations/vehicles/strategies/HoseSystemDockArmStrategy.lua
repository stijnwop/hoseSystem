HoseSystemDockArmStrategy = {}

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

---
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemDockArmStrategy:load(xmlFile, key, entry)

    return entry
end