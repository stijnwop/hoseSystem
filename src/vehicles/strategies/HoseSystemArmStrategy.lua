HoseSystemArmStrategy = {}

local HoseSystemArmStrategy_mt = Class(HoseSystemArmStrategy)

---
-- @param object
--
function HoseSystemArmStrategy:prerequisitesPresent(object)
    if not SpecializationUtil.hasSpecialization(Fillable, object.specializations) then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, "Strategy HoseSystemArmStrategy needs the specialization Fillable")

        return false
    end

    return true
end

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
        object.pumpMotorFillArmFillMode = HoseSystemPumpMotorFactory.getInitialFillMode(HoseSystemFillArmFactory.TYPE_ARM)
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
    local object = self.object

    if object.isServer and object.hasHoseSystemPumpMotor then
        self.fillTriggerInteractive:update(dt)
    end
end

function HoseSystemArmStrategy:updateTick(dt)
    local object = self.object

    if object.isServer and object.hasHoseSystemPumpMotor then
        if object.lastRaycastObject ~= nil then
            object:addFillObject(object.lastRaycastObject, object.pumpMotorFillArmFillMode, true)
        else
            object:removeFillObject(object.lastRaycastObject, object.pumpMotorFillArmFillMode)
        end

        local fillDirection = object:getFillDirection()
        local isAbleToPump = true

        -- if fill direction is IN we have some exceptions
        if fillDirection == HoseSystemPumpMotor.IN then
            if object.fillObjectHasPlane and object.fillObject.checkPlaneY ~= nil then
                if object.lastRaycastDistance ~= 0 then
                    local x, y, z = getWorldTranslation(object.fillArm.node)
                    local isUnderFillplane, _ = object.lastRaycastObject:checkPlaneY(y + object.fillArm.planeOffset, { x, y, z })

                    isAbleToPump = isUnderFillplane
                end
            end
        end

        object:handlePump(object.pumpMotorFillArmFillMode, dt, isAbleToPump)
    end
end
