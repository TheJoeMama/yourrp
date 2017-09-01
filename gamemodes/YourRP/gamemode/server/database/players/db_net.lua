--Copyright (C) 2017 Arno Zura ( https://www.gnu.org/licenses/gpl.txt )

util.AddNetworkString( "openCharakterMenu" )
util.AddNetworkString( "setPlayerValues" )
util.AddNetworkString( "setRoleValues" )

util.AddNetworkString( "getPlyList" )
util.AddNetworkString( "giveRole" )

util.AddNetworkString( "getCharakterList" )
util.AddNetworkString( "updateFirstName" )
util.AddNetworkString( "updateSurName" )

net.Receive( "updateSurName", function( len, ply )
  local _surName = string.Replace( net.ReadString(), " ", "" )
  local _result = dbUpdate( "yrp_players", "nameSur = '" .. _surName .. "'", "steamID = '" .. ply:SteamID() .. "'" )
  ply:SetNWString( "SurName", _surName )
end)

net.Receive( "updateFirstName", function( len, ply )
  local _firstName = string.Replace( net.ReadString(), " ", "" )
  local _result = dbUpdate( "yrp_players", "nameFirst = '" .. _firstName .. "'", "steamID = '" .. ply:SteamID() .. "'" )
  ply:SetNWString( "FirstName", _firstName )
end)

net.Receive( "getCharakterList", function( len, ply )
  local _tmpPlyList = dbSelect( "yrp_players", "*", "steamID = '" .. ply:SteamID() .. "'" )
  if _tmpPlyList != nil then
    net.Start( "getCharakterList" )
      net.WriteTable( _tmpPlyList )
    net.Send( ply )
  end
end)

net.Receive( "getPlyList", function( len, ply )
  local _tmpPlyList = dbSelect( "yrp_players", "*", nil )
  local _tmpRoleList = dbSelect( "yrp_roles", "*", nil )
  local _tmpGroupList = dbSelect( "yrp_groups", "*", nil )
  if _tmpPlyList != nil and _tmpRoleList != nil and _tmpGroupList != nil then
    net.Start( "getPlyList" )
      net.WriteTable( _tmpPlyList )
      net.WriteTable( _tmpRoleList )
      net.WriteTable( _tmpGroupList )
    net.Send( ply )
  end
end)

function giveRole( ply, steamID, uniqueID )
  local tmpTable = sql.Query( "SELECT * FROM yrp_roles WHERE uniqueID = " .. uniqueID )
  local _steamNick = steamID

  for k, v in pairs( player.GetAll() ) do
    if steamID == v:SteamID() then
      v:KillSilent()
      break
    end
  end

  if tmpTable != nil then
    if tmpTable[1].uses < tmpTable[1].maxamount or tonumber( tmpTable[1].maxamount ) == -1 then
      local query = ""
      query = query .. "UPDATE yrp_players "
      query = query .. "SET roleID = " .. tonumber( tmpTable[1].uniqueID ) .. ", "
      query = query .. "capital = " .. tonumber( tmpTable[1].capital ) .. " "
      query = query .. "WHERE steamID = '" .. steamID .. "'"
      local result = sql.Query( query )
      setRole( steamID, uniqueID )

      updateUses()
      for k, v in pairs( player.GetAll() ) do
        if steamID == v:SteamID() then
          _steamNick = v:Nick()
          updateHud( v )
          break
        end
      end
      printGM( "admin", ply:Nick() .. " gives " .. _steamNick .. " the Role: " .. tmpTable[1].roleID )
    else
      for k, v in pairs( player.GetAll() ) do
        if steamID == v:SteamID() then
          _steamNick = v:Nick()
          break
        end
      end
      printGM( "admin", ply:Nick() .. " can't give " .. _steamNick .. " the Role: " .. tmpTable[1].roleID .. ", because max amount reached")
    end
  else
    printERROR( "Role " .. uniqueID .. " is not available" )
  end
end

net.Receive( "giveRole", function( len, ply )
  local _tmpSteamID = net.ReadString()
  local uniqueIDRole = net.ReadInt( 16 )
  giveRole( ply, _tmpSteamID, uniqueIDRole )
end)

function isWhitelisted( ply, id )
  local _plyAllowed = dbSelect( "yrp_role_whitelist", "*", "steamID = '" .. ply:SteamID() .. "' AND roleID = " .. id )
  if _plyAllowed != nil and _plyAllowed != false then
    return true
  else
    return false
  end
end

util.AddNetworkString( "voteNo" )
net.Receive( "voteNo", function( len, ply )
  ply:SetNWString( "voteStatus", "no" )
end)

util.AddNetworkString( "voteYes" )
net.Receive( "voteYes", function( len, ply )
  ply:SetNWString( "voteStatus", "yes" )
end)

local voting = false
local votePly = nil
local voteCount = 30
function startVote( ply, table )
  if !voting then
    voting = true
    for k, v in pairs( player.GetAll() ) do
      v:SetNWString( "voteStatus", "not voted" )
      v:SetNWBool( "voting", true )
      v:SetNWString( "voteQuestion", ply:RPName() .. " want the role: " .. table[1].roleID )
    end
    votePly = ply
    voteCount = 30
    timer.Create( "voteRunning", 1, 0, function()
      for k, v in pairs( player.GetAll() ) do
        v:SetNWInt( "voteCD", voteCount )
      end
      if voteCount <= 0 then
        voting = false
        local _yes = 0
        local _no = 0
        for k, v in pairs( player.GetAll() ) do
          v:SetNWBool( "voting", false )
          if v:GetNWString( "voteStatus", "not voted" ) == "yes" then
            _yes = _yes + 1
          elseif v:GetNWString( "voteStatus", "not voted" ) == "no" then
            _no = _no + 1
          end
        end
        if _yes > _no and ( _yes + _no ) > 1 then
          setRole( votePly:SteamID(), table[1].uniqueID )
        else
          printGM( "note", "VOTE: not enough yes" )
        end
        timer.Remove( "voteRunning" )
      end
      voteCount = voteCount - 1
    end)
  else
    printGM( "note", "a vote is currently running" )
  end
end

net.Receive( "wantRole", function( len, ply )
  local uniqueIDRole = net.ReadInt( 16 )
  local tmpTableRole = sql.Query( "SELECT * FROM yrp_roles WHERE uniqueID = " .. uniqueIDRole )

  if tmpTableRole != nil then
    local tmpTableGroup = sql.Query( "SELECT * FROM yrp_groups WHERE uniqueID = " .. tmpTableRole[1].groupID )
    if tmpTableRole[1].uses < tmpTableRole[1].maxamount or tonumber( tmpTableRole[1].maxamount ) == -1 then
      if tmpTableRole[1].adminonly == 1 then
        if ply:IsAdmin() or ply:IsSuperAdmin() then
        else
          return
        end
      elseif tonumber( tmpTableRole[1].whitelist ) == 1 then
        if !isWhitelisted( ply, uniqueIDRole ) then
          //printGM( "user", ply:Nick() .. " is not in the whitelist for this role")
          startVote( ply, tmpTableRole )
          return
        end
      end
      local query = ""
      query = query .. "UPDATE yrp_players "
      query = query .. "SET roleID = " .. tonumber( tmpTableRole[1].uniqueID ) .. ", "
      query = query .. "capital = " .. tonumber( tmpTableRole[1].capital ) .. " "
      query = query .. "WHERE steamID = '" .. ply:SteamID() .. "'"
      local result = sql.Query( query )
      setRole( ply:SteamID(), uniqueIDRole )

      ply:KillSilent()

      updateHud( ply )

      printGM( "user", ply:Nick() .. " is now the Role: " .. tmpTableGroup[1].groupID .. " " .. tmpTableRole[1].roleID )

      updateUses()

    else
      printGM( "user", ply:Nick() .. " want the role: " .. tmpTableRole[1].roleID .. ", FAILED: Max amount reached" )
    end
  else
    printERROR( "Role " .. uniqueIDRole .. " is not available" )
  end
end)

net.Receive( "setPlayerValues", function( len, ply )
  local tmpSurname = string.Replace( net.ReadString(), " ", "" )
  local tmpFirstname = string.Replace( net.ReadString(), " ", "" )
  local tmpGender = string.Replace( net.ReadString(), " ", "" )

  local _result = sql.Query( "SELECT * FROM yrp_players WHERE steamID = '" .. ply:SteamID() .. "'" )
  if _result != nil then
    if tmpSurname != "" and tmpFirstname != "" and tmpGender != "" then
      local query = ""
      query = query .. "UPDATE yrp_players "
      query = query .. "SET nameFirst = '" .. tmpFirstname .. "', "
      query = query .. "nameSur = '" .. tmpSurname .. "', "
      query = query .. "gender = '" .. tmpGender .. "' "
      query = query .. "WHERE steamID = '" .. ply:SteamID() .. "'"
      sql.Query( query )
      ply:Spawn()
    else
      net.Start( "openCharakterMenu" )
      net.Send( ply )
    end
  end
end)
