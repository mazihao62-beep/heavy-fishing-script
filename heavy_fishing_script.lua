--[[
    重型钓鱼 自动钓鱼 v1.7
    WindUI 模板
    核心：抛竿 → 鱼上钩 → 直接操控Bar(50%/50%) → 捕获 → 卖鱼
    新增：飞行（WASD+空格+Shift）+ 手动卖鱼按钮
--]]

print("[钓鱼] v1.7 加载中...")

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

local WI = loadstring(game:HttpGet("https://raw.githubusercontent.com/FootageSus/WindUI/main/dist/main.lua"))()
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

print("[钓鱼] EquipRod=" .. (EquipRod and "OK" or "NIL"))
print("[钓鱼] Fishing=" .. (Fishing and "OK" or "NIL"))
print("[钓鱼] Catch=" .. (CatchEvent and "OK" or "NIL"))
print("[钓鱼] SellFish=" .. (SellFish and "OK" or "NIL"))

local S = {
    AutoFish = false, AutoSell = false,
    Flight = false, FlightSpeed = 16,
    CastPower = 30, WaitTime = 8, FishRange = 50,
    Particles = true, Acrylic = true, Transparent = false,
    ParticleColor = Color3.fromRGB(30, 150, 255)
}
local KB = { Toggle = "RightShift" }
local WN, CT = nil, {}
local PR, PS, PC = false, {}, nil
local fishCount = 0
local inBattle = false
local flying = false
local bv, bg = nil, nil

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isFishBiting()
    local pg = LP:FindFirstChild("PlayerGui")
    local mainGui = pg and pg:FindFirstChild("MainGui")
    local fishing = mainGui and mainGui:FindFirstChild("Fishing")
    return fishing and fishing.Visible == true
end

-- ============ 战斗：直接操控Bar ============
local function doBattle()
    if not S.AutoFish then return end
    if not isFishBiting() then
        if inBattle then
            print("[战斗] 结束")
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
        print("[战斗] 鱼上钩！操控Bar...")
        inBattle = true
    end
    local startTime = os.clock()
    while os.clock() - startTime < 120 do
        local pg = LP:FindFirstChild("PlayerGui")
        local f = pg and pg:FindFirstChild("MainGui") and pg.MainGui:FindFirstChild("Fishing")
        if not f or not f.Visible then
            print("[战斗] 战斗结束 " .. math.floor(os.clock()-startTime) .. "秒")
            inBattle = false
            wait(0.3)
            if CatchEvent then
                pcall(function() CatchEvent:FireServer() end)
                fishCount = fishCount + 1
                print("[钓鱼] 捕鱼成功！总数: " .. fishCount)
                if S.AutoSell and SellFish then
                    wait(0.5)
                    pcall(function() SellFish:FireServer() end)
                end
            end
            return
        end
        pcall(function()
            local bf = f:FindFirstChild("BarFrame")
            if bf then
                local bar = bf:FindFirstChild("Bar")
                if bar then bar.Position = UDim2.new(0.5, 0, 0.5, 0) end
            end
        end)
        pcall(function()
            local pf = f:FindFirstChild("ProgressionBar")
            if pf then
                local bar = pf:FindFirstChild("Bar")
                if bar then bar.Size = UDim2.new(0.5, 0, 0, 0) end
            end
        end)
        wait(0.05)
    end
    print("[战斗] 超时")
    inBattle = false
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
    print("[钓鱼] 抛竿 " .. math.floor(target.X) .. "," .. math.floor(target.Z))
    return true
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
        OnClose=function() xP(); S.AutoFish=false; S.Flight=false
            if bv then pcall(function() bv:Destroy() end); bv=nil end
            if bg then pcall(function() bg:Destroy() end); bg=nil end
            for _,ct in pairs(CT) do
                if ct and type(ct.Set)=="function" then pcall(function() ct:Set(false) end) end
            end end,
        OnOpen=function() if S.Particles then sP() end end
    })
    spawn(function() wait(0.8) pcall(function() if WN and WN.Parent then WN.Parent.ClipsDescendants=true end end) end)

    local t1=WN:Tab({Title="主控面板", Icon="solar:slider-vertical-bold"})
    CT.AutoFish=t1:Toggle({Flag="AutoFish", Title="自动钓鱼+战斗", Value=false, Callback=function(v) S.AutoFish=v end})
    t1:Space()
    CT.EquipRodBtn=t1:Button({Title="装备鱼竿", Icon="solar:fishing-bold", Justify="Center", Color=Color3.fromHex("#305dff"), Callback=function() equipRod() end})
    t1:Space()
    CT.CastPower=t1:Slider({Flag="CastPower", Title="抛竿距离", Step=5, Value={Min=10,Max=100,Default=30}, Width=200, IsTextbox=true, Callback=function(v) S.CastPower=v end})
    CT.SellToggle=t1:Toggle({Flag="SellFish", Title="捕获后自动卖鱼", Value=false, Callback=function(v) S.AutoSell=v end})
    t1:Space()
    CT.SellBtn=t1:Button({Title="手动卖鱼", Icon="solar:cart-bold", Justify="Center", Color=Color3.fromHex("#FF6347"), Callback=function()
        if SellFish then
            pcall(function() SellFish:FireServer() end)
            print("[钓鱼] 手动卖鱼")
            WI:Notify({Title="卖鱼", Content="已出售", Duration=2, Icon="solar:cart-bold"})
        end
    end})

    local tFly=WN:Tab({Title="飞行", Icon="solar:rocket-bold"})
    CT.FlightToggle=tFly:Toggle({Flag="Flight", Title="飞行", Value=false, Callback=function(v)
        S.Flight=v
        if not v then
            flying=false
            if bv then pcall(function() bv:Destroy() end); bv=nil end
            if bg then pcall(function() bg:Destroy() end); bg=nil end
            local c=LP.Character
            if c then
                local hrp=c:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Velocity=Vector3.new(0,0,0) end
                local h=c:FindFirstChildOfClass("Humanoid")
                if h then h.PlatformStand=false end
            end
        end
    end})
    CT.FlightSpeed=tFly:Slider({Flag="FlightSpeed", Title="飞行速度", Step=1, Value={Min=5,Max=100,Default=16}, Width=200, IsTextbox=true, Callback=function(v) S.FlightSpeed=v end})

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
    t6:Paragraph({Title="重型钓鱼 v1.7"}); t6:Divider()
    t6:Paragraph({Title="作者", Desc="b站英吉利超入_"})
    t6:Paragraph({Title="功能", Desc="抛竿 -> 操控Bar(50%) -> 捕获 -> 卖鱼 + 飞行"})
    return sFish
