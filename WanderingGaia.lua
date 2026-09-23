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
    centerDeadzone = 2,
    deadzoneLeft = 20,
    deadzoneRight = 20,
    deadzoneUp = 2,
    deadzoneDown = 30,
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
    useZ = false,
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
local useZCheck = nil
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
    target.centerDeadzone = Clamp(tonumber(target.centerDeadzone) or DEFAULT_SETTINGS.centerDeadzone, 0, 50)
    target.deadzoneLeft = Clamp(tonumber(target.deadzoneLeft) or DEFAULT_SETTINGS.deadzoneLeft, 0, 45)
    target.deadzoneRight = Clamp(tonumber(target.deadzoneRight) or DEFAULT_SETTINGS.deadzoneRight, 0, 45)
    target.deadzoneUp = Clamp(tonumber(target.deadzoneUp) or DEFAULT_SETTINGS.deadzoneUp, 0, 45)
    target.deadzoneDown = Clamp(tonumber(target.deadzoneDown) or DEFAULT_SETTINGS.deadzoneDown, 0, 45)

    target.curveDistance2 = Clamp(tonumber(target.curveDistance2) or DEFAULT_SETTINGS.curveDistance2, 0.1, 300)
    if target.curveDistance2 <= target.centerDeadzone then
        target.curveDistance2 = target.centerDeadzone + 0.1
    end

    target.curveDistance3 = Clamp(tonumber(target.curveDistance3) or DEFAULT_SETTINGS.curveDistance3, 0.2, 400)
    if target.curveDistance3 <= target.curveDistance2 then
        target.curveDistance3 = target.curveDistance2 + 0.1
    end

    target.curveDistance4 = Clamp(tonumber(target.curveDistance4) or DEFAULT_SETTINGS.curveDistance4, 0.3, 500)
    if target.curveDistance4 <= target.curveDistance3 then
        target.curveDistance4 = target.curveDistance3 + 0.1
    end

    target.curveDistance5 = Clamp(tonumber(target.curveDistance5) or DEFAULT_SETTINGS.curveDistance5, 0.4, 600)
    if target.curveDistance5 <= target.curveDistance4 then
        target.curveDistance5 = target.curveDistance4 + 0.1
    end

    target.curveRadius2 = Clamp(tonumber(target.curveRadius2) or DEFAULT_SETTINGS.curveRadius2, 0, 100)
    target.curveRadius3 = Clamp(tonumber(target.curveRadius3) or DEFAULT_SETTINGS.curveRadius3, 0, 100)
    target.curveRadius4 = Clamp(tonumber(target.curveRadius4) or DEFAULT_SETTINGS.curveRadius4, 0, 100)
    target.curveRadius5 = Clamp(tonumber(target.curveRadius5) or DEFAULT_SETTINGS.curveRadius5, 0, 100)

    target.nearSize = Clamp(tonumber(target.nearSize) or DEFAULT_SETTINGS.nearSize, 16, 192)
    target.farSize = Clamp(tonumber(target.farSize) or DEFAULT_SETTINGS.farSize, 16, 192)
    target.smoothing = Clamp(tonumber(target.smoothing) or DEFAULT_SETTINGS.smoothing, 0, 95)
    target.useZ = target.useZ and true or false
end

