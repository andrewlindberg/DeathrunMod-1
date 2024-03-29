#include <amxmodx>
#include <cstrike>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <reapi>
#include <gamecms5>
#include <deathrun_modes>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	#include <dhudmessage>
	#define client_disconnected client_disconnect
#endif

#define PLUGIN "Deathrun: Modes"
#define VERSION "Re 1.0.5"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define DEFAULT_BHOP 1
#define DEFAULT_USP 1
#define TIMER 15

#define IsPlayer(%1) (%1 && %1 <= MaxClients)

enum (+=100)
{
	TASK_SHOWMENU = 100
};

new const PREFIX[] = "^4[DRM]";

new Array:g_aModes, g_iModesNum;

new g_eCurModeInfo[ModeData];
new g_szAdditionalInfo[MAX_NAME_LENGTH];
new g_iCurMode = NONE_MODE;

new g_iPage[MAX_PLAYERS + 1], g_iTimer[MAX_PLAYERS + 1], bool:g_bBhop[MAX_PLAYERS + 1];

new g_fwSelectedMode, g_fwReturn;

new g_hDisableItem;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar("deathrun_modes_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_clcmd("say /bhop", "Command_Bhop");
	
	RegisterHam(Ham_Use, "func_button", "Ham_UseButtons_Pre", 0);
	
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", 1);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", 0);
	RegisterHookChain(RG_CBasePlayer_HasRestrictItem, "CBasePlayer_HasRestrictItem_Pre", 0);
	RegisterHookChain(RG_CBasePlayer_Jump, "CBasePlayer_Jump_Pre", 0);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", 1);
	
	register_menucmd(register_menuid("ModesMenu"), 1023, "ModesMenu_Handler");
	
	g_fwSelectedMode = CreateMultiForward("dr_selected_mode", ET_IGNORE, FP_CELL, FP_CELL);
	g_hDisableItem = menu_makecallback("DisableItem");
	
	g_eCurModeInfo[m_Name] = "DRM_MODE_NONE";
	g_eCurModeInfo[m_Bhop] = DEFAULT_BHOP;
	g_eCurModeInfo[m_Usp] = DEFAULT_USP;
	
	g_szAdditionalInfo = "";
}
public plugin_cfg()
{
	register_dictionary("deathrun_modes.txt");
}
public plugin_natives()
{
	g_aModes = ArrayCreate(ModeData);
	
	register_library("deathrun_modes");
	register_native("dr_register_mode", "native_register_mode");
	register_native("dr_set_mode", "native_set_mode");
	register_native("dr_get_mode", "native_get_mode");
	register_native("dr_set_mode_addinfo", "native_set_mode_addinfo");
	register_native("dr_get_mode_addinfo", "native_get_mode_addinfo");
	register_native("dr_get_mode_by_mark", "native_get_mode_by_mark");
	register_native("dr_get_mode_info", "native_get_mode_info");
	register_native("dr_set_mode_bhop", "native_set_mode_bhop");
	register_native("dr_get_mode_bhop", "native_get_mode_bhop");
	register_native("dr_set_user_bhop", "native_set_user_bhop");
	register_native("dr_get_user_bhop", "native_get_user_bhop");
}
public native_register_mode(plugin, params)
{
	enum {
		arg_name = 1,
		arg_hud,
		arg_mark,
		arg_round_delay,
		arg_ct_block_weapons,
		arg_tt_block_weapons,
		arg_ct_block_buttons,
		arg_tt_block_buttons,
		arg_bhop,
		arg_usp,
		arg_hide
	};
	
	new mode_info[ModeData];
	
	get_string(arg_name, mode_info[m_Name], charsmax(mode_info[m_Name]));
	get_string(arg_hud, mode_info[m_Hud], charsmax(mode_info[m_Hud]));
	get_string(arg_mark, mode_info[m_Mark], charsmax(mode_info[m_Mark]));
	mode_info[m_RoundDelay] = get_param(arg_round_delay);
	mode_info[m_CT_BlockWeapon] = get_param(arg_ct_block_weapons);
	mode_info[m_TT_BlockWeapon] = get_param(arg_tt_block_weapons);
	mode_info[m_CT_BlockButtons] = get_param(arg_ct_block_buttons);
	mode_info[m_TT_BlockButtons] = get_param(arg_tt_block_buttons);
	mode_info[m_Bhop] = get_param(arg_bhop);
	mode_info[m_Usp] = get_param(arg_usp);
	mode_info[m_Hide] = get_param(arg_hide);
	
	ArrayPushArray(g_aModes, mode_info);
	g_iModesNum++;
	
	return g_iModesNum;
}
public native_set_mode(plugin, params)
{
	enum {
		arg_mode_index = 1,
		arg_forward,
		arg_player_id
	};
	
	new mode_index = get_param(arg_mode_index) - 1;
	
	if(mode_index < 0 || mode_index >= g_iModesNum)
	{
		log_error(AMX_ERR_NATIVE, "[DRM] Set mode: wrong mode index! index %d", mode_index + 1);
		return 0;
	}
	
	g_iCurMode = mode_index;
	ArrayGetArray(g_aModes, mode_index, g_eCurModeInfo);
	
	if(g_eCurModeInfo[m_RoundDelay])
	{
		g_eCurModeInfo[m_CurDelay] = g_eCurModeInfo[m_RoundDelay] + 1;
		ArraySetArray(g_aModes, mode_index, g_eCurModeInfo);
	}
	
	if(get_param(arg_forward))
	{
		ExecuteForward(g_fwSelectedMode, g_fwReturn, get_param(arg_player_id), mode_index + 1);
	}
	
	return 1;
}
public native_get_mode(plugin, params)
{
	enum {
		arg_name = 1,
		arg_size
	};
	
	new size = get_param(arg_size);
	
	if(size > 0)
	{
		set_string(arg_name, g_eCurModeInfo[m_Name], size);
	}
	
	return g_iCurMode + 1;
}
public native_set_mode_addinfo(plugin, params)
{
	enum { arg_addition = 1 };
	
	get_string(arg_addition, g_szAdditionalInfo, charsmax(g_szAdditionalInfo));
}
public native_get_mode_addinfo(plugin, params)
{
	enum {
		arg_addition = 1,
		arg_size
	};
	
	new size = get_param(arg_size);
	
	if(size > 0)
	{
		set_string(arg_addition, g_szAdditionalInfo, size);
	}
}
public native_get_mode_by_mark(plugin, params)
{
	enum { arg_mark = 1 };
	
	new mark[16]; get_string(arg_mark, mark, charsmax(mark));
	
	for (new mode_index, mode_info[ModeData]; mode_index < g_iModesNum; mode_index++)
	{
		ArrayGetArray(g_aModes, mode_index, mode_info);
		if(equali(mark, mode_info[m_Mark]))
		{
			return mode_index + 1;
		}
	}
	
	return 0;
}
public native_get_mode_info(plugin, params)
{
	enum {
		arg_mode_index = 1,
		arg_info
	};
	
	new mode_index = get_param(arg_mode_index) - 1;
	
	if(mode_index < 0 || mode_index >= g_iModesNum)
	{
		log_error(AMX_ERR_NATIVE, "[DRM] Get mode info: wrong mode index! index %d", mode_index + 1);
		return 0;
	}
	
	new mode_info[ModeData]; 
	ArrayGetArray(g_aModes, mode_index, mode_info);
	set_array(arg_info, mode_info, ModeData);
	
	return 1;
}
public native_set_mode_bhop(plugin, params)
{
	enum { arg_mode_bhop = 1 };
	
	g_eCurModeInfo[m_Bhop] = get_param(arg_mode_bhop) ? 1 : 0;
}
public native_get_mode_bhop(plugin, params)
{
	return g_eCurModeInfo[m_Bhop];
}
public native_set_user_bhop(plugin, params)
{
	enum {
		arg_player_id = 1,
		arg_bhop
	};
	
	new player = get_param(arg_player_id);
	
	if(player < 1 || player > MaxClients)
	{
		log_error(AMX_ERR_NATIVE, "[DRM] Set user bhop: wrong player index! index %d", player);
		return 0;
	}
	
	g_bBhop[player] = get_param(arg_bhop) ? true : false;
	
	return 1;
}
public bool:native_get_user_bhop(id)
{
	enum { arg_player_id = 1 };
	
	new player = get_param(arg_player_id);
	
	if(player < 1 || player > MaxClients)
	{
		log_error(AMX_ERR_NATIVE, "[DRM] Get user bhop: wrong player index! index %d", player);
		return false;
	}
	
	return g_eCurModeInfo[m_Bhop] && g_bBhop[player];
}
public client_putinserver(id)
{
	new user_setting = cmsapi_get_user_setting(id, "amx_game_bhop");
	if(user_setting < 0) user_setting = 1;
	g_bBhop[id] = bool:user_setting;
}
public client_disconnected(id)
{
	remove_task(id + TASK_SHOWMENU);
}
public Command_Bhop(id)
{
	if(!g_eCurModeInfo[m_Bhop])
	{
		return PLUGIN_CONTINUE;
	}
	
	new szBhop[4]; g_bBhop[id] = !g_bBhop[id];
	num_to_str(_:g_bBhop[id], szBhop, charsmax(szBhop));
	cmsapi_set_user_setting(id, "amx_game_bhop", szBhop);
	client_print_color(id, print_team_default, "%s^1 %L", PREFIX, id, "DRM_BHOP_MSG", id, g_bBhop[id] ? "DRM_ENABLED" : "DRM_DISABLED");
	
	return PLUGIN_CONTINUE;
}
//***** Ham *****//
public Ham_UseButtons_Pre(ent, caller, activator, use_type)
{
	if(!IsPlayer(activator))
	{
		return HAM_IGNORED;
	}
	
	new TeamName:team = get_member(activator, m_iTeam);
	
	if(team == TEAM_TERRORIST && g_eCurModeInfo[m_TT_BlockButtons] || team == TEAM_CT && g_eCurModeInfo[m_CT_BlockButtons])
	{
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}
//***** ReGameDll *****//
public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	if(ROUND_GAME_RESTART > event < ROUND_GAME_COMMENCE) 
	{
		return HC_CONTINUE;
	}
	
	new mode_info[ModeData];
	for (new i = 0; i < g_iModesNum; i++)
	{
		ArrayGetArray(g_aModes, i, mode_info);
		mode_info[m_CurDelay] = 0;
		ArraySetArray(g_aModes, i, mode_info);
	}
	
	return HC_CONTINUE;
}
public CSGameRules_RestartRound_Pre()
{
	g_iCurMode = NONE_MODE;
	g_szAdditionalInfo = "";
	g_eCurModeInfo[m_Name] = "DRM_MODE_NONE";
	g_eCurModeInfo[m_Bhop] = DEFAULT_BHOP;
	g_eCurModeInfo[m_Usp] = DEFAULT_USP;
	g_eCurModeInfo[m_CT_BlockWeapon] = 0;
	g_eCurModeInfo[m_TT_BlockWeapon] = 0;
	g_eCurModeInfo[m_CT_BlockButtons] = 0;
	g_eCurModeInfo[m_TT_BlockButtons] = 0;
	
	ExecuteForward(g_fwSelectedMode, g_fwReturn, 0, g_iCurMode + 1);
	
	new mode_info[ModeData];
	for (new i = 0; i < g_iModesNum; i++)
	{
		ArrayGetArray(g_aModes, i, mode_info);
		if(mode_info[m_CurDelay])
		{
			mode_info[m_CurDelay]--;
			ArraySetArray(g_aModes, i, mode_info);
		}
	}
	for (new id = 1; id <= MaxClients; id++)
	{
		remove_task(id + TASK_SHOWMENU);
	}
}
public CBasePlayer_HasRestrictItem_Pre(const this, ItemID:item, ItemRestType:type)
{
	if(!IsPlayer(this) || g_iCurMode == NONE_MODE)
	{
		return HC_CONTINUE;
	}
	
	new TeamName:team = get_member(this, m_iTeam);
	
	if(team == TEAM_TERRORIST && g_eCurModeInfo[m_TT_BlockWeapon] || team == TEAM_CT && g_eCurModeInfo[m_CT_BlockWeapon])
	{
		SetHookChainReturn(ATYPE_INTEGER, 1);
		return HC_SUPERCEDE;
	}
	
	return HC_CONTINUE;
}
public CBasePlayer_Jump_Pre(const this)
{	
	if(!g_eCurModeInfo[m_Bhop] || !g_bBhop[this])
	{
		return HC_CONTINUE;
	}
	
	new flags = get_entvar(this, var_flags);
	
	if(flags & FL_WATERJUMP || !(flags & FL_ONGROUND) || get_entvar(this, var_waterlevel) >= 2)
	{
		return HC_CONTINUE;
	}

	new Float:velocity[3]; get_entvar(this, var_velocity, velocity);
	velocity[2] = 250.0; set_entvar(this, var_velocity, velocity);
	
	set_entvar(this, var_gaitsequence, 6);
	set_entvar(this, var_fuser2, 0);
	
	return HC_CONTINUE;
}
public CBasePlayer_Spawn_Post(const this)
{
	if(!is_user_alive(this))
	{
		return HC_CONTINUE;
	}
	
	rg_set_entity_rendering(this);
	
	new TeamName:team = get_member(this, m_iTeam);
	rg_remove_items_by_slot(this, PISTOL_SLOT);
	
	if(g_eCurModeInfo[m_Usp] && team == TEAM_CT)
	{
		rg_give_item(this, "weapon_usp");
		rg_set_user_bpammo(this, WEAPON_USP, 100);
	}
	
	if(g_iCurMode != NONE_MODE || team != TEAM_TERRORIST)
	{
		return HC_CONTINUE;
	}
	
	g_iTimer[this] = TIMER + 1;
	g_iPage[this] = 0;
	Task_MenuTimer(this + TASK_SHOWMENU);
	
	return HC_CONTINUE;
}
public Show_ModesMenu(id)
{
	new text[80]; formatex(text, charsmax(text), "%L^n^n%L ", id, "DRM_MENU_SELECT_MODE", id, "DRM_MENU_TIMELEFT", g_iTimer[id]);
	new menu = menu_create(text, "ModesMenu_Handler");
	
	new mode_info[ModeData], i;
	for (new item[2], len; i < g_iModesNum; i++)
	{
		ArrayGetArray(g_aModes, i, mode_info);
		
		if(mode_info[m_Hide]) continue;
		
		len = formatex(text, charsmax(text), "%L", id, mode_info[m_Name]);
		if(mode_info[m_CurDelay] > 0)
		{
			formatex(text[len], charsmax(text) - len, "[\r%d\d]", mode_info[m_CurDelay]);
		}
		
		item[0] = i;
		
		menu_additem(menu, text, item, 0, mode_info[m_CurDelay] ? g_hDisableItem : -1);
	}
	
	if(i > 9)
	{
		formatex(text, charsmax(text), "%L", id, "DRM_MENU_BACK");
		menu_setprop(menu, MPROP_BACKNAME, text);
		formatex(text, charsmax(text), "%L", id, "DRM_MENU_NEXT");
		menu_setprop(menu, MPROP_NEXTNAME, text);
		
		menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	}
	else
	{
		menu_setprop(menu, MPROP_PERPAGE, 0);
	}
	
	new _menu, _newmenu, _menupage;
	player_menu_info(id, _menu, _newmenu, _menupage);
	
	new page = (_newmenu != -1 && menu_items(menu) == menu_items(_newmenu)) ? _menupage : 0;
	menu_display(id, menu, page);
	
	return PLUGIN_HANDLED;
}
public ModesMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT || g_iCurMode != NONE_MODE || get_member(id, m_iTeam) != CS_TEAM_T)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new info[2], stuff;
	menu_item_getinfo(menu, item, stuff, info, charsmax(info), _, _, stuff);
	
	new mode = info[0];
	g_iCurMode = mode;
	
	ArrayGetArray(g_aModes, mode, g_eCurModeInfo);
	
	if(g_eCurModeInfo[m_RoundDelay])
	{
		g_eCurModeInfo[m_CurDelay] = g_eCurModeInfo[m_RoundDelay] + 1;
		ArraySetArray(g_aModes, mode, g_eCurModeInfo);
	}
	
	CheckUsp();
	
	remove_task(id + TASK_SHOWMENU);
	ExecuteForward(g_fwSelectedMode, g_fwReturn, id, mode + 1);
	
	if(g_eCurModeInfo[m_Hud][0])
	{
		set_dhudmessage(random(200) + 55, random(200) + 55, random(200) + 55, 0.01, 0.50, 0, 0.00, 3.00, 0.20, 3.00);
		show_dhudmessage(0, "%L^n%L", LANG_PLAYER, "DRM_SELECTED_MODE", LANG_PLAYER, g_eCurModeInfo[m_Name], LANG_PLAYER, g_eCurModeInfo[m_Hud]);
	}
	
	client_print_color(0, print_team_red, "%s ^3%L", PREFIX, LANG_PLAYER, "DRM_SELECTED_MODE", LANG_PLAYER, g_eCurModeInfo[m_Name]);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
