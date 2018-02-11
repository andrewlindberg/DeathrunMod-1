#include <amxmodx>
#include <cstrike>
#include <fun>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>
#include <xs>
#include <reapi>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	#define client_disconnected client_disconnect
#endif

#define PLUGIN "Deathrun Mode: Duel"
#define VERSION "Re 1.0.3"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define SHOW_MENU_FOR_LAST_CT

#define PRESTART_TIME 10
#define FIRE_TIME 5
#define DUEL_TIME 60
#define MAX_DISTANCE 1500
#define MIN_DISTANCE 300

enum CancelType
{
	CType_TimeOver,
	CType_PlayerDisconneced,
	CType_PlayerDied,
	CType_ModeChanged
};

enum (+=100)
{
	TASK_TURNCHANGER = 100,
	TASK_PRESTART_TIMER,
	TASK_DUELTIMER
};

new const PREFIX[] = "^4[Duel]";
new const SPAWNS_DIR[] = "deathrun_duel";

enum _:DUEL_FORWARDS
{
	DUEL_PRESTART,
	DUEL_START,
	DUEL_FINISH,
	DUEL_CANCELED
};

enum
{
	DUELIST_CT = 0,
	DUELIST_T
};

new g_iModeDuel;
new g_bDuelStarted;
new g_iDuelType;
new g_iDuelPlayers[2];
new g_iDuelWeapon[2];
new g_iDuelTurnTimer;
new g_iDuelTimer;
new g_iCurTurn;
new g_iDuelMenu;

new Float:g_fDuelSpawnOrigins[2][3];
new Float:g_fDuelSpawnAngles[2][3];
new g_bShowSpawns;
new g_bLoadedSpawns;
new g_szSpawnsFile[128];
new g_bSetSpawn[2];
new g_iMinDistance;

new Float:g_fColors[2][3] = 
{
	{ 0.0, 0.0, 250.0 },
	{ 250.0, 0.0, 0.0 }
};

new g_iForwards[DUEL_FORWARDS];
new g_iReturn;
new g_bSavedConveyorInfo;

new g_eDuelMenuItems[][] =
{
    "Knife",
    "Deagle",
    "Usp",
    "Glock18",
    "AWP",
    "Scout",
    "Famas",
    "AK47",
    "M4A1",
};