local function InitializeSettings()
    if type(WanderingGaiaDB) ~= "table" then
        WanderingGaiaDB = {}
    end

    FillMissingDefaults(WanderingGaiaDB)
    NormalizeSettings(WanderingGaiaDB)
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
    local d1 = settings.centerDeadzone
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

    if settings.useZ and geometry.distance3D ~= nil then
        geometry.distance = geometry.distance3D
        geometry.rangeMode = "3D"
    else
        geometry.distance = geometry.distance2D
        geometry.rangeMode = "2D"
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
    local bellSize = BellSizeForPercent(percent)
    local half = bellSize / 2

    local leftOffset = ((width * (settings.deadzoneLeft / 100)) + half) - (width / 2)
    local rightOffset = ((width * (1 - (settings.deadzoneRight / 100))) - half) - (width / 2)
    local bottomOffset = ((height * (settings.deadzoneDown / 100)) + half) - (height / 2)
    local topOffset = ((height * (1 - (settings.deadzoneUp / 100))) - half) - (height / 2)

    if rightOffset <= leftOffset or topOffset <= bottomOffset then
        geometry.valid = false
        return false
    end

    local edgeX = 1000000
    local edgeY = 1000000

    if geometry.directionX > 0.0001 then
        edgeX = rightOffset / geometry.directionX
    elseif geometry.directionX < -0.0001 then
        edgeX = leftOffset / geometry.directionX
    end

    if geometry.directionY > 0.0001 then
        edgeY = topOffset / geometry.directionY
    elseif geometry.directionY < -0.0001 then
        edgeY = bottomOffset / geometry.directionY
    end

    local edgeDistance = math.min(edgeX, edgeY)
    local radius = edgeDistance * percent
    local rawX = geometry.directionX * radius
    local rawY = geometry.directionY * radius

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

local function CreateOverlayFrame(name)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)

    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(frame)
    texture:SetTexture(0.35, 0.35, 0.35)
    frame:SetAlpha(0.32)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.label = label
    frame:Hide()

    return frame
end

local function EnsureDeadzoneOverlays()
    if deadzoneOverlays.left then
        return
    end

    deadzoneOverlays.left = CreateOverlayFrame("WanderingGaiaDeadzoneLeft")
    deadzoneOverlays.right = CreateOverlayFrame("WanderingGaiaDeadzoneRight")
    deadzoneOverlays.up = CreateOverlayFrame("WanderingGaiaDeadzoneUp")
    deadzoneOverlays.down = CreateOverlayFrame("WanderingGaiaDeadzoneDown")
    deadzoneOverlays.center = CreateOverlayFrame("WanderingGaiaDeadzoneCenter")
end

local function UpdateDeadzoneOverlays()
    EnsureDeadzoneOverlays()

    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()

    if not width or not height or width <= 0 or height <= 0 then
        return
    end

    local left = deadzoneOverlays.left
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    left:SetWidth(width * (settings.deadzoneLeft / 100))
    left:SetHeight(height)
    left.label:SetText(string.format(L.CONFIG_OVERLAY_LEFT, settings.deadzoneLeft))

    local right = deadzoneOverlays.right
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    right:SetWidth(width * (settings.deadzoneRight / 100))
    right:SetHeight(height)
    right.label:SetText(string.format(L.CONFIG_OVERLAY_RIGHT, settings.deadzoneRight))

    local up = deadzoneOverlays.up
    up:ClearAllPoints()
    up:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    up:SetWidth(width)
    up:SetHeight(height * (settings.deadzoneUp / 100))
    up.label:SetText(string.format(L.CONFIG_OVERLAY_UP, settings.deadzoneUp))

    local down = deadzoneOverlays.down
    down:ClearAllPoints()
    down:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    down:SetWidth(width)
    down:SetHeight(height * (settings.deadzoneDown / 100))
    down.label:SetText(string.format(L.CONFIG_OVERLAY_DOWN, settings.deadzoneDown))

    local center = deadzoneOverlays.center
    center:ClearAllPoints()
    center:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    center:SetWidth(110)
    center:SetHeight(48)
    center.label:SetText(string.format(L.CONFIG_OVERLAY_CENTER, settings.centerDeadzone))
end

local function ShowDeadzoneOverlays()
    EnsureDeadzoneOverlays()
    UpdateDeadzoneOverlays()

    deadzoneOverlays.left:Show()
    deadzoneOverlays.right:Show()
    deadzoneOverlays.up:Show()
    deadzoneOverlays.down:Show()
    deadzoneOverlays.center:Show()
end

