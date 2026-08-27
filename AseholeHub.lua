-- ============================================================
-- ASEHOLE HUB v1.2.2
-- ============================================================

-- ============================
-- CONFIG
-- ============================

local HUB_VERSION = "1.2.2"

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
local AUTO_EAT_TARGET_PERCENT = 100
local FOOD_CONFIRM_TIMEOUT = 5
local MAX_FOOD_CONFIRM_FAILURES = 3

local ANTI_FATIGUE_PERCENT = 90

-- NEW:
local ANTI_FATIGUE_DELAY = 3
local SLEEPING_BAG_EQUIP_DELAY = 0.4

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
-- GUI PATHS
-- ============================

local PlayerGui =
    player:WaitForChild("PlayerGui")

local HUD =
    PlayerGui:WaitForChild("HUD")

local Tabs =
    HUD:WaitForChild("Tabs")

local StatsChecker =
    Tabs:WaitForChild("StatsChecker")

local Bars =
    HUD:WaitForChild("Bars")

local MainHUD =
    Bars:WaitForChild("MainHUD")

local FatigueStaminaText =
    MainHUD:WaitForChild("FatigueStamina")

local HungerDisplayText =
    MainHUD:WaitForChild("HungerDisplay")

-- ============================
-- RAYFIELD
-- ============================

local Rayfield =
    loadstring(
        game:HttpGet(
            "https://sirius.menu/rayfield"
        )
    )()

local Window =
    Rayfield:CreateWindow({
        Name =
            "Asehole hub | v"
            .. HUB_VERSION,

        LoadingTitle =
            "Asehole hub",

        LoadingSubtitle =
            "Utilities • v"
            .. HUB_VERSION,

        ConfigurationSaving = {
            Enabled = true,
            FolderName = "AseholeHub",
            FileName = "Config"
        },
    })

local AutoUseTab =
    Window:CreateTab(
        "Auto Use",
        4483362458
    )

local PromptTab =
    Window:CreateTab(
        "Auto Prompts",
        4483362458
    )

local StatsTab =
    Window:CreateTab(
        "Stats",
        4483362458
    )

local WebhookTab =
    Window:CreateTab(
        "Webhook",
        4483362458
    )

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

local originalHoldDurations =
    setmetatable({}, {
        __mode = "k"
    })

-- Stats
local statAutoRefreshEnabled = true
local statRefreshRate =
    DEFAULT_STAT_REFRESH_RATE

-- Stamina
local autoStaminaRestEnabled = false
local staminaStopPercent = 30
local staminaResumePercent = 80
local staminaRestActive = false

-- Auto Eat
local autoEatEnabled = false
local customFoodNames = ""

local autoEatSessionActive = false
local autoEatWorkerRunning = false
local autoEatInProgress = false
local hungerLowHandled = false

local AutoEatStatusText = "OFF"

-- Anti Fatigue
local antiFatigueEnabled = false
local antiFatigueActive = false

-- NEW:
local antiFatigueWorkerRunning = false
local antiFatigueCycleHandled = false
local antiFatigueCycleId = 0

local AntiFatigueStatusText = "OFF"

-- Anti AFK
local antiAfkEnabled = false

-- Discord
local discordFatigueAlertEnabled = false
local discordWebhookUrl = ""
local discordUserId = ""

local fatigueWebhookSent = false
local fatigueRecoveryArmed = false

-- HUD
local currentStaminaPercent = nil
local currentFatiguePercent = nil
local currentHungerPercent = nil

-- ============================================================
-- ANTI AFK
-- ============================================================