public DisableItem(id, menu, item)
{
	return ITEM_DISABLED;
}
public Task_MenuTimer(id)
{
	id -= TASK_SHOWMENU;
	
	if(g_iCurMode != NONE_MODE || !is_user_alive(id) || get_member(id, m_iTeam) != CS_TEAM_T)
	{
		show_menu(id, 0, "^n"); return;
	}

	if(--g_iTimer[id] <= 0)
	{
		show_menu(id, 0, "^n");
		
		new mode;
		
		if(!is_all_modes_blocked())
		{
			do {
				mode = random(g_iModesNum);
				ArrayGetArray(g_aModes, mode, g_eCurModeInfo);
			} while(g_eCurModeInfo[m_CurDelay] || g_eCurModeInfo[m_Hide]);
		}
		else
		{
			do {
				mode = random(g_iModesNum);
				ArrayGetArray(g_aModes, mode, g_eCurModeInfo);
			} while (g_eCurModeInfo[m_Hide]);
		}
		
		g_iCurMode = mode;
		
		if(g_eCurModeInfo[m_RoundDelay])
		{
			g_eCurModeInfo[m_CurDelay] = g_eCurModeInfo[m_RoundDelay] + 1;
			ArraySetArray(g_aModes, mode, g_eCurModeInfo);
		}
		
		CheckUsp();
		
		ExecuteForward(g_fwSelectedMode, g_fwReturn, id, mode + 1);
		
		if(g_eCurModeInfo[m_Hud][0])
		{
			set_dhudmessage(random(200) + 55, random(200) + 55, random(200) + 55, 0.01, 0.50, 0, 0.00, 3.00, 0.20, 3.00);
			show_dhudmessage(0, "%L^n%L", LANG_PLAYER, "DRM_RANDOM_MODE", LANG_PLAYER, g_eCurModeInfo[m_Name], LANG_PLAYER, g_eCurModeInfo[m_Hud]);
		}
		
		client_print_color(0, print_team_red, "%s ^3%L", PREFIX, LANG_PLAYER, "DRM_RANDOM_MODE", LANG_PLAYER, g_eCurModeInfo[m_Name]);
	}
	else
	{
		Show_ModesMenu(id);
		set_task(1.0, "Task_MenuTimer", id + TASK_SHOWMENU);
	}
}
CheckUsp()
{
#if DEFAULT_USP < 1
	if(g_eCurModeInfo[m_Usp])
	{
		new player, players[32], pnum; get_players(players, pnum, "ae", "CT");
		for (new i = 0; i < pnum; i++)
		{
			player = players[i];
			rg_give_item(player, "weapon_usp");
			rg_set_user_bpammo(player, WEAPON_USP, 100);
		}
	}
#else
	if(!g_eCurModeInfo[m_Usp])
	{
		new player, players[32], pnum; get_players(players, pnum, "ae", "CT");
		for (new i = 0; i < pnum; i++)
		{
			player = players[i];
			rg_remove_items_by_slot(player, PISTOL_SLOT);
		}
	}
#endif
}
// ********** //
bool:is_all_modes_blocked()
{
	new mode_info[ModeData];
	for (new i; i < g_iModesNum; i++)
	{
		ArrayGetArray(g_aModes, i, mode_info);
		if(!mode_info[m_CurDelay] && !mode_info[m_Hide]) return false;
	}
	return true;
}
