--[[
    重型钓鱼 自动钓鱼 v1.5
    修复: FishingMinigame 参数改为表 {1}/{2}（关键修复！）
    扫描证实: FireServer({1}) 成功, FireServer(1) 失败
--]]

print("[钓鱼] v1.5 加载中...")

local P = game:GetService("Players")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")
local C = game:GetService("CoreGui")

local LP = P.LocalPlayer
if not LP then return end

for _, g in ipairs(C:GetChildren()) do
    if g:IsA("ScreenGui") and (g.Name == "A" or g.Name:find("Fishing") or g.Name == "WindUI") then
        pcall(function() g:Destroy() end)
    end
end

local WI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
if not WI then print("[钓鱼] WindUI 失败"); return end
print("[钓鱼] WindUI OK")

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

print("[钓鱼] EquipRod=" .. (EquipRod and "OK" or "NIL"))
print("[钓鱼] Fishing=" .. (Fishing and "OK" or "NIL"))
print("[钓鱼] Minigame=" .. (FishingMinigame and "OK" or "NIL"))

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

local function getBattleUI()
    local pg = LP:FindFirstChild("PlayerGui")
    local mainGui = pg and pg:FindFirstChild("MainGui")
    local fishing = mainGui and mainGui:FindFirstChild("Fishing")
    if not fishing or not fishing.Visible then return nil end
    local barFrame = fishing:FindFirstChild("BarFrame")
    local bar = barFrame and barFrame:FindFirstChild("Bar")
    local progBarFrame = fishing:FindFirstChild("ProgressionBar")
    local progBar = progBarFrame and progBarFrame:FindFirstChild("Bar")
    return {Fishing = fishing, Bar = bar, ProgBar = progBar}
end

local function isFishBiting()
    local pg = LP:FindFirstChild("PlayerGui")
    local mainGui = pg and pg:FindFirstChild("MainGui")
    local fishing = mainGui and mainGui:FindFirstChild("Fishing")
    return fishing and fishing.Visible == true
end

-- ============ 战斗 - 关键修复 ============
-- 扫描证实: FishingMinigame:FireServer({1}) 成功, FireServer(1) 失败
-- 参数必须包装为表！
local function doBattle()
    if not S.AutoBattle or not FishingMinigame then return end
    local ui = getBattleUI()
    if not ui then
        if inBattle then
            print("[战斗] 战斗结束")
            inBattle = false
            wait(0.3)
            if CatchEvent then
                pcall(function() CatchEvent:FireServer() end)
                fishCount = fishCount + 1
                print("[钓鱼] 捕鱼成功！总数: " .. fishCount)
                if S.AutoSell and SellFish then
                    wait(0.5)
                    pcall(function() SellFish:FireServer() end)
                    print("[钓鱼] 自动卖鱼")
                end
            end
        end
        return
    end
    if not inBattle then
        print("[战斗] 鱼上钩！开始战斗...")
        inBattle = true
    end
    local startTime = os.clock()
    local tickCount = 0
    while ui and S.AutoBattle do
        tickCount = tickCount + 1
        local action = 1
        if ui.Bar then
            local barPos = ui.Bar.Position.Y.Scale
            if barPos > 0.6 then action = 2
            elseif barPos < 0.4 then action = 1
            else action = tickCount % 2 + 1 end
        end
        -- 关键修复：传表 {1} 而不是裸数字 1
        pcall(function() FishingMinigame:FireServer({action}) end)
        if tickCount % 8 == 0 and TriggerSkill then
            pcall(function() TriggerSkill:FireServer({1}) end)
        end
        wait(S.BattleSpeed)
        if os.clock() - startTime > 60 then break end
        ui = getBattleUI()
    end
    if inBattle then
        print("[战斗] 鱼已捕获/逃脱")
        inBattle = false
        wait(0.3)
        if CatchEvent then
            pcall(function() CatchEvent:FireServer() end)
            fishCount = fishCount + 1
            print("[钓鱼] 捕鱼成功！总数: " .. fishCount)
        end
    end
end

local function equipRod()
    if not EquipRod then return false end
    local ok = pcall(function() EquipRod:InvokeServer("Fishing Rod") end)
    print("[钓鱼] 装备鱼竿: " .. tostring(ok))
    return ok
end

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

local function doAutoFish()
    if not S.AutoFish then return end
    if isFishBiting() then doBattle(); return end
    local hrp = getHRP()
    if hrp then cast() end
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
    CT.AutoBattle=t1:Toggle({Flag="AutoBattle", Title="自动战斗({1}/{2}修复版)", Value=true, Callback=function(v) S.AutoBattle=v end})
    t1:Space()
    CT.EquipRodBtn=t1:Button({Title="装备鱼竿", Icon="solar:fishing-bold", Justify="Center", Color=Color3.fromHex("#305dff"), Callback=function() equipRod() end})
    t1:Space()
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
    t6:Paragraph({Title="重型钓鱼 v1.5"}); t6:Divider()
    t6:Paragraph({Title="作者", Desc="b站英吉利超入_"})
    t6:Paragraph({Title="功能", Desc="修复: Minigame参数{1}{2} / 读Bar智能战斗"})
    return sFish
end

-- ============ 主循环 ============
pcall(function() WI:SetTheme("Dark") end)
S.ParticleColor = tc("Dark")

local PP = false
WI:Popup({
    Title="重型钓鱼 v1.5",
    Content="修复: FishingMinigame参数{1}{2} 读Bar智能战斗",
    Buttons={
        {Title="加载", Callback=function() PP=true end, Variant="Primary"},
        {Title="取消", Callback=function() return end}
    }
})
while not PP do wait(0.1) end

spawn(function()
    local sFish = mW()
    print("[钓鱼] v1.5 开始运行")
    local last = os.clock()
    while true do
        if S.AutoFish then
            if isFishBiting() then
                doBattle()
            else
                if not inBattle then cast() end
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
