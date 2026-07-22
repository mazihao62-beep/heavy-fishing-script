
--[[
    重型钓鱼 自动钓鱼 v1.3
    WindUI 模板 + 自动战斗（鱼上钩维持稳定）
    核心：EquipFishingRod → Cast → 等鱼上钩 → FishingMinigame 自动战斗 → Catch
--]]

print("[钓鱼] v1.3 加载中...")

local P = game:GetService("Players")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")
local C = game:GetService("CoreGui")

local LP = P.LocalPlayer
if not LP then return end

-- 清除旧Gui
for _, g in ipairs(C:GetChildren()) do
    if g:IsA("ScreenGui") and (g.Name == "A" or g.Name:find("Fishing") or g.Name == "WindUI") then
        pcall(function() g:Destroy() end)
    end
end

local WI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
if not WI then print("[钓鱼] WindUI 失败"); return end
print("[钓鱼] WindUI OK")

-- 获取远程事件
local Events = RS:FindFirstChild("Events")
if not Events then print("[钓鱼] Events 不存在！"); return end

local EquipRod = Events:FindFirstChild("EquipFishingRod")
local EquipBait = Events:FindFirstChild("EquipBait")
local PositionCast = Events:FindFirstChild("Position_Cast")
local Fishing = Events:FindFirstChild("Fishing")
local CatchEvent = Events:FindFirstChild("Catch")
local SellFish = Events:FindFirstChild("SellFish")
local FishingMinigame = Events:FindFirstChild("FishingMinigame")
local TriggerSkill = Events:FindFirstChild("TriggerMinigameSkill")
local UpdateProg = Events:FindFirstChild("UpdateFishProgression")

print("[钓鱼] EquipRod=" .. (EquipRod and "OK" or "NIL"))
print("[钓鱼] Fishing=" .. (Fishing and "OK" or "NIL"))
print("[钓鱼] Catch=" .. (CatchEvent and "OK" or "NIL"))
print("[钓鱼] Minigame=" .. (FishingMinigame and "OK" or "NIL"))
print("[钓鱼] SellFish=" .. (SellFish and "OK" or "NIL"))

-- 设置
local S = {
    AutoFish = false,
    AutoBattle = true,
    AutoSell = false,
    CastPower = 30,
    WaitTime = 10,
    FishRange = 50,
    BattleSpeed = 0.05,
    Particles = true,
    Acrylic = true,
    Transparent = false,
    ParticleColor = Color3.fromRGB(30, 150, 255)
}
local KB = { Toggle = "RightShift" }
local WN, CT = nil, {}
local PR, PS, PC = false, {}, nil
local fishCount = 0
local inBattle = false

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- 获取钓鱼UI
local function getFishingUI()
    local pg = LP:FindFirstChild("PlayerGui")
    local mainGui = pg and pg:FindFirstChild("MainGui")
    return mainGui and mainGui:FindFirstChild("Fishing")
end

-- 检测鱼是否上钩（Fishing UI 可见）
local function isFishBiting()
    local fishingUI = getFishingUI()
    return fishingUI and fishingUI.Visible == true
end

-- 自动战斗（保持稳定）
local function doBattle()
    if not S.AutoBattle or not FishingMinigame then return end
    local fishingUI = getFishingUI()
    if not fishingUI or not fishingUI.Visible then
        if inBattle then
            print("[战斗] 战斗结束")
            inBattle = false
        end
        return
    end

    if not inBattle then
        print("[战斗] 鱼上钩！开始战斗...")
        inBattle = true
    end

    -- 战斗循环：快速交替发 minigame 事件保持稳定
    local startTime = os.clock()

    -- 战斗持续直到 Fishing UI 消失
    local tickCount = 0
    while fishingUI and fishingUI.Visible and S.AutoBattle do
        tickCount = tickCount + 1

        -- 交替发事件
        if tickCount % 2 == 0 then
            pcall(function() FishingMinigame:FireServer(1) end)
        else
            pcall(function() FishingMinigame:FireServer(2) end)
        end

        -- 每5轮触发一次技能
        if tickCount % 10 == 0 and TriggerSkill then
            pcall(function() TriggerSkill:FireServer(1) end)
        end

        -- 更新 Progression
        if tickCount % 3 == 0 and UpdateProg then
            pcall(function() UpdateProg:FireServer(1) end)
        end

        wait(S.BattleSpeed)

        -- 超时保护（60秒强制结束）
        if os.clock() - startTime > 60 then
            print("[战斗] 超时，强制结束战斗")
            break
        end

        -- 刷新引用
        fishingUI = getFishingUI()
    end

    if inBattle then
        print("[战斗] 鱼已捕获/逃脱")
        inBattle = false
        wait(0.3)

        -- 尝试捕鱼
        if CatchEvent then
            pcall(function() CatchEvent:FireServer() end)
            fishCount = fishCount + 1
            print("[钓鱼] 捕鱼成功！总数: " .. fishCount)

            -- 自动卖鱼
            if S.AutoSell and SellFish then
                wait(0.5)
                pcall(function() SellFish:FireServer() end)
                print("[钓鱼] 自动卖鱼")
            end
        end
    end
