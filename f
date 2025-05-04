-- Load Rayfield (Keep this at the top)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create the window (Keep this)
local Window = Rayfield:CreateWindow({
    Name = "Blood Debt Role Detector",
    Icon = 0,
    LoadingTitle = "Rayfield Role Detector",
    LoadingSubtitle = "by Sirius",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "Big Hub"
    }
})

-- Create the tab (Keep this)
local Tab = Window:CreateTab("Players", "rewind")

-- (Keep all weapon lists, color/label definitions, Services like Players, lp, etc. here)
-- Weapon lists
local killerWeapons = {
    ["Charcoal Steel JS-22"] = true,
    ["Pretty Pink RR-LCP"] = true,
    ["JS-2 BondsDerringy"] = true,
    ["GILDED"] = true,
    ["Kamatov"] = true,
    ["JS2-Derringy"] = true,
    ["JS-22"] = true,
    ["NGO"] = true,
    ["Throwing Dagger"] = true,
    ["SoundMaker"] = true,
    ["SoundMakerSlower"] = true,
    ["RR-LightCompactPistolS"] = true,
    ["J9-Mereta"] = true,
    ["RY's GG-17"] = true,   -- **Special Killer Weapon**
    ["RR-LCP"] = true,
    ["JS1 Competitor"] = true,
    ["AT's KAR-15"] = true,  -- **Special Killer Weapon (Corrected)**
    ["VK's ANKM"] = true,    -- **Special Killer Weapon (Corrected)**
    ["Clothed Sawn-off"] = true,
    ["Sawn-off"] = true,
    ["Clothed Rosen-Obrez"] = true,
    ["Rosen-Obrez"] = true,
    ["Dark Steel K1911"] = true,
    ["Silver Steel K1911"] = true,
    ["K1911"] = true,
    ["ZZ-90"] = true,
    ["SKORPION"] = true,
    ["Mares Leg"] = true,
}

local vigilanteWeapons = {
    ["Beagle"] = true,
    ["IZVEKH-412"] = true,
    ["Silver Steel RR-Snubby"] = true,
    ["RR-Snubby"] = true,
    ["GG-17"] = true,
    ["J9-M"] = true,
    ["J9-Meretta"] = true,
}

-- Define Special Killer weapons (for the global check - Corrected names)
local specialKillerWeapons = {
    ["RY's GG-17"] = true,
    ["AT's KAR-15"] = true, -- Corrected
    ["VK's ANKM"] = true,   -- Corrected
}

-- Define a combined list of all relevant weapons
local allRoleWeapons = {}
for name, _ in pairs(killerWeapons) do allRoleWeapons[name] = true end
for name, _ in pairs(vigilanteWeapons) do allRoleWeapons[name] = true end


-- Define Role Colors and Labels
local killerColor = Color3.fromRGB(255, 0, 0) -- Red
local killerLabel = "KILLER"
local vigilanteColor = Color3.fromRGB(0, 255, 255) -- Cyan
local vigilanteLabel = "VIGILANTE"
local innocentColor = Color3.fromRGB(0, 255, 0) -- Green
local innocentLabel = "INNOCENT"


local Players = game:GetService("Players")
local lp = Players.LocalPlayer

-- State variables for controlling ESP (Used by the two buttons)
local espEnabled = false
local stopEspLoop = false -- Signal to stop the detection loop
local espPlayerAddedConnection = nil -- Store the main PlayerAdded connection
local espCharacterAddedConnections = {} -- Store per-player CharacterAdded connections

-- State variables for the distance locking rule
local rolesLockedByDistance = false -- Flag indicating if distance roles are locked
local lockedDistanceRoles = {} -- Stores the determined distance role ("Killer" or "Innocent")


-- Add floating name tag (smaller and neater) - Remains the same
local function addNameTag(character, text, color)
    local head = character:FindFirstChild("Head")
    if not head then return end

    local oldTag = head:FindFirstChild("RoleBillboard")
    if oldTag then oldTag:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "RoleBillboard"
    bb.Size = UDim2.new(0, 100, 0, 20)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.Adornee = head
    bb.AlwaysOnTop = true
    bb.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.2
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = bb
end

