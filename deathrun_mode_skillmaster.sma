#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <deathrun_core>
#include <deathrun_modes>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Skill Master"
#define VERSION "Re 1.0.1"
#define AUTHOR "Mistrick"

enum { NONE_MODE = 0 };

enum SIcon_Status
{
	SIcon_Hide,
	SIcon_Show,
	SIcon_Flash
};

enum Skills
{
	SKILL_PLEASE_STOP,
	SKILL_BURN_BABY_BURN,
	SKILL_KICK_IN_THE_ASS
};

#define SKILL_PLEASE_STOP_COOLDOWN 30
#define SKILL_BURN_BABY_BURN_COOLDOWN 45
#define SKILL_KICK_IN_THE_ASS_COOLDOWN 45

new g_bSkillInCooldown[Skills];
new g_fSkillCooldowns[Skills] =
{
	SKILL_PLEASE_STOP_COOLDOWN,
	SKILL_BURN_BABY_BURN_COOLDOWN,
	SKILL_KICK_IN_THE_ASS_COOLDOWN
};

new g_SkillIcons[Skills][] =
{
	"dmg_rad",
	"dmg_heat",
	"dmg_shock"
};

new g_iSkillColors[Skills][3] = 
{
	{0, 255, 85},
	{255, 123, 0},
	{255, 238, 0}
};

new g_iModeSkillMaster;
new g_iCurMode;
new g_iTerrorist;
new HookChain:g_hPreThink;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd("drop", "Command_Drop");
	register_impulse(100, "Impulse_Flashlight");
	DisableHookChain(g_hPreThink = RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink_Pre", 0));
	
	g_iModeSkillMaster = dr_register_mode
	(
		.Name = "DRM_MODE_SKILLMASTER",
		.Hud = "DRM_MODE_INFO_SKILLMASTER",
		.Mark = "skillmaster",
		.RoundDelay = 0,
		.CT_BlockWeapons = 0,
		.TT_BlockWeapons = 0,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 1,
		.Hide = 0
	);
}
public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeSkillMaster) 
	{
		DisableHookChain(g_hPreThink);
		for(new Skills:skill; skill < Skills; skill++)
		{
			remove_task(_:skill);
		}
	}

	g_iCurMode = mode;
	
	if(mode == g_iModeSkillMaster)
	{
		dr_chosen_new_terrorist(id);
		EnableHookChain(g_hPreThink);
	}
}
public dr_chosen_new_terrorist(id)
{
	g_iTerrorist = id;
	
	if(!id || g_iCurMode != g_iModeSkillMaster) return;
	
	for(new Skills:i; i < Skills; i++)
	{
		if(g_SkillIcons[i][0])
		{
			new colors[3]; colors = g_iSkillColors[i];
			UTIL_StatusIcon(id, g_SkillIcons[i], SIcon_Show, colors[0], colors[1], colors[2]);
		}
		
		g_bSkillInCooldown[i] = false;
		remove_task(_:i);
	}
}
public CBasePlayer_PreThink_Pre(const this)
{
	if(this != g_iTerrorist || !is_user_alive(this)) return HC_CONTINUE;
	
	new buttons = get_entvar(this, var_button);
	new oldbuttons = get_entvar(this, var_oldbuttons);
	
	if(buttons & IN_RELOAD && ~oldbuttons & IN_RELOAD)
	{
		ActivateSkill(SKILL_PLEASE_STOP);
	}
	
	return HC_CONTINUE;
}
public Impulse_Flashlight(id)
{
	if(g_iCurMode != g_iModeSkillMaster || id != g_iTerrorist || !is_user_alive(id)) return PLUGIN_CONTINUE;
	
	if(g_bSkillInCooldown[SKILL_BURN_BABY_BURN]) return PLUGIN_CONTINUE;
	
	ActivateSkill(SKILL_BURN_BABY_BURN);
	
	return PLUGIN_HANDLED;
}
public Command_Drop(id)
{
	if(g_iCurMode != g_iModeSkillMaster || id != g_iTerrorist || !is_user_alive(id)) return PLUGIN_CONTINUE;
	
	if(g_bSkillInCooldown[SKILL_KICK_IN_THE_ASS]) return PLUGIN_CONTINUE;
	
	ActivateSkill(SKILL_KICK_IN_THE_ASS);
	
	return PLUGIN_HANDLED;
}
ActivateSkill(Skills:skill)
{
	if(g_bSkillInCooldown[skill]) return;
	
	g_bSkillInCooldown[skill] = true;
	set_task(float(g_fSkillCooldowns[skill]), "Task_SkillCooldowns", _:skill);
	
	if(g_SkillIcons[skill][0])
	{
		new colors[3]; colors = g_iSkillColors[skill];
		UTIL_StatusIcon(g_iTerrorist, g_SkillIcons[skill], SIcon_Flash, colors[0], colors[1], colors[2]);
	}
	
	new players[32], pnum, id;
	get_players(players, pnum, "ae", "CT");
	
	switch(skill)
	{
		case SKILL_PLEASE_STOP:
		{
			// stop all ct
			for(new i; i < pnum; i++)
			{
				id = players[i];
				set_entvar(id, var_velocity, Float:{ 0.0, 0.0, 0.0 });
			}
		}
		case SKILL_BURN_BABY_BURN:
		{
			// hit all ct
			for(new i; i < pnum; i++)
			{
				id = players[i];
				ExecuteHam(Ham_TakeDamage, id, 0, 0, random_float(20.0, 50.0), DMG_BURN);
			}
		}
		case SKILL_KICK_IN_THE_ASS:
		{
			// add random velocity for all ct
			for(new i, Float:velocity[3]; i < pnum; i++)
			{
				id = players[i];
				get_entvar(id, var_velocity, velocity);
				
				velocity[0] += random_float(-200.0, 200.0);
				velocity[1] += random_float(-200.0, 200.0);
				velocity[2] += random_float(0.0, 200.0);
				
				set_entvar(id, var_velocity, velocity);
			}
		}
	}
}
public Task_SkillCooldowns(Skills:skill)
{
	g_bSkillInCooldown[skill] = false;
	
	if(g_SkillIcons[skill][0])
	{
		new colors[3]; colors = g_iSkillColors[skill];
		UTIL_StatusIcon(g_iTerrorist, g_SkillIcons[skill], SIcon_Show, colors[0], colors[1], colors[2]);
	}
}
stock UTIL_StatusIcon(id, sprite[], SIcon_Status:status, red, green, blue)
{
	static msg_statusicon; if(!msg_statusicon) msg_statusicon = get_user_msgid("StatusIcon");
	message_begin(MSG_ONE, msg_statusicon, _, id);
	write_byte(_:status); // status (0=hide, 1=show, 2=flash)
	write_string(sprite); // sprite name
	write_byte(red); // red
	write_byte(green); // green
	write_byte(blue); // blue
	message_end();
}
