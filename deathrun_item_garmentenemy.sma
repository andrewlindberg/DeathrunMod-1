// cl_minmodels "0"
#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Garment enemy"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

new g_bGarmentEnemy[MAX_PLAYERS + 1];

new g_iModeDuel;
new g_iCurMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	
	dr_shop_add_item(
		.name = "Одежда противника", 
		.cost = 12000, 
		.team = ITEM_TEAM_T|ITEM_TEAM_CT, 
		.can_gift = 1, 
		.access = 0, 
		.on_buy = "ShopItem_GarmentEnemy", 
		.can_buy = "ShopItem_CanBuy_GarmentEnemy"
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
		g_bGarmentEnemy[player] = false;
	}
}

// *********** On Buy ***********
public ShopItem_GarmentEnemy(id, &succes_buy)
{
	new const model[][] = { "gign", "leet" };
	new team = _:get_member(id, m_iTeam);
	
	g_bGarmentEnemy[id] = rg_set_user_model(id, model[team - 1]);
	succes_buy = !g_bGarmentEnemy[id];
}

// *********** Can Buy ***********
public ShopItem_CanBuy_GarmentEnemy(id)
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
	
	if(g_bGarmentEnemy[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}