-- Clear previous overlays - Remains the same
local function clearOldStuff(character)
    if not character then return end

    local oldHighlight = character:FindFirstChild("RoleHighlight")
    if oldHighlight and oldHighlight:IsA("Highlight") then
        oldHighlight:Destroy()
    end

    local head = character:FindFirstChild("Head")
    if head then
        local tag = head:FindFirstChild("RoleBillboard")
        if tag then tag:Destroy() end
    end
end

-- Tag player by role - Remains the same
local function tagPlayer(player, roleColor, labelText)
    if not player.Character then return end
    clearOldStuff(player.Character)

    local highlight = Instance.new("Highlight", player.Character)

    highlight.Name = "RoleHighlight"
    highlight.Archivable = true
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = true

    highlight.FillColor = roleColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- White outline
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0

    if labelText then
        addNameTag(player.Character, labelText, roleColor)
    end
end

-- Helper function to collect a player's tools - Remains the same
local function collectPlayerTools(player)
    local tools = {}
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                 tools[tool.Name] = tool
            end
        end
    end
    if player.Character then
        for _, tool in ipairs(player.Character:GetChildren()) do
            if tool:IsA("Tool") then
                tools[tool.Name] = tool
            end
        end
    end
    return tools -- Return table keyed by tool name
end

-- Helper function to get standard role based on weapons (excluding special killer check) - Remains the same
local function getStandardRoleFromWeapons(toolsByName)
    local role = nil
    local color = nil
    local label = nil

    -- Check standard Killer weapons first (priority), *excluding* special ones here
    for weaponName, _ in pairs(killerWeapons) do
        if not specialKillerWeapons[weaponName] and toolsByName[weaponName] then
             role = "Killer"
             color = killerColor
             label = killerLabel
             return role, color, label -- Standard Killer overrides Vigilante
        end
    end

    -- Check Vigilante weapons if no standard Killer weapon found
    for weaponName, _ in pairs(vigilanteWeapons) do
        if toolsByName[weaponName] then
            role = "Vigilante"
            color = vigilanteColor
            label = vigilanteLabel
            return role, color, label -- Found a Vigilante weapon
        end
    end

    -- No standard role weapon found
    return nil, nil, nil
end


