#include <amxmodx>
#include <fun>
#include <engine>
#include <hamsandwich>
#include <deathrun_modes>
#include <deathrun_duel>
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

#define IsPlayer(%1) (%1 && %1 <= MaxClients)
#define SHOW_MENU_FOR_LAST_CT

#define PRESTART_TIME 10
#define FIRE_TIME 8
#define DUEL_TIME 60
#define MAX_DISTANCE 1500
#define MIN_DISTANCE 200
#define SPEED_VECTOR 150

new const SPAWNS_DIR[] = "deathrun_duel";

enum (+=100)
{
	TASK_TURNCHANGER = 548679,
	TASK_PRESTART_TIMER,
	TASK_DUELTIMER,
	TASK_MISSED,
	TASK_FAST
};

enum _:SoundType
{
	SType_Fight,
	SType_Attack,
	SType_Missed,
	SType_Coward,
	SType_Fast,
	SType_Hit1,
	SType_Hit2,
	SType_Hit3,
	SType_Hit4
};

enum _:ForwardType
{
	FType_PreStart,
	FType_Start,
	FType_Finish,
	FType_Canceled
};

new g_iModeDuel;
new g_iCurMode;
new g_iCurDuel;
new g_iDuelPlayers[2];
new g_iDuelWeapon[2];
new g_iDuelTurnTimer;
new g_iDuelTimer;
new g_iCurTurn;

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

new g_iForwards[ForwardType];
new g_iReturn;
new g_bSavedConveyorInfo;
new HookChain:g_hTakeDamage;
new HookChain:g_hPreThink;
new HookChain:g_hDropPlayerItem;

new g_szWeaponName[][] =
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

new g_szSounds[SoundType][] =
{
	"sound/royal/mode/duel/duel_fight.wav",
	"sound/royal/mode/duel/duel_attack.wav",
	"sound/royal/mode/duel/duel_missed.wav",
	"sound/royal/mode/duel/duel_coward.wav",
	"sound/royal/mode/duel/duel_fast.wav",
	"sound/royal/mode/duel/duel_hit1.wav",
	"sound/royal/mode/duel/duel_hit2.wav",
	"sound/royal/mode/duel/duel_hit3.wav",
	"sound/royal/mode/duel/duel_hit4.wav"
};

