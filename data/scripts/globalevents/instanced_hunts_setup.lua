local instancedHuntsSetup = GlobalEvent("InstancedHuntsSetup")

function instancedHuntsSetup.onStartup()
	for _, config in pairs(InstancedHuntsConfigs) do
		InstancedHunts.setup(config)
	end
	return true
end

instancedHuntsSetup:register()
