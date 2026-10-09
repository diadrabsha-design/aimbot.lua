local G = (getgenv and getgenv()) or _G
local K = "_aim"
if G[K] then pcall(G[K]) end

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local C = {
    Body = 56.79,
    MaxD = 5000,
    Team = true,
    TP = true,
    TN = true,
    Tool = false,
    BS = 0.030,
    BoostAng = 0.35,
    BoostMul = 0.40,
    Relock = 6,
    JA = 0.003,
    JF = 3.7,
    NPCScan = 0.7,
    NPCr = 5000,
    CamCheck = true,
}

local S = {
    T = nil,
    At = 0,
    Bind = (function()
        local s = ""
        for _ = 1, 16 do
            s = s .. string.format("%x", math.random(0, 15))
        end
        return s
    end)(),
    NPCs = {},
    NAt = 0,
    Seed = math.random() * 1000,
    React = 0,
    LastChar = nil,
    MicroX = 0,
    MicroY = 0,
    LastMicro = 0,
    CamType = nil,
    Started = false,
}

local RP = RaycastParams.new()
RP.FilterType = Enum.RaycastFilterType.Exclude
RP.IgnoreWater = true

local HP = {"head", "hitbox_head"}
local BP = {"uppertorso", "torso", "lowertorso", "chest", "hitbox_body", "hitbox_torso", "bodyhitbox", "humanoidrootpart", "spine", "hitbox"}

local DEAD_NAMES = {"corpse", "dead", "ragdoll", "death", "fallen"}

local function getCam()
    local c = workspace.CurrentCamera
    if c and c.Parent then return c end
end

local function updRP()
    local f = {}
    local ch = LP.Character
    if ch then f[#f + 1] = ch end
    local c = getCam()
    if c then f[#f + 1] = c end
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

local function isAlive(char)
    if not char or not char.Parent then return false end
    if not char:IsDescendantOf(workspace) then return false end

    local nameLow = char.Name:lower()
    for i = 1, #DEAD_NAMES do
        if nameLow:find(DEAD_NAMES[i], 1, true) then
            if not char:FindFirstChildOfClass("Humanoid") then
                return false
            end
        end
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.Health <= 0 then return false end
        local ok, state = pcall(function() return hum:GetState() end)
        if ok and state == Enum.HumanoidStateType.Dead then return false end
        if hum.Parent ~= char then return false end
    end

    if char:GetAttribute("Dead") == true then return false end
    if char:GetAttribute("IsDead") == true then return false end
    if char:GetAttribute("Health") == 0 then return false end
    if char:GetAttribute("Alive") == false then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        if hrp:GetAttribute("Dead") == true then return false end
        if not hrp.CanCollide and hrp.Transparency > 0.9 then
            local h2 = char:FindFirstChild("Head")
            if h2 and h2.Transparency > 0.9 then return false end
        end
    end

    return true
end

local function vis(part)
    if not part or not part.Parent then return false end
    local c = getCam()
    if not c then return false end
    local o = c.CFrame.Position
    local d = part.Position - o
    local m = d.Magnitude
    if m < 1 then return true end
    local hit = workspace:Raycast(o, d, RP)
    if not hit then return true end
    if hit.Instance:IsDescendantOf(part.Parent) then return true end
    if m > 250 then
        local off = part.Size.Magnitude * 0.4
        for _ = 1, 2 do
            local j = Vector3.new(
                (math.random() - 0.5) * off,
                (math.random() - 0.5) * off,
                (math.random() - 0.5) * off
            )
            local h2 = workspace:Raycast(o, d + j, RP)
            if not h2 or h2.Instance:IsDescendantOf(part.Parent) then return true end
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
    local kids = workspace:GetChildren()
    for i = 1, #kids do
        local o = kids[i]
        if o:IsA("Model") and not isPC(o) and isAlive(o) then
            local r = o.PrimaryPart or o:FindFirstChild("HumanoidRootPart")
            if r and (r.Position - eye).Magnitude <= C.NPCr then
                out[#out + 1] = o
            end
        end
    end
    return out
end

local function hasTool()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Tool") ~= nil
end

local function nearest()
    local c = getCam()
    if not c then return nil end
    local eye = c.CFrame.Position
    local best, bd = nil, math.huge
    local now = os.clock()

    if C.TP then
        local list = Players:GetPlayers()
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

    if C.TN then
        if now - S.NAt > C.NPCScan then
            S.NPCs = scanNPC()
            S.NAt = now
        end
        local list = S.NPCs
        for i = 1, #list do
            local m = list[i]
            if m.Parent and m:IsDescendantOf(workspace) and isAlive(m) then
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
        S.MicroX = (math.random() - 0.5) * 0.0012
        S.MicroY = (math.random() - 0.5) * 0.0008
    end
    local jt = now * C.JF + S.Seed
    local jx = math.sin(jt) * C.JA * (1 + math.sin(jt * 0.23) * 0.4) + S.MicroX
    local jy = math.cos(jt * 1.31) * C.JA * 0.65 + S.MicroY
    return jx, jy
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

    local smooth = C.BS
    if ang > C.BoostAng then
        smooth = smooth * C.BoostMul
    end
    if m > 500 then
        smooth = smooth * 0.85
    end

    local a = math.clamp(dt / math.max(smooth, 0.001), 0, 1)

    local up = cur.UpVector
    if math.abs(up:Dot(want)) > 0.99 then
        up = Vector3.new(0, 1, 0)
    end

    local ok, wantCF = pcall(CFrame.lookAt, pos, pos + want, up)
    if not ok then return end

    c.CFrame = cur:Lerp(wantCF, a)
end

local function onRender(dt)
    if C.Tool and not hasTool() then return end

    if C.CamCheck then
        local c = getCam()
        if c then
            local ct = c.CameraType
            if ct ~= S.CamType then
                S.CamType = ct
            end
        end
    end

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
                S.React = 0.05 + math.random() * 0.11
            end
        end
    end

    local t = S.T
    if not t or not t.part then return end
    if not isAlive(t.c) then S.T = nil; return end
    aim(t.part, dt, os.clock() - S.At)
end

local function start()
    if S.Started then return end
    S.Started = true
    updRP()
    pcall(function() RS:UnbindFromRenderStep(S.Bind) end)
    RS:BindToRenderStep(
        S.Bind,
        Enum.RenderPriority.Camera.Value + 1,
        onRender
    )
end

local function cleanup()
    pcall(function() RS:UnbindFromRenderStep(S.Bind) end)
    S.Started = false
    G[K] = nil
end
G[K] = cleanup

task.delay(0.03 + math.random() * 0.11, start)
