local ADDON_NAME = "WanderingGaia"
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME, "Version")
local L = WanderingGaia_L

local PI = math.pi
local TWO_PI = PI * 2

local BELL_TEXTURE = "Interface\\AddOns\\WanderingGaia\\artwork\\WanderingGaia_BellSwing_256x64"
local BELL_SOUND = "Interface\\AddOns\\WanderingGaia\\artwork\\gaiasbell.wav"
local COMM_PREFIX = "WanderingGaia"
local RING_SOUND_DURATION = 1.57
local RING_THROTTLE = RING_SOUND_DURATION * 2
local POSITION_REQUEST_INTERVAL = 1.0

local BOP = {
    spellIDs = { 1022, 5599, 10278 },
    spellIDSet = {
        [1022] = true,
        [5599] = true,
        [10278] = true,
    },
    ranks = {
        [1022] = {
            duration = 6.0,
            sound = "Interface\\AddOns\\WanderingGaia\\artwork\\cena_r1.wav",
        },
        [5599] = {
            duration = 8.0,
            sound = "Interface\\AddOns\\WanderingGaia\\artwork\\cena_r2.wav",
        },
        [10278] = {
            duration = 10.0,
            sound = "Interface\\AddOns\\WanderingGaia\\artwork\\cena.wav",
        },
    },
    fallbackIcon = "Interface\\Icons\\Spell_Holy_SealOfProtection",
    auraWait = 1.5,
}
local POSITION_INTERVAL = 0.05
local COORDS_INTERVAL = 0.10
local ANIMATION_INTERVAL = 0.07
local SETTINGS_REVISION = 2

local DEFAULT_SETTINGS = {
    minimumRange = 0,
    originX = 0,
    originY = -10,
    innerRadiusX = 5,
    innerRadiusY = 15,
    outerRadiusX = 40,
    outerRadiusUp = 60,
    outerRadiusDown = 25,
    curveDistance2 = 10,
    curveRadius2 = 20,
    curveDistance3 = 20,
    curveRadius3 = 60,
    curveDistance4 = 44,
    curveRadius4 = 80,
    curveDistance5 = 80,
    curveRadius5 = 100,
    nearSize = 64,
    farSize = 16,
    smoothing = 50,
}

local settings = {}
local testEnabled = false
local coordsEnabled = false
local positionElapsed = 0
local coordsElapsed = 0
local animationElapsed = 0
local animationIndex = 1
local hasSmoothedPosition = false
local smoothedX = 0
local smoothedY = 0

local geometry = {
    hasPlayer = false,
    hasTarget = false,
    valid = false,
}

local configFrame = nil
local coordsFrame = nil
local coordsText = nil
local configFields = {}
local curvePreview = nil
local curveBars = {}
local curveMarkers = {}
local settingsExportBox = nil
local configStatus = nil
local deadzoneOverlays = {}

local runtimeMode = "client"
local knownClients = {}
local knownRingers = {}
local outgoingRings = {}
local incomingRings = {}
local pendingBopCast = nil
local bopPresentation = {
    frame = nil,
    icon = nil,
    animation = nil,
    animationTexture = nil,
    pending = nil,
    active = false,
    startedAt = 0,
    duration = 0,
}
local debugClients = {}
local debugUnitOverrides = {}
local controlButton = nil
local controlTexture = nil
local controlAnimationElapsed = 0
local controlAnimationIndex = 1
local lastRingSentAt = {}
local HandleControlClick

local ApplyConfigFields
local ResetConfigDefaults
local FocusSettingsExport

local swingFrames = {
    { 1, false },
    { 2, false },
    { 3, false },
    { 4, false },
    { 3, false },
    { 2, false },
    { 1, false },
    { 2, true },
    { 3, true },
    { 4, true },
    { 3, true },
    { 2, true },
    { 1, false },
}

local bell = CreateFrame("Frame", "WanderingGaiaBellPreview", UIParent)
bell:SetWidth(DEFAULT_SETTINGS.nearSize)
bell:SetHeight(DEFAULT_SETTINGS.nearSize)
bell:SetFrameStrata("HIGH")
bell:Hide()

local bellTexture = bell:CreateTexture(nil, "ARTWORK")
bellTexture:SetAllPoints(bell)
bellTexture:SetTexture(BELL_TEXTURE)

local function PrintMessage(message)
    if DEFAULT_CHAT_FRAME and message then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local function FormatNumber(value)
    if value == math.floor(value) then
        return tostring(math.floor(value))
    end

    return string.format("%.1f", value)
end

local function FormatOptionalNumber(value)
    if value == nil then
        return "n/a"
    end

    return string.format("%.2f", value)
end

local function CopyDefaults(target)
    local key, value

    for key, value in pairs(DEFAULT_SETTINGS) do
        target[key] = value
    end
end

local function FillMissingDefaults(target)
    local key, value

    for key, value in pairs(DEFAULT_SETTINGS) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

local function NormalizeSettings(target)
    -- User-entered tuning values are intentionally not capped or silently
    -- reshaped. Extreme values are valid experiments; only non-numeric input
    -- falls back to the configured default.
    target.minimumRange = tonumber(target.minimumRange) or DEFAULT_SETTINGS.minimumRange
    target.originX = tonumber(target.originX) or DEFAULT_SETTINGS.originX
    target.originY = tonumber(target.originY) or DEFAULT_SETTINGS.originY

    target.innerRadiusX = tonumber(target.innerRadiusX) or DEFAULT_SETTINGS.innerRadiusX
    target.innerRadiusY = tonumber(target.innerRadiusY) or DEFAULT_SETTINGS.innerRadiusY
    target.outerRadiusX = tonumber(target.outerRadiusX) or DEFAULT_SETTINGS.outerRadiusX
    target.outerRadiusUp = tonumber(target.outerRadiusUp) or DEFAULT_SETTINGS.outerRadiusUp
    target.outerRadiusDown = tonumber(target.outerRadiusDown) or DEFAULT_SETTINGS.outerRadiusDown

    target.curveDistance2 = tonumber(target.curveDistance2) or DEFAULT_SETTINGS.curveDistance2
    target.curveDistance3 = tonumber(target.curveDistance3) or DEFAULT_SETTINGS.curveDistance3
    target.curveDistance4 = tonumber(target.curveDistance4) or DEFAULT_SETTINGS.curveDistance4
    target.curveDistance5 = tonumber(target.curveDistance5) or DEFAULT_SETTINGS.curveDistance5

    target.curveRadius2 = tonumber(target.curveRadius2) or DEFAULT_SETTINGS.curveRadius2
    target.curveRadius3 = tonumber(target.curveRadius3) or DEFAULT_SETTINGS.curveRadius3
    target.curveRadius4 = tonumber(target.curveRadius4) or DEFAULT_SETTINGS.curveRadius4
    target.curveRadius5 = tonumber(target.curveRadius5) or DEFAULT_SETTINGS.curveRadius5

    target.nearSize = tonumber(target.nearSize) or DEFAULT_SETTINGS.nearSize
    target.farSize = tonumber(target.farSize) or DEFAULT_SETTINGS.farSize
    target.smoothing = tonumber(target.smoothing) or DEFAULT_SETTINGS.smoothing
end
local function InitializeSettings()
    local savedRuntimeMode = nil

    if type(WanderingGaiaDB) == "table"
        and (WanderingGaiaDB.runtimeMode == "client" or WanderingGaiaDB.runtimeMode == "ringer")
    then
        savedRuntimeMode = WanderingGaiaDB.runtimeMode
    end

    if type(WanderingGaiaDB) ~= "table" or WanderingGaiaDB.settingsRevision ~= SETTINGS_REVISION then
        -- Revision 2 intentionally resets all previous tuning so the tested
        -- profile becomes the actual starting point after this update.
        WanderingGaiaDB = {}
        CopyDefaults(WanderingGaiaDB)
        WanderingGaiaDB.settingsRevision = SETTINGS_REVISION
    else
        FillMissingDefaults(WanderingGaiaDB)
        NormalizeSettings(WanderingGaiaDB)
    end

    runtimeMode = savedRuntimeMode or "client"
    WanderingGaiaDB.runtimeMode = runtimeMode
    settings = WanderingGaiaDB
end
CopyDefaults(settings)
NormalizeSettings(settings)

