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
    self.hasHoseSystemFillArm = Utils.getNoNil(getXMLBool(self.xmlFile, 'vehicle.hoseSystem#hasFillArm'), false)

    if g_hoseSystem.log ~= nil then
        g_hoseSystem.log(self, 3, {
            hasHoseSystemConnectors = self.hasHoseSystemConnectors,
            hasHoseSystemPumpMotor = self.hasHoseSystemPumpMotor,
            hasHoseSystemFillArm = self.hasHoseSystemFillArm
        })
    end
end

local function noopFunction() end

HoseSystemVehicle.load = noopFunction
HoseSystemVehicle.delete = noopFunction
HoseSystemVehicle.mouseEvent = noopFunction
HoseSystemVehicle.keyEvent = noopFunction
HoseSystemVehicle.update = noopFunction
HoseSystemVehicle.draw = noopFunction