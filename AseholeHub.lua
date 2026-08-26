-- ============================================================
-- ASEHOLE HUB
-- Auto Use / Auto Prompts / Stamina Rest / Auto Eat
-- Anti Fatigue / Anti AFK / Stats / Discord Webhook
-- ============================================================

-- ============================
-- CONFIG
-- ============================
local OWNER_IDS = {
    10383321970,
}

local DEFAULT_TOOL_NAME = "Boxing Gloves"

local TARGET_STATS = {
    {Internal = "AG",            Display = "Agility"},
    {Internal = "BS",            Display = "Battle Sense"},
    {Internal = "BOUNTY",        Display = "Bounty"},
    {Internal = "DUR",           Display = "Durability"},
    {Internal = "EmployeeLevel", Display = "Employee Level"},
    {Internal = "FAT",           Display = "Fat"},
    {Internal = "height",        Display = "Height"},
    {Internal = "LM",            Display = "LM"},
    {Internal = "LMMEMORY",      Display = "LM Memory"},
    {Internal = "maxhp",         Display = "Max HP"},
    {Internal = "ST",            Display = "Stamina"},
    {Internal = "STR",           Display = "Strength"},
    {Internal = "TP",            Display = "Total Power"},
    {Internal = "UM",            Display = "UM"},
    {Internal = "UMMEMORY",      Display = "UM Memory"},
    {Internal = "WEIGHT",        Display = "Weight"},
}

local DEFAULT_STAT_REFRESH_RATE = 0.2
local AUTO_EAT_PERCENT = 10
local ANTI_FATIGUE_PERCENT = 90

-- ============================
-- SERVICES
-- ============================
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- ============================
-- OWNER CHECK
-- ============================
local function isOwner()
    for _, id in ipairs(OWNER_IDS) do
        if player.UserId == id then
            return true
        end
    end

    return false
end

if not isOwner() then
    return
end

-- ============================
-- GUI PATHS
-- ============================
local PlayerGui = player:WaitForChild("PlayerGui")
local HUD = PlayerGui:WaitForChild("HUD")

local Tabs = HUD:WaitForChild("Tabs")
local StatsChecker = Tabs:WaitForChild("StatsChecker")

local Bars = HUD:WaitForChild("Bars")
local MainHUD = Bars:WaitForChild("MainHUD")

local FatigueStaminaText =
    MainHUD:WaitForChild("FatigueStamina")

local HungerDisplayText =
    MainHUD:WaitForChild("HungerDisplay")

-- ============================
-- RAYFIELD
-- ============================
local Rayfield = loadstring(
    game:HttpGet("https://sirius.menu/rayfield")
)()

local Window = Rayfield:CreateWindow({
    Name = "Asehole hub",
    LoadingTitle = "Asehole hub",
    LoadingSubtitle = "Owner Utilities",

    ConfigurationSaving = {
        Enabled = false
    },
})

local AutoUseTab =
    Window:CreateTab("Auto Use", 4483362458)

local PromptTab =
    Window:CreateTab("Auto Prompts", 4483362458)

local StatsTab =
    Window:CreateTab("Stats", 4483362458)

local WebhookTab =
    Window:CreateTab("Webhook", 4483362458)

-- ============================================================
-- STATE
-- ============================================================

-- Auto Use
local autoUseEnabled = false
local targetToolName = DEFAULT_TOOL_NAME
local autoUseThread = nil

-- Prompts
local autoPromptEnabled = false
local autoKeyPromptEnabled = false
local autoDelayedKeyPromptEnabled = false
local delayedKeyPromptDelay = 0.8

-- Instant prompts
local instantHoldPromptsEnabled = false

local originalHoldDurations = setmetatable({}, {
    __mode = "k"
})

-- Stats
local statAutoRefreshEnabled = true
local statRefreshRate = DEFAULT_STAT_REFRESH_RATE

-- Stamina Rest
local autoStaminaRestEnabled = false
local staminaStopPercent = 30
local staminaResumePercent = 80
local staminaRestActive = false

-- Auto Eat
local autoEatEnabled = false
local customFoodNames = ""
local autoEatInProgress = false
local hungerLowHandled = false
local lastFoodAttempt = 0

-- Anti Fatigue
local antiFatigueEnabled = false
local antiFatigueActive = false
local lastSleepAttempt = 0

-- Anti AFK
local antiAfkEnabled = false

-- Discord
local discordFatigueAlertEnabled = false
local discordWebhookUrl = ""
local discordUserId = ""
local fatigueWebhookSent = false

-- Current HUD values
local currentStaminaPercent = nil
local currentFatiguePercent = nil
local currentHungerPercent = nil

-- Status
local AutoEatStatusText = "OFF"
local AntiFatigueStatusText = "OFF"

-- ============================================================
-- ANTI AFK
-- ============================================================
player.Idled:Connect(function()

    if not antiAfkEnabled then
        return
    end

    pcall(function()

        local camera = workspace.CurrentCamera

        if not camera then
            return
        end

        VirtualUser:CaptureController()

        VirtualUser:Button2Down(
            Vector2.new(0, 0),
            camera.CFrame
        )

        task.wait(0.1)

        VirtualUser:Button2Up(
            Vector2.new(0, 0),
            camera.CFrame
        )
    end)
end)

