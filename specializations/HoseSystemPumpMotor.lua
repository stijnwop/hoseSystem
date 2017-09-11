--
-- HoseSystemPumpMotor
--
-- @author:    	Wopster and Xentro (Marcus@Xentro.se)
-- @history:	v1.0 - 2016-02-14 - Initial implementation
-- 

HoseSystemPumpMotor = {
    sendNumBits = 1,
    fillModes = {}
}

-- DIRECTION --
HoseSystemPumpMotor.IN = 0
HoseSystemPumpMotor.OUT = 1

-- WARNING MESSAGES -- 
HoseSystemPumpMotor.NONE = 0
HoseSystemPumpMotor.POWER_DOWN = 1
HoseSystemPumpMotor.TURN_OFF = 2

function HoseSystemPumpMotor.formatFillModeKey(name)
    return ('mode_%s'):format(name:lower())
end

function HoseSystemPumpMotor.registerFillMode(name)
    local key = HoseSystemPumpMotor.formatFillModeKey(name)

    if HoseSystemPumpMotor.fillModes[key] == nil then
        HoseSystemPumpMotor.fillModes[key] = #HoseSystemPumpMotor.fillModes + 1
    end
end

function HoseSystemPumpMotor.allowFillMode(fillMode)
    for key, value in pairs(HoseSystemPumpMotor.fillModes) do
        if value == fillMode then
            return true
        end
    end

    return false
end

function HoseSystemPumpMotor.getInitialFillMode(name)
    local key = HoseSystemPumpMotor.formatFillModeKey(name)

    if HoseSystemPumpMotor.fillModes[key] ~= nil then
        return HoseSystemPumpMotor.fillModes[key]
    end

    return nil
end

function HoseSystemPumpMotor.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Fillable, specializations)
end

function HoseSystemPumpMotor:load(savegame)
    if not self.hasHoseSystemPumpMotor then
        return
    end

    self.getFillMode = HoseSystemPumpMotor.getFillMode
    self.setFillMode = SpecializationUtil.callSpecializationsFunction('setFillMode')
    self.getFillDirection = HoseSystemPumpMotor.getFillDirection
    self.setFillDirection = SpecializationUtil.callSpecializationsFunction('setFillDirection')
    self.allowPumpStarted = HoseSystemPumpMotor.allowPumpStarted
    self.setPumpStarted = SpecializationUtil.callSpecializationsFunction('setPumpStarted')
    self.doPump = HoseSystemPumpMotor.doPump
    self.doFakePump = HoseSystemPumpMotor.doFakePump
    self.getIsTurnedOn = Utils.overwrittenFunction(self.getIsTurnedOn, HoseSystemPumpMotor.getIsTurnedOn)
    self.getIsTurnedOnAllowed = Utils.overwrittenFunction(self.getIsTurnedOnAllowed, HoseSystemPumpMotor.getIsTurnedOnAllowed)
    self.getConsumedPtoTorque = Utils.overwrittenFunction(self.getConsumedPtoTorque, HoseSystemPumpMotor.getConsumedPtoTorque)
    -- self.setIsTurnedOn = Utils.overwrittenFunction(self.setIsTurnedOn, HoseSystemPumpMotor.setIsTurnedOn)

    self.attacherMotor = {
        check = false,
        isStarted = false
    }

    self.pumpIsStarted = false
    self.fillMode = 0 -- 0 is nothing
    self.fillDirection = HoseSystemPumpMotor.IN

    self.pumpEfficiency = {
        currentScale = 0,
        scaleLimit = 0.1, -- when we can change fill direction
        currentStartUpTime = 0,
        startUpTime = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#startUpTime"), 1500)
    }

    local maxTime = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#toReachMaxEfficiencyTime"), 1500)
    self.pumpFillEfficiency = {
        currentScale = 0,
        currentTime = 0,
        maxTimeStatic = maxTime,
        maxTime = maxTime, -- TODO: let the hose determine this, hose on hose would delay this!
        litersPerSecond = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#litersPerSecond"), 100)
    }

    self.autoStopPercentage = {
        inDirection = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#autoStopPercentageIn"), 0.99),
        outDirection = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#autoStopPercentageOut"), 0.98)
    }

    if self.isClient then
        local linkNode = Utils.indexToObject(self.components, Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.pumpMotor#linkNode"), "0>"))
        self.samplePump = SoundUtil.loadSample(self.xmlFile, {}, "vehicle.pumpSound", nil, self.baseDirectory, linkNode)
    end

    -- Function warningMessage.. instead of switching stuff around
    self.warningMessage = {}
    self.warningMessage.currentId = HoseSystemPumpMotor.NONE
    self.warningMessage.currentTime = 0
    self.warningMessage.howLongToShow = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#warningTime"), 1500)
    self.warningMessage.messages = {}
    self.warningMessage.messages[HoseSystemPumpMotor.POWER_DOWN] = g_i18n:getText('pumpMotor_warningPowerDown')
    self.warningMessage.messages[HoseSystemPumpMotor.TURN_OFF] = g_i18n:getText('pumpMotor_warningTurnOffFirst')

    self.pumpMotor = {
        unloadInfoIndex = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.pumpMotor#unloadInfoIndex"), 1),
        dischargeInfoIndex = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.pumpMotor#dischargeInfoIndex"), 1),
        ptoRpm = self.powerConsumer.ptoRpm
    }
end

function HoseSystemPumpMotor:delete()
    if not self.hasHoseSystemPumpMotor then
        return
    end

    if self.isClient then
        SoundUtil.deleteSample(self.samplePump)
    end
end

function HoseSystemPumpMotor:readStream(streamId, connection)
    if not self.hasHoseSystemPumpMotor then
        return
    end

    self:setPumpStarted(streamReadBool(streamId), true)
    self:setFillDirection(streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits), true)
    self:setFillMode(streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits), true)
