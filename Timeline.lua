local TimelineViewer = {}

local cg = game:GetService("CoreGui")
local run = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local plrs = game:GetService("Players")
local plr = plrs.LocalPlayer

local previewAnim = nil
local previewTrack = nil
local previewActive = false

local function getChar()
	local c = plr.Character
	return c
end

function TimelineViewer.startPreview(id)
	if previewActive then
		TimelineViewer.stopPreview()
	end
	local h = getChar()
	if not h then
		return
	end
	local hum = h:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	previewAnim = Instance.new("Animation")
	previewAnim.AnimationId = "rbxassetid://" .. tostring(id)
	local ok, tr = pcall(function()
		return hum:LoadAnimation(previewAnim)
	end)
	if not ok or not tr then
		if previewAnim then
			previewAnim:Destroy()
		end
		previewAnim = nil
		return
	end
	previewTrack = tr
	previewTrack.Looped = false
	previewTrack:Play()
	previewTrack:AdjustSpeed(0)
	previewTrack.TimePosition = 0
	previewActive = true
end

function TimelineViewer.stopPreview()
	if previewTrack then
		pcall(function()
			previewTrack:Stop()
		end)
		previewTrack = nil
	end
	if previewAnim then
		pcall(function()
			previewAnim:Destroy()
		end)
		previewAnim = nil
	end
	previewActive = false
end

function TimelineViewer.setPreviewTime(t)
	if not previewActive or not previewTrack then
		return
	end
	pcall(function()
		previewTrack.TimePosition = tonumber(t) or 0
		previewTrack:Play()
		previewTrack:AdjustSpeed(0)
	end)
end

local function mkCorner(r, p)
	local c = Instance.new("UICorner", p)
	c.CornerRadius = UDim.new(0, r)
end
local function mkStroke(col, th, p)
	local s = Instance.new("UIStroke", p)
	s.Color = col
	s.Thickness = th
end

local tlGui = nil
local tlHb = nil

function TimelineViewer.destroy()
	if tlHb then
		tlHb:Disconnect()
		tlHb = nil
	end
	if tlGui then
		tlGui:Destroy()
		tlGui = nil
	end
end

