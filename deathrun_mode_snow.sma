#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Snow"
#define VERSION "Re 1.1.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define IsPlayer(%0) (%0 && %0 <= g_iMaxPlayers)

#define CAN_FLY_THROUGH_THE_WALLS
// #define STOP_BALL_AFTER_TOUCH
// #define AUTOTARGET

#define SNOWBALL_AMOUNT 2
#define SNOWBALL_DAMAGE 25.0
#define SNOWBALL_VELOCITY 1800.0
#define SNOWBALL_LIFETIME 5.0

#define AUTOTARGET_RANGE 64.0
#define AUTOTARGET_DELAY 1.0

enum _:ForwardType
{
	HamHook:FType_Deploy,
	HamHook:FType_PrimaryAttack,
	HookChain:FType_Spawn,
	HookChain:FType_ThrowSmokeGrenade,
	FType_ShouldCollide,
	FType_Touch,
	FType_Think,
	FType_TextMsg,
	FType_SendAudio,
	FType_CurWeapon,
}

enum _:MessageType
{
	MType_TextMsg,
	MType_SendAudio,
	MType_CurWeapon,
}

new const BALL_CLASSNAME[] = "snow_ball";
new const BALL_MODEL_W[] = "models/royal/mode/snowball/w_snowball.mdl";
new const BALL_MODEL_V[] = "models/royal/mode/snowball/v_asbowball.mdl";
new const BALL_MODEL_P[] = "models/royal/mode/snowball/p_snowball.mdl";

new Float:HIT_MUL[9] = {
	0.0, // generic
	3.0, // head
	1.2, // chest
	1.1, // stomach
	0.9, // leftarm
	0.9, // rightarm
	0.75, // leftleg
	0.75, // rightleg
	0.0, // shield
};

