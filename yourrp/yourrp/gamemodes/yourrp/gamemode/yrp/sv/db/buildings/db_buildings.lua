--Copyright (C) 2017-2022 D4KiR (https://www.gnu.org/licenses/gpl.txt)

-- DO NOT TOUCH THE DATABASE FILES! If you have errors, report them here:
-- https://discord.gg/sEgNZxg

local DATABASE_NAME_DOORS = "yrp_" .. GetMapNameDB() .. "_doors"
YRP_SQL_ADD_COLUMN(DATABASE_NAME_DOORS, "buildingID", "TEXT DEFAULT '-1'" )
YRP_SQL_ADD_COLUMN(DATABASE_NAME_DOORS, "level", "INTEGER DEFAULT 1" )
YRP_SQL_ADD_COLUMN(DATABASE_NAME_DOORS, "keynr", "INTEGER DEFAULT -1" )

local DATABASE_NAME_BUILDINGS = "yrp_" .. GetMapNameDB() .. "_buildings"
YRP_SQL_ADD_COLUMN(DATABASE_NAME_BUILDINGS, "groupID", "INTEGER DEFAULT 0" )
YRP_SQL_ADD_COLUMN(DATABASE_NAME_BUILDINGS, "buildingprice", "TEXT DEFAULT 100" )
YRP_SQL_ADD_COLUMN(DATABASE_NAME_BUILDINGS, "ownerCharID", "TEXT DEFAULT ''" )
YRP_SQL_ADD_COLUMN(DATABASE_NAME_BUILDINGS, "name", "TEXT DEFAULT 'Building'" )
YRP_SQL_ADD_COLUMN(DATABASE_NAME_BUILDINGS, "text_header", "TEXT DEFAULT ''" )
YRP_SQL_ADD_COLUMN(DATABASE_NAME_BUILDINGS, "text_description", "TEXT DEFAULT ''" )
YRP_SQL_ADD_COLUMN(DATABASE_NAME_BUILDINGS, "bool_canbeowned", "INT DEFAULT 1" )
YRP_SQL_ADD_COLUMN(DATABASE_NAME_BUILDINGS, "int_securitylevel", "TEXT DEFAULT 0" )

YRP_SQL_ADD_COLUMN(DATABASE_NAME_BUILDINGS, "bool_lockdown", "INT DEFAULT 1" )

function YRPIsUnderGroup(uid, tuid)
	local group = YRP_SQL_SELECT( "yrp_ply_groups", "*", "uniqueID = '" .. uid .. "'" )
	group = group[1]
	local undergroup = YRP_SQL_SELECT( "yrp_ply_groups", "*", "uniqueID = '" .. group.int_parentgroup .. "'" )
	if IsNotNilAndNotFalse(undergroup) then
		undergroup = undergroup[1]
		if tonumber(undergroup.uniqueID) == tonumber(tuid) then
			return true
		else
			return YRPIsUnderGroup(undergroup.uniqueID, tuid)
		end
	end
	return false
end

function YRPIsUnderGroupOf(ply, uid)
	local ply_group = YRP_SQL_SELECT( "yrp_ply_groups", "*", "uniqueID = '" .. ply:GetGroupUID() .. "'" )
	if IsNotNilAndNotFalse(ply_group) then
		ply_group = ply_group[1]
		local group = YRP_SQL_SELECT( "yrp_ply_groups", "*", "uniqueID = '" .. ply_group.uniqueID .. "'" )
		group = group[1]
		return YRPIsUnderGroup(group.uniqueID, uid)
	else
		return false
	end
end

function YRPAllowedToUseDoor(id, ply, door)
	if ply:HasAccess( "YRPAllowedToUseDoor" ) then
		return true
	else
		local _tmpBuildingTable = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "*", "uniqueID = '" .. id .. "'" )
		if IsNotNilAndNotFalse(_tmpBuildingTable) then
			local bui_cuid = _tmpBuildingTable[1].ownerCharID
			local bui_guid = _tmpBuildingTable[1].groupID
			if (tostring( bui_cuid) == "" or tostring( bui_cuid) == " " ) and tonumber(_tmpBuildingTable[1].groupID) == -1 then
				return true
			else
				local _tmpChaTab = YRP_SQL_SELECT( "yrp_characters", "*", "uniqueID = " .. bui_cuid)

				local removeowner = false
				if !IsNotNilAndNotFalse(_tmpChaTab) then -- If char not available anymore => remove ownership
					YRP_SQL_UPDATE(DATABASE_NAME_BUILDINGS, {["ownerCharID"] = ""}, "uniqueID = '" .. id .. "'" )
					
					door:SetYRPString( "ownerRPName", "" )
					door:SetYRPInt( "ownerGroupUID", -99)
					door:SetYRPString( "ownerGroup", "" )
					door:SetYRPInt( "ownerCharID", 0)
					door:SetYRPBool( "bool_hasowner", false)
					YRPFireUnlock( door )
				else
					local grp_id = ply:GetGroupUID()

					if tostring( bui_cuid) == tostring(ply:CharID() ) then
						return true
					elseif tonumber( bui_guid) == tonumber(grp_id) then
						return true
					elseif YRPIsUnderGroupOf(ply, bui_guid) then
						return true
					else
						YRP.msg( "note", "[YRPAllowedToUseDoor] not allowed" )
						return false
					end
					return false
				end
			end
		else
			YRP.msg( "note", "[YRPAllowedToUseDoor] not allowed 2" )
			return false
		end
	end
