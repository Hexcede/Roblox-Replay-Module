--[[
	Replay Module V1.0
	
	Author: Hexcede
	
	Docs:
		Replay
			[description]
				The main api
		Recording Replay:BeginRecording(recordingSettings)
			[description]
				Returns a Recording object and starts recording to it
			
			Table recordingSettings
				ViewportFrame Frame
					[description]
						A viewport frame to render the replay and preview (if applicable) to
				
				function GetInstances(recordingSettings)
					return listOfInstancesToRecord
				end
					[default]
						workspace:GetDescendants()
					[description]
						A function which returns a list of instances to record
						
				boolean LiveReplay
					[default]
						false
					[description]
						Should a preview of the recording be shown in the ReplayFrame?
		Recording
			[description]
				An api for replaying, stopping, controlling, etc replays
			Recording:Stop()
				[description]
					Stops a recording
			Recording:Replay(speed)
				[description]
					Replay a recording at speed
				
				Float speed
					[default]
						1.0
					[description]
						The speed multiplier
			Recording:Destroy()
				[description]
					Delete all replay information and cleanup replay instances
					Always call this when you have no need to replay a recording anymore to save memory and improve user performance
--]]

local replay = {}

function replay:BeginRecording(recordingSettings)
	recordingSettings = recordingSettings or {}
	local frame = recordingSettings.Frame
	if not frame then
		error("You must provide a ViewportFrame for the replay!")
	end
	local recording = {}
	local data = {}
	data.Header = {}
	data.BaseParts = {}
	data.CFrames = {}
	
	data.Header.RecordingStarted = tick()
	data.Header.RecordingStopped = false
	
	local recorderEvent
	recorderEvent = game:GetService("RunService").RenderStepped:Connect(function()
		local t = tick()
		local instances
		if recordingSettings.GetInstances then
			instances = recordingSettings:GetInstances()
		else
			instances = workspace:GetDescendants()
		end
		for _, ch in ipairs(instances) do
			pcall(function()
				if ch:IsA("BasePart") then
					local cl = data.BaseParts[ch] or (function()
						local cl = ch:Clone()
						for _, ch2 in ipairs(cl:GetChildren()) do
							if not ch2:IsA("DataModelMesh") then
								ch2:Destroy()
							end
						end
						if recordingSettings.LiveReplay then
							cl.Parent = frame
						end
						return cl
					end)()
					data.BaseParts[ch] = cl
					data.CFrames[cl] = data.CFrames[cl] or {}
					data.CFrames[cl][t] = ch.CFrame
					cl.CFrame = ch.CFrame
				elseif ch:IsA("Camera") then
					local cl = data.Camera or (function()
						local cam = Instance.new("Camera")
						cam.Parent = frame
						if recordingSettings.LiveReplay then
							frame.CurrentCamera = cam
						end
						return cam
					end)()
					data.Camera = cl
					data.CFrames[cl] = data.CFrames[cl] or {}
					data.CFrames[cl][t] = ch.CFrame
					cl.CFrame = ch.CFrame
				end
			end)
		end
	end)
	
	function recording:Stop()
		if not data.Header.RecordingStopped then
			data.Header.RecordingStopped = tick()
			recorderEvent:Disconnect()
		end
	end
	
	function recording:Replay(speed)
		local twS = game:GetService("TweenService")
		
		speed = speed or 1
		local pointer = data.Header.RecordingStarted
		
		local cache = {}
		while pointer < data.Header.RecordingStopped do
			pointer = pointer + game:GetService("RunService").RenderStepped:Wait()*speed
			
			coroutine.wrap(function()
				local cframes = data.CFrames[data.Camera]
				local currentCF = data.Camera.CFrame
				for t, cf in pairs(cframes) do
					cache[data.Camera] = cache[data.Camera] or {}
					if pointer >= t and not cache[data.Camera][cf] then
						cache[data.Camera][cf] = true
						currentCF = cf
						break
					end
				end
				twS:Create(data.Camera, TweenInfo.new(1/60/speed), {CFrame=currentCF}):Play()
			end)()
			
			coroutine.wrap(function()
				for ch, cl in pairs(data.BaseParts) do
					local cframes = data.CFrames[cl]
					local currentCF = cl.CFrame
					for t, cf in pairs(cframes) do
						cache[cl] = cache[cl] or {}
						if pointer >= t and not cache[cl][cf] then
							cache[cl][cf] = true
							currentCF = cf
							break
						end
					end
					twS:Create(cl, TweenInfo.new(1/60/speed), {CFrame=currentCF}):Play()
				end
			end)()
		end
	end
	
	function recording:Destroy()
		data.Camera:Destroy()
		data.Camera = nil
		for ch, cl in pairs(data.BaseParts) do
			cl:Destroy()
		end
		data.BaseParts = nil
		data.CFrames = nil
		data.Header = nil
	end
	return recording
end

return replay