function TimelineViewer.build(cfg)
	TimelineViewer.destroy()
	tlGui = Instance.new("ScreenGui")
	tlGui.Name = "AnimTimeline"
	tlGui.ResetOnSpawn = false
	pcall(function()
		tlGui.Parent = cg
	end)

	local tf = Instance.new("Frame", tlGui)
	tf.Size = UDim2.fromOffset(620, 290)
	tf.Position = UDim2.new(0.5, -310, 0.5, -145)
	tf.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
	tf.BorderSizePixel = 0
	tf.Active = true
	tf.Draggable = true
	mkCorner(8, tf)
	mkStroke(Color3.fromRGB(40, 40, 50), 1, tf)

	local hdr = Instance.new("TextLabel", tf)
	hdr.Size = UDim2.new(1, -36, 0, 30)
	hdr.Position = UDim2.new(0, 12, 0, 0)
	hdr.BackgroundTransparency = 1
	hdr.Text = "⬡ TIMELINE VIEWER"
	hdr.TextColor3 = Color3.fromRGB(145, 105, 255)
	hdr.Font = Enum.Font.GothamBold
	hdr.TextSize = 13
	hdr.TextXAlignment = Enum.TextXAlignment.Left

	local tlX = Instance.new("TextButton", tf)
	tlX.Size = UDim2.fromOffset(24, 24)
	tlX.Position = UDim2.new(1, -30, 0, 3)
	tlX.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	tlX.BackgroundTransparency = 0.3
	tlX.Text = "✕"
	tlX.TextColor3 = Color3.fromRGB(200, 200, 200)
	tlX.Font = Enum.Font.GothamBold
	tlX.TextSize = 16
	mkCorner(6, tlX)
	mkStroke(Color3.fromRGB(100, 100, 120), 1, tlX)
	tlX.MouseButton1Click:Connect(TimelineViewer.destroy)

	local infoHdr = Instance.new("TextLabel", tf)
	infoHdr.Size = UDim2.new(1, -24, 0, 20)
	infoHdr.Position = UDim2.new(0, 12, 0, 26)
	infoHdr.BackgroundTransparency = 1
	infoHdr.TextColor3 = Color3.fromRGB(160, 160, 160)
	infoHdr.Font = Enum.Font.Code
	infoHdr.TextSize = 11
	infoHdr.TextXAlignment = Enum.TextXAlignment.Left

	local lastLen = cfg.getLastLen()
	local variants = cfg.getVariants()
	local gaps = cfg.getGaps()
	local lastData = cfg.getLastData()

	local infoTxt = "No data — run Analyze Variants in the Variants tab first"
	if lastLen > 0 then
		infoTxt = string.format("Total: %.5f s  |  ", lastLen)
		if #variants > 0 then
			for i, v in ipairs(variants) do
				infoTxt = infoTxt .. string.format("V%d: %.5f→%.5f  |  ", i, v.s, v.e)
			end
		end
		if #gaps > 0 then
			for i, g in ipairs(gaps) do
				infoTxt = infoTxt .. string.format("Pause: %.5f→%.5f  |  ", g.s, g.e)
			end
		end
	end
	infoHdr.Text = infoTxt

	local gb = Instance.new("Frame", tf)
	gb.Size = UDim2.new(1, -24, 0, 80)
	gb.Position = UDim2.new(0, 12, 0, 50)
	gb.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	gb.BorderSizePixel = 0
	gb.ClipsDescendants = true
	mkCorner(4, gb)

	local varCols = { Color3.fromRGB(35, 75, 55), Color3.fromRGB(45, 55, 120), Color3.fromRGB(80, 45, 80) }
	local gapCol = Color3.fromRGB(100, 85, 30)

	if lastLen > 0 then
		for i, v in ipairs(variants) do
			local hl = Instance.new("Frame", gb)
			hl.BackgroundColor3 = varCols[((i - 1) % #varCols) + 1]
			hl.BackgroundTransparency = 0
			hl.BorderSizePixel = 0
			hl.Size = UDim2.new((v.e - v.s) / lastLen, 0, 1, 0)
			hl.Position = UDim2.new(v.s / lastLen, 0, 0, 0)
		end
		for _, g in ipairs(gaps) do
			local hl = Instance.new("Frame", gb)
			hl.BackgroundColor3 = gapCol
			hl.BackgroundTransparency = 0
			hl.BorderSizePixel = 0
			hl.Size = UDim2.new((g.e - g.s) / lastLen, 0, 1, 0)
			hl.Position = UDim2.new(g.s / lastLen, 0, 0, 0)
		end
	end

	if lastLen and lastLen > 0 and #lastData > 0 then
		local maxM = 0.001
		for _, f in ipairs(lastData) do
			if f.Motion > maxM then
				maxM = f.Motion
			end
		end
		local step = math.max(1, math.floor(#lastData / 400))
		for i = 1, #lastData, step do
			local f = lastData[i]
			local xPct = (f.Time / lastLen)
			local hPct = math.clamp(f.Motion / maxM, 0, 1)
			local bar = Instance.new("Frame", gb)
			bar.Size = UDim2.new(step / #lastData, 1, hPct, 0)
			bar.Position = UDim2.new(xPct, 0, 1 - hPct, 0)
			bar.BackgroundColor3 = Color3.fromRGB(125, 95, 235)
			bar.BorderSizePixel = 0
		end
	end

	local playhead = Instance.new("Frame", gb)
	playhead.Size = UDim2.new(0, 2, 1, 0)
	playhead.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	playhead.BorderSizePixel = 0
	playhead.ZIndex = 10
	playhead.Position = UDim2.new(0, 0, 0, 0)

	local scrub = Instance.new("Frame", tf)
	scrub.Size = UDim2.new(1, -24, 0, 18)
	scrub.Position = UDim2.new(0, 12, 0, 138)
	scrub.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	scrub.BorderSizePixel = 0
	scrub.Active = true
	mkCorner(9, scrub)

	local scrubFill = Instance.new("Frame", scrub)
	scrubFill.Size = UDim2.new(0, 0, 1, 0)
	scrubFill.BackgroundColor3 = Color3.fromRGB(95, 65, 215)
	scrubFill.BorderSizePixel = 0
	mkCorner(9, scrubFill)

	local handle = Instance.new("TextButton", scrub)
	handle.Size = UDim2.fromOffset(20, 20)
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.Position = UDim2.new(0, 0, 0.5, 0)
	handle.BackgroundColor3 = Color3.fromRGB(200, 175, 255)
	handle.Text = ""
	handle.ZIndex = 6
	handle.BorderSizePixel = 0
	mkCorner(10, handle)

	local timeLbl = Instance.new("TextLabel", tf)
	timeLbl.Size = UDim2.new(0.6, 0, 0, 16)
	timeLbl.Position = UDim2.new(0, 12, 0, 164)
	timeLbl.BackgroundTransparency = 1
	timeLbl.Text = "Position: 0.000000 s  |  Total: 0.000000 s"
	timeLbl.TextColor3 = Color3.fromRGB(165, 165, 185)
	timeLbl.Font = Enum.Font.Code
	timeLbl.TextSize = 11
	timeLbl.TextXAlignment = Enum.TextXAlignment.Left

	local r1y = 188
	local spdLbl = Instance.new("TextLabel", tf)
	spdLbl.Size = UDim2.fromOffset(50, 24)
	spdLbl.Position = UDim2.new(0, 12, 0, r1y)
	spdLbl.BackgroundTransparency = 1
	spdLbl.Text = "Speed:"
	spdLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
	spdLbl.Font = Enum.Font.Gotham
	spdLbl.TextSize = 12
	spdLbl.TextXAlignment = Enum.TextXAlignment.Left

	local spdInp = Instance.new("TextBox", tf)
	spdInp.Size = UDim2.fromOffset(50, 24)
	spdInp.Position = UDim2.new(0, 60, 0, r1y)
	spdInp.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	spdInp.TextColor3 = Color3.fromRGB(220, 220, 220)
	spdInp.Font = Enum.Font.Gotham
	spdInp.TextSize = 12
	spdInp.Text = tostring(cfg.getSpd())
	mkCorner(4, spdInp)

	local function mkBtn(txt, col, x, y, w)
		local b = Instance.new("TextButton", tf)
		b.Size = UDim2.fromOffset(w, 24)
		b.Position = UDim2.new(0, x, 0, y)
		b.BackgroundColor3 = col
		b.Text = txt
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		mkCorner(4, b)
		return b
	end

	local applyBtn = mkBtn("Apply", Color3.fromRGB(65, 45, 160), 118, r1y, 60)
	applyBtn.MouseButton1Click:Connect(function()
		local s = tonumber(spdInp.Text)
		if s then
			cfg.setSpd(s)
			local tr = cfg.getTrack()
			if tr then
				tr:AdjustSpeed(s)
			end
		end
	end)

	local tlStartInp = Instance.new("TextBox", tf)
	tlStartInp.Size = UDim2.fromOffset(60, 24)
	tlStartInp.Position = UDim2.new(0, 186, 0, r1y)
	tlStartInp.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	tlStartInp.TextColor3 = Color3.fromRGB(220, 220, 220)
	tlStartInp.Font = Enum.Font.Gotham
	tlStartInp.TextSize = 12
	tlStartInp.Text = ""
	tlStartInp.PlaceholderText = "Start s"
	mkCorner(4, tlStartInp)

	local tlEndInp = Instance.new("TextBox", tf)
	tlEndInp.Size = UDim2.fromOffset(60, 24)
	tlEndInp.Position = UDim2.new(0, 254, 0, r1y)
	tlEndInp.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	tlEndInp.TextColor3 = Color3.fromRGB(220, 220, 220)
	tlEndInp.Font = Enum.Font.Gotham
	tlEndInp.TextSize = 12
	tlEndInp.Text = ""
	tlEndInp.PlaceholderText = "End s"
	mkCorner(4, tlEndInp)

	local r2y = 220
	local playRangeBtn = mkBtn("▶ Play Range", Color3.fromRGB(65, 45, 160), 12, r2y, 95)
	local stopBtn = mkBtn("■ Stop", Color3.fromRGB(155, 45, 45), 115, r2y, 65)

	playRangeBtn.MouseButton1Click:Connect(function()
		local rs, re = tonumber(tlStartInp.Text) or 0, tonumber(tlEndInp.Text)
		cfg.playRange(rs, re, cfg.getSpd())
	end)
	stopBtn.MouseButton1Click:Connect(function()
		local tr = cfg.getTrack()
		if tr then
			tr:Stop()
		end
	end)

	local curX = 188
	local btnCols = { Color3.fromRGB(35, 135, 70), Color3.fromRGB(45, 85, 180), Color3.fromRGB(140, 45, 140) }

	for i, v in ipairs(variants) do
		local c = btnCols[((i - 1) % #btnCols) + 1]
		local vBtn = mkBtn("V" .. i, c, curX, r2y, 40)
		vBtn.MouseButton1Click:Connect(function()
			cfg.playRange(v.s, v.e, cfg.getSpd())
		end)
		curX = curX + 48
	end

	for i, v in ipairs(variants) do
		local c = btnCols[((i - 1) % #btnCols) + 1]
		local fillBtn = mkBtn("Fill V" .. i .. " Range", c, curX, r2y, 90)
		fillBtn.MouseButton1Click:Connect(function()
			tlStartInp.Text = string.format("%.5f", v.s)
			tlEndInp.Text = string.format("%.5f", v.e)
		end)
		curX = curX + 98
	end

	local legLbl = Instance.new("TextLabel", tf)
	legLbl.Size = UDim2.new(1, -24, 0, 20)
	legLbl.Position = UDim2.new(0, 12, 0, 256)
	legLbl.BackgroundTransparency = 1
	legLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
	legLbl.Font = Enum.Font.Gotham
	legLbl.TextSize = 11
	legLbl.TextXAlignment = Enum.TextXAlignment.Left
	legLbl.Text = "Legend:   🟩 Variants (V1, V2...)    🟨 Pause Gaps    (Click scrubber to jump, drag to scrub)"

	local dragging = false
	handle.MouseButton1Down:Connect(function()
		dragging = true
	end)
	uis.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	tlHb = run.Heartbeat:Connect(function()
		if not tlGui or not tlGui.Parent then
			return
		end
		local track = cfg.getTrack()
		if track then
			local tLen = cfg.getLastLen()
			local len = (tLen > 0 and tLen) or (track.Length > 0 and track.Length) or 1
			local pos = track.IsPlaying and track.TimePosition or track.TimePosition
			local pct = math.clamp(pos / len, 0, 1)
			scrubFill.Size = UDim2.new(pct, 0, 1, 0)
			handle.Position = UDim2.new(pct, 0, 0.5, 0)
			playhead.Position = UDim2.new(pct, 0, 0, 0)
			timeLbl.Text = string.format("Position: %.6f s  |  Total: %.6f s", pos, len)
			if dragging then
				local mouse = plr:GetMouse()
				local saPos = scrub.AbsolutePosition
				local saSize = scrub.AbsoluteSize
				local p = math.clamp((mouse.X - saPos.X) / saSize.X, 0, 1)
				track.TimePosition = p * len
				-- Update preview position when scrubbing
				pcall(function()
					if previewActive and previewTrack then
						previewTrack.TimePosition = p * len
					end
				end)
			end
		end
	end)
end

function TimelineViewer.isOpen()
	return tlGui ~= nil and tlGui.Parent ~= nil
end

function TimelineViewer.toggle(cfg)
	if TimelineViewer.isOpen() then
		TimelineViewer.destroy()
	else
		TimelineViewer.build(cfg)
	end
end

return TimelineViewer