player.Idled:Connect(function()

    if not antiAfkEnabled then
        return
    end

    pcall(function()

        local camera =
            workspace.CurrentCamera

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

    if
        not name
        or name == ""
    then
        return nil
    end

    local wanted =
        string.lower(name)

    local character =
        player.Character

    local backpack =
        player:FindFirstChild("Backpack")

    if character then

        for _, item in ipairs(
            character:GetChildren()
        ) do

            if
                item:IsA("Tool")
                and string.lower(item.Name)
                    == wanted
            then
                return item
            end

        end

    end

    if backpack then

        for _, item in ipairs(
            backpack:GetChildren()
        ) do

            if
                item:IsA("Tool")
                and string.lower(item.Name)
                    == wanted
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

    local character =
        player.Character

    local humanoid =
        character
        and character:FindFirstChildOfClass(
            "Humanoid"
        )

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

    local success =
        pcall(function()
            tool:Activate()
        end)

    return success
end

local function useToolOnceByName(name)

    local tool =
        findToolByName(name)

    if not tool then
        return false
    end

    return equipAndActivateTool(tool)
end

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

    return
        obj:IsA("TextLabel")
        or obj:IsA("TextButton")
        or obj:IsA("TextBox")

end

local function stripRichText(text)

    if not text then
        return ""
    end

    text = tostring(text)

    text =
        text:gsub(
            "<[^>]*>",
            ""
        )

    text =
        text:gsub(
            "[\n\r\t]",
            " "
        )

    return text
end

-- ============================================================
-- NUMBER PARSER
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
-- HUD UPDATE
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
-- MASTER AUTOMATION GATE
-- ============================================================

local function canRunAutomation()

    -- Immediately blocks all normal automation
    -- during the 3-second fatigue delay AND sleeping.
    if antiFatigueActive then
        return false
    end

    if autoEatSessionActive then
        return false
    end

    if
        autoEatEnabled
        and currentHungerPercent ~= nil
        and currentHungerPercent
            <= AUTO_EAT_PERCENT
        and not hungerLowHandled
    then
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
        findToolByName(
            targetToolName
        )

    if not tool then
        return
    end

    equipAndActivateTool(tool)
end

local function startAutoUse()

    if autoUseThread then
        return
    end

    autoUseThread =
        task.spawn(function()

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
-- INSTANT PROMPTS
-- ============================================================

local function makePromptInstant(prompt)

    if not prompt:IsA(
        "ProximityPrompt"
    ) then
        return
    end

    if
        originalHoldDurations[prompt]
        == nil
    then

        originalHoldDurations[prompt] =
            prompt.HoldDuration

    end

    prompt.HoldDuration = 0
end

local function enableInstantPrompts()

    for _, obj in ipairs(
        workspace:GetDescendants()
    ) do

        if obj:IsA(
            "ProximityPrompt"
        ) then
            makePromptInstant(obj)
        end

    end
end

local function disableInstantPrompts()

    for prompt, duration in pairs(
        originalHoldDurations
    ) do

        if
            prompt
            and prompt.Parent
        then
            prompt.HoldDuration =
                duration
        end

    end

    table.clear(
        originalHoldDurations
    )
end

workspace.DescendantAdded:Connect(
    function(obj)

        if
            instantHoldPromptsEnabled
            and obj:IsA(
                "ProximityPrompt"
            )
        then

            makePromptInstant(obj)

        end

    end
)

-- ============================================================
-- AUTO PROXIMITY PROMPTS
-- ============================================================

ProximityPromptService.PromptShown:Connect(
    function(prompt)

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
                prompt.HoldDuration
                + 0.05
            )

            VirtualInputManager:SendKeyEvent(
                false,
                key,
                false,
                game
            )

        end)

    end
)

-- ============================================================
-- CUSTOM KEY PROMPTS
-- ============================================================

local watchedLabels = {}

local function getKeyCodeFromChar(char)

    char =
        string.upper(char)

    local success, key =
        pcall(function()

            return Enum.KeyCode[
                char
            ]

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

        local text =
            label.Text

        if
            text
            and #text == 1
        then

            local key =
                getKeyCodeFromChar(
                    text
                )

            if key then

                task.spawn(
                    pressKey,
                    key
                )

            end

        end
    end

    local function tryDelayed()

        if
            not autoDelayedKeyPromptEnabled
        then
            return
        end

        if not canRunAutomation() then
            return
        end

        if not label.Visible then
            return
        end

        local text =
            label.Text

        if
            text
            and #text == 1
        then

            local key =
                getKeyCodeFromChar(
                    text
                )

            if key then

                task.spawn(function()

                    task.wait(
                        delayedKeyPromptDelay
                    )

                    if
                        autoDelayedKeyPromptEnabled
                        and canRunAutomation()
                        and label.Visible
                        and label.Text
                            == text
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

        if child:IsA(
            "TextLabel"
        ) then

            watchLabel(child)

        end

        scanAndWatch(child)

    end
end

scanAndWatch(PlayerGui)

PlayerGui.DescendantAdded:Connect(
    function(obj)

        if obj:IsA(
            "TextLabel"
        ) then

            watchLabel(obj)

        end

    end
)

-- ============================================================
-- FORMAT NUMBER
-- ============================================================

local function formatNumber(number)

    if number == nil then
        return "N/A"
    end

    if
        math.abs(number)
        < 1000000
    then

        if number % 1 == 0 then
            return tostring(number)
        end

        local text =
            string.format(
                "%.4f",
                number
            )

        text =
            text:gsub(
                "0+$",
                ""
            )

        text =
            text:gsub(
                "%.$",
                ""
            )

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
-- STATS
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

local function findStatObject(
    statName
)

    local cached =
        cachedStatObjects[
            statName
        ]

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
            and normalizeName(
                obj.Name
            ) == target
        then

            cachedStatObjects[
                statName
            ] = obj

            return obj

        end

    end

    return nil
end

local function getStatValue(
    statName
)

    local obj =
        findStatObject(
            statName
        )

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
            statLabels[
                info.Internal
            ]

        if value ~= nil then

            label:Set(
                info.Display
                .. ": "
                .. formatNumber(
                    value
                )
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

    if
        currentStaminaPercent
        ~= nil
    then

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

    if
        currentFatiguePercent
        ~= nil
    then

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

    if
        currentHungerPercent
        ~= nil
    then

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

    if
        currentStaminaPercent
        == nil
    then
        return
    end

    if not staminaRestActive then

        if
            currentStaminaPercent
            <= staminaStopPercent
        then

            staminaRestActive =
                true

        end

    else

        if
            currentStaminaPercent
            >= staminaResumePercent
        then

            staminaRestActive =
                false

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
            findToolByName(
                foodName
            )

        if tool then
            return tool
        end

    end

    return nil
end

local function finishAutoEatSession(
    status,
    ignoreCurrentLowHunger
)

    autoEatSessionActive = false
    autoEatInProgress = false
    autoEatWorkerRunning = false

    if ignoreCurrentLowHunger then
        hungerLowHandled = true
    end

    AutoEatStatusText = status
end

local function startAutoEatSession()

    if autoEatWorkerRunning then
        return
    end

    if not autoEatEnabled then
        return
    end

    autoEatSessionActive = true
    autoEatWorkerRunning = true

    AutoEatStatusText =
        "Starting eating session"

    task.spawn(function()

        local failedConfirmations = 0

        while
            autoEatEnabled
            and autoEatSessionActive
        do

            updateHUDValues()

            if
                currentHungerPercent
                == nil
            then

                finishAutoEatSession(
                    "Hunger not found - resumed",
                    true
                )

                return
            end

            if
                currentHungerPercent
                >= AUTO_EAT_TARGET_PERCENT
            then

                finishAutoEatSession(
                    "Full - 100%",
                    true
                )

                return
            end

            -- Anti Fatigue completely pauses
            -- the food worker as well.
            if antiFatigueActive then

                AutoEatStatusText =
                    "Waiting for fatigue recovery"

                task.wait(0.25)

                continue
            end

            local food =
                findFood()

            if not food then

                finishAutoEatSession(
                    "No food left - resumed",
                    true
                )

                return
            end

            local hungerBefore =
                currentHungerPercent

            autoEatInProgress = true

            AutoEatStatusText =
                "Eating "
                .. food.Name
                .. " | "
                .. formatNumber(
                    hungerBefore
                )
                .. "%"

            local activated =
                equipAndActivateTool(
                    food
                )

            if not activated then

                autoEatInProgress =
                    false

                failedConfirmations =
                    failedConfirmations
                    + 1

                if
                    failedConfirmations
                    >= MAX_FOOD_CONFIRM_FAILURES
                then

                    finishAutoEatSession(
                        "Food use failed - resumed",
                        true
                    )

                    return
                end

                AutoEatStatusText =
                    "Food use failed - retrying"

                task.wait(0.5)

                continue
            end

            AutoEatStatusText =
                "Waiting for hunger confirmation..."

            local confirmed = false

            local deadline =
                os.clock()
                + FOOD_CONFIRM_TIMEOUT

            while
                autoEatEnabled
                and autoEatSessionActive
                and os.clock()
                    < deadline
            do

                if antiFatigueActive then
                    break
                end

                task.wait(0.1)

                updateHUDValues()

                if
                    currentHungerPercent
                    ~= nil
                then

                    if
                        currentHungerPercent
                        > hungerBefore
                    then

                        confirmed = true
                        break
                    end

                    if
                        currentHungerPercent
                        >= AUTO_EAT_TARGET_PERCENT
                    then

                        confirmed = true
                        break
                    end

                end

            end

            autoEatInProgress = false

            -- If fatigue interrupted the food
            -- confirmation, wait for fatigue instead
            -- of counting it as a failed food.
            if antiFatigueActive then

                AutoEatStatusText =
                    "Waiting for fatigue recovery"

                task.wait(0.25)

                continue
            end

            if not autoEatEnabled then
                break
            end

            if not autoEatSessionActive then
                break
            end

            if confirmed then

                failedConfirmations = 0

                updateHUDValues()

                if
                    currentHungerPercent
                    and currentHungerPercent
                        >= AUTO_EAT_TARGET_PERCENT
                then

                    finishAutoEatSession(
                        "Full - 100%",
                        true
                    )

                    return
                end

                AutoEatStatusText =
                    "Confirmed: "
                    .. formatNumber(
                        hungerBefore
                    )
                    .. "% -> "
                    .. formatNumber(
                        currentHungerPercent
                    )
                    .. "%"

                task.wait(0.25)

            else

                failedConfirmations =
                    failedConfirmations
                    + 1

                if not findFood() then

                    finishAutoEatSession(
                        "No food left - resumed",
                        true
                    )

                    return
                end

                if
                    failedConfirmations
                    >= MAX_FOOD_CONFIRM_FAILURES
                then

                    finishAutoEatSession(
                        "Food not confirmed - resumed",
                        true
                    )

                    return
                end

                AutoEatStatusText =
                    "No hunger increase - retrying"

                task.wait(0.5)

            end

        end

        autoEatInProgress = false
        autoEatSessionActive = false
        autoEatWorkerRunning = false

    end)

end

local function updateAutoEat()

    if not autoEatEnabled then

        autoEatSessionActive = false
        autoEatInProgress = false
        hungerLowHandled = false

        AutoEatStatusText = "OFF"

        return
    end

    if
        currentHungerPercent
        == nil
    then

        if not autoEatSessionActive then

            AutoEatStatusText =
                "Hunger not found"

        end

        return
    end

    if
        currentHungerPercent
        > AUTO_EAT_PERCENT
    then

        hungerLowHandled = false

        if
            not autoEatSessionActive
            and not autoEatWorkerRunning
        then

            AutoEatStatusText =
                "Ready"

        end

        return
    end

    if hungerLowHandled then

        if not autoEatSessionActive then

            AutoEatStatusText =
                "Low hunger ignored until reset"

        end

        return
    end

    if autoEatSessionActive then
        return
    end

    if antiFatigueActive then

        AutoEatStatusText =
            "Waiting for fatigue"

        return
    end

    startAutoEatSession()
end

-- ============================================================
-- DISCORD
-- ============================================================

local requestFunction =
    (syn and syn.request)
    or http_request
    or request

local DiscordStatusLabel = nil

local function buildDiscordStatFields()

    local fields = {}

    table.insert(fields, {
        name = "Player",
        value = tostring(
            player.Name
        ),
        inline = true
    })

    table.insert(fields, {
        name = "Roblox User ID",
        value = tostring(
            player.UserId
        ),
        inline = true
    })

    table.insert(fields, {
        name = "Stamina %",
        value =
            currentStaminaPercent
                ~= nil
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
            currentFatiguePercent
                ~= nil
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
            currentHungerPercent
                ~= nil
            and (
                formatNumber(
                    currentHungerPercent
                ) .. "%"
            )
            or "N/A",
        inline = true
    })

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
                and formatNumber(
                    value
                )
                or "N/A",

            inline = true
        })

    end

    return fields
end

local function sendDiscordWebhook(
    alertType
)

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

                if
                    discordUserId
                    ~= ""
                then

                    mention =
                        "<@"
                        .. discordUserId
                        .. ">"

                end

                local title =
                    "Asehole Hub"

                local description = ""

                if
                    alertType
                    == "test"
                then

                    title =
                        "Webhook Test"

                    description =
                        "Webhook connection test from Asehole hub."

                elseif
                    alertType
                    == "fatigue"
                then

                    title =
                        "Fatigue Alert"

                    description =
                        "Fatigue has reached **"
                        .. formatNumber(
                            currentFatiguePercent
                            or 0
                        )
                        .. "%**."

                elseif
                    alertType
                    == "recovered"
                then

                    title =
                        "Fatigue Recovered"

                    description =
                        "Fatigue has reached **0%**.\n"
                        .. "Recovery is complete and automation can continue."

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
                                    "Asehole hub • v"
                                    .. HUB_VERSION
                                    .. " • Stat Monitor"
                            },

                            timestamp =
                                DateTime.now():ToIsoDate(),
                        }
                    },

                    allowed_mentions = {
                        parse = {}
                    }
                }

                if
                    discordUserId
                    ~= ""
                then

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

                if
                    alertType
                    == "fatigue"
                then

                    DiscordStatusLabel:Set(
                        "Status: FATIGUE ALERT SENT"
                    )

                elseif
                    alertType
                    == "recovered"
                then

                    DiscordStatusLabel:Set(
                        "Status: RECOVERY ALERT SENT"
                    )

                elseif
                    alertType
                    == "test"
                then

                    DiscordStatusLabel:Set(
                        "Status: TEST SENT"
                    )

                else

                    DiscordStatusLabel:Set(
                        "Status: SENT"
                    )

                end

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
-- NEW SLEEPING BAG ACTIVATION
-- ============================================================

