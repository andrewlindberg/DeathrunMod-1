#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <gamecms5>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Accelerator bhop"
#define VERSION "Re 0.0.1"
#define AUTHOR "CS Royal Project"

#define BIT_ADD(%0,%1)			(%0 |= (1 << (%1)))
#define BIT_SUB(%0,%1)			(%0 &= ~(1 << (%1)))
#define BIT_VALID(%0,%1)		(%0 & (1 << (%1)))
#define BIT_NOT_VALID(%0,%1)	(~(%0) & (1 << (%1)))

#define MAX_ACCELERATE 2500

new g_iCurMode;
new g_iModeDuel;
new g_iBitConnected;
new g_iHasMaxAccelerate;
new Float: g_fMaxAccelerate[MAX_PLAYERS + 1];
new HookChain: g_hPlayer_Jump;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	g_hPlayer_Jump = RegisterHookChain(RG_CBasePlayer_Jump, "@CBasePlayer_Jump_Post", 1);
}

public plugin_cfg()
{
	g_iModeDuel = dr_get_mode_by_mark("duel");
}

public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeDuel)
	{
		EnableHookChain(g_hPlayer_Jump);
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeDuel)
	{
		DisableHookChain(g_hPlayer_Jump);
	}
}

public plugin_natives()
{
	register_library("deathrun_modes");
	
	register_native("dr_set_player_accelerator", "@native_set_player_accelerator");
	register_native("dr_reset_player_accelerator", "@native_reset_player_accelerator");
}

@native_set_player_accelerator(plugin_id, argc)
{
	enum { arg_player_id = 1, arg_maxaccelerate };
	
	new player = get_param(arg_player_id);
	
	if(BIT_NOT_VALID(g_iBitConnected, player))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", player);
		return false;
	}
	
	new Float: fMaxAccelerate = get_param_f(arg_maxaccelerate);
	
	if(fMaxAccelerate < 0.0)
	{
		log_error(AMX_ERR_NATIVE, "[CS] Invalid maxaccelerate value %.2f", fMaxAccelerate);
		return false;
	}
	
	BIT_ADD(g_iHasMaxAccelerate, player);
	g_fMaxAccelerate[player] = fMaxAccelerate;
	
	return true;
}

@native_reset_player_accelerator(plugin_id, argc)
{
	enum { arg_player_id = 1 };
	
	new player = get_param(arg_player_id);
	
	if(BIT_NOT_VALID(g_iBitConnected, player))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", player);
		return false;
	}
	
	if(BIT_NOT_VALID(g_iHasMaxAccelerate, player))
	{
		return true;
	}
	
	BIT_SUB(g_iHasMaxAccelerate, player);
	
	return true;
}

@CBasePlayer_Jump_Post(const this)
{	
	if(!dr_get_user_bhop(this) || !is_user_alive(this)) return HC_CONTINUE;
	
	if(BIT_NOT_VALID(g_iHasMaxAccelerate, this)) return HC_CONTINUE;
	
	if(!(get_member(this, m_afButtonLast) & IN_DUCK)) return HC_CONTINUE;
	
	new flags = get_entvar(this, var_flags);
	
	if(flags & FL_WATERJUMP || !(flags & FL_ONGROUND) || get_entvar(this, var_waterlevel) >= 2)
	{
		return HC_CONTINUE;
	}
	
	new Float:velocity[3]; get_entvar(this, var_velocity, velocity);
	new Float:fSpeed; fSpeed = vector_length(velocity);
	
	if(fSpeed > g_fMaxAccelerate[this]) return HC_CONTINUE;
	
	velocity[0] *= 1.20;
	velocity[1] *= 1.20;
	
	set_entvar(this, var_velocity, velocity);
	
	return HC_CONTINUE;
}

public client_putinserver(player)
{
	BIT_ADD(g_iBitConnected, player);
}

public client_remove(player)
{
	BIT_SUB(g_iHasMaxAccelerate, player);
	BIT_SUB(g_iBitConnected, player);
}