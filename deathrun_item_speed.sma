#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Speed"
#define VERSION "Re 0.2"
#define AUTHOR "CS Royal Project"

new g_bSpeed[MAX_PLAYERS + 1];

new g_iCurMode;
new g_iModeDuel;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	
	dr_shop_add_item(
		.name = "Скорость", 
		.cost = 8000, 
		.team = ITEM_TEAM_T|ITEM_TEAM_CT, 
		.can_gift = 1, 
		.access = 0, 
		.on_buy = "ShopItem_Speed", 
		.can_buy = "ShopItem_CanBuy_Speed"
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
		if(g_bSpeed[player])
		{
			g_bSpeed[player] = false;
			dr_reset_player_maxspeed(player);
		}
	}
}

// *********** On Buy ***********
public ShopItem_Speed(id, &failed_buy)
{
	g_bSpeed[id] = dr_set_player_maxspeed(id, 400.0);
	failed_buy = !g_bSpeed[id];
}

// *********** Can Buy ***********
public ShopItem_CanBuy_Speed(id)
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
	
	if(g_bSpeed[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}