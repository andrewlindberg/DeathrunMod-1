#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <gamecms5>
#include <deathrun_core>
#include <deathrun_modes>
#include <deathrun_duel>
#include <ranking_system>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#include <dhudmessage>
#define client_disconnected client_disconnect
new MaxClients;
#endif

#define PLUGIN "Deathrun: Informer"
#define VERSION "1.0"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define UPDATE_INTERVAL 1.0
//#define DONT_SHOW_FOR_ALIVE

new const DRI_PREFIX[] = "^4[DRI]";

enum (+=100)
{
	TASK_FPSCOUNT = 100,
	TASK_INFORMER,
	TASK_SPEEDOMETER
};

enum _:RankingInfo
{
	RInfo_Exp,
	RInfo_Level,
	RInfo_Prestige[16],
	RInfo_LeftExp,
	RInfo_Percent
};

new g_szCurMode[32], g_iConnected, g_iHudInformer, g_iHudSpecList, g_iHudSpeed, g_iWarmUp;
new g_bConnected[33], g_bAlive[33], g_bInformer[33], g_bSpeed[33], g_bSpecList[33];
new g_iHealth[33], g_iMoney[33], g_iFrames[33], g_iPlayerFps[33];
new g_eRankingData[33][RankingInfo];
new Float:g_fRecord[33], Float:g_fMapRecord;
new g_szMap[32], g_szData[16]; 

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say /informer", "Command_Informer");
	register_clcmd("say /speclist", "Command_SpecList");
	register_clcmd("say /speed", "Command_Speed");
	
	register_event("Money", "Event_Money", "b");
	register_event("Health", "Event_Health", "b");	
	
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Alive_Post", 1);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Alive_Post", 1);
	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink_Pre", 0);
	
	g_iHudInformer = CreateHudSyncObj();
	g_iHudSpeed = CreateHudSyncObj();
	g_iHudSpecList = CreateHudSyncObj();
	
#if AMXX_VERSION_NUM < 183
	MaxClients = get_maxplayers();
