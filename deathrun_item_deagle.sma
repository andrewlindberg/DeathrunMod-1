#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Deagle"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

new g_bDeagle[MAX_PLAYERS + 1];

new g_iModeFree;
new g_iModeRambo;
new g_iModeDuel;
new g_bCanBuyInMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	
	dr_shop_add_item(
		.name = "Дигл", 
		.cost = 21500, 
		.team = ITEM_TEAM_CT, 
		.can_gift = 1, 
		.access = 0, 
		.on_buy = "ShopItem_Deagle", 
		.can_buy = "ShopItem_CanBuy_Deagle"
	);
}

public plugin_cfg()
{
	g_iModeFree = dr_get_mode_by_mark("free");
	g_iModeRambo = dr_get_mode_by_mark("rambo");
	g_iModeDuel = dr_get_mode_by_mark("duel");
}

public dr_selected_mode(id, mode)
{
	g_bCanBuyInMode = true;
	if(mode == g_iModeFree 
	|| mode == g_iModeRambo 
	|| mode == g_iModeDuel)
	{
		g_bCanBuyInMode = false;
	}
}

public CSGameRules_RestartRound_Pre()
{
	for(new player = 1; player <= MaxClients; player++)
	{
		g_bDeagle[player] = false;
	}
}

// *********** On Buy ***********
public ShopItem_Deagle(id)
{
	g_bDeagle[id] = true;
	rg_give_item(id, "weapon_deagle");
}

// *********** Can Buy ***********
public ShopItem_CanBuy_Deagle(id)
{
	if(!g_bCanBuyInMode)
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	if(g_bDeagle[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}