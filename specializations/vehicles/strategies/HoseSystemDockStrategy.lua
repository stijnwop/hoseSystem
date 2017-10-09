--
-- HoseSystemDockStrategy
--
-- Authors: Wopster
-- Description: Strategy for loading dockings
--
-- Copyright (c) Wopster, 2017


HoseSystemDockStrategy = {}

HoseSystemDockStrategy.TYPE = 'dock'

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

---
-- @param type
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemDockStrategy:loadDock(type, xmlFile, key, entry)
    if type ~= HoseSystemConnector.getInitialType(HoseSystemDockStrategy.TYPE) then
        return entry
    end
end