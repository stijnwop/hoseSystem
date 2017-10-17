--
-- HoseSystemPumpMotor
--
-- Authors:    	Wopster and Xentro (Marcus@Xentro.se)
-- Description: Pumpmotor to pump fillTypes
--
-- Copyright (c) Wopster and Xentro, 2017

HoseSystemPumpMotor = {
    sendNumBits = 1,
    fillModesNum = 0,
    fillModes = {}
}

HoseSystemPumpMotor.IN = 0
HoseSystemPumpMotor.IN_STRING = 'in'
HoseSystemPumpMotor.OUT = 1
HoseSystemPumpMotor.OUT_STRING = 'out'

HoseSystemPumpMotor.NONE = 0
HoseSystemPumpMotor.TURN_OFF = 1
HoseSystemPumpMotor.UNIT_EMPTY = 2
HoseSystemPumpMotor.OBJECT_EMPTY = 3
HoseSystemPumpMotor.INVALID_FILLTYPE = 4

HoseSystemPumpMotor.DEFAULT_LITERS_PER_SECOND = 100

HoseSystemPumpMotor.AUTO_STOP_MULTIPLIER_IN = 0.99
HoseSystemPumpMotor.AUTO_STOP_MULTIPLIER_OUT = 0.98

HoseSystemPumpMotor.WARNING_TIME = 1500
HoseSystemPumpMotor.STARTUP_TIME = 1500
HoseSystemPumpMotor.MAX_EFFICIENCY_TIME = 1500

---
-- @param name
--
function HoseSystemPumpMotor.formatFillModeKey(name)
    return ('mode_%s'):format(name:lower())
end

---
-- @param name
--
function HoseSystemPumpMotor.registerFillMode(name)
    local key = HoseSystemPumpMotor.formatFillModeKey(name)
    if HoseSystemPumpMotor.fillModes[key] == nil then
        HoseSystemPumpMotor.fillModesNum = HoseSystemPumpMotor.fillModesNum + 1
        HoseSystemPumpMotor.fillModes[key] = HoseSystemPumpMotor.fillModesNum
    end
end

---
-- @param fillMode
--
function HoseSystemPumpMotor.allowFillMode(fillMode)
    for key, value in pairs(HoseSystemPumpMotor.fillModes) do
        if value == fillMode then
            return true
        end
    end

    return false
end

---
-- @param name
--
function HoseSystemPumpMotor.getInitialFillMode(name)
    local key = HoseSystemPumpMotor.formatFillModeKey(name)

    if HoseSystemPumpMotor.fillModes[key] ~= nil then
        return HoseSystemPumpMotor.fillModes[key]
    end

    return nil
end

---
-- @param specializations
--
function HoseSystemPumpMotor.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Fillable, specializations)
end

---
-- @param savegame
--
function HoseSystemPumpMotor:preLoad(savegame)
    self.getFillMode = HoseSystemPumpMotor.getFillMode
    self.setFillMode = HoseSystemPumpMotor.setFillMode
    self.getFillDirection = HoseSystemPumpMotor.getFillDirection
    self.setFillDirection = SpecializationUtil.callSpecializationsFunction('setFillDirection')
    self.allowPumpStarted = HoseSystemPumpMotor.allowPumpStarted
    self.setPumpStarted = SpecializationUtil.callSpecializationsFunction('setPumpStarted')
    self.pumpIn = HoseSystemPumpMotor.pumpIn
    self.pumpOut = HoseSystemPumpMotor.pumpOut
    self.doPump = HoseSystemPumpMotor.doPump
    self.doFakePump = HoseSystemPumpMotor.doFakePump
    self.getIsTurnedOn = Utils.overwrittenFunction(self.getIsTurnedOn, HoseSystemPumpMotor.getIsTurnedOn)
    self.getIsTurnedOnAllowed = Utils.overwrittenFunction(self.getIsTurnedOnAllowed, HoseSystemPumpMotor.getIsTurnedOnAllowed)
    self.getConsumedPtoTorque = Utils.overwrittenFunction(self.getConsumedPtoTorque, HoseSystemPumpMotor.getConsumedPtoTorque)
    -- self.setIsTurnedOn = Utils.overwrittenFunction(self.setIsTurnedOn, HoseSystemPumpMotor.setIsTurnedOn)
    self.setWarningMessage = HoseSystemPumpMotor.setWarningMessage
    self.getAllowedFillUnitIndex = HoseSystemPumpMotor.getAllowedFillUnitIndex
    self.addFillObject = HoseSystemPumpMotor.addFillObject
    self.removeFillObject = HoseSystemPumpMotor.removeFillObject
    self.updateFillObject = HoseSystemPumpMotor.updateFillObject
