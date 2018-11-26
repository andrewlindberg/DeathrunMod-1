#include <amxmodx>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Money"
#define VERSION "Re 0.0.1"
#define AUTHOR "CS Royal Project"

#define REWARD_AMOUNT 2500

new g_iModeMoney;
new g_iCurMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", 1);
	
	g_iModeMoney = dr_register_mode
	(
		.Name = "DRM_MODE_MONEY",
		.Hud = "DRM_MODE_INFO_MONEY",
		.Mark = "money",
		.RoundDelay = 5,
		.CT_BlockWeapons = 1,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 1,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 1,
		.Hide = 0
	);
}
//************** ReGameDll **************//
public CBasePlayer_Killed_Post(const this, pevAttacker, iGib)
{
	if(g_iCurMode == g_iModeMoney)
	{
		new players[32], pnum; get_players(players, pnum, "ae", "TERRORIST");
		if(pnum > 1)
		{
			for(new i = 0, player; i < pnum; i++)
			{
				player = players[i];
				rg_add_account(player, REWARD_AMOUNT, AS_ADD);
			}
		}
		else
		{
			rg_add_account(players[0], REWARD_AMOUNT, AS_ADD);
		}
		if(get_member(this, m_iTeam) == TEAM_CT)
		{
			new reward = get_member(this, m_iAccount);
			
			if(reward >= REWARD_AMOUNT)
			{
				reward = REWARD_AMOUNT;
			}
			
			rg_add_account(this, -reward, AS_ADD);
			new lossername[32]; get_entvar(this, var_netname, lossername, charsmax(lossername));
			client_print_color(0, this, "^1[^3Денежный^1] ^4%s ^1отдал террористу ^3$%d ^1за свою смерть.", lossername, reward);
		}
	}
}
//************** Deathrun Mode **************//
public dr_selected_mode(id, mode)
{
	g_iCurMode = mode;
}