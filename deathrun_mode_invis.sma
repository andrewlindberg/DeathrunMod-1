#include <amxmodx>
#include <hamsandwich>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Invis"
#define VERSION "Re 1.0.1"
#define AUTHOR "Mistrick"

#define TERRORIST_HEALTH 150

new g_iModeInvis, g_iCurMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", 1);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_usp", "Weapon_PrimaryAttack_Pre", 0);
	register_message(get_user_msgid("CurWeapon"), "Message_CurWeapon");
	
	g_iModeInvis = dr_register_mode
	(
		.Name = "DRM_MODE_INVIS",
		.Hud = "DRM_MODE_INFO_INVIS",
		.Mark = "invis",
		.RoundDelay = 2,
		.CT_BlockWeapons = 0,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 1,
		.Hide = 0
	);
}
//************** Message **************//
public Message_CurWeapon(msgid, dest, reciver)
{
	if(g_iCurMode != g_iModeInvis) return PLUGIN_CONTINUE;

	if(!get_msg_arg_int(1) || get_msg_arg_int(2) != CSW_USP) return PLUGIN_CONTINUE;

	if(get_member(reciver, m_iTeam) != TEAM_CT) return PLUGIN_CONTINUE;
	
	set_msg_arg_int(2, ARG_BYTE, CSW_KNIFE);
	set_msg_arg_int(3, ARG_BYTE, -1);

	return PLUGIN_CONTINUE;
}
//************** ReGameDll **************//
public CBasePlayer_Spawn_Post(const this)
{
	if(g_iCurMode == g_iModeInvis)
	{
		if(is_user_alive(this) && get_member(this, m_iTeam) == TEAM_TERRORIST)
		{
			set_invisibility(this);
		}
	}
}
//************** Ham **************//
public Weapon_PrimaryAttack_Pre(weapon)
{
	if(g_iCurMode == g_iModeInvis)
	{
		new player = get_member(weapon, m_pPlayer);
		
		if(get_member(player, m_iTeam) == TEAM_CT)
		{
			rg_set_user_ammo(player, WEAPON_USP, 20);
		}
	}
}
//************** Deathrun Mode **************//
public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeInvis)
	{
		set_cvar_num("mp_forcechasecam", 0);
		set_cvar_num("mp_forcecamera", 0);
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeInvis)
	{
		set_invisibility(id);
		
		set_cvar_num("mp_forcechasecam", 2);
		set_cvar_num("mp_forcecamera", 0);
	}
}
set_invisibility(id)
{
	rh_set_user_rendering(id, kRenderFxGlowShell, Float:{0.0, 0.0, 0.0}, kRenderTransAlpha, 0.0);
}