new g_eDuelWeaponWithTurn[][] =
{
    "weapon_knife",
    "weapon_deagle",
    "weapon_usp",
    "weapon_glock18",
    "weapon_awp",
    "weapon_scout",
    "weapon_famas",
    "weapon_ak47",
    "weapon_m4a1"
};

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd("say /dd", "Command_Duel");
	register_clcmd("say /duel", "Command_Duel");
	register_clcmd("duel_spawns", "Command_DuelSpawn", ADMIN_CFG);
	
	for(new i = 1; i < sizeof(g_eDuelWeaponWithTurn); i++)
	{
		RegisterHam(Ham_Weapon_PrimaryAttack, g_eDuelWeaponWithTurn[i], "Ham_WeaponPrimaryAttack_Post", 1);
	}
	
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_usp", "Ham_WeaponSecondaryAttack_Pre", 0);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_glock18", "Ham_WeaponSecondaryAttack_Pre", 0);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_awp", "Ham_WeaponSecondaryAttack_Pre", 0);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_scout", "Ham_WeaponSecondaryAttack_Pre", 0);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_famas", "Ham_WeaponSecondaryAttack_Pre", 0);
	
	register_touch("trigger_push", "player", "Engine_DuelTouch");
	register_touch("trigger_teleport", "player", "Engine_DuelTouch");
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", 0);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", 1);
	RegisterHookChain(RG_CBasePlayer_DropPlayerItem, "CBasePlayer_DropPlayerItem_Pre", 0);
	
	g_iForwards[DUEL_PRESTART] = CreateMultiForward("dr_duel_prestart", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_iForwards[DUEL_START] = CreateMultiForward("dr_duel_start", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_iForwards[DUEL_FINISH] = CreateMultiForward("dr_duel_finish", ET_IGNORE, FP_CELL, FP_CELL);
	g_iForwards[DUEL_CANCELED] = CreateMultiForward("dr_duel_canceled", ET_IGNORE, FP_CELL);
	
	g_iModeDuel = dr_register_mode
	(
		.Name = "DRM_MODE_DUEL",
		.Mark = "duel",
		.RoundDelay = 0,
		.CT_BlockWeapons = 1,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 1,
		.TT_BlockButtons = 1,
		.Bhop = 0,
		.Usp = 0,
		.Hide = 1
	);
	
	Create_DuelMenu();
	#if defined SHOW_MENU_FOR_LAST_CT
	register_menucmd(register_menuid("DuelOfferMenu"), 1023, "DuelOffer_Handler");
	#endif
}
Create_DuelMenu()
{
	g_iDuelMenu = menu_create("Choose duel type:", "DuelType_Handler");
	for(new i; i < sizeof(g_eDuelMenuItems); i++)
	{
		menu_additem(g_iDuelMenu, g_eDuelMenuItems[i]);
	}
}
public plugin_cfg()
{
	register_dictionary("deathrun_mode_duel.txt");
	LoadSpawns();
}
public plugin_natives()
{
	register_library("deathrun_duel");
}
LoadSpawns()
{
	new szConfigDir[128]; get_localinfo("amxx_configsdir", szConfigDir, charsmax(szConfigDir));
	new szDir[128]; formatex(szDir, charsmax(szDir), "%s/%s", szConfigDir, SPAWNS_DIR);
	
	new szMap[32]; get_mapname(szMap, charsmax(szMap));
	formatex(g_szSpawnsFile, charsmax(g_szSpawnsFile), "%s/%s.ini", szDir, szMap);
	
	if(dir_exists(szDir))
	{
		if(file_exists(g_szSpawnsFile))
		{
			new f = fopen(g_szSpawnsFile, "rt");
			
			if(f)
			{
				new szText[128], szTeam[3], szOrigins[3][16];
				while(!feof(f))
				{
					fgets(f, szText, charsmax(szText));
					parse(szText, szTeam, charsmax(szTeam), szOrigins[0], charsmax(szOrigins[]), szOrigins[1], charsmax(szOrigins[]), szOrigins[2], charsmax(szOrigins[]));
					new team = (szTeam[0] == 'C' ? 0 : 1);
					g_fDuelSpawnOrigins[team][0] = str_to_float(szOrigins[0]);
					g_fDuelSpawnOrigins[team][1] = str_to_float(szOrigins[1]);
					g_fDuelSpawnOrigins[team][2] = str_to_float(szOrigins[2]);
					g_bSetSpawn[team] = true;
				}
				fclose(f);
				if(g_bSetSpawn[DUELIST_CT] && g_bSetSpawn[DUELIST_T])
				{
					g_bLoadedSpawns = true;
					GetSpawnAngles();
				}
			}
		}
		else
		{
			FindSpawns();
		}
	}
	else
	{
		mkdir(szDir);
		FindSpawns();
	}
	
	if(g_bLoadedSpawns)
	{
		GetMinDistance();
	}
}
GetMinDistance()
{
	new Float:fDistance = get_distance_f(g_fDuelSpawnOrigins[DUELIST_CT], g_fDuelSpawnOrigins[DUELIST_T]);
	g_iMinDistance = fDistance < MIN_DISTANCE ? floatround(fDistance - 64.0) : MIN_DISTANCE;
}
FindSpawns()
{
	new first_ent = rg_find_ent_by_class(-1, "info_player_start", true);
	get_entvar(first_ent, var_origin, g_fDuelSpawnOrigins[DUELIST_CT]);
	
	new ent = first_ent, bFind;
	new Float:distance = 1000.0;
	
	while(distance > 100.0 && !bFind)
	{
		while((ent = rg_find_ent_by_class(ent, "info_player_start", true)))
		{
			if(get_entity_distance(ent, first_ent) > distance)
			{
				bFind = true;
				get_entvar(ent, var_origin, g_fDuelSpawnOrigins[DUELIST_T]);
				break;
			}
		}
		distance -= 100.0;
		ent = first_ent;
	}
	if(bFind)
	{
		g_bLoadedSpawns = true;
		GetSpawnAngles();
	}
}
GetSpawnAngles()
{
	new Float:fVector[3]; 
	{
		xs_vec_sub(g_fDuelSpawnOrigins[DUELIST_T], g_fDuelSpawnOrigins[DUELIST_CT], fVector);
		xs_vec_normalize(fVector, fVector);
		vector_to_angle(fVector, g_fDuelSpawnAngles[DUELIST_CT]);
		xs_vec_mul_scalar(fVector, -1.0, fVector);
		vector_to_angle(fVector, g_fDuelSpawnAngles[DUELIST_T]);
	}
}
public client_disconnected(id)
{
	if(g_bDuelStarted && (id == g_iDuelPlayers[DUELIST_CT] || id == g_iDuelPlayers[DUELIST_T]))
	{
		ResetDuel();
		ExecuteForward(g_iForwards[DUEL_CANCELED], g_iReturn, CType_PlayerDisconneced);
	}
}
public Command_DuelSpawn(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	
	Show_DuelSpawnControlMenu(id);
	
	return PLUGIN_HANDLED;
}
public Show_DuelSpawnControlMenu(id)
{
	new szText[64], menu = menu_create("Duel Spawn Control", "DuelSpawnControl_Handler");
	menu_additem(menu, "Set \rCT\w spawn");
	menu_additem(menu, "Set \rT\w spawn");
	formatex(szText, charsmax(szText), "%s spawns", g_bShowSpawns ? "Hide" : "Show");
	menu_additem(menu, szText);
	menu_additem(menu, "Save spawns^n");
	formatex(szText, charsmax(szText), "Noclip \r[%s]", get_user_noclip(id) ? "ON" : "OFF");
	menu_additem(menu, szText);
	menu_display(id, menu);
}
public DuelSpawnControl_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	switch(item)
	{
		case 0, 1:
		{
			g_bSetSpawn[item] = true;
			get_entvar(id, var_origin, g_fDuelSpawnOrigins[item]);
			if(g_bShowSpawns)
			{
				UpdateSpawnEnt();
			}
		}
		case 2:
		{
			if(!g_bShowSpawns)
			{
				g_bShowSpawns = true;
				CreateSpawnEnt(DUELIST_CT);
				CreateSpawnEnt(DUELIST_T);
			}
			else
			{
				g_bShowSpawns = false;
				RemoveSpawnEnt();
			}
		}
		case 3:
		{
			SaveSpawns(id);
		}
		case 4:
		{
			set_user_noclip(id, !get_user_noclip(id));
		}
	}
	
	Show_DuelSpawnControlMenu(id);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
CreateSpawnEnt(type)
{
	static szModels[][] = {"models/player/urban/urban.mdl", "models/player/arctic/arctic.mdl"};
	new ent = rg_create_entity("info_target");
	DispatchSpawn(ent);
	
	entity_set_model(ent, szModels[type]);
	entity_set_string(ent, EV_SZ_classname, "duel_spawn_ent");
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP);
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
	entity_set_int(ent, EV_INT_iuser1, type);
	entity_set_int(ent, EV_INT_sequence, 1);
	
	entity_set_vector(ent, EV_VEC_origin, g_fDuelSpawnOrigins[type]);
	entity_set_vector(ent, EV_VEC_angles, g_fDuelSpawnAngles[type]);
}
RemoveSpawnEnt()
{
	new ent = -1;
	while((ent = rg_find_ent_by_class(ent, "duel_spawn_ent")))
	{
		remove_entity(ent);
	}
}
UpdateSpawnEnt()
{
	GetSpawnAngles();
	new ent = -1;
	while((ent = rg_find_ent_by_class(ent, "duel_spawn_ent")))
	{
		new type = entity_get_int(ent, EV_INT_iuser1);
		entity_set_vector(ent, EV_VEC_origin, g_fDuelSpawnOrigins[type]);
		entity_set_vector(ent, EV_VEC_angles, g_fDuelSpawnAngles[type]);
	}
}
SaveSpawns(id)
{
	if(!g_bSetSpawn[DUELIST_CT] || !g_bSetSpawn[DUELIST_T])
	{
		client_print_color(id, print_team_default, "^%s^1 %L", PREFIX, id, "DRD_SET_SPAWNS");
		return;
	}
	if(file_exists(g_szSpawnsFile))
	{
		delete_file(g_szSpawnsFile);
	}
	new file = fopen(g_szSpawnsFile, "wt");
	if(file)
	{
		fprintf(file, "CT %f %f %f^n", g_fDuelSpawnOrigins[DUELIST_CT][0], g_fDuelSpawnOrigins[DUELIST_CT][1], g_fDuelSpawnOrigins[DUELIST_CT][2]);
		fprintf(file, "T %f %f %f^n", g_fDuelSpawnOrigins[DUELIST_T][0], g_fDuelSpawnOrigins[DUELIST_T][1], g_fDuelSpawnOrigins[DUELIST_T][2]);
		fclose(file);
		g_bLoadedSpawns = true;
		GetSpawnAngles();
		GetMinDistance();
		client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRD_SPAWNS_SAVED");
	}
}
public Command_Duel(id)
{
	if(g_bDuelStarted || !is_user_alive(id) || get_member(id, m_iTeam) != TEAM_CT) return PLUGIN_HANDLED;
		
	new players[32], pnum; get_players(players, pnum, "ae", "CT");
	if(pnum > 1) return PLUGIN_HANDLED;
	
	g_iDuelPlayers[DUELIST_CT] = id;
	
	get_players(players, pnum, "ae", "TERRORIST");
	if(pnum < 1) return PLUGIN_HANDLED;
	
	menu_display(id, g_iDuelMenu);
	
	return PLUGIN_HANDLED;
}
public DuelType_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		return PLUGIN_HANDLED;
	}
	
	new players[32], pnum; get_players(players, pnum, "ae", "CT");
	if(pnum > 1) return PLUGIN_HANDLED;
	
	get_players(players, pnum, "ae", "TERRORIST");
	if(pnum < 1) return PLUGIN_HANDLED;
	
	g_iDuelPlayers[DUELIST_T] = players[0];
	
	if(!is_user_alive(id) || !is_user_alive(g_iDuelPlayers[DUELIST_T]) || get_member(id, m_iTeam) != TEAM_CT) return PLUGIN_HANDLED;
	
	dr_set_mode(g_iModeDuel, 1);
	
	g_iDuelType = item;
	
	DuelPreStart();
	
	return PLUGIN_HANDLED;
}
DuelPreStart()
{
	g_bDuelStarted = true;
	
	PrepareForDuel(DUELIST_CT);
	PrepareForDuel(DUELIST_T);
	
	if(g_bLoadedSpawns)
	{
		MovePlayerToSpawn(DUELIST_CT);
		MovePlayerToSpawn(DUELIST_T);
	}
	
	StopFuncConveyor();
	
	g_iDuelTimer = PRESTART_TIME + 1;
	Task_PreStartTimer();
	
	ExecuteForward(g_iForwards[DUEL_PRESTART], g_iReturn, g_iDuelPlayers[DUELIST_T], g_iDuelPlayers[DUELIST_CT], g_iDuelTimer);
	
	client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "DRD_DUEL_START_TIME", PRESTART_TIME);
}
public Task_PreStartTimer()
{
	if(!g_bDuelStarted) return;
	
	if(--g_iDuelTimer <= 0)
	{
		DuelStartForward(g_iDuelType);
	}
	else
	{
		client_print(0, print_center, "%L", LANG_PLAYER, "DRD_DUEL_START_TIME", g_iDuelTimer);
		set_task(1.0, "Task_PreStartTimer", TASK_PRESTART_TIMER);
	}
}

