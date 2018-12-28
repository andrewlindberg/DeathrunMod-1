#include <amxmodx>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Description"
#define VERSION "1.0"
#define AUTHOR "CS Royal Project"

#pragma semicolon 1

new g_szCurMode[32];
new g_szGameName[32];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	g_szGameName = "vk.com/cs.royal";
	set_member_game(m_GameDesc, g_szGameName);
}

public dr_selected_mode(id, mode)
{
	dr_get_mode(g_szCurMode, charsmax(g_szCurMode));
	formatex(g_szGameName, charsmax(g_szGameName), "%L", LANG_SERVER, g_szCurMode);
	
	if(!mode) add(g_szGameName, charsmax(g_szGameName), "а");
	set_member_game(m_GameDesc, g_szGameName);
}