local function activateSleepingBag()

    local tool =
        findToolByName(
            "Sleeping Bag"
        )

    if not tool then
        return false
    end

    local character =
        player.Character

    local humanoid =
        character
        and character:FindFirstChildOfClass(
            "Humanoid"
        )

    if not humanoid then
        return false
    end

    -- Make sure another tool is not interfering.
    humanoid:UnequipTools()

    task.wait(0.15)

    -- Find it again because UnequipTools
    -- may have moved the instance.
    tool =
        findToolByName(
            "Sleeping Bag"
        )

    if not tool then
        return false
    end

    humanoid:EquipTool(tool)

    -- Give the Sleeping Bag enough time
    -- to actually become the equipped tool.
    task.wait(
        SLEEPING_BAG_EQUIP_DELAY
    )

    if
        not tool.Parent
        or tool.Parent
            ~= character
    then
        return false
    end

    local success =
        pcall(function()

            tool:Activate()

        end)

    return success
end

-- ============================================================
-- NEW ANTI FATIGUE 3-SECOND SEQUENCE
-- ============================================================

local function startAntiFatigueSequence()

    if antiFatigueWorkerRunning then
        return
    end

    if antiFatigueCycleHandled then
        return
    end

    -- Lock immediately.
    -- Auto Use, Auto Eat and prompts are blocked
    -- from this exact point.
    antiFatigueActive = true
    antiFatigueWorkerRunning = true
    antiFatigueCycleHandled = true

    antiFatigueCycleId =
        antiFatigueCycleId + 1

    local thisCycle =
        antiFatigueCycleId

    AntiFatigueStatusText =
        "Pausing for 3 seconds"

    task.spawn(function()

        -- ====================================================
        -- FULL 3 SECOND PAUSE
        -- ====================================================

        task.wait(
            ANTI_FATIGUE_DELAY
        )

        -- Sequence was cancelled / superseded.
        if
            thisCycle
            ~= antiFatigueCycleId
        then
            return
        end

        if not antiFatigueEnabled then

            antiFatigueActive = false
            antiFatigueWorkerRunning = false

            return
        end

        updateHUDValues()

        -- If somehow already fully recovered
        -- during the 3-second wait, do not use bag.
        if
            currentFatiguePercent
            and currentFatiguePercent
                <= 0
        then

            antiFatigueActive = false
            antiFatigueWorkerRunning = false
            antiFatigueCycleHandled = false

            AntiFatigueStatusText =
                "Recovered"

            return
        end

        AntiFatigueStatusText =
            "Using Sleeping Bag"

        -- ====================================================
        -- EQUIP + ACTIVATE BAG
        -- ====================================================

        local success =
            activateSleepingBag()

        if
            thisCycle
            ~= antiFatigueCycleId
        then
            return
        end

        antiFatigueWorkerRunning =
            false

        if success then

            -- IMPORTANT:
            -- antiFatigueActive stays TRUE here.
            -- Everything remains paused until 0%.
            AntiFatigueStatusText =
                "Sleeping"

        else

            -- Avoid permanently locking the hub
            -- if no usable Sleeping Bag exists.
            antiFatigueActive =
                false

            AntiFatigueStatusText =
                "Sleeping Bag failed"

            -- cycleHandled stays true so it doesn't
            -- repeat the 3-second sequence every 0.2s.

        end

    end)