-- ============================================================
-- TOOL FUNCTIONS
-- ============================================================
local function findToolByName(name)

    if not name or name == "" then
        return nil
    end

    local wanted = string.lower(name)
    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")

    if character then
        for _, item in ipairs(character:GetChildren()) do
            if
                item:IsA("Tool")
                and string.lower(item.Name) == wanted
            then
                return item
            end
        end
    end

    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if
                item:IsA("Tool")
                and string.lower(item.Name) == wanted
            then
                return item
            end
        end
    end

    return nil
end

local function equipAndActivateTool(tool)

    if not tool then
        return false
    end

    local character = player.Character

    local humanoid =
        character
        and character:FindFirstChildOfClass("Humanoid")

    if not humanoid then
        return false
    end

    if tool.Parent ~= character then
        humanoid:EquipTool(tool)
        task.wait(0.12)
    end

    if tool.Parent ~= character then
        return false
    end

    tool:Activate()

    return true
end

local function useToolOnceByName(name)

    local tool = findToolByName(name)

    if not tool then
        return false
    end

    return equipAndActivateTool(tool)
end

-- ============================================================
-- MASTER AUTOMATION GATE
-- ============================================================
local function canRunAutomation()

    -- Highest priority
    if antiFatigueActive then
        return false
    end

    if autoEatInProgress then
        return false
    end

    if
        autoStaminaRestEnabled
        and staminaRestActive
    then
        return false
    end

    return true
end

-- ============================================================
-- AUTO USE
-- ============================================================
local function equipAndUseTargetTool()

    if not canRunAutomation() then
        return
    end

    local tool =
        findToolByName(targetToolName)

    if not tool then
        return
    end

    equipAndActivateTool(tool)
end

local function startAutoUse()

    if autoUseThread then
        return
    end

    autoUseThread = task.spawn(function()

        while autoUseEnabled do

            if canRunAutomation() then
                equipAndUseTargetTool()
            end

            task.wait(0.1)
        end

        autoUseThread = nil
    end)
end

local function stopAutoUse()
    autoUseEnabled = false
end

-- ============================================================
-- INSTANT PROXIMITY PROMPTS
-- ============================================================
local function makePromptInstant(prompt)

    if not prompt:IsA("ProximityPrompt") then
        return
    end

    if originalHoldDurations[prompt] == nil then
        originalHoldDurations[prompt] =
            prompt.HoldDuration
    end

    prompt.HoldDuration = 0
end

local function enableInstantPrompts()

    for _, obj in ipairs(
        workspace:GetDescendants()
    ) do

        if obj:IsA("ProximityPrompt") then
            makePromptInstant(obj)
        end
    end
end

local function disableInstantPrompts()

    for prompt, duration in pairs(
        originalHoldDurations
    ) do

        if prompt and prompt.Parent then
            prompt.HoldDuration = duration
        end
    end

    table.clear(originalHoldDurations)
end

workspace.DescendantAdded:Connect(function(obj)

    if
        instantHoldPromptsEnabled
        and obj:IsA("ProximityPrompt")
    then
        makePromptInstant(obj)
    end
end)

-- ============================================================
-- AUTO PROXIMITY PROMPTS
-- ============================================================
ProximityPromptService.PromptShown:Connect(function(prompt)

    if instantHoldPromptsEnabled then
        makePromptInstant(prompt)
    end

    if not autoPromptEnabled then
        return
    end

    if not canRunAutomation() then
        return
    end

    task.spawn(function()

        if not canRunAutomation() then
            return
        end

        local key =
            prompt.KeyboardKeyCode

        VirtualInputManager:SendKeyEvent(
            true,
            key,
            false,
            game
        )

        task.wait(
            prompt.HoldDuration + 0.05
        )

        VirtualInputManager:SendKeyEvent(
            false,
            key,
            false,
            game
        )
    end)
end)

-- ============================================================
-- CUSTOM GUI KEY PROMPTS
-- ============================================================
local watchedLabels = {}

local function getKeyCodeFromChar(char)

    char = string.upper(char)

    local success, key =
        pcall(function()
            return Enum.KeyCode[char]
        end)

    if success then
        return key
    end

    return nil
end

local function pressKey(key)

    if not canRunAutomation() then
        return
    end

    VirtualInputManager:SendKeyEvent(
        true,
        key,
        false,
        game
    )

    task.wait(0.08)

    VirtualInputManager:SendKeyEvent(
        false,
        key,
        false,
        game
    )
end

