-- Drive lever specialization allowing to control the tractor with a joystick

DriveLever = {}

function DriveLever.prerequisitesPresent(specializations)
    return true
end

function DriveLever.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "debug", DriveLever.debug)
    SpecializationUtil.registerFunction(vehicleType, "changeDirection", DriveLever.changeDirection)
    SpecializationUtil.registerFunction(vehicleType, "changeSpeed", DriveLever.changeSpeed)
    SpecializationUtil.registerFunction(vehicleType, "getMaxSpeed", DriveLever.getMaxSpeed)
    SpecializationUtil.registerFunction(vehicleType, "setStop", DriveLever.setStop)
    SpecializationUtil.registerFunction(vehicleType, "setEnabled", DriveLever.setEnabled)
    SpecializationUtil.registerFunction(vehicleType, "accelerateToMax", DriveLever.accelerateToMax)
    SpecializationUtil.registerFunction(vehicleType, "toggleAxes", DriveLever.toggleAxes)
    SpecializationUtil.registerFunction(vehicleType, "saveConfigXml", DriveLever.saveConfigXml)
    SpecializationUtil.registerFunction(vehicleType, "loadConfigXml", DriveLever.loadConfigXml)
end

function DriveLever.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", DriveLever);
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", DriveLever);
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", DriveLever);
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", DriveLever);
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", DriveLever)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", DriveLever)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", DriveLever)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", DriveLever)
end

function DriveLever:onLoad(savegame)
    local spec = self.spec_driveLever

    spec.version = "0.5.0.0"
    spec.debug = false

    spec.isEnabled = false

    spec.vehicle = {}
    spec.vehicle.targetSpeed = 0
    spec.vehicle.targetSpeedSent = 0
    spec.vehicle.maxSpeedAdvance = 3
    spec.vehicle.brakeForce = 0.5
    spec.vehicle.stop = false
    spec.vehicle.isStopped = nil
    spec.vehicle.isWorking = false
    spec.vehicle.limitAcceleration = true
    spec.vehicle.maxSpeed = {}
    spec.vehicle.maxSpeed.cruise = 0
    spec.vehicle.maxSpeed.working = 0
    spec.vehicle.maxSpeed.savedCruise = 0
    spec.vehicle.maxSpeed.savedCruiseToggle = 0
    spec.vehicle.maxSpeed.savedWorking = 0
    spec.vehicle.maxSpeed.savedWorkingToggle = 0

    spec.input = {}
    spec.input.changed = false
    spec.input.useFrontloaderAxes = true

    spec.input.forward = {}
    spec.input.forward.value = 0
    spec.input.forward.enabled = true
    spec.input.forward.isAnalog = false
    spec.input.forward.deadzone = 0.01
    spec.input.forward.threshold = 1.1

    spec.input.backward = {}
    spec.input.backward.value = 0
    spec.input.backward.enabled = true
    spec.input.backward.isAnalog = false
    spec.input.backward.deadzone = 0.01
    spec.input.backward.threshold = 0.8

    spec.input.changeDirection = {}
    spec.input.changeDirection.value = 0
    spec.input.changeDirection.enabled = true
    spec.input.changeDirection.deadzone = 0.3

    spec.input.toMax = {}
    spec.input.toMax.value = 0
    spec.input.toMax.enabled = true
    spec.input.toMax.deadzone = 0.3

    spec.input.delay = {}
    spec.input.delay.value = 200
    spec.input.delay.multiplier = 1
    spec.input.delay.current = 0

    spec.dirtyFlag = self:getNextDirtyFlag()

    local fileName = DriveLever.getFileName()
    if not fileExists(fileName) then
        self:saveConfigXml(fileName)
    else
        self:loadConfigXml(fileName)
    end
end

function DriveLever.getFileName()
    local xmlName = "DriveLever.xml"
    if g_dedicatedServerInfo == nil then
        return getUserProfileAppPath() .. "modSettings/" .. xmlName
    else
        return g_currentMission.missionInfo.savegameDirectory .. "/" .. xmlName
    end
end

