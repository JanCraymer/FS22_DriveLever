-- Drive lever specialization allowing to control the tractor with a joystick


DriveLever = {}

function DriveLever.prerequisitesPresent(specializations)
    return true
end

function DriveLever.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "debug", DriveLever.debug)
    SpecializationUtil.registerFunction(vehicleType, "changeDirection", DriveLever.changeDirection)
    SpecializationUtil.registerFunction(vehicleType, "changeSpeed", DriveLever.changeSpeed)
    SpecializationUtil.registerFunction(vehicleType, "stop", DriveLever.stop)
    SpecializationUtil.registerFunction(vehicleType, "accelerateToMax", DriveLever.accelerateToMax)
end

function DriveLever.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", DriveLever);
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", DriveLever);
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", DriveLever);
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", DriveLever);
end

function DriveLever:onLoad(savegame)
    local spec = self.spec_driveLever

    spec.isEnabled = true
    spec.debug = true

    spec.vehicle = {}
    spec.vehicle.targetSpeed = 0
    spec.vehicle.targetSpeedSent = 0
    spec.vehicle.maxSpeedAdvance = 3
    spec.vehicle.brakeForce = 0.5
    spec.vehicle.stop = false
    spec.vehicle.isStopped = nil
    spec.vehicle.isWorking = false
    spec.vehicle.maxSpeed = {}
    spec.vehicle.maxSpeed.cruise = 0
    spec.vehicle.maxSpeed.working = 0
    spec.vehicle.maxSpeed.savedCruise = 0
    spec.vehicle.maxSpeed.savedWorking = 0

    -- @Todo: make configurable
    spec.input = {}
    spec.input.changed = false

    spec.input.forward = {}
    spec.input.forward.value = 0
    spec.input.forward.enabled = true
    spec.input.forward.isAnalog = false
    spec.input.forward.deadzone = 0.1
    spec.input.forward.threshold = 1.1

    spec.input.backward = {}
    spec.input.backward.value = 0
    spec.input.backward.enabled = true
    spec.input.backward.isAnalog = false
    spec.input.backward.deadzone = 0.1
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
    spec.input.delay.value = 250
    spec.input.delay.multiplier = 1
    spec.input.delay.current = 0

end

function DriveLever:onUpdate(dt)
    local spec = self.spec_driveLever
    local lastSpeed = self:getLastSpeed()

    if lastSpeed > 0.4 then
        spec.vehicle.isStopped = false
        if spec.vehicle.stop then
            self:brake(spec.vehicle.brakeForce)
        end
    else
        spec.vehicle.isStopped = true
        spec.vehicle.stop = false
    end

    if self.isClient and spec.isEnabled then

        -- determine max speeds
        local workingSpeedLimit, isWorking = self:getSpeedLimit(true)
        spec.vehicle.isWorking = isWorking
        spec.vehicle.maxSpeed.cruise = self:getCruiseControlMaxSpeed()
        if isWorking then
            spec.vehicle.maxSpeed.cruise = math.floor(workingSpeedLimit)
        end

        if self.isActiveForInputIgnoreSelectionIgnoreAI then

            spec.input.delay.current = spec.input.delay.current - (dt * spec.input.delay.multiplier)

            if spec.input.changed then

                -- change direction
                if spec.input.changeDirection.enabled and spec.input.changeDirection.value > spec.input.changeDirection.deadzone then
                    spec.input.changeDirection.enabled = false
                    self:changeDirection()
                end

                -- to max
                if spec.input.toMax.enabled and spec.input.toMax.value > spec.input.toMax.deadzone then
                    spec.input.toMax.enabled = false
                    self:accelerateToMax()
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
                                newSpeed = spec.vehicle.targetSpeed + speedChange
                            end

                            if newSpeed - lastSpeed > spec.vehicle.maxSpeedAdvance then
                                newSpeed = math.ceil(lastSpeed) + spec.vehicle.maxSpeedAdvance
                            end
                            self:changeSpeed(newSpeed)
                        end
                    end

                    -- backward
                    if spec.input.backward.enabled and spec.input.backward.value > spec.input.backward.deadzone then
                        if spec.input.backward.isAnalog and spec.input.backward.value > spec.input.backward.threshold then
                            spec.input.backward.enabled = false
                            self:stop()
                        else
                            -- change speed
                            local newSpeed = 0
                            if not spec.vehicle.isStopped and self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_OFF then
                                newSpeed = math.floor(lastSpeed)
                            else
                                local speedChange = calculateSpeedChangeStep(spec.input.backward.value)
                                newSpeed = spec.vehicle.targetSpeed - speedChange
                            end

                            if newSpeed > lastSpeed then
                                newSpeed = math.floor(lastSpeed)
                            end

                            self:changeSpeed(newSpeed)
                        end
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

function calculateSpeedChangeStep(inputValue)
    return 5 * math.floor(inputValue * 10) / 10
end

