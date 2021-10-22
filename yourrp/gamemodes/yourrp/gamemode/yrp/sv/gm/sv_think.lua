--Copyright (C) 2017-2021 D4KiR (https://www.gnu.org/licenses/gpl.txt)

hook.Add("PlayerStartTaunt", "yrp_taunt_start", function(ply, act, length)
	ply:SetNW2Bool("taunting", true)
	timer.Simple(length, function()
		if IsValid(ply) then
			ply:SetNW2Bool("taunting", false)
		end
	end)
end)

util.AddNetworkString("client_lang")
net.Receive("client_lang", function(len, ply)
	local _lang = net.ReadString()
	--YRP.msg("db", ply:YRPName() .. " using language: " .. string.upper(_lang))
	ply:SetNW2String("client_lang", _lang or "NONE")
end)

function YDeath(ply)
	ply:Kill()
end

function YRPConHP(ply)
	local hpreg = ply:GetNW2Int("HealthReg", nil)
	if wk(hpreg) and ply:Alive() then
		if ply:Health() <= 0 then
			YDeath(ply)
		end
		ply:Heal(hpreg)
		if ply:Health() <= 0 then
			YDeath(ply)
		end
	end
end

function YRPConAR(ply)
	local arreg = ply:GetNW2Int("ArmorReg")
	if arreg != nil then
		ply:SetArmor(ply:Armor() + arreg)
		if ply:Armor() > ply:GetNW2Int("MaxArmor") then
			ply:SetArmor(ply:GetNW2Int("MaxArmor"))
		elseif ply:Armor() < 0 then
			ply:SetArmor(0)
		end
	end
end

function IsCookPlaying()
	for i, v in pairs(player.GetAll()) do
		if v:isCook() then
			return true
		end
	end
	return false
end

function YRPConHG(ply, time)
	if GetGlobalBool("bool_onlywhencook", false) and !IsCookPlaying() then return false end
	local newval = tonumber(ply:GetNW2Float("hunger", 0.0)) - 0.01 * GetGlobalFloat("float_scale_hunger", 1.0)
	newval = math.Clamp(newval, 0.0, 100.0)
	ply:SetNW2Float("hunger", newval, 500)

	if tonumber(ply:GetNW2Float("hunger", 0.0)) < 20.0 then
		ply:TakeDamage(ply:GetMaxHealth() / 50)
	elseif GetGlobalBool("bool_hunger_health_regeneration", false) then
		local tickrate = tonumber(GetGlobalString("text_hunger_health_regeneration_tickrate", 1))
		if tickrate >= 1 and time % tickrate == 0 then
			ply:SetHealth(ply:Health() + 1)
			if ply:Health() > ply:GetMaxHealth() then
				ply:SetHealth(ply:GetMaxHealth())
			end
		end
	end
end

function YRPConTH(ply)
	local newval2 = tonumber(ply:GetNW2Float("permille", 0.0)) - 0.01 * GetGlobalFloat("float_scale_permille", 1.0)
	newval2 = math.Clamp(newval2, 0.0, ply:GetMaxPermille())
	ply:SetNW2Float("permille", newval2)

	if GetGlobalBool("bool_onlywhencook", false) and !IsCookPlaying() then return false end
	local newval = tonumber(ply:GetNW2Float("thirst", 0.0)) - 0.01 * GetGlobalFloat("float_scale_thirst", 1.0)
	newval = math.Clamp(newval, 0.0, 100.0)
	ply:SetNW2Float("thirst", newval)
	if tonumber(ply:GetNW2Float("thirst", 0.0)) < 20.0 then
		ply:TakeDamage(ply:GetMaxHealth() / 50)
	end
end

function YRPConRA(ply)
	if IsInsideRadiation(ply) then
		ply:SetNW2Float("GetCurRadiation", math.Clamp(tonumber(ply:GetNW2Float("GetCurRadiation", 0.0)) + 0.01 * GetGlobalFloat("float_scale_radiation_in", 50.0), 0, 100))
	else
		ply:SetNW2Float("GetCurRadiation", math.Clamp(tonumber(ply:GetNW2Float("GetCurRadiation", 0.0)) - 0.01 * GetGlobalFloat("float_scale_radiation_out", 8.0), 0, 100))
	end
	if tonumber(ply:GetNW2Float("GetCurRadiation", 0.0)) > 80.0 then
		ply:TakeDamage(ply:GetMaxHealth() / 50)
	end
end

function YRPConST(ply, _time)
	if GetGlobalBool("bool_onlywhencook", false) and !IsCookPlaying() then
		ply:SetNW2Float("GetCurStamina", 100)
		return false
	end
	ply.jumping = ply.jumping or false

	if ply:GetMoveType() != MOVETYPE_NOCLIP then
		if ply:IsOnGround() and ply.jumping then
			ply.jumping = false
		end

		if !ply:InVehicle() and !ply:IsOnGround() and !ply.jumping then
			ply.jumping = true

			local newval = ply:GetNW2Float("GetCurStamina", 0) - GetGlobalFloat("float_scale_stamina_jump", 30)
			newval = math.Round(math.Clamp(newval, 0, ply:GetNW2Float("GetMaxStamina", 100)), 1)
			ply:SetNW2Float("GetCurStamina", newval)
		end
	end

	if _time % 1.0 == 0 then
		if !ply:InVehicle() then
			if ply:GetMoveType() != MOVETYPE_NOCLIP and (ply:KeyDown(IN_SPEED) and (ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVERIGHT) or ply:KeyDown(IN_MOVELEFT))) then
				local newval = ply:GetNW2Float("GetCurStamina", 0) - (ply:GetNW2Float("stamindown", 1)) * GetGlobalFloat("float_scale_stamina_down", 1.0)
				newval = math.Round(math.Clamp(newval, 0, ply:GetNW2Float("GetMaxStamina", 100)), 1)
				ply:SetNW2Float("GetCurStamina", newval)
			elseif ply:GetNW2Float("thirst", 0) > 20 then
				local factor = 1
				if ply:GetMoveType() == MOVETYPE_NOCLIP then
					factor = 10
				end
				local newval = ply:GetNW2Float("GetCurStamina", 0) + ply:GetNW2Float("staminup", 1) * GetGlobalFloat("float_scale_stamina_up", 1.0) * factor
				newval = math.Round(math.Clamp(newval, 0, ply:GetNW2Float("GetMaxStamina", 100)), 1)
				ply:SetNW2Float("GetCurStamina", newval)
			end
		end

		if !ply:Slowed() then
			local rs = ply:GetNW2Int("speedrun", 0)
			local ws = ply:GetNW2Int("speedwalk", 0)
			local factor = 1
			if ply:GetNW2Float("GetCurStamina", 0) <= 20 or ply:GetNW2Float("thirst", 0) < 20 then
				factor = 0.6
			end

			if IsBonefracturingEnabled() and !ply:Slowed() then
				if ply:GetNW2Bool("broken_leg_left") and ply:GetNW2Bool("broken_leg_right") then
					factor = 0.5
				elseif ply:GetNW2Bool("broken_leg_left") or ply:GetNW2Bool("broken_leg_right") then
					factor = 0.25
				end
			end

			if factor == 1 then
				ply:SetCanWalk(true)
			else
				ply:SetCanWalk(false)
			end
			ply:SetRunSpeed(rs * factor)
			ply:SetWalkSpeed(ws * factor)
		end
	end
