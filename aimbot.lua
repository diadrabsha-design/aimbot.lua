local G = (getgenv and getgenv()) or _G
local K = "_aim"
if G[K] then pcall(G[K]) end

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local LP = Players.LocalPlayer

-- ═══ قدرات البيئة ═══
local CAP = {
    HasHttp = (typeof and typeof(game.HttpGet) == "function"),
    CamScriptable = false,
    StreamingOn = false,
}

pcall(function() CAP.StreamingOn = workspace.StreamingEnabled end)

local C = {
    Body = 56.79,
    MaxD = 5000,
    NPCr = 5000,
    Team = true,
    TP = true,
    TN = true,
    Tool = false,
    BS = 0.020,
    BoostAng = 0.20,
    BoostMul = 0.30,
    BehindAng = 1.00,
    BehindMul = 0.20,
    FarDist = 1500,
    FarMul = 0.70,
    SnapAng = 1.20,
    Relock = 7,
    JA = 0.002,
    JF = 3.7,
    NPCScan = 0.6,
    Prio = 2000,
}

local S = {
    T = nil, At = 0,
    Bind = (function()
        local s = ""
        for _ = 1, 20 do
            s = s .. string.format("%x", math.random(0, 15))
        end
        return s
    end)(),
    NPCs = {}, NAt = 0,
    Seed = math.random() * 1000,
    React = 0, LastChar = nil,
    MicroX = 0, MicroY = 0, LastMicro = 0,
    Started = false,
    CharConn = nil,
    SplashGui = nil,
}

local RP = RaycastParams.new()
RP.FilterType = Enum.RaycastFilterType.Exclude
RP.IgnoreWater = true

-- ═══ قوائم Hitbox موسّعة لكل الألعاب ═══
local HP = {
    "head", "hitbox_head", "headhitbox", "skull",
    "head_hitbox", "headshot", "hs", "hitboxhead"
}
local BP = {
    "uppertorso", "torso", "lowertorso", "chest",
    "hitbox_body", "hitbox_torso", "bodyhitbox",
    "humanoidrootpart", "root", "spine", "pelvis",
    "hitbox", "body", "upperchest", "waist",
    "hip", "abdomen", "trunk", "hitboxbody"
}

local DEAD_NAMES = {
    "corpse", "dead", "ragdoll", "death",
    "fallen", "dropped", "defeated", "downed"
}

local function getCam()
    local ok, c = pcall(function() return workspace.CurrentCamera end)
    if ok and c and c.Parent then return c end
end

local function getHRP(char)
    if not char then return nil end
    local ok, hrp = pcall(function()
        return char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
    end)
    if ok then return hrp end
end

