--[[
    重型钓鱼 - 自动钓鱼 v1.0
    WindUI 模板 + 自动抛竿/收线/卖鱼
--]]

print("[钓鱼] v1.0 加载中...")

local P = game:GetService("Players")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local C = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")

local LP = P.LocalPlayer
if not LP then print("[钓鱼] 无LocalPlayer"); return end
print("[钓鱼] 玩家: " .. LP.Name)

for _, g in ipairs(C:GetChildren()) do
    if g:IsA("ScreenGui") then
        if g.Name == "A" or g.Name:find("Fishing") or g.Name == "WindUI" then
            pcall(function() g:Destroy() end)
        end
    end
end

local WI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
if not WI then print("[钓鱼] WindUI 失败"); return end
print("[钓鱼] WindUI OK")

local EV = RS:FindFirstChild("Events")
local Fishing = EV and EV:FindFirstChild("Fishing")
local PositionCast = EV and EV:FindFirstChild("Position_Cast")
local Catch = EV and EV:FindFirstChild("Catch")
local AutoFish = EV and EV:FindFirstChild("AutoFishing")
local SellFish = EV and EV:FindFirstChild("SellFish")
local EquipRod = EV and EV:FindFirstChild("EquipFishingRod")
local EquipBait = EV and EV:FindFirstChild("EquipBait")

print("[钓鱼] Fishing=" .. tostring(Fishing and "OK" or "NIL"))
print("[钓鱼] PositionCast=" .. tostring(PositionCast and "OK" or "NIL"))
print("[钓鱼] Catch=" .. tostring(Catch and "OK" or "NIL"))
print("[钓鱼] AutoFish=" .. tostring(AutoFish and "OK" or "NIL"))
print("[钓鱼] SellFish=" .. tostring(SellFish and "OK" or "NIL"))

local function getTools()
    local tools = {}
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then table.insert(tools, t) end
        end
    end
    local c = LP.Character
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") then table.insert(tools, t) end
        end
    end
    return tools
end

local function getRod()
    local tools = getTools()
    for _, t in ipairs(tools) do
        local n = t.Name:lower()
        if n:find("rod") or n:find("pole") or n:find("fishing") then
            return t
        end
    end
    return nil
end

local function getBait()
    local tools = getTools()
    for _, t in ipairs(tools) do
        local n = t.Name:lower()
        if n:find("bait") or n:find("worm") or n:find("lure") then
            return t
        end
    end
    return nil
end

local function equip(t)
    if not t then return false end
    local c = LP.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    if t.Parent ~= c then
        h:EquipTool(t)
        wait(0.2)
    end
    return true
end

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function findWaterSpot()
    local h = getHRP()
    if not h then return nil end
    local pos = h.Position
    local dir = h.CFrame.LookVector

    local water = WS:FindFirstChild("Ocean") or WS:FindFirstChild("water") or WS:FindFirstChild("Water")
    if water then
        local best = nil
        local bestDot = 0
        for _, part in ipairs(water:GetDescendants()) do
            if part:IsA("BasePart") then
                local d = (part.Position - pos).Magnitude
                local dot = (part.Position - pos).Unit:Dot(dir)
                if d >= 10 and d <= 50 and dot > bestDot then
                    best = part.Position
                    bestDot = dot
                end
            end
        end
        if best then return best + Vector3.new(0, 1, 0) end
    end
    return pos + dir * 30 + Vector3.new(0, 1, 0)
end

local S = {
    AutoFish = false, AutoSell = false, AutoBait = true,
    FastCast = true, ShowFish = false,
    Particles = true, Acrylic = true, Transparent = false,
    ParticleColor = Color3.fromRGB(0, 150, 255)
}
local KB = { Toggle = "RightShift" }
local WN, CT = nil, {}
local PR, PS, PC = false, {}, nil
local fishCaught = 0