end

---
-- @param savegame
--
function HoseSystemPumpMotor:load(savegame)
    self.attacherMotor = {
        check = false,
        isStarted = false
    }

    self.pumpIsStarted = false
    self.fillMode = 0 -- 0 is nothing
    self.fillDirection = HoseSystemPumpMotor.IN

    local limit = getXMLString(self.xmlFile, "vehicle.pumpMotor#limitedFillDirection")
    self.limitedFillDirection = nil

    if limit ~= nil then
        self.limitedFillDirection = limit:lower() == HoseSystemPumpMotor.IN_STRING and HoseSystemPumpMotor.IN or HoseSystemPumpMotor.OUT
    end

    self.limitFillDirection = self.limitedFillDirection ~= nil

    self.pumpEfficiency = {
        currentScale = 0,
        scaleLimit = 0.1, -- when we can change fill direction
        currentStartUpTime = 0,
        startUpTime = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#startUpTime"), HoseSystemPumpMotor.STARTUP_TIME)
    }

    local maxTime = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#toReachMaxEfficiencyTime"), HoseSystemPumpMotor.MAX_EFFICIENCY_TIME)
    self.pumpFillEfficiency = {
        currentScale = 0,
        currentTime = 0,
        maxTimeStatic = maxTime,
        maxTime = maxTime,
        litersPerSecond = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#litersPerSecond"), HoseSystemPumpMotor.DEFAULT_LITERS_PER_SECOND)
    }

    self.autoStopPercentage = {
        inDirection = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#autoStopPercentageIn"), HoseSystemPumpMotor.AUTO_STOP_MULTIPLIER_IN),
        outDirection = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#autoStopPercentageOut"), HoseSystemPumpMotor.AUTO_STOP_MULTIPLIER_OUT)
    }

    if self.isClient then
        local linkNode = Utils.indexToObject(self.components, Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.pumpMotor#linkNode"), "0>"))
        self.samplePump = SoundUtil.loadSample(self.xmlFile, {}, "vehicle.pumpSound", nil, self.baseDirectory, linkNode)
    end

    self.warningMessage = {
        currentId = HoseSystemPumpMotor.NONE,
        currentTime = 0,
        howLongToShow = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#warningTime"), HoseSystemPumpMotor.WARNING_TIME),
        messages = {}
    }

    self.warningMessage.messages[HoseSystemPumpMotor.TURN_OFF] = g_i18n:getText('pumpMotor_warningTurnOffFirst')
    self.warningMessage.messages[HoseSystemPumpMotor.UNIT_EMPTY] = g_i18n:getText('pumpMotor_warningUnitEmpty')
    self.warningMessage.messages[HoseSystemPumpMotor.OBJECT_EMPTY] = g_i18n:getText('pumpMotor_warningObjectEmpty')
    self.warningMessage.messages[HoseSystemPumpMotor.INVALID_FILLTYPE] = g_i18n:getText('pumpMotor_warningInvalidFilltype')

    self.pumpMotor = {
        unloadInfoIndex = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.pumpMotor#unloadInfoIndex"), 1),
        dischargeInfoIndex = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.pumpMotor#dischargeInfoIndex"), 1),
        ptoRpm = self.powerConsumer.ptoRpm
    }

    -- Todo: lookup what we actually need on the current fillObject. (can we fill to multiple targets!?)
    --    self.fillableObjects = {}

    self.fillObject = nil
    self.fillObjectFound = false
    self.fillObjectHasPlane = false
    self.fillFromFillVolume = false
    self.fillUnitIndex = 0
    self.isSucking = false

    if self.isServer then
        self.lastFillObjectFound = false
        self.lastFillObjectHasPlane = false
        self.lastFillFromFillVolume = false
        self.lastFillUnitIndex = 0 -- stream?
    end
end

---
--
function HoseSystemPumpMotor:delete()
    if self.isClient then
        SoundUtil.deleteSample(self.samplePump)
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemPumpMotor:readStream(streamId, connection)
    self:setPumpStarted(streamReadBool(streamId), nil, true)
    self:setFillDirection(streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits), true)
    self:setFillMode(streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits), true)

    self.fillObjectFound = streamReadBool(streamId)
    self.fillFromFillVolume = streamReadBool(streamId)
    self.fillUnitIndex = streamReadInt32(streamId)
    self.fillObjectHasPlane = streamReadBool(streamId)
