--[[
]]
local ADDON_NAME, ns = ...
local settings = ns.settings

local core = {}
PredatorLootFunctions = {}
local PredatorLootTrigger = CreateFrame('Frame', nil, UIParent)
local PredatorLootGroupLootAnchor = CreateFrame('Frame', nil, UIParent)
PredatorLootGroupLootAnchor:SetWidth(10) PredatorLootGroupLootAnchor:SetHeight(10)
PredatorLootGroupLootAnchor:SetPoint('CENTER', UIParent, 'TOP', 250, -250)
local PredatorLootFrame = CreateFrame('Frame', 'PredatorLootWindow', UIParent, 'PredatorLootFrameTemplate')
local PLMLM = CreateFrame('Frame', 'PredatorLootMasterLooterManagement', UIParent, 'PredatorLootMasterLooterManagementTemplate')
PLMLM.winner = ''
PLMLM.lootLink = nil
core.LootSlots = {}
core.RollSlots = {}
core.CancelledRolls = {}
core.AnnounceChannel = ''
core.IsMasterLooter = false
core.RollInProgress = false
core.MasterLooterRaidClasses = {}
core.RollCapture = {}


-- ***** GENERAL FUNCTIONS ***************************************************************

	--[[ Debugging to ChatFrame 
		VOID debugging(STRING text)
	]]
	local function debugging(text)
		DEFAULT_CHAT_FRAME:AddMessage('|cffffd700PredatorLoot:|r |cffeeeeee'..text..'|r')
	end

	--[[ Returns a string with the color of the given class
		STRING GetClassColor(STRING class)
	]]
	core.GetClassColor = function(class) 
		local color = RAID_CLASS_COLORS[class]
		return string.format('|cFF%2x%2x%2x', floor(color.r * 255), floor(color.g * 255), floor(color.b * 255))
	end

	--[[ Determines, into which channel messages should be printed
		VOID SetAnnounceChannel()
	]]
	core.SetAnnounceChannel = function()
		local temp = GetNumRaidMembers()
		if (temp > 0) then
			temp = 'Raid'
		else
			temp = GetNumPartyMembers()
			if (temp > 0) then
				temp = 'Party'
			else
				temp = 'Solo'
			end
		end
		core.AnnounceChannel = string.upper(temp)
		-- debugging('SetAnnounceChannel(): '..core.AnnounceChannel)
	end

	--[[ Sends a chat message to the apropriate channel
		VOID SendMessage(STRING text, STRING channel)
	]]
	core.SendMessage = function(text, channel)
		if ((channel == 'RAID_WARNING') and (IsRaidOfficer() or IsRaidLeader())) then
			channel = core.AnnounceChannel
		end
		SendChatMessage(text, channel)
	end

	--[[ Generic on click handler
		VOID LootWindowClick(FRAME self, STRING button, FRAME row)
	]]
	core.LootWindowClick = function(self, button, row)
		local slot = row:GetID()
		if ( button == 'LeftButton' ) then
			if (IsModifierKeyDown()) then
				-- if ( core.IsMasterLooter ) then
					if ( IsAltKeyDown() and IsControlKeyDown() ) then
						core.SetItemToBeRolled(slot)
					else
						HandleModifiedItemClick(GetLootSlotLink(slot))
					end
				-- else
					-- HandleModifiedItemClick(GetLootSlotLink(slot))
				-- end
			else
				LootSlot(slot)
				row:Hide()
			end
		elseif ( button == 'RightButton' ) then
			if ( core.IsMasterLooter ) then
				-- debugging(slot)
				ToggleDropDownMenu(1, nil, PredatorLootMasterLooterDropDown, self, 0, 0)
			else
				LootSlot(slot)
				row:Hide()
			end
		end
	end