local function Atan2(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 then
        if y >= 0 then
            return math.atan(y / x) + PI
        else
            return math.atan(y / x) - PI
        end
    elseif y > 0 then
        return PI / 2
    elseif y < 0 then
        return -PI / 2
    end

    return 0
end

local function NormalizeAngle(angle)
    while angle > PI do
        angle = angle - TWO_PI
    end

    while angle < -PI do
        angle = angle + TWO_PI
    end

    return angle
end

local function SetBellSpriteTexture(texture, frameIndex, mirrored)
    local left = (frameIndex - 1) * 0.25
    local right = frameIndex * 0.25

    if mirrored then
        texture:SetTexCoord(right, left, 0, 1)
    else
        texture:SetTexCoord(left, right, 0, 1)
    end
end

local function SetBellSprite(frameIndex, mirrored)
    SetBellSpriteTexture(bellTexture, frameIndex, mirrored)
end

local function Interpolate(distance, distanceA, radiusA, distanceB, radiusB)
    local span = distanceB - distanceA

    if span <= 0 then
        return radiusB
    end

    return radiusA + (((distance - distanceA) / span) * (radiusB - radiusA))
end

local function DistancePercent(distance)
    local d1 = settings.minimumRange
    local d2 = settings.curveDistance2
    local d3 = settings.curveDistance3
    local d4 = settings.curveDistance4
    local d5 = settings.curveDistance5
    local r2 = settings.curveRadius2 / 100
    local r3 = settings.curveRadius3 / 100
    local r4 = settings.curveRadius4 / 100
    local r5 = settings.curveRadius5 / 100

    if distance <= d1 then
        return 0
    elseif distance <= d2 then
        return Interpolate(distance, d1, 0, d2, r2)
    elseif distance <= d3 then
        return Interpolate(distance, d2, r2, d3, r3)
    elseif distance <= d4 then
        return Interpolate(distance, d3, r3, d4, r4)
    elseif distance <= d5 then
        return Interpolate(distance, d4, r4, d5, r5)
    end

    return r5
end

local function BellSizeForPercent(percent)
    return settings.nearSize + ((settings.farSize - settings.nearSize) * percent)
end

local function RayEllipseDistance(directionX, directionY, radiusX, radiusY)
    if radiusX <= 0 or radiusY <= 0 then
        return 0
    end

    local denominator = math.sqrt(
        ((directionX * directionX) / (radiusX * radiusX)) +
        ((directionY * directionY) / (radiusY * radiusY))
    )

    if denominator <= 0 then
        return 0
    end

    return 1 / denominator
end

local function GetClassicAPIPosition(unit)
    if type(UnitPosition) ~= "function" then
        return nil
    end

    local west, north, z, instanceID = UnitPosition(unit)

    if west == nil or north == nil or instanceID == nil then
        return nil
    end

    return west, north, z, instanceID
end

local function HasDirectionalAPI()
    if type(GetPlayerFacing) ~= "function" then
        return false
    end

    local west, north, z, instanceID = GetClassicAPIPosition("player")
    if west == nil or north == nil or instanceID == nil then
        return false
    end

    return true
end

local function ClearLastKnownPosition(positionState)
    if not positionState then
        return
    end

    positionState.lastKnownWest = nil
    positionState.lastKnownNorth = nil
    positionState.lastKnownZ = nil
    positionState.lastKnownInstance = nil
end

local function UpdateGeometry(unit, positionState)
    unit = unit or "target"

    local playerWest, playerNorth, playerZ, playerInstance = GetClassicAPIPosition("player")
    local facing = nil

    geometry.hasPlayer = false
    geometry.hasTarget = false
    geometry.valid = false
    geometry.usingStaleTarget = false

    if type(GetPlayerFacing) == "function" then
        facing = GetPlayerFacing()
    end

    if playerWest == nil or playerNorth == nil or playerInstance == nil or facing == nil then
        return false
    end

    geometry.hasPlayer = true
    geometry.playerWest = playerWest
    geometry.playerNorth = playerNorth
    geometry.playerZ = playerZ
    geometry.playerInstance = playerInstance
    geometry.facing = facing

    local targetWest = nil
    local targetNorth = nil
    local targetZ = nil
    local targetInstance = nil

    if UnitExists(unit) then
        targetWest, targetNorth, targetZ, targetInstance = GetClassicAPIPosition(unit)
    end

    if targetWest ~= nil and targetNorth ~= nil and targetInstance ~= nil then
        if targetInstance ~= playerInstance then
            ClearLastKnownPosition(positionState)
            return false
        end

        if positionState then
            positionState.lastKnownWest = targetWest
            positionState.lastKnownNorth = targetNorth
            positionState.lastKnownZ = targetZ
            positionState.lastKnownInstance = targetInstance
        end
    elseif positionState
        and positionState.lastKnownWest ~= nil
        and positionState.lastKnownNorth ~= nil
        and positionState.lastKnownInstance == playerInstance
    then
        targetWest = positionState.lastKnownWest
        targetNorth = positionState.lastKnownNorth
        targetZ = positionState.lastKnownZ
        targetInstance = positionState.lastKnownInstance
        geometry.usingStaleTarget = true
    else
        if positionState and positionState.lastKnownInstance ~= nil and positionState.lastKnownInstance ~= playerInstance then
            ClearLastKnownPosition(positionState)
        end
        return false
    end

    geometry.hasTarget = true
    geometry.targetWest = targetWest
    geometry.targetNorth = targetNorth
    geometry.targetZ = targetZ
    geometry.targetInstance = targetInstance

    geometry.westDelta = targetWest - playerWest
    geometry.northDelta = targetNorth - playerNorth

    if playerZ ~= nil and targetZ ~= nil then
        geometry.zDelta = targetZ - playerZ
    else
        geometry.zDelta = nil
    end

    geometry.distance2D = math.sqrt((geometry.westDelta * geometry.westDelta) + (geometry.northDelta * geometry.northDelta))

    if geometry.zDelta ~= nil then
        geometry.distance3D = math.sqrt(
            (geometry.westDelta * geometry.westDelta) +
            (geometry.northDelta * geometry.northDelta) +
            (geometry.zDelta * geometry.zDelta)
        )
    else
        geometry.distance3D = nil
    end

    if geometry.usingStaleTarget then
        if geometry.distance3D ~= nil then
            geometry.distance = geometry.distance3D
        else
            geometry.distance = geometry.distance2D
        end
        geometry.rangeMode = "stale last-known"
    elseif geometry.distance3D ~= nil then
        geometry.distance = geometry.distance3D
        geometry.rangeMode = "3D"
    else
        geometry.distance = geometry.distance2D
        geometry.rangeMode = "2D fallback"
    end

    geometry.bearing = Atan2(geometry.westDelta, geometry.northDelta)
    geometry.relative = NormalizeAngle(geometry.bearing - facing)
    geometry.directionX = -math.sin(geometry.relative)
    geometry.directionY = math.cos(geometry.relative)
    geometry.valid = true

    return true
end

local function ComputePlacementForUnit(unit, applySmoothing, smoothingState)
    if not UpdateGeometry(unit, smoothingState) then
        return false
    end

    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()

    if not width or not height or width <= 0 or height <= 0 then
        geometry.valid = false
        return false
    end

    local percent = DistancePercent(geometry.distance)

    if geometry.usingStaleTarget then
        percent = 1
    end

    local bellSize = math.max(1, BellSizeForPercent(percent))
    local half = bellSize / 2
    local originX = width * (settings.originX / 100)
    local originY = height * (settings.originY / 100)

    -- The configured ellipses describe the visible exclusion/travel bounds.
    -- Expand the inner ellipse and contract the outer ellipse by half the bell
    -- size so the bell itself, not only its centre point, respects both.
    local innerRadiusX = (width * (settings.innerRadiusX / 100)) + half
    local innerRadiusY = (height * (settings.innerRadiusY / 100)) + half
    local outerRadiusX = (width * (settings.outerRadiusX / 100)) - half
    local outerRadiusUp = (height * (settings.outerRadiusUp / 100)) - half
    local outerRadiusDown = (height * (settings.outerRadiusDown / 100)) - half

    if outerRadiusX <= 0 or outerRadiusUp <= 0 or outerRadiusDown <= 0 then
        geometry.valid = false
        return false
    end

    local innerDistance = RayEllipseDistance(
        geometry.directionX,
        geometry.directionY,
        innerRadiusX,
        innerRadiusY
    )
    local outerRadiusY = outerRadiusDown
    if geometry.directionY >= 0 then
        outerRadiusY = outerRadiusUp
    end

    local outerDistance = RayEllipseDistance(
        geometry.directionX,
        geometry.directionY,
        outerRadiusX,
        outerRadiusY
    )

    local travelDistance = innerDistance + ((outerDistance - innerDistance) * percent)
    local rawX = originX + (geometry.directionX * travelDistance)
    local rawY = originY + (geometry.directionY * travelDistance)

    geometry.originX = originX
    geometry.originY = originY
    geometry.innerDistance = innerDistance
    geometry.outerDistance = outerDistance
    geometry.curvePercent = percent
    geometry.bellSize = bellSize
    geometry.rawOffsetX = rawX
    geometry.rawOffsetY = rawY

    if applySmoothing and settings.smoothing > 0 then
        local alpha = 1 - (settings.smoothing / 100)

        if smoothingState then
            if not smoothingState.hasSmoothedPosition then
                smoothingState.smoothedX = rawX
                smoothingState.smoothedY = rawY
                smoothingState.hasSmoothedPosition = true
            else
                smoothingState.smoothedX = smoothingState.smoothedX + ((rawX - smoothingState.smoothedX) * alpha)
                smoothingState.smoothedY = smoothingState.smoothedY + ((rawY - smoothingState.smoothedY) * alpha)
            end

            geometry.offsetX = smoothingState.smoothedX
            geometry.offsetY = smoothingState.smoothedY
        else
            if not hasSmoothedPosition then
                smoothedX = rawX
                smoothedY = rawY
                hasSmoothedPosition = true
            else
                smoothedX = smoothedX + ((rawX - smoothedX) * alpha)
                smoothedY = smoothedY + ((rawY - smoothedY) * alpha)
            end

            geometry.offsetX = smoothedX
            geometry.offsetY = smoothedY
        end
    else
        geometry.offsetX = rawX
        geometry.offsetY = rawY

        if applySmoothing then
            if smoothingState then
                smoothingState.smoothedX = rawX
                smoothingState.smoothedY = rawY
                smoothingState.hasSmoothedPosition = true
            else
                smoothedX = rawX
                smoothedY = rawY
                hasSmoothedPosition = true
            end
        end
    end

    return true
end



local function ComputePlacement(applySmoothing)
    return ComputePlacementForUnit("target", applySmoothing, nil)
end
local function PlaceBellForTarget()
    if not testEnabled then
        bell:Hide()
        return
    end

    if not ComputePlacement(true) then
        bell:Hide()
        hasSmoothedPosition = false
        return
    end

    bell:SetWidth(geometry.bellSize)
    bell:SetHeight(geometry.bellSize)
    bell:ClearAllPoints()
    bell:SetPoint("CENTER", UIParent, "CENTER", geometry.offsetX, geometry.offsetY)
    bell:Show()
end

local function SetTestEnabled(enabled)
    if enabled then
        if not HasDirectionalAPI() then
            testEnabled = false
            bell:Hide()
            PrintMessage(L.TEST_NEEDS_CLASSICAPI)
            return
        end

        testEnabled = true
        positionElapsed = POSITION_INTERVAL
        animationElapsed = ANIMATION_INTERVAL
        animationIndex = 1
        hasSmoothedPosition = false
        SetBellSprite(1, false)
        PlaceBellForTarget()
        PrintMessage(L.TEST_ENABLED)
    else
        testEnabled = false
        bell:Hide()
        hasSmoothedPosition = false
        PrintMessage(L.TEST_DISABLED)
    end
end

local function CommChannel()
    if GetNumRaidMembers() > 0 then
        return "RAID"
    end

    if GetNumPartyMembers() > 0 then
        return "PARTY"
    end

    return nil
end

local function GroupUnitForName(name)
    if not name or name == "" then
        return nil
    end

    if UnitName("player") == name then
        return "player"
    end

    local i
    local unit

    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            unit = "raid" .. i
            if UnitExists(unit) and UnitName(unit) == name then
                return unit
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            unit = "party" .. i
            if UnitExists(unit) and UnitName(unit) == name then
                return unit
            end
        end
    end

    return nil
end

local function SendComm(message)
    local channel = CommChannel()

    if not channel or type(SendAddonMessage) ~= "function" then
        return false
    end

    SendAddonMessage(COMM_PREFIX, message, channel)
    return true
end

local function EnsureBopPresentation()
    if bopPresentation.frame then
        return
    end

    local frame = CreateFrame("Frame", "WanderingGaiaBopPresentation", UIParent)
    frame:SetWidth(64)
    frame:SetHeight(64)
    frame:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture(BOP.fallbackIcon)

    local animation = CreateFrame("Frame", "WanderingGaiaBopAnimation", frame)
    animation:SetPoint("CENTER", frame, "CENTER", 0, 0)
    animation:SetWidth(frame:GetWidth())
    animation:SetHeight(frame:GetHeight())
    animation:SetScale(frame:GetScale())
    animation:Hide()
    animation.active = nil

    local animationTexture = animation:CreateTexture(nil, "BACKGROUND")
    animationTexture:SetAllPoints(animation)
    animationTexture:SetTexture(BOP.fallbackIcon)

    bopPresentation.frame = frame
    bopPresentation.icon = icon
    bopPresentation.animation = animation
    bopPresentation.animationTexture = animationTexture
end

local function StopBopPresentation()
    bopPresentation.pending = nil
    bopPresentation.active = false
    bopPresentation.startedAt = 0
    bopPresentation.duration = 0

    if bopPresentation.animation then
        bopPresentation.animation.active = nil
        bopPresentation.animation:Hide()
        bopPresentation.animation:SetAlpha(1)
        bopPresentation.animation:SetScale(1)
    end

    if bopPresentation.frame then
        bopPresentation.frame:Hide()
    end
end

local function BopAuraMatchesSender(aura, sender)
    if not aura or not sender then
        return false
    end

    if aura.sourceUnit and UnitExists(aura.sourceUnit) and UnitName(aura.sourceUnit) == sender then
        return true
    end

    if aura.sourceGUID and type(UnitGUID) == "function" then
        local senderUnit = GroupUnitForName(sender)

        if senderUnit then
            local senderGUID = UnitGUID(senderUnit)
            if senderGUID and senderGUID == aura.sourceGUID then
                return true
            end
        end
    end

    return false
end

local function FindBopAuraFromSender(sender)
    if type(C_UnitAuras) ~= "table"
        or type(C_UnitAuras.GetUnitAuraBySpellID) ~= "function"
    then
        return nil
    end

    local i
    for i = 1, table.getn(BOP.spellIDs) do
        local spellID = BOP.spellIDs[i]
        local aura = C_UnitAuras.GetUnitAuraBySpellID("player", spellID, "HELPFUL")

        if BopAuraMatchesSender(aura, sender) then
            return aura, spellID
        end
    end

    return nil
end

local function StartBopPresentation(aura, spellID)
    EnsureBopPresentation()

    local rank = BOP.ranks[spellID] or BOP.ranks[10278]

    bopPresentation.pending = nil
    bopPresentation.active = true
    bopPresentation.startedAt = GetTime()
    bopPresentation.duration = rank.duration

    local iconTexture = (aura and aura.icon) or BOP.fallbackIcon
    bopPresentation.icon:SetTexture(iconTexture)
    bopPresentation.animationTexture:SetTexture(iconTexture)
    bopPresentation.animation.active = 0
    bopPresentation.animation:Show()
    bopPresentation.frame:Show()

    if type(PlaySoundFile) == "function" then
        PlaySoundFile(rank.sound)
    end
end

local function TryStartPendingBop()
    local pending = bopPresentation.pending

    if not pending or runtimeMode ~= "client" then
        return
    end

    if not knownRingers[pending.sender] or not GroupUnitForName(pending.sender) then
        bopPresentation.pending = nil
        return
    end

    local aura, spellID = FindBopAuraFromSender(pending.sender)
    if aura then
        StartBopPresentation(aura, spellID)
        return
    end

    if GetTime() >= pending.expiresAt then
        bopPresentation.pending = nil
    end
end

local function QueueIncomingBop(sender)
    if runtimeMode ~= "client" or not knownRingers[sender] then
        return
    end

    bopPresentation.pending = {
        sender = sender,
        expiresAt = GetTime() + BOP.auraWait,
    }

    TryStartPendingBop()
end

local function UpdateBopPresentation()
    if bopPresentation.pending then
        TryStartPendingBop()
    end

    if not bopPresentation.active then
        return
    end

    local elapsed = GetTime() - bopPresentation.startedAt
    if elapsed >= bopPresentation.duration then
        StopBopPresentation()
        return
    end

    local animation = bopPresentation.animation

    if animation.active == 0 then
        animation:SetWidth(bopPresentation.frame:GetWidth())
        animation:SetHeight(bopPresentation.frame:GetHeight())
        animation:SetScale(bopPresentation.frame:GetScale())
        animation:SetAlpha(1)
        animation.active = 1
        animation:Show()
    elseif animation.active == 1 then
        local fade = 30 / GetFramerate() * 0.05
        animation:SetAlpha(animation:GetAlpha() - fade)
        animation:SetScale(animation:GetScale() + fade)

        if animation:GetAlpha() <= 0 then
            animation.active = 0
            animation:Hide()
        end
    end
end

local function HandleBopSpellcastSent(unit, target, castGUID, spellID)
    pendingBopCast = nil

    spellID = tonumber(spellID)
    if runtimeMode ~= "ringer"
        or unit ~= "player"
        or not spellID
        or not BOP.spellIDSet[spellID]
        or not target
        or target == ""
    then
        return
    end

    local targetName = target
    if UnitExists(target) and UnitName(target) then
        targetName = UnitName(target)
    end

    if not knownClients[targetName] or not GroupUnitForName(targetName) then
        return
    end

    pendingBopCast = {
        target = targetName,
        castGUID = castGUID,
        spellID = spellID,
    }
end

local function HandleBopSpellcastResult(succeeded, unit, castGUID, spellID)
    local pending = pendingBopCast

    if not pending or unit ~= "player" then
        return
    end

    spellID = tonumber(spellID)
    if castGUID ~= pending.castGUID or spellID ~= pending.spellID then
        return
    end

    pendingBopCast = nil

    if not succeeded
        or runtimeMode ~= "ringer"
        or not knownClients[pending.target]
        or not GroupUnitForName(pending.target)
    then
        return
    end

    SendComm("BOP:" .. pending.target)
end

local function ResolveIncomingUnit(sender)
    local override = debugUnitOverrides[sender]

    if override then
        if UnitExists(override) and UnitName(override) == sender then
            return override
        end

        return nil
    end

    return GroupUnitForName(sender)
end

local function CreateIncomingRing(sender)
    local entry = incomingRings[sender]

    if entry then
        return entry
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetWidth(DEFAULT_SETTINGS.nearSize)
    frame:SetHeight(DEFAULT_SETTINGS.nearSize)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(frame)
    texture:SetTexture(BELL_TEXTURE)
    SetBellSpriteTexture(texture, 1, false)

    entry = {
        sender = sender,
        frame = frame,
        texture = texture,
        active = false,
        hasSmoothedPosition = false,
        smoothedX = 0,
        smoothedY = 0,
        lastKnownWest = nil,
        lastKnownNorth = nil,
        lastKnownZ = nil,
        lastKnownInstance = nil,
        lastPositionRequestAt = nil,
    }

    incomingRings[sender] = entry
    return entry
end

local function RequestRemotePosition(entry)
    if not entry or not entry.active or runtimeMode ~= "client" then
        return
    end

    if debugUnitOverrides[entry.sender] then
        return
    end

    local now = GetTime()

    if entry.lastPositionRequestAt and (now - entry.lastPositionRequestAt) < POSITION_REQUEST_INTERVAL then
        return
    end

    entry.lastPositionRequestAt = now
    SendComm("POSQ:" .. entry.sender)
end

local function UpdateIncomingRingVisual(entry)
    if not entry or not entry.active then
        return
    end

    local unit = ResolveIncomingUnit(entry.sender)
    local remotePositionAvailable = false

    if unit then
        local west, north, z, instanceID = GetClassicAPIPosition(unit)
        if west ~= nil and north ~= nil and instanceID ~= nil then
            remotePositionAvailable = true
            entry.lastPositionRequestAt = nil
        end
    end

    if not remotePositionAvailable then
        RequestRemotePosition(entry)
    end

    if unit and HasDirectionalAPI() and ComputePlacementForUnit(unit, true, entry) then
        entry.frame:SetWidth(geometry.bellSize)
        entry.frame:SetHeight(geometry.bellSize)
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("CENTER", UIParent, "CENTER", geometry.offsetX, geometry.offsetY)
    else
        local width = UIParent:GetWidth() or 0
        local height = UIParent:GetHeight() or 0
        local bellSize = math.max(1, settings.nearSize)
        local offsetX = width * (settings.originX / 100)
        local offsetY = height * (settings.originY / 100)

        entry.hasSmoothedPosition = false
        entry.frame:SetWidth(bellSize)
        entry.frame:SetHeight(bellSize)
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
    end

    entry.frame:Show()
end

local function ActivateIncomingRing(sender)
    local entry = CreateIncomingRing(sender)

    entry.active = true
    entry.hasSmoothedPosition = false
    SetBellSpriteTexture(entry.texture, 1, false)

    if type(PlaySoundFile) == "function" then
        PlaySoundFile(BELL_SOUND)
    end

    UpdateIncomingRingVisual(entry)
end

local function DeactivateIncomingRing(sender)
    local entry = incomingRings[sender]

    if not entry then
        return
    end

    entry.active = false
    entry.hasSmoothedPosition = false
    entry.lastPositionRequestAt = nil
    ClearLastKnownPosition(entry)
    entry.frame:Hide()
end

local function HasActiveIncomingRings()
    local sender, entry

    for sender, entry in pairs(incomingRings) do
        if entry.active then
            return true
        end
    end

    return false
end

local function UpdateIncomingRings()
    local sender, entry

    for sender, entry in pairs(incomingRings) do
        if entry.active then
            UpdateIncomingRingVisual(entry)
        end
    end
end

local function AnimateIncomingRings(frameIndex, mirrored)
    local sender, entry

    for sender, entry in pairs(incomingRings) do
        if entry.active then
            SetBellSpriteTexture(entry.texture, frameIndex, mirrored)
        end
    end
end

local function PositionControlButton()
    if not controlButton then
        return
    end

    local height = UIParent:GetHeight() or 0
    local offsetY = height * ((0 - settings.originY) / 100)

    controlButton:ClearAllPoints()
    controlButton:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY)
