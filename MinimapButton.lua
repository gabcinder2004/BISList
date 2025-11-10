-- BISList Minimap Button (pfUI compatible)

BISListMinimapButton = {}

function BISListMinimapButton:Create()
    -- Wait for pfUI to finish loading if it exists
    local elapsed = 0
    local initFrame = CreateFrame("Frame")
    initFrame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed < 2 then return end -- Wait 2 seconds for pfUI to finish

        -- Create button as child of UIParent to avoid pfUI scanning
        local button = CreateFrame("Button", "BISListMinimapBtn", UIParent)
        button:SetWidth(32)
        button:SetHeight(32)
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(10)

        -- Icon
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetPoint("CENTER", 0, 1)

        -- Border
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetWidth(53)
        border:SetHeight(53)
        border:SetPoint("TOPLEFT", 0, 0)

        -- Highlight
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

        -- Load saved position
        local angle = 200 -- Default bottom-left
        local radius = 80
        if BISListDB and BISListDB.minimapPos then
            angle = BISListDB.minimapPos
        end
        if BISListDB and BISListDB.minimapRadius then
            radius = BISListDB.minimapRadius
        end

        -- Position on minimap
        local x = math.cos(math.rad(angle)) * radius
        local y = math.sin(math.rad(angle)) * radius
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)

        -- Click handler
        button:SetScript("OnClick", function()
            if BISListUI then
                BISListUI:Toggle()
            end
        end)

        -- Dragging
        button:RegisterForDrag("LeftButton")
        button:SetMovable(true)

        button:SetScript("OnDragStart", function()
            this:LockHighlight()
            this:SetScript("OnUpdate", function()
                local xpos, ypos = GetCursorPosition()
                local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()

                xpos = xmin - xpos / Minimap:GetEffectiveScale() + 70
                ypos = ypos / Minimap:GetEffectiveScale() - ymin - 70

                local newAngle = math.deg(math.atan2(ypos, xpos))
                local newX = math.cos(math.rad(newAngle)) * radius
                local newY = math.sin(math.rad(newAngle)) * radius

                this:ClearAllPoints()
                this:SetPoint("CENTER", Minimap, "CENTER", newX, newY)

                -- Save
                if not BISListDB then BISListDB = {} end
                BISListDB.minimapPos = newAngle
            end)
        end)

        button:SetScript("OnDragStop", function()
            this:UnlockHighlight()
            this:SetScript("OnUpdate", nil)
        end)

        -- Tooltip
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:SetText("BISList", 1, 1, 1)
            GameTooltip:AddLine("Left-click to open", 0.2, 1, 0.2)
            GameTooltip:AddLine("Drag to move", 0.2, 1, 0.2)
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        button:Show()
        self.button = button

        initFrame:SetScript("OnUpdate", nil)
    end)
end

-- Initialize
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        BISListMinimapButton:Create()
        frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