end

---
-- @param streamId
-- @param connection
--
function HoseSystemPumpMotor:writeStream(streamId, connection)
    streamWriteBool(streamId, self.pumpIsStarted)
    streamWriteUIntN(streamId, self.fillDirection, HoseSystemPumpMotor.sendNumBits)
    streamWriteUIntN(streamId, self.fillMode, HoseSystemPumpMotor.sendNumBits)

    streamWriteBool(streamId, self.fillObjectFound)
    streamWriteBool(streamId, self.fillFromFillVolume)
    streamWriteInt32(streamId, self.fillUnitIndex)
    streamWriteBool(streamId, self.fillObjectHasPlane)
end

---
-- @param posX
-- @param posY
-- @param isDown
-- @param isUp
-- @param button
--
function HoseSystemPumpMotor:mouseEvent(posX, posY, isDown, isUp, button)
end

---
-- @param unicode
-- @param sym
-- @param modifier
-- @param isDown
--
function HoseSystemPumpMotor:keyEvent(unicode, sym, modifier, isDown)
end

---
-- @param dt
--
function HoseSystemPumpMotor:update(dt)
    if self:getIsActive() then
        if self:getIsActiveForInput() and not self:hasInputConflictWithSelection() then
            if InputBinding.hasEvent(InputBinding.ACTIVATE_OBJECT) then
                if self.attacherMotor.isStarted then
                    if self:allowPumpStarted() then
                        self:setPumpStarted(not self.pumpIsStarted)
                    end
                end
            end

            if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA4) then
                if self.attacherMotor.isStarted then
                    if not self.pumpIsStarted then
                        if self.pumpEfficiency.currentScale < self.pumpEfficiency.scaleLimit then
                            self:setFillDirection(self:getFillDirection() + 1)
                        end
                    else
                        self:setWarningMessage(HoseSystemPumpMotor.TURN_OFF)
                    end
                end
            end
        end
    end
end

