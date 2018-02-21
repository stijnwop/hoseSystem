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
    entry.planeOffset = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#planeOffset'), 0)

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
    if self.object.isServer and self.object.hasHoseSystemPumpMotor then
        self.fillTriggerInteractive:update(dt)
    end
end

function HoseSystemArmStrategy:updateTick(dt)
    if self.object.isServer and self.object.hasHoseSystemPumpMotor then
        if self.object.lastRaycastObject ~= nil then
            self.object:addFillObject(self.object.lastRaycastObject, self.object.pumpMotorFillArmMode, true)
        else
            self.object:removeFillObject(self.object.lastRaycastObject, self.object.pumpMotorFillArmMode)
        end

        local fillDirection = self.object:getFillDirection()
        local isAbleToPump = true

        -- if fill direction is IN we have some exceptions
        if fillDirection == HoseSystemPumpMotor.IN then
            if self.object.fillObjectHasPlane and self.object.fillObject.checkPlaneY ~= nil then
                if self.object.lastRaycastDistance ~= 0 then
                    local x, y, z = getWorldTranslation(self.object.fillArm.node)
                    local isUnderFillplane, _ = self.object.lastRaycastObject:checkPlaneY(y + self.object.fillArm.planeOffset, { x, y, z })

                    isAbleToPump = isUnderFillplane
                end
            end
        end

        self.object:handlePump(self.object.pumpMotorFillArmMode, dt, isAbleToPump)
    end
end