end

-- ============ 启动 ============
pcall(function() WI:SetTheme("Dark") end)
S.ParticleColor = tc("Dark")
local PP = false
WI:Popup({
    Title="重型钓鱼 v1.7", Content="自动抛竿 + 操控Bar + 飞行",
    Buttons={{Title="加载", Callback=function() PP=true end, Variant="Primary"},{Title="取消", Callback=function() return end}}
})
while not PP do wait(0.1) end

-- ============ 主循环 ============
spawn(function()
    local sFish = mW()
    print("[钓鱼] v1.7 开始运行")
    local last = os.clock()
    while true do
        if S.AutoFish then
            if isFishBiting() then doBattle() else if not inBattle then cast() end; wait(S.WaitTime) end
        end
        if S.Flight and not flying then
            flying = true
            spawn(function()
                while S.Flight do
                    pcall(function()
                        local c = LP.Character
                        if not c then return end
                        local hrp = c:FindFirstChild("HumanoidRootPart")
                        if not hrp then return end
                        local h = c:FindFirstChildOfClass("Humanoid")
                        if h then h.PlatformStand = true end
                        if not bv or not bv.Parent then
                            bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(1,1,1) * 9e9
                            bv.P = 12500
                            bv.Parent = hrp
                        end
                        if not bg or not bg.Parent then
                            bg = Instance.new("BodyGyro")
                            bg.MaxTorque = Vector3.new(1,1,1) * 9e9
                            bg.P = 12500
                            bg.D = 500
                            bg.Parent = hrp
                        end
                        local cam = workspace.CurrentCamera
                        local mv = Vector3.new(0,0,0)
                        if UIS:IsKeyDown(Enum.KeyCode.W) then mv = mv + cam.CFrame.LookVector end
                        if UIS:IsKeyDown(Enum.KeyCode.S) then mv = mv - cam.CFrame.LookVector end
                        if UIS:IsKeyDown(Enum.KeyCode.A) then mv = mv - cam.CFrame.RightVector end
                        if UIS:IsKeyDown(Enum.KeyCode.D) then mv = mv + cam.CFrame.RightVector end
                        if UIS:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
                        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv = mv + Vector3.new(0,-1,0) end
                        if mv.Magnitude > 0 then mv = mv.Unit * S.FlightSpeed end
                        bv.Velocity = mv
                        bg.CFrame = cam.CFrame
                    end)
                    wait(0.03)
                end
                if bv then pcall(function() bv:Destroy() end); bv = nil end
                if bg then pcall(function() bg:Destroy() end); bg = nil end
                local c = LP.Character
                if c then
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if h then h.PlatformStand = false end
                end
                flying = false
            end)
        elseif not S.Flight and flying then
            flying = false
            if bv then pcall(function() bv:Destroy() end); bv = nil end
            if bg then pcall(function() bg:Destroy() end); bg = nil end
            local c = LP.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then h.PlatformStand = false end
            end
        end
        wait(0.3)
        if os.clock() - last > 5 then
            last = os.clock()
            if sFish then pcall(function() sFish:SetTitle("钓鱼次数: " .. fishCount) end) end
        end
    end
end)
