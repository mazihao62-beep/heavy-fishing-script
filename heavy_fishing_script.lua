--[[
    重型钓鱼 - 自动钓鱼 v1.1
    修复: 鱼竿检测 + 快捷键开关
--]]

print("[钓鱼] v1.1 加载中...")

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
local FishingMinigame = EV and EV:FindFirstChild("FishingMinigame")

print("[钓鱼] Fishing=" .. tostring(Fishing and "OK" or "NIL"))
print("[钓鱼] Catch=" .. tostring(Catch and "OK" or "NIL"))
print("[钓鱼] SellFish=" .. tostring(SellFish and "OK" or "NIL"))
print("[钓鱼] EquipRod=" .. tostring(EquipRod and "OK" or "NIL"))
print("[钓鱼] EquipBait=" .. tostring(EquipBait and "OK" or "NIL"))

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

local function printAllTools()
    local tools = getTools()
    if #tools == 0 then
        print("[工具] 背包和角色无Tool类对象")
    else
        for _, t in ipairs(tools) do
            print("[工具] " .. t.Name .. " (" .. t.ClassName .. ") Parent=" .. t.Parent.Name)
        end
    end
    local rods = {}
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("Tool") and obj.Name:lower():find("rod") then
            table.insert(rods, obj.Name)
        end
    end
    if #rods > 0 then
        print("[工具] 全图竿: " .. table.concat(rods, ", "))
    else
        print("[工具] 全图无Tool竿")
    end
end

local function getRod()
    local tools = getTools()
    for _, t in ipairs(tools) do
        local n = t.Name:lower()
        if n:find("rod") or n:find("pole") or n:find("fishing") then
            return t
        end
    end
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("Tool") and obj.Name:lower():find("rod") then
            return obj
        end
    end
    return nil
end

local function equipRodByName(name)
    if not EquipRod then return false end
    local ok, err = pcall(function() EquipRod:InvokeServer(name) end)
    if ok then
        print("[竿] InvokeServer(" .. name .. ") OK")
    else
        print("[竿] InvokeServer(" .. name .. ") ERR: " .. tostring(err))
    end
    return ok
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
        local best = nil; local bestDot = 0
        for _, part in ipairs(water:GetDescendants()) do
            if part:IsA("BasePart") then
                local d = (part.Position - pos).Magnitude
                local dot = (part.Position - pos).Unit:Dot(dir)
                if d >= 10 and d <= 50 and dot > bestDot then
                    best = part.Position; bestDot = dot
                end
            end
        end
        if best then return best + Vector3.new(0, 1, 0) end
    end
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj.Name:lower() == "water" and obj:IsA("BasePart") then
            local d = (obj.Position - pos).Magnitude
            local dot = (obj.Position - pos).Unit:Dot(dir)
            if d >= 5 and d <= 50 and dot > 0 then
                return obj.Position + Vector3.new(0, 1, 0)
            end
        end
    end
    return pos + dir * 30 + Vector3.new(0, 1, 0)
end

