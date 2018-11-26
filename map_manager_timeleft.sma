#include <amxmodx>
#include <reapi>
#include <map_manager>

#define PLUGIN 	"MapManager: TimeLeft"
#define VERSION	"0.1"
#define AUTHOR	"vk.com/cs.royal"

new g_pTimeLimit;
new HookChain:g_hRestartRound;
new HookChain:g_hPlayerSpawn;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	g_pTimeLimit = get_cvar_pointer("mp_timelimit");
	
	EnableHookChain(g_hRestartRound = RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", 1));
	DisableHookChain(g_hPlayerSpawn = RegisterHookChain(RG_CSGameRules_PlayerSpawn, "CSGameRules_PlayerSpawn_Post", 1));
}

public CSGameRules_RestartRound_Post()
{
	if(get_pcvar_num(g_pTimeLimit))
	{
		new iTimeLeft = get_timeleft();
		set_member_game(m_iRoundTime, iTimeLeft);
	}
}

public mapm_prepare_votelist(type)
{
	if(type != VOTE_BY_SCHEDULER_SECOND)
	{
		EnableHookChain(g_hPlayerSpawn);
		DisableHookChain(g_hRestartRound);
		for(new id = 1; id <= MaxClients; id++)
		{
			if(!is_user_alive(id)) continue;
			
			CSGameRules_PlayerSpawn_Post(id);
		}
	}
}

public CSGameRules_PlayerSpawn_Post(const index)
{
	set_member(index, m_iHideHUD, get_member(index, m_iHideHUD) | HIDEHUD_TIMER);
}

public mapm_vote_finished(const map[], type, total_votes)
{
	return_time_hud();
}

public mapm_vote_canceled(type)
{
	return_time_hud();
}

return_time_hud()
{
	EnableHookChain(g_hRestartRound);
	DisableHookChain(g_hPlayerSpawn);
	for(new id = 1; id <= MaxClients; id++)
	{
		if(!is_user_connected(id)) continue;
		
		set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) & ~HIDEHUD_TIMER);
	}
}