end

local function CurrentControlTarget()
    if runtimeMode ~= "ringer" or not UnitExists("target") then
        return nil
    end

    local targetName = UnitName("target")

    if not targetName or not knownClients[targetName] then
        return nil
    end

    return targetName
end

local function ControlRingActive()
    local targetName = CurrentControlTarget()

    if not targetName then
        return false
    end

    return outgoingRings[targetName] and true or false
end

local function ResetControlAnimation()
    controlAnimationElapsed = 0
    controlAnimationIndex = 1

    if controlTexture then
        SetBellSpriteTexture(controlTexture, 1, false)
    end
end

local function CreateControlButton()
    if controlButton then
        return
    end

    controlButton = CreateFrame("Button", "WanderingGaiaRingControl", UIParent)
    controlButton:SetWidth(42)
    controlButton:SetHeight(42)
    controlButton:SetFrameStrata("DIALOG")
    controlButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    controlTexture = controlButton:CreateTexture(nil, "ARTWORK")
    controlTexture:SetAllPoints(controlButton)
    controlTexture:SetTexture(BELL_TEXTURE)
    SetBellSpriteTexture(controlTexture, 1, false)

    controlButton:SetScript("OnClick", function()
        if HandleControlClick then
            HandleControlClick(arg1)
        end
    end)

    PositionControlButton()
    controlButton:Hide()
