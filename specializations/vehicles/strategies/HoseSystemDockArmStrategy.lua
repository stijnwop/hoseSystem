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

    if object.hasHoseSystemPumpMotor then
        object.pumpMotorDockArmMode = HoseSystemPumpMotor.getInitialFillMode(HoseSystemFillArmFactory.TYPE_DOCK)
    end

    return dockArmStrategy
end

---
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemDockArmStrategy:load(xmlFile, key, entry)
    entry.needsTransfer = Utils.getNoNil(getXMLBool(xmlFile, key .. '#needsTransfer'), false)

    return entry
end

function HoseSystemDockArmStrategy:update(dt)
end

function HoseSystemDockArmStrategy:updateTick(dt)
    if self.object.isServer and self.object.hasHoseSystemPumpMotor then
        self.object:handlePump(self.object.pumpMotorDockArmMode, dt)
    end
end
