-- Constants
local addonName = ...
local SHARD_ID = 6265
local MACRO_ICON = 136163
local MACRO_BODY = "/click MaliShardsDeleteButton"
local db, panel, countText, capInput, minimapButton

-- Messages
local function Message(text)
    print("|cffae77ffMaliShards:|r " .. text)
end

-- Inventory
local function ScanShards()
    local total, target = 0, nil
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

    for bag = 0, lastBag do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)

            if info and info.itemID == SHARD_ID then
                total = total + info.stackCount

                if not target and not info.isLocked then
                    target = { bag = bag, slot = slot }
                end
            end
        end
    end

    return total, target
end

local function Refresh()
    if not db or not countText then
        return
    end

    local total = ScanShards()
    countText:SetText("Shards: " .. total .. "     Excess: " .. math.max(0, total - db.max))
end

-- Settings
local function SetCap(value)
    local limit = tonumber(value)

    if not limit or limit < 0 or limit > 200 or limit ~= math.floor(limit) then
        Message("Enter a whole number from 0 to 200.")

        if capInput then
            capInput:SetText(tostring(db.max))
        end

        return
    end

    db.max = limit

    if capInput then
        capInput:SetText(tostring(limit))
    end

    Refresh()
end

-- Deletion
function MaliShards_Delete()
    if not db or InCombatLockdown() then
        return
    end

    local combat = UnitAffectingCombat("player")

    if type(issecretvalue) == "function" and issecretvalue(combat) then
        return
    end

    if combat then
        return
    end

    if GetCursorInfo() ~= nil then
        Message("Empty your cursor first. Nothing deleted.")
        return
    end

    local total, target = ScanShards()

    if total <= db.max or not target then
        return
    end

    local info = C_Container.GetContainerItemInfo(target.bag, target.slot)

    if not info or info.itemID ~= SHARD_ID or info.isLocked then
        return
    end

    if info.stackCount > 1 then
        C_Container.SplitContainerItem(target.bag, target.slot, 1)
    else
        C_Container.PickupContainerItem(target.bag, target.slot)
    end

    local kind, itemID = GetCursorInfo()

    if kind ~= "item" or itemID ~= SHARD_ID then
        ClearCursor()
        return
    end

    local success = pcall(DeleteCursorItem)

    if not success or GetCursorInfo() ~= nil then
        ClearCursor()
        Message("Deletion did not complete; the client may be restricting it.")
    end

    Refresh()
end

-- Bindings
local deleteButton = CreateFrame("Button", "MaliShardsDeleteButton", UIParent)
deleteButton:RegisterForClicks("LeftButtonUp")
deleteButton:SetScript("OnClick", MaliShards_Delete)

BINDING_HEADER_MALISHARDS = "MaliShards"
BINDING_NAME_MALISHARDS_DELETE = "Delete one excess Soul Shard"

-- Macro creation
local function EnsureMacro(silent)
    if InCombatLockdown() then
        if not silent then
            Message("Create the macro outside combat.")
        end

        return
    end

    local existing = GetMacroIndexByName("MaliShards")

    if existing and existing > 0 then
        local _, _, body = GetMacroInfo(existing)

        if body == MACRO_BODY then
            if not silent then
                Message("The MaliShards macro is ready in your macro list.")
            end
        elseif not silent then
            Message("A different macro named MaliShards exists. It was not changed.")
        end

        return
    end

    local success, macroID = pcall(CreateMacro, "MaliShards", MACRO_ICON, MACRO_BODY, true)

    if success and macroID then
        Message("Created the character macro MaliShards. Drag it from /macro to your bar.")
    elseif not silent then
        Message("Could not create the macro. Check for free character macro slots.")
    end
end

-- Window helpers
local function TogglePanel()
    if not panel then
        return
    end

    if panel:IsShown() then
        panel:Hide()
    else
        Refresh()
        panel:Show()
    end
end