local function watchLabel(label)

    if watchedLabels[label] then
        return
    end

    watchedLabels[label] = true

    local function tryInstant()

        if not autoKeyPromptEnabled then
            return
        end

        if not canRunAutomation() then
            return
        end

        if not label.Visible then
            return
        end

        local text = label.Text

        if text and #text == 1 then

            local key =
                getKeyCodeFromChar(text)

            if key then
                task.spawn(
                    pressKey,
                    key
                )
            end
        end
    end

    local function tryDelayed()

        if not autoDelayedKeyPromptEnabled then
            return
        end

        if not canRunAutomation() then
            return
        end

        if not label.Visible then
            return
        end

        local text = label.Text

        if text and #text == 1 then

            local key =
                getKeyCodeFromChar(text)

            if key then

                task.spawn(function()

                    task.wait(
                        delayedKeyPromptDelay
                    )

                    if
                        autoDelayedKeyPromptEnabled
                        and canRunAutomation()
                        and label.Visible
                        and label.Text == text
                    then
                        pressKey(key)
                    end
                end)
            end
        end
    end

    label:GetPropertyChangedSignal(
        "Visible"
    ):Connect(function()
        tryInstant()
        tryDelayed()
    end)

    label:GetPropertyChangedSignal(
        "Text"
    ):Connect(function()
        tryInstant()
        tryDelayed()
    end)

    tryInstant()
    tryDelayed()
end

local function scanAndWatch(instance)

    for _, child in ipairs(
        instance:GetChildren()
    ) do

        if child:IsA("TextLabel") then
            watchLabel(child)
        end

        scanAndWatch(child)
    end
end

scanAndWatch(PlayerGui)

PlayerGui.DescendantAdded:Connect(function(obj)

    if obj:IsA("TextLabel") then
        watchLabel(obj)
    end
end)

-- ============================================================
-- TEXT UTILITIES
-- ============================================================
local function normalizeName(name)

    return string.lower(
        tostring(name):gsub(
            "[%s_%-%.]",
            ""
        )
    )
end

local function isTextObject(obj)

    return obj:IsA("TextLabel")
        or obj:IsA("TextButton")
        or obj:IsA("TextBox")
end

local function stripRichText(text)

    if not text then
        return ""
    end

    text = tostring(text)

    text = text:gsub(
        "<[^>]*>",
        ""
    )

    text = text:gsub(
        "[\n\r\t]",
        " "
    )

    return text
end

-- ============================================================
-- NORMAL STAT NUMBER PARSER
-- ============================================================
local function extractNumber(text)

    if not text then
        return nil
    end

    local clean =
        stripRichText(text)

    local valuePart =
        clean:match(
            ".*:%s*(.-)%s*$"
        )

    if
        not valuePart
        or valuePart == ""
    then
        valuePart = clean
    end

    local numberText, suffix =
        valuePart:match(
            "([%+%-]?%d[%d,]*%.?%d*)%s*([KkMmBbTt]?)"
        )

    if not numberText then
        return nil
    end

    numberText =
        numberText:gsub(",", "")

    local number =
        tonumber(numberText)

    if not number then
        return nil
    end

    suffix =
        string.upper(
            suffix or ""
        )

    if suffix == "K" then
        number = number * 1e3

    elseif suffix == "M" then
        number = number * 1e6

    elseif suffix == "B" then
        number = number * 1e9

    elseif suffix == "T" then
        number = number * 1e12
    end

    return number
end

-- ============================================================
-- STAMINA + FATIGUE PARSER
-- xx%(Fatigue : yy%)
-- ============================================================
local function extractStaminaAndFatigue(text)

    if not text then
        return nil, nil
    end

    local clean =
        stripRichText(text)

    local staminaText =
        clean:match(
            "([%d%.]+)%s*%%"
        )

    local fatigueText =
        string.lower(clean):match(
            "fatigue%s*:%s*([%d%.]+)%s*%%"
        )

    local stamina =
        staminaText
        and tonumber(staminaText)
        or nil

    local fatigue =
        fatigueText
        and tonumber(fatigueText)
        or nil

    return stamina, fatigue
end

-- ============================================================
-- HUNGER PARSER
-- ============================================================
local function extractHunger(text)

    if not text then
        return nil
    end

    local clean =
        stripRichText(text)

    local percentage =
        clean:match(
            "([%d%.]+)%s*%%"
        )

    if percentage then
        return tonumber(percentage)
    end

    return extractNumber(clean)
end

-- ============================================================
-- HUD VALUE TRACKING
-- ============================================================
local function updateHUDValues()

    if
        FatigueStaminaText
        and FatigueStaminaText.Parent
    then

        local stamina, fatigue =
            extractStaminaAndFatigue(
                FatigueStaminaText.Text
            )

        currentStaminaPercent = stamina
        currentFatiguePercent = fatigue

    else

        currentStaminaPercent = nil
        currentFatiguePercent = nil
    end

    if
        HungerDisplayText
        and HungerDisplayText.Parent
    then

        currentHungerPercent =
            extractHunger(
                HungerDisplayText.Text
            )

    else

        currentHungerPercent = nil
    end
end

