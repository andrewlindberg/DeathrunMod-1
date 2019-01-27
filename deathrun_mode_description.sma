#include <amxmodx>
#include <reapi>
#include <gamecms5>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Game Description"
#define VERSION "1.0"
#define AUTHOR "CS Royal Project"

#pragma semicolon 1

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
}
public plugin_cfg()
{
	get_cvar_string("cms_url", SiteUrl, charsmax(SiteUrl));
}
public dr_selected_mode(id, mode)
{
	new g_szCurMode[MAX_NAME_LENGTH]; dr_get_mode(g_szCurMode, charsmax(g_szCurMode));
	new g_szAdditionalInfo[MAX_NAME_LENGTH/4]; dr_get_addition_info(g_szAdditionalInfo, charsmax(g_szAdditionalInfo));
	new g_szGameName[MAX_NAME_LENGTH]; formatex(g_szGameName, charsmax(g_szGameName), "%L%s", LANG_SERVER, g_szCurMode, g_szAdditionalInfo);
	
	if(!mode) formatex(g_szGameName, charsmax(g_szGameName), SiteUrl[7]);
	
	set_member_game(m_GameDesc, g_szGameName);
}
