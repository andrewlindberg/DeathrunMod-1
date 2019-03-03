#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <deathrun_shop>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Shop: Neo vision"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

#define TIME_NEOVISION 30

new g_bNeoVision[MAX_PLAYERS + 1];

new Trie: g_tClasses;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	
	register_forward(FM_AddToFullPack, "AddToFullPack_Post", ._post = true);
	
	dr_shop_add_item(
		.name = fmt("Детектор ловушек (%dс)", TIME_NEOVISION), 
		.cost = 29999, 
		.team = ITEM_TEAM_CT, 
		.can_gift = 0, 
		.access = 0, 
		.on_buy = "ShopItem_NeoVision", 
		.can_buy = "ShopItem_CanBuy_NeoVision"
	);
	
	g_tClasses = TrieCreate();

	new const g_szClasses[][] = {
		"func_door_rotating", "func_door",
		"func_breakable", "func_button"
	};

	for(new i; i < sizeof g_szClasses; i++)
	{
		TrieSetCell(g_tClasses, g_szClasses[i], 0);
	}
}

public plugin_end()
{
	TrieDestroy(g_tClasses);
}

public CSGameRules_RestartRound_Pre()
{
	for(new player = 1; player <= MaxClients; player++)
	{
		g_bNeoVision[player] = false;
	}
}

public AddToFullPack_Post(es, e, ent, host, hostflags, player, pSet) 
{
	if(!g_bNeoVision[host]) return;
	
	if(!is_user_alive(host)) return;
	
	new classname[MAX_NAME_LENGTH]; get_entvar(e, var_classname, classname, charsmax(classname));
	
	if(TrieKeyExists(g_tClasses, classname))
	{
		set_es_rendering(
			.es = es,
			.fx = kRenderFxGlowShell,
			.color = { 255, 0, 0 },
			.render = kRenderTransColor,
			.amount = 100
		);
	}
}

// *********** On Buy ***********
public ShopItem_NeoVision(id)
{
	g_bNeoVision[id] = true;
	
	set_task(TIME_NEOVISION.0, "Task_NeoVision", id);
}

// *********** Can Buy ***********
public ShopItem_CanBuy_NeoVision(id)
{
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	if(g_bNeoVision[id])
	{
		dr_shop_item_addition("\r[Has]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}

// *********** Task ***********
public Task_NeoVision(id) 
{
	g_bNeoVision[id] = false;
}

// *********** Stock ***********
stock set_es_rendering(es = 0, fx = kRenderFxNone, color[3] = {255, 255, 255}, render = kRenderNormal, amount = 16)
{
	set_es(es, ES_RenderFx, fx);
	set_es(es, ES_RenderColor, color);
	set_es(es, ES_RenderMode, render);
	set_es(es, ES_RenderAmt, amount);
}