-- ============================================================
-- FORMAT NUMBERS
-- ============================================================
local function formatNumber(number)

    if number == nil then
        return "N/A"
    end

    if math.abs(number) < 1000000 then

        if number % 1 == 0 then
            return tostring(number)
        end

        local text =
            string.format(
                "%.4f",
                number
            )

        text =
            text:gsub("0+$", "")

        text =
            text:gsub("%.$", "")

        return text
    end

    local absolute =
        math.abs(number)

    if absolute >= 1e12 then

        return string.format(
            "%.2fT",
            number / 1e12
        )

    elseif absolute >= 1e9 then

        return string.format(
            "%.2fB",
            number / 1e9
        )

    elseif absolute >= 1e6 then

        return string.format(
            "%.2fM",
            number / 1e6
        )
    end

    return tostring(number)
end

-- ============================================================
-- STAT TRACKER
-- ============================================================
local statLabels = {}
local cachedStatObjects = {}

for _, info in ipairs(
    TARGET_STATS
) do

    statLabels[info.Internal] =
        StatsTab:CreateLabel(
            info.Display
            .. ": Searching..."
        )
end

local StaminaPercentStatLabel =
    StatsTab:CreateLabel(
        "Stamina %: Searching..."
    )

local FatiguePercentStatLabel =
    StatsTab:CreateLabel(
        "Fatigue: Searching..."
    )

local HungerStatLabel =
    StatsTab:CreateLabel(
        "Hunger: Searching..."
    )

local function findStatObject(statName)

    local cached =
        cachedStatObjects[statName]

    if
        cached
        and cached.Parent
        and isTextObject(cached)
    then
        return cached
    end

    local target =
        normalizeName(statName)

    for _, obj in ipairs(
        StatsChecker:GetDescendants()
    ) do

        if
            isTextObject(obj)
            and normalizeName(obj.Name) == target
        then

            cachedStatObjects[statName] =
                obj

            return obj
        end
    end

    return nil
end

local function getStatValue(statName)

    local obj =
        findStatObject(statName)

    if not obj then
        return nil, nil
    end

    return
        extractNumber(obj.Text),
        obj.Text
end

local function refreshStats()

    for _, info in ipairs(
        TARGET_STATS
    ) do

        local value, raw =
            getStatValue(
                info.Internal
            )

        local label =
            statLabels[info.Internal]

        if value ~= nil then

            label:Set(
                info.Display
                .. ": "
                .. formatNumber(value)
            )

        elseif raw then

            label:Set(
                info.Display
                .. ": PARSE ERROR"
            )

        else

            label:Set(
                info.Display
                .. ": NOT FOUND"
            )
        end
    end

    updateHUDValues()

    if currentStaminaPercent ~= nil then

        StaminaPercentStatLabel:Set(
            "Stamina %: "
            .. formatNumber(
                currentStaminaPercent
            )
            .. "%"
        )

    else

        StaminaPercentStatLabel:Set(
            "Stamina %: NOT FOUND"
        )
    end

    if currentFatiguePercent ~= nil then

        FatiguePercentStatLabel:Set(
            "Fatigue: "
            .. formatNumber(
                currentFatiguePercent
            )
            .. "%"
        )

    else

        FatiguePercentStatLabel:Set(
            "Fatigue: NOT FOUND"
        )
    end

    if currentHungerPercent ~= nil then

        HungerStatLabel:Set(
            "Hunger: "
            .. formatNumber(
                currentHungerPercent
            )
            .. "%"
        )

    else

        HungerStatLabel:Set(
            "Hunger: NOT FOUND"
        )
    end
end

-- ============================================================
-- STAMINA REST
-- ============================================================
local function updateStaminaRest()

    if not autoStaminaRestEnabled then
        staminaRestActive = false
        return
    end

    if currentStaminaPercent == nil then
        return
    end

    if not staminaRestActive then

        if
            currentStaminaPercent
            <= staminaStopPercent
        then
            staminaRestActive = true
        end

    else

        if
            currentStaminaPercent
            >= staminaResumePercent
        then
            staminaRestActive = false
        end
    end
end

-- ============================================================
-- AUTO EAT
-- ============================================================
local function trim(text)

    return tostring(text):match(
        "^%s*(.-)%s*$"
    )
end

local function getFoodNames()

    local names = {
        "Steak",
        "Burger",
    }

    if customFoodNames ~= "" then

        for name in string.gmatch(
            customFoodNames,
            "([^,]+)"
        ) do

            name = trim(name)

            if name ~= "" then
                table.insert(
                    names,
                    name
                )
            end
        end
    end

    return names
end

local function findFood()

    for _, foodName in ipairs(
        getFoodNames()
    ) do

        local tool =
            findToolByName(foodName)

        if tool then
            return tool
        end
    end

    return nil
end

