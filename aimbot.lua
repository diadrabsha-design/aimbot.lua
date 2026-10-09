local G = (getgenv and getgenv()) or _G
local K = "_q"
if G[K] then pcall(G[K]) end

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local C = {
    On = false, Body = 56.79, MaxD = 1200,
    Team = true, TP = true, TN = true, Tool = false,
    BS = 0.08, Prio = 0, Relock = 4.5,
    JA = 0.004, JF = 3.7,
    HasMM = (typeof and typeof(mousemoverel) == "function"),
    Mobile = UIS.TouchEnabled and not UIS.KeyboardEnabled,
    PredV = 0.135,
    LatComp = 0,
    LatAlpha = 0.15,
    LastPing = 0,
    SilOcclusion = true,
    MaxHitChance = 92,
    MinHitChance = 78,
}

local S = {
    T = nil, At = 0, Gui = nil, Panel = nil, PO = false,
    Bind = "q_" .. tostring(math.random(100000, 999999)),
    NPCs = {}, NAt = 0, Seed = math.random() * 1000,
    React = 0, LastChar = nil, IdleAt = 0,
    MicroX = 0, MicroY = 0, LastMicro = 0,
    LastPingSample = 0,
    Stats = {hits = 0, total = 0, window = {}},
    LockTarget = nil,
    LastTargetSwitch = 0,
    SwitchInterval = 0,
}

local RP = RaycastParams.new()
RP.FilterType = Enum.RaycastFilterType.Exclude
RP.IgnoreWater = true

local HP = {"head","hitbox_head","skull"}
local BP = {"uppertorso","torso","lowertorso","chest","hitbox_body","hitbox_torso","bodyhitbox","humanoidrootpart","spine","hitbox"}

local function getCam()
    local c = workspace.CurrentCamera
    if c and c.Parent then return c end
end

local function updRP()
    local f = {}
    if LP.Character then table.insert(f, LP.Character) end
    local c = getCam()
    if c then table.insert(f, c) end
    RP.FilterDescendantsInstances = f
end

local function ffz(c, p)
    if not c then return nil end
    for _, o in ipairs(c:GetChildren()) do
        if o:IsA("BasePart") then
            local n = o.Name:lower()
            for i = 1, #p do
                if n:find(p[i], 1, true) then return o end
            end
        end
    end
    for _, o in ipairs(c:GetDescendants()) do
        if o:IsA("BasePart") then
            local n = o.Name:lower()
            for i = 1, #p do
                if n:find(p[i], 1, true) then return o end
            end
        end
    end
end

local function hb(c)
    if not c then return nil, nil end
    local h = c:FindFirstChild("Head")
    local b = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("LowerTorso") or c:FindFirstChild("HumanoidRootPart")
    if h and h:IsA("BasePart") then return h, b end
    return ffz(c, HP), ffz(c, BP) or b
end

local function getPing()
    local now = os.clock()
    if now - S.LastPingSample > 1.5 then
        S.LastPingSample = now
        local ok, ping = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and ping then
            S.LastPing = ping / 1000
        end
    end
    return S.LastPing
end

local function vis(part)
    if not part or not part.Parent then return false end
    local c = getCam()
    if not c then return false end
    local o = c.CFrame.Position
    local d = part.Position - o
    if d.Magnitude < 1 then return true end
    local hit = workspace:Raycast(o, d, RP)
    if not hit then return true end
    if hit.Instance:IsDescendantOf(part.Parent) then return true end
    if d.Magnitude > 180 then
        local off = part.Size.Magnitude * 0.35
        for _ = 1, 2 do
            local j = Vector3.new((math.random()-0.5)*off, (math.random()-0.5)*off, (math.random()-0.5)*off)
            local h2 = workspace:Raycast(o, d + j, RP)
            if not h2 or h2.Instance:IsDescendantOf(part.Parent) then return true end
        end
    end
    return false
end

local function onScr(part)
    if not part then return false end
    local c = getCam()
    if not c then return false end
    local sp, ok = c:WorldToViewportPoint(part.Position)
    return ok and sp.Z > 0
end

local function roll(h, b)
    if not h then return b end
    if not b then return h end
    return (math.random() * 100 < C.Body) and b or h
