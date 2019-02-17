#include <amxmodx>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_core>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Reservation"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

new g_bReservation;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", .post = true);
	
	dr_shop_add_item(
		.name = "Бронировать Терра", 
		.cost = -500, 
		.team = ITEM_TEAM_CT, 
		.can_gift = 0, 
		.access = 0, 
		.on_buy = "ShopItem_Reservation", 
		.can_buy = "ShopItem_CanBuy_Reservation"
	);
}

public CSGameRules_RestartRound_Post()
{
	g_bReservation = false;
}

// *********** On Buy ***********
public ShopItem_Reservation(id, &succes_buy)
{
	g_bReservation = dr_set_next_terrorist(id);
	succes_buy = g_bReservation;
}

// *********** Can Buy ***********
public ShopItem_CanBuy_Reservation(id)
{
	if(!g_bReservation) return ITEM_ENABLED;
	
	dr_shop_item_addition("\r[Limit]");
	return ITEM_DISABLED;
}