end

-- ============================================================
-- ANTI FATIGUE
-- ============================================================

local function updateAntiFatigue()

    if
        currentFatiguePercent
        == nil
    then

        if antiFatigueEnabled then

            AntiFatigueStatusText =
                "Fatigue not found"

        end

        return
    end

    -- ========================================================
    -- DISCORD 90%
    -- ========================================================

    if
        currentFatiguePercent
        >= ANTI_FATIGUE_PERCENT
    then

        if
            discordFatigueAlertEnabled
            and not fatigueWebhookSent
        then

            fatigueWebhookSent =
                true

            local started =
                sendDiscordWebhook(
                    "fatigue"
                )

            if started then

                fatigueRecoveryArmed =
                    true

            else

                fatigueWebhookSent =
                    false

            end

        end

    else

        fatigueWebhookSent =
            false

    end

    -- ========================================================
    -- DISCORD 0%
    -- ========================================================

    if
        discordFatigueAlertEnabled
        and fatigueRecoveryArmed
        and currentFatiguePercent
            <= 0
    then

        local started =
            sendDiscordWebhook(
                "recovered"
            )

        if started then

            fatigueRecoveryArmed =
                false

        end

    end

    -- ========================================================
    -- ANTI FATIGUE DISABLED
    -- ========================================================

    if not antiFatigueEnabled then

        if
            antiFatigueActive
            or antiFatigueWorkerRunning
        then

            -- Cancels any pending delayed worker.
            antiFatigueCycleId =
                antiFatigueCycleId + 1

        end

        antiFatigueActive = false
        antiFatigueWorkerRunning = false
        antiFatigueCycleHandled = false

        AntiFatigueStatusText =
            "OFF"

        return
    end

    -- ========================================================
    -- RECOVERED
    -- ========================================================

    if
        currentFatiguePercent
        <= 0
    then

        if
            antiFatigueActive
            or antiFatigueWorkerRunning
        then

            -- Cancel any delayed worker still alive.
            antiFatigueCycleId =
                antiFatigueCycleId + 1

        end

        antiFatigueActive = false
        antiFatigueWorkerRunning = false
        antiFatigueCycleHandled = false

        AntiFatigueStatusText =
            "Recovered"

        return
    end

    -- ========================================================
    -- CURRENTLY IN THE 3 SECOND WAIT
    -- ========================================================

    if antiFatigueWorkerRunning then

        -- Worker controls its own status.
        return
    end

    -- ========================================================
    -- CURRENTLY SLEEPING
    -- ========================================================

    if antiFatigueActive then

        AntiFatigueStatusText =
            "Sleeping - "
            .. formatNumber(
                currentFatiguePercent
            )
            .. "%"

        return
    end

    -- ========================================================
    -- REARM AFTER DROPPING BELOW 90
    -- ========================================================

    if
        currentFatiguePercent
        < ANTI_FATIGUE_PERCENT
    then

        antiFatigueCycleHandled =
            false

        AntiFatigueStatusText =
            "Ready"

        return
    end

    -- ========================================================
    -- HIT 90%
    -- ========================================================

    if
        currentFatiguePercent
        >= ANTI_FATIGUE_PERCENT
        and not antiFatigueCycleHandled
    then

        startAntiFatigueSequence()

        return
    end

    -- Bag failed during this cycle.
    if
        antiFatigueCycleHandled
        and not antiFatigueActive
    then

        -- Keep previous failure status.
        return
    end

