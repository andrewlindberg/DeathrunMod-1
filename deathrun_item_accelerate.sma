#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Accelerate"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

new g_bAccelerate[MAX_PLAYERS + 1];

new g_iCurMode;
new g_iModeDuel;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	
	dr_shop_add_item(
		.name = "Ускоритель", 
		.cost = 29000, 
		.team = ITEM_TEAM_T|ITEM_TEAM_CT, 
		.can_gift = 1, 
		.access = 0, 
		.on_buy = "ShopItem_Accelerate", 
		.can_buy = "ShopItem_CanBuy_Accelerate"
	);
}

public plugin_cfg()
{
	g_iModeDuel = dr_get_mode_by_mark("duel");
}

public dr_selected_mode(id, mode)
{
	g_iCurMode = mode;
}

public CSGameRules_RestartRound_Pre()
{
	for(new player = 1; player <= MaxClients; player++)
	{
		if(g_bAccelerate[player])
		{
			g_bAccelerate[player] = false;
			dr_reset_player_accelerator(player);
		}
	}
}

// *********** On Buy ***********
public ShopItem_Accelerate(id, &failed_buy)
{
	g_bAccelerate[id] = dr_set_player_accelerator(id, 1600.0);
	failed_buy = !g_bAccelerate[id];
}

// *********** Can Buy ***********
public ShopItem_CanBuy_Accelerate(id)
{
	if(g_iCurMode == g_iModeDuel)
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	if(g_bAccelerate[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}