local function updateAutoEat()

    if not autoEatEnabled then

        autoEatInProgress = false
        hungerLowHandled = false
        AutoEatStatusText = "OFF"

        return
    end

    if currentHungerPercent == nil then

        AutoEatStatusText =
            "Hunger not found"

        return
    end

    if
        currentHungerPercent
        > AUTO_EAT_PERCENT
    then

        hungerLowHandled = false

        if not autoEatInProgress then
            AutoEatStatusText = "Ready"
        end

        return
    end

    if antiFatigueActive then

        AutoEatStatusText =
            "Waiting for fatigue"

        return
    end

    if hungerLowHandled then
        return
    end

    if autoEatInProgress then
        return
    end

    if
        os.clock() - lastFoodAttempt
        < 1
    then
        return
    end

    lastFoodAttempt = os.clock()

    local food = findFood()

    if not food then

        AutoEatStatusText =
            "No food found"

        return
    end

    autoEatInProgress = true

    AutoEatStatusText =
        "Eating " .. food.Name

    task.spawn(function()

        local success =
            equipAndActivateTool(food)

        if success then

            hungerLowHandled = true

            task.wait(0.5)

            AutoEatStatusText =
                "Food used"

        else

            AutoEatStatusText =
                "Failed to eat"
        end

        autoEatInProgress = false
    end)
end

-- ============================================================
-- DISCORD WEBHOOK
-- ============================================================

-- Executor HTTP request support
local requestFunction =
    (syn and syn.request)
    or http_request
    or request

local DiscordStatusLabel

local function buildDiscordStatFields()

    local fields = {}

    -- Player
    table.insert(fields, {
        name = "Player",
        value = tostring(player.Name),
        inline = true
    })

    -- HUD
    table.insert(fields, {
        name = "Stamina %",
        value =
            currentStaminaPercent ~= nil
            and (
                formatNumber(
                    currentStaminaPercent
                ) .. "%"
            )
            or "N/A",
        inline = true
    })

    table.insert(fields, {
        name = "Fatigue",
        value =
            currentFatiguePercent ~= nil
            and (
                formatNumber(
                    currentFatiguePercent
                ) .. "%"
            )
            or "N/A",
        inline = true
    })

    table.insert(fields, {
        name = "Hunger",
        value =
            currentHungerPercent ~= nil
            and (
                formatNumber(
                    currentHungerPercent
                ) .. "%"
            )
            or "N/A",
        inline = true
    })

    -- Every tracked character stat
    for _, info in ipairs(
        TARGET_STATS
    ) do

        local value =
            getStatValue(
                info.Internal
            )

        table.insert(fields, {
            name = info.Display,

            value =
                value ~= nil
                and formatNumber(value)
                or "N/A",

            inline = true
        })
    end

    return fields
end

local function sendDiscordWebhook(isTest)

    if discordWebhookUrl == "" then

        if DiscordStatusLabel then
            DiscordStatusLabel:Set(
                "Status: NO WEBHOOK URL"
            )
        end

        return false
    end

    if not requestFunction then

        if DiscordStatusLabel then
            DiscordStatusLabel:Set(
                "Status: HTTP REQUEST UNSUPPORTED"
            )
        end

        return false
    end

    updateHUDValues()

    if DiscordStatusLabel then
        DiscordStatusLabel:Set(
            "Status: SENDING..."
        )
    end

    task.spawn(function()

        local success, response =
            pcall(function()

                local mention = ""

                if discordUserId ~= "" then
                    mention =
                        "<@" .. discordUserId .. ">"
                end

                local title

                if isTest then
                    title =
                        "Webhook Test"
                else
                    title =
                        "Fatigue Alert"
                end

                local description

                if isTest then

                    description =
                        "Webhook connection test from Asehole hub."

                else

                    description =
                        "Fatigue has reached **"
                        .. formatNumber(
                            currentFatiguePercent or 0
                        )
                        .. "%**."
                end

                local payload = {
                    username =
                        "Asehole hub",

                    content =
                        mention,

                    embeds = {
                        {
                            title =
                                title,

                            description =
                                description,

                            fields =
                                buildDiscordStatFields(),

                            footer = {
                                text =
                                    "Asehole hub • Stat Monitor"
                            },

                            timestamp =
                                DateTime.now():ToIsoDate(),
                        }
                    },

                    -- Do not allow arbitrary @everyone etc.
                    allowed_mentions = {
                        parse = {}
                    }
                }

                -- Explicitly allow only the
                -- entered Discord account.
                if discordUserId ~= "" then

                    payload.allowed_mentions.users = {
                        discordUserId
                    }

                end

                return requestFunction({
                    Url =
                        discordWebhookUrl,

                    Method =
                        "POST",

                    Headers = {
                        ["Content-Type"] =
                            "application/json"
                    },

                    Body =
                        HttpService:JSONEncode(
                            payload
                        )
                })
            end)

        if success then

            if DiscordStatusLabel then
                DiscordStatusLabel:Set(
                    "Status: SENT"
                )
            end

        else

            warn(
                "[Asehole hub] Discord error:",
                response
            )

            if DiscordStatusLabel then
                DiscordStatusLabel:Set(
                    "Status: FAILED"
                )
            end
        end
    end)

    return true
end

