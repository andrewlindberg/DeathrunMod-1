#include <amxmodx>
#include <engine>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Snow"
#define VERSION "Re 1.0.4"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define IsPlayer(%0) (%0 && %0 <= g_iMaxPlayers)

#define CAN_FLY_THROUGH_THE_WALLS
//#define STOP_BALL_AFTER_TOUCH

#define SNOWBALL_AMOUNT 2
#define SNOWBALL_DAMAGE 25.0
#define SNOWBALL_VELOCITY 2000.0
#define SNOWBALL_LIFETIME 5.0

new const BALL_CLASSNAME[] = "snow_ball";
new const BALL_MODEL_W[] = "models/royal/mode/snowball/w_snowball.mdl";
new const BALL_MODEL_V[] = "models/royal/mode/snowball/v_asbowball.mdl";
new const BALL_MODEL_P[] = "models/royal/mode/snowball/p_snowball.mdl";

new g_iModeSnow;
new g_iCurMode;
new g_bThrowSnow;
new g_iSprite;
new g_iMaxPlayers;
new g_iMdlIndex;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHam(Ham_Item_Deploy, "weapon_smokegrenade", "Item_Deploy_Post", 1);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_smokegrenade", "Weapon_PrimaryAttack_Pre", 0);
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", 0);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", 1);
	RegisterHookChain(RG_ThrowSmokeGrenade, "ThrowSmokeGrenade_Pre", 0);
	
#if defined CAN_FLY_THROUGH_THE_WALLS
	register_forward(FM_ShouldCollide, "ShouldCollide_Pre", false);
#endif // CAN_FLY_THROUGH_THE_WALLS
	
	register_touch(BALL_CLASSNAME, "*", "Engine_TouchSnowBall");
	register_think(BALL_CLASSNAME, "Engine_ThinkSnowBall");
	
	register_message(get_user_msgid("TextMsg"), "Message_TextMsg");
	register_message(get_user_msgid("SendAudio"), "Message_SendAudio");
	register_message(get_user_msgid("CurWeapon"), "Message_CurWeapon");
	
	g_iMaxPlayers = get_member_game(m_nMaxPlayers);
	
	g_iModeSnow = dr_register_mode
	(
		.Name = "DRM_MODE_SNOW",
		.Hud = "DRM_MODE_INFO_SNOW",
		.Mark = "snow",
		.RoundDelay = 3,
		.CT_BlockWeapons = 1,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 0,
		.Hide = 0
	);
}
public plugin_precache()
{
	precache_model(BALL_MODEL_V);
	precache_model(BALL_MODEL_P);
	g_iMdlIndex = precache_model(BALL_MODEL_W);
	g_iSprite = precache_model("sprites/zbeam3.spr");
}
//***** Deathrun Mode *****//
public dr_selected_mode(id, mode)
{
	g_iCurMode = mode;
	
	if(mode == g_iModeSnow)
	{
		g_bThrowSnow = true;
		rg_give_item(id, "weapon_smokegrenade");
	}
}
//************** Message **************//
public Message_TextMsg(msgid, dest, reciver)
{
	if(g_iCurMode != g_iModeSnow) return PLUGIN_CONTINUE;
	
	if(get_msg_args() != 5 || get_msg_argtype(5) != ARG_STRING) return PLUGIN_CONTINUE;

	new arg5[20]; get_msg_arg_string(5, arg5, charsmax(arg5));
	
	if(equal(arg5, "#Fire_in_the_hole")) return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}
public Message_SendAudio(msgid, dest, reciver)
{
	if(g_iCurMode != g_iModeSnow) return PLUGIN_CONTINUE;
	
	if(get_msg_args() != 3 || get_msg_argtype(2) != ARG_STRING) return PLUGIN_CONTINUE;

	new arg2[20]; get_msg_arg_string(2, arg2, charsmax(arg2));
	
	if(equal(arg2[1], "!MRAD_FIREINHOLE")) return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}