local function updRP()
    local f = {}
    local ch = LP.Character
    if ch then f[#f + 1] = ch end
    local c = getCam()
    if c then f[#f + 1] = c end
    pcall(function() RP.FilterDescendantsInstances = f end)
end

local function ffz(c, p)
    if not c then return nil end
    local ok, kids = pcall(function() return c:GetChildren() end)
    if ok and kids then
        for _, o in ipairs(kids) do
            if o:IsA("BasePart") then
                local n = o.Name:lower()
                for i = 1, #p do
                    if n:find(p[i], 1, true) then return o end
                end
            end
        end
    end
    local ok2, desc = pcall(function() return c:GetDescendants() end)
    if ok2 and desc then
        for _, o in ipairs(desc) do
            if o:IsA("BasePart") then
                local n = o.Name:lower()
                for i = 1, #p do
                    if n:find(p[i], 1, true) then return o end
                end
            end
        end
    end
end

local function hb(c)
    if not c then return nil, nil end
    local h, b
    pcall(function()
        h = c:FindFirstChild("Head") or c:FindFirstChild("head")
        b = c:FindFirstChild("UpperTorso")
            or c:FindFirstChild("Torso")
            or c:FindFirstChild("LowerTorso")
            or c:FindFirstChild("HumanoidRootPart")
    end)
    if h and h:IsA("BasePart") then return h, b end
    return ffz(c, HP), ffz(c, BP) or b
end

local function isAlive(char)
    if not char or not char.Parent then return false end
    local ok, isDesc = pcall(function() return char:IsDescendantOf(workspace) end)
    if not ok or not isDesc then return false end

    local nameLow = char.Name:lower()
    for i = 1, #DEAD_NAMES do
        if nameLow:find(DEAD_NAMES[i], 1, true) then
            local hasHum = false
            pcall(function() hasHum = char:FindFirstChildOfClass("Humanoid") ~= nil end)
            if not hasHum then return false end
        end
    end

    local hum
    pcall(function() hum = char:FindFirstChildOfClass("Humanoid") end)
    if hum then
        if hum.Health <= 0 then return false end
        local ok2, state = pcall(function() return hum:GetState() end)
        if ok2 and state == Enum.HumanoidStateType.Dead then return false end
        if hum.Parent ~= char then return false end
    end

    local attrs = {"Dead", "IsDead", "Alive", "Health", "IsAlive", "KO"}
    for i = 1, #attrs do
        local a = attrs[i]
        local v = char:GetAttribute(a)
        if a == "Dead" and v == true then return false end
        if a == "IsDead" and v == true then return false end
        if a == "Alive" and v == false then return false end
        if a == "IsAlive" and v == false then return false end
        if a == "Health" and v == 0 then return false end
        if a == "KO" and v == true then return false end
    end

    local hrp = getHRP(char)
    if hrp then
        if hrp:GetAttribute("Dead") == true then return false end
        if not hrp.CanCollide and hrp.Transparency > 0.9 then
            local h2
            pcall(function() h2 = char:FindFirstChild("Head") end)
            if h2 and h2.Transparency > 0.9 then return false end
        end
    end

    return true
end

local function getOrigin()
    local ch = LP.Character
    if ch then
        local hrp = getHRP(ch)
        if hrp then return hrp.Position end
    end
    local c = getCam()
    if c then return c.CFrame.Position end
end

local function vis(part)
    if not part or not part.Parent then return false end
    local o = getOrigin()
    if not o then return false end
    local d = part.Position - o
    local m = d.Magnitude
    if m < 1 then return true end

    local ok, hit = pcall(function() return workspace:Raycast(o, d, RP) end)
    if not ok then return true end
    if not hit then return true end
    if hit.Instance:IsDescendantOf(part.Parent) then return true end

    if m > 500 then
        local off = part.Size.Magnitude * 0.55
        for _ = 1, 4 do
            local j = Vector3.new(
                (math.random() - 0.5) * off,
                (math.random() - 0.5) * off,
                (math.random() - 0.5) * off
            )
            local ok2, h2 = pcall(function() return workspace:Raycast(o, d + j, RP) end)
            if ok2 and (not h2 or h2.Instance:IsDescendantOf(part.Parent)) then return true end
        end
    elseif m > 250 then
        local off = part.Size.Magnitude * 0.4
        for _ = 1, 2 do
            local j = Vector3.new(
                (math.random() - 0.5) * off,
                (math.random() - 0.5) * off,
                (math.random() - 0.5) * off
            )
            local ok2, h2 = pcall(function() return workspace:Raycast(o, d + j, RP) end)
            if ok2 and (not h2 or h2.Instance:IsDescendantOf(part.Parent)) then return true end
        end
    end
    return false
end

local function roll(h, b)
    if not h then return b end
    if not b then return h end
    return (math.random() * 100 < C.Body) and b or h
end

local function isPC(m)
    local ok, list = pcall(function() return Players:GetPlayers() end)
    if not ok then return false end
    for i = 1, #list do
        if list[i].Character == m then return true end
    end
    return false
end

local function scanNPC()
    local out = {}
    local c = getCam()
    if not c then return out end
    local eye = c.CFrame.Position
    local ok, kids = pcall(function() return workspace:GetChildren() end)
    if not ok then return out end
    for i = 1, #kids do
        local o = kids[i]
        if o:IsA("Model") and not isPC(o) and isAlive(o) then
            local r = o.PrimaryPart
                or o:FindFirstChild("HumanoidRootPart")
                or o:FindFirstChild("Head")
            if r then
                local d = (r.Position - eye).Magnitude
                if d <= C.NPCr then
                    out[#out + 1] = o
                end
            end
        end
    end
    return out
end

local function hasTool()
    local c = LP.Character
    if not c then return false end
    local ok, t = pcall(function() return c:FindFirstChildOfClass("Tool") end)
    return ok and t ~= nil
end

local function nearest()
    local c = getCam()
    if not c then return nil end
    local eye = c.CFrame.Position
    local best, bd = nil, math.huge
    local now = os.clock()

    if C.TP then
        local ok, list = pcall(function() return Players:GetPlayers() end)
        if ok then
            for i = 1, #list do
                local plr = list[i]
                if plr ~= LP then
                    local skip = false
                    if C.Team and plr.Team and LP.Team and plr.Team == LP.Team then skip = true end
                    if not skip then
                        local ch = plr.Character
                        if isAlive(ch) then
                            local h, b = hb(ch)
                            local hd, bdd = math.huge, math.huge
                            if h then hd = (h.Position - eye).Magnitude end
                            if b then bdd = (b.Position - eye).Magnitude end
                            local d = hd < bdd and hd or bdd
                            if d < bd and d <= C.MaxD then
                                if (h and hd < math.huge and vis(h)) or (b and bdd < math.huge and vis(b)) then
                                    bd = d
                                    best = {k = "p", p = plr, c = ch, n = plr.Name, d = d}
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if C.TN then
        if now - S.NAt > C.NPCScan then
            S.NPCs = scanNPC()
            S.NAt = now
        end
        local list = S.NPCs
        for i = 1, #list do
            local m = list[i]
            if m.Parent and isAlive(m) then
                local h, b = hb(m)
                local hd, bdd = math.huge, math.huge
                if h then hd = (h.Position - eye).Magnitude end
                if b then bdd = (b.Position - eye).Magnitude end
                local d = hd < bdd and hd or bdd
                if d < bd and d <= C.MaxD then
                    if (h and hd < math.huge and vis(h)) or (b and bdd < math.huge and vis(b)) then
                        bd = d
                        best = {k = "n", c = m, n = m.Name, d = d}
                    end
                end
            end
        end
    end

    return best
end

local function lock(c)
    if not c or not c.c then return nil end
    if not isAlive(c.c) then return nil end
    local h, b = hb(c.c)
    if not h and not b then return nil end
    local v = nil
    if h and vis(h) then v = h end
    if not v and b and vis(b) then v = b end
    if not v then return nil end
    local ch = roll(h, b)
    if not ch or not vis(ch) then ch = v end
    return {k = c.k, p = c.p, n = c.n, c = c.c, part = ch, d = c.d, at = os.clock()}
end

local function valid(t)
    if not t or not t.part or not t.part.Parent then return false end
    if not t.c or not t.c.Parent then return false end
    if not isAlive(t.c) then return false end
    if os.clock() - t.at > C.Relock then return false end
    if not vis(t.part) then
        local h, b = hb(t.c)
        if h and vis(h) then t.part = h; t.at = os.clock(); return true end
        if b and vis(b) then t.part = b; t.at = os.clock(); return true end
        return false
    end
    local c = getCam()
    if not c then return false end
    if (t.part.Position - c.CFrame.Position).Magnitude > C.MaxD then return false end
    return true
end

local function humanize()
    local now = os.clock()
    if now - S.LastMicro > 0.15 then
        S.LastMicro = now
        S.MicroX = (math.random() - 0.5) * 0.0008
        S.MicroY = (math.random() - 0.5) * 0.0006
    end
    local jt = now * C.JF + S.Seed
    local jx = math.sin(jt) * C.JA * (1 + math.sin(jt * 0.23) * 0.4) + S.MicroX
    local jy = math.cos(jt * 1.31) * C.JA * 0.65 + S.MicroY
    return jx, jy
end

local function safeLookAt(pos, target, up)
    local ok, cf = pcall(CFrame.lookAt, pos, target, up)
    if ok and cf then return cf end
    ok, cf = pcall(CFrame.lookAt, pos, target)
    if ok and cf then return cf end
    local dir = (target - pos)
    if dir.Magnitude < 0.001 then return nil end
    dir = dir.Unit
    local right = dir:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude < 0.001 then
        right = Vector3.new(1, 0, 0)
    else
        right = right.Unit
    end
    local upV = right:Cross(dir).Unit
    return CFrame.fromMatrix(pos, right, upV, -dir)
end

local function aim(part, dt, el)
    if el < S.React then return end
    local c = getCam()
    if not c then return end
    local cur = c.CFrame
    local pos = cur.Position
    local dir = part.Position - pos
    local m = dir.Magnitude
    if m < 0.01 then return end

    local jx, jy = humanize()
    local want = (dir.Unit + Vector3.new(jx, jy, 0)).Unit

    local look = cur.LookVector
    local dot = math.clamp(look:Dot(want), -1, 1)
    local ang = math.acos(dot)

    if ang > C.SnapAng or ang > 1.57 then
        local up = cur.UpVector
        if math.abs(up:Dot(want)) > 0.99 then
            up = Vector3.new(0, 1, 0)
        end
        local cf = safeLookAt(pos, pos + want, up)
        if cf then
            pcall(function() c.CFrame = cf end)
        end
        return
    end

    local smooth = C.BS
    if ang > C.BoostAng then
        smooth = smooth * C.BoostMul
    end
    if ang > C.BehindAng then
        smooth = smooth * C.BehindMul
    end
    if m > C.FarDist then
        smooth = smooth * C.FarMul
    end

    local a = math.clamp(dt / math.max(smooth, 0.001), 0, 1)

    local up = cur.UpVector
    if math.abs(up:Dot(want)) > 0.99 then
        up = Vector3.new(0, 1, 0)
    end

    local wantCF = safeLookAt(pos, pos + want, up)
    if not wantCF then return end

    pcall(function() c.CFrame = cur:Lerp(wantCF, a) end)
end

local function onRender(dt)
    if C.Tool and not hasTool() then return end

    local ch = LP.Character
    if ch ~= S.LastChar then
        S.LastChar = ch
        updRP()
    end

    if not valid(S.T) then S.T = nil end

    if not S.T then
        local c = nearest()
        if c then
            S.T = lock(c)
            if S.T then
                S.At = os.clock()
                S.React = 0.04 + math.random() * 0.08
            end
        end
    end

    local t = S.T
    if not t or not t.part then return end
    if not isAlive(t.c) then S.T = nil; return end
    aim(t.part, dt, os.clock() - S.At)
end

local function tryBind()
    local priorities = {
        C.Prio,
        C.Prio + 500,
        Enum.RenderPriority.Camera.Value + 500,
        Enum.RenderPriority.Camera.Value + 100,
        Enum.RenderPriority.Character.Value + 100,
        Enum.RenderPriority.Character.Value + 1,
    }
    for i = 1, #priorities do
        pcall(function() RS:UnbindFromRenderStep(S.Bind) end)
        local ok2 = pcall(function()
            RS:BindToRenderStep(S.Bind, priorities[i], onRender)
        end)
        if ok2 then return true end
    end
    return false
end

-- ═══════════════════════════════════════════
-- 🎬 شاشة ZEMPAROE
-- ═══════════════════════════════════════════
local function showSplash(callback)
    local parent = LP:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "Boot"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent
    S.SplashGui = gui

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 1, 0)
    holder.BackgroundTransparency = 1
    holder.Parent = gui

    -- الخلفية السوداء (تختفي في النهاية)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel = 0
    bg.ZIndex = 1
    bg.Parent = holder

    -- نص الشعار
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 90)
    label.Position = UDim2.new(0, 0, 0.5, -45)
    label.BackgroundTransparency = 1
    label.Text = "BY ZEMPAROE"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeColor3 = Color3.fromRGB(120, 60, 255)
    label.TextStrokeTransparency = 0
    label.TextTransparency = 1
    label.TextSize = 54
    label.Font = Enum.Font.GothamBlack
    label.ZIndex = 3
    label.Parent = holder

    -- ظل خلف النص
    local shadow = Instance.new("TextLabel")
    shadow.Size = UDim2.new(1, 0, 0, 90)
    shadow.Position = UDim2.new(0, 3, 0.5, -45)
    shadow.BackgroundTransparency = 1
    shadow.Text = "BY ZEMPAROE"
    shadow.TextColor3 = Color3.fromRGB(120, 60, 255)
    shadow.TextStrokeTransparency = 1
    shadow.TextTransparency = 1
    shadow.TextSize = 54
    shadow.Font = Enum.Font.GothamBlack
    shadow.ZIndex = 2
    shadow.Parent = holder

    -- خط فاصل أسفل النص
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 0, 0, 2)
    line.Position = UDim2.new(0.5, 0, 0.5, 50)
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BackgroundColor3 = Color3.fromRGB(120, 60, 255)
    line.BorderSizePixel = 0
    line.ZIndex = 3
    line.Parent = holder

    local lineGlow = Instance.new("UIStroke")
    lineGlow.Color = Color3.fromRGB(255, 255, 255)
    lineGlow.Thickness = 1
    lineGlow.Transparency = 0.5
    lineGlow.Parent = line

    -- تدرج جانبي على النص
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(200, 180, 255)),
        ColorSequenceKeypoint.new(0.65, Color3.fromRGB(140, 100, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(90, 50, 220)),
    })
    grad.Rotation = 90
    grad.Parent = label

    local shadowGrad = Instance.new("UIGradient")
    shadowGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(120, 60, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(40, 20, 100)),
    })
    shadowGrad.Rotation = 90
    shadowGrad.Parent = shadow

    -- ═══ Timeline ═══
    -- 0.00 → 0.75s : Fade In + Slide
    -- 0.75 → 1.15s : Hold
    -- 1.15 → 1.90s : Fade Out + Slide
    -- المجموع: 1.9s

    local tweenInfoIn = TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local tweenInfoHold = TweenInfo.new(0.40, Enum.EasingStyle.Linear)
    local tweenInfoOut = TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

    -- Fade In
    local labelStartPos = UDim2.new(0, 0, 0.5, -45)
    local labelFinalPos = UDim2.new(0, 0, 0.5, -45)
    local shadowStartPos = UDim2.new(0, 3, 0.5, -45)
    local shadowFinalPos = UDim2.new(0, 3, 0.5, -45)

    label.Position = UDim2.new(0, 0, 0.5, -30)
    shadow.Position = UDim2.new(0, 3, 0.5, -30)

    Tween:Create(label, tweenInfoIn, {
        TextTransparency = 0,
        Position = labelFinalPos,
    }):Play()

    Tween:Create(shadow, tweenInfoIn, {
        TextTransparency = 0.55,
        Position = shadowFinalPos,
    }):Play()

    Tween:Create(line, tweenInfoIn, {
        Size = UDim2.new(0.32, 0, 0, 2),
    }):Play()

    task.wait(0.75)

    -- Hold
    task.wait(0.40)

    -- Fade Out
    Tween:Create(label, tweenInfoOut, {
        TextTransparency = 1,
        Position = UDim2.new(0, 0, 0.5, -60),
    }):Play()

    Tween:Create(shadow, tweenInfoOut, {
        TextTransparency = 1,
        Position = UDim2.new(0, 3, 0.5, -60),
    }):Play()

    Tween:Create(line, tweenInfoOut, {
        Size = UDim2.new(0, 0, 0, 2),
    }):Play()

    Tween:Create(bg, tweenInfoOut, {
        BackgroundTransparency = 1,
    }):Play()

    task.wait(0.75)

    gui:Destroy()
    S.SplashGui = nil

    if callback then callback() end
