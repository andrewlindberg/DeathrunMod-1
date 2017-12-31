#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>

#if AMXX_VERSION_NUM < 183
	#define client_disconnected client_disconnect
#endif

#define PLUGIN "Deathrun: Core"
#define VERSION "Re 1.2.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define IsPlayer(%1) (%1 && %1 <= g_iMaxPlayers)

#define WARMUP_TIME 20

enum _:Cvars
{
	BLOCK_KILL,
	BLOCK_FALLDMG,
	FREEZETIME,
	ROUNDTIME,
	LIMITTEAMS,
	AUTOTEAMBALANCE,
	BUYTIME,
	MAXMONEY,
	ROUND_INFINITE,
	ROUNDRESPAWN_TIME,
	AUTO_JOIN_TEAM,
	HUMANS_JOIN_TEAM,
	TEAMKILLS,
	FORCERESPAWN,
	RADIOICON,
	ALLTALK,
	ENT_INTERSECTION,
	RESTART
};

enum Forwards
{
	FW_NEW_TERRORIST,
	FW_NEXT_TERRORIST,
	FW_WARMUP
};

new const PREFIX[] = "^3[^4Royal Project^3]";

new g_eCvars[Cvars], g_iForwards[Forwards], g_iReturn, g_bWarmUp = true;
new g_iForwardSpawn, Trie:g_tRemoveEntities;
new g_msgAmmoPickup, g_msgWeapPickup;
new g_iOldAmmoPickupBlock, g_iOldWeapPickupBlock, g_iCurrTer, g_iNextTer, g_iMaxPlayers;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar("deathrun_core_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	g_eCvars[BLOCK_KILL] = register_cvar("deathrun_block_kill", "0");
	g_eCvars[BLOCK_FALLDMG] = register_cvar("deathrun_block_falldmg", "1");
	
	g_eCvars[FREEZETIME] = get_cvar_pointer("mp_freezetime");
	g_eCvars[ROUNDTIME] = get_cvar_pointer("mp_roundtime");
	g_eCvars[LIMITTEAMS] = get_cvar_pointer("mp_limitteams");
	g_eCvars[AUTOTEAMBALANCE] = get_cvar_pointer("mp_autoteambalance");
	g_eCvars[BUYTIME] = get_cvar_pointer("mp_buytime");
	g_eCvars[MAXMONEY] = get_cvar_pointer("mp_maxmoney");
	g_eCvars[ROUND_INFINITE] = get_cvar_pointer("mp_round_infinite");
	g_eCvars[ROUNDRESPAWN_TIME] = get_cvar_pointer("mp_roundrespawn_time");
	g_eCvars[AUTO_JOIN_TEAM] = get_cvar_pointer("mp_auto_join_team");
	g_eCvars[HUMANS_JOIN_TEAM] = get_cvar_pointer("humans_join_team");
	g_eCvars[TEAMKILLS] = get_cvar_pointer("mp_max_teamkills");
	g_eCvars[FORCERESPAWN] = get_cvar_pointer("mp_forcerespawn");
	g_eCvars[RADIOICON] = get_cvar_pointer("mp_show_radioicon");
	g_eCvars[ALLTALK] = get_cvar_pointer("sv_alltalk");
	g_eCvars[ENT_INTERSECTION] = get_cvar_pointer("sv_force_ent_intersection");
	g_eCvars[RESTART] = get_cvar_pointer("sv_restart");
	
	register_clcmd("chooseteam", "Command_ChooseTeam");
	
	RegisterHam(Ham_Use, "func_button", "Ham_UseButton_Pre", 0);
	
	RegisterHookChain(RG_ShowVGUIMenu, "ShowVGUIMenu");
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre", 0);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", 1);
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "CBasePlayer_TraceAttack_Pre", 0);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", 0);
	RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "CSGameRules_FlPlayerFallDamage_Pre", 0);
		
	register_forward(FM_ClientKill, "FM_ClientKill_Pre", 0);
	
	register_touch("func_door", "weaponbox", "Engine_TouchFuncDoor");
	
	g_iForwards[FW_NEW_TERRORIST] = CreateMultiForward("dr_chosen_new_terrorist", ET_IGNORE, FP_CELL);
	g_iForwards[FW_NEXT_TERRORIST] = CreateMultiForward("dr_chosen_next_terrorist", ET_IGNORE, FP_CELL);
	g_iForwards[FW_WARMUP] = CreateMultiForward("dr_warm_up", ET_IGNORE, FP_CELL);
	
	g_msgAmmoPickup = get_user_msgid("AmmoPickup");
	g_msgWeapPickup = get_user_msgid("WeapPickup");
	
	unregister_forward(FM_Spawn, g_iForwardSpawn, 0);
	TrieDestroy(g_tRemoveEntities);
	
	Block_Commands();
	CheckMap();
	
	g_iMaxPlayers = get_member_game(m_nMaxPlayers);
}
CheckMap()
{
	new ent = rg_find_ent_by_class(-1, "info_player_deathmatch");
	
	if (is_entity(ent))
	{
		RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
		RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", true);
	}
	
	ent = -1;
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "func_door")))
	{
		new spawnflags = get_entvar(ent, var_spawnflags);
		if ((spawnflags & SF_DOOR_USE_ONLY) && UTIL_IsTargetActivate(ent))
		{
			set_entvar(ent, var_spawnflags, spawnflags & ~SF_DOOR_USE_ONLY);
		}
	}
}
public plugin_precache()
{
	new const szRemoveEntities[][] = 
	{
		"func_bomb_target", "func_escapezone", "func_hostage_rescue", "func_vip_safetyzone", "info_vip_start",
		"hostage_entity", "info_bomb_target", "func_buyzone","info_hostage_rescue", "monster_scientist"
	};
	g_tRemoveEntities = TrieCreate();
	for (new i = 0; i < sizeof(szRemoveEntities); i++)
	{
		TrieSetCell(g_tRemoveEntities, szRemoveEntities[i], i);
	}
	g_iForwardSpawn = register_forward(FM_Spawn, "FakeMeta_Spawn_Pre", 0);
	engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"));
}
public FakeMeta_Spawn_Pre(ent)
{
	if (!is_entity(ent)) return FMRES_IGNORED;
	
	static szClassName[32]; 
	{
		get_entvar(ent, var_classname, szClassName, charsmax(szClassName));
	}
	
	if (TrieKeyExists(g_tRemoveEntities, szClassName))
	{
		engfunc(EngFunc_RemoveEntity, ent);
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;
}
public plugin_cfg()
{
	register_dictionary("deathrun_core.txt");
	
	set_pcvar_num(g_eCvars[FREEZETIME], 0);
	set_pcvar_num(g_eCvars[ROUNDTIME], 0);
	set_pcvar_num(g_eCvars[LIMITTEAMS], 0);
	set_pcvar_num(g_eCvars[AUTOTEAMBALANCE], 0);
	set_pcvar_num(g_eCvars[BUYTIME], 0);
	set_pcvar_num(g_eCvars[MAXMONEY], 1000000);
	set_pcvar_string(g_eCvars[ROUND_INFINITE], "abcdeg");
	set_pcvar_num(g_eCvars[ROUNDRESPAWN_TIME], WARMUP_TIME);
	set_pcvar_num(g_eCvars[AUTO_JOIN_TEAM], 1);
	set_pcvar_string(g_eCvars[HUMANS_JOIN_TEAM], "CT");
	set_pcvar_num(g_eCvars[TEAMKILLS], 0);
	set_pcvar_num(g_eCvars[FORCERESPAWN], 1);
	set_pcvar_num(g_eCvars[RADIOICON], 0);
	set_pcvar_num(g_eCvars[ALLTALK], 1);
	set_pcvar_num(g_eCvars[ENT_INTERSECTION], 1);

	set_pcvar_num(g_eCvars[RESTART], WARMUP_TIME);
	ExecuteForward(g_iForwards[FW_WARMUP], g_iReturn, WARMUP_TIME);

}
public plugin_natives()
{
	register_library("deathrun_core");
	register_native("dr_get_terrorist", "native_get_terrorist", .style = true);
	register_native("dr_set_next_terrorist", "native_set_next_terrorist", .style = false);
	register_native("dr_get_next_terrorist", "native_get_next_terrorist", .style = true);
}
public native_get_terrorist()
{
	return g_iCurrTer;
}
public native_set_next_terrorist(plugin, params)
{
	enum { arg_player = 1 };
	new id = get_param(arg_player);
	if (1 < id > MAX_CLIENTS)
	{
		log_error(AMX_ERR_NATIVE, "[DRM] Set next terrorist: wrong player index! index %d", id);
		return 0;
	}

	g_iNextTer = id;
	ExecuteForward(g_iForwards[FW_NEXT_TERRORIST], g_iReturn, g_iNextTer);
	return 1;
}
public native_get_next_terrorist()
{
	return g_iNextTer;
}
public client_putinserver(id)
{
	if (!g_bWarmUp && !is_user_connected(g_iCurrTer))
	{
		new iPlayers[32], pnum;	pnum = rg_get_players(iPlayers);
		if (pnum == 1)
		{
			rg_round_end(5.0, WINSTATUS_NONE, ROUND_GAME_RESTART, "Подключение игрока завершено!");
		}
	}
}
public client_disconnected(id)
{
	if (id == g_iCurrTer)
	{
		new iPlayers[32], pnum;	pnum = rg_get_players(iPlayers, true, true);
		if (pnum > 1)
		{
			g_iCurrTer = iPlayers[random(pnum)];
			rg_set_user_team(g_iCurrTer, TEAM_TERRORIST);
			rg_round_respawn(g_iCurrTer);

			new Float:fOrigin[3]; 
			{
				get_entvar(id, var_origin, fOrigin);
				set_entvar(g_iCurrTer, var_origin, fOrigin);
			}
			
			// In case he was sitting in a low space
			if (get_entvar(id, var_bInDuck))
			{
				set_entvar(g_iCurrTer, var_bInDuck, true);
			}
			
			// In case he was flying over the precipice or something else
			new Float:fVelocity[3];
			{
				get_entvar(id, var_velocity, fVelocity);
				set_entvar(g_iCurrTer, var_velocity, fVelocity);
			}

			new Float:fAngles[3];
			{
				get_entvar(id, var_angles, fAngles);
				set_entvar(g_iCurrTer, var_angles, fAngles);
			}
			set_entvar(g_iCurrTer, var_fixangle, 1);
			
			ExecuteForward(g_iForwards[FW_NEW_TERRORIST], g_iReturn, g_iCurrTer);
			
			new szName[32]; get_entvar(g_iCurrTer, var_netname, szName, charsmax(szName));
			new szNameLeaver[32]; get_entvar(id, var_netname, szNameLeaver, charsmax(szNameLeaver));
			client_print_color(0, print_team_red, "%s %L", PREFIX, LANG_PLAYER, "DRC_TERRORIST_LEFT", szNameLeaver, szName);
		}
		else
		{
			rg_round_end(5.0, WINSTATUS_DRAW, ROUND_END_DRAW, "Террорист покинул сервер!");
		}
	}
	
	if(is_user_connected(g_iCurrTer))
	{
		new iPlayers[32], pnum;	pnum = rg_get_players(iPlayers, .skip_ter = true);
		if(!pnum)
		{
			rg_set_user_team(g_iCurrTer, TEAM_CT);
		}
	}
}
//******** Commands ********//
public Command_ChooseTeam(id)
{
	client_cmd(id, "menu");
	//Add custom menu
	return PLUGIN_HANDLED;
}
//***** Block Commands *****//
Block_Commands()
{
	new szBlockedCommands[][] = {"jointeam", "joinclass", "radio1", "radio2", "radio3"};
	for(new i = 0; i < sizeof(szBlockedCommands); i++)
	{
		register_clcmd(szBlockedCommands[i], "Command_BlockCmds");
	}
}
public Command_BlockCmds(id)
{
	return PLUGIN_HANDLED;
}
// ******* Hamsandwich *******
public Ham_UseButton_Pre(ent, caller, activator, use_type)
{
	if(!IsPlayer(activator) || !is_user_alive(activator) || get_member(activator, m_iTeam) == TEAM_TERRORIST) return HAM_IGNORED;
	
	new Float:fEntOrigin[3], Float:fPlayerOrigin[3];
	fEntOrigin = get_ent_brash_origin(ent);
	fPlayerOrigin = get_player_eyes_origin(activator);
	
	new bool:bCanUse = allow_press_button(ent, fPlayerOrigin, fEntOrigin);
	
	return bCanUse ? HAM_IGNORED : HAM_SUPERCEDE;
}
Float:get_ent_brash_origin(ent)
{
	new Float:mins[3]; get_entvar(ent, var_absmin, mins);
	new Float:maxs[3]; get_entvar(ent, var_absmax, maxs);
	new Float:origin[3]; xs_vec_add(mins, maxs, origin);
	xs_vec_mul_scalar(origin, 0.5, origin);
	return origin;
}
Float:get_player_eyes_origin(id)
{
	new eyes_origin[3]; get_user_origin(id, eyes_origin, 1);
	new Float:origin[3]; IVecFVec(eyes_origin, origin);
	return origin;
}
// ******* Re GameDll *******
public ShowVGUIMenu(const index, VGUIMenu:menuType, const bitsSlots, szOldMenu[])
{
    return (VGUI_Menu_Team >= menuType <= VGUI_Menu_Buy_Item) ? HC_BREAK : HC_CONTINUE;
}
public CBasePlayer_Spawn_Pre(const this)
{	
	g_iOldAmmoPickupBlock = get_msg_block(g_msgAmmoPickup);
	g_iOldWeapPickupBlock = get_msg_block(g_msgWeapPickup);
	set_msg_block(g_msgAmmoPickup, BLOCK_SET);
	set_msg_block(g_msgWeapPickup, BLOCK_SET);
}
public CBasePlayer_Spawn_Post(const this)
{
	set_msg_block(g_msgAmmoPickup, g_iOldAmmoPickupBlock);
	set_msg_block(g_msgWeapPickup, g_iOldWeapPickupBlock);
	
	if(!is_user_alive(this)) return HC_CONTINUE;
	
	block_user_radio(this);
	
	rg_remove_items_by_slot(this, PRIMARY_WEAPON_SLOT);
	rg_remove_items_by_slot(this, GRENADE_SLOT);
	rg_give_item(this, "weapon_knife", GT_REPLACE);
	
	return HC_CONTINUE;
}
public CBasePlayer_TraceAttack_Pre(const this, pevAttacker, Float:flDamage, Float:vecDir[3], tracehandle, bitsDamageType)
{
    return (flDamage < 0.0) ? HC_SUPERCEDE : HC_CONTINUE;
}
public CBasePlayer_TakeDamage_Pre(const this, pevInflictor, pevAttacker, Float:flDamage, bitsDamageType)
{
    return (flDamage < 0.0) ? HC_SUPERCEDE : HC_CONTINUE;
}
public CSGameRules_FlPlayerFallDamage_Pre(const index)
{
    if (get_pcvar_num(g_eCvars[BLOCK_FALLDMG]) && index == g_iCurrTer)
    {
        // Remove the damage to the terrorist when falling from height
        SetHookChainReturn(ATYPE_FLOAT, 0.0);
        return HC_SUPERCEDE;
    }
    
    return HC_CONTINUE;
}
public CSGameRules_RestartRound_Pre()
{
	if(get_member_game(m_bCompleteReset))
	{
		g_bWarmUp = false;
		set_pcvar_num(g_eCvars[FORCERESPAWN], 0);
		ExecuteForward(g_iForwards[FW_WARMUP], g_iReturn, 0);
	}

	if(!g_bWarmUp)
	{
		TeamBalance();	
	}
}
TeamBalance()
{
	new iPlayers[32], pnum; pnum = rg_get_players(iPlayers, false, true);
	
	if(pnum < 1 || pnum == 1 && !is_user_connected(g_iCurrTer)) return;

	if(is_user_connected(g_iCurrTer)) rg_set_user_team(g_iCurrTer, TEAM_CT);
	
	if(!is_user_connected(g_iNextTer))
	{
		g_iCurrTer = iPlayers[random(pnum)];
	}
	else
	{
		g_iCurrTer = g_iNextTer;
		g_iNextTer = 0;
	}
	
	rg_set_user_team(g_iCurrTer, TEAM_TERRORIST);
	new szName[32]; 
	{
		get_entvar(g_iCurrTer, var_netname, szName, charsmax(szName));
		client_print_color(0, print_team_red, "%s %L", PREFIX, LANG_PLAYER, "DRC_BECAME_TERRORIST", szName);
	}
}
public CSGameRules_RestartRound_Post()
{
	TerroristCheck();
}
TerroristCheck()
{
	if(!is_user_connected(g_iCurrTer))
	{
		new players[32], pnum; get_players(players, pnum, "ae", "TERRORIST");
		g_iCurrTer = pnum ? players[0] : 0;
	}
	ExecuteForward(g_iForwards[FW_NEW_TERRORIST], g_iReturn, g_iCurrTer);
}
// ******* Fakemeta *******
public FM_ClientKill_Pre(id)
{
	return (get_pcvar_num(g_eCvars[BLOCK_KILL]) || is_user_alive(id) && get_member(id, m_iTeam) == TEAM_TERRORIST) ? FMRES_SUPERCEDE : FMRES_IGNORED;
}
// ******* Engine *******
public Engine_TouchFuncDoor(ent, toucher)
{
	if(is_valid_ent(toucher))
	{
		remove_entity(toucher);
	}
}
// ********************* //
stock rg_get_players(players[32], bool:alive = false, skip_ter = false)
{
	new TeamName:team, count;
	for(new i = 1; i <= g_iMaxPlayers; i++)
	{
		if(skip_ter && i == g_iCurrTer 
		|| !is_user_connected(i) 
		|| alive && !is_user_alive(i)) continue;
		team = get_member(i, m_iTeam);
		if(TEAM_TERRORIST < team > TEAM_CT) continue;
		players[count++] = i;
	}
	return count;
}
stock block_user_radio(id)
{
	const m_iRadiosLeft = 192;
	set_pdata_int(id, m_iRadiosLeft, 0);
}
stock bool:allow_press_button(ent, Float:start[3], Float:end[3], bool:ignore_players = true)
{
	new trace = 0; engfunc(EngFunc_TraceLine, start, end, (ignore_players ? IGNORE_MONSTERS : DONT_IGNORE_MONSTERS), ent, trace);
	new Float:fraction; get_tr2(trace, TR_flFraction, fraction);
	
	if(fraction == 1.0) return true;
	
	new hit_ent = get_tr2(trace, TR_pHit);
	
	if(!is_entity(hit_ent)) return false;
	
	new Float:fAbsMin[3]; get_entvar(hit_ent, var_absmin, fAbsMin);
	new Float:fAbsMax[3]; get_entvar(hit_ent, var_absmax, fAbsMax);
	new Float:fVolume[3]; xs_vec_sub(fAbsMax, fAbsMin, fVolume);
	
	if(fVolume[0] < 48.0 && fVolume[1] < 48.0 && fVolume[2] < 48.0) return true;
	
	return false;
}
stock bool:UTIL_IsTargetActivate(const ent)
{
	new target_name[32]; get_entvar(ent, var_targetname, target_name, charsmax(target_name));
	return (target_name[0]) ? false : true;
}
