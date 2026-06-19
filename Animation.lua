local plrs = game:GetService("Players")
local http = game:GetService("HttpService")
local run = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local cg = game:GetService("CoreGui")
local plr = plrs.LocalPlayer

local confPath = "AnimCopierConfig.json"
local conf = { ignored = {}, binds = {}, prefix = true, menuKey = "Y" }

local function loadConf()
	if readfile and isfile and isfile(confPath) then
		local suc, res = pcall(function()
			return http:JSONDecode(readfile(confPath))
		end)
		if suc and type(res) == "table" then
			if res.ignored then
				conf.ignored = res.ignored
			end
			if res.binds then
				conf.binds = res.binds
			end
			if res.prefix ~= nil then
				conf.prefix = res.prefix
			end
			if res.menuKey then
				conf.menuKey = res.menuKey
			end
		end
	end
end
loadConf()

local function getBind(name, def)
	return conf.binds[name] or def
end
local bindObjs = {}

local function saveConf()
	for name, obj in pairs(bindObjs) do
		if type(obj) == "table" and obj.Value ~= nil then
			conf.binds[name] = obj.Value
		end
	end
	if writefile then
		writefile(confPath, http:JSONEncode(conf))
	end
end

local NebulaIcons =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/xKaizoMain/Libraries/refs/heads/main/logo.lua"))()
local Starlight =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/xKaizoMain/Libraries/refs/heads/main/main.lua"))()

local menuKeyCode = Enum.KeyCode[conf.menuKey] or Enum.KeyCode.Y

local Window = Starlight:CreateWindow({
	Name = "Xenon Helper Toolkit",
	Subtitle = "Anim Copier & Dex",
	ToggleKey = menuKeyCode,
	LoadingEnabled = false,
	BuildWarnings = false,
	InterfaceAdvertisingPrompts = false,
	NotifyOnCallbackError = true,
})
Starlight:SetTheme("Nebula")

Window:CreateHomeTab({
	SupportedExecutors = { "Solara", "Wave", "AWP", "Synapse Z", "Fluxus" },
	UnsupportedExecutors = { "Delta", "Hydrogen" },
	DiscordInvite = "xenonscripts",
	IconStyle = 1,
	Changelog = {
		{
			Title = "Xenon Helper Toolkit",
			Date = "Latest",
			Description = "• Visual animation logger and playback controller\n• Multi-variant animation analysis engine\n• Real-time animation timeline graph visualizer\n• Outgoing and Incoming Remote spy engine\n• Clean, optimized, modern UI powered by Starlight",
		},
	},
})

local MainSection = Window:CreateTabSection("TOOLS", true)

local function createButtonWithBind(group, name, btnOpt, extraBindOpt)
	local btnIdx = name .. "Btn"
	local bindIdx = name .. "Bind"

	local btn = group:CreateButton(btnOpt, btnIdx)

	local bindSettings = {
		CurrentValue = getBind(name, "None"),
		Callback = btnOpt.Callback,
	}
	if extraBindOpt then
		for k, v in pairs(extraBindOpt) do
			bindSettings[k] = v
		end
	end

	local lbl = group:CreateLabel({ Name = btnOpt.Name .. " Bind" }, name .. "Lbl")
	local bind = lbl:AddBind(bindSettings, bindIdx)
	bindObjs[name] = bind
	return bind
end

local logTab = MainSection:CreateTab({ Name = "Logger", Icon = NebulaIcons:GetIcon("file-text", "Lucide") }, "LogTab")
local playTab =
	MainSection:CreateTab({ Name = "Player", Icon = NebulaIcons:GetIcon("circle-play", "Lucide") }, "PlayTab")
local varTab =
	MainSection:CreateTab({ Name = "Variants", Icon = NebulaIcons:GetIcon("git-branch", "Lucide") }, "VarTab")
local tlTab = MainSection:CreateTab({ Name = "Timeline", Icon = NebulaIcons:GetIcon("activity", "Lucide") }, "TlTab")
local dexTab = MainSection:CreateTab({ Name = "Dex", Icon = NebulaIcons:GetIcon("terminal", "Lucide") }, "DexTab")
local setTab = MainSection:CreateTab({ Name = "Settings", Icon = NebulaIcons:GetIcon("settings", "Lucide") }, "SetTab")

