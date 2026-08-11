local instancedHuntsMonitor = GlobalEvent("InstancedHuntsMonitor")

function instancedHuntsMonitor.onThink(interval)
	for _, config in pairs(InstancedHuntsConfigs) do
		InstancedHunts.checkExpired(config)
	end
	return true
end

instancedHuntsMonitor:interval(60000) -- check every minute
instancedHuntsMonitor:register()
