#include <amxmodx>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Description"
#define VERSION "1.0"
#define AUTHOR "CS Royal Project"

#pragma semicolon 1

new g_szCurMode[32];
new szGameName[32];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	szGameName = "vk.com/cs.royal";
	set_member_game(m_GameDesc, szGameName);
}

public dr_selected_mode(id, mode)
{
	dr_get_mode(g_szCurMode, charsmax(g_szCurMode));
	formatex(szGameName, charsmax(szGameName), "%L", LANG_SERVER, g_szCurMode);
	
	if(!mode) add(szGameName, charsmax(szGameName), "а");
	set_member_game(m_GameDesc, szGameName);
}
