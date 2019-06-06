--[[
Copyright 2018-2019 Sean McNamara <smcnam@gmail.com>.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

]]

local LCHAT = LibStub("libChat-1.0")
local LAM = LibStub("LibAddonMenu-2.0")

local el_name = "EventLogger"
local el_playerName = GetUnitName("player")
local el_lplayerName = string.lower(el_playerName)
local el_playerAt = GetUnitDisplayName("player")
local el_lplayerAt = string.lower(el_playerAt)
local el_savedVarsName = "EventLoggerDB"
local el_panelData = {
	type = "panel",
	name = el_name,
	displayName = el_name,
	author = "@Coorbin",
	version = "1.0",
	slashCommand = "/elset",
	registerForRefresh = true,
	registerForDefaults = false,
	website = "https://github.com/allquixotic/ESOEventLoggerAddon",
}
local el_savedVariables = {}
local el_eventName = nil
local el_startTime = nil
local el_saving = false
local el_selectedDeleteEvent = nil
local el_editboxName = nil
local el_allEventNames = {}

local chatChannels = {
    [0] = "Say",
    [1] = "Yell",
    [2] = "Whisper",
    [3] = "Group",
    [4] = "Outgoing Whisper",
    [5] = "Unused 1",
    [6] = "Emote",
    [7] = "NPC Say",
    [8] = "NPC Yell",
    [9] = "NPC Whisper",
    [10] = "NPC Emote",
    [11] = "System",
    [12] = "Guild 1",
    [13] = "Guild 2",
    [14] = "Guild 3",
    [15] = "Guild 4",
    [16] = "Guild 5",
    [17] = "Officer 1",
    [18] = "Officer 2",
    [19] = "Officer 3",
    [20] = "Officer 4",
    [21] = "Officer 5",
    [22] = "Custom 1",
    [23] = "Custom 2",
    [24] = "Custom 3",
    [25] = "Custom 4",
    [26] = "Custom 5",
    [27] = "Custom 6",
    [28] = "Custom 7",
    [29] = "Custom 8",
    [30] = "Custom 9",
    [31] = "Zone",
    [32] = "Zone Intl 1",
    [33] = "Zone Intl 2",
    [34] = "Zone Intl 3",
    [35] = "Zone Intl 4"
}

local function el_yo()
	GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(el_savedVarsName)
end

local function el_containsWholeWord(input, word)
	return input:gsub('%a+', ' %1 '):match(' (' .. word .. ') ') ~= nil
end