end

local function UpdateControlButton()
    CreateControlButton()
    PositionControlButton()

    local targetName = CurrentControlTarget()

    if not targetName then
        controlButton:Hide()
        ResetControlAnimation()
        return
    end

    if outgoingRings[targetName] then
        controlButton:SetAlpha(1.0)
    else
        controlButton:SetAlpha(0.70)
        ResetControlAnimation()
    end

    controlButton:Show()
end

local function SendPositionReply(recipient)
    if not recipient or recipient == "" then
        return
    end

    local west, north, z, instanceID = GetClassicAPIPosition("player")

    if west == nil or north == nil or instanceID == nil then
        return
    end

    local zText = "n"
    if z ~= nil then
        zText = string.format("%.3f", z)
    end

    SendComm(string.format(
        "POS:%s:%s:%.3f:%.3f:%s",
        recipient,
        tostring(instanceID),
        west,
        north,
        zText
    ))
end

local function ApplyRemotePosition(sender, recipient, mapText, westText, northText, zText)
    local playerName = UnitName("player")

    if runtimeMode ~= "client" or recipient ~= playerName then
        return
    end

    local entry = incomingRings[sender]
    if not entry or not entry.active then
        return
    end

    local instanceID = tonumber(mapText)
    local west = tonumber(westText)
    local north = tonumber(northText)
    local z = nil

    if zText ~= "n" then
        z = tonumber(zText)
        if z == nil then
            return
        end
    end

    if instanceID == nil or west == nil or north == nil then
        return
    end

    entry.lastKnownWest = west
    entry.lastKnownNorth = north
    entry.lastKnownZ = z
    entry.lastKnownInstance = instanceID

    UpdateIncomingRingVisual(entry)
end

local function ProcessCommMessage(sender, message, simulated)
    if not sender or sender == "" or not message then
        return
    end

    local playerName = UnitName("player")

    if not simulated then
        if sender == playerName or not GroupUnitForName(sender) then
            return
        end
    end

    if message == "Q" then
        if runtimeMode == "client" and not simulated then
            knownRingers[sender] = true
            SendComm("MODE:C")
        end
        return
    end

    if message == "MODE:C" then
        knownRingers[sender] = nil

        if runtimeMode == "ringer" then
            knownClients[sender] = true
            UpdateControlButton()
        end
        return
    end

    if message == "MODE:R" then
        if runtimeMode == "client" and not simulated then
            knownRingers[sender] = true
        end

        knownClients[sender] = nil
        outgoingRings[sender] = nil
        UpdateControlButton()
        return
    end

    local _, _, ringState, recipient = string.find(message, "^RING:([01]):(.+)$")
    if ringState and recipient then
        if runtimeMode == "client" and recipient == playerName then
            if ringState == "1" then
                ActivateIncomingRing(sender)
            else
                DeactivateIncomingRing(sender)
            end
        end
        return
    end

    local _, _, requestedRinger = string.find(message, "^POSQ:(.+)$")
    if requestedRinger then
        if not simulated
            and runtimeMode == "ringer"
            and requestedRinger == playerName
            and outgoingRings[sender]
        then
            SendPositionReply(sender)
        end
        return
    end

    local _, _, positionRecipient, mapText, westText, northText, zText = string.find(
        message,
        "^POS:([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)$"
    )
    if positionRecipient then
        if not simulated then
            ApplyRemotePosition(sender, positionRecipient, mapText, westText, northText, zText)
        end
        return
    end

    local _, _, bopRecipient = string.find(message, "^BOP:(.+)$")
    if bopRecipient then
        if runtimeMode == "client"
            and bopRecipient == playerName
            and knownRingers[sender]
        then
            QueueIncomingBop(sender)
        end
        return
    end

    local _, _, intendedRinger = string.find(message, "^CANCEL:(.+)$")
    if intendedRinger and runtimeMode == "ringer" and intendedRinger == playerName then
        outgoingRings[sender] = nil
        UpdateControlButton()
    end
