-- Makes tarps look like cloth: loose hem flaps swing in gusts of wind and the cloth mesh
-- "breathes" slightly. Runs locally on every client (no network traffic).
local RunService = game:GetService("RunService")

local TarpSwayController = {}

type Info = { base: CFrame, flap: boolean, phase: number, model: Instance? }
local tracked: { [BasePart]: Info } = {}
local MAX_DISTANCE = 150

local function track(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local isFlap = inst:GetAttribute("Flap") ~= nil
	local isSway = inst:GetAttribute("Sway") ~= nil
	if not isFlap and not isSway then
		return
	end
	tracked[inst] = {
		base = inst.CFrame,
		flap = isFlap,
		phase = math.random() * math.pi * 2,
		model = inst:FindFirstAncestorWhichIsA("Model"),
	}
end

function TarpSwayController.init()
	for _, d in workspace:GetDescendants() do
		track(d)
	end
	workspace.DescendantAdded:Connect(track)

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		-- wind gusts: slow swell with quick flutters
		local gust = 0.55 + 0.35 * math.sin(t * 0.37) + 0.2 * math.sin(t * 1.9)
		for part, info in tracked do
			if not part.Parent or (info.model and info.model:GetAttribute("ClientRevealing")) then
				tracked[part] = nil -- gone, or the reveal animation owns the parts now
			elseif (info.base.Position - camPos).Magnitude < MAX_DISTANCE then
				if info.flap then
					local h = part.Size.Y
					local angle = (math.sin(t * 2.3 + info.phase) * 0.16 + math.sin(t * 5.3 + info.phase * 1.7) * 0.05) * gust
					part.CFrame = info.base * CFrame.new(0, h / 2, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -h / 2, 0)
				else
					part.CFrame = info.base
						* CFrame.Angles(math.sin(t * 1.2 + info.phase) * 0.004 * gust, 0, math.sin(t * 0.9 + info.phase) * 0.006 * gust)
				end
			end
		end
	end)
end

return TarpSwayController
