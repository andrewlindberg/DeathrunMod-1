#define PLUGIN "Deathrun Shop: Items"
#define VERSION "Re 0.1/1.0"
#define AUTHOR "CS Royal Project"

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>

#include <deathrun_shop>
#include <deathrun_core>
#include <deathrun_duel>
#include <deathrun_modes>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	#define client_disconnected client_disconnect
#endif

#pragma semicolon 1

#define IsPlayer(%1) (%1 && %1 <= MaxPlayers)

new const g_szModelSyringe[] = "models/royal/shop/items/v_syringe.mdl";

enum (+=100)
{
	TASK_REMOVE_SYRINGE = 100,
	TASK_TELEPORT_CT,
	TASK_RETURN_CT
};

enum _:Item_Count
{
	ItemGrenade,
	ItemHealth,
	ItemGravity,
	ItemSpeed,
	ItemDoubleJump,
	ItemFastJump,
	ItemGlow,
	ItemInvisibility,
	ItemNeoVision,
	ItemWeaponDeagle,
	ItemWeaponMac10,
	ItemTeleport,
	ItemGarmentsCt,
	ItemLottery,
	//ItemMultiplierWin,
	ItemReservation
};

enum _:Mode_Count
{
	ModeDuel,
	ModeFree,
	ModeInvis,
	ModeVictim,
	ModeRambo,
	ModeManiac
};

enum _:Item_Info
{
	Name[128],
	Cost,
	RepeatBuy,
	Team,
	CanGift,
	Access,
	OnBuy[64],
	CanBuy[64]
}

enum 
{
	Disable,
	PostRound,
	PostDeath
}

new const g_eItem[][Item_Info] = 
{
	// 	Name						Money	The repeat buy		Team						One Can Gift	Access	On Buy						Can Buy
	{ 	"Граната",					8000,	PostRound,			ITEM_TEAM_T|ITEM_TEAM_CT,	1,				0,		"ShopItem_GrenadeHE",		"ShopItem_CanBuy_GrenadeHE"		},
	{	"Стимулятор 150hp",			7000,	PostDeath,			ITEM_TEAM_T|ITEM_TEAM_CT,	0,				0,		"ShopItem_Health",			"ShopItem_CanBuy_Health"		},
	{	"Гравитация",				18500,	PostDeath,			ITEM_TEAM_T|ITEM_TEAM_CT,	1,				0,		"ShopItem_Gravity",			"ShopItem_CanBuy_Gravity"		},
	{	"Скорость",					15200,	PostDeath,			ITEM_TEAM_T|ITEM_TEAM_CT,	1,				0,		"ShopItem_Speed",			"ShopItem_CanBuy_Speed"			},
	{	"Двойной прыжок",			29000,	PostDeath,			ITEM_TEAM_T|ITEM_TEAM_CT,	1,				0,		"ShopItem_DoubleJump",		"ShopItem_CanBuy_DoubleJump"	},
	{	"Ускоритель",				35000,	PostDeath,			ITEM_TEAM_T|ITEM_TEAM_CT,	1,				0,		"ShopItem_FastJump",		"ShopItem_CanBuy_FastJump"		},
	{	"Свечение",					5000,	PostRound,			ITEM_TEAM_CT,				0,				0,		"ShopItem_Glow",			"ShopItem_CanBuy_Glow"			},
	{	"Невидимость 70%",			15013,	PostRound,			ITEM_TEAM_T,				0,				0,		"ShopItem_Invisibility",	"ShopItem_CanBuy_Invisibility"	},
	{	"Детектор лофушек (30с)",	30013,	Disable,			ITEM_TEAM_CT,				1,				0,		"ShopItem_NeoVision",		"ShopItem_CanBuy_NeoVision"		},
	{	"Дигл",						25000,	PostRound,			ITEM_TEAM_CT,				1,				0,		"ShopItem_Deagle",			"ShopItem_CanBuy_Deagle"		},
	{	"Узи",						35750,	PostRound,			ITEM_TEAM_T,				1,				0,		"ShopItem_Mac10",			"ShopItem_CanBuy_Mac10"			},
	{	"Экскурсия (10с)",			57000,	PostRound,			ITEM_TEAM_CT,				0,				0,		"ShopItem_Teleport",		"ShopItem_CanBuy_Teleport"		},
	{	"Одежда ct",				17000,	PostRound,			ITEM_TEAM_T,				0,				0,		"ShopItem_GarmentsCt",		"ShopItem_CanBuy_GarmentsCt"	},
	{	"Лотерея",					3000,	PostRound,			ITEM_TEAM_T|ITEM_TEAM_CT,	0,				0,		"ShopItem_Lottery",			"ShopItem_CanBuy_Lottery"		},
	//{	"Множитель приза",			14000,	Disable,			ITEM_TEAM_T|ITEM_TEAM_CT,	0,				0,		"ShopItem_MultiplierWin",	"ShopItem_CanBuy_MultiplierWin"	},
	{	"Бронировать Терра",		27000,	Disable,			ITEM_TEAM_CT,				0,				0,		"ShopItem_Reservation",		"ShopItem_CanBuy_Reservation"	}
};

