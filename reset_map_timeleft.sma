#include <amxmodx>
#include <reapi>

#define PLUGIN "MapManager: Online Helper"
#define VERSION "1.0"
#define AUTHOR "CS Royal Project"

new g_nTimeLimit;
new g_iTimeLimit;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", 1);
	
	g_nTimeLimit = get_cvar_num("mp_timelimit");
	g_iTimeLimit = g_nTimeLimit;
}
public OnConfigsExecuted()
{
	new default_map[32]; get_cvar_string("mapm_default_map", default_map, charsmax(default_map));
	if(!is_map_valid(default_map)) 
	{
		pause("ad");
		log_amx("Map %s not found.", default_map);
	}
}
public RoundEnd_Post()
{
	new iNumCT = get_member_game(m_iNumCT);
	
	if(g_iTimeLimit > 0 && iNumCT > 0) return HC_CONTINUE;
	
	if(!g_iTimeLimit)
	{
		g_iTimeLimit = g_nTimeLimit;
	}
	else g_iTimeLimit = 0;
	
	set_cvar_num("mp_timelimit", g_iTimeLimit);
	
	return HC_CONTINUE;
}