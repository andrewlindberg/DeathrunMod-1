#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Invisibility"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

new g_bInvisibility[MAX_PLAYERS + 1];

new g_iModeInvis;
new g_iModeVictim;
new g_iModeRambo;
new g_iModeDuel;
new g_bCanBuyInMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", .post = true);
	
	dr_shop_add_item(
		.name = "Невидимость 70%", 
		.cost = 9999, 
		.team = ITEM_TEAM_T, 
		.can_gift = 0, 
		.access = 0, 
		.on_buy = "ShopItem_Invisibility", 
		.can_buy = "ShopItem_CanBuy_Invisibility"
	);
}

public plugin_cfg()
{
	g_iModeInvis = dr_get_mode_by_mark("invis");
	g_iModeVictim = dr_get_mode_by_mark("victim");
	g_iModeRambo = dr_get_mode_by_mark("rambo");
	g_iModeDuel = dr_get_mode_by_mark("duel");
}

public dr_selected_mode(id, mode)
{
	g_bCanBuyInMode = true;
	if(mode == g_iModeInvis 
	|| mode == g_iModeVictim 
	|| mode == g_iModeRambo 
	|| mode == g_iModeDuel)
	{
		g_bCanBuyInMode = false;
	}
}

public CSGameRules_RestartRound_Post()
{
	for(new player = 1; player <= MaxClients; player++)
	{
		g_bInvisibility[player] = false;
	}
}

// *********** On Buy ***********
public ShopItem_Invisibility(id)
{
	g_bInvisibility[id] = true;
	
	new Float: rgb[3];
	rg_set_entity_rendering(id, kRenderFxGlowShell, rgb, kRenderTransAdd, 30.0);
}

// *********** Can Buy ***********
public ShopItem_CanBuy_Invisibility(id)
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
	
	if(g_bInvisibility[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}