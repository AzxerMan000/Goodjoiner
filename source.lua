--// Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Wait for LocalPlayer
local LocalPlayer
repeat
    LocalPlayer = Players.LocalPlayer
    task.wait()
until LocalPlayer

--// Configuration
local webhook = getgenv().webhook or ""
local targetPets = getgenv().TargetPetNames or {}

--// Server hop tracking
local visitedJobIds = {[game.JobId] = true}
local hops = 0
local maxHopsBeforeReset = 50

--// Teleport fails
local teleportFails = 0
local maxTeleportRetries = 3

--// Pet cache
local detectedPets = {}
local webhookSent = false
local stopHopping = false

--// Generate join link for current server
local function generateJoinLink(jobId)
    return "https://examplejoiner.vercel.app/?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. jobId
end

--// ESP function
local function addESP(targetModel)
    if targetModel:FindFirstChild("PetESP") then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PetESP"
    billboard.Adornee = targetModel
    billboard.Size = UDim2.new(0, 120, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = targetModel

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "🎯 Target Pet"
    label.TextColor3 = Color3.fromRGB(255, 0, 0)
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.Parent = billboard
end

--// Webhook function
local function sendWebhook(foundPets, jobId)
    if webhook == "" then
        warn("⚠️ Webhook is empty, skipping.")
        return
    end

    local joinLink = generateJoinLink(jobId)

    local petCounts = {}
    for _, pet in ipairs(foundPets) do
        petCounts[pet] = (petCounts[pet] or 0) + 1
    end

    local formattedPets = {}
    for petName, count in pairs(petCounts) do
        table.insert(formattedPets, count > 1 and petName .. " x" .. count or petName)
    end

    local data = HttpService:JSONEncode({
        ["content"] = "@everyone 🚨 PET DETECTED",
        ["embeds"] = {{
            ["title"] = "🧠 Pet(s) Found!",
            ["description"] = "A target pet has been detected in the server!",
            ["fields"] = {
                { ["name"] = "User", ["value"] = LocalPlayer.Name },
                { ["name"] = "Found Pet(s)", ["value"] = table.concat(formattedPets, "\n") },
                { ["name"] = "Server JobId", ["value"] = jobId },
                { ["name"] = "Join Link", ["value"] = "[👉 Click to Join Server](" .. joinLink .. ")" },
                { ["name"] = "Time", ["value"] = os.date("%Y-%m-%d %H:%M:%S") }
            },
            ["color"] = 0xFF00FF
        }}
    })

    local req = http_request or request or (syn and syn.request)
    if req then
        local success, err = pcall(function()
            req({
                Url = webhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = data
            })
        end)
        if success then
            print("✅ Webhook sent with join link.")
        else
            warn("❌ Failed to send webhook:", err)
        end
    else
        warn("❌ Executor does not support HTTP requests.")
    end
end

--// Pet detection
local function checkForPets()
    local found = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local nameLower = string.lower(obj.Name)
            for _, target in pairs(targetPets) do
                if string.find(nameLower, string.lower(target)) and not obj:FindFirstChild("PetESP") then
                    addESP(obj)
                    table.insert(found, obj.Name)
                    stopHopping = true
                    break
                end
            end
        end
    end
    return found
end

--// Server hop function
function serverHop()
    if stopHopping then return end
    task.wait(1.5)

    local cursor = nil
    local PlaceId, JobId = game.PlaceId, game.JobId
    local tries = 0

    hops += 1
    if hops >= maxHopsBeforeReset then
        visitedJobIds = {[JobId] = true}
        hops = 0
        print("♻️ Resetting visited JobIds.")
    end

    while tries < 3 do
        local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then url = url .. "&cursor=" .. cursor end

        local success, response = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if success and response and response.data then
            local servers = {}
            for _, server in ipairs(response.data) do
                if tonumber(server.playing or 0) < tonumber(server.maxPlayers or 1)
                    and server.id ~= JobId
                    and not visitedJobIds[server.id] then
                        table.insert(servers, server.id)
                end
            end

            if #servers > 0 then
                local picked = servers[math.random(1, #servers)]
                print("✅ Hopping to server:", picked)
                teleportFails = 0
                TeleportService:TeleportToPlaceInstance(PlaceId, picked)
                return
            end

            cursor = response.nextPageCursor
            if not cursor then
                tries += 1
                cursor = nil
                task.wait(0.5)
            end
        else
            warn("⚠️ Failed to fetch server list. Retrying...")
            tries += 1
            task.wait(0.5)
        end
    end

    warn("❌ No valid servers found. Forcing random teleport...")
    TeleportService:Teleport(PlaceId)
end

--// Live detection
workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.25)
    if obj:IsA("Model") then
        local nameLower = string.lower(obj.Name)
        for _, target in pairs(targetPets) do
            if string.find(nameLower, string.lower(target)) and not obj:FindFirstChild("PetESP") then
                if not detectedPets[obj.Name] then
                    detectedPets[obj.Name] = true
                    addESP(obj)
                    print("🎯 New pet appeared:", obj.Name)
                    stopHopping = true
                    if not webhookSent then
                        sendWebhook({obj.Name}, game.JobId)
                        webhookSent = true
                    end
                end
                break
            end
        end
    end
end)

--// Start
task.wait(6)
local petsFound = checkForPets()
if #petsFound > 0 then
    for _, name in ipairs(petsFound) do
        detectedPets[name] = true
    end
    if not webhookSent then
        print("🎯 Found pet(s):", table.concat(petsFound, ", "))
        sendWebhook(petsFound, game.JobId)
        webhookSent = true
    end
else
    print("🔍 No target pets found. Hopping to next server...")
    task.delay(1.5, serverHop)
end
