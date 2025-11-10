-- BISList Context Menu: Item link click hooking

BISListContextMenu = {}

local currentItemLink = nil
local lastHoveredItemLink = nil
local lastHoveredItemName = nil
local lastHoveredSourceInfo = nil
local hideTimer = 0

-- Get the equipment slot for an item
function BISListContextMenu:GetItemSlot(itemLink)
    if not itemLink then return nil end

    -- Extract item ID from link
    local _, _, itemId = string.find(itemLink, "item:(%d+)")
    if not itemId then
        return nil
    end

    -- Correct order for vanilla 1.12.1:
    -- itemName, itemLink, itemRarity, itemLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture
    local itemName, itemLink2, itemRarity, itemLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemId)

    if not itemEquipLoc or itemEquipLoc == "" then
        return nil
    end

    -- Map itemEquipLoc to slot IDs
    local slotMap = {
        ["INVTYPE_HEAD"] = 1,
        ["INVTYPE_NECK"] = 2,
        ["INVTYPE_SHOULDER"] = 3,
        ["INVTYPE_BODY"] = 4,
        ["INVTYPE_CHEST"] = 5,
        ["INVTYPE_ROBE"] = 5,
        ["INVTYPE_WAIST"] = 6,
        ["INVTYPE_LEGS"] = 7,
        ["INVTYPE_FEET"] = 8,
        ["INVTYPE_WRIST"] = 9,
        ["INVTYPE_HAND"] = 10,
        ["INVTYPE_FINGER"] = 11,
        ["INVTYPE_TRINKET"] = 13,
        ["INVTYPE_CLOAK"] = 15,
        ["INVTYPE_WEAPON"] = 16,
        ["INVTYPE_2HWEAPON"] = 16,
        ["INVTYPE_WEAPONMAINHAND"] = 16,
        ["INVTYPE_WEAPONOFFHAND"] = 17,
        ["INVTYPE_SHIELD"] = 17,
        ["INVTYPE_HOLDABLE"] = 17,
        ["INVTYPE_RANGED"] = 18,
        ["INVTYPE_RANGEDRIGHT"] = 18,
        ["INVTYPE_THROWN"] = 18,
        ["INVTYPE_RELIC"] = 18,
    }

    local slotId = slotMap[itemEquipLoc]
    return slotId
end

-- Show slot selection dialog
function BISListContextMenu:ShowSlotSelectionDialog(itemLink)
    StaticPopupDialogs["BISLIST_SELECT_SLOT"] = {
        text = "Select equipment slot for " .. itemLink .. ":",
        button1 = "Cancel",
        hasEditBox = 0,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnShow = function()
            -- Create buttons for each slot
            local yOffset = -60
            for i, slot in ipairs(BISList.Slots) do
                local button = CreateFrame("Button", "BISListSlotButton"..i, this, "UIPanelButtonTemplate")
                button:SetWidth(180)
                button:SetHeight(25)
                button:SetPoint("TOP", 0, yOffset)
                button:SetText(slot.name)
                button:SetScript("OnClick", function()
                    BISListContextMenu:AddItemToSlot(itemLink, slot.id)
                    this:GetParent():Hide()
                end)
                yOffset = yOffset - 30
            end
        end,
        OnHide = function()
            -- Clean up buttons
            for i = 1, 17 do
                local button = getglobal("BISListSlotButton"..i)
                if button then
                    button:Hide()
                    button:SetParent(nil)
                end
            end
        end
    }

    StaticPopup_Show("BISLIST_SELECT_SLOT")
end

-- Add item to a specific slot with notes dialog
function BISListContextMenu:AddItemToSlot(itemLink, slotId)
    StaticPopupDialogs["BISLIST_ADD_NOTES"] = {
        text = "Add notes for " .. itemLink .. ":",
        button1 = "Add",
        button2 = "Skip",
        hasEditBox = 1,
        maxLetters = 100,
        OnAccept = function()
            local editBox = getglobal(this:GetParent():GetName().."EditBox")
            local notes = editBox:GetText()
            BISList:AddItem(itemLink, slotId, notes)
            if BISListUI and BISListUI.Refresh then
                BISListUI:Refresh()
            end
        end,
        OnCancel = function()
            -- Add without notes
            BISList:AddItem(itemLink, slotId, "")
            if BISListUI and BISListUI.Refresh then
                BISListUI:Refresh()
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }

    StaticPopup_Show("BISLIST_ADD_NOTES")