end

function YRPRegAB(ply)
	local reg = ply:GetNW2Float("GetRegAbility", 0.0)
	local tick = ply:GetNW2Float("GetRegTick", 1.0)

	ply.abdelay = ply.abdelay or 0
	ply.abdelay = math.Round(ply.abdelay, 1)

	if reg != 0.0 and ply.abdelay < CurTime() then
		ply.abdelay = CurTime() + tick
		ply:SetNW2Int("GetCurAbility", math.Clamp(ply:GetNW2Int("GetCurAbility", 0) + reg, 0, ply:GetNW2Int("GetMaxAbility")))
	end
end

function YRPTimeJail(ply)
	if ply:GetNW2Bool("injail", false) then
		ply:SetNW2Int("jailtime", ply:GetNW2Int("jailtime", 0) - 1)
		if tonumber(ply:GetNW2Int("jailtime", 0)) <= 0 then
			clean_up_jail(ply)
		end
	end
end

function YRPCheckSalary(ply)
	local _m = ply:GetNW2String("money")
	local _ms = ply:GetNW2String("salary")
	if ply:Alive() and ply:HasCharacterSelected() and _m and _ms then
		local _money = tonumber(_m)
		local _salary = tonumber(_ms)

		if _money != nil and _salary != nil then
			if CurTime() >= ply:GetNW2Int("nextsalarytime", 0) and ply:HasCharacterSelected() and ply:Alive() then
				ply:SetNW2Int("nextsalarytime", CurTime() + ply:GetNW2Int("salarytime"))

				ply:SetNW2String("money", _money + _salary)
				ply:UpdateMoney()
			end
		end
	end
