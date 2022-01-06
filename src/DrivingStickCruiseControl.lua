DrivingStickCruiseControl = {}
DrivingStickCruiseControl.modName = g_currentModName

function DrivingStickCruiseControl.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Drivable, specializations)
end

function DrivingStickCruiseControl:onLoad(savegame)
    print("DrivingStickCruiseControl:onLoad")
    self.spec_drivingStickCruiseControl = self[("spec_%s.drivingStickCruiseControl"):format(DrivingStickCruiseControl.modName)]
    local spec = self.spec_drivingStickCruiseControl

    spec.savedSpeed = 0
    spec.accelerateInputValue = 0
    spec.decelerateInputValue = 0
    spec.accelerationEnabled = true
    spec.accelerateAxisThreshold = 0.5
    spec.decelerateAxisThreshold = 0.5

    spec.inputDelay = 150
    spec.inputDelayCurrent = 0
end

function DrivingStickCruiseControl.registerEventListeners(vehicleType)
    print("DrivingStickCruiseControl.registerEventListeners");    
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", DrivingStickCruiseControl);
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", DrivingStickCruiseControl);
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", DrivingStickCruiseControl);
end

function DrivingStickCruiseControl:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    print("DrivingStickCruiseControl.onRegisterActionEvents");

    if self.isClient then
        local spec = self.spec_drivingStickCruiseControl
        self:clearActionEventsTable(spec.actionEvents)

        spec.targetSpeed = 0

        -- if self.getIsEntered ~= nil then
        --     entered = self:getIsEntered()
        -- end

        local triggerUp, triggerDown, triggerAlways, startActive, callbackState, disableConflictingBindings = false, true, false, true, nil, true
        local state, actionEventId, otherEvents = g_inputBinding:registerActionEvent(InputAction.DRIVING_STICK_TOGGLE_CRUISECONTROL, self, DrivingStickCruiseControl.actionEventToggle, false, true, true, true, nil, true)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
        local state, actionEventId, otherEvents = g_inputBinding:registerActionEvent(InputAction.DRIVING_STICK_ACCELERATE, self, DrivingStickCruiseControl.actionEventAccelerate, false, true, true, true, nil, true)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
        local state, actionEventId, otherEvents = g_inputBinding:registerActionEvent(InputAction.DRIVING_STICK_DECELERATE, self, DrivingStickCruiseControl.actionEventDecelerate, false, true, true, true, nil, true)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
        local state, actionEventId, otherEvents = g_inputBinding:registerActionEvent(InputAction.DRIVING_STICK_SAVE_CURRENT_CRUISECONTROL_SPEED, self, DrivingStickCruiseControl.actionEventSaveCurrentCruiseControlSpeed, false, true, false, true, nil, true)
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_LOW)
    end
end

function DrivingStickCruiseControl:actionEventAccelerate(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_drivingStickCruiseControl
    spec.accelerateInputValue = inputValue
end

function DrivingStickCruiseControl:actionEventDecelerate(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_drivingStickCruiseControl
    spec.decelerateInputValue = inputValue
end

function DrivingStickCruiseControl:actionEventSaveCurrentCruiseControlSpeed(actionName, inputValue, callbackState, isAnalog)
    print("DrivingStickCruiseControl:actionEventSaveCurrentCruiseControlSpeed")
    DrivingStickCruiseControl:saveCurrentCruiseControlSpeed(self)
end

function DrivingStickCruiseControl:saveCurrentCruiseControlSpeed(self)
    print("DrivingStickCruiseControl:saveCurrentCruiseControlSpeed")
    print(self.isClient)
    local spec = self.spec_drivingStickCruiseControl
    print("DrivingStickCruiseControl:saveCurrentCruiseControlSpeed isClient")
    if self.isActiveForInputIgnoreSelectionIgnoreAI then
        print("DrivingStickCruiseControl:saveCurrentCruiseControlSpeed isActiveForInputIgnoreSelectionIgnoreAI")
        if self:getIsVehicleControlledByPlayer() then 
            if spec.savedSpeed == 0 then
                spec.savedSpeed = self:getCruiseControlSpeed()
            else
                spec.savedSpeed = 0
            end
            print("Saved Speed: " .. spec.savedSpeed)
        end
    end        
end

function DrivingStickCruiseControl:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_drivingStickCruiseControl    
    
    if self.isClient then

        spec.inputDelayCurrent = spec.inputDelayCurrent - dt

        if self.isActiveForInputIgnoreSelectionIgnoreAI then
            if self:getIsVehicleControlledByPlayer() then 
                if spec.accelerateInputValue > 0.1 or spec.decelerateInputValue > 0.1 then -- 10% axis deadzone
                    if self:getCruiseControlState() == Drivable.CRUISECONTROL_STATE_OFF then 
                        if self:getLastSpeed() > 1 then
                            spec.targetSpeed = math.floor(self:getLastSpeed())
                            spec.accelerationEnabled = false
                        else
                            spec.targetSpeed = 0
                        end
                    else
                        spec.targetSpeed = self:getCruiseControlSpeed()
                    end

                    if spec.inputDelayCurrent < 0 then
                        spec.inputDelayCurrent = spec.inputDelay

                        print("spec.accelerateInputValue" .. spec.accelerateInputValue)
                        print("spec.decelerateInputValue" .. spec.decelerateInputValue)
                        -- print("self.movingDirection" .. self.movingDirection)
                        print("lastSpeed: " .. self:getLastSpeed())


                        if spec.decelerateInputValue > spec.decelerateAxisThreshold then
                            print("brakeToStop")
                            self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
                            if self.movingDirection >= 0 then -- workaround for strange behavior while driving backwards
                                self:brakeToStop()
                            end
                            spec.targetSpeed = 0
                        elseif spec.decelerateInputValue > 0 then
                            spec.targetSpeed = spec.targetSpeed - 1
                        elseif spec.accelerateInputValue > spec.accelerateAxisThreshold then
                            if spec.savedSpeed < 1 then
                                spec.targetSpeed = self:getCruiseControlMaxSpeed()
                            else
                                spec.targetSpeed = spec.savedSpeed
                            end
                            spec.accelerationEnabled = false
                        elseif spec.accelerateInputValue > 0 and spec.accelerationEnabled then                            
                            spec.targetSpeed = spec.targetSpeed + 1
                            if spec.targetSpeed > spec.savedSpeed and spec.savedSpeed > 0 then
                                spec.targetSpeed = spec.savedSpeed
                                spec.accelerationEnabled = false
                            end
                        end

                        print("targetSpeed " .. spec.targetSpeed)

                        if spec.targetSpeed > 0 then
                            print("self:getCruiseControlMaxSpeed() " .. self:getCruiseControlMaxSpeed())
                            if spec.targetSpeed > self:getCruiseControlMaxSpeed() then 
                                spec.targetSpeed = self:getCruiseControlMaxSpeed()
                            end
                            print("targetSpeed2 " .. spec.targetSpeed)
                            self:setCruiseControlMaxSpeed(spec.targetSpeed, spec.targetSpeed)
                            self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
                        end

                    end        
                else
                    spec.inputDelayCurrent = 0
                    spec.accelerationEnabled = true
                end

            end
        end

        -- reset for next frame
        spec.accelerateInputValue = 0
        spec.decelerateInputValue = 0

    end

end

