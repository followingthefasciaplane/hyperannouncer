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

-- needs 2 be cuter
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

-- this is so fucked
for _, feedName in ipairs(feeds) do
    local f = CreateFrame("Frame", feedName, UIParent, "BackdropTemplate")
    f:SetSize(500, 200)  -- change this
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
    f.nameText:SetText(feedName) 
    f.nameText:SetPoint("TOP", f, "TOP", 0, -5) 
    f.nameText:SetJustifyH("CENTER")

    debugPrint(feedName .. " frame created.")
end

-- so fucking ugly but we'll get to that
AuraFeed:SetPoint("CENTER", -350, 0)
ActionFeed:SetPoint("CENTER", -115, 0)
ControlFeed:SetPoint("CENTER", 115, 0)
FocusFeed:SetPoint("CENTER", 350, 0)

AuraFeed:Show()
ActionFeed:Show()
ControlFeed:Show()
FocusFeed:Show()

local buffs = {} -- dont think i need to cache this

local function UpdateBuff(name, delta)
    if not buffs[name] then buffs[name] = 0 end
    buffs[name] = buffs[name] + delta
    return buffs[name]
end

local CLASS_ROLES = {
    ["DEATHKNIGHT"] = { "tank", "melee", "melee" },
    ["DEMONHUNTER"] = { "melee", "tank" },
    ["DRUID"]       = { "caster", "melee", "tank", "healer" },
    ["HUNTER"]      = { "ranged", "ranged", "melee" },
    ["MAGE"]        = { "caster", "caster", "caster" },
    ["MONK"]        = { "tank", "healer", "melee" },
    ["PALADIN"]     = { "healer", "melee", "tank" },
    ["PRIEST"]      = { "healer", "caster", "healer" },
    ["ROGUE"]       = { "melee", "melee", "melee" },
    ["SHAMAN"]      = { "caster", "melee", "healer" },
    ["WARLOCK"]     = { "caster", "caster", "caster" },
    ["WARRIOR"]     = { "melee", "melee", "tank" }
    ["EVOKER"]      = { "caster", "caster", "caster"}
}

local function DetermineRole(unit)
    if not unit then return "unknown" end
    
    local _, class = UnitClass(unit)
    local spec = GetSpecialization() -- get the active spec for a unit

    if class and spec and CLASS_ROLES[class] and CLASS_ROLES[class][spec] then
        return CLASS_ROLES[class][spec]
    end
    
    return "unknown"
end

local function Announce(event, ...)
    local timestamp, subevent, _, sourceGUID, _, _, _, destGUID, destName, _, _, spellId, spellName, _, auraType, amount = ...

    local sourceUnitID = GetReadableUnit(sourceGUID)
    local destUnitID = GetReadableUnit(destGUID)
    
    local sourceRole = DetermineRole(sourceUnitID)
    local destRole = DetermineRole(destUnitID)    

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if sourceUnit == "player" then -- me
            if subevent:match("SPELL_AURA_") then
                local simpleDestName = GetSimplifiedName(destName)
                if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
                    -- feed
                    if auraType == "BUFF" and destUnit == "player" then
                        local stackCount = UpdateBuff(spellName, 1)
                        if stackCount > 1 then
                            BuffFeed.text:SetText(spellName .. " x" .. stackCount)
                        else
                            BuffFeed.text:SetText(spellName .. " applied")
                        end
                    -- fade
                    elseif auraType == "DEBUFF" then
                        DamageFeed.text:SetText(spellName .. " applied on " .. simpleDestName .. " (" .. destUnit .. ", " .. destRole .. ")")
                    end
                elseif subevent == "SPELL_AURA_REMOVED" then
                    -- fade
                    if auraType == "BUFF" and destUnit == "player" then
                        local stackCount = UpdateBuff(spellName, -1)
                        if stackCount <= 0 then
                            BuffFeed.text:SetText(spellName .. " fades")
                        end
                    end
                end

                -- cc feeds go here eventually
                -- auraType, subevent

            elseif subevent:match("SPELL_CAST_") then
                -- defensives unfinished
                DefensiveFeed.text:SetText(spellName .. " casted on " .. simpleDestName .. " (" .. destUnit .. ", " .. destRole .. ")")
            end
        end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        -- focus target change
        local focusName = UnitName("focus")
        if focusName then
            FocusFeed.text:SetText("Focus target changed to " .. GetSimplifiedName(focusName) .. " (focus, " .. DetermineRole("focus") .. ")")
        end
    end
end

-- event reg
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:SetScript("OnEvent", Announce)
