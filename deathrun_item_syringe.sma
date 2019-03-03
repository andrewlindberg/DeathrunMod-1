#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Syringe health"
#define VERSION "Re 0.2"
#define AUTHOR "CS Royal Project"

#define TASKID_REMOVE_SYRINGE 9724236
#define DEFAULT_HEALTH 100

new const g_szModelSyringe[] = "models/royal/shop/items/v_syringe.mdl";

new g_bSyringeHealth[MAX_PLAYERS + 1];

new g_iModeInvis;
new g_iModeDuel;
new g_bCanBuyInMode;

public plugin_precache() 
{
	precache_model(g_szModelSyringe);
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);

	dr_shop_add_item(
		.name = "Стимулятор 100hp", 
		.cost = 5000, 
		.team = ITEM_TEAM_T|ITEM_TEAM_CT, 
		.can_gift = 0, 
		.access = 0, 
		.on_buy = "ShopItem_SyringeHealth", 
		.can_buy = "ShopItem_CanBuy_SyringeHealth"
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
		g_bSyringeHealth[player] = false;
	}
}

// *********** On Buy ***********
public ShopItem_SyringeHealth(id)
{
	g_bSyringeHealth[id] = true;
	DRSH_Set_Syringe_Model(id);
}

// *********** Can Buy ***********
public ShopItem_CanBuy_SyringeHealth(id)
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
	
	if(get_entvar(id, var_health) > DEFAULT_HEALTH.0 - 1)
	{
		dr_shop_item_addition("\r[Max]");
		return ITEM_DISABLED;
	}
	
	if(g_bSyringeHealth[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}

// *********** Set Buy ***********
DRSH_Set_Syringe_Model(id)
{
	set_entvar(id, var_viewmodel, g_szModelSyringe);
	set_entvar(id, var_weaponanim, 1);
	set_member(id, m_flNextAttack, 3.0);
	
	set_task(1.3, "Task_SetSyringeHealth", id+TASKID_REMOVE_SYRINGE);
	set_task(2.8, "Task_Remove_SyringeModel", id+TASKID_REMOVE_SYRINGE);
}

public Task_SetSyringeHealth(id)
{
	if(!g_bCanBuyInMode) return;
	
	id -= TASKID_REMOVE_SYRINGE;
	
	if(!is_user_alive(id)) return;

	set_entvar(id, var_health, DEFAULT_HEALTH.0);
}

public Task_Remove_SyringeModel(id)
{
	id -= TASKID_REMOVE_SYRINGE;
	
	new iActiveItem = get_member(id, m_pActiveItem);
	if(!is_nullent(iActiveItem))
	{
		ExecuteHamB(Ham_Item_Deploy, iActiveItem);
	}
}