function DriveLever:changeSpeed(targetSpeed)
    local spec = self.spec_driveLever
    if targetSpeed < 0 then
        targetSpeed = 0
    end
    spec.vehicle.targetSpeed = targetSpeed

    if spec.vehicle.targetSpeed > 0 then
        if spec.vehicle.targetSpeed < 0.5 then
            spec.vehicle.targetSpeed = 0.5
        end
        local spec_drivable = self.spec_drivable
        spec.vehicle.stop = false
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
    self:debug(spec.vehicle.targetSpeed)
end

function DriveLever:saveSpeed()

end

function DriveLever:accelerateToMax()
    print("DriveLever:accelerateToMax")
    local spec = self.spec_driveLever

    if spec.vehicle.isWorking then
        if spec.vehicle.maxSpeed.savedWorking > 0 then
            self:changeSpeed(spec.vehicle.maxSpeed.savedWorking)
        else
            self:changeSpeed(spec.vehicle.maxSpeed.working)
        end
    else
        if spec.vehicle.maxSpeed.savedCruise > 0 then
            self:changeSpeed(spec.vehicle.maxSpeed.savedCruise)
        else
            self:changeSpeed(spec.vehicle.maxSpeed.cruise)
        end
    end
end

function DriveLever:stop()
    print("DriveLever:stop")
    local spec = self.spec_driveLever
    spec.vehicle.stop = true
    self:changeSpeed(0)
    self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
end

function DriveLever:changeDirection(direction)
    local motor = self.spec_motorized.motor

    if direction == nil then
        motor:changeDirection(-motor.currentDirection)
    else
        motor:changeDirection(direction)
    end
end

function DriveLever:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    print("DriveLever:onRegisterActionEvents")

    if self.isClient then
        local spec = self.spec_driveLever
        self:clearActionEventsTable(spec.actionEvents)

        self:debug(isActiveForInput)
        self:debug(isActiveForInputIgnoreSelection)

        if isActiveForInputIgnoreSelection then

            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_TOGGLE, self, DriveLever.actionEventToggle, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_FORWARD, self, DriveLever.actionEventForward, false, true, true, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, false)
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_BACKWARD, self, DriveLever.actionEventBackward, false, true, true, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, false)
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_CHANGE_DIRECTION, self, DriveLever.actionEventChangeDirection, false, true, true, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, false)
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_SAVE_CURRENT_CRUISECONTROL_SPEED, self, DriveLever.actionEventSaveSpeed, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.DRIVE_LEVER_TO_MAX, self, DriveLever.actionEventToMax, false, true, true, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, false)

            self:debug(spec.actionEvents)

        end
    end
end

function DriveLever:actionEventToggle(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_driveLever
    spec.isEnabled = not spec.isEnabled
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
    -- print("DriveLever:actionEventBackward")
    local spec = self.spec_driveLever
    spec.input.changed = true
    spec.input.backward.value = inputValue
    spec.input.backward.isAnalog = isAnalog
    --self:debug(spec.input.backward)
end

function DriveLever:actionEventChangeDirection(actionName, inputValue, callbackState, isAnalog)
    print("DriveLever:actionEventChangeDirection")
    local spec = self.spec_driveLever
    spec.input.changed = true
    spec.input.changeDirection.value = inputValue
    self:debug(spec.input.changeDirection)
end

function DriveLever:actionEventToMax(actionName, inputValue, callbackState, isAnalog)
    print("DriveLever:actionEventToMax")
    local spec = self.spec_driveLever
    spec.input.changed = true
    spec.input.toMax.value = inputValue
    self:debug(spec.input.toMax)
end

function DriveLever:actionEventSaveSpeed()
    print("DriveLever:actionEventSaveSpeed")
    local spec = self.spec_driveLever

    local cruiseControlSpeed = math.floor(self:getCruiseControlSpeed())
    if spec.vehicle.isWorking then
        if spec.vehicle.maxSpeed.savedWorking == 0 then
            spec.vehicle.maxSpeed.savedWorking = cruiseControlSpeed
        else
            spec.vehicle.maxSpeed.savedWorking = 0
        end
    else
        if spec.vehicle.maxSpeed.savedCruise == 0 then
            spec.vehicle.maxSpeed.savedCruise = cruiseControlSpeed
        else
            spec.vehicle.maxSpeed.savedCruise = 0
        end
    end
    self:debug(spec.vehicle.maxSpeed)
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
        if spec.vehicle.isWorking then
            maxSpeedText = spec.vehicle.maxSpeed.savedWorking > 0 and spec.vehicle.maxSpeed.savedWorking or spec.vehicle.maxSpeed.working
            setTextColor(0, 0.68, 0.2, 1)
        else
            setTextColor(0.000300, 0.564700, 0.982200, 1)
        end
        renderText(x, y, textSize, "max " .. tostring(maxSpeedText))
    end
end

function DriveLever:onWriteStream(streamId, connection)
    local spec = self.spec_driveLever
    streamWriteBool(streamId, spec.vehicle.stop)
end

function DriveLever:onReadStream(streamId, connection)
    local spec = self.spec_driveLever
    spec.vehicle.stop = streamReadBool(streamId)
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
