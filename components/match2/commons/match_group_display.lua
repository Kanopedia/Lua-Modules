---
-- @Liquipedia
-- wiki=commons
-- page=Module:MatchGroup/Display
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Arguments = require('Module:Arguments')
local Array = require('Module:Array')
local FeatureFlag = require('Module:FeatureFlag')
local Lua = require('Module:Lua')
local Table = require('Module:Table')
local WarningBox = require('Module:WarningBox')

local Match = Lua.import('Module:Match', {requireDevIfEnabled = true})
local MatchGroupBase = Lua.import('Module:MatchGroup/Base', {requireDevIfEnabled = true})
local MatchGroupConfig = Lua.loadDataIfExists('Module:MatchGroup/Config')
local MatchGroupInput = Lua.import('Module:MatchGroup/Input', {requireDevIfEnabled = true})
local MatchGroupUtil = Lua.import('Module:MatchGroup/Util', {requireDevIfEnabled = true})
local WikiSpecific = Lua.import('Module:Brkts/WikiSpecific', {requireDevIfEnabled = true})

local MatchGroupDisplay = {}

--[[
Reads a matchlist input spec, saves it to LPDB, and displays the matchlist.
]]
function MatchGroupDisplay.MatchlistBySpec(args)
	local options, optionsWarnings = MatchGroupBase.readOptions(args, 'matchlist')
	local matches = MatchGroupInput.readMatchlist(options.bracketId, args)
	Match.storeMatchGroup(matches, options)

	local matchlistNode
	if options.show then
		local MatchlistDisplay = Lua.import('Module:MatchGroup/Display/Matchlist', {requireDevIfEnabled = true})
		local MatchlistContainer = WikiSpecific.getMatchGroupContainer('matchlist')
		matchlistNode = MatchlistContainer({
			bracketId = options.bracketId,
			config = MatchlistDisplay.configFromArgs(args),
		})
	end

	local parts = Array.extend(
		{matchlistNode},
		Array.map(optionsWarnings, WarningBox.display)
	)
	return table.concat(Array.map(parts, tostring))
end

--[[
Reads a bracket input spec, saves it to LPDB, and displays the bracket.
]]
function MatchGroupDisplay.BracketBySpec(args)
	local options, optionsWarnings = MatchGroupBase.readOptions(args, 'bracket')
	local matches, bracketWarnings = MatchGroupInput.readBracket(options.bracketId, args, options)
	Match.storeMatchGroup(matches, options)

	local bracketNode
	if options.show then
		local BracketDisplay = Lua.import('Module:MatchGroup/Display/Bracket', {requireDevIfEnabled = true})
		local BracketContainer = WikiSpecific.getMatchGroupContainer('bracket')
		bracketNode = BracketContainer({
			bracketId = options.bracketId,
			config = BracketDisplay.configFromArgs(args),
		})
	end

	local parts = Array.extend(
		Array.map(optionsWarnings, WarningBox.display),
		Array.map(bracketWarnings, WarningBox.display),
		{bracketNode}
	)
	return table.concat(Array.map(parts, tostring))
end