end

function HoseSystemPumpMotor:writeStream(streamId, connection)
    if not self.hasHoseSystemPumpMotor then
        return
    end

    streamWriteBool(streamId, self.pumpIsStarted)
    streamWriteUIntN(streamId, self.fillDirection, HoseSystemPumpMotor.sendNumBits)
    streamWriteUIntN(streamId, self.fillMode, HoseSystemPumpMotor.sendNumBits)
end

function HoseSystemPumpMotor:mouseEvent(posX, posY, isDown, isUp, button)
end

function HoseSystemPumpMotor:keyEvent(unicode, sym, modifier, isDown)
end

function HoseSystemPumpMotor:update(dt)
    if not self.hasHoseSystemPumpMotor then
        return
    end

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
                        else
                            self.warningMessage.currentId = HoseSystemPumpMotor.POWER_DOWN
                            self.warningMessage.currentTime = 0
                        end
                    else -- TODO: Move down isn't right..
                        self.warningMessage.currentId = HoseSystemPumpMotor.TURN_OFF
                        self.warningMessage.currentTime = 0
                    end
                end
            end
        end
    end
end

function HoseSystemPumpMotor:updateTick(dt)
    if not self.hasHoseSystemPumpMotor then
        return
    end

    if self.attacherMotor.check then
        local vehicle = self:getRootAttacherVehicle()
        self.attacherMotor.isStarted = vehicle.isMotorStarted ~= nil and vehicle.isMotorStarted
        local implement = self.attacherVehicle:getImplementByObject(self)
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
            if self.pumpEfficiency.currentScale < self.pumpEfficiency.scaleLimit then
                if self.warningMessage.currentId == HoseSystemPumpMotor.POWER_DOWN then
                    self.warningMessage.currentId = HoseSystemPumpMotor.NONE
                end
            end

            if self.pumpEfficiency.currentStartUpTime < self.pumpEfficiency.startUpTime then
                self.pumpEfficiency.currentStartUpTime = math.min(self.pumpEfficiency.currentStartUpTime + dt, self.pumpEfficiency.startUpTime)
            end

            local updateFillScale = false

            if self.fillUnitIndex ~= 0 then
                local fillType = self.fillUnits[self.fillUnitIndex].currentFilltype

                if self:getFillDirection() == HoseSystemPumpMotor.IN then
                    if self:getFillLevel(fillType) / self:getCapacity(fillType) >= self.autoStopPercentage.inDirection then
                        self:setPumpStarted(false, true)
                    end

                    if self.isSucking then
                        updateFillScale = true
                    end
                else
                    if self:getFillLevel(fillType) <= 0 or not self.fillObjectFound and not self.fillFromFillVolume then
                        self:setPumpStarted(false, true)
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
        self:setPumpStarted(false, true)
        self.pumpEfficiency.currentStartUpTime = 0
        self.pumpFillEfficiency.currentTime = 0
    end

    self.pumpEfficiency.currentScale = Utils.clamp(self.pumpEfficiency.currentStartUpTime / self.pumpEfficiency.startUpTime, 0, 1)
    self.pumpFillEfficiency.currentScale = Utils.clamp(self.pumpFillEfficiency.currentTime / self.pumpFillEfficiency.maxTime, 0, 1)

    -- TODO: only play sound on the vehicle that pumps!
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

function HoseSystemPumpMotor:draw()
    if not self.hasHoseSystemPumpMotor then
        return
    end

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
                            -- else
                            -- vehicle is empty
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