local logGroup = logTab:CreateGroupbox({ Name = "Logger Options", Column = 1 }, "LogGroup")
local animGroup = logTab:CreateGroupbox({ Name = "Logged Animations", Column = 2 }, "AnimGroup")
local playGroup = playTab:CreateGroupbox({ Name = "Playback", Column = 1 }, "PlayGroup")
local varGroup = varTab:CreateGroupbox({ Name = "Variant Analysis", Column = 1 }, "VarGroup")
local tlGroup = tlTab:CreateGroupbox({ Name = "Timeline Graph", Column = 1 }, "TlGroup")
local dexGroup = dexTab:CreateGroupbox({ Name = "Universal Tools", Column = 1 }, "DexGroup")
local setGroup = setTab:CreateGroupbox({ Name = "Config", Column = 1 }, "SetGroup")
local keyGroup = setTab:CreateGroupbox({ Name = "Keybinds", Column = 2 }, "KeyGroup")

dexGroup:CreateButton({
	Name = "Load Dex",
	Callback = function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/xKaizoMain/Utility/refs/heads/main/Dex.lua"))()
	end,
}, "LoadDexBtn")

local logged = {}
local ignored = conf.ignored
local btns = {}
local target = "Self"
local selPlr = ""
local curId, curName, curPath = nil, nil, nil
local dropIgnored = nil
local playId = ""
local track = nil
local spd = 1
local skipTm = 0

local variants = {}
local gaps = {}
local lastLen = 0
local analyzing = false
local livePlaying = false
local gapThresh = 0.5
local lastData = {}
local tlViewerInstance = nil
local tlViewerOpen = false

local function getPlrs()
	local t = {}
	for _, p in ipairs(plrs:GetPlayers()) do
		table.insert(t, p.Name)
	end
	return t
end

local function refreshIgnored()
	if not dropIgnored then
		return
	end
	local opts = {}
	for id in pairs(ignored) do
		table.insert(opts, id)
	end
	if #opts == 0 then
		table.insert(opts, "None")
	end
	dropIgnored:Set({ Options = opts })
end

local function getChar()
	return plr.Character
end
local function getAnimator()
	local c = getChar()
	if not c then
		return
	end
	local h = c:FindFirstChild("Humanoid")
	if not h then
		return
	end
	return h:FindFirstChild("Animator") or h:WaitForChild("Animator", 3)
end

local function playRange(rs, re, speed)
	if playId == "" then
		return
	end
	local a2 = getAnimator()
	if not a2 then
		return
	end
	local a = Instance.new("Animation")
	a.AnimationId = "rbxassetid://" .. playId
	if track then
		track:Stop()
	end
	track = a2:LoadAnimation(a)
	track.Looped = false
	track:Play()
	track.TimePosition = rs or 0
	if speed then
		track:AdjustSpeed(speed)
	end
	if re then
		task.spawn(function()
			while track and track.IsPlaying and track.TimePosition < re do
				task.wait()
			end
			if track and track.IsPlaying then
				track:Stop()
			end
		end)
	end
end

plr.CharacterAdded:Connect(function()
	track = nil
end)

logGroup:CreateLabel({ Name = "Log Target" }, "LogTargetLbl"):AddDropdown({
	Options = { "Self", "Everyone", "Selected" },
	CurrentOption = { "Self" },
	Callback = function(v)
		target = v[1]
	end,
}, "LogTargetDropdown")

local dropPlrs = logGroup:CreateLabel({ Name = "Selected Player" }, "SelPlrLbl"):AddDropdown({
	Options = getPlrs(),
	CurrentOption = { plr.Name },
	Callback = function(v)
		selPlr = v[1]
	end,
}, "SelPlrDropdown")

createButtonWithBind(logGroup, "RefreshPlrs", {
	Name = "Refresh Players",
	Icon = NebulaIcons:GetIcon("refresh-cw", "Lucide"),
	Callback = function()
		dropPlrs:Set({ Options = getPlrs() })
	end,
}, { SyncToggleState = false })

