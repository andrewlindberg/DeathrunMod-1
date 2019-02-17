#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Mac10"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

new g_bMac10[MAX_PLAYERS + 1];

new g_iModeFree;
new g_iModeInvis;
new g_iModeVictim;
new g_iModeDuel;
new g_bCanBuyInMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", .post = true);
	
	dr_shop_add_item(
		.name = "Узи", 
		.cost = 28500, 
		.team = ITEM_TEAM_T, 
		.can_gift = 1, 
		.access = 0, 
		.on_buy = "ShopItem_Mac10", 
		.can_buy = "ShopItem_CanBuy_Mac10"
	);
}

public plugin_cfg()
{
	g_iModeFree = dr_get_mode_by_mark("free");
	g_iModeInvis = dr_get_mode_by_mark("invis");
	g_iModeVictim = dr_get_mode_by_mark("victim");
	g_iModeDuel = dr_get_mode_by_mark("duel");
}

public dr_selected_mode(id, mode)
{
	g_bCanBuyInMode = true;
	if(mode == g_iModeFree 
	|| mode == g_iModeInvis 
	|| mode == g_iModeVictim 
	|| mode == g_iModeDuel)
	{
		g_bCanBuyInMode = false;
	}
}

public CSGameRules_RestartRound_Post()
{
	for(new player = 1; player <= MaxClients; player++)
	{
		g_bMac10[player] = false;
	}
}

// *********** On Buy ***********
public ShopItem_Mac10(id)
{
	g_bMac10[id] = true;
	rg_give_item(id, "weapon_mac10", GT_REPLACE);
}

// *********** Can Buy ***********
public ShopItem_CanBuy_Mac10(id)
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
	
	if(g_bMac10[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}