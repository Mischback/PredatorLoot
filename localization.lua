--[[
	COMMON UTF-8 ESCAPE-Strings
	
	�	--> 	c3 a4	--> \195\164
	�	--> 	c3 84	--> \195\132
	�	--> 	c3 b6	--> \195\182
	�	--> 	c3 96	--> \195\150
	�	-->		c3 bc	--> \195\188
	�	--> 	c3 9c	--> \195\156
	�	--> 	c3 9f	--> \195\159
]]

local t = GetLocale()

-- if (t == 'deDE') then

-- else
	PredatorLootStrings = {
		['MasterLooterStartButton'] = 'Start roll period',
		['MasterLooterEndButton'] = 'End roll period',
		['MasterLooterAnnounceRulesButton'] = 'Announce loot rules',
		['MasterLooterConfigButton'] = 'Open configuration dialog',
		['RollInProgress'] = 'FAIL: There is already a roll in progress!',
		['NoRollInProgress'] = 'FAIL: No roll in progress!',
		['AssignmentFailed'] = 'FAIL: Assignment failed! Please note that the assignment only works while the loot window is open!',
		['NoItem'] = 'FAIL: No item selected to roll about!',
	}
-- end