--[[
Displays a matchlist or bracket specified by ID.
]]
function MatchGroupDisplay.MatchGroupById(args)
	local bracketId = args.id or args[1]
	args.id = bracketId
	args[1] = bracketId
	assert(bracketId, 'Missing bracket ID')

	local matches = MatchGroupUtil.fetchMatches(bracketId)
	assert(#matches ~= 0, 'No data found for bracketId=' .. bracketId)
	local matchGroupType = matches[1].bracketData.type

	local config
	if matchGroupType == 'matchlist' then
		local MatchlistDisplay = Lua.import('Module:MatchGroup/Display/Matchlist', {requireDevIfEnabled = true})
		config = MatchlistDisplay.configFromArgs(args)
	else
		local BracketDisplay = Lua.import('Module:MatchGroup/Display/Bracket', {requireDevIfEnabled = true})
		config = BracketDisplay.configFromArgs(args)
	end

	MatchGroupInput.applyOverrideArgs(matches, args)

	local MatchGroupContainer = WikiSpecific.getMatchGroupContainer(matchGroupType)
	return MatchGroupContainer({
		bracketId = bracketId,
		config = config,
	})
end

--[[
Displays a singleMatch specified by a bracket ID and matchID.
]]
function MatchGroupDisplay.MatchByMatchId(args)
	local bracketId = args.id
	local matchId = args.matchid
	assert(bracketId, 'Missing bracket ID')
	assert(matchId, 'Missing match ID')

	matchId = MatchGroupUtil.matchIdFromKey(matchId)

	local matchGroup = MatchGroupUtil.fetchMatchGroup(bracketId)
	local fullMatchId = bracketId .. '_' .. matchId
	local match = matchGroup.matchesById[fullMatchId]

	assert(match, 'Match bracketId= ' .. bracketId .. ' matchId=' .. matchId .. ' not found')

	local SingleMatchDisplay = Lua.import('Module:MatchGroup/Display/SingleMatch', {requireDevIfEnabled = true})
	local config = SingleMatchDisplay.configFromArgs(args)

	local MatchGroupContainer = WikiSpecific.getMatchContainer('singleMatch')
	return MatchGroupContainer({
		matchId = fullMatchId,
		config = config,
	})
end


-- Entry point of Template:Matchlist
function MatchGroupDisplay.TemplateMatchlist(frame)
	local args = Arguments.getArgs(frame)
	return MatchGroupDisplay.MatchlistBySpec(args)
end

-- Entry point of Template:Bracket
function MatchGroupDisplay.TemplateBracket(frame)
	local args = Arguments.getArgs(frame)
	return MatchGroupDisplay.BracketBySpec(args)
end

-- Entry point of Template:ShowSingleMatch
function MatchGroupDisplay.TemplateShowSingleMatch(frame)
	local args = Arguments.getArgs(frame)
	return MatchGroupDisplay.MatchByMatchId(args)
end

-- Entry point of Template:ShowBracket, Template:DisplayMatchGroup
function MatchGroupDisplay.TemplateShowBracket(frame)
	local args = Arguments.getArgs(frame)
	return MatchGroupDisplay.MatchGroupById(args)
end

if FeatureFlag.get('perf') then
	MatchGroupDisplay.perfConfig = Table.getByPathOrNil(MatchGroupConfig, {'perf'})
	require('Module:Performance/Util').setupEntryPoints(MatchGroupDisplay)
end

Lua.autoInvokeEntryPoints(MatchGroupDisplay, 'Module:MatchGroup/Display')


MatchGroupDisplay.deprecatedCategory = '[[Category:Pages using deprecated Match Group functions]]'

-- Unused entry point
-- Deprecated
function MatchGroupDisplay.bracket(frame)
	return MatchGroupDisplay.TemplateBracket(frame) .. MatchGroupDisplay.deprecatedCategory
end

-- Deprecated
function MatchGroupDisplay.luaBracket(_, args)
	return tostring(MatchGroupDisplay.MatchGroupById(args)) .. MatchGroupDisplay.deprecatedCategory
end

-- Unused entry point
-- Deprecated
function MatchGroupDisplay.matchlist(frame)
	return MatchGroupDisplay.TemplateMatchlist(frame) .. MatchGroupDisplay.deprecatedCategory
end

-- Deprecated
function MatchGroupDisplay.luaMatchlist(_, args)
	return tostring(MatchGroupDisplay.MatchGroupById(args)) .. MatchGroupDisplay.deprecatedCategory
end

-- Entry point from Template:ShowBracket and direct #invoke
-- Deprecated
function MatchGroupDisplay.Display(frame)
	return tostring(MatchGroupDisplay.TemplateShowBracket(frame)) .. MatchGroupDisplay.deprecatedCategory
end

-- Entry point from direct #invoke
-- Deprecated
function MatchGroupDisplay.DisplayDev(frame)
	local args = Arguments.getArgs(frame)
	args.dev = true
	return tostring(MatchGroupDisplay.TemplateShowBracket(args)) .. MatchGroupDisplay.deprecatedCategory
end

return MatchGroupDisplay