end

-- 装备鱼竿
local function equipRod()
    if not EquipRod then return false end
    local ok, r = pcall(function() return EquipRod:InvokeServer("Fishing Rod") end)
    print("[钓鱼] 装备鱼竿: " .. tostring(ok))
    return ok
end

-- 抛竿
local function cast()
    equipRod()
    wait(0.3)
    local hrp = getHRP()
    if not hrp then return false end
    local pos = hrp.Position
    local dir = hrp.CFrame.LookVector
    local target = pos + dir * S.CastPower

    if PositionCast then
        pcall(function() PositionCast:FireServer(target) end)
        wait(0.1)
    end
    if Fishing then
        pcall(function() Fishing:FireServer("Cast", {Position = target}) end)
    end
    print("[钓鱼] 抛竿 @" .. math.floor(target.X) .. "," .. math.floor(target.Z))
    return true
end

-- 手动收线
local function catchFish()
    if CatchEvent then
        pcall(function() CatchEvent:FireServer() end)
        print("[钓鱼] 手动收线")
    end
end

-- 卖鱼
local function sellFish()
    if SellFish then
        pcall(function() SellFish:FireServer() end)
        print("[钓鱼] 卖鱼")
    end
end

-- 自动钓鱼循环
local function doAutoFish()
    if not S.AutoFish then return end

    -- 如果正在战斗中，先处理战斗
    if isFishBiting() then
        doBattle()
        return
    end

    -- 否则抛竿
    cast()
end

-- ============ 粒子 ============
local function sP()
    if PR then return end
    if PC then pcall(function() local p=PC.Parent; if p then p:Destroy() end end) PC=nil end
    PS={}; wait(0.3)
    local sg=Instance.new("ScreenGui"); sg.Name="FP"; sg.ResetOnSpawn=false; sg.DisplayOrder=999999; sg.IgnoreGuiInset=true; sg.Parent=C
    PC=Instance.new("Frame"); PC.Size=UDim2.new(1,0,1,0); PC.BackgroundTransparency=1; PC.BorderSizePixel=0; PC.Active=false; PC.Parent=sg
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

-- ============ 主题 ============
local tc_t = {Dark=Color3.fromRGB(30,150,255),Light=Color3.fromRGB(60,180,255),Rose=Color3.fromRGB(255,130,170),Plant=Color3.fromRGB(70,210,130),Ocean=Color3.fromRGB(0,180,230),Sunset=Color3.fromRGB(255,160,70),Midnight=Color3.fromRGB(130,100,240),Forest=Color3.fromRGB(60,180,90),Lavender=Color3.fromRGB(190,140,255),Coral=Color3.fromRGB(255,140,90),Mint=Color3.fromRGB(80,230,190),Sky=Color3.fromRGB(100,190,255),Blood=Color3.fromRGB(230,90,80),Lemon=Color3.fromRGB(230,210,70),Cyber=Color3.fromRGB(0,235,210)}
local function tc(n) return tc_t[n] or Color3.fromRGB(30,150,255) end