end

local function RingCurrentTarget()
    local targetName = CurrentControlTarget()

    if not targetName then
        return
    end

    local now = GetTime()
    local lastSent = lastRingSentAt[targetName]

    if lastSent and (now - lastSent) < RING_THROTTLE then
        return
    end

    lastRingSentAt[targetName] = now
    outgoingRings[targetName] = true
    SendComm("RING:1:" .. targetName)
    UpdateControlButton()
end

local function StopCurrentTarget()
    local targetName = CurrentControlTarget()

    if not targetName then
        return
    end

    outgoingRings[targetName] = nil
    SendComm("RING:0:" .. targetName)
    UpdateControlButton()
end

HandleControlClick = function(mouseButton)
    if mouseButton == "RightButton" then
        StopCurrentTarget()
    else
        RingCurrentTarget()
    end
end

local function ClearIncomingRings(sendCancellation)
    local sender, entry

    for sender, entry in pairs(incomingRings) do
        if entry.active then
            if sendCancellation then
                SendComm("CANCEL:" .. sender)
            end

            DeactivateIncomingRing(sender)
        end
    end
end

local function SetRuntimeMode(mode)
    if mode ~= "client" and mode ~= "ringer" then
        return
    end

    if type(WanderingGaiaDB) == "table" then
        WanderingGaiaDB.runtimeMode = mode
    end

    if runtimeMode == mode then
        if mode == "ringer" then
            SendComm("Q")
            PrintMessage(L.MODE_RINGER)
        else
            SendComm("MODE:C")
            PrintMessage(L.MODE_CLIENT)
        end

        UpdateControlButton()
        return
    end

    if runtimeMode == "ringer" then
        local recipient, active

        for recipient, active in pairs(outgoingRings) do
            if active then
                SendComm("RING:0:" .. recipient)
            end
        end

        outgoingRings = {}
        knownClients = {}
    else
        ClearIncomingRings(true)
    end

    runtimeMode = mode
    pendingBopCast = nil

    if mode ~= "client" then
        StopBopPresentation()
    end

    if mode == "ringer" then
        SendComm("MODE:R")
        SendComm("Q")
        PrintMessage(L.MODE_RINGER)
    else
        SendComm("MODE:C")
        PrintMessage(L.MODE_CLIENT)
    end

    UpdateControlButton()
end

local function RefreshGroupState()
    local name, active
    local sender, entry

    for name, active in pairs(knownClients) do
        if not debugClients[name] and not GroupUnitForName(name) then
            knownClients[name] = nil
            outgoingRings[name] = nil
        end
    end

    for name, active in pairs(outgoingRings) do
        if not debugClients[name] and not GroupUnitForName(name) then
            outgoingRings[name] = nil
        end
    end

    for name, active in pairs(knownRingers) do
        if not GroupUnitForName(name) then
            knownRingers[name] = nil

            if bopPresentation.pending and bopPresentation.pending.sender == name then
                bopPresentation.pending = nil
            end
        end
    end

    for sender, entry in pairs(incomingRings) do
        if entry.active and not debugUnitOverrides[sender] and not GroupUnitForName(sender) then
            DeactivateIncomingRing(sender)
        end
    end

    if runtimeMode == "ringer" then
        SendComm("Q")
    else
        SendComm("MODE:C")
    end

    UpdateControlButton()
end

local function CancelIncomingRingForTarget()
    if runtimeMode ~= "client" or not UnitExists("target") then
        return
    end

    local targetName = UnitName("target")
    local entry = targetName and incomingRings[targetName]

    if entry and entry.active then
        DeactivateIncomingRing(targetName)
        SendComm("CANCEL:" .. targetName)
    end
end


local function EnsureDeadzoneOverlays()
    if deadzoneOverlays.frame then
        return
    end

    local frame = CreateFrame("Frame", "WanderingGaiaEllipseOverlay", UIParent)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    frame:Hide()

    deadzoneOverlays.frame = frame
    deadzoneOverlays.innerSlices = {}
    deadzoneOverlays.outerDots = {}

    local i
    for i = 1, 28 do
        local texture = frame:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture(0.35, 0.35, 0.35)
        texture:SetAlpha(0.28)
        deadzoneOverlays.innerSlices[i] = texture
    end

    for i = 1, 48 do
        local texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(0.55, 0.55, 0.55)
        texture:SetAlpha(0.75)
        texture:SetWidth(5)
        texture:SetHeight(5)
        deadzoneOverlays.outerDots[i] = texture
    end

    deadzoneOverlays.originH = frame:CreateTexture(nil, "OVERLAY")
    deadzoneOverlays.originH:SetTexture(0.85, 0.85, 0.85)
    deadzoneOverlays.originH:SetWidth(24)
    deadzoneOverlays.originH:SetHeight(2)

    deadzoneOverlays.originV = frame:CreateTexture(nil, "OVERLAY")
    deadzoneOverlays.originV:SetTexture(0.85, 0.85, 0.85)
    deadzoneOverlays.originV:SetWidth(2)
    deadzoneOverlays.originV:SetHeight(24)

    deadzoneOverlays.innerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    deadzoneOverlays.outerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    deadzoneOverlays.originLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
end

local function UpdateDeadzoneOverlays()
    EnsureDeadzoneOverlays()

    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()

    if not width or not height or width <= 0 or height <= 0 then
        return
    end

    local originX = width * (settings.originX / 100)
    local originY = height * (settings.originY / 100)
    local innerRadiusX = width * (settings.innerRadiusX / 100)
    local innerRadiusY = height * (settings.innerRadiusY / 100)
    local outerRadiusX = width * (settings.outerRadiusX / 100)
    local outerRadiusUp = height * (settings.outerRadiusUp / 100)
    local outerRadiusDown = height * (settings.outerRadiusDown / 100)

    local sliceCount = table.getn(deadzoneOverlays.innerSlices)
    local i

    for i = 1, sliceCount do
        local normalizedY = -1 + (((i - 0.5) * 2) / sliceCount)
        local halfWidth = innerRadiusX * math.sqrt(math.max(0, 1 - (normalizedY * normalizedY)))
        local texture = deadzoneOverlays.innerSlices[i]

        texture:ClearAllPoints()
        texture:SetPoint(
            "CENTER",
            deadzoneOverlays.frame,
            "CENTER",
            originX,
            originY + (normalizedY * innerRadiusY)
        )
        texture:SetWidth(math.max(1, halfWidth * 2))
        texture:SetHeight(math.max(1, (innerRadiusY * 2) / sliceCount + 1))
    end

    local dotCount = table.getn(deadzoneOverlays.outerDots)
    for i = 1, dotCount do
        local angle = ((i - 1) / dotCount) * TWO_PI
        local texture = deadzoneOverlays.outerDots[i]

        texture:ClearAllPoints()
        local verticalRadius = outerRadiusDown
        if math.sin(angle) >= 0 then
            verticalRadius = outerRadiusUp
        end

        texture:SetPoint(
            "CENTER",
            deadzoneOverlays.frame,
            "CENTER",
            originX + (math.cos(angle) * outerRadiusX),
            originY + (math.sin(angle) * verticalRadius)
        )
    end

    deadzoneOverlays.originH:ClearAllPoints()
    deadzoneOverlays.originH:SetPoint("CENTER", deadzoneOverlays.frame, "CENTER", originX, originY)
    deadzoneOverlays.originV:ClearAllPoints()
    deadzoneOverlays.originV:SetPoint("CENTER", deadzoneOverlays.frame, "CENTER", originX, originY)

    deadzoneOverlays.innerLabel:ClearAllPoints()
    deadzoneOverlays.innerLabel:SetPoint("CENTER", deadzoneOverlays.frame, "CENTER", originX, originY)
    deadzoneOverlays.innerLabel:SetText(string.format(
        L.CONFIG_OVERLAY_INNER,
        settings.innerRadiusX,
        settings.innerRadiusY
    ))

    deadzoneOverlays.outerLabel:ClearAllPoints()
    deadzoneOverlays.outerLabel:SetPoint(
        "BOTTOM",
        deadzoneOverlays.frame,
        "CENTER",
        originX,
        originY + outerRadiusUp + 8
    )
    deadzoneOverlays.outerLabel:SetText(string.format(
        L.CONFIG_OVERLAY_OUTER,
        settings.outerRadiusX,
        settings.outerRadiusUp,
        settings.outerRadiusDown
    ))

    deadzoneOverlays.originLabel:ClearAllPoints()
    deadzoneOverlays.originLabel:SetPoint(
        "TOP",
        deadzoneOverlays.frame,
        "CENTER",
        originX,
        originY - 14
    )
    deadzoneOverlays.originLabel:SetText(L.CONFIG_OVERLAY_ORIGIN)