new g_iModeSnow;
new g_iCurMode;
new g_iSprite;
new g_iMaxPlayers;
new g_iMdlIndex;
new g_iForwardsId[ForwardType];
new g_iMessageId[MessageType];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	DisableHamForward(g_iForwardsId[FType_Deploy] = RegisterHam(Ham_Item_Deploy, "weapon_smokegrenade", "Item_Deploy_Post", 1));
	DisableHamForward(g_iForwardsId[FType_PrimaryAttack] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_smokegrenade", "Weapon_PrimaryAttack_Pre", 0));
	
	DisableHookChain(g_iForwardsId[FType_Spawn] = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", 1));
	DisableHookChain(g_iForwardsId[FType_ThrowSmokeGrenade] = RegisterHookChain(RG_ThrowSmokeGrenade, "ThrowSmokeGrenade_Pre", 0));
	
	register_touch(BALL_CLASSNAME, "*", "Engine_TouchSnowBall");
	register_think(BALL_CLASSNAME, "Engine_ThinkSnowBall");
	
	g_iMessageId[MType_TextMsg] = get_user_msgid("TextMsg");
	g_iMessageId[MType_SendAudio] = get_user_msgid("SendAudio");
	g_iMessageId[MType_CurWeapon] = get_user_msgid("CurWeapon");
	
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
	if(g_iCurMode == g_iModeSnow)
	{
		DisableForward();
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeSnow)
	{
		EnableForward();
		rg_give_item(id, "weapon_smokegrenade");
	}
}
DisableForward()
{
	DisableHamForward(g_iForwardsId[FType_Deploy]);
	DisableHamForward(g_iForwardsId[FType_PrimaryAttack]);
	DisableHookChain(g_iForwardsId[FType_Spawn]);
	DisableHookChain(g_iForwardsId[FType_ThrowSmokeGrenade]);
#if defined CAN_FLY_THROUGH_THE_WALLS
	unregister_forward(FM_ShouldCollide, g_iForwardsId[FType_ShouldCollide], false);
#endif // CAN_FLY_THROUGH_THE_WALLS
	unregister_message(g_iMessageId[MType_TextMsg], g_iForwardsId[FType_TextMsg]);
	unregister_message(g_iMessageId[MType_SendAudio], g_iForwardsId[FType_SendAudio]);
	unregister_message(g_iMessageId[MType_CurWeapon], g_iForwardsId[FType_CurWeapon]);
}
EnableForward()
{
	EnableHamForward(g_iForwardsId[FType_Deploy]);
	EnableHamForward(g_iForwardsId[FType_PrimaryAttack]);
	EnableHookChain(g_iForwardsId[FType_Spawn]);
	EnableHookChain(g_iForwardsId[FType_ThrowSmokeGrenade]);
#if defined CAN_FLY_THROUGH_THE_WALLS
	g_iForwardsId[FType_ShouldCollide] = register_forward(FM_ShouldCollide, "ShouldCollide_Pre", false);
#endif // CAN_FLY_THROUGH_THE_WALLS
	g_iForwardsId[FType_TextMsg] = register_message(g_iMessageId[MType_TextMsg], "Message_TextMsg");
	g_iForwardsId[FType_SendAudio] = register_message(g_iMessageId[MType_SendAudio], "Message_SendAudio");
	g_iForwardsId[FType_CurWeapon] = register_message(g_iMessageId[MType_CurWeapon], "Message_CurWeapon");
}
//************** Message **************//
public Message_TextMsg(msgid, dest, reciver)
{
	if(get_msg_args() != 5 || get_msg_argtype(5) != ARG_STRING) return PLUGIN_CONTINUE;
	
	new arg5[20]; get_msg_arg_string(5, arg5, charsmax(arg5));
	
	if(equal(arg5, "#Fire_in_the_hole")) return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}
public Message_SendAudio(msgid, dest, reciver)
{
	if(get_msg_args() != 3 || get_msg_argtype(2) != ARG_STRING) return PLUGIN_CONTINUE;
	
	new arg2[20]; get_msg_arg_string(2, arg2, charsmax(arg2));
	
	if(equal(arg2[1], "!MRAD_FIREINHOLE")) return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}
public Message_CurWeapon(msgid, dest, reciver)
{
	if(!get_msg_arg_int(1) || get_msg_arg_int(2) != CSW_SMOKEGRENADE) return PLUGIN_CONTINUE;
	
	if(get_member(reciver, m_iTeam) != TEAM_TERRORIST) return PLUGIN_CONTINUE;
	
	set_msg_arg_int(2, ARG_BYTE, CSW_KNIFE);
	set_msg_arg_int(3, ARG_BYTE, -1);
	
	return PLUGIN_CONTINUE;
}
//************** Ham **************//
public Item_Deploy_Post(weapon)
{
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
	new player = get_member(weapon, m_pPlayer);
	
	if(get_member(player, m_iTeam) == TEAM_TERRORIST)
	{
		rg_set_user_bpammo(player, WEAPON_SMOKEGRENADE, SNOWBALL_AMOUNT);
	}
	
	return HAM_IGNORED;
}
//************** ReGameDll **************//
public CBasePlayer_Spawn_Post(const this)
{
	if(is_user_alive(this) && get_member(this, m_iTeam) == TEAM_TERRORIST)
	{
		rg_give_item(this, "weapon_smokegrenade");
	}
}
public ThrowSmokeGrenade_Pre(const index, Float:vecStart[3], Float:vecVelocity[3], Float:time, const usEvent)
{
	if(!is_user_alive(index) || get_member(index, m_iTeam) != TEAM_TERRORIST) return HC_CONTINUE;
	
	CreateSnowBall(index);
	SetHookChainReturn(ATYPE_INTEGER, 0);
	return HC_SUPERCEDE;
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
	set_entvar(ent, var_fuser1, get_gametime() + SNOWBALL_LIFETIME);
	set_entvar(ent, var_nextthink, get_gametime() + 0.1);
	set_entvar(ent, var_model, BALL_MODEL_W);
	set_entvar(ent, var_modelindex, g_iMdlIndex);
	set_entvar(ent, var_origin, vec_start);
	
	new Float:mins[3] = { -3.0, -3.0, -3.0 };
	set_entvar(ent, var_mins, mins);
	new Float:maxs[3] = { 3.0, 3.0, 3.0 };
	set_entvar(ent, var_maxs, maxs);
	new Float:size[3];
	math_mins_maxs(mins, maxs, size);
	
	set_entvar(ent, var_size, size); 
	set_entvar(ent, var_velocity, velocity);
	
	set_task(0.1, "Task_SetTrail", ent);
}
public Task_SetTrail(ent)
{
	if(is_entity(ent))
	{
		trail_msg(ent, g_iSprite, 5, 8, 55, 55, 255, 150);
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
			new hit_zone = get_hit_zone(player, snowball);
			set_member(player, m_LastHitGroup, hit_zone);
			
			ExecuteHamB(Ham_TakeDamage, player, snowball, owner, SNOWBALL_DAMAGE * HIT_MUL[hit_zone], 0);
			set_entvar(snowball, var_flags, get_entvar(snowball, var_flags) | FL_KILLME);
			return 1;
		}
	}
	return 0;
}
public Engine_ThinkSnowBall(ent)
{
	new Float:gametime = get_gametime();
	
	if(gametime >= Float: get_entvar(ent, var_fuser1))
	{
		set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_KILLME);
		return;
	}
	
	set_entvar(ent, var_nextthink, gametime + 0.1);
	
