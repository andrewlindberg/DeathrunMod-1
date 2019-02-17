#include <amxmisc>
#include <cstrike>
#include <reapi>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#pragma semicolon 1

#define PLUGIN "Deathrun: Shop"
#define VERSION "Re 0.1.3"
#define AUTHOR "Mistrick"

#define ADMIN_DISCOUNT 35

enum _:ShopItem
{
	ItemName[MAX_NAME_LENGTH],
	ItemCost,
	ItemTeam,
	ItemCanGift,
	ItemAccess,
	ItemPlugin,
	ItemOnBuy,
	ItemCanBuy
};

new const PREFIX[] = "^4[DRS]";

new Array:g_aShopItems;
new g_iShopTotalItems;
new g_hCallbackDisabled;
new g_szItemAddition[MAX_NAME_LENGTH];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd("say /shop", "Command_Shop");
	register_clcmd("say_team /shop", "Command_Shop");
}
public plugin_cfg()
{
	register_dictionary("deathrun_shop.txt");
}
public plugin_natives()
{
	g_aShopItems = ArrayCreate(ShopItem);
	g_hCallbackDisabled = menu_makecallback("ShopDisableItem");
	
	register_library("deathrun_shop");
	register_native("dr_shop_add_item", "native_add_item");
	register_native("dr_shop_item_addition", "native_item_addition");
	register_native("dr_shop_set_item_cost", "native_set_item_cost");
}
public ShopDisableItem()
{
	return ITEM_DISABLED;
}
/**
 *  native dr_shop_add_item(name[], cost, team = (ITEM_TEAM_T|ITEM_TEAM_CT), access = 0, on_buy[], can_buy[] = "");
 */
public native_add_item(plugin, params)
{
	enum
	{
		arg_name = 1,
		arg_cost,
		arg_team,
		arg_cangift,
		arg_access,
		arg_onbuy,
		arg_canbuy
	};
	
	new item_info[ShopItem];
	{
		get_string(arg_name, item_info[ItemName], charsmax(item_info[ItemName]));
		item_info[ItemCost] = get_param(arg_cost);
		item_info[ItemTeam] = get_param(arg_team);
		item_info[ItemCanGift] = get_param(arg_cangift);
		item_info[ItemAccess] = get_param(arg_access);
		item_info[ItemPlugin] = plugin;
		
		new function[MAX_NAME_LENGTH]; get_string(arg_onbuy, function, charsmax(function));
		item_info[ItemOnBuy] = get_func_id(function, plugin);
		
		get_string(arg_canbuy, function, charsmax(function));
		
		if(function[0])
		{
			// public CanBuyItem(id);
			item_info[ItemCanBuy] = CreateMultiForward(function, ET_CONTINUE, FP_CELL);
		}
		
		ArrayPushArray(g_aShopItems, item_info);
	}
	g_iShopTotalItems++;
	
	return g_iShopTotalItems - 1;
}
/**
 *  native dr_shop_item_addition(addition[]);
 */
public native_item_addition(plugin, params)
{
	enum { arg_addition = 1 };
	get_string(arg_addition, g_szItemAddition, charsmax(g_szItemAddition));
}
/**
 *  native dr_shop_set_item_cost(item, cost);
 */