end

local function ShowDeadzoneOverlays()
    EnsureDeadzoneOverlays()
    UpdateDeadzoneOverlays()
    deadzoneOverlays.frame:Show()
end

local function HideDeadzoneOverlays()
    if deadzoneOverlays.frame then
        deadzoneOverlays.frame:Hide()
    end
end

local function CreateLabel(parent, text, x, y, fontObject)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function CreateNumericField(parent, name, x, y, width)
    local edit = CreateFrame("EditBox", "WanderingGaiaConfig" .. name, parent, "InputBoxTemplate")
    edit:SetWidth(width or 58)
    edit:SetHeight(24)
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(10)
    edit:SetJustifyH("CENTER")
    edit:SetScript("OnEnterPressed", function()
        this:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    return edit
end

local function SetField(edit, value)
    if edit then
        edit:SetText(FormatNumber(value))
    end
end

local function UpdateCurvePreview()
    if not curvePreview then
        return
    end

    local distances = {
        settings.minimumRange,
        settings.curveDistance2,
        settings.curveDistance3,
        settings.curveDistance4,
        settings.curveDistance5,
    }

    local radii = {
        0,
        settings.curveRadius2,
        settings.curveRadius3,
        settings.curveRadius4,
        settings.curveRadius5,
    }

    local width = curvePreview:GetWidth() - 12
    local height = curvePreview:GetHeight() - 12
    local maximumDistance = settings.curveDistance5
    local i

    if maximumDistance <= 0 then
        maximumDistance = 1
    end

    for i = 1, 5 do
        local x = 6 + ((distances[i] / maximumDistance) * width)
        local y = 6 + ((radii[i] / 100) * height)

        curveBars[i]:ClearAllPoints()
        curveBars[i]:SetPoint("BOTTOMLEFT", curvePreview, "BOTTOMLEFT", x, 6)
        curveBars[i]:SetWidth(2)
        curveBars[i]:SetHeight(math.max(1, y - 6))

        curveMarkers[i]:ClearAllPoints()
        curveMarkers[i]:SetPoint("CENTER", curvePreview, "BOTTOMLEFT", x, y)
    end
end

local function RefreshConfigFields()
    if not configFrame then
        return
    end

    SetField(configFields.originX, settings.originX)
    SetField(configFields.originY, settings.originY)
    SetField(configFields.innerRadiusX, settings.innerRadiusX)
    SetField(configFields.innerRadiusY, settings.innerRadiusY)
    SetField(configFields.outerRadiusX, settings.outerRadiusX)
    SetField(configFields.outerRadiusUp, settings.outerRadiusUp)
    SetField(configFields.outerRadiusDown, settings.outerRadiusDown)

    SetField(configFields.minimumRange, settings.minimumRange)
    SetField(configFields.curveDistance2, settings.curveDistance2)
    SetField(configFields.curveRadius2, settings.curveRadius2)
    SetField(configFields.curveDistance3, settings.curveDistance3)
    SetField(configFields.curveRadius3, settings.curveRadius3)
    SetField(configFields.curveDistance4, settings.curveDistance4)
    SetField(configFields.curveRadius4, settings.curveRadius4)
    SetField(configFields.curveDistance5, settings.curveDistance5)
    SetField(configFields.curveRadius5, settings.curveRadius5)

    SetField(configFields.nearSize, settings.nearSize)
    SetField(configFields.farSize, settings.farSize)
    SetField(configFields.smoothing, settings.smoothing)

    UpdateCurvePreview()

    if settingsExportBox then
        settingsExportBox:SetText("")
    end
end

local function ReadField(edit, fallback)
    if not edit then
        return fallback
    end

    return tonumber(edit:GetText()) or fallback
end

local function SettingsExportString()
    return string.format(
        "WGCFG version=%s minrange=%g origin=%g:%g inner=%g:%g outer=%g:%g:%g curve=%g:0,%g:%g,%g:%g,%g:%g,%g:%g size=%g:%g smooth=%g",
        ADDON_VERSION or "unknown",
        settings.minimumRange,
        settings.originX,
        settings.originY,
        settings.innerRadiusX,
        settings.innerRadiusY,
        settings.outerRadiusX,
        settings.outerRadiusUp,
        settings.outerRadiusDown,
        settings.minimumRange,
        settings.curveDistance2,
        settings.curveRadius2,
        settings.curveDistance3,
        settings.curveRadius3,
        settings.curveDistance4,
        settings.curveRadius4,
        settings.curveDistance5,
        settings.curveRadius5,
        settings.nearSize,
        settings.farSize,
        settings.smoothing
    )
end

local function CreateConfigFrame()
    if configFrame then
        return
    end

    local frame = CreateFrame("Frame", "WanderingGaiaConfigFrame", UIParent)
    configFrame = frame
    frame:SetWidth(650)
    frame:SetHeight(610)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
    frame:SetScript("OnShow", function()
        RefreshConfigFields()
        ShowDeadzoneOverlays()
    end)
    frame:SetScript("OnHide", function()
        HideDeadzoneOverlays()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetText(L.CONFIG_TITLE .. " - " .. (ADDON_VERSION or ""))

    local close = CreateFrame("Button", "WanderingGaiaConfigClose", frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    CreateLabel(frame, L.CONFIG_SCREEN_SECTION, 24, -52, "GameFontNormal")

    CreateLabel(frame, L.CONFIG_ORIGIN_X, 28, -80)
    configFields.originX = CreateNumericField(frame, "OriginX", 103, -74, 52)
    CreateLabel(frame, L.CONFIG_ORIGIN_Y, 180, -80)
    configFields.originY = CreateNumericField(frame, "OriginY", 255, -74, 52)

    CreateLabel(frame, L.CONFIG_INNER_X, 28, -110)
    configFields.innerRadiusX = CreateNumericField(frame, "InnerRadiusX", 103, -104, 52)
    CreateLabel(frame, L.CONFIG_INNER_Y, 180, -110)
    configFields.innerRadiusY = CreateNumericField(frame, "InnerRadiusY", 255, -104, 52)

    CreateLabel(frame, L.CONFIG_OUTER_X, 28, -140)
    configFields.outerRadiusX = CreateNumericField(frame, "OuterRadiusX", 103, -134, 52)
    CreateLabel(frame, L.CONFIG_OUTER_UP, 180, -140)
    configFields.outerRadiusUp = CreateNumericField(frame, "OuterRadiusUp", 255, -134, 52)
    CreateLabel(frame, L.CONFIG_OUTER_DOWN, 330, -140)
    configFields.outerRadiusDown = CreateNumericField(frame, "OuterRadiusDown", 410, -134, 52)

    local originNote = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    originNote:SetPoint("TOPLEFT", frame, "TOPLEFT", 330, -74)
    originNote:SetWidth(290)
    originNote:SetJustifyH("LEFT")
    originNote:SetText(L.CONFIG_ORIGIN_NOTE)

    CreateLabel(frame, L.CONFIG_DISTANCE_SECTION, 24, -182, "GameFontNormal")
    CreateLabel(frame, L.CONFIG_POINT, 30, -210)
    CreateLabel(frame, L.CONFIG_DISTANCE, 150, -210)
    CreateLabel(frame, L.CONFIG_OUTER, 244, -210)

    CreateLabel(frame, L.CONFIG_CENTER_DEADZONE, 30, -240)
    configFields.minimumRange = CreateNumericField(frame, "MinimumRange", 163, -234, 58)
    CreateLabel(frame, "0", 267, -240)

    CreateLabel(frame, "2", 30, -270)
    configFields.curveDistance2 = CreateNumericField(frame, "CurveDistance2", 163, -264, 58)
    configFields.curveRadius2 = CreateNumericField(frame, "CurveRadius2", 257, -264, 58)

    CreateLabel(frame, "3", 30, -300)
    configFields.curveDistance3 = CreateNumericField(frame, "CurveDistance3", 163, -294, 58)
    configFields.curveRadius3 = CreateNumericField(frame, "CurveRadius3", 257, -294, 58)

    CreateLabel(frame, "4", 30, -330)
    configFields.curveDistance4 = CreateNumericField(frame, "CurveDistance4", 163, -324, 58)
    configFields.curveRadius4 = CreateNumericField(frame, "CurveRadius4", 257, -324, 58)

    CreateLabel(frame, "5", 30, -360)
    configFields.curveDistance5 = CreateNumericField(frame, "CurveDistance5", 163, -354, 58)
    configFields.curveRadius5 = CreateNumericField(frame, "CurveRadius5", 257, -354, 58)

    CreateLabel(frame, L.CONFIG_CURVE_PREVIEW, 352, -210)
    curvePreview = CreateFrame("Frame", "WanderingGaiaCurvePreview", frame)
    curvePreview:SetWidth(260)
    curvePreview:SetHeight(140)
    curvePreview:SetPoint("TOPLEFT", frame, "TOPLEFT", 352, -230)
    curvePreview:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    curvePreview:SetBackdropColor(0.08, 0.08, 0.08, 0.85)

    local i
    for i = 1, 5 do
        local bar = curvePreview:CreateTexture(nil, "ARTWORK")
        bar:SetTexture(0.55, 0.55, 0.55)
        curveBars[i] = bar

        local marker = curvePreview:CreateTexture(nil, "OVERLAY")
        marker:SetTexture(0.85, 0.85, 0.85)
        marker:SetWidth(7)
        marker:SetHeight(7)
        curveMarkers[i] = marker
    end

    CreateLabel(frame, L.CONFIG_BELL_SECTION, 24, -398, "GameFontNormal")
    CreateLabel(frame, L.CONFIG_NEAR_SIZE, 30, -427)
    configFields.nearSize = CreateNumericField(frame, "NearSize", 100, -421, 58)
    CreateLabel(frame, L.CONFIG_FAR_SIZE, 185, -427)
    configFields.farSize = CreateNumericField(frame, "FarSize", 245, -421, 58)
    CreateLabel(frame, L.CONFIG_SMOOTHING, 330, -427)
    configFields.smoothing = CreateNumericField(frame, "Smoothing", 425, -421, 58)

    local rangeNote = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rangeNote:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -458)
    rangeNote:SetWidth(590)
    rangeNote:SetJustifyH("LEFT")
    rangeNote:SetText(L.CONFIG_RANGE_NOTE)

    configStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    configStatus:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -482)
    configStatus:SetWidth(250)
    configStatus:SetJustifyH("LEFT")

    local apply = CreateFrame("Button", "WanderingGaiaConfigApply", frame, "UIPanelButtonTemplate")
    apply:SetWidth(90)
    apply:SetHeight(24)
    apply:SetPoint("TOPLEFT", frame, "TOPLEFT", 292, -474)
    apply:SetText(L.CONFIG_APPLY)
    apply:SetScript("OnClick", function()
        ApplyConfigFields()
    end)

    local reset = CreateFrame("Button", "WanderingGaiaConfigReset", frame, "UIPanelButtonTemplate")
    reset:SetWidth(110)
    reset:SetHeight(24)
    reset:SetPoint("LEFT", apply, "RIGHT", 8, 0)
    reset:SetText(L.CONFIG_RESET)
    reset:SetScript("OnClick", function()
        ResetConfigDefaults()
    end)

    local copy = CreateFrame("Button", "WanderingGaiaConfigCopy", frame, "UIPanelButtonTemplate")
    copy:SetWidth(105)
    copy:SetHeight(24)
    copy:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    copy:SetText(L.CONFIG_COPY)
    copy:SetScript("OnClick", function()
        FocusSettingsExport()
    end)

    CreateLabel(frame, L.CONFIG_EXPORT_LABEL, 30, -518)

    settingsExportBox = CreateFrame("EditBox", "WanderingGaiaConfigExport", frame, "InputBoxTemplate")
    settingsExportBox:SetWidth(575)
    settingsExportBox:SetHeight(24)
    settingsExportBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -538)
    settingsExportBox:SetAutoFocus(false)
    settingsExportBox:SetMaxLetters(1024)
    settingsExportBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    settingsExportBox:SetScript("OnEnterPressed", function()
        this:HighlightText()
    end)

    local copyHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copyHint:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -570)
    copyHint:SetText(L.CONFIG_COPY_HINT)

    if UISpecialFrames then
        table.insert(UISpecialFrames, "WanderingGaiaConfigFrame")
    end

    RefreshConfigFields()
    frame:Hide()
