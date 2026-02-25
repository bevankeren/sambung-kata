--[[
    SAMBUNG KATA PRO v15.0
    Wind UI + External Kamus + Natural Backspace
]]

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
    CurrentSoal = "",
    LastWordAttempted = "",
    LastSubmitTime = 0,
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
    PreferredLength = 0,
    BackspaceDelayMin = 0.03,
    BackspaceDelayMax = 0.09,
    CurrentTypedText = "",
}

-- ═══════════════════════════════════════════════════════════════════════
-- 1. LOAD KAMUS EXTERNAL
-- ═══════════════════════════════════════════════════════════════════════
local RAW_KAMUS = {}

local loadSuccess, loadError = pcall(function()
    RAW_KAMUS = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/bevankeren/sambung-kata/master/kamus.lua"
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
        
        if State.ConsecutiveErrors > 2 and State.PreferredLength > 0 then
            for _, word in ipairs(candidates) do
                if #word <= State.PreferredLength + 2 then
                    selectedWord = word
                    break
                end
            end
        end
        
        if not selectedWord and State.WordPreference == "balanced" then
            local midIdx = math.floor(#candidates / 2) + math.random(0, math.floor(#candidates / 2))
            midIdx = math.max(1, math.min(midIdx, #candidates))
            selectedWord = candidates[midIdx]
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
    if not State.AutoBlacklist then return end
    for _, val in pairs(args) do
        if type(val) == "string" and #val > 2 then
            local clean = val:lower():gsub("%s+", "")
            if State.GlobalDict[clean] and not State.UsedWords[clean] then
                State.UsedWords[clean] = true
            end
        end
    end
end

-- Delay human-like dengan variasi
local function GetDelay()
    local baseDelay = State.TypingDelayMin + (math.random() * (State.TypingDelayMax - State.TypingDelayMin))
    if math.random() < 0.15 then
        baseDelay = baseDelay + math.random(5, 15) / 100
    end
    return baseDelay
end

-- Backspace natural: hapus teks satu huruf per waktu dengan delay
local function BackspaceText(visualRemote, currentText)
    if not currentText or currentText == "" then return end
    for i = #currentText, 1, -1 do
        if not State.AutoEnabled then return end
        local partialText = currentText:sub(1, i - 1)
        visualRemote:FireServer(partialText)
        State.CurrentTypedText = partialText
        local bsDelay = State.BackspaceDelayMin + (math.random() * (State.BackspaceDelayMax - State.BackspaceDelayMin))
        task.wait(bsDelay)
    end
end

-- EKSEKUSI UTAMA (REACTIVE LOOP)
local function ExecuteReactivePlay(word, prefixLen, submitRemote, visualRemote)
    if State.ActiveTask then return end
    State.ActiveTask = true
    
    local currentWord = word
    local currentPrefix = State.CurrentSoal
    
    local think = State.ThinkDelayMin + (math.random() * (State.ThinkDelayMax - State.ThinkDelayMin))
    task.wait(think)
    
    local startIdx = prefixLen + 1
    if startIdx < 1 then startIdx = 1 end
    
    for i = startIdx, #currentWord do
        if not State.AutoEnabled then State.ActiveTask = false; return end
        
        -- Prefix berubah: backspace dulu baru stop
        if State.CurrentSoal ~= currentPrefix then
            BackspaceText(visualRemote, State.CurrentTypedText)
            State.ActiveTask = false
            UnlockWord()
            return
        end
        
        -- Kata dipakai orang lain: backspace lalu retry
        if State.UsedWords[currentWord] then
            BackspaceText(visualRemote, State.CurrentTypedText)
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
        
        -- Locked word berubah: switch ke word baru
        if State.LockedWord ~= currentWord and State.LockedPrefix == currentPrefix then
            BackspaceText(visualRemote, State.CurrentTypedText)
            State.ActiveTask = false
            task.spawn(function() 
                ExecuteReactivePlay(State.LockedWord, #State.CurrentSoal, submitRemote, visualRemote) 
            end)
            return
        end

        -- Ketik huruf
        local typed = currentWord:sub(1, i)
        visualRemote:FireServer(typed)
        State.CurrentTypedText = typed
        task.wait(GetDelay())
    end
    
    -- SUBMIT
    task.wait(0.5)
    if State.AutoEnabled and State.CurrentSoal == currentPrefix then
        submitRemote:FireServer(currentWord)
        State.LastWordAttempted = currentWord
        State.LastSubmitTime = tick()
        State.UsedWords[currentWord] = true
        State.CurrentTypedText = ""
    end
    
    State.ActiveTask = false
end

-- ═══════════════════════════════════════════════════════════════════════
-- 3. UI CONSTRUCTION (WIND UI)
-- ═══════════════════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title = "Sambung Kata Pro",
    Icon = "solar:file-text-bold",
    Folder = "sambungkatapro",
    NewElements = true,
    HideSearchBar = true,
    Topbar = {
        Height = 44,
        ButtonsType = "Default",
    },
    OpenButton = {
        Title = "SKP",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        Scale = 0.5,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"), 
            Color3.fromHex("#00D4FF")
        )
    },
})

-- MAIN TAB
local MainTab = Window:Tab({
    Title = "Main",
    Icon = "solar:home-2-bold",
    IconColor = Color3.fromHex("#30FF6A"),
    IconShape = "Square",
    Border = true,
})

local AutoSection = MainTab:Section({
    Title = "Auto Play",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

AutoSection:Toggle({
    Title = "Auto Play",
    Desc = "Otomatis jawab soal sambung kata",
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

-- SPEED TAB
local SpeedTab = Window:Tab({
    Title = "Kecepatan",
    Icon = "solar:alarm-bold",
    IconColor = Color3.fromHex("#ECA201"),
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

-- SARAN KATA OVERLAY (manual GUI, bukan bagian WindUI)
local OverlayScroll

local function CreateOverlay()
    pcall(function() if Services.CoreGui:FindFirstChild("SKP_Overlay") then Services.CoreGui.SKP_Overlay:Destroy() end end)
    local Screen = Instance.new("ScreenGui", Services.CoreGui) Screen.Name = "SKP_Overlay"
    local Frame = Instance.new("Frame", Screen)
    Frame.Size = UDim2.new(0, 200, 0, 280)
    Frame.Position = UDim2.new(0.83, 0, 0.30, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Frame.BackgroundTransparency = 0.15
    Frame.Active = true; Frame.Draggable = true
    local corner = Instance.new("UICorner", Frame)
    corner.CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", Frame)
    stroke.Color = Color3.fromHex("#30FF6A")
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5
    
    local Title = Instance.new("TextLabel", Frame)
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.Text = "📝 SARAN KATA"
    Title.TextColor3 = Color3.fromHex("#30FF6A")
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    
    OverlayScroll = Instance.new("ScrollingFrame", Frame)
    OverlayScroll.Size = UDim2.new(0.9, 0, 0.84, 0)
    OverlayScroll.Position = UDim2.new(0.05, 0, 0.13, 0)
    OverlayScroll.BackgroundTransparency = 1
    OverlayScroll.ScrollBarThickness = 3
    OverlayScroll.ScrollBarImageColor3 = Color3.fromHex("#30FF6A")
    local layout = Instance.new("UIListLayout", OverlayScroll)
    layout.Padding = UDim.new(0, 4)
end

local function UpdateOverlay(prefix, submitRemote)
    if not OverlayScroll then return end
    for _, v in pairs(OverlayScroll:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end
    
    local bucket = State.Index[prefix:sub(1,1):lower()] or {}
    local count = 0
    for _, w in ipairs(bucket) do
        if count >= 12 then break end
        if w:sub(1, #prefix) == prefix and not State.UsedWords[w] then
            local btn = Instance.new("TextButton", OverlayScroll)
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.Text = "  " .. w
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            btn.TextColor3 = Color3.fromRGB(220, 220, 230)
            btn.Font = Enum.Font.GothamMedium
            btn.TextSize = 13
            local btnCorner = Instance.new("UICorner", btn)
            btnCorner.CornerRadius = UDim.new(0, 8)
            btn.MouseButton1Click:Connect(function()
                submitRemote:FireServer(w)
                State.UsedWords[w] = true
                btn.BackgroundColor3 = Color3.fromHex("#30FF6A")
                btn.TextColor3 = Color3.fromRGB(15, 15, 20)
            end)
            count = count + 1
        end
    end
    OverlayScroll.CanvasSize = UDim2.new(0, 0, 0, count * 32)
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
    MatchRemote.OnClientEvent:Connect(function(...)
        local args = {...}
        ScanForUsedWords(args)
        
        if args[1] == "UpdateServerLetter" and args[2] then
            local letter = tostring(args[2]):lower()
            
            if State.CurrentSoal ~= letter then
                if State.LockedPrefix ~= letter then
                    UnlockWord()
                end
                
                State.CurrentSoal = letter
                State.ActiveTask = false
                State.ConsecutiveErrors = 0
                State.TotalCorrect = State.TotalCorrect + 1
                State.CurrentTypedText = ""
                UpdateOverlay(letter, SubmitRemote)
                
                if State.AutoEnabled then
                    local word = FindWord(letter)
                    if word then
                        task.spawn(function()
                            ExecuteReactivePlay(word, #State.CurrentSoal, SubmitRemote, VisualRemote)
                        end)
                    end
                end
            end
        end
    end)

    -- POST-SUBMIT WATCHDOG
    task.spawn(function()
        while State.IsRunning do
            task.wait(0.5)
            if State.AutoEnabled and not State.ActiveTask and State.CurrentSoal ~= "" and tick() - State.LastSubmitTime > 3.0 then
                
                State.TotalErrors = State.TotalErrors + 1
                State.ConsecutiveErrors = State.ConsecutiveErrors + 1
                State.RejectedWords[State.LastWordAttempted] = true
                State.UsedWords[State.LastWordAttempted] = true
                State.ActiveTask = true
                
                task.wait(0.2)
                UnlockWord()
                
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
    
    WindUI:Notify({
        Title = "Sambung Kata Pro",
        Content = "v15.0 loaded! Kamus: " .. tostring(loadSuccess and "Online ✓" or "Fallback ⚠"),
        Icon = "solar:check-square-bold",
        Duration = 5,
    })
end

Init()