#endif
	
	set_task(1.0, "Task_FramesCount", TASK_FPSCOUNT, .flags = "b");
	set_task(UPDATE_INTERVAL, "Task_ShowInfo", TASK_INFORMER, .flags = "b");
	set_task(0.1, "Task_ShowSpeed", TASK_SPEEDOMETER, .flags = "b");
}
public plugin_cfg()
{
	register_dictionary("deathrun_informer.txt");
	
	rh_get_mapname(g_szMap, charsmax(g_szMap), MNT_TRUE);
	if(vaultdata_exists(g_szMap))
	{
		get_vaultdata(g_szMap, g_szData, charsmax(g_szData));
		g_fMapRecord = str_to_float(g_szData);
	}
}
public plugin_end()
{
	float_to_str(g_fMapRecord, g_szData, charsmax(g_szData));
	set_vaultdata(g_szMap, g_szData);
}
public client_putinserver(id)
{
	g_iConnected++;
	g_bConnected[id] = 1;
	new user_setting = cmsapi_get_user_setting(id, "amx_game_informer");
	if(user_setting < 0) user_setting = 1;
	g_bInformer[id] = user_setting;
	user_setting = cmsapi_get_user_setting(id, "amx_game_speclist");
	if(user_setting < 0) user_setting = 1;
	g_bSpecList[id] = user_setting;
	user_setting = cmsapi_get_user_setting(id, "amx_game_speedometer");
	if(user_setting < 0) user_setting = 1;
	g_bSpeed[id] = user_setting;
}
public client_disconnected(id)
{
	g_iConnected--;
	g_bConnected[id] = 0;
	g_bAlive[id] = 0;
	g_bSpeed[id] = 0;
}
/********* Ranking Core *********/
public RankingEvent(event, id, value)
{
	if(event <= Event_ExpUpped)
	{
		g_eRankingData[id][RInfo_Exp] = get_exp(id);
		g_eRankingData[id][RInfo_LeftExp] = get_left_exp(g_eRankingData[id][RInfo_Exp]);
		
		new remaining = get_remaining_exp(g_eRankingData[id][RInfo_Exp]);
		new exp_level = get_exp_level(g_eRankingData[id][RInfo_Level]);
		g_eRankingData[id][RInfo_Percent] = floatround(Float: remaining / Float: exp_level * 100.0);
	}
	
	if(Event_LevelSet <= event <= Event_LevelMax)
	{
		g_eRankingData[id][RInfo_Level] = get_level(id);
	}
	
	if(event >= Event_PrestigeSet)
	{
		get_title_prestige(value, g_eRankingData[id][RInfo_Prestige], charsmax(g_eRankingData[]));
	}
}
/********* Deathrun Core *********/
public dr_warm_up(duration)
{
	g_iWarmUp = duration;
}
/********* Deathrun Mode *********/
public dr_selected_mode(id, mode)
{
	dr_get_mode(g_szCurMode, charsmax(g_szCurMode));
}
/***** Commands *****/
public Command_Informer(id)
{
	new szInformer[4]; g_bInformer[id] = !g_bInformer[id];
	num_to_str(g_bInformer[id], szInformer, charsmax(szInformer));
	cmsapi_set_user_setting(id, "amx_game_informer", szInformer);
	client_print_color(id, print_team_default, "%s^1 %L", DRI_PREFIX, id, "DRI_INFORMER_MSG", id, g_bInformer[id] ? "DRI_ENABLED" : "DRI_DISABLED");
}
public Command_SpecList(id)
{
	new szSpecList[4]; g_bSpecList[id] = !g_bSpecList[id];
	num_to_str(g_bSpecList[id], szSpecList, charsmax(szSpecList));
	cmsapi_set_user_setting(id, "amx_game_speclist", szSpecList);
	client_print_color(id, print_team_default, "%s^1 %L", DRI_PREFIX, id, "DRI_SPECLIST_MSG", id, g_bSpecList[id] ? "DRI_ENABLED" : "DRI_DISABLED");
}
public Command_Speed(id)
{
	new szSpeed[4]; g_bSpeed[id] = !g_bSpeed[id];
	num_to_str(g_bSpeed[id], szSpeed, charsmax(szSpeed));
	cmsapi_set_user_setting(id, "amx_game_speedometer", szSpeed);
	client_print_color(id, print_team_default, "%s^1 %L", DRI_PREFIX, id, "DRI_SPEEDOMETER_MSG", id, g_bSpeed[id] ? "DRI_ENABLED" : "DRI_DISABLED");
}
/***** Events *****/
public Event_Money(id)
{
	g_iMoney[id] = read_data(1);
}
public Event_Health(id)
{
	g_iHealth[id] = get_user_health(id);
}
/***** ReGameDll *****/
public CBasePlayer_Alive_Post(const this)
{
	g_bAlive[this] = bool:is_user_alive(this);
}
public CBasePlayer_PreThink_Pre(const this)
{
	g_iFrames[this]++;
}
/***** Task Frames *****/
public Task_FramesCount()
{
	for(new id = 1; id <= MaxClients; id++)
	{
		g_iPlayerFps[id] = g_iFrames[id];
		g_iFrames[id] = 0;
	}
}
/***** Informer and SpecList *****/
/*
 * Mode: <mode>
 * Timeleft: <time>
 * ??Terrorist: <name>??
 * Alive CT: <alive>/<ct count>
 * All Players: <connected count>/<maxplayers>
 */