-- ============ UI ============
local function mW()
    WN = WI:CreateWindow({
        Title="重型钓鱼", Author="b站英吉利超入_", Icon="solar:fishing-bold",
        Size=UDim2.fromOffset(750,540), ToggleKey=Enum.KeyCode.RightShift,
        Folder="fishing-script", Acrylic=true, Resizable=false,
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
    CT.AutoBattle=t1:Toggle({Flag="AutoBattle", Title="自动战斗(保持稳定)", Value=true, Callback=function(v) S.AutoBattle=v end})
    t1:Space()
    CT.EquipRodBtn=t1:Button({Title="装备鱼竿", Icon="solar:fishing-bold", Justify="Center", Color=Color3.fromHex("#305dff"), Callback=function() equipRod() end})
    t1:Space()

    -- 鱼饵选择
    local baits = {"无"}
    if EquipBait then
        local ok, list = pcall(function() return EquipBait:InvokeServer("List") end)
        if ok and type(list) == "table" then
            baits = {}
            for _, b in ipairs(list) do table.insert(baits, tostring(b)) end
        end
    end
    if #baits <= 1 then
        local bp = LP:FindFirstChild("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                local n = t.Name:lower()
                if n:find("bait") or n:find("worm") or n:find("lure") then
                    table.insert(baits, t.Name)
                end
            end
        end
    end
    CT.BaitDropdown=t1:Dropdown({Title="选择鱼饵", Values=baits, Value=baits[1] or "无", Callback=function(v)
        if v and EquipBait and v ~= "无" then
            pcall(function() EquipBait:InvokeServer(v) end)
        end
    end})
    t1:Space()

    t1:Button({Title="手动抛竿", Icon="solar:cast-bold", Justify="Center", Color=Color3.fromHex("#10C550"), Callback=function() cast() end})
    t1:Button({Title="手动收线", Icon="solar:wind-bold", Justify="Center", Color=Color3.fromHex("#ff9040"), Callback=function() catchFish() end})
    t1:Button({Title="卖鱼", Icon="solar:wallet-bold", Justify="Center", Color=Color3.fromHex("#ff3040"), Callback=function() sellFish() end})
    t1:Divider()
    CT.CastPower=t1:Slider({Flag="CastPower", Title="抛竿距离", Step=5, Value={Min=10,Max=100,Default=30}, Width=200, IsTextbox=true, Callback=function(v) S.CastPower=v end})
    CT.BattleSpeed=t1:Slider({Flag="BattleSpeed", Title="战斗速度(秒)", Step=0.01, Value={Min=0.01,Max=0.2,Default=0.05}, Width=200, IsTextbox=true, Callback=function(v) S.BattleSpeed=v end})
    CT.SellToggle=t1:Toggle({Flag="SellFish", Title="捕获后自动卖鱼", Value=false, Callback=function(v) S.AutoSell=v end})

    local t2=WN:Tab({Title="快捷键", Icon="solar:settings-bold"})
    t2:Keybind({Flag="ToggleKey", Title="窗口开关", Value="RightShift", Callback=function(v) KB.Toggle=v end})

    local t3=WN:Tab({Title="UI设置", Icon="solar:monitor-bold"})
    CT.Particles=t3:Toggle({Flag="Particles", Title="粒子背景", Value=true, Callback=function(v) S.Particles=v; if v then sP() else xP() end end})
    t3:Toggle({Flag="Acrylic", Title="毛玻璃", Value=true, Callback=function(v) S.Acrylic=v; pcall(function() WI:ToggleAcrylic(v) end) end})
    t3:Toggle({Flag="Transparent", Title="透明", Value=false, Callback=function(v) S.Transparent=v; pcall(function() WN:ToggleTransparency(v) end) end})
    local tns={"Dark","Light","Rose","Plant","Ocean","Sunset","Midnight","Forest","Lavender","Coral","Mint","Sky","Blood","Lemon","Cyber"}
    t3:Dropdown({Flag="Theme", Title="主题", Values=tns, Value="Dark", Callback=function(v) pcall(function() WI:SetTheme(v) end); S.ParticleColor=tc(v) end})

    local t4=WN:Tab({Title="信息统计", Icon="solar:chart-bold"})
    local sFish=t4:Paragraph({Title="钓鱼次数: 0"})

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
    t6:Paragraph({Title="重型钓鱼 v1.3"}); t6:Divider()
    t6:Paragraph({Title="作者", Desc="b站英吉利超入_"})
    t6:Paragraph({Title="功能", Desc="抛竿 → 自动战斗(稳定平衡) → 捕鱼 → 卖鱼"})
    return sFish
end

-- ============ 主循环 ============
pcall(function() WI:SetTheme("Dark") end)
S.ParticleColor = tc("Dark")

local PP = false
WI:Popup({
    Title="重型钓鱼 v1.3",
    Content="抛竿 → 自动战斗(平衡条) → 捕鱼 → 卖鱼",
    Buttons={
        {Title="加载", Callback=function() PP=true end, Variant="Primary"},
        {Title="取消", Callback=function() return end}
    }
})
while not PP do wait(0.1) end

spawn(function()
    local sFish = mW()
    print("[钓鱼] v1.3 开始运行")
    local last = os.clock()

    while true do
        if S.AutoFish then
            -- 检查是否有鱼上钩
            if isFishBiting() then
                doBattle()
            else
                -- 每15秒自动抛竿一次（如果不在战斗中）
                local hrp = getHRP()
                if hrp then
                    cast()
                end
                wait(S.WaitTime)
            end
        end

        wait(0.5)

        local now = os.clock()
        if now - last > 5 then
            last = now
            if sFish then pcall(function() sFish:SetTitle("钓鱼次数: " .. fishCount) end) end
        end
    end
end)
