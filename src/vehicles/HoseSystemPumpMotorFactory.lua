--
-- HoseSystemPumpMotorFactory
--
-- Authors: Wopster
-- Description: The HoseSystem pump motor factory
--
-- Copyright (c) Wopster, 2017

HoseSystemPumpMotorFactory = {}

HoseSystemPumpMotorFactory.numFillModes = 0
HoseSystemPumpMotorFactory.fillModes = {}

---
--
function HoseSystemPumpMotorFactory:preLoadHoseSystem()
    -- Register the fill mode for the hose system
    HoseSystemPumpMotorFactory.registerFillMode(HoseSystemConnectorFactory.TYPE_HOSE_COUPLING)
    HoseSystemPumpMotorFactory.registerFillMode(HoseSystemFillArmFactory.TYPE_DOCK)
    HoseSystemPumpMotorFactory.registerFillMode(HoseSystemFillArmFactory.TYPE_ARM)
end

---
-- @param name
--
function HoseSystemPumpMotorFactory.formatFillModeKey(name)
    return ('mode_%s'):format(name:lower())
end

---
-- @param name
--
function HoseSystemPumpMotorFactory.registerFillMode(name)
    if HoseSystemPumpMotorFactory.numFillModes >= 2 ^ HoseSystemPumpMotor.sendNumBits then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ('Max number of fill modes is %s!'):format(2 ^ HoseSystemPumpMotor.sendNumBits))
        return
    end

    local key = HoseSystemPumpMotorFactory.formatFillModeKey(name)
    if HoseSystemPumpMotorFactory.fillModes[key] == nil then
        HoseSystemPumpMotorFactory.numFillModes = HoseSystemPumpMotorFactory.numFillModes + 1
        HoseSystemPumpMotorFactory.fillModes[key] = HoseSystemPumpMotorFactory.numFillModes
    end
end

---
-- @param fillMode
--
function HoseSystemPumpMotorFactory.allowFillMode(fillMode)
    for _, value in pairs(HoseSystemPumpMotorFactory.fillModes) do
        if value == fillMode then
            return true
        end
    end

    return false
end

---
-- @param name
--
function HoseSystemPumpMotorFactory.getInitialFillMode(name)
    local key = HoseSystemPumpMotorFactory.formatFillModeKey(name)

    if HoseSystemPumpMotorFactory.fillModes[key] ~= nil then
        return HoseSystemPumpMotorFactory.fillModes[key]
    end

    return nil
end