end

function YRPSearchForDoors()
	YRP.msg( "db", "[Buildings] Search Map for Doors" )

	for k, v in pairs(GetAllDoors() ) do
		YRP_SQL_INSERT_INTO_DEFAULTVALUES( "yrp_" .. GetMapNameDB() .. "_buildings" )

		local _tmpBuildingTable = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "*", nil)
		if IsNotNilAndNotFalse(_tmpBuildingTable) then
			YRP_SQL_INSERT_INTO( "yrp_" .. GetMapNameDB() .. "_doors", "buildingID", "'" .. _tmpBuildingTable[table.Count(_tmpBuildingTable)].uniqueID .. "'" )

			local _tmpDoorsTable = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_doors", "*", nil)
		end
	end

	local allDoorsNum = table.Count(GetAllDoors() )
	YRP.msg( "db", "[Buildings] Done finding them ( " .. allDoorsNum .. " doors found)" )
	return allDoorsNum
end

util.AddNetworkString( "nws_yrp_loaded_doors" )
function YRPLoadDoors()
	if GetGlobalYRPBool( "bool_building_system", false) then
		YRP.msg( "db", "[Buildings] Setting up Doors!" )
		local _tmpDoors = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_doors", "*", nil)

		if IsNotNilAndNotFalse(_tmpDoors) then
			for i, door in pairs(GetAllDoors() ) do
				if WORKED(_tmpDoors[i], "YRPLoadDoors 2" ) then
					door:SetYRPString( "buildingID", _tmpDoors[i].buildingID)
					door:SetYRPString( "uniqueID", i)
					HasUseFunction( door)
				else
					YRP.msg( "note", "[Buildings] more doors, then in list!" )
				end
			end
		end

		local _tmpBuildings = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "*", nil)
		if IsNotNilAndNotFalse(_tmpBuildings) then
			for k, v in pairs(GetAllDoors() ) do
				for l, w in pairs(_tmpBuildings) do
					if tonumber(w.uniqueID) == tonumber( v:GetYRPString( "buildingID" ) ) then
						v:SetYRPBool( "bool_canbeowned", w.bool_canbeowned)
						v:SetYRPBool( "bool_hasowner", false)
						if !strEmpty(w.ownerCharID) then
							local tabChar = YRP_SQL_SELECT( "yrp_characters", "*", "uniqueID = " .. w.ownerCharID)
							if IsNotNilAndNotFalse(tabChar) then
								tabChar = tabChar[1]
								if IsNotNilAndNotFalse(tabChar.rpname) then
									v:SetYRPString( "ownerRPName", tabChar.rpname)
									v:SetYRPInt( "ownerCharID", tonumber(w.ownerCharID) )
									v:SetYRPBool( "bool_hasowner", true)
								end
							end
						else
							if tonumber(w.groupID) != 0 then
								local _tmpGroupName = YRP_SQL_SELECT( "yrp_ply_groups", "uniqueID, string_name", "uniqueID = " .. w.groupID)
								if IsNotNilAndNotFalse(_tmpGroupName) then
									_tmpGroupName = _tmpGroupName[1]
									if IsNotNilAndNotFalse(_tmpGroupName) then
										v:SetYRPInt( "ownerGroupUID", _tmpGroupName.uniqueID)
										v:SetYRPString( "ownerGroup", tostring(_tmpGroupName.string_name) )
										v:SetYRPBool( "bool_hasowner", true)
									end
								end
							end
						end

						w.int_securitylevel = tonumber(w.int_securitylevel)
						if w.int_securitylevel > 0 then
							v:SetYRPInt( "int_securitylevel", w.int_securitylevel)
						end

						if v:SecurityLevel() > 0 then
							YRPFireLock( v )
						else
							YRPFireUnlock( v )
						end

						if !strEmpty(w.text_header) then
							v:SetYRPString( "text_header", w.text_header)
						end
						if !strEmpty(w.text_description) then
							v:SetYRPString( "text_description", w.text_description)
						end

						break
					end
				end
			end
		end

		--YRP.msg( "db", "[Buildings] Map Doors are now available!" )
		SetGlobalYRPBool( "loaded_doors", true)
		net.Start( "nws_yrp_loaded_doors" )
		net.Broadcast()
	end
