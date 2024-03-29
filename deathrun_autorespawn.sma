#include <amxmodx>
#include <reapi>
#include <deathrun_modes>

#pragma semicolon 1

#define RESPAWN_NUM 2
#define RESPAWN_DELAY 3

enum 
{
	SIcon_Hide,
	SIcon_Show
};

enum (+=100)
{
	TaskId_Respawn = 857419
};

enum _:Sounds
{
	Sound_Respawn,
	Sound_Heartbeat,
	Sound_Farts
};

enum _:Hooks
{
	HookChain:Hook_PlayerSpawn,
	HookChain:Hook_PlayerKilled
};

new g_eSoundData[Sounds][MAX_RESOURCE_PATH_LENGTH] =
{
	"royal/autorespawn/spawn.wav", 
	"royal/autorespawn/heartbeat.wav", 
	"royal/autorespawn/farts.wav"
};

new g_iModeDuel;
new g_iRespawnCount[33];
new g_hCSGameRules[Hooks];

public plugin_precache()
{
	precache_sound(g_eSoundData[Sound_Respawn]);
	precache_sound(g_eSoundData[Sound_Heartbeat]);
	precache_sound(g_eSoundData[Sound_Farts]);
}

public plugin_init()
{
	register_plugin("Deathrun: Auto Respawn", "Re 0.7", "PRoSToG4mer");
	
	RegisterHookChain(RG_RoundEnd, "RG_RoundEnd_Pre", 0);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", 1);
	DisableHookChain(g_hCSGameRules[Hook_PlayerSpawn] = RegisterHookChain(RG_CSGameRules_PlayerSpawn, "CSGameRules_PlayerSpawn_Post", 1));
	DisableHookChain(g_hCSGameRules[Hook_PlayerKilled] = RegisterHookChain(RG_CSGameRules_PlayerKilled, "CSGameRules_PlayerKilled_Post", 1));
}

public plugin_cfg()
{
	g_iModeDuel = dr_get_mode_by_mark("duel");
}

public dr_selected_mode(id, mode)
{
	if(mode == g_iModeDuel)
	{
		remove_all_task();
	}
}

public client_disconnected(id)
{
	remove_task(id + TaskId_Respawn);
}

public RG_RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	remove_all_task();
}

public CSGameRules_RestartRound_Post()
{
	new players[32], pnum; get_players(players, pnum, "ceh", "CT");
	for(new i = 0, player; i < pnum; i++)
	{
		player = players[i];
		if(is_user_connected(player))
		{
			g_iRespawnCount[player] = RESPAWN_NUM;
		}
	}
	
	if(pnum > 2)
	{
		EnableHookChain(g_hCSGameRules[Hook_PlayerSpawn]);
		EnableHookChain(g_hCSGameRules[Hook_PlayerKilled]);
	}
	else
	{
		DisableHookChain(g_hCSGameRules[Hook_PlayerSpawn]);
		DisableHookChain(g_hCSGameRules[Hook_PlayerKilled]);
	}
}

public CSGameRules_PlayerSpawn_Post(const index)
{
	remove_task(index + TaskId_Respawn);
	rg_send_bartime(index, 0, false);
}

public CSGameRules_PlayerKilled_Post(const victim, const killer, const inflictor)
{
	if(get_member(victim, m_iTeam) != TEAM_CT) return HC_CONTINUE;
	
	ActivateIcon(victim, SIcon_Show);
	
	if(!g_iRespawnCount[victim])
	{
		rg_send_audio(victim, g_eSoundData[Sound_Farts]);
		client_print(victim, print_center, "Вы достигли лимита возраждений за раунд!");
		return HC_CONTINUE;
	}
	
	rg_send_audio(victim, g_eSoundData[Sound_Heartbeat]);
	set_task(RESPAWN_DELAY.0, "Task_Respawn", victim + TaskId_Respawn);
	rg_send_bartime(victim, RESPAWN_DELAY, false);
	
	client_print(victim, print_center, "Вы возродитесь через %d секунд.", RESPAWN_DELAY);
	return HC_CONTINUE;
}

public Task_Respawn(id)
{
	id -= TaskId_Respawn;
	
	if(get_member(id, m_iTeam) == TEAM_CT)
	{
		g_iRespawnCount[id]--;
		
		ActivateIcon(id, SIcon_Hide);
		rg_send_audio(id, g_eSoundData[Sound_Respawn]);
		rg_round_respawn(id);
	}
}

remove_all_task()
{
	new iPlayers[32], pnumct; get_players(iPlayers, pnumct, "beh", "CT");
	for(new i = 0, player; i < pnumct; i++)
	{
		player = iPlayers[i];
		
		if(task_exists(player + TaskId_Respawn))
		{
			remove_task(player + TaskId_Respawn);
			rg_send_bartime(player, 0, false);
		}
	}
}

ActivateIcon(id, status)
{
	new szSprite[12]; formatex(szSprite, 11, "number_%d", g_iRespawnCount[id]);
	
	if(szSprite[0])
	{
		enum colors { red, green };
		
		new rgb[colors][3] = {
			{ 255, 0, 0 },
			{ 0, 255, 0 }
		};
		
		UTIL_StatusIcon(id, szSprite, g_iRespawnCount[id] > 0 ? rgb[green] : rgb[red], status);
	}
}

stock UTIL_StatusIcon(index, sprite[], color[3] = {0, 0, 0}, status)
{
	enum { red, green, blue };
	static msgStatusIcon;

	if(msgStatusIcon || (msgStatusIcon = get_user_msgid("StatusIcon")))
	{
		message_begin(index ? MSG_ONE : MSG_ALL, msgStatusIcon, .player = index);
		write_byte(status); // status (0=hide, 1=show, 2=flash)
		write_string(sprite); // sprite name
		
		if(status)
		{
			write_byte(color[red]);
			write_byte(color[green]);
			write_byte(color[blue]);
		}
		
		message_end(); 
	}
}