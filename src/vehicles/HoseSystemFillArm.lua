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

HoseSystemFillArm.XML_KEY = 'vehicle.hoseSystemFillArm'

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
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ('fillArm type not found!'))
        return
    end

    local factory = HoseSystemFillArmFactory.getInstance()
    local type = factory.getInitialType(typeString)

    if type == nil then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ('Invalid fillArm type %s!'):format(typeString))
        return
    end

    local node = HoseSystemXMLUtil.getOrCreateNode(self.components, self.xmlFile, HoseSystemFillArm.XML_KEY)

    if node ~= nil then
        self.fillArmStrategies = HoseSystemUtil.insertStrategy(factory:getFillArmStrategy(type, self), self.fillArmStrategies)

        self.fillArm = {
            type = type,
            node = node
        }

        self.fillArm = HoseSystemUtil.callStrategyFunction(self.fillArmStrategies, 'load', { self.xmlFile, HoseSystemFillArm.XML_KEY, self.fillArm })

        if not HoseSystemUtil.callStrategyFunction(self.fillArmStrategies, 'prerequisitesPresent', { self }) then
            self.fillArm = {}
            self.fillArmStrategies = {}
        end
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
    HoseSystemUtil.callStrategyFunction(self.fillArmStrategies, 'update', { dt })
end

---
-- @param dt
--
function HoseSystemFillArm:updateTick(dt)
    HoseSystemUtil.callStrategyFunction(self.fillArmStrategies, 'updateTick', { dt })
end

---
--
function HoseSystemFillArm:draw()
end