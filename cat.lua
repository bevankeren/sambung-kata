local message = "Script under maintenance. Please wait for the next update."

pcall(function()
    local StarterGui = game:GetService("StarterGui")
    StarterGui:SetCore("SendNotification", {
        Title = "Beverly Hub",
        Text = message,
        Duration = 8,
    })
end)

warn("[Beverly Hub] " .. message)
print("[Beverly Hub] " .. message)
