HoseSystemArmStrategy = {}

local HoseSystemArmStrategy_mt = Class(HoseSystemArmStrategy)

---
-- @param object
-- @param mt
--
function HoseSystemArmStrategy:new(object, mt)
    local armStrategy = {
        object = object
    }

    setmetatable(armStrategy, mt == nil and HoseSystemArmStrategy_mt or mt)

    if object.hasHoseSystemPumpMotor then
        object.pumpMotorFillArmMode = HoseSystemPumpMotor.getInitialFillMode(HoseSystemFillArmFactory.TYPE_ARM)
    end


    self.fillTriggerInteractive = HoseSystemFillTriggerInteractive:new(object)

    return armStrategy
end

---
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemArmStrategy:load(xmlFile, key, entry)
    entry.offset = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#offset'), 0)

    self.object.supportedFillTypes = {}

    local fillTypeCategories = getXMLString(xmlFile, key .. '#supportedFillTypeCategories')

    if fillTypeCategories ~= nil then
        local fillTypes = FillUtil.getFillTypeByCategoryName(fillTypeCategories, "Warning: '" .. self.object.configFileName .. "' has invalid fillTypeCategory '%s'.")

        if fillTypes ~= nil then
            for _, fillType in pairs(fillTypes) do
                self.object.supportedFillTypes[fillType] = true
            end
        end
    end

    return entry
end

function HoseSystemArmStrategy:update(dt)
end

function HoseSystemArmStrategy:updateTick(dt)
    if self.object.hasHoseSystemPumpMotor then
        self.fillTriggerInteractive:update(dt)

        if self.object.lastRaycastObject ~= nil then
            self.object:addFillObject(self.object.lastRaycastObject, self.object.pumpMotorFillArmMode, false)
        else
            self.object:removeFillObject(self.object.lastRaycastObject, self.object.pumpMotorFillArmMode)
        end

        if self.object.isServer and self.object:getFillMode() == self.object.pumpMotorFillArmMode then

            local isSucking = self.object.fillObjectFound

            -- Todo: move this logic to pumpMotor script since we basically doing it twice (also on the connector).
            if self.object.pumpIsStarted and self.object.fillObject ~= nil then
                local sourceObject = self.object

                if self.object.fillDirection == HoseSystemPumpMotor.IN then
                    local objectFillTypes = self.object.fillObject:getCurrentFillTypes()

                    -- isn't below dubble code?
                    if self.object.fillObject:getFreeCapacity() ~= self.object.fillObject:getCapacity() then
                        for _, objectFillType in pairs(objectFillTypes) do
                            if sourceObject:allowUnitFillType(self.object.fillUnitIndex, objectFillType, false) then
                                local objectFillLevel = self.object.fillObject:getFillLevel(objectFillType)
                                local fillLevel = sourceObject:getUnitFillLevel(self.object.fillUnitIndex)

                                if objectFillLevel > 0 and fillLevel < sourceObject:getUnitCapacity(self.object.fillUnitIndex) then
                                    self.object:pumpIn(sourceObject, dt, objectFillLevel, objectFillType)
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
                    self.object:pumpOut(sourceObject, dt)
                end
            end

            if self.object.isSucking ~= isSucking then
                self.object.isSucking = isSucking
                g_server:broadcastEvent(IsSuckingEvent:new(self.object, self.object.isSucking))
            end
        end
    end
end
