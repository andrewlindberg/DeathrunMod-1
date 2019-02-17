#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Gravity"
#define VERSION "Re 0.2"
#define AUTHOR "CS Royal Project"

new g_bGravity[MAX_PLAYERS + 1];

new g_iCurMode;
new g_iModeDuel;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", .post = true);
	
	dr_shop_add_item(
		.name = "Гравитация", 
		.cost = 12000, 
		.team = ITEM_TEAM_T|ITEM_TEAM_CT, 
		.can_gift = 1, 
		.access = 0, 
		.on_buy = "ShopItem_Gravity", 
		.can_buy = "ShopItem_CanBuy_Gravity"
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

public CSGameRules_RestartRound_Post()
{
	for(new player = 1; player <= MaxClients; player++)
	{
		if(g_bGravity[player])
		{
			g_bGravity[player] = false;
			dr_reset_player_gravity(player);
		}
	}
}

// *********** On Buy ***********
public ShopItem_Gravity(id, &failed_buy)
{
	g_bGravity[id] = dr_set_player_gravity(id, 0.5);
	failed_buy = !g_bGravity[id];
}

// *********** Can Buy ***********
public ShopItem_CanBuy_Gravity(id)
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
	
	if(g_bGravity[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}