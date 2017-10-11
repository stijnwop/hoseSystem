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
        object.pumpMotorFillArmMode = HoseSystemPumpMotor.getInitialFillMode(HoseSystemFillArmFactory.TYPE_DOCK)
    end

    return dockArmStrategy
end

---
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemDockArmStrategy:load(xmlFile, key, entry)
    -- ?
    return entry
end

function HoseSystemDockArmStrategy:update(dt)
    if self.object.hasHoseSystemPumpMotor then
        if self.object.isServer and self.object:getFillMode() == self.object.pumpMotorFillArmMode then
            local isSucking = self.object.fillObjectFound

            -- Todo: move this logic to pumpMotor script since we basically doing it twice (also on the connector).
            if self.object.pumpIsStarted and self.object.fillObject ~= nil then
                if self.object.fillDirection == HoseSystemPumpMotor.IN then
                    local objectFillTypes = self.object.fillObject:getCurrentFillTypes()

                    -- isn't below dubble code?
                    if self.object.fillObject:getFreeCapacity() ~= self.object.fillObject:getCapacity() then
                        for _, objectFillType in pairs(objectFillTypes) do
                            if self.object:allowUnitFillType(self.object.fillUnitIndex, objectFillType, false) then
                                local objectFillLevel = self.object.fillObject:getFillLevel(objectFillType)
                                local fillLevel = self.object:getUnitFillLevel(self.object.fillUnitIndex)

                                if objectFillLevel > 0 and fillLevel < self.object:getUnitCapacity(self.object.fillUnitIndex) then
                                    self.object:pumpIn(dt, objectFillLevel, objectFillType)
                                else
                                    self.object:setPumpStarted(false, HoseSystemPumpMotor.UNIT_EMPTY)
                                end
                            else
                                self.object:setPumpStarted(false, HoseSystemPumpMotor.INVALID_FILLTYPE)
                            end
                        end
                    else
                        self.object:setPumpStarted(false, HoseSystemPumpMotor.OBJECT_EMPTY)
                    end
                else
                    self.object:pumpOut(dt)
                end
            end

            if self.object.isSucking ~= isSucking then
                self.object.isSucking = isSucking
                g_server:broadcastEvent(IsSuckingEvent:new(self.object, self.object.isSucking))
            end
        end
    end
end