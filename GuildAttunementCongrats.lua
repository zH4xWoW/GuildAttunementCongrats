-- GuildAttunementCongrats
-- TBC Classic Anniversary / Interface 20505
-- Listens for Attune guild chat completion announcements and replies with a race/class-aware congrats message.
-- v0.2.5 fixes saved-variable naming and greatly improves Attune guild-chat detection/debugging.

local ADDON_NAME = ...
local AC = CreateFrame("Frame")

local DEFAULTS = {
    enabled = true,
    debug = false,
    announceSelf = false,
    cooldownSeconds = 300,
    minDelay = 0.8,
    maxDelay = 2.4,
    guildChannel = "GUILD",

    -- Race is not available from the TBC guild roster, so this optional lookup
    -- helps the addon pick the most specific race/class message possible.
    whoLookup = true,
    whoTimeout = 2.0,
    whoCooldownSeconds = 10,
}

local HEROIC_KEYWORDS = {
    -- Generic heroic wording
    "heroic", "heroics", "heroic dungeon", "heroic dungeons",

    -- Heroic key item names
    "flamewrought key",
    "reservoir key",
    "auchenai key",
    "warpforged key",
    "key of time",

    -- Reputation/key factions, included because some Attune messages may use the faction/key unlock name
    "honor hold", "thrallmar",
    "cenarion expedition",
    "lower city",
    "the sha'tar", "sha'tar",
    "keepers of time",

    -- Safer dungeon-wing wording. These are only used together with completion text from Attune.
    "hellfire citadel heroic", "coilfang reservoir heroic", "auchindoun heroic",
    "tempest keep heroic", "caverns of time heroic",
    "hellfire heroics", "coilfang heroics", "auchindoun heroics",
    "tempest keep heroics", "caverns of time heroics",

    -- Attune may announce only the attunement/key group without the word heroic.
    "hellfire citadel",
    "coilfang reservoir",
    "auchindoun",
    "tempest keep",
    "caverns of time",

    -- Some versions/exports use shortened heroic key names.
    "hf heroic", "hellfire heroic",
    "cf heroic", "coilfang heroic",
    "auch heroic", "auchindoun heroic",
    "tk heroic", "tempest heroic",
    "cot heroic", "caverns heroic",
}

-- Class/race flavor pools. These work like GuildCongrats: pick a non-repeating line
-- from the most useful bucket and combine it into the final congrats message.
local CLASS_LINES = {
    Warrior = {
        "That key never stood a chance against all that plate and rage.",
        "Another heroic door unlocked by simply charging at the paperwork.",
        "The heroic attunement surrendered before the first Sunder stack.",
    },
    Paladin = {
        "The Light has officially approved this heroic paperwork.",
        "Bubble, blessing, and now a heroic key -- very on brand.",
        "Another holy stamp of approval for the dungeon grind.",
    },
    Hunter = {
        "Your pet probably did half the rep grind, but we will credit you anyway.",
        "Tracking heroic keys now counts as hunter utility.",
        "Another heroic unlocked, another dungeon your pet gets dragged through.",
    },
    Rogue = {
        "Naturally the locked heroic door lost to the rogue.",
        "Sneaking past the requirements would have been easier, but grats anyway.",
        "That heroic key is just a very official lockpick now.",
    },
    Priest = {
        "The spirits, the Light, or the shadows clearly signed off on this one.",
        "Another heroic group gets a little more survivable.",
        "A healer with heroic access is basically guild infrastructure.",
    },
    Shaman = {
        "The elements have spoken: heroic dungeons are open.",
        "Drop a totem for the heroic key grind -- it is finally done.",
        "The attunement has been cleansed, shocked, and officially completed.",
    },
    Mage = {
        "Portals, water, and now heroic access -- the utility package grows.",
        "The heroic key was probably frozen, burned, and polymorphed into submission.",
        "Another dungeon door opened by superior arcane paperwork.",
    },
    Warlock = {
        "Even the heroic key looks slightly fel-corrupted now.",
        "A demon was probably involved, but the attunement counts.",
        "Summoning stones everywhere just got a little more dangerous.",
    },
    Druid = {
        "Bear, cat, tree, moonkin -- and now heroic-ready.",
        "Nature itself apparently endorsed this heroic attunement.",
        "Another form unlocked: heroic dungeon enjoyer.",
    },
}