createButtonWithBind(logGroup, "ClearAll", {
	Name = "Clear All",
	Icon = NebulaIcons:GetIcon("trash-2", "Lucide"),
	Callback = function()
		for _, btn in pairs(btns) do
			if btn and btn.Destroy then
				btn:Destroy()
			end
		end
		table.clear(btns)
		table.clear(logged)
		curId = nil
	end,
})

logGroup:CreateDivider()

local function copyIdAction()
	if curId then
		local s = conf.prefix and ("rbxassetid://" .. curId) or curId
		setclipboard(s)
	end
end

createButtonWithBind(
	logGroup,
	"CopyId",
	{ Name = "Copy ID", Icon = NebulaIcons:GetIcon("clipboard", "Lucide"), Callback = copyIdAction }
)

createButtonWithBind(logGroup, "CopyName", {
	Name = "Copy Name",
	Icon = NebulaIcons:GetIcon("type", "Lucide"),
	Callback = function()
		if curName then
			setclipboard(curName)
		end
	end,
})

createButtonWithBind(logGroup, "CopyPath", {
	Name = "Copy Path",
	Icon = NebulaIcons:GetIcon("folder", "Lucide"),
	Callback = function()
		if curPath then
			setclipboard(curPath)
		end
	end,
})

createButtonWithBind(logGroup, "IgnoreAnim", {
	Name = "Ignore",
	Icon = NebulaIcons:GetIcon("eye-off", "Lucide"),
	Callback = function()
		if curId then
			ignored[curId] = true
			logged[curId] = nil
			if btns[curId] then
				btns[curId]:Destroy()
				btns[curId] = nil
			end
			refreshIgnored()
			curId = nil
		end
	end,
})

local function getAnimPlr(animator)
	if not animator then
		return
	end
	local hum = animator.Parent
	if not hum or not hum:IsA("Humanoid") then
		return
	end
	return plrs:GetPlayerFromCharacter(hum.Parent)
end

local function logAnim(animTrack, animator)
	if target == "Self" then
		if getAnimPlr(animator) ~= plr then
			return
		end
	elseif target == "Selected" then
		local p = getAnimPlr(animator)
		if not p or p.Name ~= selPlr then
			return
		end
	end
	local animObj = animTrack.Animation
	if not animObj then
		return
	end
	local id = animObj.AnimationId:match("%d+")
	if not id or ignored[id] or logged[id] then
		return
	end

	local aName = (animObj.Name ~= "Animation") and animObj.Name or animTrack.Name
	if not aName or aName == "" or aName == "Animation" then
		aName = "Anim_" .. id
	end
	local aPath = animObj:GetFullName()

	logged[id] = { Name = aName, Id = id, Path = aPath }

	local btn = animGroup:CreateButton({
		Name = string.format("%s  (rbxassetid://%s)", aName, id),
		Callback = function()
			curId = id
			curName = aName
			curPath = aPath
			Window:PromptDialog({
				Name = aName,
				Content = string.format("ID: rbxassetid://%s\nPath: %s", id, aPath),
				Type = 1,
				Actions = {
					Primary = {
						Name = "Load and Play",
						Icon = NebulaIcons:GetIcon("play", "Lucide"),
						Callback = function()
							playId = id
							playRange(0, nil, spd)
						end,
					},
					{
						Name = "Load into Player",
						Icon = NebulaIcons:GetIcon("play-circle", "Lucide"),
						Callback = function()
							playId = id
						end,
					},
					{
						Name = "Load into Variants",
						Icon = NebulaIcons:GetIcon("git-branch", "Lucide"),
						Callback = function()
							playId = id
						end,
					},
					{
						Name = "Load into Timeline",
						Icon = NebulaIcons:GetIcon("activity", "Lucide"),
						Callback = function()
							playId = id
						end,
					},
					{
						Name = "Copy ID",
						Icon = NebulaIcons:GetIcon("clipboard", "Lucide"),
						Callback = function()
							setclipboard(conf.prefix and ("rbxassetid://" .. id) or id)
						end,
					},
					{
						Name = "Copy Name",
						Icon = NebulaIcons:GetIcon("type", "Lucide"),
						Callback = function()
							setclipboard(aName)
						end,
					},
					{
						Name = "Copy Path",
						Icon = NebulaIcons:GetIcon("folder", "Lucide"),
						Callback = function()
							setclipboard(aPath)
						end,
					},
					{
						Name = "Ignore",
						Icon = NebulaIcons:GetIcon("eye-off", "Lucide"),
						Callback = function()
							ignored[id] = true
							logged[id] = nil
							if btns[id] then
								btns[id]:Destroy()
								btns[id] = nil
							end
							refreshIgnored()
						end,
					},
					{
						Name = "Cancel",
						Callback = function() end,
					},
				},
			})
		end,
	}, "AnimBtn_" .. id)
	btns[id] = btn
