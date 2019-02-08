#include <amxmodx>
#include <reapi>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Victim"
#define VERSION "Re 0.0.1"
#define AUTHOR "CS Royal Project"

#define AMMO_AMOUNT 100
#define HEALTH_START 600

new g_iModeVictim;
new g_iCurMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	g_iModeVictim = dr_register_mode
	(
		.Name = "DRM_MODE_VICTIM",
		.Hud = "DRM_MODE_INFO_VICTIM",
		.Mark = "victim",
		.RoundDelay = 3,
		.CT_BlockWeapons = 0,
		.TT_BlockWeapons = 0,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 1,
		.Hide = 0
	);
}
//************** Deathrun Mode **************//
public dr_selected_mode(id, mode)
{
	g_iCurMode = mode;

	if(g_iModeVictim == g_iCurMode)
	{
		new players[32], pnum; get_players(players, pnum, "ae", "CT");
		
		new Float: health_multiplier = HEALTH_START.0 * pnum;
		set_entvar(id, var_health, health_multiplier);
		
		for(new i = 0, player; i < pnum; i++)
		{
			player = players[i];
			
			rg_give_weapons(player);
		}
	}
}
rg_give_weapons(player)
{
	rg_give_item(player, "weapon_deagle");
	rg_give_item(player, "weapon_m4a1");
	rg_give_item(player, "weapon_ak47");
	rg_give_item(player, "weapon_awp");
	
	rg_set_user_ammo(player, WEAPON_DEAGLE, AMMO_AMOUNT);
	rg_set_user_ammo(player, WEAPON_M4A1, AMMO_AMOUNT);
	rg_set_user_ammo(player, WEAPON_AK47, AMMO_AMOUNT);
	rg_set_user_ammo(player, WEAPON_AWP, AMMO_AMOUNT);
}