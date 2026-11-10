-- Car Market Tycoon: one-step setup for Roblox Studio.
-- 1) Import assets/CarMeshes.obj (Home -> Import 3D).
-- 2) Copy this whole file into View -> Command Bar and press Enter.
-- It finds the imported meshes, moves them to ReplicatedStorage/Assets/CarMeshes
-- and switches off the Studio test mode (free lots / upgrades).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function findPack()
	for _, inst in ipairs(game:GetDescendants()) do
		if inst:IsA("Model") and inst.Name ~= "CarMeshes" and inst:FindFirstChild("Origin", true) and inst:FindFirstChild("sedan__Body", true) then
			return inst
		end
	end
	local existing = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("CarMeshes")
	return existing
end

local recording = ChangeHistoryService:TryBeginRecording("CarMarketTycoon setup")

local assets = ReplicatedStorage:FindFirstChild("Assets")
if not assets then
	assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
end

local pack = findPack()
if pack then
	pack.Name = "CarMeshes"
	pack.Parent = assets
	for _, d in ipairs(pack:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	print("[Setup] OK: meshes moved to ReplicatedStorage/Assets/CarMeshes (" .. #pack:GetDescendants() .. " objects)")
else
	warn("[Setup] Imported meshes not found. Import assets/CarMeshes.obj first (Home -> Import 3D), then run this again.")
end

local config = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Configs") and ReplicatedStorage.Shared.Configs:FindFirstChild("GameConfig")
if config and config:IsA("ModuleScript") then
	local source = config.Source
	source = source:gsub("FreeLotsInStudio = true", "FreeLotsInStudio = false")
	source = source:gsub("FreeUpgradesInStudio = true", "FreeUpgradesInStudio = false")
	config.Source = source
	print("[Setup] OK: Studio test mode switched off")
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[Setup] Done. Now: File -> Publish to Roblox.")