function DriveLever:loadConfigXml(fileName)
    local spec = self.spec_driveLever
    local xmlFile = loadXMLFile("DriveLever_XML", fileName)

    local version = getXMLString(xmlFile, "DriveLever.version")
    spec.debug = Utils.getNoNil(getXMLBool(xmlFile, "DriveLever.debug"), spec.debug)
    spec.input.useFrontloaderAxes = Utils.getNoNil(getXMLBool(xmlFile, "DriveLever.useFrontloaderAxes"), spec.input.useFrontloaderAxes)
    spec.vehicle.brakeForce = Utils.getNoNil(getXMLFloat(xmlFile, "DriveLever.vehicleBrakeForce"), spec.vehicle.brakeForce)
    spec.vehicle.maxSpeedAdvance = Utils.getNoNil(getXMLFloat(xmlFile, "DriveLever.maxSpeedAdvance"), spec.vehicle.maxSpeedAdvance)
    spec.input.forward.deadzone = Utils.getNoNil(getXMLFloat(xmlFile, "DriveLever.forwardDeadzone"), spec.input.forward.deadzone)
    spec.input.forward.threshold = Utils.getNoNil(getXMLFloat(xmlFile, "DriveLever.forwardThreshold"), spec.input.forward.threshold)
    spec.input.backward.deadzone = Utils.getNoNil(getXMLFloat(xmlFile, "DriveLever.backwardDeadzone"), spec.input.backward.deadzone)
    spec.input.backward.threshold = Utils.getNoNil(getXMLFloat(xmlFile, "DriveLever.backwardThreshold"), spec.input.backward.threshold)
    spec.input.toMax.deadzone = Utils.getNoNil(getXMLFloat(xmlFile, "DriveLever.toMaxDeadzone"), spec.input.toMax.deadzone)
    spec.input.changeDirection.deadzone = Utils.getNoNil(getXMLFloat(xmlFile, "DriveLever.changeDirectionDeadzone"), spec.input.changeDirection.deadzone)

    delete(xmlFile)

    if version ~= spec.version then
        self:saveConfigXml(fileName)
    end
end

function DriveLever:saveConfigXml(fileName)
    local spec = self.spec_driveLever
    local xmlFile = createXMLFile("DriveLever_XML", fileName, "DriveLever")

    setXMLString(xmlFile, "DriveLever.version", spec.version)
    setXMLBool(xmlFile, "DriveLever.debug", spec.debug)
    setXMLBool(xmlFile, "DriveLever.useFrontloaderAxes", spec.input.useFrontloaderAxes)
    setXMLFloat(xmlFile, "DriveLever.vehicleBrakeForce", spec.vehicle.brakeForce)
    setXMLFloat(xmlFile, "DriveLever.maxSpeedAdvance", spec.vehicle.maxSpeedAdvance)
    setXMLFloat(xmlFile, "DriveLever.forwardDeadzone", spec.input.forward.deadzone)
    setXMLFloat(xmlFile, "DriveLever.forwardThreshold", spec.input.forward.threshold)
    setXMLFloat(xmlFile, "DriveLever.backwardDeadzone", spec.input.backward.deadzone)
    setXMLFloat(xmlFile, "DriveLever.backwardThreshold", spec.input.backward.threshold)
    setXMLFloat(xmlFile, "DriveLever.toMaxDeadzone", spec.input.toMax.deadzone)
    setXMLFloat(xmlFile, "DriveLever.changeDirectionDeadzone", spec.input.changeDirection.deadzone)
    saveXMLFile(xmlFile)

    delete(xmlFile)
end

