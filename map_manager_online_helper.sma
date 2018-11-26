#include <amxmodx>
#include <reapi>

#define PLUGIN "MapManager: Online Helper"
#define VERSION "1.0"
#define AUTHOR "vk.com/cs.royal"

new g_nTimeLimit;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	new default_map[32]; get_cvar_string("mapm_default_map", default_map, charsmax(default_map));
	if(!is_map_valid(default_map)) 
	{
		pause("ad"), log_amx("Map %s not found.", default_map);
		return;
	}
	
	g_nTimeLimit = get_cvar_num("mp_timelimit");
	
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", 1);
}
public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	if(ROUND_GAME_RESTART > event < ROUND_GAME_COMMENCE && event != ROUND_END_DRAW) 
	{
		return HC_CONTINUE;
	}
	
	new timelimit = 0;
	if(get_member_game(m_iNumCT) > 1)
	{
		timelimit = g_nTimeLimit;
	}

	set_cvar_num("mp_timelimit", timelimit);
	
	log_amx(" --------- mp_timelimit %d --------- ", timelimit);
	
	return HC_CONTINUE;
}