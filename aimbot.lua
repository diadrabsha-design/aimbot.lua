local ENV = (getgenv and getgenv()) or _G
if ENV.__aimv9_cleanup then pcall(ENV.__aimv9_cleanup) end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local LP         = Players.LocalPlayer

local CFG = {
    Active        = false,
    Smooth        = 0.04,        
    MaxDist       = 1500,        
    BodyChance    = 56.79,
    HardLock      = false,
    PrioOffset    = 0,

    TargetPlayers = true,
    TargetNPCs    = true,
    NPCScanRange  = 800,
    RequireTool   = false,
    IgnoreTeam    = true,
    Method        = "camera",    

    RescanDelay   = 0.05,        
    NPCScanDelay  = 0.3,
}

local S = {
    Target=nil, LastPick=0,
    Gui=nil, BindName="__aimv9_"..tostring(math.random(1e6)),
    Diag1=nil, Diag2=nil,
    Stat={wrote=0, stuck=0, reverted=0},
    LastWrittenCF=nil,
    NPCCache={}, LastNPCScan=0,
}

-- ═══════════════════════════════════════════
-- Fuzzy Hitbox Finder
-- ═══════════════════════════════════════════
local HEAD_PAT = {"head", "hitbox_head", "headhitbox", "skull"}
local BODY_PAT = {
    "uppertorso", "torso", "lowertorso", "chest",
    "hitbox_body", "hitbox_torso", "body", "bodyhitbox",
    "humanoidrootpart", "root", "spine", "pelvis", "hitbox"
}

local function findFuzzy(container, patterns, excludeRoot)
    if not container then return nil end
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if excludeRoot and name == "humanoidrootpart" then continue end
            for _, pat in ipairs(patterns) do
                if name:find(pat, 1, true) then return obj end
            end
        end
    end
    return nil
end

local function getHitboxes(char)
    if not char then return nil, nil end
    local directHead = char:FindFirstChild("Head") or char:FindFirstChild("head")
    local directBody = char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("LowerTorso")
        or char:FindFirstChild("HumanoidRootPart")

    if directHead and directHead:IsA("BasePart") then
        return directHead, directBody
    end
    return findFuzzy(char, HEAD_PAT), (findFuzzy(char, BODY_PAT) or directBody)
end

-- ═══════════════════════════════════════════
-- 👁️ LOS صارم
-- ═══════════════════════════════════════════
local function visible(part)
    if not part or not part.Parent then return false end
    local Cam = workspace.CurrentCamera
    if not Cam then return false end
    local o = Cam.CFrame.Position
    local d = part.Position - o
    if d.Magnitude < 1 then return true end
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = {LP.Character, Cam}
    p.IgnoreWater = true
    local h = workspace:Raycast(o, d, p)
    if not h then return true end
    -- ✅ لازم الجزء المرصود يكون نفس الهدف
    return h.Instance:IsDescendantOf(part.Parent)
end

-- ═══════════════════════════════════════════
-- 56.79%
-- ═══════════════════════════════════════════
local function roll(h, b)
    if not h then return b end
    if not b then return h end
    return (math.random() * 100 < CFG.BodyChance) and b or h
end

-- ═══════════════════════════════════════════
-- NPCs Scan
-- ═══════════════════════════════════════════
local function isPlayerCharacter(model)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == model then return true end
    end
    return false
end