function DriveLever:onUpdate(dt)
    local spec = self.spec_driveLever

    if spec.isEnabled then
        local lastSpeed = self:getLastSpeed()

        if lastSpeed > 0.4 then
            spec.vehicle.isStopped = false
            if spec.vehicle.stop then
                self:brake(spec.vehicle.brakeForce)
            end
        else
            spec.vehicle.isStopped = true
            self:setStop(false)
        end

        if self.isClient then

            -- determine max speeds
            local workingSpeedLimit, isWorking = self:getSpeedLimit(true)
            spec.vehicle.isWorking = isWorking
            spec.vehicle.maxSpeed.cruise = self:getCruiseControlMaxSpeed()
            if isWorking then
                spec.vehicle.maxSpeed.working = math.floor(workingSpeedLimit)
            end

            if self.isActiveForInputIgnoreSelectionIgnoreAI then

                spec.input.delay.current = spec.input.delay.current - (dt * spec.input.delay.multiplier)

                if spec.input.changed then

                    -- change direction
                    if spec.input.changeDirection.enabled and spec.input.changeDirection.value > spec.input.changeDirection.deadzone then
                        spec.input.changeDirection.enabled = false
                        spec.input.forward.enabled = false
                        spec.input.backward.enabled = false
                        self:changeDirection()
                    end

                    -- to max
                    if spec.input.toMax.enabled and spec.input.toMax.value > spec.input.toMax.deadzone then
                        spec.input.toMax.enabled = false
                        spec.input.forward.enabled = false
                        spec.input.backward.enabled = false
                        self:accelerateToMax()
                    end

                    -- stop
                    if spec.input.backward.isAnalog and spec.input.backward.value > spec.input.backward.threshold then
                        spec.input.backward.enabled = false
                        self:setStop(true)
                    end

                    if spec.input.delay.current < 0 then
                        spec.input.delay.current = spec.input.delay.value
                        -- local motor = self.spec_motorized.motor
                        -- local direction = motor.currentDirection

                        -- forward
                        if spec.input.forward.enabled and spec.input.forward.value > spec.input.forward.deadzone then
                            if spec.input.forward.isAnalog and spec.input.forward.value > spec.input.forward.threshold then
                                self:accelerateToMax()
                            else
                                -- change speed
                                local newSpeed = 0
                                if not spec.vehicle.isStopped and self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_OFF then
                                    newSpeed = math.floor(lastSpeed)
                                else
                                    local speedChange = calculateSpeedChangeStep(spec.input.forward.value)
                                    newSpeed = math.ceil(lastSpeed) + speedChange
                                end

                                if newSpeed - lastSpeed > spec.vehicle.maxSpeedAdvance then
                                    newSpeed = math.ceil(lastSpeed) + spec.vehicle.maxSpeedAdvance
                                end
                                self:changeSpeed(newSpeed)
                            end
                        end

                        -- backward
                        if spec.input.backward.enabled and spec.input.backward.value > spec.input.backward.deadzone then
                            -- change speed
                            local newSpeed = 0
                            if not spec.vehicle.isStopped and self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_OFF then
                                newSpeed = lastSpeed
                            else
                                local speedChange = calculateSpeedChangeStep(spec.input.backward.value)
                                newSpeed = lastSpeed - speedChange
                            end

                            if newSpeed > lastSpeed then
                                newSpeed = lastSpeed
                            end

                            newSpeed = math.floor(newSpeed)

                            self:changeSpeed(newSpeed)
                        end
                    end
                    spec.input.changed = false
                else
                    spec.input.forward.enabled = true
                    spec.input.backward.enabled = true
                    spec.input.changeDirection.enabled = true
                    spec.input.toMax.enabled = true

                    spec.input.delay.current = 0
                    spec.input.delay.multiplier = 1
                end

            end

            -- self:debug(spec)

            -- reset for next frame
            spec.input.forward.value = 0
            spec.input.backward.value = 0
            spec.input.changeDirection.value = 0
            spec.input.toMax.value = 0
        end
    end
end

function calculateSpeedChangeStep(inputValue)
    return 5 * math.floor(inputValue * 10) / 10
end

function DriveLever:changeSpeed(targetSpeed)
    local spec = self.spec_driveLever

    targetSpeed = math.min(targetSpeed, self:getMaxSpeed())

    if targetSpeed == spec.vehicle.targetSpeed then
        return
    end

    if targetSpeed < 0 then
        targetSpeed = 0
    end

    spec.vehicle.targetSpeed = targetSpeed

    if spec.vehicle.targetSpeed > 0 then
        if spec.vehicle.targetSpeed < 0.5 then
            spec.vehicle.targetSpeed = 0.5
        end
        local spec_drivable = self.spec_drivable
        self:setStop(false)
        self:setCruiseControlMaxSpeed(spec.vehicle.targetSpeed, spec_drivable.cruiseControl.maxSpeedReverse)

        if spec.vehicle.targetSpeed ~= spec.vehicle.targetSpeedSent then
            if g_server ~= nil then
                g_server:broadcastEvent(SetCruiseControlSpeedEvent.new(self, spec.vehicle.targetSpeed, spec_drivable.cruiseControl.maxSpeedReverse), nil, nil, self)
            else
                g_client:getServerConnection():sendEvent(SetCruiseControlSpeedEvent.new(self, spec.vehicle.targetSpeed, spec_drivable.cruiseControl.maxSpeedReverse))
            end
            spec.vehicle.targetSpeedSent = spec.vehicle.targetSpeed
        end

        self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
    end
    --self:debug(spec.vehicle.targetSpeed)