end

game.DescendantAdded:Connect(function(d)
	if not d:IsA("Animator") then
		return
	end
	d.AnimationPlayed:Connect(function(t)
		if t.Animation then
			logAnim(t, d)
		end
	end)
end)
for _, d in ipairs(game:GetDescendants()) do
	if not d:IsA("Animator") then
		continue
	end
	d.AnimationPlayed:Connect(function(t)
		if t.Animation then
			logAnim(t, d)
		end
	end)
end

playGroup:CreateInput({
	Name = "Animation ID",
	Placeholder = "Enter ID...",
	Callback = function(v)
		playId = v:match("%d+") or ""
	end,
}, "PlayIdInput")

createButtonWithBind(playGroup, "LoadPlay", {
	Name = "Load And Play",
	Icon = NebulaIcons:GetIcon("play", "Lucide"),
	Callback = function()
		if playId == "" then
			return
		end
		local a2 = getAnimator()
		if not a2 then
			return
		end
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://" .. playId
		if track then
			track:Stop()
		end
		track = a2:LoadAnimation(a)
		track:Play()
		if spd ~= 1 then
			track:AdjustSpeed(spd)
		end
	end,
})

createButtonWithBind(playGroup, "CopyLen", {
	Name = "Copy Length",
	Icon = NebulaIcons:GetIcon("clock", "Lucide"),
	Callback = function()
		if not track then
			return
		end
		task.delay(0.1, function()
			local l = string.format("%.6f", track.Length)
			setclipboard(l)
		end)
	end,
})

createButtonWithBind(playGroup, "StopAnim", {
	Name = "Stop",
	Icon = NebulaIcons:GetIcon("square", "Lucide"),
	Callback = function()
		if track then
			track:Stop()
		end
	end,
})

playGroup:CreateDivider()

playGroup:CreateInput({
	Name = "Play Speed",
	Placeholder = "1",
	Callback = function(v)
		spd = tonumber(v) or 1
	end,
}, "PlaySpeedInput")

createButtonWithBind(playGroup, "ApplySpd", {
	Name = "Apply Speed",
	Icon = NebulaIcons:GetIcon("fast-forward", "Lucide"),
	Callback = function()
		if not track then
			return
		end
		track:AdjustSpeed(spd)
	end,
})

playGroup:CreateInput({
	Name = "Skip To Point",
	Placeholder = "0.5",
	Callback = function(v)
		skipTm = tonumber(v) or 0
	end,
}, "SkipToPointInput")

createButtonWithBind(playGroup, "SkipFrz", {
	Name = "Skip And Freeze",
	Icon = NebulaIcons:GetIcon("pause-circle", "Lucide"),
	Callback = function()
		if not track then
			return
		end
		track.TimePosition = skipTm
		track:AdjustSpeed(0)
	end,
})

playGroup:CreateDivider()

local liveInfoLabel = playGroup:CreateLabel({ Name = "Status: Ready" }, "LiveInfoLabel")

