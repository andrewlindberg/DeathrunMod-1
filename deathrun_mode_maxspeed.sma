#include <amxmodx>
#include <reapi>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Max speed"
#define VERSION "Re 0.0.1"
#define AUTHOR "CS Royal Project"

#define BIT_ADD(%0,%1)			(%0 |= (1 << (%1)))
#define BIT_SUB(%0,%1)			(%0 &= ~(1 << (%1)))
#define BIT_VALID(%0,%1)		(%0 & (1 << (%1)))
#define BIT_NOT_VALID(%0,%1)	(~(%0) & (1 << (%1)))

#define DEFAULT_MAXSPEED_T 280
#define DEFAULT_MAXSPEED_CVAR 1000

new g_iCurMode;
new g_iModeDuel;
new g_iBitConnected;
new g_iHasCustomMaxSpeed;
new g_iMaxSpeedIsMultiplier;
new Float: g_fCustomMaxSpeed[MAX_PLAYERS + 1];
new HookChain: g_hResetMaxSpeed;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	g_hResetMaxSpeed = RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "@CBasePlayer_ResetMaxSpeed_Post", .post = true);
}

public plugin_cfg()
{
	g_iModeDuel = dr_get_mode_by_mark("duel");
	
	// Prevents CS from limiting player maxspeeds at 320
	server_cmd("sv_maxspeed %d", DEFAULT_MAXSPEED_CVAR);
}

public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeDuel)
	{
		EnableHookChain(g_hResetMaxSpeed);
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeDuel)
	{
		DisableHookChain(g_hResetMaxSpeed);
	}
}

public plugin_natives()
{
	register_library("deathrun_modes");
	
	register_native("dr_set_player_maxspeed", "@native_set_player_maxspeed");
	register_native("dr_reset_player_maxspeed", "@native_reset_player_maxspeed");
}

@native_set_player_maxspeed(plugin_id, argc)
{
	enum { arg_player_id = 1, arg_maxspeed, arg_multiplier };
	
	new player = get_param(arg_player_id);
	
	if(BIT_NOT_VALID(g_iBitConnected, player))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", player);
		return false;
	}
	
	new Float: flMaxSpeed = get_param_f(arg_maxspeed);
	
	if(flMaxSpeed < 0.0)
	{
		log_error(AMX_ERR_NATIVE, "[CS] Invalid maxspeed value %.2f", flMaxSpeed);
		return false;
	}
	
	new iMultiplier = get_param(arg_multiplier);
	
	BIT_ADD(g_iHasCustomMaxSpeed, player);
	g_fCustomMaxSpeed[player] = flMaxSpeed;
	
	if(iMultiplier)
	{
		BIT_ADD(g_iMaxSpeedIsMultiplier, player);
	}
	else
	{
		BIT_SUB(g_iMaxSpeedIsMultiplier, player);
	}
	
	rg_reset_maxspeed(player);
	
	return true;
}

@native_reset_player_maxspeed(plugin_id, argc)
{
	enum { arg_player_id = 1 };
	
	new player = get_param(arg_player_id);
	
	if(BIT_NOT_VALID(g_iBitConnected, player))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", player);
		return false;
	}
	
	// Player doesn't have custom maxspeed, no need to reset
	if(BIT_NOT_VALID(g_iHasCustomMaxSpeed, player))
	{
		return true;
	}
	
	BIT_SUB(g_iHasCustomMaxSpeed, player);
	rg_reset_maxspeed(player);
	
	return true;
}

@CBasePlayer_ResetMaxSpeed_Post(const this)
{
	// is_user_alive is used to prevent the bug that occurs when using the bit sum
	if(!is_user_alive(this))
		return HC_CONTINUE;
	
	if(get_member(this, m_iTeam) == TEAM_TERRORIST)
		set_entvar(this, var_maxspeed, DEFAULT_MAXSPEED_T.0);
	
	if(BIT_NOT_VALID(g_iHasCustomMaxSpeed, this))
		return HC_CONTINUE;
	
	new Float: flMaxSpeed = get_entvar(this, var_maxspeed);
	
	if(BIT_VALID(g_iMaxSpeedIsMultiplier, this))
		set_entvar(this, var_maxspeed, flMaxSpeed * g_fCustomMaxSpeed[this]);
	else
		set_entvar(this, var_maxspeed, g_fCustomMaxSpeed[this]);
	
	return HC_CONTINUE;
}

public client_putinserver(player)
{
	BIT_ADD(g_iBitConnected, player);
	
	query_client_cvar(player, "cl_forwardspeed", "@maxspeed_cvar_callback");
	query_client_cvar(player, "cl_sidespeed", "@maxspeed_cvar_callback");
	query_client_cvar(player, "cl_backspeed", "@maxspeed_cvar_callback");
}

public client_remove(player)
{
	BIT_SUB(g_iHasCustomMaxSpeed, player);
	BIT_SUB(g_iBitConnected, player);
}

@maxspeed_cvar_callback(id, const cvar[], const value[], const param[])
{
	new iValue = str_to_num(value);
	if(iValue < DEFAULT_MAXSPEED_CVAR)
	{
		client_cmd(id, "%s ^"%d^"", cvar, DEFAULT_MAXSPEED_CVAR);
		
		client_print(id, print_console, "Для коректной работы прироста к скорости бега");
		client_print(id, print_console, "изменено значение квара %s ^"%d^" на ^"%d^"!", cvar, iValue, DEFAULT_MAXSPEED_CVAR);
	}
}