end

function DriveLever:getMaxSpeed()
    local spec = self.spec_driveLever
    local maxSpeed = 0
    if spec.vehicle.isWorking then
        maxSpeed = spec.vehicle.maxSpeed.working
        if spec.vehicle.limitAcceleration and spec.vehicle.maxSpeed.savedWorking > 0 then
            maxSpeed = spec.vehicle.maxSpeed.savedWorking
        end
    else
        maxSpeed = spec.vehicle.maxSpeed.cruise
        if spec.vehicle.limitAcceleration and spec.vehicle.maxSpeed.savedCruise > 0 then
            maxSpeed = spec.vehicle.maxSpeed.savedCruise
        end
    end
    return maxSpeed
end

function DriveLever:accelerateToMax()
    --print("DriveLever:accelerateToMax")
    local spec = self.spec_driveLever

    if spec.vehicle.isWorking then
        if spec.vehicle.maxSpeed.savedWorking > 0 then
            if spec.vehicle.maxSpeed.savedWorkingToggle > 0 and spec.vehicle.targetSpeed == spec.vehicle.maxSpeed.savedWorking then
                self:changeSpeed(spec.vehicle.maxSpeed.savedWorkingToggle)
            else
                self:changeSpeed(spec.vehicle.maxSpeed.savedWorking)
            end
        else
            self:changeSpeed(spec.vehicle.maxSpeed.working)
        end
    else
        if spec.vehicle.maxSpeed.savedCruise > 0 then
            if spec.vehicle.maxSpeed.savedCruiseToggle > 0 and spec.vehicle.targetSpeed == spec.vehicle.maxSpeed.savedCruise then
                self:changeSpeed(spec.vehicle.maxSpeed.savedCruiseToggle)
            else
                self:changeSpeed(spec.vehicle.maxSpeed.savedCruise)
            end
        else
            self:changeSpeed(spec.vehicle.maxSpeed.cruise)
        end
    end
end

function DriveLever:setEnabled(enabled)
    local spec = self.spec_driveLever
    if enabled ~= spec.isEnabled then
        spec.isEnabled = enabled
        self:raiseDirtyFlags(spec.dirtyFlag)
    end
end

function DriveLever:setStop(stop)
    local spec = self.spec_driveLever
    if stop ~= spec.vehicle.stop then
        spec.vehicle.stop = stop
        self:raiseDirtyFlags(spec.dirtyFlag)

        if spec.vehicle.stop then
            self:changeSpeed(0)
            self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
        end

    end
end

function DriveLever:changeDirection(direction)
    local motor = self.spec_motorized.motor

    if direction == nil then
        MotorGearShiftEvent.sendEvent(self, MotorGearShiftEvent.TYPE_DIRECTION_CHANGE)
    else
        if direction > 0 then
            MotorGearShiftEvent.sendEvent(self, MotorGearShiftEvent.TYPE_DIRECTION_CHANGE_POS)
        else
            MotorGearShiftEvent.sendEvent(self, MotorGearShiftEvent.TYPE_DIRECTION_CHANGE_NEG)
        end
    end
end

function DriveLever:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    --print("DriveLever:onRegisterActionEvents")

    if self.isClient then
        local spec = self.spec_driveLever
        self:clearActionEventsTable(spec.actionEvents)

        --if isActiveForInputIgnoreSelection then
        if self:getIsActiveForInput(true) and spec ~= nil then

            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_TOGGLE, self, DriveLever.actionEventToggle, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_SAVE_CURRENT_CRUISECONTROL_SPEED, self, DriveLever.actionEventSaveSpeed, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_TOGGLE_ACCELERATION_LIMIT, self, DriveLever.actionToggleAccelerationLimit, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
            if spec.input.useFrontloaderAxes then
                _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.AXIS_FRONTLOADER_ARM, self, DriveLever.actionEventChangeSpeed, false, true, true, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, false)
                _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.AXIS_FRONTLOADER_TOOL, self, DriveLever.actionEventChangeDirectionAndMax, false, true, true, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, false)
            else
                _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_FORWARD, self, DriveLever.actionEventForward, false, true, true, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, false)
                _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_BACKWARD, self, DriveLever.actionEventBackward, false, true, true, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, false)
                _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_CHANGE_DIRECTION, self, DriveLever.actionEventChangeDirection, false, true, true, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, false)
                _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_TO_MAX, self, DriveLever.actionEventToMax, false, true, true, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, false)
                --_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_SPEED, self, DriveLever.actionEventChangeSpeed, false, true, true, true, nil)
                --g_inputBinding:setActionEventTextPriority(actionEventId, false)
                --_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_DIRECTION_AND_MAX, self, DriveLever.actionEventChangeDirectionAndMax, false, true, true, true, nil)
                --g_inputBinding:setActionEventTextPriority(actionEventId, false)
            end

            self:toggleAxes(spec.isEnabled)
        end
    end