local S = {
    AutoFish = false, AutoSell = false, AutoBait = true,
    ShowFish = false,
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
    if not rod then
        print("[钓] 搜不到竿Tool，试试EquipFishingRod...")
        pcall(function() equipRodByName("Fishing Rod") end)
        wait(0.5)
        rod = getRod()
        if not rod then print("[钓] 无竿"); return end
    end
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
    if not rod then
        pcall(function() equipRodByName("Fishing Rod") end)
        wait(0.5)
        rod = getRod()
    end
    if not rod then print("[钓] 无竿"); return end
    equip(rod)
    if S.AutoBait and EquipBait then
        pcall(function()
            local ok, err = pcall(function() EquipBait:InvokeServer() end)
            if not ok then
                local baits = {}
                for _, obj in ipairs(WS:GetDescendants()) do
                    if obj.Name:lower():find("bait") and obj:IsA("Tool") then
                        table.insert(baits, obj.Name)
                    end
                end
                if #baits > 0 then equip(getRod()) end
            end
        end)
        wait(0.2)
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
    local current = {}; local h = getHRP(); local pos = h and h.Position
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
    for m, v in pairs(fishESP) do if not current[m] then pcall(function() v:Destroy() end); fishESP[m] = nil end end
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
        Title="重型钓鱼", Author="b站英吉利超入_", Icon="solar:fish-bold",
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

    local t1=WN:Tab({Title="主控面板", Icon="solar:slider-vertical-bold"})
    CT.AutoFish=t1:Toggle({Flag="AutoFish", Title="自动钓鱼", Value=false, Callback=function(v) S.AutoFish=v end})
    t1:Space()
    CT.AutoSell=t1:Toggle({Flag="AutoSell", Title="自动卖鱼", Value=false, Callback=function(v) S.AutoSell=v end})
    CT.AutoBait=t1:Toggle({Flag="AutoBait", Title="自动装饵", Value=true, Callback=function(v) S.AutoBait=v end})
    t1:Divider()
    CT.ShowFish=t1:Toggle({Flag="ShowFish", Title="鱼群ESP", Value=false, Callback=function(v) S.ShowFish=v; if not v then updateFishESP() end end})
    t1:Divider()
    t1:Button({Title="手动抛竿", Icon="solar:round-arrow-up-bold", Justify="Center", Color=Color3.fromHex("#305dff"), Callback=function() pcall(doCast) end})
    t1:Space()
    t1:Button({Title="手动收线", Icon="solar:round-arrow-down-bold", Justify="Center", Color=Color3.fromHex("#ff6030"), Callback=function() pcall(doReel) end})
    t1:Space()
    t1:Button({Title="调试: 打印所有工具", Icon="solar:bug-bold", Justify="Center", Color=Color3.fromHex("#ff9900"), Callback=function() printAllTools() end})

    local t2=WN:Tab({Title="快捷键", Icon="solar:settings-bold"})
    t2:Keybind({Flag="ToggleKey", Title="窗口开关", Value="RightShift",
        Callback=function(v)
            KB.Toggle = v
            if WN then pcall(function() WN:SetToggleKey(v) end) end
            print("[键] 切换键设为: " .. tostring(v))
        end
    })

    local t3=WN:Tab({Title="UI设置", Icon="solar:monitor-bold"})
    CT.Particles=t3:Toggle({Flag="Particles", Title="粒子背景", Value=true, Callback=function(v) S.Particles=v; if v then sP() else xP() end end})
    t3:Toggle({Flag="Acrylic", Title="毛玻璃", Value=true, Callback=function(v) S.Acrylic=v; pcall(function() WI:ToggleAcrylic(v) end) end})
    t3:Toggle({Flag="Transparent", Title="透明", Value=false, Callback=function(v) S.Transparent=v; pcall(function() WN:ToggleTransparency(v) end) end})
    local tns={"Blue","Dark","Light","Rose","Ocean","Sunset","Midnight","Forest","Lavender","Coral","Mint","Sky","Blood","Lemon","Cyber"}
    t3:Dropdown({Flag="Theme", Title="主题", Values=tns, Value="Blue", Callback=function(v) pcall(function() WI:SetTheme(v) end); S.ParticleColor=tc(v) end})

    local t4=WN:Tab({Title="信息统计", Icon="solar:chart-bold"})
    local sFish=t4:Paragraph({Title="上钩: 0"})
    local sRod=t4:Paragraph({Title="鱼竿: 无"})

    local t5=WN:Tab({Title="配置管理", Icon="solar:diskette-bold"})
    pcall(function()
        local CM=WN.ConfigManager; if not CM then return end
        local cni=t5:Input({Flag="CN", Title="配置名称", Value="default", Icon="solar:file-text-bold", Callback=function(v) end})
        t5:Space(); local AC={}; pcall(function() AC=CM:AllConfigs() end)
        local DV=nil; for _,v in ipairs(AC) do if v=="default" then DV="default"; break end end
        local ACD=t5:Dropdown({Title="已有配置", Values=AC, Value=DV, Callback=function(v) if v then pcall(function() cni:Set(v) end) end end})
        t5:Space()
        t5:Button({Title="保存", Icon="solar:check-circle-bold", Justify="Center", Color=Color3.fromHex("#305dff"), Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Save() then WI:Notify({Title="已保存", Content="OK", Duration=3, Icon="solar:check-circle-bold"})
                pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        t5:Space()
        t5:Button({Title="加载", Icon="solar:refresh-circle-bold", Justify="Center", Color=Color3.fromHex("#10C550"), Callback=function()
            if not CM then return end; local c=CM:CreateConfig("default",false)
            if c and c:Load() then WI:Notify({Title="已加载", Content="OK", Duration=3, Icon="solar:refresh-circle-bold"}) end end})
        t5:Space()
        t5:Button({Title="删除", Icon="solar:trash-bin-trash-bold", Justify="Center", Color=Color3.fromHex("#ff3040"), Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Delete() then WI:Notify({Title="已删除", Content="OK", Duration=3, Icon="solar:trash-bin-trash-bold"})
                pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        spawn(function() wait(1) pcall(function() CM:CreateConfig("default",true) end) end)
    end)

    local t6=WN:Tab({Title="关于", Icon="solar:info-square-bold"})
    t6:Paragraph({Title="重型钓鱼 v1.1"}); t6:Divider()
    t6:Paragraph({Title="作者", Desc="b站英吉利超入_"})
    t6:Paragraph({Title="说明", Desc="自动抛竿+收线+卖鱼+鱼群ESP"})
    return sFish, sRod
end

pcall(function() WI:SetTheme("Ocean") end)
S.ParticleColor = tc("Ocean")

local PP = false
WI:Popup({
    Title="重型钓鱼 v1.1",
    Content="自动抛竿/收线/卖鱼 鱼群ESP",
    Buttons={
        {Title="加载", Callback=function() PP=true end, Variant="Primary"},
        {Title="取消", Callback=function() return end}
    }
})
while not PP do wait(0.1) end

print("[调试] 加载时工具列表:")
printAllTools()

spawn(function()
    local sFish, sRod = mW()
    print("[钓鱼] v1.1 开始运行")
    local last = 0
    while true do
        if S.AutoFish then pcall(autoFishLoop); wait(2) end
        if S.AutoSell then pcall(doSellFish); wait(1) end
        pcall(updateFishESP)
        local now = tick()
        if now - last > 3 then
            last = now
            if sFish then pcall(function() sFish:SetTitle("上钩: " .. fishCaught) end) end
            if sRod then
                local rod = getRod()
                pcall(function() sRod:SetTitle("鱼竿: " .. (rod and rod.Name or "无")) end)
            end
        end
        wait(0.5)
    end
end)
