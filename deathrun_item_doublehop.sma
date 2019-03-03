#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Double hop"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

new g_bDoubleHop[MAX_PLAYERS + 1];

new g_iCurMode;
new g_iModeDuel;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	
	dr_shop_add_item(
		.name = "Двойной прыжок", 
		.cost = 19000, 
		.team = ITEM_TEAM_T|ITEM_TEAM_CT, 
		.can_gift = 1, 
		.access = 0, 
		.on_buy = "ShopItem_DoubleHop", 
		.can_buy = "ShopItem_CanBuy_DoubleHop"
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
		if(g_bDoubleHop[player])
		{
			g_bDoubleHop[player] = false;
			dr_reset_player_multihop(player);
		}
	}
}

// *********** On Buy ***********
public ShopItem_DoubleHop(id, &failed_buy)
{
	g_bDoubleHop[id] = dr_set_player_multihop(id, 2);
	failed_buy = !g_bDoubleHop[id];
}

// *********** Can Buy ***********
public ShopItem_CanBuy_DoubleHop(id)
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
	
	if(g_bDoubleHop[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}