local function scanNPCs()
    local list = {}
    local eye = workspace.CurrentCamera.CFrame.Position
    for _, obj in ipairs(workspace:GetChildren()) do
        if not obj:IsA("Model") then continue end
        if isPlayerCharacter(obj) then continue end
        local hum = obj:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local root = obj.PrimaryPart
            or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Head")
        if not root then continue end
        local dist = (root.Position - eye).Magnitude
        if dist > CFG.NPCScanRange then continue end
        list[#list+1] = obj
    end
    return list
end

local function hasTool()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Tool") ~= nil
end

-- ═══════════════════════════════════════════
-- 🎯 إيجاد الأقرب المرئي (بدون FOV، بدون عشوائي)
-- ═══════════════════════════════════════════
local function findNearest()
    local Cam = workspace.CurrentCamera
    if not Cam then return nil end
    local eye = Cam.CFrame.Position

    local best = nil       -- {dist, kind, name, char, part}
    local bestDist = math.huge

    -- ═══ 1) لاعبين ═══
    if CFG.TargetPlayers then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LP then continue end
            if CFG.IgnoreTeam and plr.Team and LP.Team and plr.Team == LP.Team then
                continue
            end
            local char = plr.Character
            if not char then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then continue end

            local h, b = getHitboxes(char)
            if not h and not b then continue end

            -- فحص أي جزء مرئي
            local chosen, chosenDist
            if h and visible(h) then
                local d = (h.Position - eye).Magnitude
                if d < bestDist and d <= CFG.MaxDist then
                    chosen, chosenDist = roll(h, b), d
                end
            end
            if not chosen and b and visible(b) then
                local d = (b.Position - eye).Magnitude
                if d < bestDist and d <= CFG.MaxDist then
                    chosen, chosenDist = roll(h, b), d
                end
            end

            if chosen and chosenDist < bestDist then
                -- تأكد الجزء المختار مرئي، وإلا خذ المرئي
                if not visible(chosen) then
                    chosen = (h and visible(h)) and h or b
                end
                bestDist = chosenDist
                best = {
                    kind = "player",
                    player = plr,
                    name = plr.Name,
                    part = chosen,
                }
            end
        end
    end

    -- ═══ 2) NPCs ═══
    if CFG.TargetNPCs then
        if tick() - S.LastNPCScan > CFG.NPCScanDelay then
            S.NPCCache = scanNPCs()
            S.LastNPCScan = tick()
        end
        for _, model in ipairs(S.NPCCache) do
            if not model.Parent then continue end
            local hum = model:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end

            local h, b = getHitboxes(model)
            if not h and not b then continue end

            local chosen, chosenDist
            if h and visible(h) then
                local d = (h.Position - eye).Magnitude
                if d < bestDist and d <= CFG.MaxDist then
                    chosen, chosenDist = roll(h, b), d
                end
            end
            if not chosen and b and visible(b) then
                local d = (b.Position - eye).Magnitude
                if d < bestDist and d <= CFG.MaxDist then
                    chosen, chosenDist = roll(h, b), d
                end
            end

            if chosen and chosenDist < bestDist then
                if not visible(chosen) then
                    chosen = (h and visible(h)) and h or b
                end
                bestDist = chosenDist
                best = {
                    kind = "npc",
                    name = model.Name,
                    part = chosen,
                }
            end
        end
    end

    return best, bestDist
end

-- ═══════════════════════════════════════════
-- 🎯 محرك الكاميرا — سريع
-- ═══════════════════════════════════════════
local function aimCamera(Cam, targetPart, dt)
    local cur = Cam.CFrame
    local pos = cur.Position
    local curLook = cur.LookVector

    local wantLook = targetPart.Position - pos
    if wantLook.Magnitude < 0.01 then return end
    wantLook = wantLook.Unit

    -- ⚡ 5x سرعة: alpha أكبر
    local alpha
    if CFG.HardLock then
        alpha = 1
    else
        alpha = math.clamp(dt / math.max(CFG.Smooth, 0.001), 0, 1)
    end

    local newLook = curLook:Lerp(wantLook, alpha)
    if newLook.Magnitude < 0.01 then return end
    newLook = newLook.Unit

    Cam.CFrame = CFrame.lookAt(pos, pos + newLook)
end

-- ═══════════════════════════════════════════
-- 🖱️ محرك الماوس
-- ═══════════════════════════════════════════
local hasMouseMove = (typeof and typeof(mousemoverel) == "function")
    or (typeof and typeof(MouseMoveRel) == "function")

local function aimMouse(Cam, targetPart, dt)
    if not hasMouseMove then return end
    local vp = Cam.ViewportSize
    local center = vp * 0.5
    local sp = Cam:WorldToViewportPoint(targetPart.Position)
    if not sp then return end
    local alpha = CFG.HardLock and 1 or math.clamp(dt / CFG.Smooth, 0, 1)
    local dx = (sp.X - center.X) * alpha
    local dy = (sp.Y - center.Y) * alpha
    pcall(function()
        if typeof(mousemoverel) == "function" then mousemoverel(dx, dy)
        elseif typeof(MouseMoveRel) == "function" then MouseMoveRel(dx, dy) end
    end)
