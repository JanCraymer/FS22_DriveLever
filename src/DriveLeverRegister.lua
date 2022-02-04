if g_specializationManager:getSpecializationByName("driveLever") == nil then
    g_specializationManager:addSpecialization("driveLever", "DriveLever", Utils.getFilename("src/DriveLever.lua", g_currentModDirectory), true, nil)
end

for typeName, typeEntry in pairs(g_vehicleTypeManager.types) do
  if
          SpecializationUtil.hasSpecialization(Drivable, typeEntry.specializations) 
      and	SpecializationUtil.hasSpecialization(Enterable, typeEntry.specializations)
      and	SpecializationUtil.hasSpecialization(Motorized, typeEntry.specializations)
  
      and not SpecializationUtil.hasSpecialization(Locomotive, typeEntry.specializations)
  
  then
       g_vehicleTypeManager:addSpecialization(typeName, "driveLever")
  end
end