-- Detect and apply roles - Implements the distance snapshot logic
local function detectRoles()
    if not espEnabled then return end -- Safety check

    local specialKillerDetected = false
    local playersWithSpecialWeapons = {} -- For the highest priority rule

    local playersWithValidCharacters = {} -- Track players who are not local and have characters/HRP
    local playersWithoutAnyGun = {}         -- Track players without *any* role weapon
    local playersWithAnyGun = {}            -- Track players with *any* role weapon


    -- **Pass 1: Scan for Special Killers and identify players with/without guns**
    for _, player in ipairs(Players:GetPlayers()) do
        -- Only process players who are not the local player and have a valid character model with HRP
        if player ~= lp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
             playersWithValidCharacters[player] = true -- Mark as valid target for tagging

             local toolsByName = collectPlayerTools(player)
             local hasAnyRoleWeapon = false

             -- Check for Special Killers and Any Role Weapon on this player
             for name, tool in pairs(toolsByName) do
                 if specialKillerWeapons[name] then
                     specialKillerDetected = true
                     playersWithSpecialWeapons[player] = true -- Mark this player as a special weapon holder
                 end
                 if allRoleWeapons[name] then
                      hasAnyRoleWeapon = true
                 end
             end

             if not hasAnyRoleWeapon then
                 playersWithoutAnyGun[player] = true -- Mark if they have no role weapon
             else
                 playersWithAnyGun[player] = true -- Mark if they DO have a role weapon
             end

        else
            -- Player is local player or without a valid character - ensure tags are cleared
            clearOldStuff(player.Character)
        end
    end

    -- **Step 2: Determine the state of "Everyone has a gun" and "No one has a gun" conditions**
    local everyoneHasGunConditionMet = false
    local noOneHasGunConditionMet = false

    if not specialKillerDetected then
         -- Check "Everyone has a gun" (only if no special killer)
         local allValidTargetsHaveGun = true
         for player, _ in pairs(playersWithValidCharacters) do
             if playersWithoutAnyGun[player] then
                 allValidTargetsHaveGun = false # Found someone without a gun
                 break
             end
         end
         local otherPlayersWithCharCount = 0
         for player, _ in pairs(playersWithValidCharacters) do
             if player ~= lp then otherPlayersWithCharCount = otherPlayersWithCharCount + 1 end
         end
         if allValidTargetsHaveGun and otherPlayersWithCharCount > 0 then
             everyoneHasGunConditionMet = true
         end

         -- Check "No one has a gun" (only if no special killer)
         local anyValidTargetHasGun = false
         for player, _ in pairs(playersWithValidCharacters) do
              if playersWithAnyGun[player] then
                  anyValidTargetHasGun = true # Found someone *with* a gun
                  break
              end
         end
         -- Condition is met if NO valid target has a gun AND there is at least one valid target
         if not anyValidTargetHasGun and otherPlayersWithCharCount > 0 then
              noOneHasGunConditionMet = true
         end
    end

    -- **Step 3: Manage the distance locking state (rolesLockedByDistance)**
    local prevRolesLockedByDistance = rolesLockedByDistance -- Store state before checking transitions

    -- Condition to ACTIVATE lock: No special killer AND Everyone has a gun AND Not already locked
    if not specialKillerDetected and everyoneHasGunConditionMet and not rolesLockedByDistance then
         rolesLockedByDistance = true -- Activate the lock
         lockedDistanceRoles = {} -- Clear any old locked roles

         -- Determine and store the distance-based roles for locking
         local localHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") -- Need local HRP for distance

         if localHRP then
             for player, _ in pairs(playersWithValidCharacters) do
                 local playerHRP = player.Character:FindFirstChild("HumanoidRootPart")
                 if playerHRP then
                     local distance = (localHRP.Position - playerHRP.Position).Magnitude
                     if distance >= distanceThreshold then
                          lockedDistanceRoles[player] = "Killer"
                     else
                          lockedDistanceRoles[player] = "Innocent"
                     end
                 else
                      -- Should not happen if playersWithValidCharacters is correct, but safety
                 end
             end
         else
              -- Local player HRP missing - cannot lock distance roles
              rolesLockedByDistance = false -- Force lock off if cannot calculate distance
              lockedDistanceRoles = {}
         end
    end

    -- Condition to DEACTIVATE lock: No special killer AND No one has a gun AND Currently locked
    if not specialKillerDetected and noOneHasGunConditionMet and rolesLockedByDistance then
         rolesLockedByDistance = false -- Deactivate the lock
         lockedDistanceRoles = {} -- Clear stored roles
    end

    -- Note: If neither transition happens, rolesLockedByDistance keeps its state


    -- **Pass 2: Apply Tags based on determined state (Special Killer > Distance Locked > Standard)**
    for _, player in ipairs(Players:GetPlayers()) do
        -- Only process players who were marked as valid targets in Pass 1
        if playersWithValidCharacters[player] then

             if specialKillerDetected then
                 -- Condition 1: Special Killer rule (Highest Priority)
                 -- Rule: Holder is Killer. Everyone else is Innocent when special is present.
                 if playersWithSpecialWeapons[player] then
                     tagPlayer(player, killerColor, killerLabel)
                 else
                     tagPlayer(player, innocentColor, innocentLabel)
                 end

             elseif rolesLockedByDistance then
                 -- Condition 2: Roles locked by "Everyone has a gun" rule (Medium Priority) - Use LOCKED distance roles
                 local lockedRole = lockedDistanceRoles[player] -- Look up the stored distance role string

                 if lockedRole then -- Should exist if roles are locked and player is valid
                      if lockedRole == "Killer" then
                           tagPlayer(player, killerColor, killerLabel)
                      elseif lockedRole == "Innocent" then
                           tagPlayer(player, innocentColor, innocentLabel)
                      -- No other roles should be stored for this lock type
                      end
                 else
                     -- Player somehow valid but not in lockedDistanceRoles - safety clear?
                     clearOldStuff(player.Character)
                 end

             else
                 -- Condition 3: Standard detection (Lowest Priority)
                 local toolsByName = collectPlayerTools(player)
                 local standardRole, standardColor, standardLabel = getStandardRoleFromWeapons(toolsByName)

                 if standardRole then
                     tagPlayer(player, standardColor, standardLabel)
                 else
                     tagPlayer(player, innocentColor, innocentLabel)
                 end
             end

        -- Players not in playersWithValidCharacters were handled in Pass 1 (cleared)
        end
    end

    -- No need to update previous state flags like prevEveryoneHasGunConditionMet
    -- because the lock state `rolesLockedByDistance` directly controls the behavior.