end

function YRPCheckMapDoors()
	--YRP.msg( "db", "[Buildings] Get Database Doors and Buildings" )
	local _tmpTable = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_doors", "*", nil)
	local _tmpTable2 = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "*", nil)
	if IsNotNilAndNotFalse(_tmpTable) and IsNotNilAndNotFalse(_tmpTable2) then
		--YRP.msg( "db", "[Buildings] Found! ( " .. tostring(table.Count(_tmpTable) ) .. " Doors | " .. tostring(table.Count(_tmpTable) ) .. " Buildings)" )
		local doors = GetAllDoors()
		if (table.Count(_tmpTable) ) < (table.Count( doors) ) then
			YRP.msg( "db", "[Buildings] New doors found!" )
			YRPSearchForDoors()
		end
	else
		YRPSearchForDoors()
	end

	YRPLoadDoors()
end

util.AddNetworkString( "nws_yrp_sendBuildingInfo" )
util.AddNetworkString( "nws_yrp_getBuildingInfo" )
util.AddNetworkString( "nws_yrp_getBuildings" )
util.AddNetworkString( "nws_yrp_changeBuildingName" )
util.AddNetworkString( "nws_yrp_changeBuildingID" )
util.AddNetworkString( "nws_yrp_changeBuildingPrice" )
util.AddNetworkString( "nws_yrp_changeBuildingSL" )

util.AddNetworkString( "nws_yrp_changeBuildingHeader" )
util.AddNetworkString( "nws_yrp_changeBuildingDescription" )

util.AddNetworkString( "nws_yrp_getBuildingGroups" )

util.AddNetworkString( "nws_yrp_setBuildingOwnerGroup" )

util.AddNetworkString( "nws_yrp_buyBuilding" )
util.AddNetworkString( "nws_yrp_removeOwner" )
util.AddNetworkString( "nws_yrp_sellBuilding" )

