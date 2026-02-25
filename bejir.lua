--[[
    SAMBUNG KATA PRO v16.0
    Beverly Hub — Safe Backspace + Failchecks
]]--=============================================================================
-- ANTI-DUPLICATION / RE-EXECUTION SAFEGUARD
--=============================================================================
if _G.BeverlyHubUnload then
    pcall(function() _G.BeverlyHubUnload() end)
end

-- LOAD WIND UI
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Services = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    CoreGui = game:GetService("CoreGui"),
    RunService = game:GetService("RunService")
}

local LocalPlayer = Services.Players.LocalPlayer

local State = {
    IsRunning = true,
    AutoEnabled = false,
    AutoBlacklist = true,
    UsedWords = {},
    RejectedWords = {},
    Index = {},
    GlobalDict = {},
    ActiveTask = false,
    IsBackspacing = false,           -- NEW: guard against overlapping backspace
    HasSubmitted = false,            -- NEW: true only after actual submit
    SubmitPending = false,           -- NEW: waiting for server response
    BlatantEnabled = false,          -- NEW: instant submit mode
    BlatantDelay = 0.0,              -- NEW: delay between instant submits
    BlatantPredict = false,          -- NEW: predict next turn and bypass animation
    CurrentSoal = "",
    LastWordAttempted = "",
    LastSubmitTime = 0,              -- will be set to tick() at Init()
    LockedWord = "",
    LockedPrefix = "",
    TotalWordsFound = 0,
    TotalCorrect = 0,
    TotalErrors = 0,
    ConsecutiveErrors = 0,
    TypingDelayMin = 0.45,
    TypingDelayMax = 0.95,
    ThinkDelayMin = 0.8,
    ThinkDelayMax = 2.5,
    WordPreference = "balanced",
    WordMode = "balanced",           -- NEW: umum / aneh / balanced
    PreferredLength = 0,
    BackspaceDelayMin = 0.03,
    BackspaceDelayMax = 0.09,
    CurrentTypedText = "",
    MatchRemoteConn = nil,           -- NEW: keep track of event conn for safe unload
}

-- Helper: get character safely
-- 1. LOAD KAMUS EXTERNAL
-- ═══════════════════════════════════════════════════════════════════════
local RAW_KAMUS = {}

local loadSuccess, loadError = pcall(function()
    RAW_KAMUS = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/bevankeren/sambung-kata/master/kamus_lengkap.lua"
    ))()
end)

if not loadSuccess then
    WindUI:Notify({
        Title = "Kamus Error",
        Content = "Gagal load kamus external: " .. tostring(loadError),
        Duration = 5,
    })
    RAW_KAMUS = {
        ["a"]={"aku","ada","apa","asal","aman"},
        ["b"]={"bisa","baik","baru","buat"},
        ["c"]={"coba","cari","cara"},
        ["d"]={"dari","dan","dengan"},
    }
end