end

-- ═══════════════════════════════════════════
-- 🔄 Render loop
-- ═══════════════════════════════════════════
local function onRender(dt)
    if not CFG.Active then return end

    if CFG.RequireTool and not hasTool() then
        if S.Diag1 then S.Diag1.Text = "🔫 لا تحمل سلاح" end
        return
    end

    local Cam = workspace.CurrentCamera
    if not Cam then return end

    -- قياس صدق الكتابة السابقة
    if S.LastWrittenCF then
        local posDiff = (Cam.CFrame.Position - S.LastWrittenCF.Position).Magnitude
        local dot = Cam.CFrame.LookVector:Dot(S.LastWrittenCF.LookVector)
        if posDiff < 0.01 and dot > 0.9999 then
            S.Stat.stuck += 1
        else
            S.Stat.reverted += 1
        end
    end

    -- إعادة اختيار كل 0.05s (أسرع بكثير)
    if not S.Target or tick() - S.LastPick > CFG.RescanDelay then
        local newT = findNearest()
        if newT then S.Target = newT end
        S.LastPick = tick()
    end

    local t = S.Target
    if not t or not t.part or not t.part.Parent then
        S.Target = nil
        if S.Diag1 then S.Diag1.Text = "🔴 لا هدف مرئي" end
        return
    end

    -- تأكد من الرؤية في كل إطار
    if not visible(t.part) then
        S.Target = nil
        if S.Diag1 then S.Diag1.Text = "🚫 الهدف اختفى (خلف جدار)" end
        return
    end

    -- التصويب
    if CFG.Method == "camera" then
        aimCamera(Cam, t.part, dt)
    else
        aimMouse(Cam, t.part, dt)
    end
    S.LastWrittenCF = Cam.CFrame
    S.Stat.wrote += 1

    -- تشخيص
    if S.Diag1 then
        local kind = t.kind == "npc" and "🤖" or "👤"
        S.Diag1.Text = string.format(
            "%s %s | W:%d S:%d R:%d | %s",
            kind, t.name or "?",
            S.Stat.wrote, S.Stat.stuck, S.Stat.reverted,
            CFG.Method:upper()
        )
    end
    if S.Diag2 then
        local modeStr = ""
        if CFG.TargetNPCs and CFG.TargetPlayers then modeStr = "🤖👤 الكل"
        elseif CFG.TargetNPCs then modeStr = "🤖 NPCs"
        else modeStr = "👤 Players" end

        local v = S.Stat.reverted > S.Stat.stuck and S.Stat.wrote > 10
            and "❌" or (S.Stat.stuck > 5 and "✅" or "⏳")
        S.Diag2.Text = modeStr .. " | Smooth:" .. CFG.Smooth .. " | " .. v
    end
end