-- ***** LOOT WINDOW **********************************************************************

	--[[ Builds the loot window
		VOID OpenLoot()
	]]
	core.OpenLoot = function()
		-- debugging('OpenLoot()')
		local itemCount = GetNumLootItems()
		local i, row, icon, name, count, lootTexture, lootName, lootQuantity, lootLink, lootRarity, color
		for i = 1, itemCount do

			if ( not core.LootSlots[i] ) then
				core.LootSlots[i] = CreateFrame('Frame', 'PredatorLootRow'..i, PredatorLootFrame, 'PredatorLootFrameRowTemplate')
			end
			row = core.LootSlots[i]
			icon = _G['PredatorLootRow'..i..'IconIconTexture']
			name = _G['PredatorLootRow'..i..'Name']
			count = _G['PredatorLootRow'..i..'IconLootCount']

			lootTexture, lootName, lootQuantity = GetLootSlotInfo(i)
			if ( not lootName ) then break end
			if ( LootSlotIsItem(i) ) then
				lootLink = GetLootSlotLink(i)
				_, _, lootRarity = GetItemInfo(lootLink)
			elseif ( LootSlotIsCoin(i) ) then
				lootLink = nil
				lootRarity = 1
				lootName = string.gsub(lootName, '\n', ' ', 1, true)
			end

			row:SetID(i)
			icon:SetTexture(lootTexture)
			name:SetText(lootName)
			if ( lootQuantity > 1 ) then
				count:SetText(lootQuantity)
			else
				count:SetText('')
			end
			color = ITEM_QUALITY_COLORS[lootRarity]
			name:SetVertexColor(color.r, color.g, color.b)

			if ( i == 1 ) then
				row:SetPoint('TOP', PredatorLootFrame, 'TOP', 0, -15)
			else
				row:SetPoint('TOP', core.LootSlots[i-1], 'BOTTOM', 0, -15)
			end

			row:Show()
		end
		PredatorLootFrame:SetHeight(itemCount*40 + 15)
		PredatorLootFrame:Show()
	end

	--[[ Hides the loot-window
		VOID CloseLoot()
	]]
	core.CloseLoot = function()
		-- debugging('CloseLoot()')
		local v
		for _, v in pairs(core.LootSlots) do
			v:Hide()
		end
		PredatorLootFrame:Hide()
	end


-- ***** GROUP LOOT ***********************************************************************

	--[[
	
	]]
	core.CancelRollEvent = function(frame, event, rollID)
		core.CancelledRolls[rollID] = true
		if ( frame.rollID == rollID ) then
			frame.rollID = nil
			frame.timeLeft = nil
			frame.itemLink = nil
			frame:Hide()
		end
	end

	--[[
	
	]]
	core.StartGroupLoot = function(rollID, timeLeft)
		if ( core.CancelledRolls[rollID] ) then return end

		local frame = nil
		local k, v, frameName, name, icon, statusbar, bop, buttonNeed, buttonGreed, buttonDisEnchant, color, lootTexture, lootName, lootRarity, lootBoP, canNeed, canGreed, canDisEnchant

		for _, v in ipairs(core.RollSlots) do
			if ( not v.rollID ) then
				frame = v
			end
		end
		if ( not frame ) then
			frame = CreateFrame('Frame', 'PredatorLootGroupLoot'..rollID, UIParent, 'PredatorLootGroupLootTemplate')
			frame:RegisterEvent('CANCEL_LOOT_ROLL')
			frame:SetScript('OnEvent', core.CancelRollEvent)
			table.insert(core.RollSlots, frame)
		end

		frameName = frame:GetName()
		icon = _G[frameName..'IconIconTexture']
		bop = _G[frameName..'IconLootCount']
		name = _G[frameName..'NameFrameName']
		statusbar = _G[frameName..'Timer']
		buttonNeed = _G[frameName..'NeedButton']
		buttonGreed = _G[frameName..'GreedButton']
		buttonDisEnchant = _G[frameName..'DisEnchantButton']

		frame.rollID = rollID
		frame.itemLink = GetLootRollItemLink(rollID)

		lootTexture, lootName, _, lootRarity, lootBoP, canNeed, canGreed, canDisEnchant = GetLootRollItemInfo(rollID)
		color = ITEM_QUALITY_COLORS[lootRarity]

		icon:SetTexture(lootTexture)
		bop:SetText(lootBoP and 'BoP' or 'BoE')
		name:SetText(lootName)
		name:SetVertexColor(color.r, color.g, color.b)
		statusbar:SetMinMaxValues(0, timeLeft)
		statusbar:SetValue(timeLeft)
		if canNeed then buttonNeed:Enable() else buttonNeed:Disable() end
		if canGreed then buttonGreed:Enable() else buttonGreed:Disable() end
		if canDisEnchant then buttonDisEnchant:Enable() else buttonDisEnchant:Disable() end
		SetDesaturation(buttonNeed:GetNormalTexture(), not canNeed)
		SetDesaturation(buttonGreed:GetNormalTexture(), not canGreed)
		SetDesaturation(buttonDisEnchant:GetNormalTexture(), not canDisEnchant)

		for k, v in ipairs(core.RollSlots) do
			if ( v:IsShown() ) then
				if ( k == 1 ) then
					v:SetPoint('TOPLEFT', PredatorLootGroupLootAnchor, 'TOPLEFT', 0, 0)
				else
					v:SetPoint('TOPLEFT', core.RollSlots[k-1], 'BOTTOMLEFT', 0, -50)
				end
			end
		end
		frame:Show()
	end


