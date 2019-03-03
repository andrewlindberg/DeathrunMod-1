#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Gravity"
#define VERSION "Re 0.0.1"
#define AUTHOR "CS Royal Project"

#define BIT_ADD(%0,%1)			(%0 |= (1 << (%1)))
#define BIT_SUB(%0,%1)			(%0 &= ~(1 << (%1)))
#define BIT_VALID(%0,%1)		(%0 & (1 << (%1)))
#define BIT_NOT_VALID(%0,%1)	(~(%0) & (1 << (%1)))

new g_iCurMode;
new g_iModeDuel;
new g_iBitConnected;
new g_iHasCustomGravity;
new Float: g_fCustomGravity[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	static szWeaponName[MAX_NAME_LENGTH];
	for(new wid = CSW_P228; wid <= CSW_P90; wid++)
	{
		get_weaponname(wid, szWeaponName, charsmax(szWeaponName));
		if(szWeaponName[0])
		{
			RegisterHam(Ham_Item_Deploy, szWeaponName, "@Ham_Item_Deploy_Post", .Post = true);
		}
	}
}

public plugin_cfg()
{
	g_iModeDuel = dr_get_mode_by_mark("duel");
}

public dr_selected_mode(id, mode)
{
	g_iCurMode = mode;
}

public plugin_natives()
{
	register_library("deathrun_modes");
	
	register_native("dr_set_player_gravity", "@native_set_player_gravity");
	register_native("dr_reset_player_gravity", "@native_reset_player_gravity");
}

@native_set_player_gravity(plugin_id, argc)
{
	enum { arg_player_id = 1, arg_gravity };
	
	new player = get_param(arg_player_id);
	
	if(BIT_NOT_VALID(g_iBitConnected, player))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", player);
		return false;
	}
	
	new Float: fGravity = get_param_f(arg_gravity);
	
	if(fGravity < 0.0)
	{
		log_error(AMX_ERR_NATIVE, "[CS] Invalid gravity value %.2f", fGravity);
		return false;
	}
	
	BIT_ADD(g_iHasCustomGravity, player);
	g_fCustomGravity[player] = fGravity;
	executeItemDeploy(player);
	
	return true;
}

@native_reset_player_gravity(plugin_id, argc)
{
	enum { arg_player_id = 1 };
	
	new player = get_param(arg_player_id);
	
	if(BIT_NOT_VALID(g_iBitConnected, player))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", player);
		return false;
	}
	
	if(BIT_NOT_VALID(g_iHasCustomGravity, player))
	{
		return true;
	}
	
	BIT_SUB(g_iHasCustomGravity, player);
	executeItemDeploy(player);
	
	return true;
}

@Ham_Item_Deploy_Post(weapon)
{
	if(g_iCurMode == g_iModeDuel) return HAM_IGNORED;
	
	new player = get_member(weapon, m_pPlayer);
	
	if(!is_user_alive(player)) return HAM_IGNORED;
	
	if(BIT_NOT_VALID(g_iBitConnected, player)) return HAM_IGNORED;
	
	if(BIT_VALID(g_iHasCustomGravity, player))
	{
		set_entvar(player, var_gravity, g_fCustomGravity[player]);
	}
	
	return HAM_IGNORED;
}

public client_putinserver(player)
{
	BIT_ADD(g_iBitConnected, player);
}

public client_remove(player)
{
	BIT_SUB(g_iHasCustomGravity, player);
	BIT_SUB(g_iBitConnected, player);
}

executeItemDeploy(player)
{
	new iActiveItem = get_member(player, m_pActiveItem);
	if(!is_nullent(iActiveItem) && iActiveItem > 0)
	{
		ExecuteHamB(Ham_Item_Deploy, iActiveItem);
	}
}