-- INDEXING
for key, wordList in pairs(RAW_KAMUS) do
    local validWords = {}
    for _, word in ipairs(wordList) do
        if #word >= 3 then
            table.insert(validWords, word)
            State.GlobalDict[word] = true
        end
    end
    table.sort(validWords, function(a, b) return #a < #b end)
    State.Index[key] = validWords
end

-- ═══════════════════════════════════════════════════════════════════════
-- 2. SMART LOGIC
-- ═══════════════════════════════════════════════════════════════════════

-- Cari kata dari kamus berdasarkan prefix
local function FindWord(prefix, forceNew)
    if not prefix or prefix == "" then return nil end
    
    if not forceNew and State.LockedPrefix == prefix and State.LockedWord ~= "" then
        if not State.UsedWords[State.LockedWord] then
            return State.LockedWord
        end
    end
    
    local bucket = State.Index[prefix:sub(1,1):lower()]
    if not bucket then return nil end
    
    local candidates = {}
    
    for _, word in ipairs(bucket) do
        if word:sub(1, #prefix) == prefix and not State.UsedWords[word] then
            table.insert(candidates, word)
        end
    end
    
    if #candidates > 0 then
        local selectedWord = nil
        
        -- Error recovery: setelah banyak error, pilih kata pendek
        if State.ConsecutiveErrors > 2 and State.PreferredLength > 0 then
            for _, word in ipairs(candidates) do
                if #word <= State.PreferredLength + 2 then
                    selectedWord = word
                    break
                end
            end
        end
        
        -- WORD MODE LOGIC
        if not selectedWord then
            if State.WordMode == "umum" then
                -- Pilih kata pendek (umum/sering didengar) — ambil dari awal list (sudah di-sort by length)
                local maxIdx = math.min(math.ceil(#candidates * 0.3), #candidates)
                maxIdx = math.max(1, maxIdx)
                selectedWord = candidates[math.random(1, maxIdx)]
                
            elseif State.WordMode == "aneh" then
                -- Pilih kata panjang (jarang didengar) — ambil dari akhir list
                local startIdx = math.max(math.floor(#candidates * 0.7), 1)
                selectedWord = candidates[math.random(startIdx, #candidates)]
                
            else -- balanced
                local midIdx = math.floor(#candidates / 2) + math.random(0, math.floor(#candidates / 2))
                midIdx = math.max(1, math.min(midIdx, #candidates))
                selectedWord = candidates[midIdx]
            end
        end
        
        if not selectedWord then
            selectedWord = candidates[1]
        end
        
        State.LockedWord = selectedWord
        State.LockedPrefix = prefix
        State.TotalWordsFound = State.TotalWordsFound + 1
        
        return selectedWord
    end
    
    State.LockedWord = ""
    State.LockedPrefix = ""
    return nil
end

-- Reset word lock
local function UnlockWord()
    State.LockedWord = ""
    State.LockedPrefix = ""
end

-- Scan kata yang sudah dipakai pemain lain
local function ScanForUsedWords(args)
    if not State.AutoBlacklist then return nil end
    local newlyFoundWord = nil
    for _, val in pairs(args) do
        if type(val) == "string" and #val > 2 then
            local clean = val:lower():gsub("%s+", "")
            if State.GlobalDict[clean] and not State.UsedWords[clean] then
                State.UsedWords[clean] = true
                -- We found a word that was just accepted by the server!
                newlyFoundWord = clean
            end
        end
    end
    return newlyFoundWord
end

-- Delay human-like dengan variasi
local function GetDelay()
    local baseDelay = State.TypingDelayMin + (math.random() * (State.TypingDelayMax - State.TypingDelayMin))
    if math.random() < 0.15 then
        baseDelay = baseDelay + math.random(5, 15) / 100
    end
    return baseDelay
end

-- Backspace natural: hapus teks satu huruf per waktu, berhenti di `stopAt` huruf
-- HANYA dipanggil setelah submit + rejection, TIDAK PERNAH saat sedang ngetik
local function BackspaceText(visualRemote, currentText, stopAt)
    -- FAILCHECK: jangan jalankan kalau sedang backspace / tidak ada teks / remote nil
    if State.BlatantEnabled then return end
    if State.IsBackspacing then return end
    if not currentText or currentText == "" then return end
    if not visualRemote then return end
    
    State.IsBackspacing = true
    stopAt = stopAt or 0
    
    for i = #currentText, stopAt + 1, -1 do
        -- FAILCHECK: berhenti kalau auto dimatikan atau prefix berubah (seseorang jawab duluan)
        if not State.AutoEnabled then 
            State.IsBackspacing = false
            return 
        end
        local partialText = currentText:sub(1, i - 1)
        pcall(function() visualRemote:FireServer(partialText) end)
        State.CurrentTypedText = partialText
        local bsDelay = State.BackspaceDelayMin + (math.random() * (State.BackspaceDelayMax - State.BackspaceDelayMin))
        task.wait(bsDelay)
    end
    State.IsBackspacing = false
end

-- EKSEKUSI UTAMA (REACTIVE LOOP)
local function ExecuteReactivePlay(word, prefixLen, submitRemote, visualRemote)
    -- FAILCHECK: jangan jalankan kalau sudah ada task aktif atau sedang backspace
    if State.BlatantEnabled then return end
    if State.ActiveTask then return end
    if State.IsBackspacing then return end
    if not word or word == "" then return end
    if not submitRemote or not visualRemote then return end
    
    State.ActiveTask = true
    State.HasSubmitted = false  -- reset: belum submit apa-apa
    
    local currentWord = word
    local currentPrefix = State.CurrentSoal
    
    -- FAILCHECK: pastikan kata dimulai dengan prefix yang benar
    if not currentWord:sub(1, #currentPrefix):lower() == currentPrefix:lower() then
        State.ActiveTask = false
        return
    end
    
    local think = State.ThinkDelayMin + (math.random() * (State.ThinkDelayMax - State.ThinkDelayMin))
    task.wait(think)
    
    -- FAILCHECK: re-check setelah think delay, mungkin prefix sudah berubah
    if State.CurrentSoal ~= currentPrefix then
        State.ActiveTask = false
        UnlockWord()
        return
    end
    
    local startIdx = prefixLen + 1
    if startIdx < 1 then startIdx = 1 end
    
    for i = startIdx, #currentWord do
        -- FAILCHECK: auto dimatikan
        if not State.AutoEnabled then 
            State.ActiveTask = false
            return 
        end
        
        -- FAILCHECK: sedang backspace, berhenti ngetik
        if State.IsBackspacing then
            State.ActiveTask = false
            return
        end
        
        -- Prefix berubah: langsung stop, TIDAK hapus teks
        if State.CurrentSoal ~= currentPrefix then
            State.ActiveTask = false
            UnlockWord()
            return
        end
        
        -- Kata sudah dipakai orang lain: cari kata baru, TIDAK hapus teks
        if State.UsedWords[currentWord] then
            UnlockWord()
            local retry = FindWord(State.CurrentSoal, true)
            if retry then
                State.ActiveTask = false
                task.spawn(function() ExecuteReactivePlay(retry, #State.CurrentSoal, submitRemote, visualRemote) end)
            else
                State.ActiveTask = false
            end
            return
        end
        
        -- Locked word berubah: switch ke word baru, TIDAK hapus teks
        if State.LockedWord ~= currentWord and State.LockedPrefix == currentPrefix then
            State.ActiveTask = false
            task.spawn(function() 
                ExecuteReactivePlay(State.LockedWord, #State.CurrentSoal, submitRemote, visualRemote) 
            end)
            return
        end

        -- Ketik huruf (dengan pcall untuk safety)
        local typed = currentWord:sub(1, i)
        pcall(function() visualRemote:FireServer(typed) end)
        State.CurrentTypedText = typed
        task.wait(GetDelay())
    end
    
    -- ═══ SUBMIT ═══
    -- FAILCHECK: triple-check sebelum submit
    task.wait(0.5)
    if not State.AutoEnabled then
        State.ActiveTask = false
        return
    end
    if State.CurrentSoal ~= currentPrefix then
        -- Prefix sudah berubah saat kita nunggu, jangan submit
        State.ActiveTask = false
        UnlockWord()
        return
    end
    if State.UsedWords[currentWord] then
        -- Kata tiba-tiba sudah terpakai (orang lain jawab duluan)
        State.ActiveTask = false
        UnlockWord()
        return
    end
    
    -- Semua check passed, aman untuk submit
    pcall(function() submitRemote:FireServer(currentWord) end)
    State.LastWordAttempted = currentWord
    State.LastSubmitTime = tick()
    State.HasSubmitted = true      -- BARU SET TRUE SETELAH BENAR-BENAR SUBMIT
    State.SubmitPending = true     -- Menunggu respons server
    State.UsedWords[currentWord] = true
    
    State.ActiveTask = false
end

-- ═══════════════════════════════════════════════════════════════════════
-- 3. UI CONSTRUCTION (WIND UI) — Beverly Hub V 1.0
-- ═══════════════════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title = "Beverly Hub  |  V 1.0",
    Icon = "solar:star-bold",
    Folder = "beverlyhub",
    NewElements = true,
    HideSearchBar = true,
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    },
    OpenButton = {
        Title = "✦ Beverly",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 0,
        Enabled = true,
        Draggable = true,
        Scale = 0.55,
        Color = ColorSequence.new(
            Color3.fromHex("#C084FC"),
            Color3.fromHex("#F472B6"),
            Color3.fromHex("#38BDF8")
        )
    },
})

-- INFO TAB (OPENS FIRST — disclaimer + developer info)
local InfoTab = Window:Tab({
    Title = "Info",
    Icon = "solar:info-circle-bold",
    IconColor = Color3.fromHex("#FBBF24"),
    IconShape = "Square",
    Border = true,
})

local DisclaimerSection = InfoTab:Section({
    Title = "⚠ DISCLAIMER",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

DisclaimerSection:Paragraph({
    Title = "Peringatan Penggunaan",
    Desc = "Jangan terlalu brutal menggunakan auto play.\n\nKalau mau aman, gunakan fitur KAMUS SAJA (panel saran kata di kanan layar) untuk memilih kata secara manual.\n\nAuto play hanya untuk bantuan, bukan untuk spam.\nGunakan dengan bijak agar tidak terdeteksi.",
})

DisclaimerSection:Space()

DisclaimerSection:Paragraph({
    Title = "Tips Aman",
    Desc = "• Gunakan delay tinggi (1-2 detik)\n• Jangan nyalakan auto play terus-menerus\n• Sesekali jawab manual lewat panel kamus\n• Pilih mode kata 'Umum' agar tidak mencurigakan",
})

local DevSection = InfoTab:Section({
    Title = "✦ Developer",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

DevSection:Paragraph({
    Title = "Beverly Hub V 1.0",
    Desc = "Sambung Kata Pro — Script otomatis untuk game Sambung Kata di Roblox.\n\nDibuat oleh: Beverly\nDiscord: (coming soon)\nUI Library: Wind UI by Footagesus",
})

DevSection:Space()

DevSection:Paragraph({
    Title = "Fitur",
    Desc = "• Auto Play dengan natural typing\n• 30.000+ kosa kata KBBI\n• Panel Saran Kata (manual pick)\n• Mode kata: Umum / Aneh / Balanced\n• Safe backspace (hanya setelah submit)\n• Anti-duplikat otomatis",
})

-- MAIN TAB
local MainTab = Window:Tab({
    Title = "Main",
    Icon = "solar:home-2-bold",
    IconColor = Color3.fromHex("#C084FC"),
    IconShape = "Square",
    Border = true,
})

local AutoSection = MainTab:Section({
    Title = "✦ Auto Play",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

-- Build the Unload Function to be registered globally
_G.BeverlyHubUnload = function()
    State.IsRunning = false
    MiscState.IsRunning = false
    if State.MatchRemoteConn then State.MatchRemoteConn:Disconnect() end
    if MiscState.HideIdentityConn then MiscState.HideIdentityConn:Disconnect() end
    if MiscState.NoclipConn then MiscState.NoclipConn:Disconnect() end
    if MiscState.FlyConn then MiscState.FlyConn:Disconnect() end
    if pcall(function() Window:Destroy() end) then end
    if pcall(function() if Services.CoreGui:FindFirstChild("BEV_Overlay") then Services.CoreGui.BEV_Overlay:Destroy() end end) then end
    _G.BeverlyHubUnload = nil
end

AutoSection:Toggle({
    Title = "Auto Play",
    Desc = "Otomatis jawab soal sambung kata\n⚙ Masih dalam perkembangan — gunakan dengan bijak",
    Default = false,
    Callback = function(v) State.AutoEnabled = v end
})

AutoSection:Space()

AutoSection:Toggle({
    Title = "Auto Blacklist",
    Desc = "Otomatis tandai kata yang sudah dipakai",
    Default = true,
    Callback = function(v) State.AutoBlacklist = v end
})

AutoSection:Space()

AutoSection:Dropdown({
    Title = "Mode Kata",
    Desc = "Pilih jenis kata yang digunakan",
    Multi = false,
    Value = "Balanced",
    Values = {"Umum", "Balanced", "Aneh"},
    Callback = function(v)
        State.WordMode = v:lower()
        UnlockWord()  -- reset agar kata berikutnya pakai mode baru
    end
})

-- SPEED TAB
local SpeedTab = Window:Tab({
    Title = "Kecepatan",
    Icon = "solar:alarm-bold",
    IconColor = Color3.fromHex("#F472B6"),
    IconShape = "Square",
    Border = true,
})

local TypingSection = SpeedTab:Section({
    Title = "Kecepatan Mengetik",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

TypingSection:Slider({
    Title = "Delay Minimum",
    Desc = "Delay tercepat antar huruf (detik)",
    IsTooltip = true,
    Step = 0.05,
    Value = { Min = 0.1, Max = 2.0, Default = 0.45 },
    Callback = function(v)
        State.TypingDelayMin = v
        if State.TypingDelayMin > State.TypingDelayMax then
            State.TypingDelayMax = State.TypingDelayMin
        end
    end
})

TypingSection:Space()

TypingSection:Slider({
    Title = "Delay Maksimum",
    Desc = "Delay terlama antar huruf (detik)",
    IsTooltip = true,
    Step = 0.05,
    Value = { Min = 0.1, Max = 3.0, Default = 0.95 },
    Callback = function(v)
        State.TypingDelayMax = v
        if State.TypingDelayMax < State.TypingDelayMin then
            State.TypingDelayMin = State.TypingDelayMax
        end
    end
})

TypingSection:Space()

TypingSection:Slider({
    Title = "Waktu Mikir",
    Desc = "Jeda sebelum mulai ngetik (detik)",
    IsTooltip = true,
    Step = 0.1,
    Value = { Min = 0.5, Max = 5.0, Default = 2.5 },
    Callback = function(v)
        State.ThinkDelayMax = v
        State.ThinkDelayMin = v * 0.4
    end
})

local BackspaceSection = SpeedTab:Section({
    Title = "Kecepatan Backspace",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

BackspaceSection:Slider({
    Title = "Backspace Speed",
    Desc = "Delay per huruf saat menghapus (detik)",
    IsTooltip = true,
    Step = 0.01,
    Value = { Min = 0.02, Max = 0.15, Default = 0.05 },
    Callback = function(v)
        State.BackspaceDelayMin = v * 0.6
        State.BackspaceDelayMax = v * 1.4
    end
})

-- ═══════════════════════════════════════════════════════════════════════
-- MISC TAB — Utility Features
-- ═══════════════════════════════════════════════════════════════════════
local MiscTab = Window:Tab({
    Title = "Misc",
    Icon = "solar:settings-bold",
    IconColor = Color3.fromHex("#34D399"),
    IconShape = "Square",
    Border = true,
})

-- Misc State
local MiscState = {
    FlyEnabled = false,
    FlySpeed = 50,
    FlyBody = nil,
    FlyGyro = nil,
    NoclipEnabled = false,
    NoclipConn = nil,
    InfJumpEnabled = false,
    InfJumpConn = nil,
    OriginalWalkSpeed = 16,
    OriginalJumpPower = 50,
    OriginalGravity = 196.2,
    OriginalDisplayName = LocalPlayer.DisplayName,
    HideIdentityConn = nil,
}

-- Helper: get character safely
local function GetCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ══ MOVEMENT SECTION ══
local MovementSection = MiscTab:Section({
    Title = "🏃 Movement",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

MovementSection:Slider({
    Title = "WalkSpeed",
    Desc = "Kecepatan jalan (default: 16)",
    IsTooltip = true,
    Step = 1,
    Value = { Min = 16, Max = 200, Default = 16 },
    Callback = function(v)
        pcall(function()
            local hum = GetHumanoid()
            if hum then hum.WalkSpeed = v end
        end)
    end
})

MovementSection:Space()

MovementSection:Slider({
    Title = "JumpPower",
    Desc = "Kekuatan lompat (default: 50)",
    IsTooltip = true,
    Step = 5,
    Value = { Min = 50, Max = 500, Default = 50 },
    Callback = function(v)
        pcall(function()
            local hum = GetHumanoid()
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = v
            end
        end)
    end
})

MovementSection:Space()

MovementSection:Toggle({
    Title = "Infinite Jump",
    Desc = "Lompat tanpa batas di udara",
    Default = false,
    Callback = function(v)
        MiscState.InfJumpEnabled = v
        if v then
            MiscState.InfJumpConn = game:GetService("UserInputService").JumpRequest:Connect(function()
                pcall(function()
                    local hum = GetHumanoid()
                    if hum and MiscState.InfJumpEnabled then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end)
            end)
        else
            if MiscState.InfJumpConn then
                MiscState.InfJumpConn:Disconnect()
                MiscState.InfJumpConn = nil
            end
        end
    end
})

-- ══ FLY SECTION ══
local FlySection = MiscTab:Section({
    Title = "✈ Fly",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

FlySection:Toggle({
    Title = "Fly",
    Desc = "Terbang bebas (WASD + Space/Shift)",
    Default = false,
    Callback = function(v)
        MiscState.FlyEnabled = v
        pcall(function()
            local rootPart = GetRootPart()
            local hum = GetHumanoid()
            if not rootPart or not hum then return end
            
            if v then
                -- Create fly bodies
                local bg = Instance.new("BodyGyro")
                bg.P = 9e4
                bg.D = 500
                bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                bg.CFrame = rootPart.CFrame
                bg.Parent = rootPart
                MiscState.FlyGyro = bg
                
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                bv.Velocity = Vector3.new(0, 0, 0)
                bv.Parent = rootPart
                MiscState.FlyBody = bv
                
                hum.PlatformStand = true
                
                -- Fly loop
                task.spawn(function()
                    local UIS = game:GetService("UserInputService")
                    local cam = workspace.CurrentCamera
                    while MiscState.FlyEnabled and MiscState.FlyBody and MiscState.FlyBody.Parent do
                        local dir = Vector3.new(0, 0, 0)
                        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
                        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
                        
                        if dir.Magnitude > 0 then
                            MiscState.FlyBody.Velocity = dir.Unit * MiscState.FlySpeed
                        else
                            MiscState.FlyBody.Velocity = Vector3.new(0, 0, 0)
                        end
                        MiscState.FlyGyro.CFrame = cam.CFrame
                        task.wait()
                    end
                end)
            else
                -- Cleanup
                if MiscState.FlyGyro then pcall(function() MiscState.FlyGyro:Destroy() end) MiscState.FlyGyro = nil end
                if MiscState.FlyBody then pcall(function() MiscState.FlyBody:Destroy() end) MiscState.FlyBody = nil end
                hum.PlatformStand = false
            end
        end)
    end
})

FlySection:Space()

FlySection:Slider({
    Title = "Fly Speed",
    Desc = "Kecepatan terbang",
    IsTooltip = true,
    Step = 5,
    Value = { Min = 10, Max = 300, Default = 50 },
    Callback = function(v) MiscState.FlySpeed = v end
})

-- ══ WORLD SECTION ══
local WorldSection = MiscTab:Section({
    Title = "🌍 World",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

WorldSection:Toggle({
    Title = "Noclip",
    Desc = "Tembus dinding dan objek",
    Default = false,
    Callback = function(v)
        MiscState.NoclipEnabled = v
        if v then
            MiscState.NoclipConn = Services.RunService.Stepped:Connect(function()
                pcall(function()
                    if not MiscState.NoclipEnabled then return end
                    local char = LocalPlayer.Character
                    if char then
                        for _, part in pairs(char:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end)
            end)
        else
            if MiscState.NoclipConn then
                MiscState.NoclipConn:Disconnect()
                MiscState.NoclipConn = nil
            end
            -- Restore collision
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = true
                        end
                    end
                end
            end)
        end
    end
})

WorldSection:Space()

WorldSection:Slider({
    Title = "Gravity",
    Desc = "Gravitasi dunia (default: 196.2)",
    IsTooltip = true,
    Step = 5,
    Value = { Min = 0, Max = 500, Default = 196 },
    Callback = function(v)
        pcall(function()
            workspace.Gravity = v
        end)
    end
})

WorldSection:Space()

WorldSection:Toggle({
    Title = "Hide Identity",
    Desc = "Samarkan nama karakter menjadi 'beverlyhub' (Client-side)",
    Default = false,
    Callback = function(v)
        if v then
            -- Enable Spoofing
            MiscState.HideIdentityConn = Services.RunService.Heartbeat:Connect(function()
                pcall(function()
                    local char = LocalPlayer.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum and hum.DisplayName ~= "beverlyhub" then
                            hum.DisplayName = "beverlyhub"
                        end
                        
                        -- Spoof custom nametags (BillboardGuis, etc)
                        for _, obj in pairs(char:GetDescendants()) do
                            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                                local text = obj.Text
                                if text:find(MiscState.OriginalDisplayName) or text:find(LocalPlayer.Name) then
                                    obj.Text = text:gsub(MiscState.OriginalDisplayName, "beverlyhub"):gsub(LocalPlayer.Name, "beverlyhub")
                                end
                            end
                        end
                    end
                end)
            end)
        else
            -- Disable Spoofing
            if MiscState.HideIdentityConn then
                MiscState.HideIdentityConn:Disconnect()
                MiscState.HideIdentityConn = nil
            end
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.DisplayName = MiscState.OriginalDisplayName
                    end
                    -- Attempt to restore some tags (though usually they reset on respawn anyway)
                    for _, obj in pairs(char:GetDescendants()) do
                        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                            if obj.Text:find("beverlyhub") then
                                obj.Text = obj.Text:gsub("beverlyhub", MiscState.OriginalDisplayName)
                            end
                        end
                    end
                end
            end)
        end
    end
})

WorldSection:Space()

WorldSection:Button({
    Title = "Rejoin Same Server",
    Desc = "Keluar dan masuk kembali ke server ini",
    Callback = function()
        pcall(function()
            WindUI:Notify({Title = "Rejoin", Content = "Sedang mencoba rejoin ke server ini...", Duration = 3})
            
            local ts = game:GetService("TeleportService")
            local p = game:GetService("Players").LocalPlayer
            
            -- Try method 1: specific to this job ID (works but sometimes blocked by some games)
            pcall(function()
                ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
            end)
            
            -- Try method 2: fallback (just teleport to the place, Roblox often puts you back in same/new server)
            task.wait(1)
            pcall(function()
                ts:Teleport(game.PlaceId, p)
            end)
        end)
    end
})

-- ══ PERFORMANCE SECTION ══
local PerfSection = MiscTab:Section({
    Title = "⚡ Performance",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

PerfSection:Toggle({
    Title = "FPS Booster",
    Desc = "Hapus efek visual untuk naikkan FPS",
    Default = false,
    Callback = function(v)
        pcall(function()
            local lighting = game:GetService("Lighting")
            if v then
                -- Disable heavy effects
                for _, effect in pairs(lighting:GetChildren()) do
                    if effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or 
                       effect:IsA("BloomEffect") or effect:IsA("DepthOfFieldEffect") or
                       effect:IsA("ColorCorrectionEffect") then
                        effect.Enabled = false
                    end
                end
                -- Lower terrain detail
                pcall(function()
                    game:GetService("Terrain").WaterWaveSize = 0
                    game:GetService("Terrain").WaterWaveSpeed = 0
                    game:GetService("Terrain").WaterReflectance = 0
                    game:GetService("Terrain").WaterTransparency = 0
                end)
                -- Remove particles
                for _, v in pairs(workspace:GetDescendants()) do
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or 
                       v:IsA("Fire") or v:IsA("Sparkles") then
                        v.Enabled = false
                    end
                end
                
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            else
                -- Re-enable
                for _, effect in pairs(lighting:GetChildren()) do
                    if effect:IsA("PostEffect") then
                        effect.Enabled = true
                    end
                end
                for _, v in pairs(workspace:GetDescendants()) do
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or 
                       v:IsA("Fire") or v:IsA("Sparkles") then
                        v.Enabled = true
                    end
                end
                settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            end
        end)
    end
})



-- ═══════════════════════════════════════════════════════════════════════
-- BLATANT TAB — Auto Farm Money
-- ═══════════════════════════════════════════════════════════════════════
local BlatantTab = Window:Tab({
    Title = "Blatant",
    Icon = "solar:bolt-circle-bold",
    IconColor = Color3.fromHex("#EF4444"),
    IconShape = "Square",
    Border = true,
})

local FarmSection = BlatantTab:Section({
    Title = "💰 Auto Farm Money",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

FarmSection:Paragraph({
    Title = "⚠ Peringatan",
    Desc = "Fitur ini SANGAT BLATANT dan mudah terlihat.\n\nUntuk hasil maksimal & aman:\n• Gunakan 2 akun di 1 meja (private server)\n• Akun utama farm, akun ke-2 sebagai partner\n• Jangan gunakan di server publik yang ramai\n• Kata langsung di-submit tanpa animasi ketik",
})

FarmSection:Space()

FarmSection:Toggle({
    Title = "Auto Farm",
    Desc = "Langsung jawab instan tanpa proses mengetik.\nHarus pakai 2 akun dalam 1 meja agar maksimal.",
    Default = false,
    Callback = function(v)
        State.BlatantEnabled = v
        if v then
            -- Matikan auto play biasa kalau blatant aktif
            State.AutoEnabled = false
            WindUI:Notify({
                Title = "💰 Auto Farm ON",
                Content = "Mode blatant aktif! Jawaban akan di-submit instan.",
                Duration = 3,
            })
        end
    end
})

FarmSection:Space()

FarmSection:Slider({
    Title = "Submit Delay",
    Desc = "Jeda sebelum submit instan (detik)",
    IsTooltip = true,
    Step = 0.05,
    Value = { Min = 0.0, Max = 1.0, Default = 0.0 },
    Callback = function(v)
        State.BlatantDelay = v
    end
})

FarmSection:Space()

FarmSection:Toggle({
    Title = "Predictive Spam",
    Desc = "LEWATI ANIMASI SERVER!\nLgsg nebak huruf selanjutnya detik itu juga.\nBisa bikin 0.0 detik delay total.",
    Default = false,
    Callback = function(v)
        State.BlatantPredict = v
    end
})

FarmSection:Space()

FarmSection:Dropdown({
    Title = "Farm Mode Kata",
    Desc = "Pilih kata untuk farm",
    Multi = false,
    Value = "Terpendek",
    Values = {"Terpendek", "Random", "Terpanjang"},
    Callback = function(v)
        if v == "Terpendek" then
            State.WordMode = "umum"
        elseif v == "Terpanjang" then
            State.WordMode = "aneh"
        else
            State.WordMode = "balanced"
        end
        UnlockWord()
    end
})

-- SARAN KATA OVERLAY (Optimized)
local OverlayScroll
local OverlayTitle
local OverlayCounter

local function CreateOverlay()
    pcall(function() if Services.CoreGui:FindFirstChild("BEV_Overlay") then Services.CoreGui.BEV_Overlay:Destroy() end end)
    local Screen = Instance.new("ScreenGui", Services.CoreGui) Screen.Name = "BEV_Overlay"
    local Frame = Instance.new("Frame", Screen)
    Frame.Size = UDim2.new(0, 230, 0, 340)
    Frame.Position = UDim2.new(0.81, 0, 0.22, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(14, 10, 22)
    Frame.BackgroundTransparency = 0.05
    Frame.Active = true; Frame.Draggable = true
    local corner = Instance.new("UICorner", Frame)
    corner.CornerRadius = UDim.new(0, 16)
    local stroke = Instance.new("UIStroke", Frame)
    stroke.Color = Color3.fromHex("#C084FC")
    stroke.Thickness = 2
    stroke.Transparency = 0.2

    -- Gradient header strip
    local headerBg = Instance.new("Frame", Frame)
    headerBg.Size = UDim2.new(1, 0, 0, 54)
    headerBg.BackgroundColor3 = Color3.fromHex("#1A0A2E")
    headerBg.BorderSizePixel = 0
    local headerCorner = Instance.new("UICorner", headerBg)
    headerCorner.CornerRadius = UDim.new(0, 16)
    local headerGrad = Instance.new("UIGradient", headerBg)
    headerGrad.Color = ColorSequence.new(Color3.fromHex("#C084FC"), Color3.fromHex("#F472B6"))
    headerGrad.Rotation = 90
    headerGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 0.9)})

    -- Title
    OverlayTitle = Instance.new("TextLabel", Frame)
    OverlayTitle.Size = UDim2.new(1, 0, 0, 30)
    OverlayTitle.Position = UDim2.new(0, 0, 0, 4)
    OverlayTitle.Text = "✦ SARAN KATA"
    OverlayTitle.TextColor3 = Color3.fromHex("#E9D5FF")
    OverlayTitle.BackgroundTransparency = 1
    OverlayTitle.Font = Enum.Font.GothamBold
    OverlayTitle.TextSize = 14

    -- Counter
    OverlayCounter = Instance.new("TextLabel", Frame)
    OverlayCounter.Size = UDim2.new(1, -16, 0, 18)
    OverlayCounter.Position = UDim2.new(0, 10, 0, 34)
    OverlayCounter.Text = "Menunggu soal..."
    OverlayCounter.TextColor3 = Color3.fromHex("#D8B4FE")
    OverlayCounter.BackgroundTransparency = 1
    OverlayCounter.Font = Enum.Font.Gotham
    OverlayCounter.TextSize = 11
    OverlayCounter.TextXAlignment = Enum.TextXAlignment.Left

    -- Separator
    local sep = Instance.new("Frame", Frame)
    sep.Size = UDim2.new(0.88, 0, 0, 1)
    sep.Position = UDim2.new(0.06, 0, 0, 56)
    sep.BackgroundColor3 = Color3.fromHex("#7C3AED")
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0

    -- Scroll
    OverlayScroll = Instance.new("ScrollingFrame", Frame)
    OverlayScroll.Size = UDim2.new(0.92, 0, 1, -62)
    OverlayScroll.Position = UDim2.new(0.04, 0, 0, 60)
    OverlayScroll.BackgroundTransparency = 1
    OverlayScroll.ScrollBarThickness = 3
    OverlayScroll.ScrollBarImageColor3 = Color3.fromHex("#C084FC")
    OverlayScroll.ScrollBarImageTransparency = 0.2
    local layout = Instance.new("UIListLayout", OverlayScroll)
    layout.Padding = UDim.new(0, 3)
end

local function UpdateOverlay(prefix, submitRemote)
    if not OverlayScroll then return end
    for _, v in pairs(OverlayScroll:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end
    
    local bucket = State.Index[prefix:sub(1,1):lower()] or {}
    local totalAvailable = 0
    local shown = 0
    local MAX_SHOWN = 20
    
    local candidates = {}
    -- Count total available and collect candidates
    for _, w in ipairs(bucket) do
        if w:sub(1, #prefix) == prefix and not State.UsedWords[w] then
            totalAvailable = totalAvailable + 1
            table.insert(candidates, w)
        end
    end
    
    -- Pick words that are "umum" (common lengths, usually 4-7 letters, not just the absolute shortest which might be weird acronyms)
    local selectedWords = {}
    if #candidates > 0 then
        -- Shuffle or pick from the first 30% of the list (which contains relatively short but real words)
        local maxIdx = math.min(math.ceil(#candidates * 0.3), #candidates)
        maxIdx = math.max(MAX_SHOWN, maxIdx) -- ensure we have enough to show
        
        local usedIndices = {}
        for i = 1, math.min(MAX_SHOWN, #candidates) do
            local attempts = 0
            local r
            repeat
                r = math.random(1, math.max(1, maxIdx))
                attempts = attempts + 1
            until not usedIndices[r] or attempts > 10
            
            usedIndices[r] = true
            table.insert(selectedWords, candidates[r])
        end
    end
    
    -- Update counter
    if OverlayCounter then
        OverlayCounter.Text = "Prefix: \"" .. prefix .. "\"  •  " .. totalAvailable .. " kata tersedia"
    end
    if OverlayTitle then
        OverlayTitle.Text = "📝 SARAN KATA [" .. totalAvailable .. "]"
    end
    
    -- Build buttons with alternating colors
    local colors = {
        Color3.fromHex("#1E1035"),
        Color3.fromHex("#1A1028"),
        Color3.fromHex("#1D0E30"),
    }
    local hoverColors = {
        Color3.fromHex("#4C1D95"),
        Color3.fromHex("#831843"),
        Color3.fromHex("#1E40AF"),
    }
    local accentColors = {
        Color3.fromHex("#C084FC"),
        Color3.fromHex("#F472B6"),
        Color3.fromHex("#38BDF8"),
    }
    for _, w in ipairs(selectedWords) do
        if shown >= MAX_SHOWN then break end
        if true then -- already filtered by prefix and used state
            local colorIdx = (shown % 3) + 1
            local btn = Instance.new("TextButton", OverlayScroll)
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3 = colors[colorIdx]
            btn.AutoButtonColor = false
            btn.Font = Enum.Font.GothamMedium
            btn.TextSize = 13
            btn.TextColor3 = Color3.fromHex("#E9D5FF")
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.Text = "  " .. w .. "  (" .. #w .. ")"
            local btnCorner = Instance.new("UICorner", btn)
            btnCorner.CornerRadius = UDim.new(0, 8)
            local btnStroke = Instance.new("UIStroke", btn)
            btnStroke.Color = accentColors[colorIdx]
            btnStroke.Thickness = 1
            btnStroke.Transparency = 0.7

            btn.MouseEnter:Connect(function()
                btn.BackgroundColor3 = hoverColors[colorIdx]
                btnStroke.Transparency = 0.1
            end)
            btn.MouseLeave:Connect(function()
                btn.BackgroundColor3 = colors[colorIdx]
                btnStroke.Transparency = 0.7
            end)
            btn.MouseButton1Click:Connect(function()
                submitRemote:FireServer(w)
                State.UsedWords[w] = true
                btn.BackgroundColor3 = Color3.fromHex("#7C3AED")
                btn.TextColor3 = Color3.fromHex("#F5F3FF")
                btn.Text = "  ✓ " .. w
                btnStroke.Color = Color3.fromHex("#C084FC")
                btnStroke.Transparency = 0
                task.delay(1, function()
                    if btn.Parent then btn:Destroy() end
                end)
            end)
            shown = shown + 1
        end
    end
    OverlayScroll.CanvasSize = UDim2.new(0, 0, 0, shown * 33)
end

-- ═══════════════════════════════════════════════════════════════════════
-- 4. MAIN LOOP
-- ═══════════════════════════════════════════════════════════════════════
local function Init()
    CreateOverlay()
    local MatchRemote = Services.ReplicatedStorage:FindFirstChild("MatchUI", true)
    local SubmitRemote = Services.ReplicatedStorage:FindFirstChild("SubmitWord", true)
    local VisualRemote = Services.ReplicatedStorage:FindFirstChild("BillboardUpdate", true)
    
    if not MatchRemote or not SubmitRemote then
        WindUI:Notify({Title = "Error", Content = "Remote tidak ditemukan!", Duration = 5})
        return
    end

    -- EVENT LISTENER
    State.MatchRemoteConn = MatchRemote.OnClientEvent:Connect(function(...)
        local args = {...}
        
        local newlyUsedWord = nil
        pcall(function() newlyUsedWord = ScanForUsedWords(args) end)
        
        -- PREDICTIVE BLATANT MODE
        -- Kalau ada kata yang baru masuk (berarti ada yang baru jawab bener), langsung tebak huruf ujungnya!
        if State.BlatantEnabled and State.BlatantPredict and newlyUsedWord then
            local predictedPrefix = newlyUsedWord:sub(-1)
            task.spawn(function()
                if State.BlatantDelay > 0 then task.wait(State.BlatantDelay) end
                local word = FindWord(predictedPrefix)
                if word and not State.UsedWords[word] then
                    -- Tembak peluru sebelum server ganti giliran!
                    pcall(function() VisualRemote:FireServer(word) end)
                    pcall(function() SubmitRemote:FireServer(word) end)
                    State.UsedWords[word] = true
                    State.LastWordAttempted = word
                    State.LastSubmitTime = tick()
                    State.HasSubmitted = true
                    State.SubmitPending = true
                    UnlockWord()
                end
            end)
        end
        
        if args[1] == "UpdateServerLetter" and args[2] then
            local letter = tostring(args[2]):lower()
            
            if State.CurrentSoal ~= letter then
                if State.LockedPrefix ~= letter then
                    UnlockWord()
                end
                
                -- Prefix berubah = jawaban sebelumnya diterima (atau orang lain jawab)
                if State.HasSubmitted and State.SubmitPending then
                    -- Jawaban BERHASIL! Prefix berubah berarti server menerima kata kita
                    State.TotalCorrect = State.TotalCorrect + 1
                    State.ConsecutiveErrors = 0
                end
                
                -- Reset semua state untuk soal baru
                State.CurrentSoal = letter
                State.ActiveTask = false
                State.IsBackspacing = false
                State.HasSubmitted = false
                State.SubmitPending = false
                State.CurrentTypedText = ""
                State.LastSubmitTime = tick()  -- reset timer agar watchdog tidak langsung fire
                
                if State.BlatantEnabled then
                    -- OPTIMIZATION: Submit langsung SEBELUM update UI karena UpdateOverlay bikin yield 0.1s
                    task.spawn(function()
                        if State.BlatantDelay > 0 then task.wait(State.BlatantDelay) end
                        -- Re-check prefix masih sama
                        if State.CurrentSoal == letter and State.BlatantEnabled then
                            local word = FindWord(letter)
                            if word and not State.UsedWords[word] then
                                pcall(function() VisualRemote:FireServer(word) end)
                                pcall(function() SubmitRemote:FireServer(word) end)
                                State.UsedWords[word] = true
                                State.LastWordAttempted = word
                                State.LastSubmitTime = tick()
                                State.HasSubmitted = true
                                State.SubmitPending = true
                                UnlockWord()
                            end
                        end
                    end)
                    
                    -- Update UI *setelah* submit terkirim ke server
                    pcall(function() UpdateOverlay(letter, SubmitRemote) end)
                    
                elseif State.AutoEnabled then
                    pcall(function() UpdateOverlay(letter, SubmitRemote) end)
                    local word = FindWord(letter)
                    if word then
                        task.spawn(function()
                            ExecuteReactivePlay(word, #State.CurrentSoal, SubmitRemote, VisualRemote)
                        end)
                    end
                else
                    -- Mode manual (auto/blatant mati)
                    pcall(function() UpdateOverlay(letter, SubmitRemote) end)
                end
            end
        end
    end)

    -- POST-SUBMIT WATCHDOG
    -- Menangani rejection untuk KEDUA mode: AutoPlay dan Blatant
    task.spawn(function()
        while State.IsRunning do
            task.wait(0.8)
            
            -- === BLATANT MODE WATCHDOG ===
            if State.BlatantEnabled 
                and State.HasSubmitted 
                and State.SubmitPending 
                and State.CurrentSoal ~= ""
                and (tick() - State.LastSubmitTime > 0.4)  -- 0.4 detik untuk blatant (sangat cepat retry)
            then
                -- Kata ditolak — langsung retry tanpa backspace
                State.TotalErrors = State.TotalErrors + 1
                State.ConsecutiveErrors = State.ConsecutiveErrors + 1
                
                if State.LastWordAttempted ~= "" then
                    State.RejectedWords[State.LastWordAttempted] = true
                    State.UsedWords[State.LastWordAttempted] = true
                end
                
                State.HasSubmitted = false
                State.SubmitPending = false
                UnlockWord()
                
                -- Langsung coba kata baru (instant submit)
                local retry = FindWord(State.CurrentSoal, true)
                if retry and not State.UsedWords[retry] then
                    if State.BlatantDelay > 0 then task.wait(State.BlatantDelay) end
                    if State.BlatantEnabled and State.CurrentSoal ~= "" then
                        pcall(function() VisualRemote:FireServer(retry) end)
                        pcall(function() SubmitRemote:FireServer(retry) end)
                        State.UsedWords[retry] = true
                        State.LastWordAttempted = retry
                        State.LastSubmitTime = tick()
                        State.HasSubmitted = true
                        State.SubmitPending = true
                        UnlockWord()
                    end
                else
                    -- Kehabisan kata, reset rejected dan coba lagi
                    State.RejectedWords = {}
                    State.LastSubmitTime = tick()
                end
            
            -- === AUTO PLAY MODE WATCHDOG ===
            elseif State.AutoEnabled 
                and State.HasSubmitted
                and State.SubmitPending
                and not State.ActiveTask
                and not State.IsBackspacing
                and State.CurrentSoal ~= ""
                and (tick() - State.LastSubmitTime > 5.0)
            then
                -- Kata ditolak server — backspace lalu retry
                State.TotalErrors = State.TotalErrors + 1
                State.ConsecutiveErrors = State.ConsecutiveErrors + 1
                
                if State.LastWordAttempted ~= "" then
                    State.RejectedWords[State.LastWordAttempted] = true
                    State.UsedWords[State.LastWordAttempted] = true
                end
                
                State.HasSubmitted = false
                State.SubmitPending = false
                
                -- Backspace: hapus hanya sampai prefix, sisakan prefix
                task.wait(0.3)
                if State.CurrentTypedText ~= "" and VisualRemote then
                    BackspaceText(VisualRemote, State.CurrentTypedText, #State.CurrentSoal)
                end
                
                UnlockWord()
                
                -- Coba kata baru
                local retry = FindWord(State.CurrentSoal, true)
                if retry then
                    State.ActiveTask = false
                    ExecuteReactivePlay(retry, #State.CurrentSoal, SubmitRemote, VisualRemote)
                else
                    State.ActiveTask = false
                    State.RejectedWords = {}
                end
                
                State.LastSubmitTime = tick()
            end
        end
    end)
    
    -- BLATANT IDLE DETECTOR
    -- Kalau blatant aktif tapi tidak ada submit dalam 0.5 detik dan tidak ada pending, coba submit
    task.spawn(function()
        while State.IsRunning do
            task.wait(0.5)
            if State.BlatantEnabled 
                and not State.HasSubmitted 
                and not State.SubmitPending 
                and State.CurrentSoal ~= ""
                and (tick() - State.LastSubmitTime > 0.5) 
            then
                -- Blatant idle — paksa submit
                local word = FindWord(State.CurrentSoal)
                if word and not State.UsedWords[word] then
                    if State.BlatantDelay > 0 then task.wait(State.BlatantDelay) end
                    if State.BlatantEnabled and State.CurrentSoal ~= "" then
                        pcall(function() VisualRemote:FireServer(word) end)
                        pcall(function() SubmitRemote:FireServer(word) end)
                        State.UsedWords[word] = true
                        State.LastWordAttempted = word
                        State.LastSubmitTime = tick()
                        State.HasSubmitted = true
                        State.SubmitPending = true
                        UnlockWord()
                    end
                end
            end
        end
    end)
    
    -- Initialize LastSubmitTime agar watchdog tidak langsung fire
    State.LastSubmitTime = tick()
    
    -- Hitung total kata di kamus
    local totalKata = 0
    for _, bucket in pairs(State.Index) do
        totalKata = totalKata + #bucket
    end
    
    WindUI:Notify({
        Title = "✦ Beverly Hub V 1.0",
        Content = "Loaded! Kamus: " .. tostring(loadSuccess and (totalKata .. " kata ✓") or "Fallback ⚠"),
        Icon = "solar:star-bold",
        Duration = 5,
    })
end

Init()