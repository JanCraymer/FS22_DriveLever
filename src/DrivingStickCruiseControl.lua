DrivingStickCruiseControl = {}
DrivingStickCruiseControl.modName = g_currentModName

function DrivingStickCruiseControl.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Drivable, specializations)
end

function DrivingStickCruiseControl:onLoad(savegame)
    -- print("DrivingStickCruiseControl:onLoad")
    local spec = self.spec_drivingStickCruiseControl

    spec.isActive = false
    spec.savedSpeed = 0
    spec.savedSpeedWorking = 0
    spec.isWorking = false
    spec.accelerateInputValue = 0
    spec.decelerateInputValue = 0
    spec.accelerationEnabled = true
    spec.decelerationEnabled = true
    spec.accelerateAxisThreshold = 0.9
    spec.decelerateAxisThreshold = 0.8
    spec.switchDirectionInputValue = 0
    spec.switchDirectionEnabled = true
    spec.speedChangeStep = 0.5
    spec.fullStop = false
    spec.maxSpeed = 0
    spec.targetSpeed = 0

    spec.inputDelay = 250
    spec.inputDelayMultiplier = 1
    spec.inputDelayCurrent = 0
end

function DrivingStickCruiseControl.registerEventListeners(vehicleType)
    -- print("DrivingStickCruiseControl.registerEventListeners");    
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", DrivingStickCruiseControl);
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", DrivingStickCruiseControl);
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", DrivingStickCruiseControl);
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", DrivingStickCruiseControl);
end