#if defined AUTOTARGET
	if(get_entvar(ent, var_fuser2) > gametime) return;
	
	new p = -1;
	new target = 0;
	new Float:dist = -1.0;
	new Float:origin[3], Float:porigin[3];
	get_entvar(ent, var_origin, origin);
	
	new owner = get_entvar(ent, var_owner);
	
	while((p = engfunc(EngFunc_FindEntityInSphere, p, origin, AUTOTARGET_RANGE)))
	{
		if(p > 32) break;
		
		if(!is_user_alive(p)) continue;
		
		if(get_member(p, m_iTeam) == get_member(owner, m_iTeam)) continue;
		
		get_entvar(p, var_origin, porigin);
		new Float:d = vector_distance(origin, porigin);
		if(dist == -1.0 || dist > d)
		{
			dist = d;
			target = p;
		}
	}
	
	if(target)
	{
		new Float:velocity[3];
		get_entvar(ent, var_velocity, velocity);
		
		entity_set_follow(ent, target, vector_length(velocity), !random_num(0, 5));
		set_entvar(ent, var_fuser2, gametime + AUTOTARGET_DELAY);
	}
#endif
}
#if defined CAN_FLY_THROUGH_THE_WALLS
public ShouldCollide_Pre(ent, toucher)
{
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

stock get_hit_zone(player, ent)
{
	new Float:porigin[3], Float:eorigin[3];
	get_entvar(player, var_origin, porigin);
	get_entvar(ent, var_origin, eorigin);
	
	new Float:point[3];
	get_entvar(ent, var_velocity, point);
	xs_vec_normalize(point, point);
	xs_vec_mul_scalar(point, 32.0, point);
	xs_vec_sub(eorigin, point, eorigin);
	xs_vec_mul_scalar(point, 4.0, point);
	xs_vec_add(eorigin, point, porigin);
	
	new trace = 0;
	engfunc(EngFunc_TraceLine, eorigin, porigin, DONT_IGNORE_MONSTERS, ent, trace);
	
	return get_tr2(trace, TR_iHitgroup);
}

trail_msg(ent, sprite, lifetime, size, r, g, b, alpha)
{
	message_begin(MSG_ALL, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);// TE_BEAMFOLLOW
	write_short(ent);
	write_short(sprite);//sprite
	write_byte(lifetime * 10);//lifetime
	write_byte(size);//size
	write_byte(r);//r
	write_byte(g);//g
	write_byte(b);//b
	write_byte(alpha);//alpha
	message_end();
}

stock entity_set_follow(entity, target, Float:speed, bool:head)
{
	if (!is_entity(entity) || !is_entity(target)) return 0;
	
	new Float:entity_origin[3], Float:target_origin[3];
	get_entvar(entity, var_origin, entity_origin);
	get_entvar(target, var_origin, target_origin);
	
	if(head)
	{
		new Float:view_ofs[3];
		get_entvar(target, var_view_ofs, view_ofs);
		xs_vec_add(target_origin, view_ofs, target_origin);
	}
	
	new Float:diff[3];
	diff[0] = target_origin[0] - entity_origin[0];
	diff[1] = target_origin[1] - entity_origin[1];
	diff[2] = target_origin[2] - entity_origin[2];
	
	new Float:length = floatsqroot(floatpower(diff[0], 2.0) + floatpower(diff[1], 2.0) + floatpower(diff[2], 2.0));
	
	new Float:Velocity[3];
	Velocity[0] = diff[0] * (speed / length);
	Velocity[1] = diff[1] * (speed / length);
	Velocity[2] = diff[2] * (speed / length);
	
	set_entvar(entity, var_velocity, Velocity);
	
	return 1;
}