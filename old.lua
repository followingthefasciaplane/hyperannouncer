-- Define some constants and utility functions
local feeds = {"AuraFeed", "ActionFeed", "ControlFeed", "FocusFeed"}
local DEBUG_MODE = false

local function debugPrint(msg)
    if DEBUG_MODE then
        print("DEBUG: " .. msg)
    end
end

local function GetSimplifiedName(name)
    if not name then return "" end
    return strsplit("-", name)
end

local function GetReadableUnit(guid)
    local units = {"player", "target", "focus", "party1", "party2", "arena1", "arena2", "arena3"}
    for _, unit in ipairs(units) do
        if UnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
end

-- Create the options panel
local optionsPanel = CreateFrame("Frame", "HyperannouncerOptionsPanel", InterfaceOptionsFramePanelContainer)
optionsPanel.name = "Hyperannouncer"
InterfaceOptions_AddCategory(optionsPanel)

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Hyperannouncer Options")

local debugCheckbox = CreateFrame("CheckButton", "HyperannouncerDebugCheckbox", optionsPanel, "UICheckButtonTemplate")
debugCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
debugCheckbox.Text:SetText("Enable Debug Mode")
debugCheckbox:SetScript("OnClick", function(self)
    DEBUG_MODE = self:GetChecked()
end)

debugPrint("Options GUI created.")

-- Create frames for feeds
for _, feedName in ipairs(feeds) do
    local f = CreateFrame("Frame", feedName, UIParent, "BackdropTemplate")
    f:SetSize(500, 200)  -- Adjusted default size
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetPoint("CENTER")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    local resizer = CreateFrame("Button", nil, f)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT")
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    local isResizing = false
    local startWidth, startHeight, startX, startY

    resizer:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isResizing = true
            startX, startY = GetCursorPosition()
            startWidth, startHeight = f:GetSize()
            self:SetButtonState("PUSHED", true)
        end
    end)

    resizer:SetScript("OnMouseUp", function(self)
        isResizing = false
        self:SetButtonState("NORMAL", false)
    end)

    resizer:SetScript("OnUpdate", function(self)
        if not isResizing then return end
        local curX, curY = GetCursorPosition()
        local diffX, diffY = (curX - startX) / f:GetEffectiveScale(), (curY - startY) / f:GetEffectiveScale()
        f:SetWidth(math.max(100, startWidth + diffX))
        f:SetHeight(math.max(25, startHeight - diffY))
    end)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("CENTER", f, "CENTER")
    f.text:SetJustifyH("CENTER")

    f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.nameText:SetText(feedName) -- Set the text to the feedName
    f.nameText:SetPoint("TOP", f, "TOP", 0, -5) -- Adjust the position as needed
    f.nameText:SetJustifyH("CENTER")

    debugPrint(feedName .. " frame created.")
end

-- Update the default positions to be side by side
AuraFeed:SetPoint("CENTER", -350, 0)
ActionFeed:SetPoint("CENTER", -115, 0)
ControlFeed:SetPoint("CENTER", 115, 0)
FocusFeed:SetPoint("CENTER", 350, 0)

AuraFeed:Show()
ActionFeed:Show()
ControlFeed:Show()
FocusFeed:Show()

local function Announce(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    debugPrint("Event fired: " .. tostring(event))
    local spellName, target, readableUnit

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, eventType, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellId, spellName, _, extraSpellId = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID("player") then
            if eventType == "SPELL_CAST_SUCCESS" then
                readableUnit = GetReadableUnit(destGUID)
                local currentText = ActionFeed.text:GetText()
                ActionFeed.text:SetText((spellName .. " on " .. (readableUnit or GetSimplifiedName(destName))) .. "\n" .. (currentText or ""))
            elseif eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" then
                readableUnit = GetReadableUnit(destGUID)
                local currentText = AuraFeed.text:GetText()
                AuraFeed.text:SetText((spellName .. " on " .. (readableUnit or GetSimplifiedName(destName))) .. "\n" .. (currentText or ""))
            elseif eventType == "SPELL_INTERRUPT" or eventType == "SPELL_STOLEN" or eventType == "SPELL_DISPEL" or eventType == "SPELL_AURA_BROKEN" or eventType == "SPELL_AURA_BROKEN_SPELL" then
                spellName = GetSpellInfo(extraSpellId)
                if not spellName then return end
                readableUnit = GetReadableUnit(destGUID)
                local currentText = ControlFeed.text:GetText()
                ControlFeed.text:SetText(("Interrupted " .. (readableUnit or GetSimplifiedName(destName)) .. "'s " .. spellName) .. "\n" .. (currentText or ""))
            end
        end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        target = UnitName("focus")
        if target then
            local currentText = FocusFeed.text:GetText()
            FocusFeed.text:SetText(("Focus target changed to " .. GetSimplifiedName(target)) .. "\n" .. (currentText or ""))
        end
    end
end

-- Event registrations
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:SetScript("OnEvent", Announce)