-- ***** MASTER LOOTER ********************************************************************

	--[[ Determines if the player is the masterlooter
		VOID SetMasterLooter
	]]
	core.SetMasterLooter = function()
		local lootMethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()
		if ( lootMethod == 'master' ) then
			if ( core.AnnounceChannel == 'RAID' ) then
				if ( masterlooterRaidID == nil ) then
					SetAnnounceChannel()
				elseif ( masterlooterRaidID == GetNumRaidMembers() ) then
					if ( masterlooterPartyID == 0 ) then
						core.IsMasterLooter = true
						PLMLM:Show()
					end
				end
			elseif ( core.AnnounceChannel == 'PARTY' ) then
				if ( masterlooterPartyID == 0 ) then
					core.IsMasterLooter = true
					PLMLM:Show()
				else
					core.IsMasterLooter = false
					PLMLM:Hide()
				end
			end
		else
			core.IsMasterLooter = false
			PLMLM:Hide()
		end
	end

	--[[ Assigns an item to a raid-/group- member
		VOID MasterLootAssignLoot()
	]]
	core.MasterLootAssignLoot = function(self)
		local candidate = self.value['Characters']
		if ( PLMLM.slot ~= '' ) then
			GiveMasterLoot(PLMLM.slot, candidate)
			PLMLM.winner = ''
			PLMLM.slot = ''
			PLMLM.lootLink = nil
		else
			debugging(PredatorLootStrings.AssignmentFailed)
		end
		_G['PredatorLootMasterLooterManagementIconIconTexture']:SetTexture()
		CloseDropDownMenus()
	end

	--[[ Builds the MasterLooter DropDown
		VOID InitializeMasterLooterDropDown(FRAME self, INT level)
	]]
	core.InitializeMasterLooterDropDown = function(self, level)
		level = level or 1
		local k, v, i
		local info = {}
		if ( level == 1 ) then
			for k, v in pairs(core.MasterLooterRaidClasses) do
				wipe(info)
				if ( v ) then
					info.text = core.GetClassColor(k)..v
					info.hasArrow = true
					info.notCheckable = true
					info.value = {
						['Classes'] = k
					}
					UIDropDownMenu_AddButton(info, level)
				end
			end
		elseif ( level == 2 ) then
			local classes = UIDROPDOWNMENU_MENU_VALUE['Classes']
			for i = 1, 40 do
				wipe(info)
				candidate = GetMasterLootCandidate(i)
				if ( candidate ) then
					_, class = UnitClass(candidate)
					info.text = candidate
					info.value = {
						['Classes'] = classes,
						['Characters'] = i
					}
					info.notCheckable = true
					info.func = core.MasterLootAssignLoot
					if ( class == classes ) then
						UIDropDownMenu_AddButton(info, level)
					end
				end
			end
		end
	end

	--[[ Determines which classes are in your raid to prepare the MasterLooterDropDown
		VOID UpdateDropDownClasses()
	]]
	core.UpdateDropDownClasses = function()
		-- debugging('ClassDropDown')
		local i, classLoc, class, maxPlayers

		core.MasterLooterRaidClasses['DEATHKNIGHT'] = false
		core.MasterLooterRaidClasses['DRUID'] = false
		core.MasterLooterRaidClasses['HUNTER'] = false
		core.MasterLooterRaidClasses['MAGE'] = false
		core.MasterLooterRaidClasses['PALADIN'] = false
		core.MasterLooterRaidClasses['PRIEST'] = false 
		core.MasterLooterRaidClasses['ROGUE'] = false
		core.MasterLooterRaidClasses['SHAMAN'] = false
		core.MasterLooterRaidClasses['WARLOCK'] = false
		core.MasterLooterRaidClasses['WARRIOR'] = false

		if ( core.AnnounceChannel == 'RAID' ) then
			for i = 1, MAX_RAID_MEMBERS do
				_, _, _, _, classLoc, class = GetRaidRosterInfo(i)
				if ( class ) then
					core.MasterLooterRaidClasses[class] = classLoc
				end
			end
		elseif ( core.AnnounceChannel == 'PARTY' ) then
			for i = 1, 4 do
				classLoc, class = UnitClass('party'..i)
				if ( class ) then
					core.MasterLooterRaidClasses[class] = classLoc
				end
			end
			classLoc, class = UnitClass('player')
			core.MasterLooterRaidClasses[class] = classLoc
		end
		UIDropDownMenu_Initialize(PredatorLootMasterLooterDropDown, core.InitializeMasterLooterDropDown, 'MENU')
	end

	--[[ 
		VOID SetItemToBeRolled(INT slot)
	]]
	core.SetItemToBeRolled = function(slot)
		PLMLM.lootLink = GetLootSlotLink(slot)
		PLMLM.slot = slot
		_G['PredatorLootMasterLooterManagementIconIconTexture']:SetTexture(GetItemIcon(PLMLM.lootLink))
	end

	--[[ Listens and parses the roll-lines from the chat
		VOID RollListener(STRING line)
	]]
	core.RollListener = function(line)
		if ( gmatch(line, RANDOM_ROLL_RESULT) ) then
			local _, _, player, roll, minroll, maxroll = string.find(line, settings.static.RollPattern)
			-- debugging('(player, roll, minroll, maxroll) ('..player..', '..roll..', '..minroll..', '..maxroll..')')
			if ( not core.RollCapture[maxroll] ) then
				core.RollCapture[maxroll] = {}
			end
			if ( (not core.RollCapture[maxroll][player]) or (tonumber(core.RollCapture[maxroll][player]) > tonumber(roll)) ) then
				core.RollCapture[maxroll][player] = roll
			end
		end
	end

	--[[ Evaluate the recorded rolls and announces the winner
		VOID EvaluateRolls()
	]]
	core.EvaluateRolls = function()
		-- debugging('EvaluateRolls()')
		local k, v
		local winnerarray = nil
		for k, v in ipairs(settings.options.AcceptedRolls) do
			-- debugging(k..': '..settings.options.RollDescriptions[v])
			if ( core.RollCapture[tostring(v)] ) then
				-- debugging('found '..v)
				if ( not winnerarray ) then
					winnerarray = core.RollCapture[tostring(v)]
				end
			end
		end

		if ( winnerarray ) then
			local playername, playerroll = '', 0
			for k, v in pairs(winnerarray) do
				-- debugging(k..': '..v)
				if (tonumber(v) > tonumber(playerroll)) then
					playername = k
					playerroll = v
				end
			end
			PLMLM.winner = playername
			core.SendMessage('Winner: '..playername, core.AnnounceChannel)
		else
			core.SendMessage(PredatorLootStrings.ToBeDisenchated, core.AnnounceChannel)
		end
	end


