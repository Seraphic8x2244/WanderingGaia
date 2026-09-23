local ADDON_NAME = "WanderingGaia"
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME, "Version")
local L = WanderingGaia_L

local PI = math.pi
local TWO_PI = PI * 2

local BELL_TEXTURE = "Interface\\AddOns\\WanderingGaia\\artwork\\WanderingGaia_BellSwing_256x64"
local POSITION_INTERVAL = 0.05
local COORDS_INTERVAL = 0.10
local ANIMATION_INTERVAL = 0.07

local DEFAULT_SETTINGS = {
    minimumRange = 2,
    originX = 0,
    originY = 0,
    innerRadiusX = 6,
    innerRadiusY = 10,
    outerRadiusX = 30,
    outerRadiusUp = 40,
    outerRadiusDown = 40,
    curveDistance2 = 10,
    curveRadius2 = 20,
    curveDistance3 = 40,
    curveRadius3 = 48,
    curveDistance4 = 90,
    curveRadius4 = 90,
    curveDistance5 = 110,
    curveRadius5 = 92,
    nearSize = 64,
    farSize = 64,
    smoothing = 0,
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

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end

    return value
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
    if type(WanderingGaiaDB) ~= "table" then
        WanderingGaiaDB = {}
    end

    -- Migrate the old yard-based centre setting if this SavedVariables file
    -- predates the ellipse model. Old rectangular deadzones and the Z toggle
    -- are intentionally retired rather than mapped onto unrelated geometry.
    if WanderingGaiaDB.minimumRange == nil and WanderingGaiaDB.centerDeadzone ~= nil then
        WanderingGaiaDB.minimumRange = WanderingGaiaDB.centerDeadzone
    end

    -- Preserve the existing symmetric outer Y tuning when moving to separate
    -- upper/lower radii.
    if WanderingGaiaDB.outerRadiusUp == nil and WanderingGaiaDB.outerRadiusY ~= nil then
        WanderingGaiaDB.outerRadiusUp = WanderingGaiaDB.outerRadiusY
    end
    if WanderingGaiaDB.outerRadiusDown == nil and WanderingGaiaDB.outerRadiusY ~= nil then
        WanderingGaiaDB.outerRadiusDown = WanderingGaiaDB.outerRadiusY
    end

    FillMissingDefaults(WanderingGaiaDB)
    NormalizeSettings(WanderingGaiaDB)

    WanderingGaiaDB.centerDeadzone = nil
    WanderingGaiaDB.deadzoneLeft = nil
    WanderingGaiaDB.deadzoneRight = nil
    WanderingGaiaDB.deadzoneUp = nil
    WanderingGaiaDB.deadzoneDown = nil
    WanderingGaiaDB.useZ = nil
    WanderingGaiaDB.outerRadiusY = nil

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

local function SetBellSprite(frameIndex, mirrored)
    local left = (frameIndex - 1) * 0.25
    local right = frameIndex * 0.25

    if mirrored then
        bellTexture:SetTexCoord(right, left, 0, 1)
    else
        bellTexture:SetTexCoord(left, right, 0, 1)
    end
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

local function UpdateGeometry()
    local playerWest, playerNorth, playerZ, playerInstance = GetClassicAPIPosition("player")
    local facing = nil

    geometry.hasPlayer = false
    geometry.hasTarget = false
    geometry.valid = false

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

    if not UnitExists("target") then
        return false
    end

    local targetWest, targetNorth, targetZ, targetInstance = GetClassicAPIPosition("target")
    if targetWest == nil or targetNorth == nil or targetInstance == nil or targetInstance ~= playerInstance then
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

    if geometry.distance3D ~= nil then
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

local function ComputePlacement(applySmoothing)
    if not UpdateGeometry() then
        return false
    end

    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()

    if not width or not height or width <= 0 or height <= 0 then
        geometry.valid = false
        return false
    end

    local percent = DistancePercent(geometry.distance)
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

    if outerDistance < innerDistance then
        outerDistance = innerDistance
    end

    local travelDistance = innerDistance + ((outerDistance - innerDistance) * percent)
    local rawX = originX + (geometry.directionX * travelDistance)
    local rawY = originY + (geometry.directionY * travelDistance)

    -- Last-resort physical-screen safety clamp. The ellipse remains the normal
    -- limiter, but a deliberately extreme origin/ellipse cannot lose the bell.
    rawX = Clamp(rawX, (-width / 2) + half, (width / 2) - half)
    rawY = Clamp(rawY, (-height / 2) + half, (height / 2) - half)

    geometry.originX = originX
    geometry.originY = originY
    geometry.innerDistance = innerDistance
    geometry.outerDistance = outerDistance
    geometry.curvePercent = percent
    geometry.bellSize = bellSize
    geometry.rawOffsetX = rawX
    geometry.rawOffsetY = rawY

    if applySmoothing and settings.smoothing > 0 then
        if not hasSmoothedPosition then
            smoothedX = rawX
            smoothedY = rawY
            hasSmoothedPosition = true
        else
            local alpha = 1 - (settings.smoothing / 100)
            smoothedX = smoothedX + ((rawX - smoothedX) * alpha)
            smoothedY = smoothedY + ((rawY - smoothedY) * alpha)
        end

        geometry.offsetX = smoothedX
        geometry.offsetY = smoothedY
    else
        geometry.offsetX = rawX
        geometry.offsetY = rawY

        if applySmoothing then
            smoothedX = rawX
            smoothedY = rawY
            hasSmoothedPosition = true
        end
    end

    return true
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

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    if not testEnabled and not coordsEnabled then
        return
    end

    positionElapsed = positionElapsed + arg1
    coordsElapsed = coordsElapsed + arg1

    if testEnabled then
        animationElapsed = animationElapsed + arg1

        if positionElapsed >= POSITION_INTERVAL then
            positionElapsed = 0
            PlaceBellForTarget()
        end

        if animationElapsed >= ANIMATION_INTERVAL then
            animationElapsed = 0

            local frame = swingFrames[animationIndex]
            SetBellSprite(frame[1], frame[2])

            animationIndex = animationIndex + 1
            if animationIndex > table.getn(swingFrames) then
                animationIndex = 1
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
events:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitializeSettings()

        if configFrame then
            RefreshConfigFields()
        end
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
