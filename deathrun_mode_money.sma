#include <amxmodx>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Money"
#define VERSION "Re 0.0.1"
#define AUTHOR "CS Royal Project"

#define IsPlayer(%1) (%1 && %1 <= MaxClients)
#define REWARD_AMOUNT 2500

new g_iModeMoney;
new g_iCurMode;
new g_iTerrorist;
new g_iVictim;
new g_iDeathCount;

new HookChain:g_hPlayerKilled;
new HookChain:g_hAddAccount;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	DisableHookChain(g_hPlayerKilled = RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Pre", 0));
	DisableHookChain(g_hAddAccount = RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount_Pre", 0));
	
	g_iModeMoney = dr_register_mode
	(
		.Name = "DRM_MODE_MONEY",
		.Hud = "DRM_MODE_INFO_MONEY",
		.Mark = "money",
		.RoundDelay = 5,
		.CT_BlockWeapons = 1,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 1,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 1,
		.Hide = 0
	);
}
//************** ReGameDll **************//
public CBasePlayer_Killed_Pre(const this, pevAttacker, iGib)
{
	if(this == g_iTerrorist) return HC_CONTINUE;
	
	g_iVictim = this;
	g_iDeathCount++;
	
	if(!IsPlayer(pevAttacker))
	{
		SetHookChainArg(2, ATYPE_INTEGER, g_iTerrorist);
	}
	EnableHookChain(g_hAddAccount);
	
	return HC_CONTINUE;
}
public CBasePlayer_AddAccount_Pre(const this, amount, RewardType:type, bool:bTrackChange)
{
	DisableHookChain(g_hAddAccount);
	
	if(type == RT_ENEMY_KILLED)
	{
		new multiplied_reward = amount * g_iDeathCount;
		new losser[32]; get_entvar(g_iVictim, var_netname, losser, charsmax(losser));
		client_print_color(0, g_iVictim, "^1[^3%l^1] %l", "DRM_MODE_MONEY", "DRM_MODE_CHAT_MONEY", losser, multiplied_reward, g_iDeathCount);
		
		rg_add_account(g_iVictim, -clamp(multiplied_reward, 0, get_member(g_iVictim, m_iAccount)), AS_ADD);
		SetHookChainArg(2, ATYPE_INTEGER, multiplied_reward);
	}
	return HC_CONTINUE;
}
//************** Deathrun Mode **************//
public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeMoney)
	{
		g_iTerrorist = 0;
		DisableHookChain(g_hPlayerKilled);
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeMoney)
	{
		g_iTerrorist = id;
		g_iDeathCount = 0;
		EnableHookChain(g_hPlayerKilled);
	}
}