createButtonWithBind(playGroup, "PlayMeasure", {
	Name = "Play And Measure",
	Icon = NebulaIcons:GetIcon("activity", "Lucide"),
	Callback = function()
		if livePlaying then
			return
		end
		if playId == "" then
			return
		end
		local a2 = getAnimator()
		if not a2 then
			return
		end
		livePlaying = true
		liveInfoLabel:Set({ Name = "Status: Loading..." })
		task.spawn(function()
			local ok, err = pcall(function()
				local a = Instance.new("Animation")
				a.AnimationId = "rbxassetid://" .. playId
				local lt = a2:LoadAnimation(a)
				lt.Looped = false
				lt.Priority = Enum.AnimationPriority.Action4
				local w = 0
				while (not lt.Length or lt.Length == 0) and w < 2 do
					task.wait(0.05)
					w = w + 0.05
				end
				local len = lt.Length
				local t0 = os.clock()
				local last = 0
				lt:Play()
				local hb = run.Heartbeat:Connect(function()
					local now = os.clock()
					if now - last < 0.05 then
						return
					end
					last = now
					local el = now - t0
					liveInfoLabel:Set({ Name = string.format("Status: %.5f / %.5f s", el, len) })
				end)
				lt.Stopped:Wait()
				hb:Disconnect()
				local dur = os.clock() - t0
				liveInfoLabel:Set({ Name = string.format("Done: %.6f s (asset: %.6f s)", dur, len) })
				track = lt
			end)
			livePlaying = false
			if not ok then
				liveInfoLabel:Set({ Name = "Status: Error: " .. tostring(err) })
			end
		end)
	end,
})

varGroup:CreateInput({
	Name = "Animation ID",
	Placeholder = "Uses Player ID if empty...",
	Callback = function(v)
		local id = v:match("%d+")
		if id and id ~= "" then
			playId = id
		end
	end,
}, "VarIdInput")

local varInfoLabel = varGroup:CreateLabel({ Name = "Analysis: Click Analyze to scan for variants" }, "VarInfoLabel")

