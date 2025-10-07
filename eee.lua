--// Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

--// GUI
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 200, 0, 120)
MainFrame.Position = UDim2.new(0, 10, 0, 10)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true

local ESPToggle = Instance.new("TextButton", MainFrame)
ESPToggle.Size = UDim2.new(1, -10, 0, 50)
ESPToggle.Position = UDim2.new(0, 5, 0, 5)
ESPToggle.Text = "ESP: ON"
ESPToggle.TextColor3 = Color3.fromRGB(255,255,255)
ESPToggle.BackgroundColor3 = Color3.fromRGB(50,50,50)
ESPToggle.MouseButton1Click:Connect(function()
    getgenv().ESPEnabled = not getgenv().ESPEnabled
    ESPToggle.Text = "ESP: "..(getgenv().ESPEnabled and "ON" or "OFF")
end)

local HopperButton = Instance.new("TextButton", MainFrame)
HopperButton.Size = UDim2.new(1, -10, 0, 50)
HopperButton.Position = UDim2.new(0, 5, 0, 65)
HopperButton.Text = "Server Hopper: ON"
HopperButton.TextColor3 = Color3.fromRGB(255,255,255)
HopperButton.BackgroundColor3 = Color3.fromRGB(50,50,50)
HopperButton.MouseButton1Click:Connect(function()
    getgenv().ServerHopEnabled = not getgenv().ServerHopEnabled
    HopperButton.Text = "Server Hopper: "..(getgenv().ServerHopEnabled and "ON" or "OFF")
end)

--// Core Notification
local function sendNotification(title, text, duration)
    StarterGui:SetCore("SendNotification", {
        Title = title or "Notification";
        Text = text or "";
        Duration = duration or 3;
    })
end

--// Server join link
local function getServerLink()
    return "https://examplejoiner.vercel.app/?placeid="..game.PlaceId.."&gameInstanceId="..game.JobId
end

--// Webhook
local function sendWebhook(model)
    if getgenv().Webhook ~= "" then
        local data = {["content"]="🎯 Pet detected: "..model.Name.."\nServer link: "..getServerLink()}
        pcall(function()
            HttpService:PostAsync(getgenv().Webhook, HttpService:JSONEncode(data))
        end)
    end
end

--// ESP
local function addESP(model)
    if not getgenv().ESPEnabled then return end
    local root = model:FindFirstChild("HumanoidRootPart")
    if root and not model:FindFirstChild("PetESP") then
        local esp = Instance.new("BillboardGui")
        esp.Name = "PetESP"
        esp.Adornee = root
        esp.Size = UDim2.new(0,100,0,50)
        esp.AlwaysOnTop = true

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,1,0)
        label.BackgroundTransparency = 1
        label.Text = model.Name
        label.TextColor3 = Color3.fromRGB(0,255,0)
        label.TextScaled = true
        label.Parent = esp

        esp.Parent = model
    end
end

--// Detect model
local function detectModel(model)
    for _, target in pairs(getgenv().Pets or {}) do
        if string.find(string.lower(model.Name), string.lower(target)) then
            addESP(model)
            sendWebhook(model)
            sendNotification("Pet Detected", model.Name.." | Join link: "..getServerLink(), 5)
            print("🎯 Pet detected:", model.Name)
            break
        end
    end
end

--// Detect existing models
for _, obj in pairs(workspace:GetDescendants()) do
    if obj:IsA("Model") then
        detectModel(obj)
    end
end

--// Detect new models
workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") then
        task.wait(0.25)
        detectModel(obj)
    end
end)

--// Server Hopper (1-2 players only)
spawn(function()
    while task.wait(10) do
        if getgenv().ServerHopEnabled then
            local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")).data
            for _, server in pairs(servers) do
                local players = server.playing
                local id = server.id
                if players <= 2 and id ~= game.JobId then
                    print("🌐 Hopping to new server:", id)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, id, Players.LocalPlayer)
                    return
                end
            end
        end
    end
end)