function HoseSystemPumpMotor:onAttach(attacherVehicle, jointDescIndex)
    if not self.hasHoseSystemPumpMotor then
        return
    end

    self.attacherMotor.check = true
end

function HoseSystemPumpMotor:onDetach(attacherVehicle, jointDescIndex)
    if not self.hasHoseSystemPumpMotor then
        return
    end

    self.warningMessage.currentId = HoseSystemPumpMotor.NONE
    self.attacherMotor.check = false
    self.attacherMotor.isStarted = false

    if self.isClient then
        SoundUtil.stop3DSample(self.samplePump)
    end
end

function HoseSystemPumpMotor:onDeactivate()
    if not self.hasHoseSystemPumpMotor then
        return
    end

    self:setPumpStarted(false, true)
end

function HoseSystemPumpMotor:getFillMode()
    return self.fillMode
end

function HoseSystemPumpMotor:setFillMode(int, noEventSend)
    self.fillMode = math.floor(int) -- cast it to int!

    setFillModeEvent.sendEvent(self, int, noEventSend)
end

function HoseSystemPumpMotor:getFillDirection()
    return self.fillDirection
end

function HoseSystemPumpMotor:setFillDirection(int, noEventSend)
    self.fillDirection = int > HoseSystemPumpMotor.OUT and 0 or int

    setFillDirectionEvent.sendEvent(self, int, noEventSend)
end

function HoseSystemPumpMotor:setPumpStarted(isStarted, noEventSend)
    if self.pumpIsStarted ~= isStarted then
        self.pumpIsStarted = isStarted
        self.allowsSpraying = not isStarted -- THIS

        self:setIsTurnedOn(isStarted)

        setPumpStartedEvent.sendEvent(self, isStarted, noEventSend)
    end
end

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

function HoseSystemPumpMotor:doPump(targetObject, fillType, deltaFill, fillInfo)
    local fillDirection = self:getFillDirection()
    local fillLevel = self:getUnitFillLevel(self.fillUnitIndex)
    local targetObjectFillLevel = targetObject:getFillLevel(fillType)

    self:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and fillLevel + deltaFill or fillLevel - deltaFill, fillType, false, fillInfo)

    if fillDirection == HoseSystemPumpMotor.OUT then
        targetObject:resetFillLevelIfNeeded(fillType)
    end

    if self.fillFromFillVolume then
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
        targetObject:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and targetObjectFillLevel - deltaFill or targetObjectFillLevel + deltaFill, fillType)

        if fillDirection == HoseSystemPumpMotor.OUT then
            if targetObjectFillLevel >= (targetObject:getCapacity(fillType) * self.autoStopPercentage.outDirection) then
                self:setPumpStarted(false)
            end
        end
    end
end


function HoseSystemPumpMotor:doFakePump(fillType, deltaFill, fillInfo)
    self:setFillLevel(deltaFill, fillType, true)
end

function HoseSystemPumpMotor:getIsTurnedOn(superFunc)
    return self.pumpIsStarted and true or superFunc(self)
end

function HoseSystemPumpMotor:getIsTurnedOnAllowed(superFunc, isTurnedOn)
    if self.fillObjectFound or self.pumpIsStarted then
        return false
    end

    return superFunc(self)
end

function HoseSystemPumpMotor:getConsumedPtoTorque(superFunc)
    if self.pumpIsStarted then
        local rpm = superFunc(self) * 3

        return rpm * self.pumpEfficiency.currentScale
    end

    return superFunc(self)
end

function HoseSystemPumpMotor:showWarningMessage(message)
    g_currentMission:showBlinkingWarning(message)
end

-- Todo: FS17 has something else to this..

-- Manual Ignition keeps tool active if pump is on!
-- function HoseSystemPumpMotor:getIsTurnedOn(oldFunc)
-- if self.pumpIsStarted then
-- return true;
-- end;

-- return oldFunc(self);
-- end;

-- Event
setPumpStartedEvent = {}
setPumpStartedEvent_mt = Class(setPumpStartedEvent, Event)

InitEventClass(setPumpStartedEvent, "setPumpStartedEvent")

function setPumpStartedEvent:emptyNew()
    local self = Event:new(setPumpStartedEvent_mt)
    self.className = "setPumpStartedEvent"

    return self
end

function setPumpStartedEvent:new(vehicle, isStarted)
    local self = setPumpStartedEvent:emptyNew();
    self.vehicle = vehicle;
    self.isStarted = isStarted;

    return self
end

function setPumpStartedEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
    self.vehicle = networkGetObject(id);
    self.isStarted = streamReadBool(streamId);
    self:run(connection);
end

function setPumpStartedEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
    streamWriteBool(streamId, self.isStarted);
end

