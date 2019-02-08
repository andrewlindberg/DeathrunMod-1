#include <amxmodx>
#include <reapi>
#include <deathrun_duel>

#define PLUGIN  "Deathrun Duel: Reward"
#define VERSION "1.0.1"
#define AUTHOR  "CS Royal Project"

enum _:StatusType {
	SType_Winner,
	SType_Looser
}

new g_iStatusPlayers[StatusType];
new g_iWinStreak[MAX_PLAYERS + 1];

new HookChain:g_hAddAccount;

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	DisableHookChain(g_hAddAccount = RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount_Pre", 0));
}

public CBasePlayer_AddAccount_Pre(const pPlayer, amount, RewardType:type, bool:bTrackChange)
{
	if(type != RT_ENEMY_KILLED || pPlayer != g_iStatusPlayers[SType_Winner]) return HC_CONTINUE;
	
	DisableHookChain(g_hAddAccount);
	
	amount = get_member_game(m_iNumCT) * 10;
	g_iWinStreak[pPlayer]++;
	
	new iWinStreak = g_iWinStreak[pPlayer];
	new looser = g_iStatusPlayers[SType_Looser];
	new szWinner[MAX_NAME_LENGTH]; get_entvar(pPlayer, var_netname, szWinner, charsmax(szWinner));
	
	if(g_iWinStreak[looser] > iWinStreak)
	{
		iWinStreak += g_iWinStreak[looser];
		client_print_color(0, pPlayer, "%s^1 %L", DRD_PREFIX, LANG_PLAYER, "DRD_DUEL_WINSTREAK", szWinner, g_iWinStreak[looser]);
	}
	
	if(iWinStreak > 1)
	{
		amount *= iWinStreak;
	}
	
	client_print_color(0, pPlayer, "%s^1 %L", DRD_PREFIX, LANG_PLAYER, "DRD_DUEL_REWARD", szWinner, amount, iWinStreak);
	SetHookChainArg(2, ATYPE_INTEGER, amount);
	g_iWinStreak[looser] = 0;
	
	return HC_CONTINUE;
}

public dr_duel_finish(winner, looser)
{
	g_iStatusPlayers[SType_Winner] = winner;
	g_iStatusPlayers[SType_Looser] = looser;
	
	EnableHookChain(g_hAddAccount);
}