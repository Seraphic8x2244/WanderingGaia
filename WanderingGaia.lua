local ADDON_NAME = "WanderingGaia"
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME, "Version")
local L = WanderingGaia_L

local PI = math.pi
local TWO_PI = PI * 2

local BELL_TEXTURE = "Interface\\AddOns\\WanderingGaia\\artwork\\WanderingGaia_BellSwing_256x64"
local BELL_SIZE = 64

local SAFE_LEFT = 0.20
local SAFE_RIGHT = 0.80
local SAFE_BOTTOM = 0.30
local SAFE_TOP = 0.98

local POSITION_INTERVAL = 0.05
local ANIMATION_INTERVAL = 0.07

local testEnabled = false
local positionElapsed = 0
local animationElapsed = 0
local animationIndex = 1

-- The source sheet contains centre -> slight left -> further left -> full left.
-- The second half of the swing mirrors those same frames in-game.
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
bell:SetWidth(BELL_SIZE)
bell:SetHeight(BELL_SIZE)
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

local function DistancePercent(distance)
    if distance <= 2 then
        return 0
    elseif distance <= 10 then
        return ((distance - 2) / 8) * 0.20
    elseif distance <= 40 then
        return 0.20 + ((distance - 10) / 30) * 0.28
    elseif distance <= 90 then
        return 0.48 + ((distance - 40) / 50) * 0.42
    elseif distance <= 110 then
        return 0.90 + ((distance - 90) / 20) * 0.02
    end

    return 0.92
end

local function GetClassicAPIPosition(unit)
    if type(UnitPosition) ~= "function" then
        return nil
    end

    local west, north, z, instanceID = UnitPosition(unit)

    -- ClassicAPI intentionally follows Blizzard's standard four-value shape.
    -- If another DLL owns UnitPosition with a different shape, do not guess.
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

local function PlaceBellForTarget()
    if not testEnabled or not UnitExists("target") then
        bell:Hide()
        return
    end

    local playerWest, playerNorth, playerZ, playerInstance = GetClassicAPIPosition("player")
    local targetWest, targetNorth, targetZ, targetInstance = GetClassicAPIPosition("target")
    local facing = GetPlayerFacing()

    if playerWest == nil or targetWest == nil or facing == nil or playerInstance ~= targetInstance then
        bell:Hide()
        return
    end

    local westDelta = targetWest - playerWest
    local northDelta = targetNorth - playerNorth
    local distance = math.sqrt((westDelta * westDelta) + (northDelta * northDelta))

    -- Facing is 0 at north and increases counter-clockwise.
    -- UnitPosition's first return is the west axis and second is north.
    local bearing = Atan2(westDelta, northDelta)
    local relative = NormalizeAngle(bearing - facing)

    -- Screen-space direction: ahead=up, left=left, behind=down.
    local directionX = -math.sin(relative)
    local directionY = math.cos(relative)

    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()
    local half = BELL_SIZE / 2

    if not width or not height or width <= 0 or height <= 0 then
        bell:Hide()
        return
    end

    local left = (width * SAFE_LEFT) + half
    local right = (width * SAFE_RIGHT) - half
    local bottom = (height * SAFE_BOTTOM) + half
    local top = (height * SAFE_TOP) - half

    if right <= left or top <= bottom then
        bell:Hide()
        return
    end

    -- Direction is relative to the player character, so cast from the
    -- physical screen centre. The safe-area bounds still limit how far
    -- the bell can travel toward each edge.
    local centerX = width / 2
    local centerY = height / 2

    local edgeX = 1000000
    local edgeY = 1000000

    if directionX > 0.0001 then
        edgeX = (right - centerX) / directionX
    elseif directionX < -0.0001 then
        edgeX = (left - centerX) / directionX
    end

    if directionY > 0.0001 then
        edgeY = (top - centerY) / directionY
    elseif directionY < -0.0001 then
        edgeY = (bottom - centerY) / directionY
    end

    local edgeDistance = math.min(edgeX, edgeY)
    local radius = edgeDistance * DistancePercent(distance)

    local x = centerX + (directionX * radius)
    local y = centerY + (directionY * radius)

    bell:ClearAllPoints()
    bell:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
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
        SetBellSprite(1, false)
        PlaceBellForTarget()
        PrintMessage(L.TEST_ENABLED)
    else
        testEnabled = false
        bell:Hide()
        PrintMessage(L.TEST_DISABLED)
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    if not testEnabled then
        return
    end

    positionElapsed = positionElapsed + arg1
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
end)

SLASH_WANDERINGGAIATEST1 = "/wgtest"
SlashCmdList["WANDERINGGAIATEST"] = function(message)
    local command = string.lower(message or "")

    if command == "" then
        SetTestEnabled(not testEnabled)
    elseif command == "on" then
        SetTestEnabled(true)
    elseif command == "off" then
        SetTestEnabled(false)
    else
        PrintMessage(L.TEST_HELP)
    end
end