end

-- ============================================================
-- AUTO USE UI
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
            tostring(
                text or ""
            )

    end,
})

AutoUseTab:CreateToggle({
    Name =
        "Auto Use Tool",
    CurrentValue =
        false,
    Flag =
        "AutoUseToggle",

    Callback = function(value)

        autoUseEnabled =
            value

        if value then

            startAutoUse()

        else

            stopAutoUse()

        end

    end,
})

AutoUseTab:CreateButton({
    Name =
        "Use Once",

    Callback = function()

        if canRunAutomation() then

            equipAndUseTargetTool()

        end

    end,
})

-- ============================================================
-- PROMPT UI
-- ============================================================

PromptTab:CreateToggle({
    Name =
        "Instant Hold Prompts",
    CurrentValue =
        false,
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
    CurrentValue =
        false,
    Flag =
        "AutoPromptToggle",

    Callback = function(value)

        autoPromptEnabled =
            value

    end,
})

PromptTab:CreateToggle({
    Name =
        "Auto-Press Custom Key Prompts",
    CurrentValue =
        false,
    Flag =
        "AutoKeyPromptToggle",

    Callback = function(value)

        autoKeyPromptEnabled =
            value

    end,
})

PromptTab:CreateToggle({
    Name =
        "Auto-Press Delayed Key Prompts",
    CurrentValue =
        false,
    Flag =
        "AutoDelayedKeyPromptToggle",

    Callback = function(value)

        autoDelayedKeyPromptEnabled =
            value

    end,
})