end

function YRPIsDealerAlive(uid)
	for j, npc in pairs(ents.GetAll()) do
		if npc:IsNPC() and tonumber(npc:GetNW2String("dealerID", "0")) == tonumber(uid) then
			return true
		end
	end
	return false
end

function YRPIsTeleporterAlive(uid)
	for j, tel in pairs(ents.GetAll()) do
		if tel:GetClass() == "yrp_teleporter" then
			if tonumber(tel:GetNW2Int("yrp_teleporter_uid", -1)) != -1 and tonumber(tel:GetNW2Int("yrp_teleporter_uid", -1)) == tonumber(uid) then
				return true
			end
			tel.PermaProps = true
		end
	end
	return false
end

util.AddNetworkString("yrp_autoreload")

local _time = 0
local TICK = 0.1
local DEC = 1
timer.Remove("ServerThink")
timer.Create("ServerThink", TICK, 0, function()
	if _time % 1.0 == 0 then	-- Every second
		for k, ply in pairs(player.GetAll()) do

			ply:AddPlayTime()

			if ply:AFK() and !ply:HasAccess() then
				if CurTime() - tonumber(ply:GetNW2Float("afkts", 0)) >= tonumber(GetGlobalInt("int_afkkicktime", 0)) then
					ply:SetNW2Bool("isafk", false)
					ply:Kick("AFK")
				end
			end

			if ply:GetNW2Bool("loaded", false) then
				if !ply:GetNW2Bool("inCombat") then
					YRPConHP(ply)	 --HealthReg
					YRPConAR(ply)	 --ArmorReg
					if ply:GetNW2Int("yrp_stars", 0) != 0 then
						ply:SetNW2Int("yrp_stars", 0)
					end
				end

				if ply:IsBleeding() then
					local effect = EffectData()
					effect:SetOrigin(ply:GetPos() - ply:GetBleedingPosition())
					effect:SetScale(1)
					util.Effect("bloodimpact", effect)
					ply:TakeDamage(0.5, ply, ply)
				end

				if GetGlobalBool("bool_hunger", false) and ply:GetNW2Bool("bool_hunger", false) then
					YRPConHG(ply, _time)
				end
				if GetGlobalBool("bool_thirst", false) and ply:GetNW2Bool("bool_thirst", false) then
					YRPConTH(ply)
				end
				if GetGlobalBool("bool_radiation", false) then
					YRPConRA(ply)
				end

				YRPTimeJail(ply)
				YRPCheckSalary(ply)
			end
		end

		if GetGlobalBool("bool_radiation", false) then
			for k, ent in pairs(ents.GetAll()) do
				if ent:IsNPC() then
					YRPConRA(ent)
				end
			end
		end
	end

	for k, ply in pairs(player.GetAll()) do -- Every 0.1 seconds
		if ply:GetNW2Bool("loaded", false) then
			-- Every 0.1
			YRPRegAB(ply)

			if GetGlobalBool("bool_stamina", false) and ply:GetNW2Bool("bool_stamina", false) then
				YRPConST(ply, _time)
			end
		end
	end

	if _time % 60.0 == 1 then
		if YRP.XPPerMinute != nil then
			local xp_per_minute = YRP.XPPerMinute()
			for i, p in pairs(player.GetAll()) do
				p:AddXP(xp_per_minute)
			end
		end
	end

	if _time % 30.0 == 1 or GetGlobalBool("yrp_update_teleporters", false) then
		if GetGlobalBool("yrp_update_teleporters", true) != false then
			SetGlobalBool("yrp_update_teleporters", false)
		end

		local _dealers = YRP_SQL_SELECT("yrp_dealers", "*", "map = '" .. GetMapNameDB() .. "'")
		if wk(_dealers) then
			for i, dealer in pairs(_dealers) do
				if tonumber(dealer.uniqueID) != 1 and !YRPIsDealerAlive(dealer.uniqueID) then
					local _del = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'dealer' AND linkID = '" .. dealer.uniqueID .. "'")
					if _del != nil then
						YRP.msg("gm", "DEALER [" .. dealer.name .. "] NOT ALIVE, reviving!")
						_del = _del[1]
						local _dealer = ents.Create("yrp_dealer")
						_dealer:SetNW2String("dealerID", dealer.uniqueID)
						_dealer:SetNW2String("name", dealer.name)
						local _pos = string.Explode(",", _del.position)
						_pos = Vector(_pos[1], _pos[2], _pos[3])
						_dealer:SetPos(_pos)
						local _ang = string.Explode(",", _del.angle)
						_ang = Angle(0, _ang[2], 0)
						_dealer:SetAngles(_ang)
						_dealer:SetModel(dealer.WorldModel)
						_dealer:Spawn()

						timer.Simple(1, function()
							if ea(_dealer.Entity) then
								_dealer.Entity:LookupSequence("idle_all_01")
								_dealer.Entity:ResetSequence("idle_all_01")
							end
						end)
					end
				end
			end
		end

		if YRP_SQL_TABLE_EXISTS("yrp_teleporters") then
			local teleporters = YRP_SQL_SELECT("yrp_teleporters", "*", "string_map = '" .. game.GetMap() .. "'")
			if wk(teleporters) then
				if table.Count(teleporters) < 100 then
					for i, teleporter in pairs(teleporters) do
						if !YRPIsTeleporterAlive(teleporter.uniqueID) then
							local tp = ents.Create("yrp_teleporter")
							if ( IsValid( tp ) ) then
								local pos = string.Explode(",", teleporter.string_position)
								pos = Vector(pos[1], pos[2], pos[3])
								tp:SetPos(pos - tp:GetUp() * 5)
								local ang = string.Explode(",", teleporter.string_angle)
								ang = Angle(ang[1], ang[2], ang[3])
								tp:SetAngles(ang)
								tp:SetNW2Int("yrp_teleporter_uid", tonumber(teleporter.uniqueID))
								tp:SetNW2String("string_name", teleporter.string_name)
								tp:SetNW2String("string_target", teleporter.string_target)
								tp:Spawn()
								tp.PermaProps = true

								YRP.msg("note", "[YourRP Teleporters] " .. "Was dead, respawned")
							else
								YRP.msg("note", "[YourRP Teleporters] " .. "FAIL CREATING ONE")
							end
						end
					end
				else
					YRP.msg("note", "There are a lot of Teleporters!")
				end
			end
		end
	end

	if _time % GetBackupCreateTime() == 0 then
		RemoveOldBackups()
		CreateBackup()
	end

	local _auto_save = 300
	if _time % _auto_save == 0 then
		local _mod = _time % 60
		local _left = _time / 60 - _mod
		local _str = "Auto-Save (Uptime: " .. _left .. " " .. "minutes" .. ")"
		save_clients(_str)
		--SaveStorages(_str)
	end

	local _changelevel = 21600
	if GetGlobalBool("bool_server_reload", false) then
		if _time >= _changelevel then
			YRP.msg("gm", "Auto Reload")
			timer.Simple(1, function()
				game.ConsoleCommand("changelevel " .. GetMapNameDB() .. "\n")
			end)
		end
	end
	if GetGlobalBool("bool_server_reload_notification", false) then
		if _time >= _changelevel - 30 then
			local _str = "Auto Reload in " .. _changelevel - _time .. " sec"
			YRP.msg("gm", _str)

			net.Start("yrp_autoreload")
				net.WriteString(_changelevel - _time)
			net.Broadcast()
		end
	end

	if _time % 1 == 0 and HasDarkrpmodification() then
		MsgC( Color(255, 0, 0), "You have locally \"darkrpmodification\", remove it to make YourRP work!", Color(255, 255, 255), "\n" )
		MsgC( Color(255, 0, 0), "-------------------------------------------------------------------------------", Color(255, 255, 255), "\n" )
		YRPTestDarkrpmodification()
	end

	if _time % 1 == 0 and !HasYRPContent() then
		MsgC( Color(255, 255, 0), "You don't have \"YourRP Content\" on your Server Collection, add it to make YourRP work!", Color(255, 255, 255), "\n" )
		MsgC( Color(255, 255, 0), "-------------------------------------------------------------------------------", Color(255, 255, 255), "\n" )
		YRPTestContentAddons()
	end

	if _time == 10 then
		YRPCheckVersion("think")
	elseif _time == 30 then
		--IsServerInfoOutdated()
	end
	_time = _time + TICK
	_time = math.Round(_time, DEC)
end)