createButtonWithBind(varGroup, "Analyze", {
	Name = "Analyze Variants",
	Icon = NebulaIcons:GetIcon("git-merge", "Lucide"),
	Callback = function()
		if analyzing then
			return
		end
		if playId == "" then
			return
		end
		local a2 = getAnimator()
		if not a2 then
			return
		end
		local char = getChar()
		if not char then
			return
		end
		analyzing = true
		varInfoLabel:Set({ Name = "Analysis: Analyzing..." })
		task.spawn(function()
			local ok, err = pcall(function()
				local root = char:FindFirstChild("HumanoidRootPart")
				local joints = {}
				for _, d in ipairs(char:GetDescendants()) do
					if d:IsA("Motor6D") and (not root or d.Part0 ~= root) then
						table.insert(joints, d)
					end
				end
				local a = Instance.new("Animation")
				a.AnimationId = "rbxassetid://" .. playId
				local vt = a2:LoadAnimation(a)
				vt.Looped = false
				local w = 0
				while (not vt.Length or vt.Length == 0) and w < 2 do
					task.wait(0.05)
					w = w + 0.05
				end
				local tData = {}
				local scanning = false
				local conn = run.Heartbeat:Connect(function()
					if not scanning or not vt.IsPlaying then
						return
					end
					local m = 0
					for _, j in ipairs(joints) do
						m = m + j.Transform.Position.Magnitude
					end
					table.insert(tData, { Time = vt.TimePosition, Motion = m })
				end)
				vt:Play()
				scanning = true
				vt.Stopped:Wait()
				scanning = false
				conn:Disconnect()
				local len = vt.Length
				lastLen = len
				lastData = tData

				gaps = {}
				local ps, pe = nil, nil
				for i = 2, #tData do
					local f = tData[i]
					if f.Motion < 0.05 then
						if not ps then
							ps = f.Time
						end
						pe = f.Time
					elseif ps and pe then
						if (pe - ps) >= gapThresh then
							table.insert(gaps, { s = ps, e = pe })
						end
						ps, pe = nil, nil
					end
				end
				if ps and pe and (pe - ps) >= gapThresh then
					table.insert(gaps, { s = ps, e = pe })
				end

				variants = {}
				local pos = 0
				for _, g in ipairs(gaps) do
					if g.s > pos then
						table.insert(variants, { s = pos, e = g.s })
					end
					pos = g.e
				end
				if pos < len then
					table.insert(variants, { s = pos, e = len })
				end

				local desc = string.format("ID: rbxassetid://%s  |  Length: %.6f s", playId, len)
				if #gaps > 0 then
					desc = desc .. string.format("  |  Gaps: %d  |  Variants: %d", #gaps, #variants)
				else
					desc = desc .. "  |  No pause gaps detected"
				end
				varInfoLabel:Set({ Name = desc })
				vt:Destroy()
				a:Destroy()
			end)
			analyzing = false
			if not ok then
				varInfoLabel:Set({ Name = "Analysis: Error: " .. tostring(err) })
			end
		end)
	end,
})

createButtonWithBind(varGroup, "CopyAnalysis", {
	Name = "Copy Analysis",
	Icon = NebulaIcons:GetIcon("clipboard-list", "Lucide"),
	Callback = function()
		if #variants == 0 and #gaps == 0 then
			return
		end
		local out = string.format("ID: rbxassetid://%s\nTotal Length: %.6f s\n", playId, lastLen)
		if #gaps > 0 then
			out = out .. "\n"
			for i, g in ipairs(gaps) do
				out = out .. string.format("Pause Gap %d:  %.5f s  ->  %.5f s\n", i, g.s, g.e)
			end
		else
			out = out .. "\nNo pause gaps\n"
		end
		out = out .. "\n"
		for i, v in ipairs(variants) do
			out = out .. string.format("Variant %d:  %.5f s  ->  %.5f s\n", i, v.s, v.e)
		end
		setclipboard(out)
	end,
})

varGroup:CreateDivider()

local varBtns = {}

local function clearVarBtns()
	for _, b in ipairs(varBtns) do
		if b and b.Destroy then
			b:Destroy()
		end
	end
	table.clear(varBtns)
end

createButtonWithBind(varGroup, "RefreshVars", {
	Name = "Refresh Variant Buttons",
	Icon = NebulaIcons:GetIcon("refresh-ccw", "Lucide"),
	Callback = function()
		clearVarBtns()
		if #variants == 0 then
			return
		end
		for i, v in ipairs(variants) do
			local b = varGroup:CreateButton({
				Name = string.format("Variant %d  (%.5f -> %.5f)", i, v.s, v.e),
				Callback = function()
					playRange(v.s, v.e, spd)
				end,
			}, "VarBtn_" .. i)
			table.insert(varBtns, b)
		end
	end,
})

varGroup:CreateDivider()

local rStart, rEnd = 0, nil
varGroup:CreateInput({
	Name = "Range Start",
	Placeholder = "0.0",
	Callback = function(v)
		rStart = tonumber(v) or 0
	end,
}, "RangeStartInput")
varGroup:CreateInput({
	Name = "Range End",
	Placeholder = "Leave empty for full",
	Callback = function(v)
		rEnd = tonumber(v)
	end,
}, "RangeEndInput")

createButtonWithBind(varGroup, "PlayRange", {
	Name = "Play Range",
	Icon = NebulaIcons:GetIcon("play-circle", "Lucide"),
	Callback = function()
		if playId == "" then
			return
		end
		playRange(rStart, rEnd, spd)
	end,
})

createButtonWithBind(varGroup, "StopRange", {
	Name = "Stop",
	Icon = NebulaIcons:GetIcon("square", "Lucide"),
	Callback = function()
		if track then
			track:Stop()
		end
	end,
})

tlGroup:CreateInput({
	Name = "Animation ID",
	Placeholder = "Uses Player ID if empty...",
	Callback = function(v)
		local id = v:match("%d+")
		if id and id ~= "" then
			playId = id
		end
	end,
}, "TlIdInput")

local tlInfoLabel = tlGroup:CreateLabel({ Name = "Timeline: Load an animation to begin" }, "TlInfoLabel")
local tlPosLabel = tlGroup:CreateLabel({ Name = "Position: 0.000000 s / 0.000000 s" }, "TlPosLabel")

createButtonWithBind(tlGroup, "OpenVisualTimeline", {
	Name = "Open Visual Graph Menu",
	Icon = NebulaIcons:GetIcon("bar-chart-2", "Lucide"),
	Callback = function()
		if not tlViewerInstance then
			tlViewerInstance = loadstring(
				game:HttpGet("https://raw.githubusercontent.com/xKaizoMain/Utility/refs/heads/main/Timeline.lua")
			)()
		end
		tlViewerInstance.toggle({
			getTrack = function()
				return track
			end,
			getLastLen = function()
				return lastLen
			end,
			getVariants = function()
				return variants
			end,
			getGaps = function()
				return gaps
			end,
			getLastData = function()
				return lastData
			end,
			getSpd = function()
				return spd
			end,
			setSpd = function(s)
				spd = s
			end,
			playRange = function(rs, re, speed)
				playRange(rs, re, speed)
			end,
		})
		tlViewerOpen = not tlViewerOpen
	end,
})

tlGroup:CreateDivider()

tlGroup:CreateInput({
	Name = "Speed",
	Placeholder = "1",
	Callback = function(v)
		spd = tonumber(v) or 1
	end,
}, "TlSpeedInput")

createButtonWithBind(tlGroup, "TlApplySpd", {
	Name = "Apply Speed",
	Icon = NebulaIcons:GetIcon("fast-forward", "Lucide"),
	Callback = function()
		if track then
			track:AdjustSpeed(spd)
		end
	end,
})

createButtonWithBind(tlGroup, "TlFreeze", {
	Name = "Freeze",
	Icon = NebulaIcons:GetIcon("pause", "Lucide"),
	Callback = function()
		if track then
			track:AdjustSpeed(0)
		end
	end,
})

createButtonWithBind(tlGroup, "TlResume", {
	Name = "Resume",
	Icon = NebulaIcons:GetIcon("play", "Lucide"),
	Callback = function()
		if track then
			track:AdjustSpeed(spd)
		end
	end,
})

run.Heartbeat:Connect(function()
	if not track then
		return
	end
	local len = (track.Length and track.Length > 0) and track.Length or 1
	local pos = track.TimePosition or 0
	tlPosLabel:Set({ Name = string.format("Position: %.6f s / %.6f s", pos, len) })
end)

createButtonWithBind(setGroup, "SaveConf", {
	Name = "Save Config",
	Icon = NebulaIcons:GetIcon("save", "Lucide"),
	Callback = function()
		saveConf()
	end,
})

setGroup:CreateToggle({
	Name = "Include Asset Prefix",
	CurrentValue = conf.prefix,
	Callback = function(v)
		conf.prefix = v
	end,
}, "IncludeAssetPrefixToggle")

setGroup:CreateInput({
	Name = "Variant Gap Threshold",
	Placeholder = "0.5 seconds (pauses below this are not gaps)",
	Callback = function(v)
		local t = tonumber(v)
		if t then
			gapThresh = t
		end
	end,
}, "GapThresholdInput")

local selIgnored = "None"
dropIgnored = setGroup:CreateLabel({ Name = "Ignored Animations" }, "IgnoredAnimsLabel"):AddDropdown({
	Options = { "None" },
	CurrentOption = { "None" },
	Callback = function(v)
		selIgnored = v[1]
	end,
}, "IgnoredAnimsDropdown")
refreshIgnored()

createButtonWithBind(setGroup, "UnIgnore", {
	Name = "Unignore Selected",
	Icon = NebulaIcons:GetIcon("eye", "Lucide"),
	Callback = function()
		if selIgnored and selIgnored ~= "None" and ignored[selIgnored] then
			ignored[selIgnored] = nil
			refreshIgnored()
		end
	end,
})

keyGroup:CreateLabel({ Name = "Menu Toggle Key (default: Y)" }, "MenuKeyLbl")
keyGroup:CreateInput({
	Name = "Menu Toggle Key",
	Placeholder = conf.menuKey or "Y",
	Callback = function(v)
		v = v:upper():gsub("%s+", "")
		if v == "" then
			return
		end
		local ok, kc = pcall(function()
			return Enum.KeyCode[v]
		end)
		if ok and kc then
			conf.menuKey = v
			Window:SetToggleKey(kc)
		else
		end
	end,
}, "MenuKeyInput")

keyGroup:CreateDivider()

keyGroup:CreateLabel({ Name = "Action Keybinds" }, "ActionBindsLbl")
keyGroup:CreateLabel({ Name = "Set keybinds for actions using the Logger tab controls." }, "ActionBindsHintLbl")