PromptTab:CreateSlider({
    Name =
        "Delay Before Press",
    Range =
        {0.1, 3},
    Increment =
        0.1,
    Suffix =
        "s",
    CurrentValue =
        0.8,
    Flag =
        "DelayedKeyPromptDelay",

    Callback = function(value)

        delayedKeyPromptDelay =
            value

    end,
})

-- ============================================================
-- STAMINA UI
-- ============================================================

PromptTab:CreateToggle({
    Name =
        "Auto Stamina Rest",
    CurrentValue =
        false,
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
    Range =
        {0, 100},
    Increment =
        1,
    Suffix =
        "%",
    CurrentValue =
        30,
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
    Range =
        {0, 100},
    Increment =
        1,
    Suffix =
        "%",
    CurrentValue =
        80,
    Flag =
        "StaminaResumePercent",

    Callback = function(value)

        staminaResumePercent =
            value

    end,
})

-- ============================================================
-- AUTO EAT UI
-- ============================================================

PromptTab:CreateToggle({
    Name =
        "Auto Eat",
    CurrentValue =
        false,
    Flag =
        "AutoEat",

    Callback = function(value)

        autoEatEnabled =
            value

        if not value then

            autoEatSessionActive =
                false

            autoEatInProgress =
                false

            hungerLowHandled =
                false

            AutoEatStatusText =
                "OFF"

        end

    end,
})

