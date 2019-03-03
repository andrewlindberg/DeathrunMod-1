#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Gravity"
#define VERSION "Re 0.2"
#define AUTHOR "CS Royal Project"

#define CUSTOM_GRAVITY 0.6

new g_bGravity[MAX_PLAYERS + 1];

new g_iCurMode;
new g_iModeDuel;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "CSGameRules_PlayerSpawn_Post", .post = true);
	
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

public CSGameRules_RestartRound_Pre()
{
	for(new player = 1; player <= MaxClients; player++)
	{
		g_bGravity[player] = false;
	}
}

public CSGameRules_PlayerSpawn_Post(const index)
{
	if(g_bGravity[index])
	{
		set_entvar(index, var_gravity, CUSTOM_GRAVITY);
	}
}

// *********** On Buy ***********
public ShopItem_Gravity(id)
{
	g_bGravity[id] = true;
	set_entvar(id, var_gravity, CUSTOM_GRAVITY);
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