new g_bItemUsed[Item_Count][33];
new g_iJumpNum[33];

new g_iCurMode;
new g_eiMode[Mode_Count];
new MaxPlayers, g_bCompleteReset = false;

new Trie: g_tClasses;

public plugin_precache() 
{
	precache_model(g_szModelSyringe);
}
public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_forward(FM_AddToFullPack, "AddToFullPack_Post", ._post = true);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	RegisterHookChain(RG_CSGameRules_PlayerKilled, "CSGameRules_PlayerKilled_Pre", .post = false);
	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Pre", .post = false);
	RegisterHookChain(RG_CBasePlayer_Jump, "CBasePlayer_Jump_Pre", .post = false);
	
	RegisterForwardsSettingWeapon();
	
	for(new item = 0; item < sizeof g_eItem; item++)
	{
		dr_shop_add_item
		(
			.name[] = g_eItem[item][Name], 
			.cost = g_eItem[item][Cost], 
			.team = g_eItem[item][Team], 
			.can_gift = g_eItem[item][CanGift], 
			.access = g_eItem[item][Access], 
			.on_buy[] = g_eItem[item][OnBuy], 
			.can_buy[] = g_eItem[item][CanBuy]
		);
	}
	
	g_tClasses = TrieCreate();

	new const g_sClasses[][] = 
	{
		"func_door_rotating", "func_door",
		"func_breakable", "func_button"
	};

	for(new i; i < sizeof g_sClasses; i++)
	{
		TrieSetCell(g_tClasses, g_sClasses[i], 0);
	}
	
	MaxPlayers = get_member_game(m_nMaxPlayers);
}
public plugin_end()
{
    TrieDestroy(g_tClasses);
}
RegisterForwardsSettingWeapon() 
{
	static szWeaponName[24];
	for(new i = CSW_P228; i <= CSW_P90; i++)
    {
        get_weaponname(i, szWeaponName, charsmax(szWeaponName));
        if(szWeaponName[0])
        {
            RegisterHam(Ham_Item_Deploy, szWeaponName, "Ham_Item_Deploy_Post", .Post = true);
        }
    }
}
public plugin_cfg()
{
	g_eiMode[ModeDuel] = dr_get_mode_by_mark("duel");
	g_eiMode[ModeFree] = dr_get_mode_by_mark("free");
	g_eiMode[ModeInvis] = dr_get_mode_by_mark("invis");
	g_eiMode[ModeVictim] = dr_get_mode_by_mark("victim");
	g_eiMode[ModeRambo] = dr_get_mode_by_mark("rambo");
	g_eiMode[ModeManiac] = dr_get_mode_by_mark("maniac");
}
public dr_selected_mode(id, mode)
{
	g_iCurMode = mode;
}
public client_disconnected(id)
{
	remove_task(id+TASK_REMOVE_SYRINGE);
	remove_task(id+TASK_TELEPORT_CT);
	remove_task(id+TASK_RETURN_CT);
}
public AddToFullPack_Post(es, e, ent, host, hostflags, player, pSet) 
{
	if(!g_bItemUsed[ItemNeoVision][host]) return;
	
	if(!is_user_alive(host)) return;
	
	static classname[25]; get_entvar(e, var_classname, classname, charsmax(classname));
	
	if(TrieKeyExists(g_tClasses, classname))
	{
		set_es_rendering(
			.es = es,
			.fx = kRenderFxGlowShell,
			.color = {255, 0, 0},
			.render = kRenderTransColor,
			.amount = 100
		);
	}
}
public CSGameRules_RestartRound_Pre()
{
	if(get_member_game(m_bCompleteReset))
	{
		g_bCompleteReset = true;
	}
	
	for(new player = 1; player <= MaxPlayers; player++)
	{
		remove_task(player+TASK_REMOVE_SYRINGE);
		remove_task(player+TASK_TELEPORT_CT);
		remove_task(player+TASK_RETURN_CT);
		
		for(new item = 0; item < Item_Count; item++)
		{
			if(g_eItem[item][RepeatBuy] != PostRound) continue;
			
			g_bItemUsed[item][player] = false; 
		}
	}
}
public CSGameRules_PlayerKilled_Pre(const victim, const killer, const inflictor)
{
	if(!g_bCompleteReset) return HC_CONTINUE;
	
	remove_task(victim+TASK_REMOVE_SYRINGE);
	remove_task(victim+TASK_TELEPORT_CT);
	remove_task(victim+TASK_RETURN_CT);
	
	for(new item = 0; item < Item_Count; item++)
	{
		if(g_eItem[item][RepeatBuy] != PostDeath) continue;
		
		g_bItemUsed[item][victim] = false; 
	}
	return HC_CONTINUE;
}
public CBasePlayer_ResetMaxSpeed_Pre(const this)
{
	if(g_iCurMode == g_eiMode[ModeDuel] || !g_bCompleteReset) return HC_CONTINUE;
	
	if(g_bItemUsed[ItemSpeed][this])
	{
		set_entvar(this, var_maxspeed, 400.0);
		return HC_SUPERCEDE;
	}
	
	return HC_CONTINUE;
}
public CBasePlayer_Jump_Pre(const this)
{
	if(g_iCurMode == g_eiMode[ModeDuel] \
	|| !is_user_alive(this) \
	|| !g_bCompleteReset) return HC_CONTINUE;
	
	if(g_bItemUsed[ItemDoubleJump][this])
	{
		if(get_entvar(this, var_flags) & FL_ONGROUND)
		{
			g_iJumpNum[this] = 0;
		}
		else if((~get_member(this, m_afButtonLast) & IN_JUMP) && !g_iJumpNum[this])
		{
			static Float:velocity[3]; 
			get_entvar(this, var_velocity, velocity);
			velocity[2] = random_float(265.0, 285.0); 
			set_entvar(this, var_velocity, velocity);
			
			g_iJumpNum[this]++;
		}
	}
	
	if(!dr_get_user_bhop(this)) return HC_CONTINUE;
	
	if(g_bItemUsed[ItemFastJump][this]) 
	{
		if(get_member(this, m_afButtonLast) & IN_DUCK) 
		{
			if(get_entvar(this, var_flags) & FL_WATERJUMP \
			|| get_entvar(this, var_waterlevel) >= 2 \
			|| !(get_entvar(this, var_flags) & FL_ONGROUND)) return HC_CONTINUE;
			
			set_entvar(this, var_fuser2, 0);
			
			new Float:velocity[3]; get_entvar(this, var_velocity, velocity);
			new Float:fSpeed; fSpeed = vector_length(velocity);
			
			if(fSpeed > 1800.0) return HC_CONTINUE;
			
			velocity[0] *= 1.20;
			velocity[1] *= 1.20;
			
			set_entvar(this, var_velocity, velocity);
			set_entvar(this, var_gaitsequence, 6);
		}
	}
	return HC_CONTINUE;
}
public Ham_Item_Deploy_Post(weapon)
{
	if(g_iCurMode == g_eiMode[ModeDuel] || !g_bCompleteReset) return HAM_IGNORED;
	
	new player = get_member(weapon, m_pPlayer);
	if(IsPlayer(player) && g_bItemUsed[ItemGravity][player])
	{
		set_entvar(player, var_gravity, 0.5);
	}
	
	return HAM_IGNORED;
}
// *********** On Buy ***********
public ShopItem_GrenadeHE(id)
{
	g_bItemUsed[ItemGrenade][id] = true;
	rg_give_item(id, "weapon_hegrenade");
}
public ShopItem_Health(id)
{
	g_bItemUsed[ItemHealth][id] = true;
	
	DRSH_Set_Syringe_Model(id);
}
public ShopItem_Gravity(id)
{
	g_bItemUsed[ItemGravity][id] = true;
	set_entvar(id, var_gravity, 0.5);
}
public ShopItem_Speed(id)
{
	g_bItemUsed[ItemSpeed][id] = true;
	rg_reset_maxspeed(id);
}
public ShopItem_DoubleJump(id)
{
	g_bItemUsed[ItemDoubleJump][id] = true;
}
public ShopItem_FastJump(id)
{
	g_bItemUsed[ItemFastJump][id] = true;
}
public ShopItem_Glow(id)
{
	g_bItemUsed[ItemGlow][id] = true;
	
	new Float:fColor[3];
	fColor[0] = random_float(0.0, 255.0);
	fColor[1] = random_float(0.0, 255.0);
	fColor[2] = random_float(0.0, 255.0);
	
	rh_set_user_rendering(id, kRenderFxGlowShell, fColor, kRenderNormal, 20.0);
}
public ShopItem_Invisibility(id)
{
	g_bItemUsed[ItemInvisibility][id] = true;
	rh_set_user_rendering(id, kRenderFxGlowShell, Float:{0.0, 0.0, 0.0}, kRenderTransAdd, 30.0);
}
public ShopItem_NeoVision(id)
{
	g_bItemUsed[ItemNeoVision][id] = true;
	
	new Float:fTimeCount = 30.0; 
	set_task(fTimeCount, "Task_NeoVision", id);
}
public ShopItem_Deagle(id)
{
	g_bItemUsed[ItemWeaponDeagle][id] = true;
	rg_give_item(id, "weapon_deagle", GT_REPLACE);
}
public ShopItem_Mac10(id)
{
	g_bItemUsed[ItemWeaponMac10][id] = true;
	rg_give_item(id, "weapon_mac10", GT_REPLACE);
}
public ShopItem_Teleport(id)
{
	g_bItemUsed[ItemTeleport][id] = true;
	
	new Float:fTimeCount = 2.0; 
	rg_send_bartime(id, floatround(fTimeCount));
	
	set_task(fTimeCount, "Task_TeleportCt", id+TASK_TELEPORT_CT);
}
public ShopItem_GarmentsCt(id)
{
	g_bItemUsed[ItemGarmentsCt][id] = true;
	rg_set_user_model(id, "urban", true);
}
public ShopItem_Lottery(id)
{
	g_bItemUsed[ItemLottery][id] = true;
	DRSH_Lottery(id);
}
/*public ShopItem_MultiplierWin(id)
{
	multiplier_win(id);
}*/
public ShopItem_Reservation(id)
{
	dr_set_next_terrorist(id); 
}
// *********** Can Buy ***********
public ShopItem_CanBuy_GrenadeHE(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel] \
	|| g_iCurMode == g_eiMode[ModeFree]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemGrenade][id])
	{
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_Health(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel] \
	|| g_iCurMode == g_eiMode[ModeInvis]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemHealth][id])
	{
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	if(get_entvar(id, var_health) >= 100.0)
	{
		dr_shop_item_addition("\r[Max]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_Gravity(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemGravity][id])
	{
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_Speed(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemSpeed][id])
	{
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_DoubleJump(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemDoubleJump][id])
	{
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_FastJump(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemFastJump][id])
	{
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_Glow(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel] \
	|| g_iCurMode == g_eiMode[ModeInvis]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemGlow][id])
	{
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_Invisibility(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel] \
	|| g_iCurMode == g_eiMode[ModeInvis] \
	|| g_iCurMode == g_eiMode[ModeVictim] \
	|| g_iCurMode == g_eiMode[ModeRambo]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemInvisibility][id])
	{
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_NeoVision(id)
{
	if(g_bItemUsed[ItemNeoVision][id])
	{
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_Deagle(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel] \
	|| g_iCurMode == g_eiMode[ModeFree] \
	|| g_iCurMode == g_eiMode[ModeRambo] \
	|| g_iCurMode == g_eiMode[ModeManiac]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemWeaponDeagle][id])
	{
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_Mac10(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel] \
	|| g_iCurMode == g_eiMode[ModeFree] \
	|| g_iCurMode == g_eiMode[ModeInvis] \
	|| g_iCurMode == g_eiMode[ModeVictim] \
	|| g_iCurMode == g_eiMode[ModeManiac]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemWeaponMac10][id])
	{
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_Teleport(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemTeleport][id])
	{
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_GarmentsCt(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemGarmentsCt][id])
	{
		dr_shop_item_addition("\r[Одета]");
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
public ShopItem_CanBuy_Lottery(id)
{
	if(g_iCurMode == g_eiMode[ModeDuel]) 
	{
		dr_shop_item_addition("\r[Block]");
		return ITEM_DISABLED;
	}
	
	if(g_bItemUsed[ItemLottery][id])
	{
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	return ITEM_ENABLED;
}
/*public ShopItem_CanBuy_MultiplierWin(id)
{
	if(get_multiplier_win(id))
	{
		dr_shop_item_addition("\r[Куплено] [Дуэль]");
		return ITEM_DISABLED;
	}
	
	if(!is_user_alive(id))
	{
		dr_shop_item_addition("\r[Dead]");
		return ITEM_DISABLED;
	}
	
	dr_shop_item_addition("\y[x5] [Дуэль]");
	return ITEM_ENABLED;
}*/
public ShopItem_CanBuy_Reservation(id)
{
	if(dr_get_next_terrorist())
	{
		dr_shop_item_addition("\r[Занят]");
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
	
	set_task(1.3, "Task_Set_Syringe_Health", id+TASK_REMOVE_SYRINGE);
	set_task(2.8, "Task_Remove_Syringe_Model", id+TASK_REMOVE_SYRINGE);
}
public Task_Set_Syringe_Health(id)
{
	if(g_iCurMode != g_eiMode[ModeDuel])
	{
		id -= TASK_REMOVE_SYRINGE;
		
		if(is_user_alive(id))
		{
			set_entvar(id, var_health, 150.0);
		}
	}
}
public Task_Remove_Syringe_Model(id)
{
	id -= TASK_REMOVE_SYRINGE;
	if(is_user_alive(id)) 
	{
		new iActiveItem = get_member(id, m_pActiveItem);
		if(iActiveItem > 0)
		{	
			ExecuteHamB(Ham_Item_Deploy, iActiveItem);
		}
	}
}
public Task_NeoVision(id) 
{
	g_bItemUsed[ItemNeoVision][id] = false;
}
public Task_TeleportCt(id) 
{
	id -= TASK_TELEPORT_CT;
	
	new ent = rg_find_ent_by_class(-1, "info_player_deathmatch", true);
	new Float:origin[3]; get_entvar(ent, var_origin, origin);
	
	set_entvar(id, var_origin, origin);
	
	new Float:fTimeReturn = 6.0;
	rg_send_bartime(id, floatround(fTimeReturn));
	set_task(fTimeReturn, "Task_ReturnCt", id+TASK_RETURN_CT);
}
public Task_ReturnCt(id) 
{
	id -= TASK_RETURN_CT;
	
	if(is_user_alive(id))
	{
		new ent = rg_find_ent_by_class(-1, "info_player_start", true);
		new Float:origin[3]; get_entvar(ent, var_origin, origin);
		
		set_entvar(id, var_origin, origin);
	}
}
public DRSH_Lottery(id) 
{
	new const szPrefix[] = "^1[^3Лоторея^1]";
	switch(random_num(1, get_member(id, m_iTeam) == TEAM_CT ? 10:6)) 
	{
		case 1..4: 
		{
			new LoseMoney = random_num(2000, 10000);
			rg_add_account(id, get_member(id, m_iAccount) - LoseMoney, AS_SET, true);
			if(LoseMoney > 7000) 
			{
				client_print_color(0, print_team_red, "%s ^4Неизвестный неудачник потерял ^1$%d^4.", szPrefix, LoseMoney);
			}
			client_print_color(id, print_team_red, "%s ^4Вам не повезло! Вы потеряли ^3$%d.", szPrefix, LoseMoney);
		}
		case 5: 
		{
			ShopItem_Health(id);
			client_print_color(id, print_team_red, "%s ^4Вы выиграли^1 стимулятор 150hp.", szPrefix);
		}
		case 6: 
		{
			new WinMoney = random_num(2000, 10000); 
			rg_add_account(id, WinMoney);
			if(WinMoney > 7000) 
			{
				client_print_color(0, print_team_red, "%s ^4Неизвестный сорвал куш в размере ^1$%d^4.", szPrefix, WinMoney);
			}
			client_print_color(id, print_team_red, "%s ^4Вы выиграли^1 %d ^4денег.", szPrefix, WinMoney);
		}
		case 7: 
		{
			ShopItem_Deagle(id);
			client_print_color(id, print_team_red, "%s ^4Вы выиграли дигл (^1с 7-мью патронами^4).", szPrefix);
		}
		case 8: 
		{
			ShopItem_GrenadeHE(id);
			client_print_color(id, print_team_red, "%s ^4Вы выиграли гранату.", szPrefix);
		}
		case 9: 
		{
			ShopItem_Speed(id);
			client_print_color(id, print_team_red, "%s ^4Вы выиграли скорость.", szPrefix);
		}
		case 10: 
		{
			ShopItem_Gravity(id);
			client_print_color(id, print_team_red, "%s ^4Вы выиграли гравитацию.", szPrefix);
		}
	} 
}
stock set_es_rendering(es = 0, fx = kRenderFxNone, color[3] = {255, 255, 255}, render = kRenderNormal, amount = 16)
{
    set_es(es, ES_RenderFx, fx);
    set_es(es, ES_RenderColor, color);
    set_es(es, ES_RenderMode, render);
    set_es(es, ES_RenderAmt, amount);
}