PromptTab:CreateInput({
    Name =
        "Custom Food Name",

    PlaceholderText =
        "Apple or Apple, Chicken",

    RemoveTextAfterFocusLost =
        false,

    CurrentValue =
        "",

    Flag =
        "CustomFoodName",

    Callback = function(text)

        customFoodNames =
            tostring(
                text or ""
            )

    end,
})

PromptTab:CreateLabel(
    "Starts eating when hunger reaches 10%."
)

PromptTab:CreateLabel(
    "Keeps eating until hunger reaches 100%."
)

PromptTab:CreateLabel(
    "Each food use must increase the Hunger HUD."
)

PromptTab:CreateLabel(
    "No food left = automation resumes."
)

PromptTab:CreateLabel(
    "Default foods: Steak and Burger."
)

-- ============================================================
-- ANTI FATIGUE UI
-- ============================================================

PromptTab:CreateToggle({
    Name =
        "Anti Fatigue",
    CurrentValue =
        false,
    Flag =
        "AntiFatigue",

    Callback = function(value)

        antiFatigueEnabled =
            value

        if not value then

            -- Cancel a pending 3-second sequence.
            antiFatigueCycleId =
                antiFatigueCycleId + 1

            antiFatigueActive =
                false

            antiFatigueWorkerRunning =
                false

            antiFatigueCycleHandled =
                false

            AntiFatigueStatusText =
                "OFF"

        end

    end,
})

PromptTab:CreateLabel(
    "At 90%: pauses everything for 3 seconds."
)

PromptTab:CreateLabel(
    "Then equips and activates Sleeping Bag."
)

PromptTab:CreateLabel(
    "Automation resumes when fatigue reaches 0%."
)

-- ============================================================
-- ANTI AFK UI
-- ============================================================

PromptTab:CreateToggle({
    Name =
        "Anti AFK",
    CurrentValue =
        false,
    Flag =
        "AntiAFK",

    Callback = function(value)

        antiAfkEnabled =
            value

    end,
})

-- ============================================================
-- STATUS LABELS
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
-- WEBHOOK UI
-- ============================================================

WebhookTab:CreateLabel(
    "Discord Fatigue Notifications"
)

WebhookTab:CreateLabel(
    "Hub Version: v"
    .. HUB_VERSION
)

WebhookTab:CreateInput({
    Name =
        "Webhook URL",

    PlaceholderText =
        "Paste Discord webhook URL",

    RemoveTextAfterFocusLost =
        false,

    CurrentValue =
        "",

    Flag =
        "DiscordWebhookURL",

    Callback = function(text)

        discordWebhookUrl =
            tostring(
                text or ""
            )

    end,
})

WebhookTab:CreateInput({
    Name =
        "Discord User ID",

    PlaceholderText =
        "e.g. 123456789012345678",

    RemoveTextAfterFocusLost =
        false,

    CurrentValue =
        "",

    Flag =
        "DiscordUserID",

    Callback = function(text)

        discordUserId =
            tostring(
                text or ""
            ):gsub(
                "%D",
                ""
            )

    end,
})

WebhookTab:CreateToggle({
    Name =
        "Fatigue Webhook Alert",

    CurrentValue =
        false,

    Flag =
        "DiscordFatigueAlert",

    Callback = function(value)

        discordFatigueAlertEnabled =
            value

        if not value then

            fatigueWebhookSent =
                false

            fatigueRecoveryArmed =
                false

        end

    end,
})

DiscordStatusLabel =
    WebhookTab:CreateLabel(
        "Status: OFF"
    )

WebhookTab:CreateLabel(
    "90% fatigue: sends warning + ping."
)

WebhookTab:CreateLabel(
    "0% fatigue: sends recovery + ping."
)

WebhookTab:CreateLabel(
    "Both alerts include all tracked stats."
)

WebhookTab:CreateButton({
    Name =
        "Send Test Webhook",

    Callback = function()

        sendDiscordWebhook(
            "test"
        )

    end,
})

-- ============================================================
-- STATS UI
-- ============================================================

StatsTab:CreateToggle({
    Name =
        "Auto Refresh Stats",

    CurrentValue =
        true,

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
    Name =
        "Stat Refresh Rate",

    Range =
        {0.1, 2},

    Increment =
        0.1,

    Suffix =
        "s",

    CurrentValue =
        DEFAULT_STAT_REFRESH_RATE,

    Flag =
        "StatRefreshRate",

    Callback = function(value)

        statRefreshRate =
            value

    end,
})

StatsTab:CreateButton({
    Name =
        "Refresh Stats Now",

    Callback = function()

        refreshStats()

    end,
})

