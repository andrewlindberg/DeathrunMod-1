#include <amxmodx>
#include <reapi>
#include <deathrun_duel>

#define PLUGIN  "Deathrun Duel: Reward"
#define VERSION "1.0"
#define AUTHOR  "CS Royal Project"

new g_iDuelPlayers[2];
new g_iMultipliedReward[MAX_CLIENTS + 1];

new HookChain:g_hAddAccount;

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	DisableHookChain(g_hAddAccount = RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount_Pre", 0));
}

public plugin_cfg()
{
	register_dictionary("deathrun_mode_duel.txt");
}

public CBasePlayer_AddAccount_Pre(const pPlayer, amount, RewardType:type, bool:bTrackChange)
{
	if(type != RT_ENEMY_KILLED || (pPlayer != g_iDuelPlayers[DUELIST_T] && pPlayer != g_iDuelPlayers[DUELIST_CT]))
	{
		return HC_CONTINUE;
	}
	
	DisableHookChain(g_hAddAccount);
	
	amount = get_member_game(m_iNumCT) * 10;
	if(++g_iMultipliedReward[pPlayer] > 1)
	{
		amount *= g_iMultipliedReward[pPlayer];
	}
	
	new szWinner[32]; get_entvar(pPlayer, var_netname, szWinner, charsmax(szWinner));
	client_print_color(0, pPlayer, "%s^1 %L", DRD_PREFIX, LANG_PLAYER, "DRD_DUEL_REWARD", szWinner, amount, g_iMultipliedReward[pPlayer]);
	
	SetHookChainArg(2, ATYPE_INTEGER, amount);
	return HC_CONTINUE;
}

public dr_duel_prestart(duelist_t, duelist_ct, duel_timer)
{
	g_iDuelPlayers[DUELIST_T] = duelist_t;
	g_iDuelPlayers[DUELIST_CT] = duelist_ct;
}

public dr_duel_finish(winner, looser)
{
	if(g_iMultipliedReward[looser] > 0)
	{
		g_iMultipliedReward[looser] = 0;
	}
	EnableHookChain(g_hAddAccount);
}