end -- End of detectRoles function


-- Function to disable ESP - Shared logic (Includes clearing lock state)
local function disableEsp()
    if espEnabled then -- Only disable if it's currently enabled
        espEnabled = false
        stopEspLoop = true -- Signal the loop to stop
        print("ESP Disabled")

        -- Clear lock state variables
        rolesLockedByDistance = false
        lockedDistanceRoles = {}

        -- Disconnect the main PlayerAdded connection
        if espPlayerAddedConnection then
            espPlayerAddedConnection:Disconnect()
            espPlayerAddedConnection = nil
        end

        -- Disconnect all stored CharacterAdded connections
        for player, connection in pairs(espCharacterAddedConnections) do
             if connection and typeof(connection) == "RBXScriptConnection" then -- Safety check connection type
                connection:Disconnect()
             end
             espCharacterAddedConnections[player] = nil
        end
        espCharacterAddedConnections = {} -- Clear the table itself


        -- Clear ESP visuals for all players currently in the game
        for _, player in ipairs(Players:GetPlayers()) do
             if player.Character then
                clearOldStuff(player.Character)
             end
        end
         Rayfield:Notify({
            Title = "ESP Disabled",
            Content = "Role detection has been turned off.",
            Duration = 3,
            Image = 4483362458
        })
    end
end


-- Function to teleport to dropped gun - Includes all relevant weapons
local function tpToDroppedGun()
    local bloodFolder = workspace:FindFirstChild("BloodFolder")
    if bloodFolder then
        for _, item in ipairs(bloodFolder:GetChildren()) do
            -- Check if the dropped item is a Killer, Vigilante, or Special Killer weapon
            if item:IsA("Tool") and (killerWeapons[item.Name] or vigilanteWeapons[item.Name] or specialKillerWeapons[item.Name]) then
                local targetPosition = item.Position + Vector3.new(0, 5, 0)
                lp.Character:SetPrimaryPartCFrame(CFrame.new(targetPosition))
                return
            end
        end
    end
    Rayfield:Notify({
        Title = "No Gun Found",
        Content = "There are no valid guns in the BloodFolder.",
        Duration = 5,
        Image = 4483362458
    })
end


