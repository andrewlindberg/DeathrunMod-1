#include <amxmodx>
#include <reapi>
#include <deathrun_modes>

#pragma semicolon 1

#define NUM_RESPAWN 2
#define COUNTDOWN 3

enum SIcon_Status
{
	SIcon_Hide,
	SIcon_Show,
	SIcon_Flash
};

enum (+=100)
{
	TASK_RESPAWN = 100
};

enum _:sounds_struct
{
	m_Respawn,
	m_Heartbeat,
	m_Farts
};

enum FuncCBasePlayer
{
	HookChain:RG_PlayerSpawn_Pre,
	HookChain:RG_PlayerKilled_Post
};

new g_eSoundData[sounds_struct][64] =
{
	"royal/autorespawn/spawn.wav", 
	"royal/autorespawn/heartbeat.wav", 
	"royal/autorespawn/farts.wav"
};

new g_iCurMode, g_iModeDuel;
new g_bRoundEnd = false;
new g_iRespawnCount[33];
new g_hCBaseData[FuncCBasePlayer];

public plugin_precache()
{
	precache_sound(g_eSoundData[m_Respawn]);
	precache_sound(g_eSoundData[m_Heartbeat]);
	precache_sound(g_eSoundData[m_Farts]);
}

public plugin_init()
{
	register_plugin("Deathrun: Auto Respawn", "Re 0.5", "PRoSToG4mer");
	
	RegisterHookChain(RG_RoundEnd, "RG_RoundEnd_Pre", 0);
	g_hCBaseData[RG_PlayerSpawn_Pre] = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre", 0);
	g_hCBaseData[RG_PlayerKilled_Post] = RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", 1);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", 0);
}

public plugin_cfg()
{
	g_iModeDuel = dr_get_mode_by_mark("duel");
	
	DisableHookChain(g_hCBaseData[RG_PlayerSpawn_Pre]);
	DisableHookChain(g_hCBaseData[RG_PlayerKilled_Post]);
}

public dr_selected_mode(id, mode)
{
	g_iCurMode = mode;
}

public client_disconnect(id)
{
	remove_task(id + TASK_RESPAWN);
}

public RG_RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	g_bRoundEnd = true;
}

public CBasePlayer_Spawn_Pre(this)
{
	remove_task(this + TASK_RESPAWN);
}

public CBasePlayer_Killed_Post(this, pevAttacker, iGib)
{
	if (g_iCurMode == g_iModeDuel)
	{
		return HC_CONTINUE;
	}
	
	if (get_member_game(m_iNumCT) < 2)
	{
		return HC_CONTINUE;
	}

	if (get_member(this, m_iTeam) != TEAM_CT)
	{
		return HC_CONTINUE;
	}

	ActivateIcon(this, SIcon_Show);
	
	if (!g_iRespawnCount[this])
	{
		client_print(this, print_center, "Вы достигли лимита возраждений за раунд!");
		return HC_CONTINUE;
    }
	
	rg_send_audio(this, g_eSoundData[m_Heartbeat]);
	set_task(COUNTDOWN.0, "Task_Respawn", this + TASK_RESPAWN);
	rg_send_bartime(this, COUNTDOWN, false);
	
	client_print(this, print_center, "Вы возродитесь через %d секунд.", COUNTDOWN);
	return HC_CONTINUE;
}

public CSGameRules_RestartRound_Pre()
{
	if (get_member_game(m_bCompleteReset))
    {
		EnableHookChain(g_hCBaseData[RG_PlayerSpawn_Pre]);
		EnableHookChain(g_hCBaseData[RG_PlayerKilled_Post]);
	}
	
	new iPlayers[32], pnum; 
	get_players(iPlayers, pnum, "eh", "CT");
	for (new i = 0; i < pnum; i++)
	{
		if (is_user_connected(i))
		{
			g_iRespawnCount[i] = NUM_RESPAWN;
		}
	}
}

public Task_Respawn(id)
{
	id -= TASK_RESPAWN;
	
	if (!is_user_connected(id))
	{
		return;
	}
	
	if (g_iCurMode != g_iModeDuel && !g_bRoundEnd)
	{
		g_iRespawnCount[id]--;
		
		ActivateIcon(id, SIcon_Hide);
		rg_send_audio(id, g_eSoundData[m_Respawn]);
		rg_round_respawn(id);
	}
	else
	{
		rg_send_audio(id, g_eSoundData[m_Farts]);
	}
}

ActivateIcon(id, SIcon_Status:status)
{
	new szSprite[12]; formatex(szSprite, 11, "number_%d", g_iRespawnCount[id]);
	
	if(szSprite[0])
	{
		enum colors { red, green };
		
		new rgb[colors][3] =
		{
			{ 255, 0, 0 },
			{ 0, 255, 0 }
		};
		
		UTIL_StatusIcon(id, szSprite, g_iRespawnCount[id] ? rgb[green] : rgb[red], status);
	}
}

stock UTIL_StatusIcon(id, sprite[], color[3] = {0, 0, 0}, SIcon_Status:status)
{
	enum { red, green, blue };
	static msg_statusicon; if(!msg_statusicon) msg_statusicon = get_user_msgid("StatusIcon");
	message_begin(MSG_ONE, msg_statusicon, _, id);
	write_byte(_:status); // status (0=hide, 1=show, 2=flash)
	write_string(sprite); // sprite name
	write_byte(color[red]); // red
	write_byte(color[green]); // green
	write_byte(color[blue]); // blue
	message_end();
}