---
-- @param dt
--
function HoseSystemPumpMotor:updateTick(dt)
    if self.attacherMotor.check then
        local vehicle = self:getRootAttacherVehicle()
        self.attacherMotor.isStarted = vehicle.getIsMotorStarted ~= nil and vehicle:getIsMotorStarted()
    end

    if self.attacherMotor.isStarted then
        if self:getIsActive() then
            if self.warningMessage.currentId ~= HoseSystemPumpMotor.NONE then
                if self.warningMessage.currentTime < self.warningMessage.howLongToShow then
                    self.warningMessage.currentTime = self.warningMessage.currentTime + dt
                else
                    self.warningMessage.currentId = HoseSystemPumpMotor.NONE
                end
            end
        end

        if self.pumpIsStarted then
            if not self.fillObjectFound then -- if we lost the object stop pump
                self:setPumpStarted(false, nil, true)
            end

            if self.pumpEfficiency.currentStartUpTime < self.pumpEfficiency.startUpTime then
                self.pumpEfficiency.currentStartUpTime = math.min(self.pumpEfficiency.currentStartUpTime + dt, self.pumpEfficiency.startUpTime)
            end

            local updateFillScale = false

            if self.fillUnitIndex ~= 0 then
                local fillType = self.fillUnits[self.fillUnitIndex].currentFilltype

                if self:getFillDirection() == HoseSystemPumpMotor.IN then
                    if self:getFillLevel(fillType) / self:getCapacity(fillType) >= self.autoStopPercentage.inDirection then
                        self:setPumpStarted(false, nil, true)
                    end

                    if self.isSucking then
                        updateFillScale = true
                    end
                else
                    if self:getFillLevel(fillType) <= 0 or not self.fillObjectFound and not self.fillFromFillVolume then
                        self:setPumpStarted(false, nil, true)
                    end

                    updateFillScale = true
                end
            end

            if updateFillScale then
                if self.pumpFillEfficiency.currentTime < self.pumpFillEfficiency.maxTime then
                    self.pumpFillEfficiency.currentTime = math.min(self.pumpFillEfficiency.currentTime + dt, self.pumpFillEfficiency.maxTime)
                end
            else
                if self.pumpFillEfficiency.currentTime > 0 then
                    self.pumpFillEfficiency.currentTime = math.max(self.pumpFillEfficiency.currentTime - dt, 0)
                end
            end
        else
            if self.pumpEfficiency.currentStartUpTime > 0 then
                self.pumpEfficiency.currentStartUpTime = math.max(self.pumpEfficiency.currentStartUpTime - dt, 0)
            end

            if self.pumpFillEfficiency.currentTime > 0 then
                self.pumpFillEfficiency.currentTime = math.max(self.pumpFillEfficiency.currentTime - dt, 0)
            end
        end
    else
        self:setPumpStarted(false, nil, true)
        self.pumpEfficiency.currentStartUpTime = 0
        self.pumpFillEfficiency.currentTime = 0
    end

    self.pumpEfficiency.currentScale = Utils.clamp(self.pumpEfficiency.currentStartUpTime / self.pumpEfficiency.startUpTime, 0, 1)
    self.pumpFillEfficiency.currentScale = Utils.clamp(self.pumpFillEfficiency.currentTime / self.pumpFillEfficiency.maxTime, 0, 1)

    if self.isClient then
        if self.pumpIsStarted then
            if self.pumpEfficiency.currentScale ~= 0 then
                if self:getIsActiveForSound(true) then
                    SoundUtil.playSample(self.samplePump, 0, 0, nil)
                    SoundUtil.stop3DSample(self.samplePump)
                    SoundUtil.setSampleVolume(self.samplePump, math.max(self.pumpEfficiency.currentScale, 0.08))
                else
                    SoundUtil.stopSample(self.samplePump)
                    SoundUtil.play3DSample(self.samplePump)
                end
            else
                SoundUtil.stopSample(self.samplePump)
                SoundUtil.stop3DSample(self.samplePump)
            end
        else
            SoundUtil.stopSample(self.samplePump)
            SoundUtil.stop3DSample(self.samplePump)
        end
    end
end

---
--
function HoseSystemPumpMotor:draw()
    if self.attacherMotor.isStarted then
        if self.warningMessage.currentId ~= HoseSystemPumpMotor.NONE then
            g_currentMission:showBlinkingWarning(self.warningMessage.messages[self.warningMessage.currentId])
        end

        if self:getFillDirection() == HoseSystemPumpMotor.IN then
            if self.fillObjectFound or self.fillFromFillVolume then
                if not self.pumpIsStarted then -- get fillLevel of object, we got no value to access it for clients
                    g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_activatePump'), InputBinding.ACTIVATE_OBJECT)
                else
                    g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_deactivatePump'), InputBinding.ACTIVATE_OBJECT)
                end
            elseif self.pumpIsStarted then
                g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_deactivatePump'), InputBinding.ACTIVATE_OBJECT)
            end
        else
            if self.fillObjectFound or self.fillFromFillVolume then
                if not self.pumpIsStarted then
                    if self.fillUnitIndex ~= 0 then
                        local fillType = self.fillUnits[self.fillUnitIndex].currentFilltype

                        if self:getFillLevel(fillType) > 0 then
                            g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_activatePump'), InputBinding.ACTIVATE_OBJECT)
                        end
                    end
                else
                    g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_deactivatePump'), InputBinding.ACTIVATE_OBJECT)
                end
            elseif self.pumpIsStarted then
                g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_deactivatePump'), InputBinding.ACTIVATE_OBJECT)
            end
        end

        if not self.pumpIsStarted then
            if self.pumpEfficiency.currentScale < self.pumpEfficiency.scaleLimit then
                g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_changeDirection'):format(self:getFillDirection() == HoseSystemPumpMotor.IN and g_i18n:getText('pumpMotor_directionOut') or g_i18n:getText('pumpMotor_directionIn')), InputBinding.IMPLEMENT_EXTRA4)
            end
        end
    end