util.AddNetworkString( "nws_yrp_addnewbuilding" )
net.Receive( "nws_yrp_addnewbuilding", function( len, ply )
	if !ply:HasAccess( "nws_yrp_addnewbuilding" ) then
		YRP.msg( "note", ply:Nick() .. " has no rights to change Building." )
		return 
	end

	YRP_SQL_INSERT_INTO_DEFAULTVALUES( "yrp_" .. GetMapNameDB() .. "_buildings" )
end)

util.AddNetworkString( "nws_yrp_door_anim" )

function YRPFireUnlock( ent, owner )
	ent:Fire( "Unlock" )
	if EntityAlive( owner ) then
		owner:EmitSound("npc/metropolice/gear" .. math.random( 1, 7 ) .. ".wav")
		
		net.Start( "nws_yrp_door_anim" )
			net.WriteEntity( owner )
			net.WriteString( "unlock" )
		net.Broadcast()
	end
end

function YRPFireLock( ent, owner )
	ent:Fire( "Lock" )
	if EntityAlive( owner ) then
		owner:EmitSound("npc/metropolice/gear" ..  math.random( 1, 7 ) .. ".wav")

		net.Start( "nws_yrp_door_anim" )
			net.WriteEntity( owner )
			net.WriteString( "lock" )
		net.Broadcast()
	end
end

function YRPUnlockDoor( ply, ent, nr )
	if YRPCanLock( ply, ent ) then
		YRPFireUnlock( ent, ply )
		return true
	end
	return false
end

function YRPLockDoor( ply, ent, nr )
	if YRPCanLock( ply, ent ) then
		YRPFireLock( ent, ply )
		return true
	end
	return false
end

function YRPOpenDoor( ply, ent, nr )
	if YRPCanLock( ply, ent, true ) then
		if ent:SecurityLevel() > 0 and ply:SecurityLevel() >= ent:SecurityLevel() then
			local locked = ent:GetSaveTable().m_bLocked
			if locked then
				YRPFireUnlock( ent )
			end

			local currentstate = ent:GetSaveTable().m_toggle_state
			if currentstate == 0 then
				ent:Fire( "close" )
			elseif currentstate == 1 then
				ent:Fire( "open" )
			else -- NO TOGGLE DOOR
				ent:Fire( "open" )
			end

			if locked then
				YRPFireLock( ent )
			end
		end
	else
		local filename = "doors/default_locked.wav"
		util.PrecacheSound(filename)
		ent:EmitSound(filename, 75, 100, 1, CHAN_AUTO )
	end
end

function YRPBuildingRemoveOwner( SteamID )
	YRP.msg( "db", "YRPBuildingRemoveOwner( " .. tostring(SteamID) .. " )" )
	local chars = YRP_SQL_SELECT( "yrp_characters", "*", "SteamID = '" .. SteamID .. "'" )

	if IsNotNilAndNotFalse( chars ) then
		for i, c in pairs( chars ) do
			local charid = c.uniqueID
			for k, v in pairs( GetAllDoors() ) do
				if v:GetYRPInt( "ownerCharID" ) == tonumber( charid) then
					v:SetYRPString( "ownerRPName", "" )
					v:SetYRPInt( "ownerGroupUID", -99)
					v:SetYRPString( "ownerGroup", "" )
					v:SetYRPInt( "ownerCharID", 0)
					v:SetYRPBool( "bool_hasowner", false)
					YRPFireUnlock( v )
					YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["ownerCharID"] = ""}, "uniqueID = '" .. v:GetYRPString( "uniqueID" ) .. "'" )
				end
			end
		end
	end
end

