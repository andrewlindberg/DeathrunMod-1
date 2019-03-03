#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Multi hop"
#define VERSION "Re 0.0.1"
#define AUTHOR "CS Royal Project"

#define BIT_ADD(%0,%1)			(%0 |= (1 << (%1)))
#define BIT_SUB(%0,%1)			(%0 &= ~(1 << (%1)))
#define BIT_VALID(%0,%1)		(%0 & (1 << (%1)))
#define BIT_NOT_VALID(%0,%1)	(~(%0) & (1 << (%1)))

enum _:HopType {
	HType_Amount,
	HType_Max
};

new g_iCurMode;
new g_iModeDuel;
new g_iBitConnected;
new g_iHasMultiHop;
new g_iMultiHop[MAX_PLAYERS + 1][HopType];
new HookChain: g_hPlayer_Jump;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	g_hPlayer_Jump = RegisterHookChain(RG_CBasePlayer_Jump, "@CBasePlayer_Jump_Pre", .post = false);
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
	
	register_native("dr_set_player_multihop", "@native_set_player_multihop");
	register_native("dr_reset_player_multihop", "@native_reset_player_multihop");
}

@native_set_player_multihop(plugin_id, argc)
{
	enum { arg_player_id = 1, arg_maxhop };
	
	new player = get_param(arg_player_id);
	
	if(BIT_NOT_VALID(g_iBitConnected, player))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", player);
		return false;
	}
	
	new MaxHop = get_param(arg_maxhop);
	
	if(MaxHop < 0)
	{
		log_error(AMX_ERR_NATIVE, "[CS] Invalid maxhop value %.2f", MaxHop);
		return false;
	}
	
	BIT_ADD(g_iHasMultiHop, player);
	g_iMultiHop[player][HType_Max] = MaxHop;
	
	return true;
}

@native_reset_player_multihop(plugin_id, argc)
{
	enum { arg_player_id = 1 };
	
	new player = get_param(arg_player_id);
	
	if(BIT_NOT_VALID(g_iBitConnected, player))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", player);
		return false;
	}
	
	if(BIT_NOT_VALID(g_iHasMultiHop, player))
	{
		return true;
	}
	
	BIT_SUB(g_iHasMultiHop, player);

	return true;
}

@CBasePlayer_Jump_Pre(const this)
{
	if(!is_user_alive(this) || BIT_NOT_VALID(g_iBitConnected, this)) return HC_CONTINUE;
	
	if(BIT_VALID(g_iHasMultiHop, this))
	{
		if(get_entvar(this, var_flags) & FL_ONGROUND)
		{
			g_iMultiHop[this][HType_Amount] = 0;
			return HC_CONTINUE;
		}
		
		if((~get_member(this, m_afButtonLast) & IN_JUMP) && ++g_iMultiHop[this][HType_Amount] < g_iMultiHop[this][HType_Max])
		{
			static Float:velocity[3];
			get_entvar(this, var_velocity, velocity);
			velocity[2] = random_float(265.0, 285.0);
			set_entvar(this, var_velocity, velocity);
		}
	}
	
	return HC_CONTINUE;
}

public client_putinserver(player)
{
	BIT_ADD(g_iBitConnected, player);
}

public client_remove(player)
{
	BIT_SUB(g_iHasMultiHop, player);
	BIT_SUB(g_iBitConnected, player);
}