end

---
-- @param attacherVehicle
-- @param jointDescIndex
--
function HoseSystemPumpMotor:onAttach(attacherVehicle, jointDescIndex)
    self.attacherMotor.check = true
end

---
-- @param attacherVehicle
-- @param jointDescIndex
--
function HoseSystemPumpMotor:onDetach(attacherVehicle, jointDescIndex)
    self.warningMessage.currentId = HoseSystemPumpMotor.NONE
    self.attacherMotor.check = false
    self.attacherMotor.isStarted = false

    if self.isClient then
        SoundUtil.stop3DSample(self.samplePump)
    end
end

---
--
function HoseSystemPumpMotor:onDeactivate()
    self:setPumpStarted(false, nil, true)
end

---
--
function HoseSystemPumpMotor:getFillMode()
    return self.fillMode
end

---
-- @param int
-- @param noEventSend
--
function HoseSystemPumpMotor:setFillMode(int, noEventSend)
    self.fillMode = math.floor(int) -- cast it to int!

    SetFillModeEvent.sendEvent(self, int, noEventSend)
end

---
--
function HoseSystemPumpMotor:getFillDirection()
    return self.fillDirection
end

---
-- @param int
-- @param noEventSend
--
function HoseSystemPumpMotor:setFillDirection(int, noEventSend)
    self.fillDirection = int > HoseSystemPumpMotor.OUT and HoseSystemPumpMotor.IN or int

    SetFillDirectionEvent.sendEvent(self, int, noEventSend)
end

---
-- @param isStarted
-- @param noEventSend
--
function HoseSystemPumpMotor:setPumpStarted(isStarted, warningId, noEventSend)
    if self.pumpIsStarted ~= isStarted then
        self.pumpIsStarted = isStarted
        self.allowsSpraying = not isStarted -- disable manure tankers to start emptying while pumping

        self:setIsTurnedOn(isStarted)

        if not isStarted and warningId ~= nil and self.isClient then
            self:setWarningMessage(warningId)
        end

        SetPumpStartedEvent.sendEvent(self, isStarted, warningId, noEventSend)
    end
end

---
--
function HoseSystemPumpMotor:allowPumpStarted()
    local fillMode = self:getFillMode()

    if HoseSystemPumpMotor.allowFillMode(fillMode) then
        if self.fillUnitIndex == 0 then
            return false
        end

        if self:getFillDirection() == HoseSystemPumpMotor.IN then
            if not self.fillObjectFound and not self.fillFromFillVolume then
                return false
            end
        else
            local fillType = self.fillUnits[self.fillUnitIndex].currentFilltype

            if (self:getFillLevel(fillType) <= 0 or not self.fillObjectFound and not self.fillFromFillVolume) then
                return false
            end
        end
    else
        return false
    end

    return true
end

---
-- @param dt
-- @param targetFillLevel
-- @param targetFillType
-- @param scale
--
function HoseSystemPumpMotor:pumpIn(dt, targetFillLevel, targetFillType, scale)
    if not self.isServer or self:getFillDirection() ~= HoseSystemPumpMotor.IN then
        return
    end

    if self.pumpFillEfficiency.currentScale > 0 then
        local deltaFillLevel = math.min((self.pumpFillEfficiency.litersPerSecond * self.pumpFillEfficiency.currentScale) * 0.001 * dt, targetFillLevel)

        self:doPump(self.fillObject, targetFillType, deltaFillLevel, self.fillVolumeDischargeInfos[self.pumpMotor.dischargeInfoIndex], self.fillObjectIsObject)
    end
end

---
-- @param dt
-- @param scale
--
function HoseSystemPumpMotor:pumpOut(dt, scale)
    if not self.isServer or self:getFillDirection() ~= HoseSystemPumpMotor.OUT then
        return
    end

    local fillType = self:getUnitLastValidFillType(self.fillUnitIndex)
    local fillLevel = self:getFillLevel(fillType)

    -- we checked that the fillObject accepts the fillType already
    if fillLevel > 0 then
        local deltaFillLevel = math.min((self.pumpFillEfficiency.litersPerSecond * self.pumpFillEfficiency.currentScale) * 0.001 * dt, fillLevel)

        self:doPump(self.fillObject, fillType, deltaFillLevel, self.fillVolumeUnloadInfos[self.pumpMotor.unloadInfoIndex], self.fillObjectIsObject)
    else
        self:setPumpStarted(false)
    end