local RACE_LINES = {
    Human = {
        "Stormwind bureaucracy has nothing on this heroic paperwork.",
        "A very respectable Alliance-approved heroic unlock.",
    },
    Dwarf = {
        "Ironforge should tap a keg for this one.",
        "That heroic key has strong ale-and-anvil energy.",
    },
    ["Night Elf"] = {
        "Elune clearly gave this heroic grind a nod.",
        "Very graceful, very ancient, very heroic-ready.",
    },
    Gnome = {
        "Tiny character, huge heroic access energy.",
        "The key may be bigger than you, but it still works.",
    },
    Draenei = {
        "The naaru are probably glowing a little brighter for this one.",
        "Exodar-approved heroic access achieved.",
    },
    Orc = {
        "Lok'tar -- heroic access earned the hard way.",
        "That heroic door is about to learn what zug zug means.",
    },
    Undead = {
        "Death was not enough, and apparently neither was the rep grind.",
        "A heroic key in cold dead hands still opens the door.",
    },
    Tauren = {
        "The Earthmother approves of this heroic-sized achievement.",
        "Large hooves, larger heroic energy.",
    },
    Troll = {
        "Da heroic grind is done, mon.",
        "The key has been blessed with premium troll swagger.",
    },
    ["Blood Elf"] = {
        "Silvermoon style has officially entered heroic mode.",
        "Elegant, dramatic, and now heroic-ready.",
    },
}

local OPENER_LINES = {
    "Grats {name} on completing {attune}!",
    "Huge grats {name} -- {attune} complete!",
    "Nice work {name}, {attune} is done!",
    "Congrats {name}! Heroic access upgraded: {attune}.",
}

local UNKNOWN_INFO_LINES = {
    "Grats {name} on completing {attune}! Heroic access secured.",
    "Huge grats {name} -- {attune} complete!",
    "Nice work {name}, {attune} is done!",
}

local CLASS_TOKEN_TO_DISPLAY = {
    WARRIOR = "Warrior",
    PALADIN = "Paladin",
    HUNTER = "Hunter",
    ROGUE = "Rogue",
    PRIEST = "Priest",
    SHAMAN = "Shaman",
    MAGE = "Mage",
    WARLOCK = "Warlock",
    DRUID = "Druid",
}

local CLASS_ALIASES = {
    warrior = "Warrior",
    paladin = "Paladin",
    hunter = "Hunter",
    rogue = "Rogue",
    priest = "Priest",
    shaman = "Shaman",
    mage = "Mage",
    warlock = "Warlock",
    druid = "Druid",
}

local RACE_ALIASES = {
    human = "Human",
    dwarf = "Dwarf",
    ["night elf"] = "Night Elf",
    nightelf = "Night Elf",
    gnome = "Gnome",
    draenei = "Draenei",
    orc = "Orc",
    undead = "Undead",
    scourge = "Undead",
    tauren = "Tauren",
    troll = "Troll",
    ["blood elf"] = "Blood Elf",
    bloodelf = "Blood Elf",
}

local recent = {}
local characterCache = {}
local pendingByName = {}
local lastUsed = {
    opener = {},
    race = {},
    class = {},
    fallback = {},
}
local lastWhoRequestAt = 0

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GuildAttunementCongrats:|r " .. tostring(msg))
end

local function Debug(msg)
    if GuildAttunementCongratsDB and GuildAttunementCongratsDB.debug then
        Print("debug: " .. tostring(msg))
    end
end

local function StripChatCodes(text)
    text = tostring(text or "")
    -- Strip color codes, links, textures, raid icons, and some common invisible/control chars.
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("{%a+%d*}", "")
    text = text:gsub("{rt%d}", "")
    text = text:gsub("[%z\1-\31]", "")
    return text
end