DuelStartForward(type)
{
	StartTurnDuel(type);
	StartDuelTimer();
}
StartDuelTimer()
{
	g_iDuelTimer = DUEL_TIME + 1;
	Task_DuelTimer();
	
	ExecuteForward(g_iForwards[DUEL_START], g_iReturn, g_iDuelPlayers[DUELIST_T], g_iDuelPlayers[DUELIST_CT], g_iDuelTimer);
}
public Task_DuelTimer()
{
	if(!g_bDuelStarted) return;
	
	if(--g_iDuelTimer <= 0)
	{
		ExecuteHam(Ham_Killed, g_iDuelPlayers[DUELIST_CT], g_iDuelPlayers[DUELIST_CT], 0);
		ExecuteHam(Ham_Killed, g_iDuelPlayers[DUELIST_T], g_iDuelPlayers[DUELIST_T], 0);
		
		ExecuteForward(g_iForwards[DUEL_CANCELED], g_iReturn, CType_TimeOver);
		ResetDuel();
		
		client_print_color(0, print_team_default, "%s^1 %L", PREFIX, LANG_PLAYER, "DRD_TIME_OVER");
	}
	else
	{
		client_cmd(0, "spk buttons/lightswitch2");
		set_task(1.0, "Task_DuelTimer", TASK_DUELTIMER);
	}
}
PrepareForDuel(player)
{
	rg_remove_all_items(g_iDuelPlayers[player], true);
	set_entvar(g_iDuelPlayers[player], var_health, 100.0);
	set_entvar(g_iDuelPlayers[player], var_gravity, 1.0);
	rh_set_user_rendering(g_iDuelPlayers[player], kRenderFxGlowShell, g_fColors[player], kRenderNormal, 20.0);
}
MovePlayerToSpawn(player)
{
	set_entvar(g_iDuelPlayers[player], var_origin, g_fDuelSpawnOrigins[player]);
	set_entvar(g_iDuelPlayers[player], var_v_angle, g_fDuelSpawnAngles[player]);
	set_entvar(g_iDuelPlayers[player], var_angles, g_fDuelSpawnAngles[player]);
	set_entvar(g_iDuelPlayers[player], var_fixangle, 1);
	set_entvar(g_iDuelPlayers[player], var_velocity, Float:{0.0, 0.0, 0.0});
}
StartTurnDuel(type)
{
	g_iDuelWeapon[DUELIST_CT] = rg_give_item(g_iDuelPlayers[DUELIST_CT], g_eDuelWeaponWithTurn[type], GT_REPLACE);
	g_iDuelWeapon[DUELIST_T] = rg_give_item(g_iDuelPlayers[DUELIST_T], g_eDuelWeaponWithTurn[type], GT_REPLACE);
	
	new WeaponIdType:WeaponId, AmmoType;
	{
		WeaponId = rg_get_weapon_info(g_eDuelWeaponWithTurn[type], WI_ID);
		AmmoType = rg_get_weapon_info(WeaponId, WI_AMMO_TYPE);
		
		if(AmmoType > 0)
		{	
			if(is_entity(g_iDuelWeapon[DUELIST_CT]) 
			&& is_entity(g_iDuelWeapon[DUELIST_T]))
			{
				rg_set_user_ammo(g_iDuelPlayers[DUELIST_CT], WeaponId, 1);
				rg_set_user_ammo(g_iDuelPlayers[DUELIST_T], WeaponId, 0);
			}
			
			g_iDuelTurnTimer = FIRE_TIME;
			g_iCurTurn = DUELIST_CT;
			Task_ChangeTurn();
		}
	}
}
public Task_ChangeTurn()
{
	if(!g_bDuelStarted) return;
	
	if(g_iDuelTurnTimer > 0)
	{
		client_print(g_iDuelPlayers[g_iCurTurn], print_center, "%L", g_iDuelPlayers[g_iCurTurn], "DRD_SHOOT_TIME", g_iDuelTurnTimer);
	}
	else
	{
		if(is_entity(g_iDuelWeapon[g_iCurTurn]))
		{
			ExecuteHamB(Ham_Weapon_PrimaryAttack, g_iDuelWeapon[g_iCurTurn]);
		}
	}
	
	if(g_bLoadedSpawns)
	{
		CheckPlayersDistance();
	}
	
	g_iDuelTurnTimer--;
	set_task(1.0, "Task_ChangeTurn", TASK_TURNCHANGER);
}
CheckPlayersDistance()
{
	if(!is_user_alive(g_iDuelPlayers[DUELIST_CT]) || !is_user_alive(g_iDuelPlayers[DUELIST_T]))
	{
		return;
	}
	
	new distance = get_entity_distance(g_iDuelPlayers[DUELIST_CT], g_iDuelPlayers[DUELIST_T]);
	if(distance < g_iMinDistance || distance > MAX_DISTANCE)
	{
		MovePlayerToSpawn(DUELIST_CT);
		MovePlayerToSpawn(DUELIST_T);
	}
}
public Ham_WeaponPrimaryAttack_Post(weapon)
{
	if(!g_bDuelStarted || (weapon != g_iDuelWeapon[DUELIST_CT] && weapon != g_iDuelWeapon[DUELIST_T])) return HAM_IGNORED;
	
	new player = get_member(weapon, m_pPlayer);
	
	if(player == g_iDuelPlayers[g_iCurTurn])
	{
		g_iDuelTurnTimer = FIRE_TIME;
		g_iCurTurn ^= 1;
		
		new WeaponIdType:weaponbox_id;
		{
			weaponbox_id = rg_get_weaponbox_id(g_iDuelWeapon[g_iCurTurn]);
			rg_set_user_ammo(g_iDuelPlayers[g_iCurTurn], weaponbox_id, 1);
		}
		
		remove_task(TASK_TURNCHANGER);
		Task_ChangeTurn();
	}
	
	return HAM_IGNORED;
}
public Ham_WeaponSecondaryAttack_Pre(weapon)
{
	return g_bDuelStarted ? HAM_SUPERCEDE : HAM_IGNORED;
}
public Engine_DuelTouch(ent, toucher)
{
	return g_bDuelStarted ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}