local function CreateButton(parent, label, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end

-- Minimap position
local function PositionMinimapButton()
    local angle = math.rad(db.angle)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint(
        "CENTER", Minimap, "CENTER",
        math.cos(angle) * (Minimap:GetWidth() / 2 + 8),
        math.sin(angle) * (Minimap:GetHeight() / 2 + 8)
    )
end

-- Interface
local function BuildUI()
    panel = CreateFrame("Frame", "MaliShardsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(270, 178)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    panel:SetBackdropColor(0.07, 0.04, 0.10, 0.97)
    panel:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 0)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        db.x = x - parentX
        db.y = y - parentY
    end)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("MaliShards")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)

    countText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countText:SetPoint("TOPLEFT", 16, -45)

    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 16, -80)
    label:SetText("Keep:")

    capInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    capInput:SetSize(52, 24)
    capInput:SetPoint("TOPLEFT", 106, -73)
    capInput:SetAutoFocus(false)
    capInput:SetNumeric(true)
    capInput:SetMaxLetters(3)
    capInput:SetText(tostring(db.max))
    capInput:SetScript("OnEnterPressed", function(self)
        SetCap(self:GetText())
        self:ClearFocus()
    end)
    capInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(db.max))
        self:ClearFocus()
    end)
    capInput:SetScript("OnEditFocusLost", function(self)
        SetCap(self:GetText())
    end)

    CreateButton(panel, "-", 26, 70, -73, function()
        SetCap(math.max(0, db.max - 1))
    end)
    CreateButton(panel, "+", 26, 166, -73, function()
        SetCap(math.min(200, db.max + 1))
    end)
    CreateButton(panel, "Trim One", 112, 16, -109, MaliShards_Delete)
    CreateButton(panel, "Create Macro", 112, 140, -109, function()
        EnsureMacro(false)
    end)

    local footer = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOM", 0, 14)
    footer:SetText("One excess shard per click. Outside combat.")

    panel:SetScript("OnShow", Refresh)
    table.insert(UISpecialFrames, "MaliShardsPanel")
    panel:Hide()

    minimapButton = CreateFrame("Button", "MaliShardsMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02")
    minimapButton:GetNormalTexture():SetTexCoord(0.05, 0.95, 0.05, 0.95)
    minimapButton:GetNormalTexture():ClearAllPoints()
    minimapButton:GetNormalTexture():SetPoint("CENTER")
    minimapButton:GetNormalTexture():SetSize(23, 23)
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:RegisterForClicks("LeftButtonUp")
    minimapButton:SetScript("OnClick", TogglePanel)
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local centerX, centerY = Minimap:GetCenter()
            local cursorX, cursorY = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()

            if math.atan2 then
                db.angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
            elseif atan2 then
                db.angle = atan2(cursorY / scale - centerY, cursorX / scale - centerX)
            end

            PositionMinimapButton()
        end)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("MaliShards")
        local total = ScanShards()
        GameTooltip:AddLine("Shards: " .. total .. " / Keep: " .. db.max, 1, 1, 1)
        GameTooltip:AddLine("Click: settings | Drag: move", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    PositionMinimapButton()
    minimapButton:SetShown(not db.hideMinimap)
end

-- Commands
local function ShowHelp()
    Message("/mshards - Open settings")
    Message("/mshards set N - Set maximum shards (0-200)")
    Message("/mshards status - Show shard count and maximum")
    Message("/mshards delete - Delete one excess shard")
    Message("/mshards macro - Create the macro")
    Message("/mshards minimap - Show or hide the minimap icon (requires /reload)")
end

SLASH_MALISHARDS1 = "/malishards"
SLASH_MALISHARDS2 = "/mshards"

SlashCmdList.MALISHARDS = function(message)
    if not db then
        return
    end

    local command, argument = message:lower():match("^%s*(%S*)%s*(.-)%s*$")

    if command == "" then
        TogglePanel()
    elseif command == "set" then
        SetCap(argument)
    elseif command == "delete" or command == "trim" then
        MaliShards_Delete()
    elseif command == "status" then
        local total = ScanShards()
        Message(total .. " carried; cap " .. db.max .. ".")
    elseif command == "macro" then
        EnsureMacro(false)
    elseif command == "minimap" then
        db.hideMinimap = not db.hideMinimap
        local state = db.hideMinimap and "hidden" or "shown"
        Message("Minimap icon will be " .. state .. " after /reload.")
    else
        ShowHelp()
    end
end

-- Events
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        if type(MaliShardsDB) ~= "table" then
            MaliShardsDB = {}
        end

        db = MaliShardsDB
        local limit = tonumber(db.max)

        if not limit or limit < 0 or limit > 200 or limit ~= math.floor(limit) then
            limit = 20
        end

        db.max = limit

        if type(db.angle) ~= "number" then
            db.angle = 220
        end
    elseif event == "PLAYER_LOGIN" and db then
        BuildUI()
        Message("Loaded. /mshards help to list commands.")
        EnsureMacro(true)
    elseif event == "PLAYER_REGEN_ENABLED" and db then
        EnsureMacro(true)
        Refresh()
    elseif event == "BAG_UPDATE_DELAYED" then
        Refresh()
    end
end)
