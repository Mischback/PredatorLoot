--[[ 
]]

local ADDON_NAME, ns = ...								-- get the addons namespace to exchange functions between core and layout
local settings = CreateFrame('Frame')					-- create the settings
-- *****************************************************

settings.static = {
	['RollPattern'] = '(%S+) %D+ (%d+)%D+%((%d+)%-(%d+)%)'
}

settings.options = {
	['AcceptedRolls'] = {
		100, 
		200, 
		300,
	},
	['RollDescriptions'] = {
		[100] = '/rnd 100: Main-Specc, no item received', 
		[200] = '/rnd 200: Main-Specc, already received an item', 
		[300] = '/rnd 300: Greed or Twink',
	},
}

-- *****************************************************
ns.settings = settings									-- handover of the settings to the namespace