public Message_CurWeapon(msgid, dest, reciver)
{
	if(g_iCurMode != g_iModeSnow) return PLUGIN_CONTINUE;

	if(!get_msg_arg_int(1) || get_msg_arg_int(2) != CSW_SMOKEGRENADE) return PLUGIN_CONTINUE;

	if(get_member(reciver, m_iTeam) != TEAM_TERRORIST) return PLUGIN_CONTINUE;
	
	set_msg_arg_int(2, ARG_BYTE, CSW_KNIFE);
	set_msg_arg_int(3, ARG_BYTE, -1);

	return PLUGIN_CONTINUE;
}
//************** Ham **************//
public Item_Deploy_Post(weapon)
{
	if(g_iCurMode != g_iModeSnow) return HAM_IGNORED;
	
	new player = get_member(weapon, m_pPlayer);
	
	if(get_member(player, m_iTeam) == TEAM_TERRORIST)
	{
		set_entvar(player, var_viewmodel, BALL_MODEL_V);
		set_entvar(player, var_weaponmodel, BALL_MODEL_P);
	}
	
	return HAM_IGNORED;
}
public Weapon_PrimaryAttack_Pre(weapon)
{
	if(g_iCurMode != g_iModeSnow) return HAM_IGNORED;
	
	new player = get_member(weapon, m_pPlayer);
	
	if(get_member(player, m_iTeam) == TEAM_TERRORIST)
	{
		rg_set_user_bpammo(player, WEAPON_SMOKEGRENADE, SNOWBALL_AMOUNT);
	}
	
	return HAM_IGNORED;
}
//************** ReGameDll **************//
public CSGameRules_RestartRound_Pre()
{
	if(g_bThrowSnow)
	{
		g_bThrowSnow = false;
	}
}
public CBasePlayer_Spawn_Post(const this)
{
	if(g_iCurMode != g_iModeSnow) return HC_CONTINUE;
	
	if(is_user_alive(this) && get_member(this, m_iTeam) == TEAM_TERRORIST)
	{
		rg_give_item(this, "weapon_smokegrenade");
	}
	
	return HC_CONTINUE;
}
public ThrowSmokeGrenade_Pre(const index, Float:vecStart[3], Float:vecVelocity[3], Float:time, const usEvent)
{
	if(!g_bThrowSnow) return HC_CONTINUE;
	
	if(is_user_alive(index) && get_member(index, m_iTeam) == TEAM_TERRORIST)
	{
		CreateSnowBall(index);
		SetHookChainReturn(ATYPE_INTEGER, 0);
		return HC_SUPERCEDE;
	}
	
	return HC_CONTINUE;
}
CreateSnowBall(id)
{
	new Float:vec_start[3]; get_entvar(id, var_origin, vec_start);
	new Float:view_ofs[3]; get_entvar(id, var_view_ofs, view_ofs);
	xs_vec_add(vec_start, view_ofs, vec_start);
	
	new end_of_view[3]; get_user_origin(id, end_of_view, Origin_AimEndEyes);
	new Float:vec_end[3]; IVecFVec(end_of_view, vec_end);
	
	new Float:velocity[3]; xs_vec_sub(vec_end, vec_start, velocity);
	new Float:normal[3]; xs_vec_normalize(velocity, normal);
	xs_vec_mul_scalar(normal, SNOWBALL_VELOCITY, velocity);
	
	new ent = rg_create_entity("info_target");
	
	set_entvar(ent, var_classname, BALL_CLASSNAME);
	set_entvar(ent, var_owner, id);
	set_entvar(ent, var_movetype, MOVETYPE_BOUNCE);
	set_entvar(ent, var_solid, SOLID_BBOX);
	set_entvar(ent, var_nextthink, get_gametime() + SNOWBALL_LIFETIME);
	set_entvar(ent, var_model, BALL_MODEL_W);
	set_entvar(ent, var_modelindex, g_iMdlIndex);
	set_entvar(ent, var_origin, vec_start);
	new Float:mins[3] = {-3.0, -3.0, -3.0}; set_entvar(ent, var_mins, mins);
	new Float:maxs[3] = {3.0, 3.0, 3.0}; set_entvar(ent, var_maxs, maxs);
	new Float:size[3]; math_mins_maxs(mins, maxs, size);
	set_entvar(ent, var_size, size); 
	set_entvar(ent, var_velocity, velocity);
	
	if(is_entity(ent))
	{
		trail_msg(ent, g_iSprite, 1, 5, { 55, 55, 255 }, 150);
	}
}
public Engine_TouchSnowBall(ent, toucher)
{
	if(!is_entity(ent)) return PLUGIN_CONTINUE;
	
	if(IsPlayer(toucher) && SnowBallTakeDamage(ent, toucher)) return PLUGIN_CONTINUE;
	
#if defined STOP_BALL_AFTER_TOUCH
	set_entvar(ent, var_movetype, MOVETYPE_FLY);
	set_entvar(ent, var_velocity, Float:{0.0, 0.0, 0.0});
#else
	new Float:velocity[3]; get_entvar(ent, var_velocity, velocity);
	xs_vec_mul_scalar(velocity, 0.7, velocity);
	set_entvar(ent, var_velocity, velocity);
#endif // STOP_BALL_AFTER_TOUCH
	return PLUGIN_CONTINUE;
}
SnowBallTakeDamage(snowball, player)
{
	new owner = get_entvar(snowball, var_owner);
	if(is_user_connected(owner))
	{
		if(is_user_alive(player) && get_member(player, m_iTeam) != get_member(owner, m_iTeam))
		{
			ExecuteHamB(Ham_TakeDamage, player, snowball, owner, SNOWBALL_DAMAGE, 0);
			engfunc(EngFunc_RemoveEntity, snowball);
			return 1;
		}
	}
	return 0;
}
public Engine_ThinkSnowBall(ent)
{
	set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_KILLME);
}
#if defined CAN_FLY_THROUGH_THE_WALLS
public ShouldCollide_Pre(ent, toucher)
{
	if(g_iCurMode != g_iModeSnow) return FMRES_IGNORED;
	
	if(IsPlayer(toucher)) return FMRES_IGNORED;
	
	new toucher_classname[32]; get_entvar(toucher, var_classname , toucher_classname, charsmax(toucher_classname));
	if(equal(toucher_classname, BALL_CLASSNAME))
	{
		new ent_classname[32]; get_entvar(ent, var_classname , ent_classname, charsmax(ent_classname));
		if(equal(ent_classname, "func_wall"))
		{
			new Float:FXAmount = Float:get_entvar(ent, var_renderamt);
			if(FXAmount < 200.0)
			{
				forward_return(FMV_CELL, 0); 
				return FMRES_SUPERCEDE;
			}
		}
	}
	return FMRES_IGNORED;
}
#endif // CAN_FLY_THROUGH_THE_WALLS
stock math_mins_maxs(const Float:mins[3], const Float:maxs[3], Float:size[3])
{
	size[0] = (xs_fsign(mins[0]) * mins[0]) + maxs[0];
	size[1] = (xs_fsign(mins[1]) * mins[1]) + maxs[1];
	size[2] = (xs_fsign(mins[2]) * mins[2]) + maxs[2];
}
stock trail_msg(ent, sprite, lifetime, size, color[3], alpha)
{
	enum { red, green, blue}
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);// TE_BEAMFOLLOW
	write_short(ent);
	write_short(sprite);//sprite
	write_byte(lifetime * 10);//lifetime
	write_byte(size);//size
	write_byte(color[red]);//r
	write_byte(color[green]);//g
	write_byte(color[blue]);//b
	write_byte(alpha);//alpha
	message_end();
}