function YRPRestartServer()
	RunConsoleCommand( "map", game.GetMap() )
end

function UpdateSpawnerNPCTable()
	local t = {}
	local all = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'spawner_npc'")
	if wk(all) then
		for i, v in pairs(all) do
			local spawner = {}
			spawner.pos = v.position
			spawner.uniqueID = v.uniqueID
			if !table.HasValue(t, spawner) then
				table.insert(t, spawner)
			end
		end
	end
	SetGlobalTable("yrp_spawner_npc", t)
end
UpdateSpawnerNPCTable()

function UpdateSpawnerENTTable()
	local t = {}
	local all = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'spawner_ent'")
	if wk(all) then
		for i, v in pairs(all) do
			local spawner = {}
			spawner.pos = v.position
			spawner.uniqueID = v.uniqueID
			if !table.HasValue(t, spawner) then
				table.insert(t, spawner)
			end
		end
	end
	SetGlobalTable("yrp_spawner_ent", t)
end
UpdateSpawnerENTTable()

function UpdateJailpointTable()
	local t = {}
	local all = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'jailpoint'")
	if wk(all) then
		for i, v in pairs(all) do
			local spawner = {}
			spawner.pos = v.position
			spawner.uniqueID = v.uniqueID
			spawner.name = v.name
			if !table.HasValue(t, spawner) then
				table.insert(t, spawner)
			end
		end
	end
	SetGlobalTable("yrp_jailpoints", t)