net.Receive( "nws_yrp_removeOwner", function( len, ply )
	if !ply:HasAccess( "nws_yrp_removeOwner" ) then
		YRP.msg( "note", ply:Nick() .. " has no rights to change Building." )
		return 
	end

	local _tmpBuildingID = net.ReadString()
	local _tmpTable = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "*", "uniqueID = '" .. _tmpBuildingID .. "'" )

	YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {
		["ownerCharID"] = "",
		["groupID"] = 0
	}, "uniqueID = '" .. _tmpBuildingID .. "'" )

	for k, v in pairs(GetAllDoors() ) do
		if tonumber( v:GetYRPString( "buildingID" ) ) == tonumber(_tmpBuildingID) then
			v:SetYRPString( "ownerRPName", "" )
			v:SetYRPInt( "ownerGroupUID", -99)
			v:SetYRPString( "ownerGroup", "" )
			v:SetYRPInt( "ownerCharID", 0)
			v:SetYRPBool( "bool_hasowner", false)
			YRPFireUnlock( v )
		end
	end
end)

net.Receive( "nws_yrp_sellBuilding", function( len, ply )
	local _tmpBuildingID = net.ReadString()
	local _tmpTable = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "*", "uniqueID = '" .. _tmpBuildingID .. "'" )

	YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {
		["ownerCharID"] = "",
		["groupID"] = 0
	}, "uniqueID = '" .. _tmpBuildingID .. "'" )

	for k, v in pairs(GetAllDoors() ) do
		if tonumber( v:GetYRPString( "buildingID" ) ) == tonumber(_tmpBuildingID) then
			v:SetYRPString( "ownerRPName", "" )
			v:SetYRPInt( "ownerGroupUID", -99)
			v:SetYRPString( "ownerGroup", "" )
			v:SetYRPInt( "ownerCharID", 0)
			v:SetYRPBool( "bool_hasowner", false)
			YRPFireUnlock( v )
			YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_doors", {["keynr"] = -1}, "buildingID = " .. tonumber( v:GetYRPString( "buildingID" ) ))
		end
	end

	if _tmpTable and _tmpTable[1] then
		ply:addMoney(_tmpTable[1].buildingprice / 2)
	end
end)

net.Receive( "nws_yrp_buyBuilding", function( len, ply )
	if GetGlobalYRPBool( "bool_building_system", false) then
		local _tmpBuildingID = net.ReadString()
		local _tmpTable = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "*", "uniqueID = '" .. _tmpBuildingID .. "'" )

		if ply:canAfford(_tmpTable[1].buildingprice) then
			if (_tmpTable[1].ownerCharID == "" or _tmpTable[1].ownerCharID == " " ) and tonumber(_tmpTable[1].groupID) <= 0 then
				ply:addMoney(- _tmpTable[1].buildingprice)
				YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["ownerCharID"] = ply:CharID()}, "uniqueID = '" .. _tmpBuildingID .. "'" )
				local tabChar = YRP_SQL_SELECT( "yrp_characters", "rpname", "uniqueID = " .. ply:CharID() )
				if IsNotNilAndNotFalse(tabChar) then
					tabChar = tabChar[1]
				end
				for k, v in pairs(GetAllDoors() ) do
					if tonumber( v:GetYRPString( "buildingID" ) ) == tonumber(_tmpBuildingID) then
						v:SetYRPString( "ownerRPName", tabChar.rpname)
						v:SetYRPInt( "ownerCharID", tonumber(ply:CharID() ))
						v:SetYRPBool( "bool_hasowner", true)
					end
				end
				YRP.msg( "gm", ply:RPName() .. " has buyed a door" )
			else
				YRP.msg( "gm", ply:RPName() .. " has already an owner!" )
			end
		else
			YRP.msg( "gm", ply:RPName() .. " has not enough money to buy door" )
		end
	else
		YRP.msg( "note", "buildings disabled" )
	end
end)

net.Receive( "nws_yrp_setBuildingOwnerGroup", function( len, ply )
	local _tmpBuildingID = net.ReadString()
	local _tmpGroupID = net.ReadInt(32)

	YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["groupID"] = _tmpGroupID}, "uniqueID = " .. _tmpBuildingID)

	local _tmpGroupName = YRP_SQL_SELECT( "yrp_ply_groups", "uniqueID, string_name", "uniqueID = " .. _tmpGroupID)
	if IsNotNilAndNotFalse(_tmpGroupName) then
		for k, v in pairs(GetAllDoors() ) do
			if tonumber( v:GetYRPString( "buildingID" ) ) == tonumber(_tmpBuildingID) then
				v:SetYRPInt( "ownerGroupUID", _tmpGroupName[1].uniqueID)
				v:SetYRPString( "ownerGroup", _tmpGroupName[1].string_name)
				v:SetYRPBool( "bool_hasowner", true)
			end
		end
	end