local function doCast()
    if not Fishing then return end
    local rod = getRod()
    if not rod then print("[钓] 无鱼竿"); return end
    equip(rod)
    local spot = findWaterSpot()
    if not spot then print("[钓] 找不到水面"); return end
    local h = getHRP()
    if h then h.CFrame = CFrame.lookAt(h.Position, spot); wait(0.2) end
    pcall(function() Fishing:FireServer("Cast", {Position = spot}); print("[钓] 抛竿") end)
end

local function doReel()
    if not Fishing then return end
    pcall(function() Fishing:FireServer("Reel"); print("[钓] 收线") end)
end

local function autoFishLoop()
    if not S.AutoFish or not Fishing then return end
    local rod = getRod()
    if not rod then print("[钓] 无鱼竿"); return end
    equip(rod)
    if S.AutoBait then
        local bait = getBait()
        if bait and EquipBait then
            pcall(function() EquipBait:InvokeServer(bait.Name) end)
            wait(0.2)
        end
    end
    local spot = findWaterSpot()
    if spot then
        local h = getHRP()
        if h then h.CFrame = CFrame.lookAt(h.Position, spot); wait(0.3) end
        pcall(function() Fishing:FireServer("Cast", {Position = spot}) end)
        print("[钓] 抛竿")
    end
    wait(5 + math.random(3))
    pcall(function() Fishing:FireServer("Reel") end)
    print("[钓] 收线")
    wait(0.5)
    if Catch then
        pcall(function() Catch:FireServer() end)
        fishCaught = fishCaught + 1
        print("[钓] 捕鱼! 总计:" .. fishCaught)
    end
end

local function doSellFish()
    if not S.AutoSell or not SellFish then return end
    local npcFolder = WS:FindFirstChild("NPC")
    if not npcFolder then return end
    for _, npc in ipairs(npcFolder:GetChildren()) do
        local n = npc.Name:lower()
        if n:find("sell") or n:find("merchant") or n:find("shop") or n:find("fish") then
            local npcPart = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true)
            if npcPart then
                local h = getHRP()
                if h then
                    local d = (npcPart.Position - h.Position).Magnitude
                    if d > 15 then
                        h.CFrame = CFrame.new(npcPart.Position.X, npcPart.Position.Y + 2, npcPart.Position.Z - 4)
                        wait(0.5)
                    end
                    pcall(function() SellFish:FireServer() end)
                    print("[钓] 卖鱼")
                end
            end
            break
        end
    end
end

local fishESP = {}
local function updateFishESP()
    if not S.ShowFish then
        for _, v in pairs(fishESP) do pcall(function() v:Destroy() end) end
        fishESP = {}; return
    end
    local fishes = WS:FindFirstChild("Fishes")
    if not fishes then return end
    local current = {}
    local h = getHRP()
    local pos = h and h.Position
    if not pos then return end
    for _, fish in ipairs(fishes:GetChildren()) do
        if fish:IsA("Model") then
            local bp = fish.PrimaryPart or fish:FindFirstChildWhichIsA("BasePart", true)
            if bp and (bp.Position - pos).Magnitude <= 100 then
                current[fish] = true
                if not fishESP[fish] then
                    local bb = Instance.new("BillboardGui")
                    bb.Size = UDim2.new(0, 60, 0, 30); bb.MaxDistance = 100
                    bb.AlwaysOnTop = true; bb.StudsOffset = Vector3.new(0, 3, 0)
                    pcall(function() bb.Parent = fish end)
                    local tl = Instance.new("TextLabel", bb)
                    tl.Size = UDim2.new(1,0,1,0); tl.Text = "Fish"
                    tl.TextScaled = true; tl.BackgroundTransparency = 1
                    tl.TextColor3 = Color3.fromRGB(0, 200, 255)
                    fishESP[fish] = bb
                end
            end
        end
    end
    for m, v in pairs(fishESP) do
        if not current[m] then pcall(function() v:Destroy() end); fishESP[m] = nil end
    end
end