end

-- ═══════════════════════════════════════════
-- ▶️ التشغيل
-- ═══════════════════════════════════════════
local function start()
    if S.Started then return end
    S.Started = true
    updRP()

    local function onChar()
        task.wait(0.1)
        updRP()
        S.LastChar = nil
    end
    pcall(function()
        if S.CharConn then S.CharConn:Disconnect() end
        S.CharConn = LP.CharacterAdded:Connect(onChar)
    end)

    if not tryBind() then
        pcall(function()
            RS.Heartbeat:Connect(onRender)
        end)
    end

    pcall(function()
        workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            task.wait(0.1)
            updRP()
            if S.Started then tryBind() end
        end)
    end)
end

local function cleanup()
    pcall(function() RS:UnbindFromRenderStep(S.Bind) end)
    pcall(function() if S.CharConn then S.CharConn:Disconnect() end end)
    pcall(function() if S.SplashGui then S.SplashGui:Destroy() end end)
    S.Started = false
    G[K] = nil
end
G[K] = cleanup

-- شغّل شاشة الشعار أولاً → ثم ابدأ الأيمبوت
task.delay(0.05, function()
    pcall(function()
        showSplash(function()
            task.delay(0.03 + math.random() * 0.10, function()
                pcall(start)
            end)
        end)
    end)
end)