function DrivingStickCruiseControl:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    -- print("DrivingStickCruiseControl.onRegisterActionEvents");

    if self.isClient then

        local spec = self.spec_drivingStickCruiseControl
        self:clearActionEventsTable(spec.actionEvents)
        DrivingStickCruiseControl.actionEvents = {} 

        if self:getIsActiveForInput(true) and spec ~= nil then 

            local _, actionEventId = self:addActionEvent(DrivingStickCruiseControl.actionEvents, InputAction.DRIVING_STICK_TOGGLE, self, DrivingStickCruiseControl.actionEventToggle, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
            _, actionEventId = self:addActionEvent(DrivingStickCruiseControl.actionEvents, InputAction.DRIVING_STICK_ACCELERATE, self, DrivingStickCruiseControl.actionEventAccelerate, false, true, true, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
            _, actionEventId = self:addActionEvent(DrivingStickCruiseControl.actionEvents, InputAction.DRIVING_STICK_DECELERATE, self, DrivingStickCruiseControl.actionEventDecelerate, false, true, true, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
            _, actionEventId = self:addActionEvent(DrivingStickCruiseControl.actionEvents, InputAction.DRIVING_STICK_SWITCH_DIRECTION, self, DrivingStickCruiseControl.actionEventSwitchDirection, false, true, true, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
            _, actionEventId = self:addActionEvent(DrivingStickCruiseControl.actionEvents, InputAction.DRIVING_STICK_SAVE_CURRENT_CRUISECONTROL_SPEED, self, DrivingStickCruiseControl.actionEventSaveCurrentCruiseControlSpeed, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
        
        end
    end
end

function DrivingStickCruiseControl:actionEventToggle(actionName, inputValue, callbackState, isAnalog)
    DrivingStickCruiseControl:toggle(self)
end

function DrivingStickCruiseControl:actionEventAccelerate(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_drivingStickCruiseControl
    spec.accelerateInputValue = inputValue
end

function DrivingStickCruiseControl:actionEventDecelerate(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_drivingStickCruiseControl
    spec.decelerateInputValue = inputValue
end

function DrivingStickCruiseControl:actionEventSwitchDirection(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_drivingStickCruiseControl
    spec.switchDirectionInputValue = inputValue
end

function DrivingStickCruiseControl:actionEventSaveCurrentCruiseControlSpeed(actionName, inputValue, callbackState, isAnalog)
    DrivingStickCruiseControl:saveCurrentCruiseControlSpeed(self)
end

function DrivingStickCruiseControl:toggle(self)
    -- print("DrivingStickCruiseControl:toggle")
    local spec = self.spec_drivingStickCruiseControl
    spec.isActive = not spec.isActive
end

function DrivingStickCruiseControl:saveCurrentCruiseControlSpeed(self)
    -- print("DrivingStickCruiseControl:saveCurrentCruiseControlSpeed")
    local spec = self.spec_drivingStickCruiseControl
    if self.isActiveForInputIgnoreSelectionIgnoreAI then
        if DrivingStickCruiseControl:getIsVehicleControlledByPlayer(self) then
            local cruiseControlSpeed = math.floor(self:getCruiseControlSpeed())
            if spec.isWorking then
                if spec.savedSpeedWorking == 0 then
                    spec.savedSpeedWorking = cruiseControlSpeed
                else
                    spec.savedSpeedWorking = 0
                end
                -- print("Saved Workingspeed: " .. spec.savedSpeedWorking)
            else
                if spec.savedSpeed == 0 then
                    spec.savedSpeed = cruiseControlSpeed
                else
                    spec.savedSpeed = 0
                end
                -- print("Saved Speed: " .. spec.savedSpeed)
            end
        end
    end        
end

function DrivingStickCruiseControl:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_drivingStickCruiseControl    
       
    if self.isClient then

        local savedSpeed = 0

        if spec.isActive then
            local workingSpeedLimit, isWorking = self:getSpeedLimit(true)
            spec.isWorking = isWorking
            spec.maxSpeed = self:getCruiseControlMaxSpeed()
            savedSpeed = spec.savedSpeed
            if isWorking then
                spec.maxSpeed = math.floor(workingSpeedLimit)
                savedSpeed = spec.savedSpeedWorking
            end
        end

        spec.inputDelayCurrent = spec.inputDelayCurrent - (dt * spec.inputDelayMultiplier)
        -- spec.inputDelayMultiplier = math.min(spec.inputDelayMultiplier + (dt * 0.003), 6)
        local axisIputValue = spec.accelerateInputValue + spec.decelerateInputValue
        spec.inputDelayMultiplier = math.min((axisIputValue * 10), 6)

        if self.isActiveForInputIgnoreSelectionIgnoreAI then

            if DrivingStickCruiseControl:getIsVehicleControlledByPlayer(self) and self:getIsMotorStarted() then

                if spec.switchDirectionInputValue > 0.3 and spec.isActive then
                    if spec.switchDirectionEnabled then                
                        spec.switchDirectionEnabled = false
        
                        local motor = self.spec_motorized.motor
                        motor:changeDirection(-motor.currentDirection)
        
                    end
                else
                    spec.switchDirectionEnabled = true
                end

                local lastSpeed = self:getLastSpeed()

                if spec.fullStop and lastSpeed > 1 then
                    self:brake(0.5)
                else
                    spec.fullStop = false
                end

                -- print(lastSpeed)
                -- print(spec.fullStop)


                if (spec.accelerateInputValue > 0.01 or spec.decelerateInputValue > 0.01) and spec.isActive then -- 1% axis deadzone

                    -- print("spec.inputDelayMultiplier: " .. spec.inputDelayMultiplier)

                    if self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_OFF then                         
                        if lastSpeed > 1 and spec.decelerationEnabled and spec.accelerationEnabled then
                            spec.targetSpeed = math.floor(lastSpeed)
                            spec.accelerationEnabled = false
                        else
                            spec.targetSpeed = 0
                        end
                    else
                        spec.targetSpeed = self:getCruiseControlSpeed()
                    end

                    if spec.inputDelayCurrent < 0 then
                        spec.inputDelayCurrent = spec.inputDelay

                        -- print("spec.accelerateInputValue " .. spec.accelerateInputValue)
                        -- print("spec.decelerateInputValue " .. spec.decelerateInputValue)
                        -- print("self.movingDirection " .. self.movingDirection)
                        -- print("savedSpeed " .. savedSpeed)


                        if spec.decelerateInputValue > spec.decelerateAxisThreshold and spec.decelerationEnabled then -- full backward
                            self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
                            spec.fullStop = true
                            spec.targetSpeed = 0
                            spec.decelerationEnabled = false
                        elseif spec.decelerateInputValue > 0 and spec.decelerationEnabled then
                            spec.targetSpeed = spec.targetSpeed - spec.speedChangeStep
                            if spec.targetSpeed > lastSpeed then
                                spec.targetSpeed = math.floor(lastSpeed)
                            end
                        elseif spec.accelerateInputValue > spec.accelerateAxisThreshold then -- full forward
                            if savedSpeed < 1 then
                                spec.targetSpeed = self:getCruiseControlMaxSpeed()
                            else
                                spec.targetSpeed = savedSpeed
                            end
                            spec.accelerationEnabled = false
                        elseif spec.accelerateInputValue > 0 and spec.accelerationEnabled then
                            spec.targetSpeed = spec.targetSpeed + spec.speedChangeStep
                            if spec.targetSpeed > savedSpeed and savedSpeed > 0 then
                                spec.targetSpeed = savedSpeed
                                -- spec.accelerationEnabled = false
                            end
                        end

                        if spec.targetSpeed > 0 then
                            -- self:brake(0)
                            spec.fullStop = false
                            if spec.targetSpeed > spec.maxSpeed then 
                                spec.targetSpeed = spec.maxSpeed
                            end
                            self:setCruiseControlMaxSpeed(spec.targetSpeed)
                            self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
                        end

                    end        
                else
                    spec.inputDelayCurrent = 0
                    spec.inputDelayMultiplier = 1
                    spec.accelerationEnabled = true
                    spec.decelerationEnabled = true
                end

            end
        end

        -- reset for next frame
        spec.accelerateInputValue = 0
        spec.decelerateInputValue = 0

    end

end

function DrivingStickCruiseControl:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_drivingStickCruiseControl
    if spec.isActive then
        local baseX, baseY = g_currentMission.inGameMenu.hud.speedMeter.cruiseControlElement:getPosition()
        local textSize = g_currentMission.inGameMenu.hud.speedMeter.cruiseControlTextSize * 0.7

        local x = baseX + (g_currentMission.inGameMenu.hud.speedMeter.cruiseControlElement:getWidth())
        local y = baseY - (textSize * 0.8)
        
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        
        local maxSpeedText = spec.savedSpeed > 0 and spec.savedSpeed or spec.maxSpeed
        if spec.isWorking then
            maxSpeedText = spec.savedSpeedWorking > 0 and spec.savedSpeedWorking or spec.maxSpeed
            setTextColor(0, 0.68, 0.2, 1)
        else
            setTextColor(0.000300, 0.564700, 0.982200, 1)
        end
        renderText(x, y , textSize, "max " .. tostring(maxSpeedText))
    end
end

function DrivingStickCruiseControl:getIsVehicleControlledByPlayer(obj)
    return obj:getIsVehicleControlledByPlayer() or (obj.spec_globalPositioningSystem ~= nil and obj.spec_globalPositioningSystem.guidanceSteeringIsActive)
end