#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Glow"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

new g_bGlow[MAX_PLAYERS + 1];

new g_iModeInvis;
new g_iModeDuel;
new g_bCanBuyInMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	
	dr_shop_add_item(
		.name = "Свечение", 
		.cost = 7600, 
		.team = ITEM_TEAM_CT, 
		.can_gift = 0, 
		.access = 0, 
		.on_buy = "ShopItem_Glow", 
		.can_buy = "ShopItem_CanBuy_Glow"
	);
}

public plugin_cfg()
{
	g_iModeInvis = dr_get_mode_by_mark("invis");
	g_iModeDuel = dr_get_mode_by_mark("duel");
}

public dr_selected_mode(id, mode)
{
	g_bCanBuyInMode = true;
	if(mode == g_iModeInvis || mode == g_iModeDuel)
	{
		g_bCanBuyInMode = false;
	}
}

public CSGameRules_RestartRound_Pre()
{
	for(new player = 1; player <= MaxClients; player++)
	{
		g_bGlow[player] = false;
	}
}

// *********** On Buy ***********
public ShopItem_Glow(id)
{
	g_bGlow[id] = true;
	
	new Float:fColor[3];
	fColor[0] = random_float(0.0, 255.0);
	fColor[1] = random_float(0.0, 255.0);
	fColor[2] = random_float(0.0, 255.0);
	
	rg_set_entity_rendering(id, kRenderFxGlowShell, fColor, kRenderNormal, 20.0);
}

// *********** Can Buy ***********
public ShopItem_CanBuy_Glow(id)
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
	
	if(g_bGlow[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}