local function HideDeadzoneOverlays()
    if not deadzoneOverlays.left then
        return
    end

    deadzoneOverlays.left:Hide()
    deadzoneOverlays.right:Hide()
    deadzoneOverlays.up:Hide()
    deadzoneOverlays.down:Hide()
    deadzoneOverlays.center:Hide()
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
        settings.centerDeadzone,
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

    SetField(configFields.deadzoneLeft, settings.deadzoneLeft)
    SetField(configFields.deadzoneRight, settings.deadzoneRight)
    SetField(configFields.deadzoneUp, settings.deadzoneUp)
    SetField(configFields.deadzoneDown, settings.deadzoneDown)

    SetField(configFields.centerDeadzone, settings.centerDeadzone)
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

    if useZCheck then
        if settings.useZ then
            useZCheck:SetChecked(1)
        else
            useZCheck:SetChecked(nil)
        end
    end

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
    local zValue = 0

    if settings.useZ then
        zValue = 1
    end

    return string.format(
        "WGCFG version=%s center=%g left=%g right=%g up=%g down=%g curve=%g:0,%g:%g,%g:%g,%g:%g,%g:%g size=%g:%g smooth=%g z=%d",
        ADDON_VERSION or "unknown",
        settings.centerDeadzone,
        settings.deadzoneLeft,
        settings.deadzoneRight,
        settings.deadzoneUp,
        settings.deadzoneDown,
        settings.centerDeadzone,
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
        settings.smoothing,
        zValue
    )
end