-- ***** TEMPLATE FUNCTIONS (global!) *****************************************************

	--[[ Click-handler for rows in the loot window
		VOID HandleRowClick(FRAME self, STRING button)
	]]
	PredatorLootFunctions.HandleRowClick = function(self, button)
		local row = _G[self:GetName()]
		core.LootWindowClick(self, button, row)
	end

	--[[ Click-handler for the item icons in the loot window
		VOID HandleIconClick(BUTTON self, STRING button)
	]]
	PredatorLootFunctions.HandleIconClick = function(self, button)
		local row = _G[self:GetParent():GetName()]
		core.LootWindowClick(self, button, row)
	end

	--[[ OnMouseOver-handler for the loot-window
		VOID ShowTooltip(BUTTON self)
	]]
	PredatorLootFunctions.ShowTooltip = function(self)
		local slot = _G[self:GetParent():GetName()]:GetID()
		if (LootSlotIsItem(slot)) then
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:SetLootItem(slot)
			CursorUpdate(self)
		end
	end

	--[[  OnMouseOver-handler for the MasterLooter-window
		VOID ShowMasterLooterTooltip(BUTTON self)
	]]
	PredatorLootFunctions.ShowMasterLooterTooltip = function(self)
		if ( PLMLM.lootLink ) then
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:SetHyperlink(PLMLM.lootLink)
			CursorUpdate(self)
		end
	end

	--[[
	
	]]
	PredatorLootFunctions.ShowGroupLootTooltip = function(self)
		local itemLink = self:GetParent().itemLink
		if ( itemLink ) then
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:SetHyperlink(itemLink)
			CursorUpdate(self)
		end
	end

	--[[ Click-handler for the item icon in the MasterLooter-window
		VOID HandleMasterLooterIconClick(BUTTON self, STRING button)
	]]
	PredatorLootFunctions.HandleMasterLooterIconClick = function(self, button)
		if ( button == 'RightButton' ) then
			if ( core.IsMasterLooter ) then
				-- debugging(slot)
				ToggleDropDownMenu(1, nil, PredatorLootMasterLooterDropDown, self, 0, 0)
			end
		end
	end

	--[[ Starts a roll-period
		VOID StartLootPeriod()
	]]
	PredatorLootFunctions.StartLootPeriod = function()
		if ( core.RollInProgress ) then
			debugging(PredatorLootStrings.RollInProgress)
		else
			if ( PLMLM.lootLink ) then
				core.RollInProgress = true
				wipe(core.RollCapture)
				PredatorLootTrigger:RegisterEvent('CHAT_MSG_SYSTEM')
				core.SendMessage(PredatorLootStrings.StartRollFor..PLMLM.lootLink, 'RAID_WARNING')
			else
				debugging(PredatorLootStrings.NoItem)
			end
		end
	end

	--[[ Ends a roll period
		VOID EndLootPeriod()
	]]
	PredatorLootFunctions.EndLootPeriod = function()
		if ( not core.RollInProgress ) then
			debugging(PredatorLootStrings.NoRollInProgress)
		else
			PredatorLootTrigger:UnregisterEvent('CHAT_MSG_SYSTEM')
			core.RollInProgress = false
			core.EvaluateRolls()
		end
	end

	--[[
		VOID AnnounceLootRules()
	]]
	PredatorLootFunctions.AnnounceLootRules = function()
		if ( core.AnnounceChannel ~= '' and core.AnnounceChannel ~= 'SOLO' ) then 
			local v
			for _, v in ipairs(settings.options.AcceptedRolls) do
				core.SendMessage(settings.options.RollDescriptions[v], core.AnnounceChannel)
			end
		else
			debugging(PredatorLootStrings.NoAnnounce)
		end
	end

	--[[
		VOID GroupLootRoll(BUTTON button, INT ROLL)
	]]
	PredatorLootFunctions.GroupLootRoll = function(button, roll)
		local rollID = button:GetParent().rollID
		RollOnLoot(rollID, roll)
	end

	--[[
		VOID GroupLootTimerOnUpdate(FRAME self)
	]]
	PredatorLootFunctions.GroupLootTimerOnUpdate = function(self)
		self:SetValue(GetLootRollTimeLeft(self:GetParent().rollID))
	end