end

local function isPC(m)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == m then return true end
    end
    return false
end

local function scanNPC()
    local out = {}
    local c = getCam()
    if not c then return out end
    local eye = c.CFrame.Position
    for _, o in ipairs(workspace:GetChildren()) do
        if o:IsA("Model") and not isPC(o) then
            local hum = o:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local r = o.PrimaryPart or o:FindFirstChild("HumanoidRootPart") or o:FindFirstChild("Head")
                if r and (r.Position - eye).Magnitude <= 700 then
                    table.insert(out, o)
                end
            end
        end
    end
    return out
end

local function hasTool()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Tool") ~= nil
end

local function predictPos(part, vel)
    local ping = getPing()
    local comp = C.PredV + ping * 0.5 + C.LatComp
    return part.Position + vel * comp
end

local function nearest()
    local c = getCam()
    if not c then return nil end
    local eye = c.CFrame.Position
    local best, bd = nil, math.huge
    local now = os.clock()

    if C.TP then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local skip = false
                if C.Team and plr.Team and LP.Team and plr.Team == LP.Team then skip = true end
                if not skip then
                    local ch = plr.Character
                    if ch then
                        local hum = ch:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            local h, b = hb(ch)
                            local hd, bdd = math.huge, math.huge
                            if h and onScr(h) then hd = (h.Position - eye).Magnitude end
                            if b and onScr(b) then bdd = (b.Position - eye).Magnitude end
                            local d = hd < bdd and hd or bdd
                            if d < bd and d <= C.MaxD then
                                if (h and hd < math.huge and vis(h)) or (b and bdd < math.huge and vis(b)) then
                                    bd = d
                                    best = {k="p", p=plr, c=ch, n=plr.Name, d=d}
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if C.TN then
        if now - S.NAt > 0.4 then
            S.NPCs = scanNPC()
            S.NAt = now
        end
        for _, m in ipairs(S.NPCs) do
            if m.Parent and m:IsDescendantOf(workspace) then
                local hum = m:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local h, b = hb(m)
                    local hd, bdd = math.huge, math.huge
                    if h and onScr(h) then hd = (h.Position - eye).Magnitude end
                    if b and onScr(b) then bdd = (b.Position - eye).Magnitude end
                    local d = hd < bdd and hd or bdd
                    if d < bd and d <= C.MaxD then
                        if (h and hd < math.huge and vis(h)) or (b and bdd < math.huge and vis(b)) then
                            bd = d
                            best = {k="n", c=m, n=m.Name, d=d}
                        end
                    end
                end
            end
        end
    end

    return best
end

local function lock(c)
    if not c or not c.c then return nil end
    local h, b = hb(c.c)
    if not h and not b then return nil end
    local v = nil
    if h and vis(h) then v = h end
    if not v and b and vis(b) then v = b end
    if not v then return nil end
    local ch = roll(h, b)
    if not ch or not vis(ch) then ch = v end
    local hitTarget = math.random(C.MinHitChance, C.MaxHitChance) / 100
    S.Stats.total = S.Stats.total + 1
    if math.random() < hitTarget then
        S.Stats.hits = S.Stats.hits + 1
    end
    return {k=c.k, p=c.p, n=c.n, c=c.c, part=ch, d=c.d, at=os.clock(), hit = math.random() < hitTarget}
end

local function valid(t)
    if not t or not t.part or not t.part.Parent then return false end
    if not t.c or not t.c.Parent then return false end
    local hum = t.c:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end
    if os.clock() - t.at > C.Relock then return false end
    if os.clock() - S.LastTargetSwitch > S.SwitchInterval then
        S.LastTargetSwitch = os.clock()
        S.SwitchInterval = 2 + math.random() * 4
        return false
    end
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
    if now - S.LastMicro > 0.12 then
        S.LastMicro = now
        S.MicroX = (math.random() - 0.5) * 0.0018
        S.MicroY = (math.random() - 0.5) * 0.0012
    end
    local jt = now * C.JF + S.Seed
    local jx = math.sin(jt) * C.JA * (1 + math.sin(jt * 0.23) * 0.4) + S.MicroX
    local jy = math.cos(jt * 1.31) * C.JA * 0.65 + S.MicroY
    return jx, jy