end

---
-- @param targetObject
-- @param fillType
-- @param deltaFill
-- @param fillInfo
-- @param isTrigger
--
function HoseSystemPumpMotor:doPump(targetObject, fillType, deltaFill, fillInfo, isTrigger)
    local fillDirection = self:getFillDirection()
    local fillLevel = self:getUnitFillLevel(self.fillUnitIndex)
    local targetObjectFillLevel = targetObject:getFillLevel(fillType)

    self:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and fillLevel + deltaFill or fillLevel - deltaFill, fillType, false, fillInfo)

    if fillDirection == HoseSystemPumpMotor.OUT then
        targetObject:resetFillLevelIfNeeded(fillType)
    end

    if self.fillFromFillVolume then -- Todo: Lookup new fill volume changes
        local fillVolumeInfo = fillDirection == HoseSystemPumpMotor.IN and self.fillVolumeLoadInfo or self.fillVolumeDischargeInfo
        local x, y, z = getWorldTranslation(fillVolumeInfo.node)
        local d1x, d1y, d1z = localDirectionToWorld(fillVolumeInfo.node, fillVolumeInfo.width, 0, 0)
        local d2x, d2y, d2z = localDirectionToWorld(fillVolumeInfo.node, 0, 0, fillVolumeInfo.length)
        local fillSourceStruct = { x = x, y = y, z = z, d1x = d1x, d1y = d1y, d1z = d1z, d2x = d2x, d2y = d2y, d2z = d2z }

        targetObject:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and targetObjectFillLevel - deltaFill or targetObjectFillLevel + deltaFill, fillType, false, fillSourceStruct)

        if fillDirection == HoseSystemPumpMotor.OUT then
            if targetObjectFillLevel >= (targetObject:getCapacity(fillType) * self.autoStopPercentage.outDirection) then
                self:setPumpStarted(false)
            end
        end
    else
        if isTrigger then
            targetObject:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and targetObjectFillLevel - deltaFill or targetObjectFillLevel + deltaFill)
        else
            targetObject:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and targetObjectFillLevel - deltaFill or targetObjectFillLevel + deltaFill, fillType)
        end

        if fillDirection == HoseSystemPumpMotor.OUT then
            if targetObjectFillLevel >= (targetObject:getCapacity(fillType) * self.autoStopPercentage.outDirection) then
                self:setPumpStarted(false)
            end
        end
    end
end

---
-- @param fillType
-- @param deltaFill
-- @param fillInfo
--
function HoseSystemPumpMotor:doFakePump(fillType, deltaFill, fillInfo)
    self:setFillLevel(deltaFill, fillType, true)
end

---
-- @param superFunc
--
function HoseSystemPumpMotor:getIsTurnedOn(superFunc)
    return self.pumpIsStarted and true or superFunc(self)
end

---
-- @param superFunc
-- @param isTurnedOn
--
function HoseSystemPumpMotor:getIsTurnedOnAllowed(superFunc, isTurnedOn)
    if self.fillObjectFound or self.pumpIsStarted then
        return false
    end

    return superFunc(self, isTurnedOn)
end

---
-- @param superFunc
--
function HoseSystemPumpMotor:getConsumedPtoTorque(superFunc)
    if self.pumpIsStarted then
        local rpm = superFunc(self) * 3

        return rpm * self.pumpEfficiency.currentScale
    end

    return superFunc(self)
end

---
-- @param id
--
function HoseSystemPumpMotor:setWarningMessage(id)
    self.warningMessage.currentId = id
    self.warningMessage.currentTime = 0
end

---
-- @param message
--
function HoseSystemPumpMotor:showWarningMessage(message)
    g_currentMission:showBlinkingWarning(message)
end