StatsTab:CreateButton({
    Name =
        "Print Raw Stats",

    Callback = function()

        print("")
        print("==============================")
        print("ASEHOLE HUB RAW STATS")
        print("==============================")

        for _, info in ipairs(
            TARGET_STATS
        ) do

            local obj =
                findStatObject(
                    info.Internal
                )

            if obj then

                print(
                    "Internal:",
                    info.Internal
                )

                print(
                    "Display:",
                    info.Display
                )

                print(
                    "RAW:",
                    obj.Text
                )

                print(
                    "CLEAN:",
                    stripRichText(
                        obj.Text
                    )
                )

                print(
                    "PARSED:",
                    extractNumber(
                        obj.Text
                    )
                )

                print(
                    "PATH:",
                    obj:GetFullName()
                )

                print(
                    "------------------------------"
                )

            else

                print(
                    info.Display,
                    "= NOT FOUND"
                )

            end

        end

        print("==============================")
        print("")

    end,
})

StatsTab:CreateButton({
    Name =
        "Print Stamina Raw Text",

    Callback = function()

        updateHUDValues()

        print("")
        print("==============================")
        print("STAMINA / FATIGUE DEBUG")
        print("==============================")

        print(
            "RAW:",
            FatigueStaminaText.Text
        )

        print(
            "CLEAN:",
            stripRichText(
                FatigueStaminaText.Text
            )
        )

        print(
            "STAMINA:",
            currentStaminaPercent
        )

        print(
            "FATIGUE:",
            currentFatiguePercent
        )

        print(
            "PATH:",
            FatigueStaminaText:GetFullName()
        )

        print("==============================")
        print("")

    end,
})

StatsTab:CreateButton({
    Name =
        "Print HUD Values",

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

        print(
            "Hunger RAW:",
            HungerDisplayText.Text
        )

        print("==============================")
        print("")

    end,
})

-- ============================================================
-- LOAD SAVED CONFIG
-- ============================================================

task.wait(0.5)

local configLoaded,
      configError =
    pcall(function()

        Rayfield:LoadConfiguration()

    end)

if not configLoaded then

    warn(
        "[Asehole hub] Config load failed:",
        configError
    )

end

-- ============================================================
-- MAIN LOOP
-- ============================================================

task.spawn(function()

    while true do

        updateHUDValues()

        updateStaminaRest()

        -- IMPORTANT:
        -- Anti Fatigue is processed before
        -- Auto Eat so it gets priority.
        updateAntiFatigue()

        updateAutoEat()

        if statAutoRefreshEnabled then
            refreshStats()
        end

        -- ============================
        -- STAMINA
        -- ============================

        if
            currentStaminaPercent
            ~= nil
        then

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

        if
            currentFatiguePercent
            ~= nil
        then

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

        if
            currentHungerPercent
            ~= nil
        then

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
        -- STAMINA REST
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
        -- AUTO EAT
        -- ============================

        AutoEatStatusLabel:Set(
            "Auto Eat Status: "
            .. AutoEatStatusText
        )

        -- ============================
        -- ANTI FATIGUE
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
        -- WEBHOOK
        -- ============================

        if
            not discordFatigueAlertEnabled
        then

            DiscordStatusLabel:Set(
                "Status: OFF"
            )

        elseif
            discordWebhookUrl
            == ""
        then

            DiscordStatusLabel:Set(
                "Status: WAITING FOR WEBHOOK"
            )

        elseif
            discordUserId
            == ""
        then

            DiscordStatusLabel:Set(
                "Status: ARMED - NO PING ID"
            )

        elseif
            currentFatiguePercent
            and currentFatiguePercent
                >= ANTI_FATIGUE_PERCENT
            and fatigueWebhookSent
        then

            -- Keep sent status.

        else

            DiscordStatusLabel:Set(
                "Status: ARMED"
            )

        end

        -- ============================
        -- MASTER AUTOMATION
        -- ============================

        if antiFatigueActive then

            if antiFatigueWorkerRunning then

                AutomationStatusLabel:Set(
                    "Automation: PAUSED - FATIGUE 3S"
                )

            else

                AutomationStatusLabel:Set(
                    "Automation: PAUSED - SLEEPING"
                )

            end

        elseif autoEatSessionActive then

            AutomationStatusLabel:Set(
                "Automation: PAUSED - EATING TO 100%"
            )

        elseif
            autoEatEnabled
            and currentHungerPercent
            and currentHungerPercent
                <= AUTO_EAT_PERCENT
            and not hungerLowHandled
        then

            AutomationStatusLabel:Set(
                "Automation: PAUSED - FOOD"
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

task.wait(0.5)

updateHUDValues()
refreshStats()
updateStaminaRest()
updateAntiFatigue()
updateAutoEat()
