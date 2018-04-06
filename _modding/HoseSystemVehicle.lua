--
-- HoseSystemVehicle
--
-- Authors: Wopster
-- Description: Enables you to make use of the Hose System vehicle specializations
--
-- Copyright (c) Wopster, 2017

HoseSystemVehicle = {}
HoseSystemVehicle.version = 1.2

---
-- @param specializations
--
function HoseSystemVehicle.prerequisitesPresent(specializations)
    return true
end

---
--
function HoseSystemVehicle:preLoadHoseSystem()
    self.hasHoseSystemConnectors = Utils.getNoNil(getXMLBool(self.xmlFile, 'vehicle.hoseSystem#hasConnectors'), true)
    self.hasHoseSystemPumpMotor = Utils.getNoNil(getXMLBool(self.xmlFile, 'vehicle.hoseSystem#hasPumpMotor'), false)
    self.hasHoseSystemFillArm = Utils.getNoNil(getXMLBool(self.xmlFile, 'vehicle.hoseSystem#hasFillArm'), false)
end