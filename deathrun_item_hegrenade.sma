#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: High explosive grenade"
#define VERSION "Re 0.2"
#define AUTHOR "CS Royal Project"

new g_bHeGrenade[MAX_PLAYERS + 1];

new g_iModeFree;
new g_iModeDuel;
new g_bCanBuyInMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);

	dr_shop_add_item(
		.name = "Граната", 
		.cost = 3000, 
		.team = ITEM_TEAM_T|ITEM_TEAM_CT, 
		.can_gift = 1, 
		.access = 0, 
		.on_buy = "ShopItem_HeGrenade", 
		.can_buy = "ShopItem_CanBuy_HeGrenade"
	);
}

public plugin_cfg()
{
	g_iModeFree = dr_get_mode_by_mark("free");
	g_iModeDuel = dr_get_mode_by_mark("duel");
}

public dr_selected_mode(id, mode)
{
	g_bCanBuyInMode = true;
	if(mode == g_iModeFree || mode == g_iModeDuel)
	{
		g_bCanBuyInMode = false;
	}
}

public CSGameRules_RestartRound_Pre()
{
	for(new player = 1; player <= MaxClients; player++)
	{
		g_bHeGrenade[player] = false;
	}
}

// *********** On Buy ***********
public ShopItem_HeGrenade(id)
{
	g_bHeGrenade[id] = true;
	rg_give_item(id, "weapon_hegrenade");
}

// *********** Can Buy ***********
public ShopItem_CanBuy_HeGrenade(id)
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
	
	if(g_bHeGrenade[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	if(rg_has_item_by_name(id, "weapon_hegrenade"))
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}