-- ============================================================
-- ANTI FATIGUE + WEBHOOK TRIGGER
-- ============================================================
local function updateAntiFatigue()

    if currentFatiguePercent == nil then

        if antiFatigueEnabled then
            AntiFatigueStatusText =
                "Fatigue not found"
        end

        return
    end

    -- ============================
    -- DISCORD ALERT
    -- ============================

    if
        currentFatiguePercent
        >= ANTI_FATIGUE_PERCENT
    then

        if
            discordFatigueAlertEnabled
            and not fatigueWebhookSent
        then

            -- Lock BEFORE sending so the
            -- refresh loop cannot spam.
            fatigueWebhookSent = true

            local started =
                sendDiscordWebhook(false)

            -- If there was no URL/request support,
            -- allow another attempt later.
            if not started then
                fatigueWebhookSent = false
            end
        end

    else

        -- Rearm for next fatigue cycle.
        fatigueWebhookSent = false
    end

    -- ============================
    -- ANTI FATIGUE
    -- ============================

    if not antiFatigueEnabled then

        antiFatigueActive = false
        AntiFatigueStatusText = "OFF"

        return
    end

    if antiFatigueActive then

        if currentFatiguePercent <= 0 then

            antiFatigueActive = false

            AntiFatigueStatusText =
                "Recovered"

        else

            AntiFatigueStatusText =
                "Sleeping - "
                .. formatNumber(
                    currentFatiguePercent
                )
                .. "%"
        end

        return
    end

    if
        currentFatiguePercent
        >= ANTI_FATIGUE_PERCENT
    then

        if
            os.clock() - lastSleepAttempt
            < 1
        then
            return
        end

        lastSleepAttempt = os.clock()

        -- Pause everything immediately.
        antiFatigueActive = true

        AntiFatigueStatusText =
            "Using Sleeping Bag"

        local success =
            useToolOnceByName(
                "Sleeping Bag"
            )

        if not success then

            antiFatigueActive = false

            AntiFatigueStatusText =
                "Sleeping Bag not found"

        else

            AntiFatigueStatusText =
                "Sleeping"
        end

    else

        AntiFatigueStatusText =
            "Ready"
    end
end

-- ============================================================
-- AUTO USE TAB
-- ============================================================
AutoUseTab:CreateInput({
    Name = "Tool Name",

    PlaceholderText =
        "e.g. Boxing Gloves",

    RemoveTextAfterFocusLost =
        false,

    CurrentValue =
        DEFAULT_TOOL_NAME,

    Flag =
        "ToolNameInput",

    Callback = function(text)
        targetToolName =
            tostring(text or "")
    end,
})

AutoUseTab:CreateToggle({
    Name = "Auto Use Tool",

    CurrentValue = false,

    Flag =
        "AutoUseToggle",

    Callback = function(value)

        autoUseEnabled = value

        if value then
            startAutoUse()
        else
            stopAutoUse()
        end
    end,
})

AutoUseTab:CreateButton({
    Name = "Use Once",

    Callback = function()

        if canRunAutomation() then
            equipAndUseTargetTool()
        end
    end,
})

-- ============================================================
-- AUTO PROMPTS TAB
-- ============================================================
PromptTab:CreateToggle({
    Name = "Instant Hold Prompts",

    CurrentValue = false,

    Flag =
        "InstantHoldPrompts",

    Callback = function(value)

        instantHoldPromptsEnabled =
            value

        if value then
            enableInstantPrompts()
        else
            disableInstantPrompts()
        end
    end,
})

PromptTab:CreateToggle({
    Name =
        "Auto-Press ProximityPrompts",

    CurrentValue = false,

    Flag =
        "AutoPromptToggle",

    Callback = function(value)
        autoPromptEnabled = value
    end,
})

PromptTab:CreateToggle({
    Name =
        "Auto-Press Custom Key Prompts",

    CurrentValue = false,

    Flag =
        "AutoKeyPromptToggle",

    Callback = function(value)
        autoKeyPromptEnabled = value
    end,
})

PromptTab:CreateToggle({
    Name =
        "Auto-Press Delayed Key Prompts",

    CurrentValue = false,

    Flag =
        "AutoDelayedKeyPromptToggle",

    Callback = function(value)
        autoDelayedKeyPromptEnabled =
            value
    end,
})

PromptTab:CreateSlider({
    Name = "Delay Before Press",

    Range = {
        0.1,
        3
    },

    Increment = 0.1,

    Suffix = "s",

    CurrentValue = 0.8,

    Flag =
        "DelayedKeyPromptDelay",

    Callback = function(value)
        delayedKeyPromptDelay =
            value
    end,
})

-- ============================
-- AUTO STAMINA REST
-- ============================
PromptTab:CreateToggle({
    Name = "Auto Stamina Rest",

    CurrentValue = false,

    Flag =
        "AutoStaminaRest",

    Callback = function(value)

        autoStaminaRestEnabled =
            value

        if not value then
            staminaRestActive =
                false
        end
    end,
})

PromptTab:CreateSlider({
    Name =
        "Rest When Stamina Below",

    Range = {
        0,
        100
    },

    Increment = 1,

    Suffix = "%",

    CurrentValue = 30,

    Flag =
        "StaminaStopPercent",

    Callback = function(value)
        staminaStopPercent =
            value
    end,
})

PromptTab:CreateSlider({
    Name =
        "Resume When Stamina Reaches",

    Range = {
        0,
        100
    },

    Increment = 1,

    Suffix = "%",

    CurrentValue = 80,

    Flag =
        "StaminaResumePercent",

    Callback = function(value)
        staminaResumePercent =
            value
    end,
})

