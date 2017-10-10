--
-- HoseSystemFillArm
--
-- Authors: Wopster
-- Description: The HoseSystem fillArm script for vehicles
--
-- Copyright (c) Wopster, 2017

HoseSystemFillArm = {
    baseDirectory = g_currentModDirectory
}

HoseSystemFillArm.typesToInt = {}

HoseSystemFillArm.XML_KEY = 'vehicle.hoseSystemFillArm'

source(HoseSystemFillArm.baseDirectory .. 'specializations/vehicles/HoseSystemFillArmFactory.lua')

---
-- @param name
--
function HoseSystemFillArm.formatTypeKey(name)
    return ('type_%s'):format(name:lower())
end

---
-- @param name
--
function HoseSystemFillArm.registerType(name)
    local key = HoseSystemFillArm.formatTypeKey(name)

    if HoseSystemFillArm.typesToInt[key] == nil then
        HoseSystemFillArm.typesToInt[key] = #HoseSystemFillArm.typesToInt + 1
    end
end

---
-- @param name
--
function HoseSystemFillArm.getInitialType(name)
    local key = HoseSystemFillArm.formatTypeKey(name)

    if HoseSystemFillArm.typesToInt[key] ~= nil then
        return HoseSystemFillArm.typesToInt[key]
    end

    return nil
end

HoseSystemFillArm.registerType(HoseSystemDockArmStrategy.TYPE)

---
-- @param specializations
--
function HoseSystemFillArm.prerequisitesPresent(specializations)
    return true
end

---
-- @param savegame
--
function HoseSystemFillArm:preLoad(savegame)
end

---
-- @param savegame
--
function HoseSystemFillArm:load(savegame)
    self.fillArm = {}
    self.fillArmStrategies = {}

    local typeString = getXMLString(self.xmlFile, HoseSystemFillArm.XML_KEY .. '#type')

    if typeString == nil then
        -- Todo: log!
        return
    end

    local type = HoseSystemFillArm.getInitialType(typeString)

    if type == nil then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ('Invalid fillArm type %s!'):format(typeString))
        return
    end

    local factory = HoseSystemFillArmFactory.getInstance()
    table.insert(self.fillArmStrategies, factory:getFillArmStrategy(type, self))

    local node = HoseSystemXMLUtil.getOrCreateNode(self.components, self.xmlFile, HoseSystemFillArm.XML_KEY)

    if node ~= nil then
        self.fillArm = {
            type = type,
            node = node
        }

        self.fillArm = HoseSystemUtil.callStrategyFunction(self.fillArmStrategies, 'load', { self.xmlFile, HoseSystemFillArm.XML_KEY, self.fillArm })
    end
end

---
--
function HoseSystemFillArm:delete()
end

---
-- @param streamId
-- @param connection
--
function HoseSystemFillArm:readStream(streamId, connection)
end

---
-- @param streamId
-- @param connection
--
function HoseSystemFillArm:writeStream(streamId, connection)
end

---
-- @param ...
--
function HoseSystemFillArm:mouseEvent(...)
end

---
-- @param ...
--
function HoseSystemFillArm:keyEvent(...)
end

---
-- @param dt
--
function HoseSystemFillArm:update(dt)
end

---
-- @param dt
--
function HoseSystemFillArm:updateTick(dt)
end

---
--
function HoseSystemFillArm:draw()
end