local function sP()
    if PR then return end
    if PC then pcall(function() local p=PC.Parent; if p then p:Destroy() end end) PC=nil end
    PS={}; wait(0.3)
    local sg=Instance.new("ScreenGui"); sg.Name="FP"; sg.ResetOnSpawn=false; sg.DisplayOrder=999999; sg.IgnoreGuiInset=true; sg.Parent=C
    PC=Instance.new("Frame"); PC.Size=UDim2.new(1,0,1,0); PC.BackgroundTransparency=1; PC.BorderSizePixel=0; PC.Parent=sg
    for i=1,50 do
        local d=Instance.new("Frame"); local sz=math.random(5,10)
        d.Size=UDim2.new(0,sz,0,sz); d.Position=UDim2.new(0.2+math.random()*0.6,0,0.2+math.random()*0.6,0)
        d.BackgroundColor3=S.ParticleColor; d.BackgroundTransparency=0.3+math.random()*0.5; d.BorderSizePixel=0; d.Parent=PC
        Instance.new("UICorner",d).CornerRadius=UDim.new(0,10)
        local a=math.random()*6.28; local sp=0.0008+math.random()*0.002
        table.insert(PS,{F=d,Sx=d.Position.X.Scale,Sy=d.Position.Y.Scale,Vx=math.cos(a)*sp,Vy=math.sin(a)*sp,Ph=math.random()*6.28,Sz=sz})
    end
    PR=true
    spawn(function() local t=0; while PR and PC do t=t+0.03
        pcall(function() local c=S.ParticleColor; for _,p in ipairs(PS) do if p.F and p.F.Parent then
            local sx=math.max(0.05,math.min(0.95,p.Sx+p.Vx)); local sy=math.max(0.05,math.min(0.95,p.Sy+p.Vy))
            if sx>=0.95 or sx<=0.05 then p.Vx=-p.Vx end; if sy>=0.95 or sy<=0.05 then p.Vy=-p.Vy end
            p.Sx=sx; p.Sy=sy; p.F.Position=UDim2.new(sx,0,sy,0); p.F.BackgroundColor3=c
            p.F.BackgroundTransparency=0.3+math.sin(t*0.8+p.Ph)*0.4
            p.F.Size=UDim2.new(0,math.max(2,p.Sz+math.sin(t+p.Ph)*1.5),0,math.max(2,p.Sz+math.sin(t+p.Ph)*1.5))
    end end end) wait(0.03) end end)
end
local function xP() PR=false; if PC then pcall(function() local p=PC.Parent; if p then p:Destroy() end end) PC=nil end; PS={} end

local tc_t = {Blue=Color3.fromRGB(0,150,255),Dark=Color3.fromRGB(80,170,255),Light=Color3.fromRGB(60,130,210),Rose=Color3.fromRGB(255,130,170),Ocean=Color3.fromRGB(0,180,230),Sunset=Color3.fromRGB(255,160,70),Midnight=Color3.fromRGB(130,100,240),Forest=Color3.fromRGB(60,180,90),Lavender=Color3.fromRGB(190,140,255),Coral=Color3.fromRGB(255,140,90),Mint=Color3.fromRGB(80,230,190),Sky=Color3.fromRGB(100,190,255),Blood=Color3.fromRGB(230,90,80),Lemon=Color3.fromRGB(230,210,70),Cyber=Color3.fromRGB(0,235,210)}
local function tc(n) return tc_t[n] or Color3.fromRGB(0,150,255) end