public native_set_item_cost(plugin, params)
{
	enum { arg_item = 1, arg_cost };
	
	new item = get_param(arg_item);
	
	if(item < 0 || item >= g_iShopTotalItems)
	{
		log_error(AMX_ERR_NATIVE, "[DRS] Set item cost: wrong item index! index %d", item);
		return 0;
	}
	
	new item_info[ShopItem];
	{
		ArrayGetArray(g_aShopItems, item, item_info);
		item_info[ItemCost] = get_param(arg_cost);
		ArraySetArray(g_aShopItems, item, item_info);
	}
	
	return 1;
}
public Command_Shop(id)
{
	Show_ShopMenu(id, 0);
}
Show_ShopMenu(id, page)
{
	if(!g_iShopTotalItems) return;
	
	new flags = get_user_flags(id);
	new text[MAX_MENU_LENGTH], len;
	len = formatex(text, charsmax(text), "\d%L^n%L", id, "DRS_MENU_TITLE", id, "DRS_MENU_DISCOUNT", get_percent(flags));
	new menu = menu_create(text, "ShopMenu_Handler");
	
	new target = re_observer_target(id);
	if(target != id)
	{
		len += formatex(text[len], charsmax(text) - len, "^n%L", id, "DRS_MENU_INFO");
	}
	
	new szCanGift[5], hCallback, szNum[2], item_info[ShopItem];
	new team = (1 << _:get_member(target, m_iTeam));
	
	for (new i = 0; i < g_iShopTotalItems; i++)
	{
		g_szItemAddition = "";
		ArrayGetArray(g_aShopItems, i, item_info);
		
		if(~item_info[ItemTeam] & team) continue;
		
		szCanGift = "";
		if(target != id && item_info[ItemCanGift])
		{
			szCanGift = " \r*";
		}
		
		szNum[0] = i;
		hCallback = (GetCanBuyAnswer(target, item_info[ItemCanBuy]) == ITEM_ENABLED) ? -1 : g_hCallbackDisabled;
		formatex(text, charsmax(text), "%s %s \R\y$%d%s", item_info[ItemName], g_szItemAddition, get_discount(item_info[ItemCost], flags), szCanGift);
		
		menu_additem(menu, text, szNum, item_info[ItemAccess], hCallback);
	}
	
	formatex(text, charsmax(text), "%L", id, "DRS_MENU_BACK");
	menu_setprop(menu, MPROP_BACKNAME, text);
	formatex(text, charsmax(text), "%L", id, "DRS_MENU_NEXT");
	menu_setprop(menu, MPROP_NEXTNAME, text);
	formatex(text, charsmax(text), "%L", id, "DRS_MENU_EXIT");
	menu_setprop(menu, MPROP_EXITNAME, text);
	
	menu_display(id, menu, page);
}
public ShopMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new iAccess, szInfo[2], hCallback;
	menu_item_getinfo(menu, item, iAccess, szInfo, charsmax(szInfo), .callback = hCallback);
	menu_destroy(menu);
	
	new item_index = szInfo[0];
	new item_info[ShopItem]; ArrayGetArray(g_aShopItems, item_index, item_info);
	
	new target = re_observer_target(id);
	new team = (1 << _:get_member(target, m_iTeam));
	
	if((~item_info[ItemTeam] & team) || GetCanBuyAnswer(target, item_info[ItemCanBuy]) != ITEM_ENABLED)
	{
		client_print_color(id, id, "%s^1 %L", PREFIX, id, "DRS_CHAT_CANT_BUY");
		return PLUGIN_HANDLED;
	}
	
	new flags = get_user_flags(id);
	new money = get_discount(item_info[ItemCost], flags);
	new need_money = get_member(id, m_iAccount) - money;
	
	if(need_money < 0)
	{
		client_print_color(id, target, "%s^1 %L", PREFIX, id, "DRS_CHAT_NEED_MORE_MONEY", -need_money);
	}
	else
	{
		// public OnBuyItem(id);
		if(callfunc_begin_i(item_info[ItemOnBuy], item_info[ItemPlugin]))
		{
			new failed_buy;
			callfunc_push_int(target);
			callfunc_push_intrf(failed_buy);
			callfunc_end();
			
			if(!failed_buy)
			{
				new id_netname[MAX_NAME_LENGTH]; get_entvar(id, var_netname, id_netname, charsmax(id_netname));
				if(target == id)
				{
					client_print_color(id, id, "%s^1 %L", PREFIX, id, "DRS_CHAT_BOUGHT_ITEM", item_info[ItemName], id_netname);
				}
				else
				{
					new target_netname[MAX_NAME_LENGTH]; get_entvar(target, var_netname, target_netname, charsmax(target_netname));
					client_print_color(0, id, "%s^1 %L", PREFIX, id, "DRS_CHAT_BOUGHT_GIFT", id_netname, item_info[ItemName], target_netname);
				}
				
				rg_add_account(id, -money);
			}
		}
	}
	
	Show_ShopMenu(id, item / 7);
	return PLUGIN_HANDLED;
}
GetCanBuyAnswer(id, callback)
{
	if(!callback) return ITEM_ENABLED;
	new return_value; ExecuteForward(callback, return_value, id);
	return return_value;
}
get_discount(cost = 0, flags = ADMIN_ALL)
{
	new percent = get_percent(flags);
	
	if(cost > 0 && percent > 0)
	{
		cost -= (cost * percent / 100);
	}
	
	return cost;
}
get_percent(flags = ADMIN_ALL)
{
	if(flags > ADMIN_ALL && !(flags & ADMIN_USER))
	{
		return ADMIN_DISCOUNT;
	}
	
	new percent = 0;
	new hours; time(.hour = hours);
	switch (hours)
	{
		case 0..6: percent = 25;
		case 7..12: percent = 15;
		case 19..23: percent = 10;
	}
	return percent;
}
stock re_observer_target(id)
{
	new iSpecmode = get_entvar(id, var_iuser1);
	if(iSpecmode == OBS_CHASE_LOCKED || iSpecmode == OBS_CHASE_FREE || iSpecmode == OBS_IN_EYE)
	{
		return get_entvar(id, var_iuser2);
	}
	
	return id;
}