---
-- @param object
-- @param fillMode
--
function HoseSystemPumpMotor:addFillObject(object, fillMode)
    if not self.isServer then
        return
    end

    if not HoseSystemPumpMotor.allowFillMode(fillMode) then
        return
    end

    local allowedFillUnitIndex = self:getAllowedFillUnitIndex(object)

    -- Todo: lookup table insertings on multiple fill objects
    if allowedFillUnitIndex ~= 0 then
        if self:getFillMode() ~= fillMode then
            self:setFillMode(fillMode)
        end

        self.fillObject = object
        self.fillObjectFound = true
        self.fillFromFillVolume = false -- not implemented
        self.fillObjectIsObject = object:isa(FillTrigger) -- or Object.. but we are actually pumping from a map trigger

        if object.checkPlaneY ~= nil then
            self.fillObjectHasPlane = true
        end

        self.fillUnitIndex = allowedFillUnitIndex
    end

    self:updateFillObject()
end

---
-- @param object
-- @param fillMode
--
function HoseSystemPumpMotor:removeFillObject(object, fillMode)
    if not self.isServer then
        return
    end

    if self:getFillMode() == fillMode then
        -- Todo: lookup table insertings on multiple fill objects

        self.fillObject = nil
        self.fillObjectFound = false
        self.fillFromFillVolume = false -- not implemented
        self.fillObjectIsObject = false
        self.fillObjectHasPlane = false
        self.fillUnitIndex = 0

        self:updateFillObject()
    end
end

---
--
function HoseSystemPumpMotor:updateFillObject()
    if self.lastFillObjectFound ~= self.fillObjectFound or self.lastFillFromFillVolume ~= self.fillFromFillVolume or self.lastFillUnitIndex ~= self.fillUnitIndex or self.lastFillObjectHasPlane ~= self.fillObjectHasPlane then
        g_server:broadcastEvent(SendUpdateOnFillEvent:new(self, self.fillObjectFound, self.fillFromFillVolume, self.fillUnitIndex, self.fillObjectHasPlane))

        self.lastFillUnitIndex = self.fillUnitIndex
        self.lastFillObjectFound = self.fillObjectFound
        self.lastFillFromFillVolume = self.fillFromFillVolume
        self.lastFillObjectHasPlane = self.fillObjectHasPlane
    end
end

---
-- @param object
--
function HoseSystemPumpMotor:getAllowedFillUnitIndex(object)
    if self.fillUnits == nil then
        return 0
    end

    for index, fillUnit in pairs(self.fillUnits) do
        if fillUnit.currentFillType ~= FillUtil.FILLTYPE_UNKNOWN then
            if object:allowFillType(fillUnit.currentFillType) then
                return index
            end
        else
            local fillTypes = self:getUnitFillTypes(index)

            for fillType, bool in pairs(fillTypes) do
                -- check if object accepts any of our fillTypes
                if object:allowFillType(fillType) then
                    return index
                end
            end
        end
    end

    return 0
end

--

SetPumpStartedEvent = {}
SetPumpStartedEvent_mt = Class(SetPumpStartedEvent, Event)

InitEventClass(SetPumpStartedEvent, 'SetPumpStartedEvent')

function SetPumpStartedEvent:emptyNew()
    local event = Event:new(SetPumpStartedEvent_mt)
    return event
end

function SetPumpStartedEvent:new(object, isStarted, warningId)
    local event = SetPumpStartedEvent:emptyNew()

    event.object = object
    event.isStarted = isStarted
    event.warningId = warningId

    return event
end

function SetPumpStartedEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.isStarted = streamReadBool(streamId)

    if streamReadBool(streamId) then
        self.warningId = streamReadUInt8(streamId)
    end

    self:run(connection)
end

function SetPumpStartedEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.isStarted)
    streamWriteBool(streamId, self.warningId ~= nil)

    if self.warningId ~= nil then
        streamWriteUInt8(streamId, self.warningId)
    end
end

function SetPumpStartedEvent:run(connection)
    self.object:setPumpStarted(self.isStarted, self.warningId, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function SetPumpStartedEvent.sendEvent(object, isStarted, warningId, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetPumpStartedEvent:new(object, isStarted, warningId), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SetPumpStartedEvent:new(object, isStarted, warningId))
        end
    end
end

--

SetFillDirectionEvent = {}
SetFillDirectionEvent_mt = Class(SetFillDirectionEvent, Event)

InitEventClass(SetFillDirectionEvent, 'SetFillDirectionEvent')

function SetFillDirectionEvent:emptyNew()
    local event = Event:new(SetFillDirectionEvent_mt)
    return event
end

function SetFillDirectionEvent:new(object, int)
    local event = SetFillDirectionEvent:emptyNew()

    event.object = object
    event.int = int

    return self
end

function SetFillDirectionEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.int = streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits)

    self:run(connection)