-- ═══════════════════════════════════════════
-- UI (بدون دائرة FOV)
-- ═══════════════════════════════════════════
local function buildUI()
    local parent = (gethui and gethui()) or LP:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "\0"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.Parent = parent
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    S.Gui = gui

    -- ❌ لا دائرة FOV

    local d1 = Instance.new("TextLabel")
    d1.Size = UDim2.new(0, 700, 0, 22)
    d1.Position = UDim2.new(0.5, -350, 0, 25)
    d1.BackgroundTransparency = 1; d1.TextColor3 = Color3.fromRGB(0,255,120)
    d1.TextStrokeTransparency = 0.3; d1.Font = Enum.Font.Code; d1.TextSize = 14
    d1.Text = "⏸ غير مفعل"; d1.Parent = gui; S.Diag1 = d1

    local d2 = Instance.new("TextLabel")
    d2.Size = UDim2.new(0, 700, 0, 22)
    d2.Position = UDim2.new(0.5, -350, 0, 50)
    d2.BackgroundTransparency = 1; d2.TextColor3 = Color3.fromRGB(255,220,100)
    d2.TextStrokeTransparency = 0.3; d2.Font = Enum.Font.Code; d2.TextSize = 14
    d2.Text = "🤖👤 الكل | Smooth:0.04"; d2.Parent = gui; S.Diag2 = d2

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 38, 0, 38)
    btn.Position = UDim2.new(0, 20, 0.5, -19)
    btn.BackgroundColor3 = Color3.fromRGB(25,25,32); btn.BackgroundTransparency = 0.1
    btn.Text = "⌖"; btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 20; btn.Font = Enum.Font.GothamBold; btn.AutoButtonColor = false
    btn.Parent = gui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = btn
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(90,90,110); s.Thickness = 1.2; s.Transparency = 0.4
    s.Parent = btn

    local drag, ds, sp, moved = false, nil, nil, false
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag, moved = true, false; ds, sp = i.Position, btn.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    drag = false
                    if not moved then toggle() end
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement
        and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = i.Position - ds
        if math.abs(d.X) > 5 or math.abs(d.Y) > 5 then moved = true end
        btn.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
    end)

    local function bind()
        pcall(function() RunService:UnbindFromRenderStep(S.BindName) end)
        local prio = Enum.RenderPriority.Character.Value + CFG.PrioOffset
        RunService:BindToRenderStep(S.BindName, prio, onRender)
        S.Stat = {wrote=0, stuck=0, reverted=0}
        S.LastWrittenCF = nil
        S.Target = nil
    end

    function toggle()
        CFG.Active = not CFG.Active
        if CFG.Active then
            btn.Text = "✕"; btn.BackgroundColor3 = Color3.fromRGB(200,40,60)
            bind()
        else
            btn.Text = "⌖"; btn.BackgroundColor3 = Color3.fromRGB(25,25,32)
            pcall(function() RunService:UnbindFromRenderStep(S.BindName) end)
            S.Target = nil
        end
    end

    UIS.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == Enum.KeyCode.RightShift then
            toggle()
        elseif i.KeyCode == Enum.KeyCode.M then
            CFG.Method = (CFG.Method == "camera") and "mouse" or "camera"
            S.Diag2.Text = "🔧 " .. CFG.Method:upper()
        elseif i.KeyCode == Enum.KeyCode.L then
            CFG.HardLock = not CFG.HardLock
            S.Diag2.Text = "🔒 " .. (CFG.HardLock and "فوري" or "سلس")
        elseif i.KeyCode == Enum.KeyCode.N then
            CFG.TargetNPCs = true; CFG.TargetPlayers = false
            S.Diag2.Text = "🤖 NPCs فقط"
        elseif i.KeyCode == Enum.KeyCode.B then
            CFG.TargetNPCs = true; CFG.TargetPlayers = true
            S.Diag2.Text = "🤖👤 الكل"
        elseif i.KeyCode == Enum.KeyCode.V then
            CFG.TargetNPCs = false; CFG.TargetPlayers = true
            S.Diag2.Text = "👤 Players فقط"
        elseif i.KeyCode == Enum.KeyCode.T then
            CFG.RequireTool = not CFG.RequireTool
            S.Diag2.Text = "🔫 Tool: " .. (CFG.RequireTool and "ON" or "OFF")
        elseif i.KeyCode == Enum.KeyCode.P then
            CFG.PrioOffset += 100
            if CFG.Active then bind() end
            S.Diag2.Text = "⬆️ +" .. CFG.PrioOffset
        -- ⚡ أزرار السرعة
        elseif i.KeyCode == Enum.KeyCode.LeftBracket then
            CFG.Smooth = math.max(0.01, CFG.Smooth - 0.02)
            S.Diag2.Text = "⚡ سرعة: " .. CFG.Smooth
        elseif i.KeyCode == Enum.KeyCode.RightBracket then
            CFG.Smooth = math.min(0.5, CFG.Smooth + 0.02)
            S.Diag2.Text = "🐢 سرعة: " .. CFG.Smooth
        end
    end)
end

local function cleanup()
    pcall(function() RunService:UnbindFromRenderStep(S.BindName) end)
    if S.Gui then S.Gui:Destroy() end
end
ENV.__aimv9_cleanup = cleanup

pcall(buildUI)
print("[Aim v9] ⚡ جاهز — Smooth:0.04 | الأقرب فقط | بدون FOV")
print("[Aim v9] RShift=تفعيل M=Mode L=فوري N/V/B=نوع الهدف [ ]=سرعة")