local function Trim(text)
    text = tostring(text or "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Lower(text)
    return string.lower(tostring(text or ""))
end

local function CleanPlayerName(name)
    name = Trim(name or "")
    name = name:gsub("^%[", ""):gsub("%]$", "")
    if Ambiguate then
        name = Ambiguate(name, "guild")
    else
        name = name:gsub("%-.*$", "")
    end
    return name
end

local function NormalizeClass(className, classToken)
    if classToken and CLASS_TOKEN_TO_DISPLAY[string.upper(tostring(classToken))] then
        return CLASS_TOKEN_TO_DISPLAY[string.upper(tostring(classToken))]
    end

    if not className or className == "" then return nil end
    local raw = tostring(className)
    if CLASS_TOKEN_TO_DISPLAY[string.upper(raw)] then
        return CLASS_TOKEN_TO_DISPLAY[string.upper(raw)]
    end

    local lower = Lower(raw)
    return CLASS_ALIASES[lower] or raw
end

local function NormalizeRace(raceName)
    if not raceName or raceName == "" then return nil end
    local raw = tostring(raceName)
    local lower = Lower(raw)
    local compact = lower:gsub("%s+", "")
    return RACE_ALIASES[lower] or RACE_ALIASES[compact] or raw
end

local function makeKey(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    return table.concat(parts, ":")
end

local function PickNonRepeating(pool, bucket, key)
    if type(pool) ~= "table" or #pool == 0 then return nil end
    local count = #pool
    if count == 1 then
        bucket[key] = 1
        return pool[1]
    end

    local idx = math.random(1, count)
    local lastIdx = bucket[key]
    local tries = 0
    while lastIdx and idx == lastIdx and tries < 20 do
        idx = math.random(1, count)
        tries = tries + 1
    end

    bucket[key] = idx
    return pool[idx]
end

local function AC_CreateTimer(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
        return
    end

    local timerFrame = CreateFrame("Frame")
    local elapsed = 0
    timerFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            self:Hide()
            self:SetScript("OnUpdate", nil)
            callback()
        end
    end)
    timerFrame:Show()
end

local function FormatMessage(template, name, attune, info)
    info = info or {}
    local raceName = info.race or "Unknown"
    local className = info.class or "Adventurer"

    template = tostring(template or UNKNOWN_INFO_LINES[1])
    template = template:gsub("{name}", name or "guildie")
    template = template:gsub("{attune}", attune or "their heroic attunement")
    template = template:gsub("{race}", raceName)
    template = template:gsub("{class}", className)
    template = template:gsub("{racelower}", Lower(raceName))
    template = template:gsub("{classlower}", Lower(className))
    return template
end

local function PickFallbackMessage()
    return PickNonRepeating(UNKNOWN_INFO_LINES, lastUsed.fallback, "unknown") or UNKNOWN_INFO_LINES[1]
end

local function PickRaceClassMessage(name, attune, info)
    info = info or {}

    local className = NormalizeClass(info.class, info.classToken)
    local raceName = NormalizeRace(info.race)

    if not className and not raceName then
        return FormatMessage(PickFallbackMessage(), name, attune, info)
    end

    local opener = PickNonRepeating(OPENER_LINES, lastUsed.opener, "opener") or OPENER_LINES[1]
    local parts = { FormatMessage(opener, name, attune, { race = raceName, class = className }) }

    if raceName and RACE_LINES[raceName] then
        local line = PickNonRepeating(RACE_LINES[raceName], lastUsed.race, raceName)
        if line then table.insert(parts, FormatMessage(line, name, attune, { race = raceName, class = className })) end
    end

    if className and CLASS_LINES[className] then
        local line = PickNonRepeating(CLASS_LINES[className], lastUsed.class, className)
        if line then table.insert(parts, FormatMessage(line, name, attune, { race = raceName, class = className })) end
    end

    -- If we only found an unknown/localized class with no matching flavor pool,
    -- still include a small race/class-specific fallback.
    if #parts == 1 and (raceName or className) then
        table.insert(parts, FormatMessage("{race} {class} heroic access confirmed.", name, attune, { race = raceName, class = className }))
    end

    return table.concat(parts, " ")
end

local function CacheCharacter(name, raceName, className, classToken, gender)
    name = CleanPlayerName(name)
    if not name or name == "" then return end

    characterCache[name] = characterCache[name] or {}
    local entry = characterCache[name]

    local normalizedRace = NormalizeRace(raceName)
    local normalizedClass = NormalizeClass(className, classToken)

    if normalizedRace and normalizedRace ~= "" and normalizedRace ~= "Unknown" then
        entry.race = normalizedRace
    end
    if normalizedClass and normalizedClass ~= "" and normalizedClass ~= "Unknown" then
        entry.class = normalizedClass
    end
    if classToken and classToken ~= "" then
        entry.classToken = tostring(classToken)
    end
    if gender then
        entry.gender = gender
    end
    entry.updated = time()
end

local function GetCachedCharacter(name)
    name = CleanPlayerName(name)
    return characterCache[name]
end

local function ScanVisibleUnitsForCharacter(name)
    name = CleanPlayerName(name)
    if not name or name == "" then return end

    local units = { "player", "target", "focus", "mouseover", "party1", "party2", "party3", "party4" }
    for i = 1, 40 do
        units[#units + 1] = "raid" .. i
    end

    for _, unit in ipairs(units) do
        if UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit) then
            local unitName = UnitName(unit)
            if unitName and CleanPlayerName(unitName) == name then
                local raceName = nil
                local className = nil
                local classToken = nil
                local gender = nil

                if UnitRace then raceName = UnitRace(unit) end
                if UnitClass then className, classToken = UnitClass(unit) end
                if UnitSex then gender = UnitSex(unit) end

                CacheCharacter(name, raceName, className, classToken, gender)
                return characterCache[name]
            end
        end
    end
end

local function ScanGuildRoster()
    if not IsInGuild or not IsInGuild() then return end
    if not GetNumGuildMembers or not GetGuildRosterInfo then return end

    local num = GetNumGuildMembers()
    if not num or num <= 0 then return end

    for i = 1, num do
        -- TBC-ish return order:
        -- name, rank, rankIndex, level, classDisplayName, zone, note, officernote, online, status, classFileName
        local fullName, _, _, _, classDisplayName, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
        if fullName then
            CacheCharacter(fullName, nil, classDisplayName, classFileName, nil)
        end
    end
end

local function IsHeroicAttunement(attuneText)
    local lower = Lower(attuneText)
    for _, keyword in ipairs(HEROIC_KEYWORDS) do
        if lower:find(keyword, 1, true) then
            return true, keyword
        end
    end
    return false, nil
end

local function ContainsAttuneMarker(text)
    local lower = Lower(text)
    -- Support common formats: [Attune], Attune:, and Attune - .
    return lower:find("%[attune%]") or lower:find("^%s*attune[%s:%-]") or lower:find("%sattune[%s:%-]")
end

local function StripAttunePrefix(text)
    text = Trim(text or "")
    text = text:gsub("^%s*%[Attune%]%s*", "")
    text = text:gsub("^%s*%[attune%]%s*", "")
    text = text:gsub("^%s*Attune%s*[:%-]%s*", "")
    text = text:gsub("^%s*attune%s*[:%-]%s*", "")
    text = text:gsub("^[%s:%-]+", "")
    return Trim(text)
end

local function StripLeadingDecorations(text)
    text = Trim(text or "")
    -- Handles formats like "[Player]", "<Player>", or "Player:".
    text = text:gsub("^%[([^%]]+)%]%s*", "%1 ")
    text = text:gsub("^<([^>]+)>%s*", "%1 ")
    text = text:gsub("^([^:]+):%s+", "%1 ")
    return Trim(text)
end

local function ParseNameAndAttuneFromBody(body)
    body = StripLeadingDecorations(body)

    local patterns = {
        "^(.-)%s+has%s+completed%s+the%s+attunement%s+for%s+(.+)$",
        "^(.-)%s+has%s+completed%s+attunement%s+for%s+(.+)$",
        "^(.-)%s+has%s+completed%s+the%s+(.+)%s+attunement$",
        "^(.-)%s+has%s+completed%s+(.+)$",
        "^(.-)%s+completed%s+the%s+attunement%s+for%s+(.+)$",
        "^(.-)%s+completed%s+attunement%s+for%s+(.+)$",
        "^(.-)%s+completed%s+the%s+(.+)%s+attunement$",
        "^(.-)%s+completed%s+(.+)$",
        "^(.-)%s+is%s+now%s+attuned%s+to%s+(.+)$",
        "^(.-)%s+is%s+attuned%s+to%s+(.+)$",
        "^(.-)%s+became%s+attuned%s+to%s+(.+)$",
        "^(.-)%s+has%s+become%s+attuned%s+to%s+(.+)$",
        "^(.-)%s+earned%s+(.+)$",
        "^(.-)%s+unlocked%s+(.+)$",
    }

    for _, pattern in ipairs(patterns) do
        local name, attune = body:match(pattern)
        if name and attune then
            return name, attune
        end
    end

    return nil, nil
end

local function ParseAttuneGuildCompletion(message, author)
    local clean = StripChatCodes(message)

    -- Require an Attune marker somewhere so normal guild chat does not trigger it.
    if not ContainsAttuneMarker(clean) then
        return nil
    end

    local body = StripAttunePrefix(clean)
    local name, attune = ParseNameAndAttuneFromBody(body)

    -- Fallback: some Attune messages are authored by the player and only say the attunement in the body.
    if (not name or not attune) and author and author ~= "" then
        local authorShort = CleanPlayerName(author)
        local lowerBody = Lower(body)
        local possibleAttune = nil

        possibleAttune = body:match("completed%s+the%s+attunement%s+for%s+(.+)$")
            or body:match("completed%s+attunement%s+for%s+(.+)$")
            or body:match("completed%s+the%s+(.+)%s+attunement$")
            or body:match("completed%s+(.+)$")
            or body:match("attuned%s+to%s+(.+)$")
            or body:match("unlocked%s+(.+)$")

        if possibleAttune and authorShort ~= "" then
            name, attune = authorShort, possibleAttune
        elseif (lowerBody:find("complete") or lowerBody:find("attuned") or lowerBody:find("unlocked")) and IsHeroicAttunement(body) then
            name, attune = authorShort, body
        end
    end

    if not name or not attune then
        Debug("Saw Attune guild message but could not parse player/attunement: " .. clean)
        return nil
    end

    name = CleanPlayerName(name)
    attune = Trim(attune:gsub("^[%s:%-]+", ""):gsub("[%!%.]+$", ""))
    attune = attune:gsub("^the%s+", "")
    attune = attune:gsub("%s+attunement$", "")

    if name == "" or attune == "" then
        Debug("Saw Attune guild message but parsed empty name/attunement: " .. clean)
        return nil
    end

    -- Check both the attunement text and the full line. Some Attune versions put
    -- the heroic/key wording outside the final attunement name.
    local isHeroic, matchedKeyword = IsHeroicAttunement(attune)
    if not isHeroic then
        isHeroic, matchedKeyword = IsHeroicAttunement(clean)
    end

    if not isHeroic then
        Debug("Ignored Attune completion because it did not look heroic: " .. clean)
        return nil
    end

    return name, attune, matchedKeyword, clean
end

local function ShouldThrottle(name, attune)
    local db = GuildAttunementCongratsDB or DEFAULTS
    local key = Lower(name .. "|" .. attune)
    local now = time()
    local last = recent[key]
    if last and (now - last) < (db.cooldownSeconds or 300) then
        return true
    end
    recent[key] = now
    return false
end

local function SendCongrats(name, attune, info)
    local db = GuildAttunementCongratsDB or DEFAULTS
    local msg = PickRaceClassMessage(name, attune, info)
    local channel = db.guildChannel or "GUILD"

    Debug("Sending to " .. channel .. ": " .. msg)
    SendChatMessage(msg, channel)
end

local function ScheduleCongrats(name, attune, info)
    local db = GuildAttunementCongratsDB or DEFAULTS
    local minDelay = tonumber(db.minDelay) or DEFAULTS.minDelay
    local maxDelay = tonumber(db.maxDelay) or DEFAULTS.maxDelay
    if maxDelay < minDelay then maxDelay = minDelay end

    local delay = minDelay
    if maxDelay > minDelay then
        delay = minDelay + (math.random() * (maxDelay - minDelay))
    end

    AC_CreateTimer(delay, function()
        SendCongrats(name, attune, info)
    end)
end

local function FlushPendingForName(name)
    name = CleanPlayerName(name)
    local list = pendingByName[name]
    if type(list) ~= "table" or #list == 0 then return end

    pendingByName[name] = nil
    local info = GetCachedCharacter(name) or {}

    for _, pending in ipairs(list) do
        ScheduleCongrats(pending.name, pending.attune, info)
    end
end

local function QueuePendingForWho(name, attune)
    name = CleanPlayerName(name)
    pendingByName[name] = pendingByName[name] or {}
    table.insert(pendingByName[name], { name = name, attune = attune, queued = time() })

    local db = GuildAttunementCongratsDB or DEFAULTS
    local timeout = tonumber(db.whoTimeout) or DEFAULTS.whoTimeout
    AC_CreateTimer(timeout, function()
        if pendingByName[name] then
            Debug("Who lookup timed out for " .. name .. "; sending with cached/fallback info.")
            FlushPendingForName(name)
        end
    end)
end

local function SetWhoResultsHidden()
    if C_FriendList and C_FriendList.SetWhoToUi then
        pcall(C_FriendList.SetWhoToUi, false)
    elseif SetWhoToUI then
        pcall(SetWhoToUI, 0)
    end
end

local function SendWhoQuery(query)
    if C_FriendList and C_FriendList.SendWho then
        return pcall(C_FriendList.SendWho, query)
    elseif SendWho then
        return pcall(SendWho, query)
    end
    return false
end

local function TryWhoLookup(name)
    local db = GuildAttunementCongratsDB or DEFAULTS
    if not db.whoLookup then return false end

    local now = time()
    if lastWhoRequestAt and lastWhoRequestAt > 0 and (now - lastWhoRequestAt) < (db.whoCooldownSeconds or 10) then
        Debug("Who lookup skipped due to cooldown for " .. name)
        return false
    end

    SetWhoResultsHidden()
    lastWhoRequestAt = now

    -- n-Name asks the Who system to search by character name.
    local ok = SendWhoQuery("n-" .. name)
    if ok then
        Debug("Requested hidden who lookup for " .. name)
    else
        Debug("Who lookup API unavailable for " .. name)
    end
    return ok
end

local function GetWhoCount()
    if C_FriendList and C_FriendList.GetNumWhoResults then
        local ok, count = pcall(C_FriendList.GetNumWhoResults)
        if ok then return count end
    end
    if GetNumWhoResults then
        local ok, count = pcall(GetNumWhoResults)
        if ok then return count end
    end
    return 0
end

local function GetWhoResult(index)
    if C_FriendList and C_FriendList.GetWhoInfo then
        local ok, a, b, c, d, e, f, g, h = pcall(C_FriendList.GetWhoInfo, index)
        if ok then
            if type(a) == "table" then
                return a.fullName or a.name, a.fullGuildName or a.guild, a.level, a.raceStr or a.race, a.classStr or a.className or a.class, a.area or a.zone, a.filename or a.classFileName, a.gender
            end
            return a, b, c, d, e, f, g, h
        end
    end

    if GetWhoInfo then
        local ok, name, guild, level, race, className, zone, classFileName, gender = pcall(GetWhoInfo, index)
        if ok then return name, guild, level, race, className, zone, classFileName, gender end
    end

    return nil
end

local function HandleWhoListUpdate()
    local count = GetWhoCount()
    if not count or count <= 0 then return end

    for i = 1, count do
        local whoName, _, _, raceName, className, _, classToken, gender = GetWhoResult(i)
        if whoName then
            local shortName = CleanPlayerName(whoName)
            CacheCharacter(shortName, raceName, className, classToken, gender)

            if pendingByName[shortName] then
                Debug("Who lookup found " .. shortName .. " as " .. tostring(NormalizeRace(raceName) or "?") .. " " .. tostring(NormalizeClass(className, classToken) or "?"))
                FlushPendingForName(shortName)
            end
        end
    end
end

local function ResolveAndScheduleCongrats(name, attune)
    name = CleanPlayerName(name)

    -- First try visible units, because this gives race instantly when the player is in party/raid/target/mouseover.
    ScanVisibleUnitsForCharacter(name)

    local info = GetCachedCharacter(name) or {}
    if info.race or not (GuildAttunementCongratsDB and GuildAttunementCongratsDB.whoLookup) then
        ScheduleCongrats(name, attune, info)
        return
    end

    -- Guild roster generally gives class but not race. Try a hidden who lookup so the final line can use both.
    QueuePendingForWho(name, attune)
    local requested = TryWhoLookup(name)
    if not requested then
        FlushPendingForName(name)
    end
end

local function OnGuildMessage(message, author)
    local db = GuildAttunementCongratsDB or DEFAULTS
    if not db.enabled then return end

    local name, attune, keyword, cleanMessage = ParseAttuneGuildCompletion(message, author)
    if not name then return end

    if author and author ~= "" then
        -- The Attune guild message is usually sent by the character who completed the attunement.
        -- This gives us a clean name even if Attune uses a realm suffix in the chat author field.
        local authorShort = CleanPlayerName(author)
        if authorShort == name then
            ScanVisibleUnitsForCharacter(authorShort)
        end
    end

    local playerName = UnitName("player")
    if not db.announceSelf and playerName and CleanPlayerName(name) == CleanPlayerName(playerName) then
        Debug("Ignored own Attune completion: " .. attune)
        return
    end

    if ShouldThrottle(name, attune) then
        Debug("Ignored duplicate completion for " .. name .. ": " .. attune)
        return
    end

    Debug("Matched heroic keyword '" .. tostring(keyword) .. "' for " .. name .. ": " .. attune)
    ResolveAndScheduleCongrats(name, attune)
end

local function ShowHelp()
    Print("/gac on - enable")
    Print("/gac off - disable")
    Print("/gac status - show settings")
    Print("/gac debug - toggle debug output, including ignored Attune lines")
    Print("/gac self - toggle congratulating yourself")
    Print("/gac who - toggle hidden /who race lookup")
    Print("/gac scan - refresh guild roster cache")
    Print("/gac cache <name> - show cached race/class for a character")
    Print("/gac reset - reset saved settings")
    Print("/gac test [race] [class] - preview a fake Attune heroic message without sending to guild")
    Print("/gac parse <Attune line> - test whether a pasted Attune guild line matches")
end

local function ShowStatus()
    local db = GuildAttunementCongratsDB or DEFAULTS
    Print("Enabled: " .. tostring(db.enabled))
    Print("Debug: " .. tostring(db.debug))
    Print("Congratulate self: " .. tostring(db.announceSelf))
    Print("Race/class messages: always on")
    Print("Hidden /who race lookup: " .. tostring(db.whoLookup))
    Print("Cooldown seconds: " .. tostring(db.cooldownSeconds))
end

local function ShowCachedCharacter(rest)
    local name = CleanPlayerName(rest or "")
    if name == "" then
        Print("Usage: /gac cache CharacterName")
        return
    end

    ScanVisibleUnitsForCharacter(name)
    local info = GetCachedCharacter(name)
    if not info then
        Print("No cached info for " .. name .. ". Try /gac scan, target the player, or wait for /who lookup after an Attune message.")
        return
    end

    Print(name .. ": race=" .. tostring(info.race or "?") .. ", class=" .. tostring(info.class or info.classToken or "?") .. ", updated=" .. tostring(info.updated or "?"))
end

local function PreviewTest(rest)
    rest = Trim(rest or "")
    local raceName, className = rest:match("^(.-)%s+([^%s]+)$")

    -- Handle two-word races for the preview command.
    if rest == "" then
        raceName, className = "Human", "Paladin"
    else
        local words = {}
        for word in rest:gmatch("%S+") do words[#words + 1] = word end
        if #words >= 3 then
            raceName = words[1] .. " " .. words[2]
            className = words[3]
        elseif #words == 2 then
            raceName = words[1]
            className = words[2]
        elseif #words == 1 then
            raceName = nil
            className = words[1]
        end
    end

    local fake = "[Attune] Testguildie has completed Heroic Hellfire Citadel"
    local name, attune, keyword = ParseAttuneGuildCompletion(fake, "Testguildie")
    if name then
        local info = { race = NormalizeRace(raceName), class = NormalizeClass(className) }
        Print("test matched keyword '" .. tostring(keyword) .. "'.")
        Print("preview: " .. PickRaceClassMessage(name, attune, info))
    else
        Print("test failed to match.")
    end
end

local function PreviewParse(rest)
    rest = Trim(rest or "")
    if rest == "" then
        Print("Usage: /gac parse [Attune guild chat line]")
        return
    end

    local name, attune, keyword = ParseAttuneGuildCompletion(rest, "")
    if name then
        Print("parse matched: name=" .. tostring(name) .. ", attune=" .. tostring(attune) .. ", keyword=" .. tostring(keyword))
    else
        Print("parse did not match as a heroic Attune completion. Turn on /gac debug for the ignored reason.")
    end
end

local function SlashHandler(input)
    input = Trim(input or "")
    local cmd, rest = input:match("^(%S+)%s*(.-)$")
    cmd = Lower(cmd or "")
    rest = Trim(rest or "")

    local db = GuildAttunementCongratsDB or CopyDefaults(DEFAULTS, {})
    GuildAttunementCongratsDB = db

    if cmd == "on" or cmd == "enable" then
        db.enabled = true
        Print("enabled.")
    elseif cmd == "off" or cmd == "disable" then
        db.enabled = false
        Print("disabled.")
    elseif cmd == "debug" then
        db.debug = not db.debug
        Print("debug is now " .. tostring(db.debug) .. ".")
    elseif cmd == "self" then
        db.announceSelf = not db.announceSelf
        Print("congratulate self is now " .. tostring(db.announceSelf) .. ".")
    elseif cmd == "who" then
        db.whoLookup = not db.whoLookup
        Print("hidden /who race lookup is now " .. tostring(db.whoLookup) .. ".")
    elseif cmd == "scan" or cmd == "refresh" then
        if IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
        ScanGuildRoster()
        Print("guild roster cache refreshed. Class data should be available; race data needs target/party/raid or /who lookup.")
    elseif cmd == "cache" then
        ShowCachedCharacter(rest)
    elseif cmd == "status" then
        ShowStatus()
    elseif cmd == "reset" then
        GuildAttunementCongratsDB = CopyDefaults(DEFAULTS, {})
        Print("settings reset.")
    elseif cmd == "test" then
        PreviewTest(rest)
    elseif cmd == "parse" then
        PreviewParse(rest)
    else
        ShowHelp()
    end
end

AC:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName == ADDON_NAME then
            -- In-session compatibility: if the old addon name was loaded before this rename in the same UI session, reuse its settings.
            if type(GuildAttunementCongratsDB) ~= "table" and type(GuildGuildAttunementCongratsDB) == "table" then
                GuildAttunementCongratsDB = GuildGuildAttunementCongratsDB
            elseif type(GuildAttunementCongratsDB) ~= "table" and type(AttuneHeroicCongratsDB) == "table" then
                GuildAttunementCongratsDB = AttuneHeroicCongratsDB
            end
            GuildAttunementCongratsDB = CopyDefaults(DEFAULTS, GuildAttunementCongratsDB)
            -- Clean up settings from v0.1/v0.2 custom-message mode.
            GuildAttunementCongratsDB.messages = nil
            GuildAttunementCongratsDB.useRaceClassMessages = nil
            if not AC._seeded then
                AC._seeded = true
                math.randomseed(time())
            end
            Print("loaded. Type /gac for help.")
        end
    elseif event == "PLAYER_LOGIN" then
        if IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
        ScanGuildRoster()
    elseif event == "PLAYER_GUILD_UPDATE" then
        if IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
        ScanGuildRoster()
    elseif event == "GUILD_ROSTER_UPDATE" then
        ScanGuildRoster()
    elseif event == "WHO_LIST_UPDATE" then
        HandleWhoListUpdate()
    elseif event == "CHAT_MSG_GUILD" then
        local message, author = ...
        OnGuildMessage(message, author)
    end
end)

AC:RegisterEvent("ADDON_LOADED")
AC:RegisterEvent("PLAYER_LOGIN")
AC:RegisterEvent("PLAYER_GUILD_UPDATE")
AC:RegisterEvent("GUILD_ROSTER_UPDATE")
AC:RegisterEvent("WHO_LIST_UPDATE")
AC:RegisterEvent("CHAT_MSG_GUILD")

SLASH_GUILDATTUNEMENTCONGRATS1 = "/gac"
SLASH_GUILDATTUNEMENTCONGRATS2 = "/guildattunementcongrats"
SlashCmdList["GUILDATTUNEMENTCONGRATS"] = SlashHandler