end

-- Handle context menu click
function BISListContextMenu:OnMenuClick(itemLink)
    if not itemLink then return end

    -- Try to auto-detect slot
    local slotId = self:GetItemSlot(itemLink)

    if slotId then
        -- Show notes dialog
        self:AddItemToSlot(itemLink, slotId)
    else
        -- Show slot selection dialog
        self:ShowSlotSelectionDialog(itemLink)
    end
end

-- Hook SetItemRef to catch item link clicks with Alt modifier
local originalSetItemRef = SetItemRef
function SetItemRef(link, text, button)
    -- If Alt-clicking an item link, add to BIS list
    if IsAltKeyDown() and string.find(link, "item:") then
        local slotId = BISListContextMenu:GetItemSlot(link)
        if slotId then
            BISList:AddItem(link, slotId, "")
            if BISListUI and BISListUI.Refresh and BISListUI:IsVisible() then
                BISListUI:Refresh()
            end
        end
        return
    end
    -- Call original function
    return originalSetItemRef(link, text, button)
end

-- Hook GameTooltip to track hovered items from chat links
local originalTooltipSetItem = GameTooltip.SetHyperlink
GameTooltip.SetHyperlink = function(self, link)
    originalTooltipSetItem(self, link)
    if link and string.find(link, "item:") then
        lastHoveredItemLink = link
    end
end

-- Hook ChatEdit_InsertLink to intercept Shift+Alt+Click
local originalChatEdit_InsertLink = ChatEdit_InsertLink
function ChatEdit_InsertLink(link)
    if IsAltKeyDown() and link and string.find(link, "item:") then
        local slotId = BISListContextMenu:GetItemSlot(link)
        if slotId then
            BISList:AddItem(link, slotId, "")
            if BISListUI and BISListUI.Refresh and BISListUI:IsVisible() then
                BISListUI:Refresh()
            end
        end
        return
    end

    return originalChatEdit_InsertLink(link)
end