-- ****************************************************************************************

PredatorLootTrigger:RegisterEvent('ADDON_LOADED')
PredatorLootTrigger:RegisterEvent('LOOT_OPENED')
PredatorLootTrigger:RegisterEvent('LOOT_CLOSED')
PredatorLootTrigger:RegisterEvent('PARTY_LEADER_CHANGED')
PredatorLootTrigger:RegisterEvent('PARTY_LOOT_METHOD_CHANGED')
PredatorLootTrigger:RegisterEvent('PARTY_MEMBERS_CHANGED')
PredatorLootTrigger:RegisterEvent('RAID_ROSTER_UPDATE')
PredatorLootTrigger:RegisterEvent('START_LOOT_ROLL')
PredatorLootTrigger:RegisterEvent('PLAYER_REGEN_DISABLED')
PredatorLootTrigger:RegisterEvent('PLAYER_REGEN_ENABLED')
PredatorLootTrigger:SetScript('OnEvent', function(self, event, addon)

	if ( event == 'LOOT_OPENED' ) then
		core.OpenLoot()
	elseif ( event == 'LOOT_CLOSED' ) then
		core.CloseLoot()
	elseif ( event == 'PARTY_LEADER_CHANGED' or
			 event == 'PARTY_LOOT_METHOD_CHANGED' or
			 event == 'PARTY_MEMBERS_CHANGED' or
			 event == 'RAID_ROSTER_UPDATE' ) then
		core.SetAnnounceChannel()
		core.SetMasterLooter()
		core.UpdateDropDownClasses()
	elseif ( event == 'START_LOOT_ROLL' ) then
		core.StartGroupLoot(arg1, arg2)
	elseif ( event == 'CHAT_MSG_SYSTEM' ) then
		core.RollListener(arg1)
	elseif ( event == 'PLAYER_REGEN_DISABLED' ) then
		PLMLM:Hide()
	elseif ( event == 'PLAYER_REGEN_ENABLED' and core.IsMasterLooter ) then
		PLMLM:Show()
	elseif ( event == 'ADDON_LOADED' ) then
		if ( addon ~= ADDON_NAME ) then return end

		debugging('PredatorLoot loaded...')

		PredatorLootTrigger:UnregisterEvent('ADDON_LOADED')
		UIParent:UnregisterEvent('START_LOOT_ROLL')
		UIParent:UnregisterEvent('CANCEL_LOOT_ROLL')

		-- do
			-- if ( not PredatorLootOptions ) then
				-- PredatorLootOptions = {}
			-- end
			-- local k, v
			-- for k, v in pairs(settings.options) do
				-- if type(v) ~= type(PredatorLootOptions[k]) then
					-- PredatorLootOptions[k] = v
				-- end
			-- end
			-- settings.options = PredatorLootOptions
		-- end
	end

end)