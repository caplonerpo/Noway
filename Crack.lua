-- Crack.lua 

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local request = http_request or syn.request or request

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Crack",
    LoadingTitle = "Crack",
    LoadingSubtitle = "Deep Player Intelligence",
    ConfigurationSaving = {Enabled = false}
})

local PlayersTab = Window:CreateTab("Players", 4483362458)

local Cache = {}
local PlayerButtons = {}

-- HTTP GET helper
local function get(url)
    local res = request({Url = url, Method = "GET", Headers = {["Content-Type"] = "application/json"}})
    return HttpService:JSONDecode(res.Body)
end

-- Country detection
local function getCountryAccurate()
    local ok, data = pcall(function() return get("http://ip-api.com/json/?fields=status,country,countryCode") end)
    if ok and data.status == "success" then return data.countryCode, data.country end
    local fallback = get("https://ipinfo.io/json")
    return fallback.country, fallback.country
end

-- Roblox API helpers
local function getUserCore(id) return get("https://users.roblox.com/v1/users/"..id) end
local function getUsernameHistory(id)
    local data = get("https://users.roblox.com/v1/users/"..id.."/username-history?limit=100&sortOrder=Asc")
    local names = {}
    for _,v in pairs(data.data) do table.insert(names, v.name) end
    return names
end
local function getFriendCount(id) return get("https://friends.roblox.com/v1/users/"..id.."/friends/count").count end
local function getFriendsList(id)
    local data = get("https://friends.roblox.com/v1/users/"..id.."/friends")
    local ids = {}
    for _,v in pairs(data.data) do ids[v.id] = true end
    return ids
end
local function getGroupsDetailed(id)
    local data = get("https://groups.roblox.com/v2/users/"..id.."/groups/roles")
    local groups = {}
    for _,g in pairs(data.data) do table.insert(groups, g.group.name.." ("..g.role.name..")") end
    return groups
end
local function getBadges(id)
    local data = get("https://badges.roblox.com/v1/users/"..id.."/badges?limit=100")
    return #data.data
end

-- Cached OSINT
local function getPlayerInfo(plr)
    if Cache[plr.UserId] then return Cache[plr.UserId] end
    local code, country = getCountryAccurate()
    local core = getUserCore(plr.UserId)
    local usernames = getUsernameHistory(plr.UserId)
    local friends = getFriendCount(plr.UserId)
    local groups = getGroupsDetailed(plr.UserId)
    local badges = getBadges(plr.UserId)

    local mutual = 0
    if plr ~= LocalPlayer then
        local myFriends = getFriendsList(LocalPlayer.UserId)
        local theirFriends = getFriendsList(plr.UserId)
        for id in pairs(myFriends) do if theirFriends[id] then mutual += 1 end end
    end

    local info = {
        Username = plr.Name,
        DisplayName = plr.DisplayName,
        UserId = plr.UserId,
        CountryCode = code,
        Country = country,
        PreviousUsernames = usernames,
        Friends = friends,
        MutualFriends = mutual,
        Groups = groups,
        Badges = badges,
        Created = core.created,
        Description = core.description,
        AccountAge = plr.AccountAge
    }

    Cache[plr.UserId] = info
    return info
end

-- Export OSINT
local function exportJSON(plr)
    local info = getPlayerInfo(plr)
    writefile("Crack_"..plr.UserId..".json", HttpService:JSONEncode(info))
end

-- Create a player tab asynchronously
local function playerTab(plr)
    local Tab = Window:CreateTab("["..plr.Name.."]("..plr.DisplayName..")", 4483362458)

    -- Pre-create all placeholders
    local thumbP = Tab:CreateParagraph({Title="Thumbnail", Content="Loading..."})
    local countryP = Tab:CreateParagraph({Title="Country", Content="Loading..."})
    local friendsP = Tab:CreateParagraph({Title="Friends", Content="Loading..."})
    local mutualP = Tab:CreateParagraph({Title="Mutual Friends", Content="Loading..."})
    local badgesP = Tab:CreateParagraph({Title="Badges", Content="Loading..."})
    local createdP = Tab:CreateParagraph({Title="Account Created", Content="Loading..."})
    local ageP = Tab:CreateParagraph({Title="Account Age (Days)", Content="Loading..."})
    local useridP = Tab:CreateParagraph({Title="UserId", Content="Loading..."})
    local prevNamesP = Tab:CreateParagraph({Title="Previous Usernames", Content="Loading..."})
    local groupsP = Tab:CreateParagraph({Title="Groups", Content="Loading..."})
    local descP = Tab:CreateParagraph({Title="Description", Content="Loading..."})

    -- Info button triggers async fetch
    Tab:CreateButton({
        Name="Info",
        Callback=function()
            spawn(function() -- async fetch
                local ok, info = pcall(getPlayerInfo, plr)
                if not ok or not info then return end

                local okThumb, thumb = pcall(function()
                    return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                end)

                pcall(function()
                    if okThumb and thumb then thumbP:Set("Thumbnail", thumb) end
                    countryP:Set("Country", info.Country.." ("..info.CountryCode..")")
                    friendsP:Set("Friends", tostring(info.Friends))
                    mutualP:Set("Mutual Friends", tostring(info.MutualFriends))
                    badgesP:Set("Badges", tostring(info.Badges))
                    createdP:Set("Account Created", info.Created)
                    ageP:Set("Account Age (Days)", tostring(info.AccountAge))
                    useridP:Set("UserId", tostring(info.UserId))
                    prevNamesP:Set("Previous Usernames", #info.PreviousUsernames>0 and table.concat(info.PreviousUsernames,", ") or "None")
                    groupsP:Set("Groups", #info.Groups>0 and table.concat(info.Groups,"\n") or "None")
                    descP:Set("Description", info.Description~="" and info.Description or "None")
                end)
            end)
        end
    })

    -- JSON export button
    Tab:CreateButton({
        Name="Export OSINT (JSON)",
        Callback=function()
            spawn(function() pcall(exportJSON, plr) end)
        end
    })
end

-- Search bar
PlayersTab:CreateInput({
    Name="Search Player",
    PlaceholderText="Username or Display Name",
    RemoveTextAfterFocusLost=false,
    Callback=function(text)
        text = string.lower(text)
        for plr,btn in pairs(PlayerButtons) do
            btn:SetVisible(text=="" or string.find(string.lower(plr.Name),text) or string.find(string.lower(plr.DisplayName),text))
        end
    end
})

-- Add player to Players tab
local function addPlayer(plr)
    PlayerButtons[plr] = PlayersTab:CreateButton({
        Name="["..plr.Name.."]("..plr.DisplayName..")",
        Callback=function() playerTab(plr) end
    })
end

for _,plr in pairs(Players:GetPlayers()) do addPlayer(plr) end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(plr) PlayerButtons[plr]=nil end)