end
UpdateJailpointTable()

function UpdateReleasepointTable()
	local t = {}
	local all = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'releasepoint'")
	if wk(all) then
		for i, v in pairs(all) do
			local spawner = {}
			spawner.pos = v.position
			spawner.uniqueID = v.uniqueID
			if !table.HasValue(t, spawner) then
				table.insert(t, spawner)
			end
		end
	end
	SetGlobalTable("yrp_releasepoints", t)
end
UpdateReleasepointTable()

function UpdateRadiationTable()
	local t = {}
	local all = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'radiation'")
	if wk(all) then
		for i, v in pairs(all) do
			local spawner = {}
			spawner.pos = v.position
			spawner.uniqueID = v.uniqueID
			spawner.name = v.name
			if !table.HasValue(t, spawner) then
				table.insert(t, spawner)
			end
		end
	end
	SetGlobalTable("yrp_radiation", t)
end
UpdateRadiationTable()

function UpdateSafezoneTable()
	local t = {}
	local all = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'safezone'")
	if wk(all) then
		for i, v in pairs(all) do
			local safezone = {}
			safezone.pos = v.position
			safezone.uniqueID = v.uniqueID
			safezone.name = v.name
			if !table.HasValue(t, safezone) then
				table.insert(t, safezone)
			end
		end
	end
	SetGlobalTable("yrp_safezone", t)
end
UpdateSafezoneTable()

function UpdateZoneTable()
	local t = {}
	local all = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'zone'")
	if wk(all) then
		for i, v in pairs(all) do
			local zone = {}
			zone.pos = v.position
			zone.uniqueID = v.uniqueID
			zone.name = v.name
			zone.color = v.color
			if !table.HasValue(t, zone) then
				table.insert(t, zone)
			end
		end
	end
	SetGlobalTable("yrp_zone", t)