end

local function aimCam(part, dt, el)
    if el < S.React then return end
    local c = getCam()
    if not c then return end
    local cur = c.CFrame
    local pos = cur.Position
    local vel = part.AssemblyLinearVelocity or Vector3.zero
    local aimPos = predictPos(part, vel)
    local dir = aimPos - pos
    if dir.Magnitude < 0.01 then return end
    local jx, jy = humanize()
    local want = (dir.Unit + Vector3.new(jx, jy, 0)).Unit
    local dot = math.clamp(cur.LookVector:Dot(dir.Unit), -1, 1)
    local ang = math.acos(dot)
    local smooth = C.BS * (1 + ang * 0.5)
    local a = math.clamp(dt / math.max(smooth, 0.001), 0, 1)
    local nl = cur.LookVector:Lerp(want, a)
    if nl.Magnitude < 0.01 then return end
    c.CFrame = CFrame.lookAt(pos, pos + nl.Unit, cur.UpVector)
end

local function aimMouse(part, dt, el)
    if not C.HasMM or C.Mobile or el < S.React then return end
    local c = getCam()
    if not c then return end
    local vp = c.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local vel = part.AssemblyLinearVelocity or Vector3.zero
    local aimPos = predictPos(part, vel)
    local sp = c:WorldToViewportPoint(aimPos)
    if not sp or sp.Z < 0 then return end
    local jx, jy = humanize()
    local a = math.clamp(dt / C.BS, 0, 1)
    pcall(mousemoverel, (sp.X - cx) * a + jx * 35, (sp.Y - cy) * a + jy * 25)
end

local function onRender(dt)
    if not C.On then return end
    if C.Tool and not hasTool() then return end
    local ch = LP.Character
    if ch ~= S.LastChar then S.LastChar = ch; updRP() end
    if not valid(S.T) then S.T = nil end
    if not S.T then
        local c = nearest()
        if c then
            S.T = lock(c)
            if S.T then
                S.At = os.clock()
                S.React = 0.05 + math.random() * 0.11
            end
        end
    end
    local t = S.T
    if not t or not t.part then return end
    local el = os.clock() - S.At
    if C.Mobile then
        aimCam(t.part, dt, el)
    elseif C.HasMM then
        aimMouse(t.part, dt, el)
    else
        aimCam(t.part, dt, el)
    end
end

local function bind()
    updRP()
    pcall(function() RS:UnbindFromRenderStep(S.Bind) end)
    RS:BindToRenderStep(S.Bind, Enum.RenderPriority.Camera.Value + 5 + C.Prio, onRender)
    S.T = nil
end

local function mkbtn(parent, txt, sz, pos)
    local b = Instance.new("TextButton")
    b.Size = sz; b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    b.BackgroundTransparency = 0.1
    b.Text = txt; b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.TextSize = 15; b.Font = Enum.Font.GothamBold; b.AutoButtonColor = false
    b.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 9); c.Parent = b
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(85, 85, 105); s.Thickness = 1; s.Transparency = 0.5; s.Parent = b
    return b
end

local function refresh()
    if not S.Panel then return end
    for _, ch in ipairs(S.Panel:GetChildren()) do
        local r = ch:GetAttribute("role")
        if r == "toggle" then
            ch.Text = C.On and "●" or "◉"
            ch.TextColor3 = C.On and Color3.fromRGB(255, 85, 85) or Color3.fromRGB(200, 200, 210)
        elseif r == "targets" then
            ch.Text = C.TN and C.TP and "🤖👤" or (C.TN and "🤖" or "👤")
        elseif r == "tool" then
            ch.Text = C.Tool and "🔒" or "🔓"
        end
    end
end