end

ApplyConfigFields = function()
    settings.originX = ReadField(configFields.originX, settings.originX)
    settings.originY = ReadField(configFields.originY, settings.originY)
    settings.innerRadiusX = ReadField(configFields.innerRadiusX, settings.innerRadiusX)
    settings.innerRadiusY = ReadField(configFields.innerRadiusY, settings.innerRadiusY)
    settings.outerRadiusX = ReadField(configFields.outerRadiusX, settings.outerRadiusX)
    settings.outerRadiusUp = ReadField(configFields.outerRadiusUp, settings.outerRadiusUp)
    settings.outerRadiusDown = ReadField(configFields.outerRadiusDown, settings.outerRadiusDown)

    settings.minimumRange = ReadField(configFields.minimumRange, settings.minimumRange)
    settings.curveDistance2 = ReadField(configFields.curveDistance2, settings.curveDistance2)
    settings.curveRadius2 = ReadField(configFields.curveRadius2, settings.curveRadius2)
    settings.curveDistance3 = ReadField(configFields.curveDistance3, settings.curveDistance3)
    settings.curveRadius3 = ReadField(configFields.curveRadius3, settings.curveRadius3)
    settings.curveDistance4 = ReadField(configFields.curveDistance4, settings.curveDistance4)
    settings.curveRadius4 = ReadField(configFields.curveRadius4, settings.curveRadius4)
    settings.curveDistance5 = ReadField(configFields.curveDistance5, settings.curveDistance5)
    settings.curveRadius5 = ReadField(configFields.curveRadius5, settings.curveRadius5)

    settings.nearSize = ReadField(configFields.nearSize, settings.nearSize)
    settings.farSize = ReadField(configFields.farSize, settings.farSize)
    settings.smoothing = ReadField(configFields.smoothing, settings.smoothing)

    NormalizeSettings(settings)
    hasSmoothedPosition = false
    RefreshConfigFields()
    UpdateDeadzoneOverlays()

    if testEnabled then
        PlaceBellForTarget()
    end

    UpdateControlButton()

    if configStatus then
        configStatus:SetText(L.CONFIG_APPLIED)
    end
end

ResetConfigDefaults = function()
    CopyDefaults(settings)
    NormalizeSettings(settings)
    hasSmoothedPosition = false
    RefreshConfigFields()
    UpdateDeadzoneOverlays()

    if testEnabled then
        PlaceBellForTarget()
    end

    UpdateControlButton()

    if configStatus then
        configStatus:SetText(L.CONFIG_RESET_DONE)
    end
end

FocusSettingsExport = function()
    CreateConfigFrame()
    settingsExportBox:SetText(SettingsExportString())
    settingsExportBox:SetFocus()
    settingsExportBox:HighlightText()
end

local function ToggleConfig()
    CreateConfigFrame()

    if configFrame:IsVisible() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end

local function CreateCoordsFrame()
    if coordsFrame then
        return
    end

    coordsFrame = CreateFrame("Frame", "WanderingGaiaCoordsFrame", UIParent)
    coordsFrame:SetWidth(470)
    coordsFrame:SetHeight(142)
    coordsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -20)
    coordsFrame:SetFrameStrata("TOOLTIP")
    coordsFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    coordsFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.80)

    coordsText = coordsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coordsText:SetPoint("TOPLEFT", coordsFrame, "TOPLEFT", 10, -10)
    coordsText:SetWidth(450)
    coordsText:SetHeight(122)
    coordsText:SetJustifyH("LEFT")
    coordsText:SetJustifyV("TOP")

    coordsFrame:Hide()
end

local function UpdateCoordsDisplay()
    CreateCoordsFrame()

    if not testEnabled then
        ComputePlacement(false)
    end

    if not geometry.hasPlayer then
        coordsText:SetText(L.COORDS_TITLE .. " - " .. (ADDON_VERSION or "") .. "\n" .. L.COORDS_NO_API)
        return
    end

    local lines = {}
    table.insert(lines, L.COORDS_TITLE .. " - " .. (ADDON_VERSION or ""))
    table.insert(lines, string.format(
        L.COORDS_PLAYER,
        geometry.playerWest,
        geometry.playerNorth,
        FormatOptionalNumber(geometry.playerZ)
    ))

    if not geometry.hasTarget or not geometry.valid then
        table.insert(lines, L.COORDS_NO_TARGET)
        coordsText:SetText(table.concat(lines, "\n"))
        return
    end

    table.insert(lines, string.format(
        L.COORDS_TARGET,
        geometry.targetWest,
        geometry.targetNorth,
        FormatOptionalNumber(geometry.targetZ)
    ))
    table.insert(lines, string.format(
        L.COORDS_DELTA,
        geometry.westDelta,
        geometry.northDelta,
        FormatOptionalNumber(geometry.zDelta)
    ))
    table.insert(lines, string.format(
        L.COORDS_RANGE,
        geometry.distance2D,
        FormatOptionalNumber(geometry.distance3D),
        geometry.rangeMode
    ))
    table.insert(lines, string.format(
        L.COORDS_ANGLES,
        geometry.facing * 180 / PI,
        geometry.bearing * 180 / PI,
        geometry.relative * 180 / PI
    ))
    table.insert(lines, string.format(
        L.COORDS_ELLIPSES,
        settings.innerRadiusX,
        settings.innerRadiusY,
        settings.outerRadiusX,
        settings.outerRadiusUp,
        settings.outerRadiusDown
    ))

    if geometry.curvePercent ~= nil and geometry.bellSize ~= nil and geometry.offsetX ~= nil and geometry.offsetY ~= nil then
        table.insert(lines, string.format(
            L.COORDS_PLACEMENT,
            settings.originX,
            settings.originY,
            geometry.curvePercent * 100,
            geometry.bellSize,
            geometry.offsetX,
            geometry.offsetY
        ))
    end

    coordsText:SetText(table.concat(lines, "\n"))