public Task_ShowInfo()
{
	new szName[MAX_NAME_LENGTH], szInformer[MAX_FMT_LENGTH], iLen = 0;
	new Hour, Minute, Second; time(Hour, Minute, Second);
	new iAlive, iCount; get_ct(iAlive, iCount);
	new iSpecmode;
	
	if(g_iWarmUp > 0)
	{
		iLen = formatex(szInformer, charsmax(szInformer), "%l: %d^n", "DRI_WARMUP", g_iWarmUp--);
	}
	else
	{
		iLen = formatex(szInformer, charsmax(szInformer), "%l: %l^n", "DRI_MODE", g_szCurMode);
	}

	iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%l^n", "DRI_TIME", Hour, Minute, Second);
	iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%l^n", "DRI_ALIVECT", iAlive, iCount);
	iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%l^n^n", "DRI_ALL_PLAYERS", g_iConnected, MaxClients);
	
	static szSpecInfo[MAX_FMT_LENGTH], szSpecList[MAX_FMT_LENGTH*4];
	for(new id = 1, target; id <= MaxClients; id++)
	{
		if(!g_bConnected[id]) continue;
		
		if(g_bInformer[id])
		{
			iSpecmode = get_entvar(id, var_iuser1);
			target = (iSpecmode == 1  || iSpecmode == 2 || iSpecmode == 4) ? get_entvar(id, var_iuser2) : id;
			
			if(get_exp(target) < 0)
			{
				iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%l", "DRI_RANK_FAIL");
			}
			else
			{
				iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%l^n", "DRI_EXP", g_eRankingData[target][RInfo_Exp], g_eRankingData[target][RInfo_LeftExp]);
				iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%l^n", "DRI_LEVEL", g_eRankingData[target][RInfo_Level], g_eRankingData[target][RInfo_Percent]);
				iLen += formatex(szInformer[iLen], charsmax(szInformer) - iLen, "%l", "DRI_PRESTIGE", g_eRankingData[target][RInfo_Prestige]);
			}
			
			set_hudmessage(55, 245, 55, 0.02, 0.18, 0, .holdtime = UPDATE_INTERVAL, .channel = 3);
			ShowSyncHudMsg(id, g_iHudInformer, szInformer);
		}
		
		if(!g_bAlive[id]) continue;
		
		if(g_iHealth[id] >= 255)
		{
			set_dhudmessage(55, 245, 55, 0.02, 0.90, 0, .holdtime = UPDATE_INTERVAL - 0.05);
			show_dhudmessage(id, "%L", id, "DRI_HEALTH", g_iHealth[id]);
		}
		
		new bool:bShowInfo[33];
		
		iLen = 0;
		
		for(new dead = 1; dead <= MaxClients; dead++)
		{
			if(!g_bConnected[dead] || g_bAlive[dead]) continue;
			
			if(get_entvar(dead, var_iuser2) == id)
			{
				get_entvar(dead, var_netname, szName, charsmax(szName));
				iLen += formatex(szSpecList[iLen], charsmax(szSpecList) - iLen, "^n%s", szName);
				
				bShowInfo[dead] = true;
				bShowInfo[id] = true;
			}
		}
		if(bShowInfo[id])
		{
			#if defined DONT_SHOW_FOR_ALIVE
			bShowInfo[id] = false;
			#endif
			
			get_entvar(id, var_netname, szName, charsmax(szName));
			for(new player = 1; player < MaxClients; player++)
			{
				if(g_bSpecList[player] && bShowInfo[player])
				{
					formatex(szSpecInfo, charsmax(szSpecInfo), "%L^n", player, "DRI_SPECLIST", szName, g_iHealth[id], g_iMoney[id], g_iPlayerFps[id]);
					
					set_hudmessage(245, 245, 245, 0.70, 0.15, 0, .holdtime = UPDATE_INTERVAL, .channel = 3);
					ShowSyncHudMsg(player, g_iHudSpecList, "%s%s", szSpecInfo, szSpecList);
				}
			}
		}
	}
}
/***** Speedometer *****/
public Task_ShowSpeed()
{
	new Float:fSpeed, Float:fVelocity[3], iSpecmode, iPercent, iColor[3];
	for(new id = 1, target; id <= MaxClients; id++)
	{
		if(!g_bSpeed[id]) continue;
		
		iSpecmode = get_entvar(id, var_iuser1);
		target = (iSpecmode == 1  || iSpecmode == 2 || iSpecmode == 4) ? get_entvar(id, var_iuser2) : id;
		get_entvar(target, var_velocity, fVelocity);
		
		fSpeed = vector_length(fVelocity);
		
		if(fSpeed > g_fRecord[target])
		{
			g_fRecord[target] = fSpeed;
		}
		
		if(g_fRecord[target] > g_fMapRecord)
		{
			g_fMapRecord = g_fRecord[target];
		}
		
		iPercent = (g_fRecord[target] > 0.0) ? floatround(fSpeed / g_fRecord[target] * 100.0) : 0;
		
		iColor = { 0, 255, 0 };
		if(iPercent > 90.0)
		{
			iColor = { 255, 0, 0 };
		}
		else if(iPercent > 50.0)
		{
			iColor = { 255, 128, 0 };
		}
		
		set_hudmessage(iColor[0], iColor[1], iColor[2], -1.0, 0.7, .holdtime = 0.1, .channel = 2);
		ShowSyncHudMsg(id, g_iHudSpeed, "%L", id, "DRI_SPEEDOMETER", fSpeed, iPercent, g_fRecord[target], g_fMapRecord);
	}
}
/********* Stocks *********/
stock get_ct(&alive, &count)
{
	count = 0; alive = 0;
	for(new id = 1; id <= MaxClients; id++)
	{
		if(g_bConnected[id] && get_member(id, m_iTeam) == TEAM_CT)
		{
			count++;
			if(g_bAlive[id]) alive++;
		}
	}
}