local function mW()
    WN = WI:CreateWindow({
        Title="\351\207\215\345\236\213\351\222\223\351\261\274", Author="b\347\253\231\350\213\261\345\220\211\345\210\251\350\266\205\345\205\245\137", Icon="solar:fish-bold",
        Size=UDim2.fromOffset(750,540), ToggleKey=Enum.KeyCode.RightShift,
        Folder="heavy-fishing", Acrylic=true, Resizable=false,
        ScrollBarEnabled=true, HideSearchBar=true,
        OnClose=function()
            xP(); S.AutoFish=false
            for _,ct in pairs(CT) do
                if ct and type(ct.Set)=="function" then pcall(function() ct:Set(false) end) end
            end
        end,
        OnOpen=function() if S.Particles then sP() end end
    })
    spawn(function() wait(0.8) pcall(function() if WN and WN.Parent then WN.Parent.ClipsDescendants=true end end) end)

    local t1=WN:Tab({Title="\344\270\273\346\216\247\351\235\242\346\235\277", Icon="solar:slider-vertical-bold"})
    CT.AutoFish=t1:Toggle({Flag="AutoFish", Title="\350\207\252\345\212\250\351\222\223\351\261\274(\345\276\252\347\216\257\346\212\233\347\253\277\346\224\266\347\272\277)", Value=false, Callback=function(v) S.AutoFish=v end})
    t1:Space()
    CT.AutoSell=t1:Toggle({Flag="AutoSell", Title="\350\207\252\345\212\250\345\215\226\351\261\274", Value=false, Callback=function(v) S.AutoSell=v end})
    CT.AutoBait=t1:Toggle({Flag="AutoBait", Title="\350\207\252\345\212\250\350\243\205\351\245\265", Value=true, Callback=function(v) S.AutoBait=v end})
    t1:Divider()
    CT.ShowFish=t1:Toggle({Flag="ShowFish", Title="\351\261\274\347\276\244ESP", Value=false, Callback=function(v) S.ShowFish=v; if not v then updateFishESP() end end})
    t1:Divider()
    t1:Button({Title="\346\211\213\345\212\250\346\212\233\347\253\277", Icon="solar:round-arrow-up-bold", Justify="Center", Color=Color3.fromHex("#305dff"), Callback=function()
        pcall(doCast)
    end})
    t1:Space()
    t1:Button({Title="\346\211\213\345\212\250\346\224\266\347\272\277", Icon="solar:round-arrow-down-bold", Justify="Center", Color=Color3.fromHex("#ff6030"), Callback=function()
        pcall(doReel)
    end})

    local t2=WN:Tab({Title="\345\277\253\346\215\267\351\224\256", Icon="solar:settings-bold"})
    t2:Keybind({Flag="ToggleKey", Title="\347\252\227\345\217\243\345\274\200\345\205\263", Value="RightShift", Callback=function(v) KB.Toggle=v end})

    local t3=WN:Tab({Title="UI\350\256\276\347\275\256", Icon="solar:monitor-bold"})
    CT.Particles=t3:Toggle({Flag="Particles", Title="\347\262\222\345\255\220\350\203\214\346\231\257", Value=true, Callback=function(v) S.Particles=v; if v then sP() else xP() end end})
    t3:Toggle({Flag="Acrylic", Title="\346\257\233\347\216\273\347\222\203", Value=true, Callback=function(v) S.Acrylic=v; pcall(function() WI:ToggleAcrylic(v) end) end})
    t3:Toggle({Flag="Transparent", Title="\351\200\217\346\230\216", Value=false, Callback=function(v) S.Transparent=v; pcall(function() WN:ToggleTransparency(v) end) end})
    local tns={"Blue","Dark","Light","Rose","Ocean","Sunset","Midnight","Forest","Lavender","Coral","Mint","Sky","Blood","Lemon","Cyber"}
    t3:Dropdown({Flag="Theme", Title="\344\270\273\351\242\230", Values=tns, Value="Blue", Callback=function(v) pcall(function() WI:SetTheme(v) end); S.ParticleColor=tc(v) end})

    local t4=WN:Tab({Title="\344\277\241\346\201\257\347\273\237\350\256\241", Icon="solar:chart-bold"})
    local sFish=t4:Paragraph({Title="\344\270\212\351\222\251: 0"})
    local sRod=t4:Paragraph({Title="\351\261\274\347\253\277: \346\227\240"})

    local t5=WN:Tab({Title="\351\205\215\347\275\256\347\256\241\347\220\206", Icon="solar:diskette-bold"})
    pcall(function()
        local CM=WN.ConfigManager; if not CM then return end
        local cni=t5:Input({Flag="CN", Title="\351\205\215\347\275\256\345\220\215\347\247\260", Value="default", Icon="solar:file-text-bold", Callback=function(v) end})
        t5:Space(); local AC={}; pcall(function() AC=CM:AllConfigs() end)
        local DV=nil; for _,v in ipairs(AC) do if v=="default" then DV="default"; break end end
        local ACD=t5:Dropdown({Title="\345\267\262\346\234\211\351\205\215\347\275\256", Values=AC, Value=DV, Callback=function(v) if v then pcall(function() cni:Set(v) end) end end})
        t5:Space()
        t5:Button({Title="\344\277\235\345\255\230", Icon="solar:check-circle-bold", Justify="Center", Color=Color3.fromHex("#305dff"), Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Save() then WI:Notify({Title="\345\267\262\344\277\235\345\255\230", Content="OK", Duration=3, Icon="solar:check-circle-bold"})
                pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        t5:Space()
        t5:Button({Title="\345\212\240\350\275\275", Icon="solar:refresh-circle-bold", Justify="Center", Color=Color3.fromHex("#10C550"), Callback=function()
            if not CM then return end; local c=CM:CreateConfig("default",false)
            if c and c:Load() then WI:Notify({Title="\345\267\262\345\212\240\350\275\275", Content="OK", Duration=3, Icon="solar:refresh-circle-bold"}) end end})
        t5:Space()
        t5:Button({Title="\345\210\240\351\231\244", Icon="solar:trash-bin-trash-bold", Justify="Center", Color=Color3.fromHex("#ff3040"), Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Delete() then WI:Notify({Title="\345\267\262\345\210\240\351\231\244", Content="OK", Duration=3, Icon="solar:trash-bin-trash-bold"})
                pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        spawn(function() wait(1) pcall(function() CM:CreateConfig("default",true) end) end)
    end)

    local t6=WN:Tab({Title="\345\205\263\344\272\216", Icon="solar:info-square-bold"})
    t6:Paragraph({Title="\351\207\215\345\236\213\351\222\223\351\261\274 v1.0"}); t6:Divider()
    t6:Paragraph({Title="\344\275\234\350\200\205", Desc="b\347\253\231\350\213\261\345\220\211\345\210\251\350\266\205\345\205\245\137"})
    t6:Paragraph({Title="\350\257\264\346\230\216", Desc="\350\207\252\345\212\250\346\212\233\347\253\277+\346\224\266\347\272\277+\345\215\226\351\261\274+\351\261\274\347\276\244ESP"})
    return sFish, sRod
end

pcall(function() WI:SetTheme("Ocean") end)
S.ParticleColor = tc("Ocean")

local PP = false
WI:Popup({
    Title="\351\207\215\345\236\213\351\222\223\351\261\274 v1.0",
    Content="\350\207\252\345\212\250\346\212\233\347\253\277/\346\224\266\347\272\277/\345\215\226\351\261\274 \351\261\274\347\276\244ESP",
    Buttons={
        {Title="\345\212\240\350\275\275", Callback=function() PP=true end, Variant="Primary"},
        {Title="\345\217\226\346\266\210", Callback=function() return end}
    }
})
while not PP do wait(0.1) end

spawn(function()
    local sFish, sRod = mW()
    print("[钓鱼] v1.0 开始运行")
    local last = 0
    while true do
        if S.AutoFish then pcall(autoFishLoop); wait(2) end
        if S.AutoSell then pcall(doSellFish); wait(1) end
        pcall(updateFishESP)
        local now = tick()
        if now - last > 3 then
            last = now
            if sFish then pcall(function() sFish:SetTitle("\344\270\212\351\222\251: " .. fishCaught) end) end
            if sRod then
                local rod = getRod()
                pcall(function() sRod:SetTitle("\351\261\274\347\253\277: " .. (rod and rod.Name or "\346\227\240")) end)
            end
        end
        wait(0.5)
    end
end)