end
UpdateZoneTable()

local YNPCs = {}
local YENTs = {}
local delay = CurTime()
hook.Add("Think", "yrp_spawner_think", function()
	if delay < CurTime() then
		delay = CurTime() + 1

		local t = GetGlobalTable("yrp_spawner_npc")
		for _, v in pairs(t) do
			local pos = StringToVector(v.pos)
			if YNPCs[v.uniqueID] == nil then
				YNPCs[v.uniqueID] = {}
				YNPCs[v.uniqueID].npcs = {}
				YNPCs[v.uniqueID].delay = CurTime()
			end

			local npc_spawner = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'spawner_npc' AND uniqueID = '" .. v.uniqueID .. "'")
			if wk(npc_spawner) then
				npc_spawner = npc_spawner[1]
				npc_spawner.int_amount = tonumber(npc_spawner.int_amount)
				npc_spawner.int_respawntime = tonumber(npc_spawner.int_respawntime)
				for _, npc in pairs(YNPCs[v.uniqueID].npcs) do
					if !npc:IsValid() then
						YRP.msg("gm", "A NPC Died, start respawning...")
						table.RemoveByValue(YNPCs[v.uniqueID].npcs, npc)
						YNPCs[v.uniqueID].delay = CurTime() + npc_spawner.int_respawntime
					end
				end

				if YNPCs[v.uniqueID].delay < CurTime() and table.Count(YNPCs[v.uniqueID].npcs) < npc_spawner.int_amount then
					npc_spawner.delay = CurTime() + npc_spawner.int_respawntime
					local npc = ents.Create(npc_spawner.string_classname)
					if npc:IsValid() then
						npc:Spawn()
						teleportToPoint(npc, pos)

						table.insert(YNPCs[v.uniqueID].npcs, npc)
					end
				end
			end
		end

		local t = GetGlobalTable("yrp_spawner_ent")
		for _, v in pairs(t) do
			local pos = StringToVector(v.pos)
			if YENTs[v.uniqueID] == nil then
				YENTs[v.uniqueID] = {}
				YENTs[v.uniqueID].ents = {}
				YENTs[v.uniqueID].delay = CurTime()
			end

			local ent_spawner = YRP_SQL_SELECT("yrp_" .. GetMapNameDB(), "*", "type = 'spawner_ent' AND uniqueID = '" .. v.uniqueID .. "'")
			if wk(ent_spawner) then
				ent_spawner = ent_spawner[1]
				ent_spawner.int_amount = tonumber(ent_spawner.int_amount)
				ent_spawner.int_respawntime = tonumber(ent_spawner.int_respawntime)
				for _, ent in pairs(YENTs[v.uniqueID].ents) do
					if !ent:IsValid() then
						YRP.msg("gm", "A ENT Died, start respawning...")
						table.RemoveByValue(YENTs[v.uniqueID].ents, ent)
						YENTs[v.uniqueID].delay = CurTime() + ent_spawner.int_respawntime
					end
				end

				if YENTs[v.uniqueID].delay < CurTime() and table.Count(YENTs[v.uniqueID].ents) < ent_spawner.int_amount then
					ent_spawner.delay = CurTime() + ent_spawner.int_respawntime
					local ent = ents.Create(ent_spawner.string_classname)
					if ent:IsValid() then
						ent:Spawn()
						teleportToPoint(ent, pos)

						table.insert(YENTs[v.uniqueID].ents, ent)
					end
				end
			end
		end
	end
end, hook.MONITOR_HIGH)

hook.Add( "KeyPress", "yrp_keypress_use_door", function( ply, key )
	if ( key == IN_USE ) then
		local tr = util.TraceLine( {
			start = ply:EyePos(),
			endpos = ply:EyePos() + ply:EyeAngles():Forward() * GetGlobalInt("int_door_distance", 200),
			filter = function( ent ) if ( ent:YRPIsDoor() ) then return true end end
		} )

		local ent = tr.Entity
		if IsValid(ent) then
			if ent:YRPIsDoor() then
				local door = ent
				YRPOpenDoor(ply, door)
			end
		end
	end
end )