-- ============================
-- AUTO EAT
-- ============================
PromptTab:CreateToggle({
    Name = "Auto Eat",

    CurrentValue = false,

    Flag = "AutoEat",

    Callback = function(value)

        autoEatEnabled = value

        if not value then
            autoEatInProgress = false
            hungerLowHandled = false
        end
    end,
})

PromptTab:CreateInput({
    Name = "Custom Food Name",

    PlaceholderText =
        "Apple or Apple, Chicken",

    RemoveTextAfterFocusLost =
        false,

    CurrentValue = "",

    Flag =
        "CustomFoodName",

    Callback = function(text)
        customFoodNames =
            tostring(text or "")
    end,
})

PromptTab:CreateLabel(
    "Auto Eat activates at 10% hunger."
)

PromptTab:CreateLabel(
    "Default foods: Steak and Burger."
)

-- ============================
-- ANTI FATIGUE
-- ============================
PromptTab:CreateToggle({
    Name = "Anti Fatigue",

    CurrentValue = false,

    Flag =
        "AntiFatigue",

    Callback = function(value)

        antiFatigueEnabled =
            value

        if not value then
            antiFatigueActive =
                false
        end
    end,
})

PromptTab:CreateLabel(
    "Uses Sleeping Bag at 90% fatigue and resumes at 0%."
)

-- ============================
-- ANTI AFK
-- ============================
PromptTab:CreateToggle({
    Name = "Anti AFK",

    CurrentValue = false,

    Flag = "AntiAFK",

    Callback = function(value)
        antiAfkEnabled = value
    end,
})

-- ============================================================
-- PROMPT STATUS
-- ============================================================
local StaminaStatusLabel =
    PromptTab:CreateLabel(
        "Stamina: Searching..."
    )

local FatigueStatusLabel =
    PromptTab:CreateLabel(
        "Fatigue: Searching..."
    )

local HungerStatusLabel =
    PromptTab:CreateLabel(
        "Hunger: Searching..."
    )

local RestStatusLabel =
    PromptTab:CreateLabel(
        "Stamina Rest: OFF"
    )

local AutoEatStatusLabel =
    PromptTab:CreateLabel(
        "Auto Eat Status: OFF"
    )

local AntiFatigueStatusLabel =
    PromptTab:CreateLabel(
        "Anti Fatigue Status: OFF"
    )

local AntiAfkStatusLabel =
    PromptTab:CreateLabel(
        "Anti AFK Status: OFF"
    )

local AutomationStatusLabel =
    PromptTab:CreateLabel(
        "Automation: RUNNING"
    )

-- ============================================================
-- WEBHOOK TAB
-- ============================================================

WebhookTab:CreateLabel(
    "Discord Fatigue Notifications"
)

WebhookTab:CreateInput({
    Name = "Webhook URL",

    PlaceholderText =
        "Paste Discord webhook URL",

    RemoveTextAfterFocusLost =
        false,

    CurrentValue = "",

    Flag =
        "DiscordWebhookURL",

    Callback = function(text)

        discordWebhookUrl =
            tostring(text or "")
    end,
})

WebhookTab:CreateInput({
    Name = "Discord User ID",

    PlaceholderText =
        "e.g. 123456789012345678",

    RemoveTextAfterFocusLost =
        false,

    CurrentValue = "",

    Flag =
        "DiscordUserID",

    Callback = function(text)

        -- Discord IDs are numeric.
        discordUserId =
            tostring(text or "")
                :gsub("%D", "")
    end,
})

WebhookTab:CreateToggle({
    Name = "Fatigue Webhook Alert",

    CurrentValue = false,

    Flag =
        "DiscordFatigueAlert",

    Callback = function(value)

        discordFatigueAlertEnabled =
            value

        if not value then
            fatigueWebhookSent =
                false
        end
    end,
})

DiscordStatusLabel =
    WebhookTab:CreateLabel(
        "Status: OFF"
    )

WebhookTab:CreateLabel(
    "At 90% fatigue, one notification is sent."
)

WebhookTab:CreateLabel(
    "The alert contains every tracked stat."
)

WebhookTab:CreateLabel(
    "Enter your Discord User ID to be pinged."
)

WebhookTab:CreateButton({
    Name = "Send Test Webhook",

    Callback = function()

        sendDiscordWebhook(true)

    end,
})

-- ============================================================
-- STATS TAB
-- ============================================================
StatsTab:CreateToggle({
    Name = "Auto Refresh Stats",

    CurrentValue = true,

    Flag =
        "StatAutoRefresh",

    Callback = function(value)

        statAutoRefreshEnabled =
            value

        if value then
            refreshStats()
        end
    end,
})

StatsTab:CreateSlider({
    Name = "Stat Refresh Rate",

    Range = {
        0.1,
        2
    },

    Increment = 0.1,

    Suffix = "s",

    CurrentValue =
        DEFAULT_STAT_REFRESH_RATE,

    Flag =
        "StatRefreshRate",

    Callback = function(value)
        statRefreshRate = value
    end,
})