end)

net.Receive( "nws_yrp_getBuildingGroups", function( len, ply )
	local _tmpTable = YRP_SQL_SELECT( "yrp_ply_groups", "*", nil)

	net.Start( "nws_yrp_getBuildingGroups" )
		net.WriteTable(_tmpTable)
	net.Send(ply)
end)

net.Receive( "nws_yrp_changeBuildingPrice", function( len, ply )
	local _tmpBuildingID = net.ReadString()
	local _tmpNewPrice = net.ReadString()
	_tmpNewPrice = tonumber(_tmpNewPrice) or 99

	local _result = YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["buildingprice"] = _tmpNewPrice}, "uniqueID = " .. _tmpBuildingID)
end)

function YRPSetSecurityLevel(id, sl)
	if GetGlobalYRPBool( "bool_building_system", false) then
		for i, door in pairs(GetAllDoors() ) do
			if door:GetYRPString( "buildingID", -1) == id then
				door:SetYRPInt( "int_securitylevel", sl)
				if door:SecurityLevel() > 0 then
					YRPFireLock( door )
				else
					YRPFireUnlock( door )
				end
			end
		end
	end
end

net.Receive( "nws_yrp_changeBuildingSL", function( len, ply )
	local _tmpBuildingID = net.ReadString()
	local _tmpNewSL = net.ReadString()
	_tmpNewSL = tonumber(_tmpNewSL) or 0
	if _tmpNewSL > 1000 then
		_tmpNewSL = 1000
	end
	local _result = YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["int_securitylevel"] = _tmpNewSL}, "uniqueID = " .. _tmpBuildingID)
	YRPSetSecurityLevel(_tmpBuildingID, _tmpNewSL)
end)

util.AddNetworkString( "nws_yrp_canBuildingBeOwned" )
net.Receive( "nws_yrp_canBuildingBeOwned", function( len, ply )
	local _tmpBuildingID = net.ReadString()
	local _canbeowned = tonum(net.ReadBool() )

	YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["bool_canbeowned"] = _canbeowned}, "uniqueID = " .. _tmpBuildingID)

	YRPChangeBuildingBool(tonumber(_tmpBuildingID), "bool_canbeowned", _canbeowned)
end)


function YRPHasDoors(id)
	local _allDoors = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_doors", "*", nil)
	for k, v in pairs(_allDoors) do
		if tonumber( v.buildingID) == tonumber(id) then
			return true
		end
	end
	return false
end

function YRPLookForEmptyBuildings()
	local _allBuildings = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "*", nil)
	if IsNotNilAndNotFalse(_allBuildings) then
		for k, v in pairs(_allBuildings) do
			if !YRPHasDoors( v.uniqueID) then
				YRP_SQL_DELETE_FROM( "yrp_" .. GetMapNameDB() .. "_buildings", "uniqueID = " .. tonumber( v.uniqueID) )
			end
		end
	end
end
YRPLookForEmptyBuildings()

net.Receive( "nws_yrp_changeBuildingID", function( len, ply )
	local _tmpDoor = net.ReadEntity()
	local _tmpBuildingID = net.ReadString()

	_tmpDoor:SetYRPString( "buildingID", _tmpBuildingID)
	YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_doors", {["buildingID"] = tonumber(_tmpBuildingID)}, "uniqueID = " .. _tmpDoor:GetYRPString( "uniqueID" ) )

	YRPLookForEmptyBuildings()
end)

