// Credits: Eriurias
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <deathrun_modes>
#include <reapi>

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Rambo"
#define VERSION "Re 1.0.0"
#define AUTHOR "Mistrick"

#define MIN_DIFF 8.0
#define MAX_OVERHEAT 200
#define DURATION_COOLING 1
#define BIG_HEAT 4
#define SMALL_HEAT 2

enum (+=100)
{
	TASK_OVERHEAT_TICK = 150
};

enum _:Hooks
{
	HookChain:Hook_Spawn,
	HamHook:Hook_PrimaryAttack,
	HamHook:Hook_CanDrop,
	Hook_AddToFullPack
};

new g_hHooks[Hooks];
new g_bEnabled, g_iModeRambo, g_iCurMode;
new g_iOverHeat[33], Float:g_fOldAngles[33][3];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	DisableHookChain(g_hHooks[Hook_Spawn] = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", 1));
	DisableHamForward(g_hHooks[Hook_PrimaryAttack] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m249", "Weapon_PrimaryAttack_Pre", 0));
	DisableHamForward(g_hHooks[Hook_CanDrop ] = RegisterHam(Ham_CS_Item_CanDrop, "weapon_m249", "CS_Item_CanDrop_Pre", 0));
	
	register_message(get_user_msgid("CurWeapon"), "Message_CurWeapon");
	
	g_iModeRambo = dr_register_mode
	(
		.Name = "DRM_MODE_RAMBO",
		.Hud = "DRM_MODE_INFO_RAMBO",
		.Mark = "rambo",
		.RoundDelay = 0,
		.CT_BlockWeapons = 0,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 0,
		.Hide = 0
	);
}
public client_disconnected(id)
{
	remove_task(id + TASK_OVERHEAT_TICK);
}
//************** Message **************//
public Message_CurWeapon(msgid, dest, reciver)
{
	if(g_iCurMode != g_iModeRambo) return PLUGIN_CONTINUE;

	if(!get_msg_arg_int(1) || get_msg_arg_int(2) != CSW_M249) return PLUGIN_CONTINUE;

	if(get_member(reciver, m_iTeam) != TEAM_TERRORIST) return PLUGIN_CONTINUE;
	
	set_msg_arg_int(2, ARG_BYTE, CSW_KNIFE);
	set_msg_arg_int(3, ARG_BYTE, -1);

	return PLUGIN_CONTINUE;
}
//************** ReGameDll **************//
public CBasePlayer_Spawn_Post(const this)
{
	if(is_user_alive(this) && get_member(this, m_iTeam) == TEAM_TERRORIST)
	{
		rg_give_item(this, "weapon_m249");
		g_iOverHeat[this] = 0;
		set_task(0.1, "Task_OverHeat_Tick", this + TASK_OVERHEAT_TICK, .flags = "b");
	}
}
public Task_OverHeat_Tick(id)
{
	id -= TASK_OVERHEAT_TICK;
	
	if(g_iOverHeat[id] > 0)
	{
		g_iOverHeat[id]--;
	}
}
//************** Ham **************//
public Weapon_PrimaryAttack_Pre(weapon)
{
	new player = get_member(weapon, m_pPlayer);
	
	if(get_member(player, m_iTeam) != TEAM_TERRORIST) return HAM_IGNORED;
	
	if(g_iOverHeat[player] > MAX_OVERHEAT)
	{
		new Float:flRate = 0.35 / DURATION_COOLING.0;
		set_member(player, m_flNextAttack, flRate);
	}
	
	rg_set_user_ammo(player, WEAPON_M249, 100);
	
	new Float:angles[3]; get_entvar(player, var_angles, angles);
	new Float:diff = get_distance_f(angles, g_fOldAngles[player]);
	g_fOldAngles[player] = angles;
	
	g_iOverHeat[player] += (diff < MIN_DIFF) ? BIG_HEAT : SMALL_HEAT;
	
	SendMessage_BarTime2(player, MAX_OVERHEAT / 10, 100 - g_iOverHeat[player] * 100 / MAX_OVERHEAT);
	
	return HAM_IGNORED;
}
public CS_Item_CanDrop_Pre(const this)
{
	SetHamReturnInteger(false);
	return HAM_SUPERCEDE;
}
//************** Fakemeta **************//
public FM_AddToFullPack_Post(es, e, ent, host, flags, player, pSet)
{
	if(player && host != ent)
	{
		if(get_member(host, m_iTeam) == TEAM_TERRORIST && get_member(ent, m_iTeam) == TEAM_CT)
		{
			set_es(es, ES_RenderAmt, false);
			set_es(es, ES_RenderMode, kRenderTransAlpha);
		}
	}
}
//************** Deathrun Mode **************//
public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeRambo)
	{
		for(new id = 1; id < MaxClients; id++)
		{
			remove_task(id + TASK_OVERHEAT_TICK);
			if(is_user_alive(id)) 
			{
				SendMessage_BarTime2(id, 0, 100);
			}
		}
		DisableHooks();
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeRambo)
	{
		EnableHooks();
		
		rg_give_item(id, "weapon_m249");
		g_iOverHeat[id] = 0;
		set_task(0.1, "Task_OverHeat_Tick", id + TASK_OVERHEAT_TICK, .flags = "b");
	}
}
EnableHooks()
{
	g_bEnabled = true;
	
	EnableHookChain(g_hHooks[Hook_Spawn]);
	EnableHamForward(g_hHooks[Hook_PrimaryAttack]);
	EnableHamForward(g_hHooks[Hook_CanDrop]);
	g_hHooks[Hook_AddToFullPack] = register_forward(FM_AddToFullPack, "FM_AddToFullPack_Post", true);
}
DisableHooks()
{
	if(g_bEnabled)
	{
		g_bEnabled = false;
		
		DisableHookChain(g_hHooks[Hook_Spawn]);
		DisableHamForward(g_hHooks[Hook_PrimaryAttack]);
		DisableHamForward(g_hHooks[Hook_CanDrop]);
		unregister_forward(FM_AddToFullPack, g_hHooks[Hook_AddToFullPack], true);
	}
}
stock SendMessage_BarTime2(id, duration, startpercent)
{
	static BarTime2; if(!BarTime2) BarTime2 = get_user_msgid("BarTime2");
	
	message_begin(MSG_ONE, BarTime2, .player = id);
	write_short(duration);
	write_short(startpercent);
	message_end();
}