function setPumpStartedEvent:run(connection)
    self.vehicle:setPumpStarted(self.isStarted, true);

    if not connection:getIsServer() then
        g_server:broadcastEvent(setPumpStartedEvent:new(self.vehicle, self.isStarted), nil, connection, self.object);
    end;
end

function setPumpStartedEvent.sendEvent(vehicle, isStarted, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(setPumpStartedEvent:new(vehicle, isStarted), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(setPumpStartedEvent:new(vehicle, isStarted));
        end;
    end;
end

---

setFillDirectionEvent = {};
setFillDirectionEvent_mt = Class(setFillDirectionEvent, Event);

InitEventClass(setFillDirectionEvent, "setFillDirectionEvent");

function setFillDirectionEvent:emptyNew()
    local self = Event:new(setFillDirectionEvent_mt);
    self.className = "setFillDirectionEvent";

    return self;
end

function setFillDirectionEvent:new(vehicle, int)
    local self = setFillDirectionEvent:emptyNew();
    self.vehicle = vehicle;
    self.int = int;

    return self;
end

function setFillDirectionEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
    self.vehicle = networkGetObject(id);
    self.int = streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits);
    self:run(connection);
end

function setFillDirectionEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
    streamWriteUIntN(streamId, self.int, HoseSystemPumpMotor.sendNumBits);
end

function setFillDirectionEvent:run(connection)
    self.vehicle:setFillDirection(self.int, true);

    if not connection:getIsServer() then
        g_server:broadcastEvent(setFillDirectionEvent:new(self.vehicle, self.int), nil, connection, self.object);
    end;
end

function setFillDirectionEvent.sendEvent(vehicle, int, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(setFillDirectionEvent:new(vehicle, int), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(setFillDirectionEvent:new(vehicle, int));
        end;
    end;
end

---

setFillModeEvent = {}
setFillModeEvent_mt = Class(setFillModeEvent, Event)

InitEventClass(setFillModeEvent, "setFillModeEvent")

function setFillModeEvent:emptyNew()
    local self = Event:new(setFillModeEvent_mt);
    self.className = "setFillModeEvent";

    return self;
end

function setFillModeEvent:new(vehicle, int)
    local self = setFillModeEvent:emptyNew();
    self.vehicle = vehicle;
    self.int = int;

    return self;
end

function setFillModeEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
    self.vehicle = networkGetObject(id);
    self.int = streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits);
    self:run(connection);
end

function setFillModeEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
    streamWriteUIntN(streamId, self.int, HoseSystemPumpMotor.sendNumBits);
end

function setFillModeEvent:run(connection)
    self.vehicle:setFillMode(self.int, true);

    if not connection:getIsServer() then
        g_server:broadcastEvent(setFillModeEvent:new(self.vehicle, self.int), nil, connection, self.object);
    end;
end

function setFillModeEvent.sendEvent(vehicle, int, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(setFillModeEvent:new(vehicle, int), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(setFillModeEvent:new(vehicle, int));
        end;
    end;
end

---
-- Extern accessible events

IsSuckingEvent = {}
IsSuckingEvent_mt = Class(IsSuckingEvent, Event)

InitEventClass(IsSuckingEvent, 'IsSuckingEvent')

function IsSuckingEvent:emptyNew()
    local self = Event:new(IsSuckingEvent_mt)
    self.className = 'IsSuckingEvent'

    return self
end

function IsSuckingEvent:new(vehicle, isSucking)
    local self = IsSuckingEvent:emptyNew()

    self.vehicle = vehicle
    self.isSucking = isSucking

    return self
end

function IsSuckingEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isSucking)
end

function IsSuckingEvent:readStream(streamId, connection)
    self.vehicle = readNetworkNodeObject(streamId)
    self.isSucking = streamReadBool(streamId)
    self:run(connection)
end

function IsSuckingEvent:run(connection)
    self.vehicle.isSucking = self.isSucking
end

SendUpdateOnFillEvent = {}
SendUpdateOnFillEvent_mt = Class(SendUpdateOnFillEvent, Event)

InitEventClass(SendUpdateOnFillEvent, 'SendUpdateOnFillEvent')

function SendUpdateOnFillEvent:emptyNew()
    local self = Event:new(SendUpdateOnFillEvent_mt)
    self.className = 'SendUpdateOnFillEvent'

    return self
end

function SendUpdateOnFillEvent:new(vehicle, fillObjectFound, fillFromFillVolume, fillUnitIndex, fillObjectHasPlane)
    local self = SendUpdateOnFillEvent:emptyNew()

    self.vehicle = vehicle
    self.fillObjectFound = fillObjectFound
    self.fillFromFillVolume = fillFromFillVolume
    self.fillUnitIndex = fillUnitIndex
    self.fillObjectHasPlane = fillObjectHasPlane

    return self
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