net.Receive( "nws_yrp_changeBuildingName", function( len, ply )
	local _tmpBuildingID = net.ReadString()
	local _tmpNewName = net.ReadString()
	if IsNotNilAndNotFalse(_tmpBuildingID) then
		YRP.msg( "note", "renamed Building: " .. _tmpNewName)
		YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["name"] = _tmpNewName}, "uniqueID = " .. _tmpBuildingID)
	else
		YRP.msg( "note", "changeBuildingName failed" )
	end
end)

function YRPChangeBuildingString(uid, net_str, new_str)
	for i, v in pairs(GetAllDoors() ) do
		if uid == tonumber( v:GetYRPString( "buildingID" ) ) then
			v:SetYRPString( net_str, new_str ) -- only building stuff
		end
	end
end

function YRPChangeBuildingBool(uid, net_str, new_boo)
	local tabBuilding = YRP_SQL_SELECT(DATABASE_NAME_BUILDINGS, "*", "uniqueID = '" .. uid .. "'" )
	if IsNotNilAndNotFalse(tabBuilding) then
		tabBuilding = tabBuilding[1]
	else
		tabBuilding = {}
	end
	for i, v in pairs(GetAllDoors() ) do
		if uid == tonumber( v:GetYRPString( "buildingID" ) ) then
			v:SetYRPBool(net_str, new_boo)
		end
	end
end

net.Receive( "nws_yrp_changeBuildingHeader", function( len, ply )
	if !ply:HasAccess( "nws_yrp_changeBuildingHeader", true ) then
		YRP.msg( "note", ply:Nick() .. " has no rights to change Building." )
		return 
	end

	local _tmpBuildingID = net.ReadString()
	local _tmpNewName = net.ReadString()
	if IsNotNilAndNotFalse(_tmpBuildingID) then
		YRP.msg( "note", "header Building: " .. _tmpNewName)
		YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["text_header"] = _tmpNewName}, "uniqueID = " .. _tmpBuildingID)
		YRPChangeBuildingString(tonumber(_tmpBuildingID), "text_header", _tmpNewName)
	else
		YRP.msg( "note", "changeBuildingName failed" )
	end
end)

net.Receive( "nws_yrp_changeBuildingDescription", function( len, ply )
	if !ply:HasAccess( "nws_yrp_changeBuildingDescription", true ) then
		YRP.msg( "note", ply:Nick() .. " has no rights to change Building." )
		return 
	end

	local _tmpBuildingID = net.ReadString()
	local _tmpNewName = net.ReadString()
	if IsNotNilAndNotFalse(_tmpBuildingID) then
		YRP.msg( "note", "description Building: " .. _tmpNewName)
		YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["text_description"] = _tmpNewName}, "uniqueID = " .. _tmpBuildingID)
		YRPChangeBuildingString(tonumber(_tmpBuildingID), "text_description", _tmpNewName)
	else
		YRP.msg( "note", "changeBuildingName failed" )
	end
end)

function YRPGetDoors()
	local _tmpTable = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "name, uniqueID", "name != 'Building'" )

	if IsNotNilAndNotFalse(_tmpTable) then
		for k, building in pairs(_tmpTable) do
			local _doors = 0
			_tmpDoors = ents.FindByClass( "prop_door_rotating" )
			for j, d in pairs(_tmpDoors) do
				if tonumber( d:GetYRPString( "buildingID", "-1" ) ) == tonumber( building.uniqueID) then
					_doors = _doors + 1
				end
			end
			_tmpFDoors = ents.FindByClass( "func_door" )
			for j, d in pairs(_tmpFDoors) do
				if tonumber( d:GetYRPString( "buildingID", "-1" ) ) == tonumber( building.uniqueID) then
					_doors = _doors + 1
				end
			end
			_tmpFRDoors = ents.FindByClass( "func_door_rotating" )
			for j, d in pairs(_tmpFRDoors) do
				if tonumber( d:GetYRPString( "buildingID", "-1" ) ) == tonumber( building.uniqueID) then
					_doors = _doors + 1
				end
			end

			building.name = building.name
			building.doors = _doors
		end
	end
	if !IsNotNilAndNotFalse(_tmpTable) then
		_tmpTable = {}
	end

	return _tmpTable