StatsTab:CreateButton({
    Name = "Refresh Stats Now",

    Callback = function()
        refreshStats()
    end,
})

StatsTab:CreateButton({
    Name = "Print HUD Values",

    Callback = function()

        updateHUDValues()

        print("")
        print("==============================")
        print("ASEHOLE HUB HUD DEBUG")
        print("==============================")

        print(
            "Stamina:",
            currentStaminaPercent
        )

        print(
            "Fatigue:",
            currentFatiguePercent
        )

        print(
            "Hunger:",
            currentHungerPercent
        )

        for _, info in ipairs(
            TARGET_STATS
        ) do

            local value =
                getStatValue(
                    info.Internal
                )

            print(
                info.Display,
                "=",
                value
            )
        end

        print("==============================")
        print("")
    end,
})

-- ============================================================
-- MAIN LOOP
-- ============================================================
task.spawn(function()

    while true do

        -- Always update these because
        -- automation relies on them.
        updateHUDValues()

        -- Stamina rest
        updateStaminaRest()

        -- Anti Fatigue also controls
        -- Discord fatigue notification.
        updateAntiFatigue()

        -- Auto Eat
        updateAutoEat()

        -- Stats
        if statAutoRefreshEnabled then
            refreshStats()
        end

        -- ============================
        -- STAMINA
        -- ============================
        if currentStaminaPercent ~= nil then

            StaminaStatusLabel:Set(
                "Stamina: "
                .. formatNumber(
                    currentStaminaPercent
                )
                .. "%"
            )

        else

            StaminaStatusLabel:Set(
                "Stamina: NOT FOUND"
            )
        end

        -- ============================
        -- FATIGUE
        -- ============================
        if currentFatiguePercent ~= nil then

            FatigueStatusLabel:Set(
                "Fatigue: "
                .. formatNumber(
                    currentFatiguePercent
                )
                .. "%"
            )

        else

            FatigueStatusLabel:Set(
                "Fatigue: NOT FOUND"
            )
        end

        -- ============================
        -- HUNGER
        -- ============================
        if currentHungerPercent ~= nil then

            HungerStatusLabel:Set(
                "Hunger: "
                .. formatNumber(
                    currentHungerPercent
                )
                .. "%"
            )

        else

            HungerStatusLabel:Set(
                "Hunger: NOT FOUND"
            )
        end

        -- ============================
        -- STAMINA REST STATUS
        -- ============================
        if not autoStaminaRestEnabled then

            RestStatusLabel:Set(
                "Stamina Rest: OFF"
            )

        elseif staminaRestActive then

            RestStatusLabel:Set(
                "Stamina Rest: RESTING"
            )

        else

            RestStatusLabel:Set(
                "Stamina Rest: ACTIVE"
            )
        end

        -- ============================
        -- AUTO EAT STATUS
        -- ============================
        AutoEatStatusLabel:Set(
            "Auto Eat Status: "
            .. AutoEatStatusText
        )

        -- ============================
        -- ANTI FATIGUE STATUS
        -- ============================
        AntiFatigueStatusLabel:Set(
            "Anti Fatigue Status: "
            .. AntiFatigueStatusText
        )

        -- ============================
        -- ANTI AFK
        -- ============================
        if antiAfkEnabled then

            AntiAfkStatusLabel:Set(
                "Anti AFK Status: ACTIVE"
            )

        else

            AntiAfkStatusLabel:Set(
                "Anti AFK Status: OFF"
            )
        end

        -- ============================
        -- WEBHOOK STATUS
        -- ============================
        if not discordFatigueAlertEnabled then

            DiscordStatusLabel:Set(
                "Status: OFF"
            )

        elseif discordWebhookUrl == "" then

            DiscordStatusLabel:Set(
                "Status: WAITING FOR WEBHOOK"
            )

        elseif discordUserId == "" then

            DiscordStatusLabel:Set(
                "Status: ARMED - NO PING ID"
            )

        elseif
            currentFatiguePercent
            and currentFatiguePercent
                >= ANTI_FATIGUE_PERCENT
            and fatigueWebhookSent
        then

            -- Do not overwrite SENT / FAILED
            -- while current fatigue event remains active.

        else

            DiscordStatusLabel:Set(
                "Status: ARMED"
            )
        end

        -- ============================
        -- MASTER AUTOMATION
        -- ============================
        if antiFatigueActive then

            AutomationStatusLabel:Set(
                "Automation: PAUSED - FATIGUE"
            )

        elseif autoEatInProgress then

            AutomationStatusLabel:Set(
                "Automation: PAUSED - EATING"
            )

        elseif
            autoStaminaRestEnabled
            and staminaRestActive
        then

            AutomationStatusLabel:Set(
                "Automation: PAUSED - STAMINA"
            )

        else

            AutomationStatusLabel:Set(
                "Automation: RUNNING"
            )
        end

        task.wait(
            statRefreshRate
        )
    end
end)

-- ============================================================
-- INITIAL UPDATE
-- ============================================================
task.wait(1)

updateHUDValues()
refreshStats()
