-- Player persistence: DataStore loading with session locking, autosave, release on leave,
-- BindToClose flush and retry / error handling.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local Util = require(Shared.Modules.Util)
local Signal = require(Shared.Modules.Signal)

local DataConfig = GameConfig.Data
local LOCK_RETRY_SECONDS = 6
local MAX_LOCK_WAITS = 4 -- after this many waits a lock is taken over (the old server keeps no write access)

local PlayerDataService = {}
PlayerDataService.ProfileLoaded = Signal.new()
PlayerDataService.ProfileReleasing = Signal.new()

local TEMPLATE = {
	version = DataConfig.SchemaVersion,
	cash = GameConfig.Economy.StartingCash,
	xp = 0,
	level = 1,
	vehicles = {}, -- [id] = vehicle record
	displayed = {}, -- array of vehicle ids shown in the showroom
	displayLevel = 1,
	garageSlots = GameConfig.Garage.StartSlots,
	collection = {}, -- [modelKey] = number owned so far
	stats = {
		lotsOpened = 0,
		carsSold = 0,
		totalEarned = 0,
		totalSpent = 0,
		bestValue = 0,
		bestName = "",
		rarityCounts = {},
	},
	salesHistory = {}, -- newest first
	createdAt = 0,
	lastLogin = 0,
}

type Profile = {
	player: Player,
	key: string,
	data: any,
	canSave: boolean,
	saving: boolean,
	released: boolean,
	releaseFired: boolean,
	lastSave: number,
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local function migrate(data)
	data.version = data.version or 0
	if data.version < 1 then
		-- v0 -> v1: make sure every vehicle has the fields introduced in v1
		for _, vehicle in data.vehicles or {} do
			vehicle.mods = vehicle.mods or {}
			vehicle.finds = vehicle.finds or {}
		end
		data.version = 1
	end
	Util.reconcile(data, TEMPLATE)
	-- remove displayed ids that no longer exist
	local cleaned = {}
	for _, id in data.displayed do
		if data.vehicles[id] and not table.find(cleaned, id) then
			table.insert(cleaned, id)
		end
	end
	data.displayed = cleaned
	return data
end

local function loadFromStore(player: Player): (any, boolean)
	if not store then
		return nil, false
	end
	local key = "player_" .. player.UserId
	local attempts, lockWaits = 0, 0
	while player.Parent do
		local loaded, lockedBy = nil, nil
		local ds = store :: DataStore
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(old)
				loaded, lockedBy = nil, nil
				local data = old
				if type(data) ~= "table" then
					data = Util.deepCopy(TEMPLATE)
					data.createdAt = os.time()
				end
				local lock = data.__lock
				if type(lock) == "table" and lock.job ~= game.JobId
					and os.time() - (tonumber(lock.time) or 0) < DataConfig.SessionLockSeconds
					and lockWaits < MAX_LOCK_WAITS then
					lockedBy = lock.job
					return nil -- cancel the write, another server owns the session
				end
				data.__lock = { job = game.JobId, time = os.time() }
				loaded = data
				return data
			end)
		end)
		if ok and loaded then
			return loaded, true
		elseif ok and lockedBy then
			lockWaits += 1
			warn(("[Data] %s is locked by another server, waiting (%d/%d)"):format(player.Name, lockWaits, MAX_LOCK_WAITS))
			task.wait(LOCK_RETRY_SECONDS)
		else
			attempts += 1
			warn(("[Data] Load failed for %s (attempt %d): %s"):format(player.Name, attempts, tostring(err)))
			-- in Studio without API access every call fails the same way: give up quickly
			local maxAttempts = if RunService:IsStudio() then 2 else DataConfig.LoadAttempts
			if attempts >= maxAttempts then
				break
			end
			task.wait(math.min(2 * attempts, 8))
		end
	end
	return nil, false
end

local function saveProfile(profile: Profile, release: boolean): boolean
	if not profile.canSave or not store then
		return true
	end
	while profile.saving do
		task.wait(0.1)
	end
	if profile.released then
		return true
	end
	profile.saving = true
	local lostLock = false
	local ds = store :: DataStore
	local ok, err = pcall(function()
		ds:UpdateAsync(profile.key, function(old)
			lostLock = false
			if type(old) == "table" and type(old.__lock) == "table" and old.__lock.job ~= game.JobId then
				lostLock = true
				return nil
			end
			profile.data.__lock = if release then nil else { job = game.JobId, time = os.time() }
			return profile.data
		end)
	end)
	profile.saving = false
	if not ok then
		warn(("[Data] Save failed for %s: %s"):format(profile.player.Name, tostring(err)))
		return false
	end
	if lostLock then
		warn(("[Data] %s session was taken by another server; this server stops saving"):format(profile.player.Name))
		profile.canSave = false
		if profile.player.Parent then
			profile.player:Kick("Ваш акаунт відкрито на іншому сервері. Перезайдіть у гру.")
		end
		return false
	end
	profile.lastSave = os.clock()
	if release then
		profile.released = true
	end
	return true
end

local function onPlayerAdded(player: Player)
	local data, fromStore = loadFromStore(player)
	local canSave = fromStore
	if not data then
		if RunService:IsStudio() then
			warn("[Data] DataStore unavailable in Studio — using temporary data (progress will NOT be saved). "
				.. "Enable Game Settings > Security > 'Enable Studio Access to API Services' to test saving.")
			data = Util.deepCopy(TEMPLATE)
			data.createdAt = os.time()
			canSave = false
		else
			if player.Parent then
				player:Kick("Не вдалося завантажити ваші дані. Спробуйте зайти ще раз за хвилину.")
			end
			return
		end
	end

	data = migrate(data)
	data.lastLogin = os.time()

	local profile: Profile = {
		player = player,
		key = "player_" .. player.UserId,
		data = data,
		canSave = canSave,
		saving = false,
		released = false,
		releaseFired = false,
		lastSave = os.clock(),
	}

	if not player.Parent then
		-- left while loading: give the lock back straight away
		saveProfile(profile, true)
		return
	end

	profiles[player] = profile
	PlayerDataService.ProfileLoaded:Fire(player, profile)
end

-- Lets other services clean up exactly once, then saves and frees the session lock.
local function releaseProfile(player: Player, profile: Profile)
	if not profile.releaseFired then
		profile.releaseFired = true
		PlayerDataService.ProfileReleasing:Fire(player, profile)
	end
	saveProfile(profile, true)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	releaseProfile(player, profile)
	profiles[player] = nil
end

function PlayerDataService.getProfile(player: Player): Profile?
	return profiles[player]
end

function PlayerDataService.getData(player: Player): any
	local profile = profiles[player]
	return profile and profile.data
end

function PlayerDataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function PlayerDataService.allProfiles(): { [Player]: Profile }
	return profiles
end

function PlayerDataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] Could not open DataStore: " .. tostring(result))
	end
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave loop (staggered, respects the request budget)
	task.spawn(function()
		while true do
			task.wait(DataConfig.AutosaveSeconds)
			for _, profile in profiles do
				if os.clock() - profile.lastSave >= DataConfig.AutosaveSeconds * 0.8 then
					local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
					if budget < 3 then
						warn("[Data] Autosave postponed: request budget is low")
						break
					end
					task.spawn(saveProfile, profile, false)
					task.wait(0.5)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				releaseProfile(player, profile)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
