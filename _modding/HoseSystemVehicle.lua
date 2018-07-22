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
--
function HoseSystemVehicle.initSpecialization()
    if g_hoseSystem ~= nil then
        return
    end

    local noopFunction = function() end

    for _, method in pairs({ "load", "delete", "mouseEvent", "keyEvent", "update", "draw" }) do
        if HoseSystemVehicle[method] == nil then
            HoseSystemVehicle[method] = noopFunction
        end
    end
end

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