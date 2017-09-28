--
-- HoseSystemVehicle
--
-- Authors: Wopster
-- Description: Enables you to make use of the Hose System vehicle specializations
--
-- Copyright (c) Wopster, 2017

HoseSystemVehicle = {}

---
-- @param specializations
--
function HoseSystemVehicle.prerequisitesPresent(specializations)
    return true
end

---
-- @param savegame
--
function HoseSystemVehicle:preLoadHoseSystem(savegame)
    self.hasHoseSystemConnectors = Utils.getNoNil(getXMLBool(self.xmlFile, 'vehicle.hoseSystem#hasConnectors'), true) -- since i implement this spec i assume you want to add the references
    self.hasHoseSystemPumpMotor = Utils.getNoNil(getXMLBool(self.xmlFile, 'vehicle.hoseSystem#hasPumpMotor'), false)

    if g_currentMission.hoseSystemLog ~= nil then
        g_currentMission.hoseSystemLog(self, 3, {
            hasHoseSystemConnectors = self.hasHoseSystemConnectors,
            hasHoseSystemPumpMotor = self.hasHoseSystemPumpMotor,
        })
    end
end

function HoseSystemVehicle:load(savegame)
end

function HoseSystemVehicle:delete()
end

function HoseSystemVehicle:mouseEvent(...)
end

function HoseSystemVehicle:keyEvent(...)
end

function HoseSystemVehicle:update(dt)
end

function HoseSystemVehicle:draw()
end