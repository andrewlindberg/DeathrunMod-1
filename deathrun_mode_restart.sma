#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <deathrun_core>
#include <deathrun_modes>

#pragma semicolon 1

#define PLUGIN "Deathrun Mode: Restart"
#define VERSION "Re 0.1"
#define AUTHOR "CS Royal Project"

#define TASKID_UPDATE 13647454

new g_iModeRestart;
new g_iCurMode;
new g_iDuration;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	g_iModeRestart = dr_register_mode
	(
		.Name = "DRM_MODE_RESTART",
		.Hud = "",
		.Mark = "restart",
		.RoundDelay = 0,
		.CT_BlockWeapons = 1,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 1,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 0,
		.Hide = 1
	);
}
/* ******** Deathrun Core ******** */
public dr_warm_up(duration)
{
	if(duration > 0)
	{
		g_iDuration = duration - 1;
		dr_set_mode(g_iModeRestart, 1);
	}
}
/* ******** Deathrun Modes ******** */
public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeRestart)
	{
		remove_task(TASKID_UPDATE);
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeRestart)
	{
		set_task_ex(1.0, "Task_UpdateInfo", TASKID_UPDATE, .flags = SetTask_RepeatTimes, .repeat = g_iDuration);
	}
}
/* ******** Task ******** */
public Task_UpdateInfo()
{
	new szDuration[MAX_NAME_LENGTH/4];
	num_to_str(--g_iDuration, szDuration, charsmax(szDuration));
	dr_set_mode_addinfo(szDuration);
}