end

function SetFillDirectionEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.int, HoseSystemPumpMotor.sendNumBits)
end

function SetFillDirectionEvent:run(connection)
    self.object:setFillDirection(self.int, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function SetFillDirectionEvent.sendEvent(object, int, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetFillDirectionEvent:new(object, int), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SetFillDirectionEvent:new(object, int))
        end
    end
end

--

SetFillModeEvent = {}
SetFillModeEvent_mt = Class(SetFillModeEvent, Event)

InitEventClass(SetFillModeEvent, 'SetFillModeEvent')

function SetFillModeEvent:emptyNew()
    local event = Event:new(SetFillModeEvent_mt)
    return event
end

function SetFillModeEvent:new(object, int)
    local event = SetFillModeEvent:emptyNew()

    event.object = object
    event.int = int

    return event
end

function SetFillModeEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.int = streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits)

    self:run(connection)
end

function SetFillModeEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.int, HoseSystemPumpMotor.sendNumBits)
end

function SetFillModeEvent:run(connection)
    self.object:setFillMode(self.int, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function SetFillModeEvent.sendEvent(object, int, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetFillModeEvent:new(object, int), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SetFillModeEvent:new(object, int))
        end
    end
end

--

IsSuckingEvent = {}
IsSuckingEvent_mt = Class(IsSuckingEvent, Event)

InitEventClass(IsSuckingEvent, 'IsSuckingEvent')

function IsSuckingEvent:emptyNew()
    local event = Event:new(IsSuckingEvent_mt)
    return event
end

function IsSuckingEvent:new(object, isSucking)
    local event = IsSuckingEvent:emptyNew()

    event.object = object
    event.isSucking = isSucking

    return event
end

function IsSuckingEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.isSucking)
end

function IsSuckingEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.isSucking = streamReadBool(streamId)

    self:run(connection)
end

function IsSuckingEvent:run(connection)
    self.object.isSucking = self.isSucking
end

--

SendUpdateOnFillEvent = {}
SendUpdateOnFillEvent_mt = Class(SendUpdateOnFillEvent, Event)

InitEventClass(SendUpdateOnFillEvent, 'SendUpdateOnFillEvent')

function SendUpdateOnFillEvent:emptyNew()
    local event = Event:new(SendUpdateOnFillEvent_mt)
    return event
end

function SendUpdateOnFillEvent:new(vehicle, fillObjectFound, fillFromFillVolume, fillUnitIndex, fillObjectHasPlane)
    local event = SendUpdateOnFillEvent:emptyNew()

    event.vehicle = vehicle
    event.fillObjectFound = fillObjectFound
    event.fillFromFillVolume = fillFromFillVolume
    event.fillUnitIndex = fillUnitIndex
    event.fillObjectHasPlane = fillObjectHasPlane

    return event
end

function SendUpdateOnFillEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.fillObjectFound)
    streamWriteBool(streamId, self.fillFromFillVolume)
    streamWriteInt32(streamId, self.fillUnitIndex)
    streamWriteBool(streamId, self.fillObjectHasPlane)
end

function SendUpdateOnFillEvent:readStream(streamId, connection)
    self.vehicle = readNetworkNodeObject(streamId)
    self.fillObjectFound = streamReadBool(streamId)
    self.fillFromFillVolume = streamReadBool(streamId)
    self.fillUnitIndex = streamReadInt32(streamId)
    self.fillObjectHasPlane = streamReadBool(streamId)
    self:run(connection)
end

function SendUpdateOnFillEvent:run(connection)
    self.vehicle.fillObjectFound = self.fillObjectFound
    self.vehicle.fillFromFillVolume = self.fillFromFillVolume
    self.vehicle.fillUnitIndex = self.fillUnitIndex
    self.vehicle.fillObjectHasPlane = self.fillObjectHasPlane
end