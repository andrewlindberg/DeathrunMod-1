#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Teleport"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

#define DELAY_TELEPORT 8

new g_bTeleport[MAX_PLAYERS + 1];
new Float: g_fOrigin[MAX_PLAYERS + 1][3];

new g_iModeDuel;
new g_iCurMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	
	dr_shop_add_item(
		.name = fmt("Экскурсия (%dс)", DELAY_TELEPORT), 
		.cost = 48100, 
		.team = ITEM_TEAM_CT, 
		.can_gift = 1, 
		.access = 0, 
		.on_buy = "ShopItem_Teleport", 
		.can_buy = "ShopItem_CanBuy_Teleport"
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
		g_bTeleport[player] = false;
		remove_task(player);
	}
}

// *********** On Buy ***********
public ShopItem_Teleport(id)
{
	g_bTeleport[id] = true;
	
	rg_send_bartime(id, DELAY_TELEPORT / 2);
	
	get_entvar(id, var_origin, g_fOrigin[id]);
	set_task(DELAY_TELEPORT.0 / 2, "Task_TeleportCt", id);
}

// *********** Can Buy ***********
public ShopItem_CanBuy_Teleport(id)
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
	
	if(g_bTeleport[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}

// *********** Task ***********
public Task_TeleportCt(id)
{
	if(!is_user_alive(id) || !g_bTeleport[id]) return;
	
	new ent = rg_find_ent_by_class(-1, "info_player_deathmatch", true);
	new Float:origin[3]; get_entvar(ent, var_origin, origin);
	
	set_entvar(id, var_origin, origin);
	
	rg_send_bartime(id, DELAY_TELEPORT);
	set_task(DELAY_TELEPORT.0, "Task_ReturnCt", id);
}

public Task_ReturnCt(id)
{
	if(!is_user_alive(id)) return;
	
	set_entvar(id, var_origin, g_fOrigin[id]);
}