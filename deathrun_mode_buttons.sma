#include <amxmodx>
#include <hamsandwich>
#include <deathrun_modes>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Buttons"
#define VERSION "Re 1.0.0"
#define AUTHOR "Mistrick"

#define IsPlayer(%1) (%1 && %1 <= MaxClients)

enum { NONE_MODE = 0 };

new const PREFIX[] = "^4[DRM]";

new g_iModeButtons, g_iCurMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	RegisterHam(Ham_Use, "func_button", "Ham_UseButtons_Pre", 0);
	
	g_iModeButtons = dr_register_mode
	(
		.Name = "DRM_MODE_BUTTONS",
		.Hud = "DRM_MODE_INFO_BUTTONS",
		.Mark = "buttons",
		.RoundDelay = 0,
		.CT_BlockWeapons = 0,
		.TT_BlockWeapons = 0,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 0,
		.Bhop = 0,
		.Usp = 1,
		.Hide = 0
	);
}
public dr_selected_mode(id, mode)
{
	g_iCurMode = mode;
}
public Ham_UseButtons_Pre(ent, caller, activator, use_type)
{
	if(g_iCurMode != NONE_MODE || !IsPlayer(activator)) return HAM_IGNORED;
	
	new TeamName:team = get_member(activator, m_iTeam);
	
	if(team != TEAM_TERRORIST) return HAM_IGNORED;

	dr_set_mode(g_iModeButtons, 1, activator);
	show_menu(activator, 0, "^n");
	client_print_color(0, print_team_red, "%s %L", PREFIX, LANG_PLAYER, "DRM_USED_BUTTON", LANG_PLAYER, "DRM_MODE_BUTTONS");
	
	return HAM_IGNORED;
}