public CBasePlayer_TakeDamage_Pre(const this, pevInflictor, pevAttacker, Float:flDamage, bitsDamageType)
{
	if(!g_bDuelStarted || this == pevAttacker || (this != g_iDuelPlayers[DUELIST_CT] && this != g_iDuelPlayers[DUELIST_T]))
	{
		return HC_CONTINUE;
	}
	
	if(pevAttacker != g_iDuelPlayers[DUELIST_CT] && pevAttacker != g_iDuelPlayers[DUELIST_T])
	{
		SetHookChainReturn(ATYPE_INTEGER, 0);
		return HC_SUPERCEDE;
	}
	
	return HC_CONTINUE;
}
public CBasePlayer_Killed_Post(const this, pevAttacker, iGib)
{
	if(g_bDuelStarted && (this == g_iDuelPlayers[DUELIST_CT] || this == g_iDuelPlayers[DUELIST_T]))
	{
		if(pevAttacker != this && (pevAttacker == g_iDuelPlayers[DUELIST_CT] || pevAttacker == g_iDuelPlayers[DUELIST_T]))
		{
			FinishDuel(pevAttacker, this);
		}
		else
		{
			ExecuteForward(g_iForwards[DUEL_CANCELED], g_iReturn, CType_PlayerDied);
		}
		ResetDuel();
	}
#if defined SHOW_MENU_FOR_LAST_CT
	else
	{
		new players[32], pnum; get_players(players, pnum, "ae", "CT");
		if(pnum == 1)
		{
			new ct = players[0]; get_players(players, pnum, "ae", "TERRORIST"); 
			if(pnum)
			{
				new t = players[0];
				Show_DuelOffer(ct, t);
			}
		}
	}
#endif
}
#if defined SHOW_MENU_FOR_LAST_CT
Show_DuelOffer(id, enemy)
{
	new szMenu[256], iLen;
	new szEnemy[32]; get_entvar(enemy, var_netname, szEnemy, charsmax(szEnemy));
	iLen = formatex(szMenu, charsmax(szMenu), "%L^n^n", id, "DRD_DUEL_OFFER", szEnemy);
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1.\w %L^n", id, "DRD_YES");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2.\w %L", id, "DRD_NO");
	
	show_menu(id, (1 << 0)|(1 << 1), szMenu, -1, "DuelOfferMenu");
}
public DuelOffer_Handler(id, item)
{
	if(item == 0)
	{
		Command_Duel(id);
	}
	return PLUGIN_HANDLED;
}
#endif
FinishDuel(winner, looser)
{
	ExecuteForward(g_iForwards[DUEL_FINISH], g_iReturn, winner, looser);
	
	new szWinner[32]; get_entvar(winner, var_netname, szWinner, charsmax(szWinner));
	client_print_color(0, winner, "%s^1 %L", PREFIX, LANG_PLAYER, "DRD_DUEL_WINNER", szWinner);
}
public CBasePlayer_DropPlayerItem_Pre(const this, const pszItemName[])
{
	return g_bDuelStarted ? HC_SUPERCEDE : HC_CONTINUE;
}
public dr_selected_mode(id, mode)
{
	if(g_bDuelStarted && mode != g_iModeDuel)
	{
		g_bDuelStarted = false;
		ResetDuel();
		ExecuteForward(g_iForwards[DUEL_CANCELED], g_iReturn, CType_ModeChanged);
	}
}
ResetDuel()
{
	g_iDuelPlayers[DUELIST_CT] = 0;
	g_iDuelPlayers[DUELIST_T] = 0;
	remove_task(TASK_PRESTART_TIMER);
	remove_task(TASK_TURNCHANGER);
	remove_task(TASK_DUELTIMER);
	RestoreFuncConveyor();
}
StopFuncConveyor()
{
	g_bSavedConveyorInfo = true;
	new ent = -1;
	while((ent = rg_find_ent_by_class(ent, "func_conveyor", true)))
	{
		new Float:speed;
		{
			get_entvar(ent, var_speed);
			set_entvar(ent, var_fuser1, speed);
			set_entvar(ent, var_speed, 0.0);
		}
		new Float:vector[3];
		{
			get_entvar(ent, var_rendercolor, vector);
			set_entvar(ent, var_vuser1, vector);
			set_entvar(ent, var_rendercolor, Float:{0.0, 0.0, 0.0});
		}
	}
}
RestoreFuncConveyor()
{
	if(g_bSavedConveyorInfo)
	{
		new ent = -1;
		while((ent = rg_find_ent_by_class(ent, "func_conveyor", true)))
		{
			new Float:speed;
			{
				get_entvar(ent, var_fuser1, speed);
				set_entvar(ent, var_speed, speed);
			}
			new Float:vector[3];
			{
				get_entvar(ent, var_vuser1, vector);
				set_entvar(ent, var_rendercolor, vector);
			}
		}
	}
}

stock rh_set_user_rendering(index, fx = kRenderFxNone, Float:rgb[3], render = kRenderNormal, Float:amount)
{
	set_entvar(index, var_renderfx, fx);
	set_entvar(index, var_rendercolor, rgb);
	set_entvar(index, var_rendermode, render);
	set_entvar(index, var_renderamt, amount);
}