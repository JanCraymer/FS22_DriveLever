DrivingStick = {}

local DrivingStick_mt = Class(DrivingStick)

function DrivingStick:new(mission, input, i18n, inputDisplayManager, soundManager, modDirectory, modName)
    local self = setmetatable({}, DrivingStick_mt)

    self.isServer = mission:getIsServer()
    self.isClient = mission:getIsClient()
    self.mission = mission
    self.input = input
    self.i18n = i18n
    self.soundManager = soundManager
    self.modDirectory = modDirectory
    self.modName = modName

    -- self.hudAtlasPath = g_baseHUDFilename

    -- self.vehicles = {}
    -- self.controlledVehicle = nil

    self.isEnabled = true
    -- self.hasHoseEventInput = 0
    -- self.allowPtoEvent = true
    -- self.handleEventCurrentDelay = ManualAttach.TIMER_THRESHOLD

    -- self.uiScale = g_gameSettings:getValue("uiScale")
    -- self.context = ContextActionDisplay.new(self.hudAtlasPath, inputDisplayManager)
    -- self.context:setScale(self.uiScale)

    -- self.detectionHandler = ManualAttachDetectionHandler:new(self.isServer, self.isClient, self.mission, modDirectory)

    -- self:setState(self.isEnabled)

    return self
end

function DrivingStick.installSpecializations(vehicleTypeManager, specializationManager, modDirectory, modName)
    specializationManager:addSpecialization("drivingStickCruiseControl", "DrivingStickCruiseControl", Utils.getFilename("src/DrivingStickCruiseControl.lua", modDirectory), nil)

    for typeName, typeEntry in pairs(vehicleTypeManager:getTypes()) do
        if SpecializationUtil.hasSpecialization(Drivable, typeEntry.specializations) and
            not SpecializationUtil.hasSpecialization(SplineVehicle, typeEntry.specializations) then
            vehicleTypeManager:addSpecialization(typeName, modName .. ".drivingStickCruiseControl")
        end
    end
end