end

local function SetCoordsEnabled(enabled)
    CreateCoordsFrame()

    if enabled then
        coordsEnabled = true
        coordsElapsed = COORDS_INTERVAL
        UpdateCoordsDisplay()
        coordsFrame:Show()
        PrintMessage(L.COORDS_ENABLED)
    else
        coordsEnabled = false
        coordsFrame:Hide()
        PrintMessage(L.COORDS_DISABLED)
    end
end

local function ParseCommand(message)
    local text = message or ""
    local _, _, command, remainder = string.find(text, "^%s*(%S*)%s*(.-)%s*$")

    return string.lower(command or ""), string.lower(remainder or "")
end

local function DebugActiveIncomingCount()
    local count = 0
    local sender, entry

    for sender, entry in pairs(incomingRings) do
        if entry.active then
            count = count + 1
        end
    end

    return count
end

local function DebugState()
    local targetName = "-"
    local known = "no"
    local outgoing = "no"

    if UnitExists("target") and UnitName("target") then
        targetName = UnitName("target")

        if knownClients[targetName] then
            known = "yes"
        end

        if outgoingRings[targetName] then
            outgoing = "yes"
        end
    end

    PrintMessage(string.format(
        L.DEBUG_STATE,
        runtimeMode,
        targetName,
        known,
        outgoing,
        DebugActiveIncomingCount()
    ))
end

local function DebugClear()
    local name, active
    local sender, entry

    for name, active in pairs(debugClients) do
        knownClients[name] = nil
        outgoingRings[name] = nil
    end

    for sender, entry in pairs(incomingRings) do
        if debugUnitOverrides[sender] then
            DeactivateIncomingRing(sender)
        end
    end

    debugClients = {}
    debugUnitOverrides = {}
    UpdateControlButton()
    PrintMessage(L.DEBUG_CLEARED)
end

local function HandleDebugCommand(remainder)
    local command, argument = ParseCommand(remainder)

    if command == "discover" then
        if runtimeMode ~= "ringer" then
            PrintMessage(L.DEBUG_NEEDS_RINGER)
            return
        end

        if not UnitExists("target") or not UnitName("target") then
            PrintMessage(L.DEBUG_NEEDS_TARGET)
            return
        end

        local targetName = UnitName("target")
        debugClients[targetName] = true
        ProcessCommMessage(targetName, "MODE:C", true)
        PrintMessage(string.format(L.DEBUG_DISCOVERED, targetName))
    elseif command == "ring" then
        if runtimeMode ~= "client" then
            PrintMessage(L.DEBUG_NEEDS_CLIENT)
            return
        end

        if not UnitExists("target") or not UnitName("target") then
            PrintMessage(L.DEBUG_NEEDS_TARGET)
            return
        end

        local sender = UnitName("target")
        debugUnitOverrides[sender] = "target"
        ProcessCommMessage(sender, "RING:1:" .. (UnitName("player") or ""), true)
        PrintMessage(string.format(L.DEBUG_RING_STARTED, sender))
    elseif command == "off" then
        if not UnitExists("target") or not UnitName("target") then
            PrintMessage(L.DEBUG_NEEDS_TARGET)
            return
        end

        local sender = UnitName("target")
        ProcessCommMessage(sender, "RING:0:" .. (UnitName("player") or ""), true)
        PrintMessage(string.format(L.DEBUG_RING_STOPPED, sender))
    elseif command == "cena" then
        local rank = tonumber(argument)
        if argument == "" then
            rank = 3
        end

        if rank ~= 1 and rank ~= 2 and rank ~= 3 then
            PrintMessage(L.DEBUG_CENA_HELP)
            return
        end

        StartBopPresentation({ icon = BOP.fallbackIcon }, BOP.spellIDs[rank])
        PrintMessage(string.format(L.DEBUG_CENA_STARTED, rank))
    elseif command == "clear" then
        DebugClear()
    elseif command == "state" then
        DebugState()
    else
        PrintMessage(L.DEBUG_HELP)
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    local incomingActive = HasActiveIncomingRings()
    local controlActive = ControlRingActive()
    local bopActive = bopPresentation.active or (bopPresentation.pending and true or false)

    if not testEnabled and not coordsEnabled and not incomingActive and not controlActive and not bopActive then
        return
    end

    if bopActive then
        UpdateBopPresentation()
    end

    positionElapsed = positionElapsed + arg1
    coordsElapsed = coordsElapsed + arg1

    if testEnabled or incomingActive then
        animationElapsed = animationElapsed + arg1

        if positionElapsed >= POSITION_INTERVAL then
            positionElapsed = 0

            if testEnabled then
                PlaceBellForTarget()
            end

            if incomingActive then
                UpdateIncomingRings()
            end
        end

        if animationElapsed >= ANIMATION_INTERVAL then
            animationElapsed = 0

            local frame = swingFrames[animationIndex]

            if testEnabled then
                SetBellSprite(frame[1], frame[2])
            end

            if incomingActive then
                AnimateIncomingRings(frame[1], frame[2])
            end

            animationIndex = animationIndex + 1
            if animationIndex > table.getn(swingFrames) then
                animationIndex = 1
            end
        end
    end

    if controlActive then
        controlAnimationElapsed = controlAnimationElapsed + arg1

        if controlAnimationElapsed >= ANIMATION_INTERVAL then
            controlAnimationElapsed = 0

            local controlFrame = swingFrames[controlAnimationIndex]
            SetBellSpriteTexture(controlTexture, controlFrame[1], controlFrame[2])

            controlAnimationIndex = controlAnimationIndex + 1
            if controlAnimationIndex > table.getn(swingFrames) then
                controlAnimationIndex = 1
            end
        end
    end

    if coordsEnabled and coordsElapsed >= COORDS_INTERVAL then
        coordsElapsed = 0
        UpdateCoordsDisplay()
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PARTY_MEMBERS_CHANGED")
events:RegisterEvent("RAID_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UNIT_SPELLCAST_SENT")
events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
events:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
events:RegisterEvent("UNIT_SPELLCAST_FAILED")
events:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
events:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitializeSettings()
        CreateControlButton()

        if configFrame then
            RefreshConfigFields()
        end

        RefreshGroupState()
    elseif event == "CHAT_MSG_ADDON" then
        if arg1 == COMM_PREFIX then
            ProcessCommMessage(arg4, arg2, false)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        CancelIncomingRingForTarget()
        UpdateControlButton()
    elseif event == "UNIT_SPELLCAST_SENT" then
        HandleBopSpellcastSent(arg1, arg2, arg3, arg4)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        HandleBopSpellcastResult(true, arg1, arg2, arg3)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_FAILED_QUIET"
    then
        HandleBopSpellcastResult(false, arg1, arg2, arg3)
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        RefreshGroupState()
    end
end)

SLASH_WANDERINGGAIA1 = "/wg"
SlashCmdList["WANDERINGGAIA"] = function(message)
    local command, remainder = ParseCommand(message)

    if command == "test" then
        if remainder == "" then
            SetTestEnabled(not testEnabled)
        elseif remainder == "on" then
            SetTestEnabled(true)
        elseif remainder == "off" then
            SetTestEnabled(false)
        else
            PrintMessage(L.TEST_HELP)
        end
    elseif command == "ringer" then
        SetRuntimeMode("ringer")
    elseif command == "client" then
        SetRuntimeMode("client")
    elseif command == "debug" then
        HandleDebugCommand(remainder)
    elseif command == "config" then
        if remainder == "" then
            ToggleConfig()
        elseif remainder == "print" then
            CreateConfigFrame()
            configFrame:Show()
            FocusSettingsExport()
        elseif remainder == "reset" then
            CreateConfigFrame()
            ResetConfigDefaults()
            configFrame:Show()
        else
            PrintMessage(L.CONFIG_HELP)
        end
    elseif command == "coords" then
        if remainder == "" then
            SetCoordsEnabled(not coordsEnabled)
        elseif remainder == "on" then
            SetCoordsEnabled(true)
        elseif remainder == "off" then
            SetCoordsEnabled(false)
        else
            PrintMessage(L.COORDS_HELP)
        end
    else
        PrintMessage(L.ROOT_HELP)
    end
end