-- Hook GameTooltip:SetBagItem to capture bag item hovers
local originalSetBagItem = GameTooltip.SetBagItem
GameTooltip.SetBagItem = function(self, bag, slot)
    local result = originalSetBagItem(self, bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if link then
        lastHoveredItemLink = link
        -- The link itself is already the proper colored item link!
        lastHoveredItemName = link
    end
    return result
end

-- Hook GameTooltip:SetInventoryItem to capture equipped item hovers
local originalSetInventoryItem = GameTooltip.SetInventoryItem
GameTooltip.SetInventoryItem = function(self, unit, slot)
    local result = originalSetInventoryItem(self, unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if link then
        lastHoveredItemLink = link
        -- The link itself is already the proper colored item link!
        lastHoveredItemName = link
    end
    return result
end

-- Hook GameTooltip:SetLootItem for loot window
local originalSetLootItem = GameTooltip.SetLootItem
GameTooltip.SetLootItem = function(self, slot)
    local result = originalSetLootItem(self, slot)
    local link = GetLootSlotLink(slot)
    if link then
        lastHoveredItemLink = link
        -- The link itself is already the proper colored item link!
        lastHoveredItemName = link
    end
    return result
end

-- Continuously check for AtlasLoot and other addon item tooltips
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function()
    -- Handle hide timer countdown
    if hideTimer > 0 then
        hideTimer = hideTimer - arg1
        if hideTimer <= 0 then
            lastHoveredItemLink = nil
            lastHoveredItemName = nil
            lastHoveredSourceInfo = nil
        end
    end

    -- Check both GameTooltip and AtlasLootTooltip
    local tooltipVisible = GameTooltip:IsVisible() or (AtlasLootTooltip and AtlasLootTooltip:IsVisible())

    if tooltipVisible then
        -- Reset hide timer since tooltip is visible
        hideTimer = 0

        -- Check mouse focus for AtlasLoot item buttons
        local mouseFocus = GetMouseFocus()
        if mouseFocus and mouseFocus.itemID then
            local itemID = tonumber(mouseFocus.itemID)
            -- Check if it's a numeric ID (not spell/enchant prefix)
            if itemID then
                local idStr = tostring(mouseFocus.itemID)
                local firstChar = string.sub(idStr, 1, 1)
                -- Only process if first char is a digit (not 's' or 'e')
                if firstChar >= "0" and firstChar <= "9" then
                    -- Store the basic link format
                    lastHoveredItemLink = "item:" .. itemID .. ":0:0:0"

                    -- Capture item name from AtlasLoot database
                    if mouseFocus.itemIDName then
                        lastHoveredItemName = mouseFocus.itemIDName
                    end

                    -- Capture source information if available
                    if AtlasLootItemsFrame and AtlasLootItemsFrame.refresh then
                        local dataID = AtlasLootItemsFrame.refresh[1]
                        local dataSource = AtlasLootItemsFrame.refresh[2]
                        if dataID and dataSource then
                            lastHoveredSourceInfo = dataID .. "|" .. dataSource
                        end
                    end
                end
            end
        end

        -- AtlasLoot stores itemID directly on GameTooltip
        if GameTooltip.itemID then
            local itemID = tonumber(GameTooltip.itemID)
            if itemID then
                -- Always use the constructed link format that will work
                lastHoveredItemLink = "item:" .. itemID .. ":0:0:0"
            end
        end

        -- Check common item link storage fields on mouse focus
        if mouseFocus then
            local itemLink = mouseFocus.link or mouseFocus.itemLink or mouseFocus.itemlink
            if itemLink and string.find(itemLink, "item:") then
                lastHoveredItemLink = itemLink
            end
        end
    end
end)

-- Hook GameTooltip:Hide with delayed clear to handle rapid tooltip changes
local originalHide = GameTooltip.Hide
GameTooltip.Hide = function(self)
    -- Don't clear immediately, set a timer to clear after 0.5 seconds
    hideTimer = 0.5
    return originalHide(self)
end

-- Helper function to convert AtlasLoot format to colored text
local function AtlasLoot_FixText(text)
    if not text then return nil end
    -- Convert AtlasLoot color codes to WoW color codes
    text = gsub(text, "=q1=", "|cffFFFFFF")  -- common
    text = gsub(text, "=q2=", "|cff1eff00")  -- uncommon
    text = gsub(text, "=q3=", "|cff0070dd")  -- rare
    text = gsub(text, "=q4=", "|cffa335ee")  -- epic
    text = gsub(text, "=q5=", "|cffFF8000")  -- legendary
    return text
end

-- Function to add/remove currently hovered item (called by keybinding)
function BISList_AddHoveredItem()
    if lastHoveredItemLink then
        local slotId = BISListContextMenu:GetItemSlot(lastHoveredItemLink)
        if slotId then
            -- Extract item ID
            local itemId = BISList:GetItemIdFromLink(lastHoveredItemLink)
            if itemId then
                -- Check if item already exists in the slot
                if BISList:ItemExistsInSlot(slotId, itemId) then
                    -- Remove it
                    BISList:RemoveItem(slotId, itemId)
                else
                    -- Add it with captured name and source info
                    BISList:AddItem(lastHoveredItemLink, slotId, lastHoveredItemName, lastHoveredSourceInfo)
                end

                -- Refresh UI if visible
                if BISListUI and BISListUI.Refresh and BISListUI:IsVisible() then
                    BISListUI:Refresh()
                end
            end
        end
    end
end

-- Slash command for manual testing
SLASH_BISTEST1 = "/bistest"
SlashCmdList["BISTEST"] = function(msg)
    BISList_AddHoveredItem()
end

-- Hook into the UI
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        -- Set default keybinding if none is set
        local key1, key2 = GetBindingKey("BISLIST_ADD")
        if not key1 and not key2 then
            SetBinding("ALT-B", "BISLIST_ADD")
            SaveBindings(GetCurrentBindingSet())
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Loaded! Default keybind set to ALT-B. Hover items and press ALT-B to add to your list, or use /bis to view.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00BISList:|r Loaded! Hover items and press ALT-B to add to your list, or use /bis to view.")
        end
    end
end)