local function CreateConfigFrame()
    if configFrame then
        return
    end

    local frame = CreateFrame("Frame", "WanderingGaiaConfigFrame", UIParent)
    configFrame = frame
    frame:SetWidth(650)
    frame:SetHeight(540)
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
    CreateLabel(frame, L.CONFIG_LEFT, 28, -80)
    configFields.deadzoneLeft = CreateNumericField(frame, "DeadzoneLeft", 72, -74, 52)
    CreateLabel(frame, L.CONFIG_RIGHT, 145, -80)
    configFields.deadzoneRight = CreateNumericField(frame, "DeadzoneRight", 196, -74, 52)
    CreateLabel(frame, L.CONFIG_UP, 270, -80)
    configFields.deadzoneUp = CreateNumericField(frame, "DeadzoneUp", 300, -74, 52)
    CreateLabel(frame, L.CONFIG_DOWN, 380, -80)
    configFields.deadzoneDown = CreateNumericField(frame, "DeadzoneDown", 426, -74, 52)

    CreateLabel(frame, L.CONFIG_DISTANCE_SECTION, 24, -122, "GameFontNormal")
    CreateLabel(frame, L.CONFIG_POINT, 30, -150)
    CreateLabel(frame, L.CONFIG_DISTANCE, 150, -150)
    CreateLabel(frame, L.CONFIG_OUTER, 244, -150)

    CreateLabel(frame, L.CONFIG_CENTER_DEADZONE, 30, -180)
    configFields.centerDeadzone = CreateNumericField(frame, "CenterDeadzone", 163, -174, 58)
    CreateLabel(frame, "0", 267, -180)

    CreateLabel(frame, "2", 30, -210)
    configFields.curveDistance2 = CreateNumericField(frame, "CurveDistance2", 163, -204, 58)
    configFields.curveRadius2 = CreateNumericField(frame, "CurveRadius2", 257, -204, 58)

    CreateLabel(frame, "3", 30, -240)
    configFields.curveDistance3 = CreateNumericField(frame, "CurveDistance3", 163, -234, 58)
    configFields.curveRadius3 = CreateNumericField(frame, "CurveRadius3", 257, -234, 58)

    CreateLabel(frame, "4", 30, -270)
    configFields.curveDistance4 = CreateNumericField(frame, "CurveDistance4", 163, -264, 58)
    configFields.curveRadius4 = CreateNumericField(frame, "CurveRadius4", 257, -264, 58)

    CreateLabel(frame, "5", 30, -300)
    configFields.curveDistance5 = CreateNumericField(frame, "CurveDistance5", 163, -294, 58)
    configFields.curveRadius5 = CreateNumericField(frame, "CurveRadius5", 257, -294, 58)

    CreateLabel(frame, L.CONFIG_CURVE_PREVIEW, 352, -150)
    curvePreview = CreateFrame("Frame", "WanderingGaiaCurvePreview", frame)
    curvePreview:SetWidth(260)
    curvePreview:SetHeight(140)
    curvePreview:SetPoint("TOPLEFT", frame, "TOPLEFT", 352, -170)
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

    CreateLabel(frame, L.CONFIG_BELL_SECTION, 24, -338, "GameFontNormal")
    CreateLabel(frame, L.CONFIG_NEAR_SIZE, 30, -367)
    configFields.nearSize = CreateNumericField(frame, "NearSize", 100, -361, 58)
    CreateLabel(frame, L.CONFIG_FAR_SIZE, 185, -367)
    configFields.farSize = CreateNumericField(frame, "FarSize", 245, -361, 58)
    CreateLabel(frame, L.CONFIG_SMOOTHING, 330, -367)
    configFields.smoothing = CreateNumericField(frame, "Smoothing", 425, -361, 58)

    useZCheck = CreateFrame("CheckButton", "WanderingGaiaConfigUseZ", frame, "UICheckButtonTemplate")
    useZCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 505, -354)
    local useZLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    useZLabel:SetPoint("LEFT", useZCheck, "RIGHT", 2, 0)
    useZLabel:SetText(L.CONFIG_USE_Z)

    local zNote = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zNote:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -398)
    zNote:SetWidth(590)
    zNote:SetJustifyH("LEFT")
    zNote:SetText(L.CONFIG_Z_NOTE)

    configStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    configStatus:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -422)
    configStatus:SetWidth(250)
    configStatus:SetJustifyH("LEFT")

    local apply = CreateFrame("Button", "WanderingGaiaConfigApply", frame, "UIPanelButtonTemplate")
    apply:SetWidth(90)
    apply:SetHeight(24)
    apply:SetPoint("TOPLEFT", frame, "TOPLEFT", 292, -414)
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

    CreateLabel(frame, L.CONFIG_EXPORT_LABEL, 30, -458)

    settingsExportBox = CreateFrame("EditBox", "WanderingGaiaConfigExport", frame, "InputBoxTemplate")
    settingsExportBox:SetWidth(575)
    settingsExportBox:SetHeight(24)
    settingsExportBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -478)
    settingsExportBox:SetAutoFocus(false)
    settingsExportBox:SetMaxLetters(1024)
    settingsExportBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    settingsExportBox:SetScript("OnEnterPressed", function()
        this:HighlightText()
    end)

    local copyHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copyHint:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -510)
    copyHint:SetText(L.CONFIG_COPY_HINT)

    if UISpecialFrames then
        table.insert(UISpecialFrames, "WanderingGaiaConfigFrame")
    end

    RefreshConfigFields()
    frame:Hide()
end

ApplyConfigFields = function()
    settings.deadzoneLeft = ReadField(configFields.deadzoneLeft, settings.deadzoneLeft)
    settings.deadzoneRight = ReadField(configFields.deadzoneRight, settings.deadzoneRight)
    settings.deadzoneUp = ReadField(configFields.deadzoneUp, settings.deadzoneUp)
    settings.deadzoneDown = ReadField(configFields.deadzoneDown, settings.deadzoneDown)

    settings.centerDeadzone = ReadField(configFields.centerDeadzone, settings.centerDeadzone)
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

    if useZCheck and useZCheck:GetChecked() then
        settings.useZ = true
    else
        settings.useZ = false
    end

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

    if geometry.curvePercent ~= nil and geometry.bellSize ~= nil and geometry.offsetX ~= nil and geometry.offsetY ~= nil then
        table.insert(lines, string.format(
            L.COORDS_PLACEMENT,
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