local function el_startsWith(str, start)
   return str:sub(1, #start) == start
end

local function el_getAllEventNames()
	local retval = {}
	if el_savedVariables.logs == nil then return retval end
	for k,v in pairs(el_savedVariables.logs) do
		table.insert(retval, k)
	end
	return retval
end

local function el_mutateAllEventNames()
	while #el_allEventNames > 0 do
		table.remove(el_allEventNames)
	end
	for k,v in pairs(el_getAllEventNames()) do
		table.insert(el_allEventNames, v)
	end
end

local el_defaultVars = {
	logs = {},
	channelFilter = {}
}

local function el_isChannelEnabled(chanNum)
	chanNum = tonumber(chanNum)
	return el_savedVariables.channelFilter == nil or (el_savedVariables.channelFilter[chanNum] == nil or el_savedVariables.channelFilter[chanNum] == true)
end

local function el_setChannelEnabled(chanNum, isEnabled)
	chanNum = tonumber(chanNum)
	if el_savedVariables.channelFilter == nil then el_savedVariables.channelFilter = {} end
	el_savedVariables.channelFilter[chanNum] = isEnabled
	el_yo()
end

local function el_split(text)
	local spat, epat, buf, quoted = [=[^(['"])]=], [=[(['"])$]=]
	local retval = {}
	for str in text:gmatch("%S+") do
		local squoted = str:match(spat)
		local equoted = str:match(epat)
		local escaped = str:match([=[(\*)['"]$]=])
		if squoted and not quoted and not equoted then
			buf, quoted = str, squoted
		elseif buf and equoted == quoted and #escaped % 2 == 0 then
			str, buf, quoted = buf .. ' ' .. str, nil, nil
		elseif buf then
			buf = buf .. ' ' .. str
		end
		if not buf then table.insert(retval, (str:gsub(spat,""):gsub(epat,""))) end
	end
	if buf then 
		return { [1] = "Missing matching quote for "..buf } 
	else
		return retval
	end
end

local function el_logon(argu)
	local eventNameFilled = false
	if argu == nil then argu = "" end
	local args = el_split(argu)
	if #args > 0 then
		el_eventName = args[1]
		eventNameFilled = true
	else
		el_eventName = tostring(GetTimeStamp())
	end
	el_startTime = tostring(GetTimeStamp())
	el_saving = true
	if eventNameFilled == false then
		d("EventLogger Addon: Started saving chat for event " .. el_eventName .. ". To customize the event name, supply it as a parameter with a space after the /logon command.")
	else
		d("EventLogger Addon: Started saving chat for event " .. el_eventName .. ".")
	end
	el_mutateAllEventNames()
end

local function el_logoff(argu)
	if el_savedVariables["logs"] ~= nil and el_savedVariables["logs"][el_eventName] ~= nil then
		el_savedVariables["logs"][el_eventName]["endTime"] = GetTimeStamp()
	end
	el_saving = false
	el_eventName = nil
	el_startTime = nil
	if el_saving == true then
		d("EventLogger Addon: Stopped saving chat for event " .. el_eventName .. ".")
	else
		d("EventLogger Addon: Wasn't saving chat! To start logging chat, use the /logon command.")
	end
end

local function el_onChatMessage(channelID, from, text, isCustomerService, fromDisplayName)
	if el_saving == true and el_isChannelEnabled(channelID) then
		if el_savedVariables["logs"] == nil then 
			el_savedVariables["logs"] = {} 
		end
		if el_savedVariables["logs"][el_eventName] == nil then 
			el_savedVariables["logs"][el_eventName] = {} 
		end
		el_savedVariables["logs"][el_eventName]["startTime"] = el_startTime
		if el_savedVariables["logs"][el_eventName]["chatLines"] == nil then
			el_savedVariables["logs"][el_eventName]["chatLines"] = {} 
		end
		table.insert(el_savedVariables["logs"][el_eventName]["chatLines"], {
			channelID = channelID,
			from = from,
			text = text,
			fromDisplayName = fromDisplayName,
			timestamp = GetTimeStamp()
		})
		el_yo()
	end
	return text
end

local el_optionsData = {
	{
		type = "description",
		title = "Status",
		text = function()
			local p = "Currently "
			if el_saving == false then
				p = p .. "NOT "
			end
			p = p .. "logging event"
			if el_saving == true then
				p = p .. " named " .. el_eventName
			end
			p = p .. ". There are " .. #el_getAllEventNames() .. " events stored in the main SavedVariables file for EventLogger."
			return p
		end,
		width = "full"
	},
	{
		type = "divider",
		width = "full"
	},
	{
		type = "editbox",
		width = "half",
		name = "Event Name",
		getFunc = function()
			return el_editboxName
		end,
		setFunc = function(var)
			el_editboxName = var
		end,
		isMultiline = false,
		isExtraWide = false,
		tooltip = "The event name to record in the log."
	},
	{
		type = "button",
		name = "Start Event Log",
		func = function() 
			el_logon(el_editboxName)
		end,
		width = "half",
		isDangerous = false
	},
	{
		type = "divider",
		width = "full"
	},
	{
		type = "button",
		name = "Stop Event Log",
		func = function()
			el_logoff(el_editboxName)
		end,
		width = "half",
		isDangerous = false
	},
	{
		type = "divider",
		width = "full"
	},
	{
		type = "button",
		name = "Clear ALL logs",
		func = function()
			el_savedVariables.logs = {}
			el_yo()
			el_mutateAllEventNames()
			d("Deleted ALL EventLogger logs!")
		end,
		width = "half",
		isDangerous = true,
		warning = "Are you SURE you want to completely clear all your EventLogger logs? Note: Doesn't affect ChatLog.txt from the /chatlog command."
	},
	{
		type = "divider",
		width = "full"
	},
	{
		type = "dropdown",
		name = "Event Name",
		choices = el_allEventNames,
		width = "half",
		scrollable = true,
		getFunc = function()
			return el_selectedDeleteEvent
		end,
		setFunc = function(var)
			el_selectedDeleteEvent = var
		end
	},
	{
		type = "button",
		name = "Delete log",
		func = function()
			if el_selectedDeleteEvent ~= nil then
				el_savedVariables.logs[el_selectedDeleteEvent] = nil
				el_mutateAllEventNames()
				d("Deleted log for " .. el_selectedDeleteEvent)
			end
		end,
		width = "half",
		isDangerous = true,
		warning = function()
			if el_selectedDeleteEvent == nil then el_selectedDeleteEvent = "" end
			local retval = "Are you SURE you want to delete EventLogger event named " .. el_selectedDeleteEvent .. "? Note: Doesn't affect ChatLog.txt from the /chatlog command."
			if el_selectedDeleteEvent == "" then el_selectedDeleteEvent = nil end
			return retval
		end
	},
	{
		type = "divider",
		width = "full"
	}
}

local function el_generateOptions()
	for k,v in pairs(chatChannels) do
		table.insert(el_optionsData, {
			type = "checkbox",
			name = "Log " .. v .. "?",
			getFunc = function() 
				return el_isChannelEnabled(k)
			end,
			setFunc = function(var) 
				el_setChannelEnabled(k, var)
			end,
			tooltip = "Whether or not to log messages from " .. v .. " channel.",
			default = true,
			width = "full",
		})
	end
end

local function el_OnAddOnLoaded(event, addonName)
	if addonName == el_name then
		EVENT_MANAGER:UnregisterForEvent(el_name, EVENT_ADD_ON_LOADED)
		el_savedVariables = ZO_SavedVars:NewAccountWide(el_savedVarsName, 15, nil, el_defaultVars)
		el_mutateAllEventNames()
		LAM:RegisterAddonPanel(addonName, el_panelData)
		el_generateOptions()
		LAM:RegisterOptionControls(addonName, el_optionsData)	
		SLASH_COMMANDS["/logon"] = el_logon
		SLASH_COMMANDS["/logoff"] = el_logoff
		SLASH_COMMANDS["/logclear"] = el_logclear
		LCHAT:registerText(el_onChatMessage, el_name)
		d(#el_allEventNames)
	end
end

EVENT_MANAGER:RegisterForEvent(el_name, EVENT_ADD_ON_LOADED, el_OnAddOnLoaded)