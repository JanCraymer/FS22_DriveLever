DrivingStickCruiseControl = {}
DrivingStickCruiseControl.modName = g_currentModName

function DrivingStickCruiseControl.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Drivable, specializations)
end

function DrivingStickCruiseControl:onLoad(savegame)
    -- print("DrivingStickCruiseControl:onLoad")
    self.spec_drivingStickCruiseControl = self[("spec_%s.drivingStickCruiseControl"):format(DrivingStickCruiseControl.modName)]
    local spec = self.spec_drivingStickCruiseControl

    spec.active = false
    spec.savedSpeed = 0
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

    spec.inputDelay = 200
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

        spec.targetSpeed = 0

        local triggerUp, triggerDown, triggerAlways, startActive, callbackState, disableConflictingBindings = false, true, false, true, nil, true
        local state, actionEventId, otherEvents = g_inputBinding:registerActionEvent(InputAction.DRIVING_STICK_TOGGLE, self, DrivingStickCruiseControl.actionEventToggle, false, true, false, true, nil, true)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
        local state, actionEventId, otherEvents = g_inputBinding:registerActionEvent(InputAction.DRIVING_STICK_ACCELERATE, self, DrivingStickCruiseControl.actionEventAccelerate, false, true, true, true, nil, false)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
        local state, actionEventId, otherEvents = g_inputBinding:registerActionEvent(InputAction.DRIVING_STICK_DECELERATE, self, DrivingStickCruiseControl.actionEventDecelerate, false, true, true, true, nil, false)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
        local state, actionEventId, otherEvents = g_inputBinding:registerActionEvent(InputAction.DRIVING_STICK_SWITCH_DIRECTION, self, DrivingStickCruiseControl.actionEventSwitchDirection, false, true, true, true, nil, false)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
        local state, actionEventId, otherEvents = g_inputBinding:registerActionEvent(InputAction.DRIVING_STICK_SAVE_CURRENT_CRUISECONTROL_SPEED, self, DrivingStickCruiseControl.actionEventSaveCurrentCruiseControlSpeed, false, true, false, true, nil, true)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
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
    spec.active = not spec.active
    -- print(spec.active)
end

function DrivingStickCruiseControl:saveCurrentCruiseControlSpeed(self)
    -- print("DrivingStickCruiseControl:saveCurrentCruiseControlSpeed")
    local spec = self.spec_drivingStickCruiseControl
    if self.isActiveForInputIgnoreSelectionIgnoreAI then
        if DrivingStickCruiseControl:getIsVehicleControlledByPlayer(self) then
            if spec.savedSpeed == 0 then
                spec.savedSpeed = self:getCruiseControlSpeed()
            else
                spec.savedSpeed = 0
            end
            -- print("Saved Speed: " .. spec.savedSpeed)
        end
    end        
end

function DrivingStickCruiseControl:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_drivingStickCruiseControl    
       
    if self.isClient then

        spec.inputDelayCurrent = spec.inputDelayCurrent - (dt * spec.inputDelayMultiplier)
        -- spec.inputDelayMultiplier = math.min(spec.inputDelayMultiplier + (dt * 0.003), 6)
        local axisIputValue = spec.accelerateInputValue + spec.decelerateInputValue
        spec.inputDelayMultiplier = math.min((axisIputValue * 10), 6)

        if self.isActiveForInputIgnoreSelectionIgnoreAI then

            if DrivingStickCruiseControl:getIsVehicleControlledByPlayer(self) then 

                if spec.switchDirectionInputValue > 0.2 and spec.active then
                    if spec.switchDirectionEnabled then                
                        -- print("switch direction")            
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


                if (spec.accelerateInputValue > 0.01 or spec.decelerateInputValue > 0.01) and spec.active and not spec.fullStop then -- 1% axis deadzone

                    -- print("spec.inputDelayMultiplier: " .. spec.inputDelayMultiplier)

                    if self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_OFF then 
                        self:brake(0)
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
                        -- print("lastSpeed: " .. self:getLastSpeed())


                        if spec.decelerateInputValue > spec.decelerateAxisThreshold and spec.decelerationEnabled then
                            self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
                            if self.movingDirection >= 0 then -- workaround for strange behavior while driving backwards
                                -- self:brakeToStop()
                            end
                            -- self:brake(1)
                            -- self:setBrakePedalInput(1)
                            spec.fullStop = true
                            spec.targetSpeed = 0
                            spec.decelerationEnabled = false
                        elseif spec.decelerateInputValue > 0 and spec.decelerationEnabled then
                            spec.targetSpeed = spec.targetSpeed - spec.speedChangeStep
                        elseif spec.accelerateInputValue > spec.accelerateAxisThreshold then
                            if spec.savedSpeed < 1 then
                                spec.targetSpeed = self:getCruiseControlMaxSpeed()
                            else
                                spec.targetSpeed = spec.savedSpeed
                            end
                            spec.accelerationEnabled = false
                        elseif spec.accelerateInputValue > 0 and spec.accelerationEnabled then
                            spec.targetSpeed = spec.targetSpeed + spec.speedChangeStep
                            if spec.targetSpeed > spec.savedSpeed and spec.savedSpeed > 0 then
                                spec.targetSpeed = spec.savedSpeed
                                spec.accelerationEnabled = false
                            end
                        end

                        -- print("targetSpeed " .. spec.targetSpeed)

                        if spec.targetSpeed > 0 then
                            -- print("self:getCruiseControlMaxSpeed() " .. self:getCruiseControlMaxSpeed())
                            if spec.targetSpeed > self:getCruiseControlMaxSpeed() then 
                                spec.targetSpeed = self:getCruiseControlMaxSpeed()
                            end
                            self:setCruiseControlMaxSpeed(spec.targetSpeed, spec.targetSpeed)
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
    if spec.active then
        local baseX, baseY = g_currentMission.inGameMenu.hud.speedMeter.cruiseControlElement:getPosition()
        local textSize = g_currentMission.inGameMenu.hud.speedMeter.cruiseControlTextSize * 0.7

        local x = baseX + (g_currentMission.inGameMenu.hud.speedMeter.cruiseControlElement:getWidth())
        local y = baseY - (textSize * 0.8)
        
        -- setTextColor(1,1,1,0.5)
        setTextColor(0.000300, 0.564700 , 0.982200, 1)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        
        local maxSpeedText = spec.savedSpeed > 0 and spec.savedSpeed or self:getCruiseControlMaxSpeed()
        renderText(x, y , textSize, "max " .. tostring(maxSpeedText))
    end
end

function DrivingStickCruiseControl:getIsVehicleControlledByPlayer(obj)
    return obj:getIsVehicleControlledByPlayer() or (obj.spec_globalPositioningSystem ~= nil and obj.spec_globalPositioningSystem.guidanceSteeringIsActive)
end