end

net.Receive( "nws_yrp_getBuildings", function( len, ply )
	local doors = YRPGetDoors()

	net.Start( "nws_yrp_getBuildings" )
		net.WriteTable( doors)
	net.Send(ply)
end)

function YRPSendBuildingInfo(ply, ent, tab)
	local t = tab or {}
	if net.BytesLeft() == nil and net.BytesWritten() == nil then
		net.Start( "nws_yrp_sendBuildingInfo" )
			net.WriteEntity(ent)
			net.WriteTable(t)
		net.Send(ply)
	else
		timer.Simple(0.1, function()
			YRPSendBuildingInfo(ply, ent, t)
		end)
	end
end

net.Receive( "nws_yrp_getBuildingInfo", function( len, ply )
	local door = net.ReadEntity()
	local buid = door:GetYRPString( "buildingID", "" )

	if IsNilOrFalse( buid ) and buid == "" then
		YRP.msg( "note", "[getBuildingInfo] -> BuildingID (" .. tostring( buid ) .. ") is not valid [Map: " .. GetMapNameDB() .. "]" )
		return
	end

	if ply:GetYRPBool( "bool_" .. "ishobo", false) then
		YRP.msg( "note", "[getBuildingInfo] Is Hobo, not possible to buy as hobo" )
		return
	end

	local tabOwner = {}
	local tabGroup = {}
	local tabBuilding = YRP_SQL_SELECT( "yrp_" .. GetMapNameDB() .. "_buildings", "*", "uniqueID = '" .. buid .. "'" )
	--local owner = ""
	if IsNotNilAndNotFalse(tabBuilding) then
		tabBuilding = tabBuilding[1]
		tabBuilding.name = tabBuilding.name
		tabBuilding.groupID = tonumber(tabBuilding.groupID)
		if !strEmpty(tabBuilding.ownerCharID) then
			tabOwner = YRP_SQL_SELECT( "yrp_characters", "*", "uniqueID = '" .. tabBuilding.ownerCharID .. "'" )
			if IsNotNilAndNotFalse(tabOwner) then
				tabOwner = tabOwner[1]
				--owner = tabOwner.rpname
			else
				YRP.msg( "note", "[getBuildingInfo] owner dont exists." )
				tabOwner = {}
			end
		elseif tabBuilding.groupID != 0 then
			tabGroup = YRP_SQL_SELECT( "yrp_ply_groups", "*", "uniqueID = '" .. tabBuilding.groupID .. "'" )
			if IsNotNilAndNotFalse(tabGroup) then
				tabGroup = tabGroup[1]
				--owner = _tmpGroTab.string_name
			else
				local test = YRP_SQL_UPDATE( "yrp_" .. GetMapNameDB() .. "_buildings", {["groupID"] = 0}, "uniqueID = '" .. buid .. "'" )

				YRP.msg( "note", "[getBuildingInfo] group dont exists." )
				tabGroup = {}
			end
		end
		
		local tab = {}
		tab["B"] = tabBuilding
		tab["O"] = tabOwner
		tab["G"] = tabGroup

		YRPSendBuildingInfo(ply, door, tab)
	else
		YRP.msg( "note", "getBuildingInfo -> Building not found in Database. [Map: " .. GetMapNameDB() .. "]" )
	end
end)

util.AddNetworkString( "nws_yrp_update_lockdown_buildings" )
net.Receive( "nws_yrp_update_lockdown_buildings", function( len, ply )
	local buid = net.ReadString()
	local checked = net.ReadBool()

	YRP_SQL_UPDATE(DATABASE_NAME_BUILDINGS, {["bool_lockdown"] = tonum( checked)}, "uniqueID = '" .. buid .. "'" )
end)