end

-- Enable / Disable action event for frontloader axes
function DriveLever:toggleAxes(active)
    --print("DriveLever:toggleAxes")
    if self.isClient then
        local spec = self.spec_driveLever

        local axes = {}
        axes.actionEventChangeSpeed = spec.actionEvents[InputAction.AXIS_FRONTLOADER_ARM]
        axes.actionEventChangeDirectionAndMax = spec.actionEvents[InputAction.AXIS_FRONTLOADER_TOOL]

        for k, v in pairs(axes) do
            --print("toggle: " .. k)
            g_inputBinding:setActionEventActive(v.actionEventId, active)
        end
    end
end

function DriveLever:actionEventToggle(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_driveLever
    self:setEnabled(not spec.isEnabled)
    self:toggleAxes(spec.isEnabled)
end

function DriveLever:actionEventForward(actionName, inputValue, callbackState, isAnalog)
    -- print("DriveLever:actionEventForward")
    local spec = self.spec_driveLever
    spec.input.changed = true
    spec.input.forward.value = inputValue
    spec.input.forward.isAnalog = isAnalog
    --self:debug(spec.input.forward)
end

function DriveLever:actionEventBackward(actionName, inputValue, callbackState, isAnalog)
    --print("DriveLever:actionEventBackward")
    local spec = self.spec_driveLever
    spec.input.changed = true
    spec.input.backward.value = inputValue
    spec.input.backward.isAnalog = isAnalog
    --self:debug(spec.input.backward)
end

function DriveLever:actionEventChangeSpeed(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_driveLever
    spec.input.changed = true

    spec.input.forward.isAnalog = isAnalog
    spec.input.backward.isAnalog = isAnalog

    if spec.input.useFrontloaderAxes then
        inputValue = -inputValue
    end

    if inputValue > 0 then
        spec.input.forward.value = inputValue
    else
        spec.input.backward.value = -inputValue
    end
end

function DriveLever:actionEventChangeDirection(actionName, inputValue, callbackState, isAnalog)
    --print("DriveLever:actionEventChangeDirection")
    local spec = self.spec_driveLever
    spec.input.changed = true
    spec.input.changeDirection.value = inputValue
    --self:debug(spec.input.changeDirection)
end

function DriveLever:actionEventToMax(actionName, inputValue, callbackState, isAnalog)
    --print("DriveLever:actionEventToMax")
    local spec = self.spec_driveLever
    spec.input.changed = true
    spec.input.toMax.value = inputValue
    --self:debug(spec.input.toMax)
end

function DriveLever:actionEventChangeDirectionAndMax(actionName, inputValue, callbackState, isAnalog)
    --print("DriveLever:actionEventChangeDirectionAndMax")
    local spec = self.spec_driveLever
    spec.input.changed = true

    spec.input.changeDirection.isAnalog = isAnalog
    spec.input.toMax.isAnalog = isAnalog

    if inputValue > 0 then
        spec.input.changeDirection.value = inputValue
    else
        spec.input.toMax.value = -inputValue
    end
end

function DriveLever:actionEventSaveSpeed()
    --print("DriveLever:actionEventSaveSpeed")
    local spec = self.spec_driveLever

    local cruiseControlSpeed = math.min(math.floor(self:getCruiseControlSpeed()), self:getMaxSpeed())

    if spec.vehicle.isWorking then
        if spec.vehicle.maxSpeed.savedWorking == 0 then
            spec.vehicle.maxSpeed.savedWorking = cruiseControlSpeed
        elseif spec.vehicle.maxSpeed.savedWorkingToggle == 0 and spec.vehicle.maxSpeed.savedWorking > 0 then
            spec.vehicle.maxSpeed.savedWorkingToggle = cruiseControlSpeed
        else
            spec.vehicle.maxSpeed.savedWorking = 0
            spec.vehicle.maxSpeed.savedWorkingToggle = 0
        end
    else
        if spec.vehicle.maxSpeed.savedCruise == 0 then
            spec.vehicle.maxSpeed.savedCruise = cruiseControlSpeed
        elseif spec.vehicle.maxSpeed.savedCruiseToggle == 0 and spec.vehicle.maxSpeed.savedCruise > 0 then
            spec.vehicle.maxSpeed.savedCruiseToggle = cruiseControlSpeed
        else
            spec.vehicle.maxSpeed.savedCruise = 0
            spec.vehicle.maxSpeed.savedCruiseToggle = 0
        end
    end
    --self:debug(spec.vehicle.maxSpeed)
end

function DriveLever:actionToggleAccelerationLimit()
    local spec = self.spec_driveLever
    spec.vehicle.limitAcceleration = not spec.vehicle.limitAcceleration
end

function DriveLever:onDraw()
    local spec = self.spec_driveLever

    if spec.isEnabled then
        local baseX, baseY = g_currentMission.inGameMenu.hud.speedMeter.cruiseControlElement:getPosition()
        local textSize = g_currentMission.inGameMenu.hud.speedMeter.cruiseControlTextSize * 0.7

        local x = baseX + (g_currentMission.inGameMenu.hud.speedMeter.cruiseControlElement:getWidth())
        local y = baseY - (textSize * 0.8)

        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)

        local maxSpeedText = spec.vehicle.maxSpeed.savedCruise > 0 and spec.vehicle.maxSpeed.savedCruise or spec.vehicle.maxSpeed.cruise
        if spec.vehicle.maxSpeed.savedCruiseToggle > 0 then
            maxSpeedText = tostring(maxSpeedText) .. "/" .. tostring(spec.vehicle.maxSpeed.savedCruiseToggle)
        end
        if spec.vehicle.isWorking then
            maxSpeedText = spec.vehicle.maxSpeed.savedWorking > 0 and spec.vehicle.maxSpeed.savedWorking or spec.vehicle.maxSpeed.working
            if spec.vehicle.maxSpeed.savedWorkingToggle > 0 then
                maxSpeedText = tostring(maxSpeedText) .. "/" .. tostring(spec.vehicle.maxSpeed.savedWorkingToggle)
            end
            setTextColor(0, 0.68, 0.2, 1)
        else
            setTextColor(0.000300, 0.564700, 0.982200, 1)
        end

        if spec.vehicle.limitAcceleration then
            renderText(x, y, textSize, "Max " .. tostring(maxSpeedText))
        else
            renderText(x, y, textSize, "Mem " .. tostring(maxSpeedText))
        end
    end
end

function DriveLever:onWriteUpdateStream(streamId, connection, dirtyMask)
    --print("DriveLever:onWriteUpdateStream")
    local spec = self.spec_driveLever
    if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
        streamWriteBool(streamId, spec.isEnabled)
        streamWriteBool(streamId, spec.vehicle.stop)
    end
    --if not connection:getIsServer() then
    --end
end

function DriveLever:onReadUpdateStream(streamId, timestamp, connection)
    --print("DriveLever:onReadUpdateStream")
    local spec = self.spec_driveLever
    if streamReadBool(streamId) then
        spec.isEnabled = streamReadBool(streamId)
        spec.vehicle.stop = streamReadBool(streamId)
    end
    --if connection:getIsServer() then
    --end
end

function DriveLever:onWriteStream(streamId, connection)
    local spec = self.spec_driveLever
    streamWriteBool(streamId, spec.isEnabled)
end

function DriveLever:onReadStream(streamId, connection)
    local spec = self.spec_driveLever
    spec.isEnabled = streamReadBool(streamId)
    self:toggleAxes(spec.isEnabled)
end

function DriveLever:debug(v)
    local spec = self.spec_driveLever

    if spec.debug then
        if type(v) == "table" then
            tprint(v)
        else
            print(tostring(v))
        end
    end
end

function tprint (tbl, indent)
    if not indent then
        indent = 0
    end
    for k, v in pairs(tbl) do
        formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            tprint(v, indent + 1)
        elseif type(v) == 'boolean' then
            print(formatting .. tostring(v))
        else
            print(formatting .. v)
        end
    end
end