public plugin_precache()
{
	for(new i = 0; i < sizeof(g_szSounds); i++)
	{
		precache_sound(g_szSounds[i][6]);
	}
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd("say /dd", "Command_Duel");
	register_clcmd("say /duel", "Command_Duel");
	register_clcmd("duel_spawns", "Command_DuelSpawn", ADMIN_CFG);
	
	for(new i = 1; i < sizeof(g_szWeaponName); i++)
	{
		RegisterHam(Ham_Weapon_PrimaryAttack, g_szWeaponName[i], "Ham_WeaponPrimaryAttack_Post", 1);
	}
	
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_usp", "Ham_WeaponSecondaryAttack_Pre", 0);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_glock18", "Ham_WeaponSecondaryAttack_Pre", 0);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_awp", "Ham_WeaponSecondaryAttack_Pre", 0);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_scout", "Ham_WeaponSecondaryAttack_Pre", 0);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_famas", "Ham_WeaponSecondaryAttack_Pre", 0);
	
	register_touch("trigger_push", "player", "Engine_DuelTouch");
	register_touch("trigger_teleport", "player", "Engine_DuelTouch");
	
	RegisterHookChain(RG_CSGameRules_PlayerKilled, "CSGameRules_PlayerKilled_Pre", 0);
	DisableHookChain(g_hTakeDamage = RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", 0));
	DisableHookChain(g_hDropPlayerItem = RegisterHookChain(RG_CBasePlayer_DropPlayerItem, "CBasePlayer_DropPlayerItem_Pre", 0));
	DisableHookChain(g_hPreThink = RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink_Post", 1));
	
	g_iForwards[FType_PreStart] = CreateMultiForward("dr_duel_prestart", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_iForwards[FType_Start] = CreateMultiForward("dr_duel_start", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_iForwards[FType_Finish] = CreateMultiForward("dr_duel_finish", ET_IGNORE, FP_CELL, FP_CELL);
	g_iForwards[FType_Canceled] = CreateMultiForward("dr_duel_canceled", ET_IGNORE, FP_CELL);
	
	g_iModeDuel = dr_register_mode
	(
		.Name = "DRM_MODE_DUEL",
		.Hud = "",
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
	
	#if defined SHOW_MENU_FOR_LAST_CT
	register_menucmd(register_menuid("DuelOfferMenu"), 1023, "DuelOffer_Handler");
	#endif
}
public plugin_cfg()
{
	register_dictionary("deathrun_mode_duel.txt");
	LoadSpawns();
}
public plugin_natives()
{
	register_library("deathrun_duel");
	register_native("dr_get_duel", "native_get_duel");
}
public native_get_duel(plugin_id, argc)
{
	enum { arg_name = 1, arg_size };
	
	new size = get_param(arg_size);
	
	if(size > 0)
	{
		set_string(arg_name, g_szWeaponName[g_iCurDuel][7], size);
	}
	
	return g_iCurDuel;
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
	xs_vec_sub(g_fDuelSpawnOrigins[DUELIST_T], g_fDuelSpawnOrigins[DUELIST_CT], fVector);
	xs_vec_normalize(fVector, fVector);
	vector_to_angle(fVector, g_fDuelSpawnAngles[DUELIST_CT]);
	xs_vec_mul_scalar(fVector, -1.0, fVector);
	vector_to_angle(fVector, g_fDuelSpawnAngles[DUELIST_T]);
}
public client_disconnected(id)
{
	if(g_iCurMode == g_iModeDuel && (id == g_iDuelPlayers[DUELIST_CT] || id == g_iDuelPlayers[DUELIST_T]))
	{
		ResetDuel();
		ExecuteForward(g_iForwards[FType_Canceled], g_iReturn, CType_PlayerDisconneced);
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
	new text[64]; formatex(text, charsmax(text), "%L", id, "DRD_DUEL_SPAWN");
	new menu = menu_create(text, "DuelSpawnControl_Handler");
	formatex(text, charsmax(text), "%L", id, "DRD_SPAWN_SET_CT");
	menu_additem(menu, text);
	formatex(text, charsmax(text), "%L", id, "DRD_SPAWN_SET_T");
	menu_additem(menu, text);
	formatex(text, charsmax(text), "%L", id, g_bShowSpawns ? "DRD_DUEL_SPAWN_TYPE_HIDE" : "DRD_DUEL_SPAWN_TYPE_SHOW");
	menu_additem(menu, text);
	formatex(text, charsmax(text), "%L^n", id, "DRD_DUEL_SPAWN_SAVE");
	menu_additem(menu, text);
	formatex(text, charsmax(text), "%L", id, get_user_noclip(id) ? "DRD_DUEL_SPAWN_NOCLIP_ON" : "DRD_DUEL_SPAWN_NOCLIP_OFF");
	menu_additem(menu, text);
	formatex(text, charsmax(text), "%L", id, "DRD_DUEL_EXIT");
	menu_setprop(menu, MPROP_EXITNAME, text);
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
		client_print_color(id, print_team_default, "%s^1 %L", DRD_PREFIX, id, "DRD_SET_SPAWNS");
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
		client_print_color(id, print_team_default, "%s^1 %L", DRD_PREFIX, id, "DRD_SPAWNS_SAVED");
	}
}
public Command_Duel(id)
{
	if(g_iCurMode == g_iModeDuel || !is_user_alive(id) || get_member(id, m_iTeam) != TEAM_CT) return PLUGIN_HANDLED;
	
	new players[32], pnum; get_players(players, pnum, "ae", "CT");
	if(pnum > 1) return PLUGIN_HANDLED;
	
	g_iDuelPlayers[DUELIST_CT] = id;
	
	get_players(players, pnum, "ae", "TERRORIST");
	if(pnum < 1) return PLUGIN_HANDLED;
	
	new text[64]; formatex(text, charsmax(text), "%L", id, "DRD_DUEL_CHOOSE");
	new menu = menu_create(text, "DuelType_Handler");
	
	for(new i; i < sizeof(g_szWeaponName); i++)
	{
		menu_additem(menu, g_szWeaponName[i][7]);
	}
	
	formatex(text, charsmax(text), "%L", id, "DRD_DUEL_BACK");
	menu_setprop(menu, MPROP_BACKNAME, text);
	formatex(text, charsmax(text), "%L", id, "DRD_DUEL_NEXT");
	menu_setprop(menu, MPROP_NEXTNAME, text);
	formatex(text, charsmax(text), "%L", id, "DRD_DUEL_EXIT");
	menu_setprop(menu, MPROP_EXITNAME, text);
	menu_display(id, menu);
	
	return PLUGIN_HANDLED;
}
public DuelType_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new players[32], pnum; get_players(players, pnum, "ae", "CT");
	if(pnum > 1) return PLUGIN_HANDLED;
	
	get_players(players, pnum, "ae", "TERRORIST");
	if(pnum < 1) return PLUGIN_HANDLED;
	
	g_iDuelPlayers[DUELIST_T] = players[0];
	
	if(!is_user_alive(id) || !is_user_alive(g_iDuelPlayers[DUELIST_T]) || get_member(id, m_iTeam) != TEAM_CT) return PLUGIN_HANDLED;
	
	dr_set_mode(g_iModeDuel, 1);
	
	g_iCurDuel = item;
	
	DuelPreStart();
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
DuelPreStart()
{
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
	
	ExecuteForward(g_iForwards[FType_PreStart], g_iReturn, g_iDuelPlayers[DUELIST_T], g_iDuelPlayers[DUELIST_CT], g_iDuelTimer);
	
	client_print_color(0, print_team_default, "%s^1 %L", DRD_PREFIX, LANG_PLAYER, "DRD_DUEL_START_TIME", PRESTART_TIME);
}
public Task_PreStartTimer()
{
	if(g_iCurMode != g_iModeDuel) return;
	
	if(--g_iDuelTimer <= 0)
	{
		DuelStartForward(g_iCurDuel);
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
	rg_send_audio(0, g_szSounds[SType_Fight], PITCH_NORM);
	ExecuteForward(g_iForwards[FType_Start], g_iReturn, g_iDuelPlayers[DUELIST_T], g_iDuelPlayers[DUELIST_CT], g_iDuelTimer);
}
public Task_DuelTimer()
{
	if(g_iCurMode != g_iModeDuel) return;
	
	if(--g_iDuelTimer <= 0)
	{
		ExecuteHam(Ham_Killed, g_iDuelPlayers[DUELIST_CT], g_iDuelPlayers[DUELIST_CT], 0);
		ExecuteHam(Ham_Killed, g_iDuelPlayers[DUELIST_T], g_iDuelPlayers[DUELIST_T], 0);
		
		ExecuteForward(g_iForwards[FType_Canceled], g_iReturn, CType_TimeOver);
		ResetDuel();
		
		client_print_color(0, print_team_default, "%s^1 %L", DRD_PREFIX, LANG_PLAYER, "DRD_TIME_OVER");
	}
	else
	{
		client_cmd(0, "spk buttons/lightswitch2");
		set_dhudmessage(
			.red = floatround(g_fColors[g_iCurTurn][0]), 
			.green = floatround(g_fColors[g_iCurTurn][1]), 
			.blue = floatround(g_fColors[g_iCurTurn][2]), 
			.x = -1.0,
			.y = 0.20, 
			.effects = 0, 
			.fxtime = 6.0, 
			.holdtime = 0.8, 
			.fadeintime = 0.1, 
			.fadeouttime = 0.2
		);
		show_dhudmessage(0, "%L", LANG_SERVER, "DRD_DUEL_END_TIME", g_iDuelTimer);
		set_task(1.0, "Task_DuelTimer", TASK_DUELTIMER);
	}
}
PrepareForDuel(player)
{
	rg_remove_all_items(g_iDuelPlayers[player]);
	rg_set_user_armor(g_iDuelPlayers[player], 0, ARMOR_NONE);
	set_entvar(g_iDuelPlayers[player], var_health, 100.0);
	set_entvar(g_iDuelPlayers[player], var_gravity, 1.0);
	rg_set_entity_rendering(g_iDuelPlayers[player], kRenderFxGlowShell, g_fColors[player], kRenderNormal, 20.0);
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
	g_iDuelWeapon[DUELIST_CT] = rg_give_item(g_iDuelPlayers[DUELIST_CT], g_szWeaponName[type]);
	g_iDuelWeapon[DUELIST_T] = rg_give_item(g_iDuelPlayers[DUELIST_T], g_szWeaponName[type]);
	
	new PrimaryAmmoType = get_member(g_iDuelWeapon[DUELIST_CT], m_Weapon_iPrimaryAmmoType);
	
	if(PrimaryAmmoType > 0)
	{
		if(is_entity(g_iDuelWeapon[DUELIST_CT]) && is_entity(g_iDuelWeapon[DUELIST_T]))
		{
			new WeaponIdType:WeaponId = rg_get_weapon_info(g_szWeaponName[type], WI_ID);
			rg_set_user_ammo(g_iDuelPlayers[DUELIST_CT], WeaponId, 1);
			rg_set_user_ammo(g_iDuelPlayers[DUELIST_T], WeaponId, 0);
		}
		
		g_iDuelTurnTimer = FIRE_TIME;
		g_iCurTurn = DUELIST_CT;
		set_task(1.0, "Task_ChangeTurn", TASK_TURNCHANGER, .flags = "b");
	}
	else
	{
		DisableHookChain(g_hPreThink);
	}
}
public Task_ChangeTurn()
{
	if(g_iCurMode != g_iModeDuel) return;
	
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
	
	/* if(g_bLoadedSpawns)
	{
		CheckPlayersDistance();
	} */
	
	g_iDuelTurnTimer--;
}
stock CheckPlayersDistance()
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
	if(g_iCurMode != g_iModeDuel || (weapon != g_iDuelWeapon[DUELIST_CT] && weapon != g_iDuelWeapon[DUELIST_T])) return HAM_IGNORED;
	
	new player = get_member(weapon, m_pPlayer);
	
	if(player == g_iDuelPlayers[g_iCurTurn])
	{
		rg_send_audio(0, g_szSounds[SType_Attack], PITCH_NORM);
		
		if(!task_exists(TASK_MISSED))
		{
			set_task(1.0, "Task_SendMissed", TASK_MISSED);
		}
		
		remove_task(TASK_FAST);
		set_task(FIRE_TIME.0 / 2, "Task_SendFast", TASK_FAST);
		
		g_iDuelTurnTimer = FIRE_TIME;
		g_iCurTurn ^= 1;
		
		new WeaponIdType:WeaponId = rg_get_weapon_info(g_szWeaponName[g_iCurDuel], WI_ID);
		rg_set_user_ammo(g_iDuelPlayers[g_iCurTurn], WeaponId, 1);
	}
	
	return HAM_IGNORED;
}
public Ham_WeaponSecondaryAttack_Pre(weapon)
{
	return g_iCurMode == g_iModeDuel ? HAM_SUPERCEDE : HAM_IGNORED;
}
public Engine_DuelTouch(ent, toucher)
{
	return g_iCurMode == g_iModeDuel ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}
public CSGameRules_PlayerKilled_Pre(const victim, const killer, const inflictor)
{
	if(g_iCurMode == g_iModeDuel && (victim == g_iDuelPlayers[DUELIST_CT] || victim == g_iDuelPlayers[DUELIST_T]))
	{
		if(killer != victim && (killer == g_iDuelPlayers[DUELIST_CT] || killer == g_iDuelPlayers[DUELIST_T]))
		{
			FinishDuel(killer, victim);
		}
		else
		{
			ExecuteForward(g_iForwards[FType_Canceled], g_iReturn, CType_PlayerDied);
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
		return PLUGIN_HANDLED;
	}
	
	rg_send_audio(0, g_szSounds[SType_Coward], PITCH_NORM);
	return PLUGIN_HANDLED;
}
#endif
FinishDuel(winner, looser)
{
	ExecuteForward(g_iForwards[FType_Finish], g_iReturn, winner, looser);
	
	new szWinner[32]; get_entvar(winner, var_netname, szWinner, charsmax(szWinner));
	client_print_color(0, winner, "%s^1 %L", DRD_PREFIX, LANG_PLAYER, "DRD_DUEL_WINNER", szWinner);
}
public CBasePlayer_TakeDamage_Pre(const this, pevInflictor, pevAttacker, Float:flDamage, bitsDamageType)
{
	if(this == pevAttacker) return HC_CONTINUE;
	
	if(!IsPlayer(pevAttacker) || (pevAttacker != g_iDuelPlayers[DUELIST_CT] && pevAttacker != g_iDuelPlayers[DUELIST_T]))
	{
		SetHookChainReturn(ATYPE_INTEGER, 0);
		return HC_SUPERCEDE;
	}
	
	if(this == g_iDuelPlayers[DUELIST_CT] || this == g_iDuelPlayers[DUELIST_T])
	{
		set_task(0.2, "Task_SendHit", this);
	}
	
	return HC_CONTINUE;
}
public CBasePlayer_DropPlayerItem_Pre(const this, const pszItemName[])
{
	SetHookChainReturn(ATYPE_INTEGER, 0);
	return HC_SUPERCEDE;
}
public CBasePlayer_PreThink_Post(const this)
{
	if(!g_bLoadedSpawns) return HC_CONTINUE;
	
	if(this != g_iDuelPlayers[DUELIST_CT] && this != g_iDuelPlayers[DUELIST_T]) return HC_CONTINUE;
	
	if(!is_user_alive(this)) return HC_CONTINUE;
	
	new enemy = g_iDuelPlayers[DUELIST_T]; 
	if(this == g_iDuelPlayers[DUELIST_T])
	{
		enemy = g_iDuelPlayers[DUELIST_CT];
	}
	
	if(!is_user_alive(enemy)) return HC_CONTINUE;
	
	static Float:velocity[3];
	
	if(get_entity_distance(enemy, this) < g_iMinDistance && rh_get_speed_vector2(enemy, this, SPEED_VECTOR.0, velocity) 
	|| get_entity_distance(this, enemy) > MAX_DISTANCE && rh_get_speed_vector2(this, enemy, SPEED_VECTOR.0, velocity))
	{
		set_entvar(this, var_velocity, velocity);
	}
	
	return HC_CONTINUE;
}
public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeDuel)
	{
		ResetDuel();
		DisableHookChain(g_hTakeDamage);
		ExecuteForward(g_iForwards[FType_Canceled], g_iReturn, CType_ModeChanged);
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeDuel)
	{
		EnableHookChain(g_hTakeDamage);
		EnableHookChain(g_hDropPlayerItem);
		EnableHookChain(g_hPreThink);
	}
}
ResetDuel()
{
	g_iDuelPlayers[DUELIST_CT] = g_iDuelPlayers[DUELIST_T] = 0;
	
	DisableHookChain(g_hDropPlayerItem);
	DisableHookChain(g_hPreThink);
	
	remove_task(TASK_PRESTART_TIMER);
	remove_task(TASK_TURNCHANGER);
	remove_task(TASK_DUELTIMER);
	remove_task(TASK_FAST);
	RestoreFuncConveyor();
}
public Task_SendHit(id)
{
	remove_task(TASK_MISSED);
	rh_emit_sound2(id, 0, CHAN_WEAPON, g_szSounds[random_num(SType_Hit1, SType_Hit4)][6], random_float(0.5, VOL_NORM), ATTN_NORM, .pitch = PITCH_NORM);
}
public Task_SendMissed()
{
	rg_send_audio(0, g_szSounds[SType_Missed], PITCH_NORM);
}
public Task_SendFast()
{
	rg_send_audio(0, g_szSounds[SType_Fast], PITCH_NORM);
}
StopFuncConveyor()
{
	g_bSavedConveyorInfo = true;
	new ent = -1;
	while((ent = rg_find_ent_by_class(ent, "func_conveyor")))
	{
		new Float:speed; get_entvar(ent, var_speed, speed);
		set_entvar(ent, var_fuser1, speed);
		set_entvar(ent, var_speed, 0.0);
		new Float:vector[3]; get_entvar(ent, var_rendercolor, vector);
		set_entvar(ent, var_vuser1, vector);
		set_entvar(ent, var_rendercolor, Float:{0.0, 0.0, 0.0});
	}
}
RestoreFuncConveyor()
{
	if(g_bSavedConveyorInfo)
	{
		new ent = -1;
		while((ent = rg_find_ent_by_class(ent, "func_conveyor")))
		{
			new Float:speed; get_entvar(ent, var_fuser1, speed);
			set_entvar(ent, var_speed, speed);
			new Float:vector[3]; get_entvar(ent, var_vuser1, vector);
			set_entvar(ent, var_rendercolor, vector);
		}
	}
}
stock rh_get_speed_vector2(ent1, ent2, Float:speed, Float:new_velocity[3])
{
	if(!is_entity(ent1) || !is_entity(ent2))
	{
		return 0;
	}
	
	static Float:origin[2][3];
	get_entvar(ent1, var_origin, origin[0]);
	get_entvar(ent2, var_origin, origin[1]);
	
	new_velocity[0] = origin[1][0] - origin[0][0];
	new_velocity[1] = origin[1][1] - origin[0][1];
	new_velocity[2] = origin[1][2] - origin[0][2];
	new Float:fnum = floatsqroot(speed * speed / (new_velocity[0] * new_velocity[0] + new_velocity[1] * new_velocity[1] + new_velocity[2] * new_velocity[2]));
	new_velocity[0] *= fnum;
	new_velocity[1] *= fnum;
	new_velocity[2] *= fnum;
	
	return 1;
}