-- Create Enable ESP button - Only enables if not already enabled
local ButtonEnableESP = Tab:CreateButton({
    Name = "Enable ESP",
    Callback = function()
        if not espEnabled then -- Only enable if it's currently disabled
            espEnabled = true
            stopEspLoop = false -- Ensure loop will run
            print("ESP Enabled")

            -- Start the detection loop in a new thread/coroutine
            task.spawn(function()
                while espEnabled and not stopEspLoop do -- Loop condition
                    task.wait(0.5)
                    detectRoles() -- detectRoles has its own espEnabled check
                end
                 print("ESP Detection loop stopped.")
            end)

            -- Connect PlayerAdded/CharacterAdded events
            espPlayerAddedConnection = game.Players.PlayerAdded:Connect(function(player)
                 local charAddedConn = player.CharacterAdded:Connect(function(character)
                     task.wait(0.1)
                     detectRoles()
                 end)
                 espCharacterAddedConnections[player] = charAddedConn -- Store connection

                 if player.Character then
                      task.wait(0.1)
                      detectRoles()
                 end
            end)

            -- Connect PlayerRemoving for cleanup
             game.Players.PlayerRemoving:Connect(function(player)
                if espCharacterAddedConnections[player] then
                    if typeof(espCharacterAddedConnections[player]) == "RBXScriptConnection" then -- Safety check
                        espCharacterAddedConnections[player]:Disconnect()
                    end
                    espCharacterAddedConnections[player] = nil
                end
                clearOldStuff(player.Character)
            end)

            -- Initial detection right after enabling
            detectRoles() -- Run one scan immediately

            Rayfield:Notify({
                Title = "ESP Enabled",
                Content = "Role detection has been turned on.",
                Duration = 3,
                Image = 4483362458
            })

        else
            print("ESP is already enabled.")
             Rayfield:Notify({
                Title = "ESP Already On",
                Content = "Role detection is already running.",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

-- Create Disable ESP button - Calls the disable function
local ButtonDisableESP = Tab:CreateButton({
    Name = "Disable ESP",
    Callback = function()
        disableEsp() -- Call the shared disable function
    end
})


-- Create button to teleport to dropped gun - Remains the same
local ButtonTP = Tab:CreateButton({
    Name = "TP to Dropped Gun",
    Callback = function()
        tpToDroppedGun()
    end
})

-- Notify the user about ESP - Adjusted to mention two buttons
Rayfield:Notify({
    Title = "ESP Ready",
    Content = "Click 'Enable ESP' to start detection. Use 'Disable ESP' to turn it off.",
    Duration = 5,
    Image = 4483362458
})


-- New Z Key Bind Functionality (Separate from ESP)
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get event references safely
local success, RagdollEventsFolder = pcall(function()
    return ReplicatedStorage:WaitForChild("RagdollEvents", 10) -- Wait up to 10 seconds
end)

local RagdollEvent = nil
local UnragdollEvent = nil

if success and RagdollEventsFolder then
    local s1, ragEvent = pcall(function() return RagdollEventsFolder:WaitForChild("RagdollEvent", 5) end)
    if s1 then RagdollEvent = ragEvent else warn("Blood Debt Role Detector: Could not find RagdollEvent.") end

    local s2, unragEvent = pcall(function() return RagdollEventsFolder:WaitForChild("UnragdollEvent", 5) end)
    if s2 then UnragdollEvent = unragEvent else warn("Blood Debt Role Detector: Could not find UnragdollEvent.") end

    if not RagdollEvent or not UnragdollEvent then
         -- Notification already printed inside pcalls if events not found
    end
else
    warn("Blood Debt Role Detector: Could not find RagdollEvents folder in ReplicatedStorage. Z key bind disabled.")
     Rayfield:Notify({
        Title = "Z Key Bind Failed",
        Content = "Ragdoll events not found. Z key bind disabled.",
        Duration = 5,
        Image = 4483362458
    })
end


-- State variable for the Z key toggle
local isRagdolled = false -- Assume character is not ragdolled initially

-- Connect Input Began event
if RagdollEvent and UnragdollEvent then -- Only connect if both events were found successfully
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        -- Check if the input is the 'Z' key and it's not processed by the game (like typing in a textbox)
        if not gameProcessedEvent and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Z then

            if not isRagdolled then
                -- Current state is NOT ragdolled, so Fire RagdollEvent
                local success, err = pcall(function()
                    RagdollEvent:FireServer(true) -- Fire the ragdoll event with argument 'true'
                end)
                if success then
                    isRagdolled = true -- Update state if firing succeeded
                    print("Fired RagdollEvent(true)")
                else
                    warn("Failed to fire RagdollEvent:", err)
                    -- Optionally reset state if firing failed? Depends on game behavior. Let's not change state on fire failure for now.
                end
            else
                -- Current state IS ragdolled, so Fire UnragdollEvent
                 local success, err = pcall(function()
                    UnragdollEvent:FireServer() -- Fire the unragdoll event (no arguments)
                end)
                if success then
                    isRagdolled = false -- Update state if firing succeeded
                    print("Fired UnragdollEvent()")
                 else
                    warn("Failed to fire UnragdollEvent:", err)
                    -- Optionally reset state if firing failed?
                end
            end
        end
    end)
end