local function build()
    local parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "Hud"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.Parent = parent
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    S.Gui = gui

    local cont = Instance.new("Frame")
    cont.Size = UDim2.new(0, 44, 0, 44)
    cont.Position = UDim2.new(0, 18, 0.5, -22)
    cont.BackgroundTransparency = 1
    cont.Parent = gui

    local main = mkbtn(cont, "◉", UDim2.new(0, 44, 0, 44), UDim2.new(0, 0, 0, 0))
    main:SetAttribute("role", "toggle")
    main.TextSize = 20

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 50, 0, 150)
    panel.Position = UDim2.new(0, 52, 0.5, -75)
    panel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    panel.BackgroundTransparency = 0.05
    panel.Visible = false
    panel.Parent = cont
    S.Panel = panel

    local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 11); pc.Parent = panel
    local ps = Instance.new("UIStroke")
    ps.Color = Color3.fromRGB(75, 75, 95); ps.Thickness = 1; ps.Transparency = 0.4; ps.Parent = panel

    local tg = mkbtn(panel, "🤖👤", UDim2.new(0, 42, 0, 42), UDim2.new(0, 4, 0, 5))
    tg:SetAttribute("role", "targets")

    local tl = mkbtn(panel, "🔓", UDim2.new(0, 42, 0, 42), UDim2.new(0, 4, 0, 52))
    tl:SetAttribute("role", "tool")

    local fa = mkbtn(panel, "＋", UDim2.new(0, 42, 0, 42), UDim2.new(0, 4, 0, 99))
    local sl = mkbtn(panel, "－", UDim2.new(0, 42, 0, 42), UDim2.new(0, 4, 0, 146))
    panel.Size = UDim2.new(0, 50, 0, 194)

    local function tog()
        C.On = not C.On
        if C.On then bind() else
            pcall(function() RS:UnbindFromRenderStep(S.Bind) end)
            S.T = nil
        end
        refresh()
    end

    local drag, ds, sp, moved = false, nil, nil, false
    main.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag, moved = true, false
            ds, sp = i.Position, cont.Position
            local c
            c = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    drag = false
                    if c then c:Disconnect() end
                    if not moved then
                        S.PO = not S.PO
                        panel.Visible = S.PO
                    end
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = i.Position - ds
        if math.abs(d.X) > 6 or math.abs(d.Y) > 6 then moved = true end
        cont.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
    end)

    main.MouseButton2Click:Connect(tog)

    tg.MouseButton1Click:Connect(function()
        if C.TN and C.TP then C.TN, C.TP = true, false
        elseif C.TN then C.TN, C.TP = false, true
        else C.TN, C.TP = true, true end
        refresh()
    end)
    tg.TouchTap:Connect(function()
        if C.TN and C.TP then C.TN, C.TP = true, false
        elseif C.TN then C.TN, C.TP = false, true
        else C.TN, C.TP = true, true end
        refresh()
    end)

    tl.MouseButton1Click:Connect(function() C.Tool = not C.Tool; refresh() end)
    tl.TouchTap:Connect(function() C.Tool = not C.Tool; refresh() end)

    fa.MouseButton1Click:Connect(function() C.BS = math.max(0.01, C.BS - 0.015) end)
    fa.TouchTap:Connect(function() C.BS = math.max(0.01, C.BS - 0.015) end)

    sl.MouseButton1Click:Connect(function() C.BS = math.min(0.5, C.BS + 0.015) end)
    sl.TouchTap:Connect(function() C.BS = math.min(0.5, C.BS + 0.015) end)

    UIS.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        local k = i.KeyCode
        if k == Enum.KeyCode.RightShift then tog()
        elseif k == Enum.KeyCode.N then C.TN, C.TP = true, false; refresh()
        elseif k == Enum.KeyCode.B then C.TN, C.TP = true, true; refresh()
        elseif k == Enum.KeyCode.V then C.TN, C.TP = false, true; refresh()
        elseif k == Enum.KeyCode.T then C.Tool = not C.Tool; refresh()
        elseif k == Enum.KeyCode.LeftBracket then C.BS = math.max(0.01, C.BS - 0.015)
        elseif k == Enum.KeyCode.RightBracket then C.BS = math.min(0.5, C.BS + 0.015)
        end
    end)

    refresh()
end

local function cleanup()
    pcall(function() RS:UnbindFromRenderStep(S.Bind) end)
    if S.Gui then S.Gui:Destroy() end
    G[K] = nil
end
G[K] = cleanup

pcall(build)
