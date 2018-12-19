#include <amxmodx>
#include <fun>
#include <hamsandwich>
#include <deathrun_modes>

#define PLUGIN "Deathrun Mode: Free"
#define VERSION "Re 1.0.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

new g_iModeFree, g_iCurMode;
new HookChain:g_hAddPlayerItem;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	DisableHookChain(g_hAddPlayerItem = RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "CBasePlayer_AddPlayerItem_Pre", 0));
	
	g_iModeFree = dr_register_mode
	(
		.Name = "DRM_MODE_FREE",
		.Hud = "DRM_MODE_INFO_FREE",
		.Mark = "free",
		.RoundDelay = 0,
		.CT_BlockWeapons = 1,
		.TT_BlockWeapons = 1,
		.CT_BlockButtons = 0,
		.TT_BlockButtons = 1,
		.Bhop = 1,
		.Usp = 0,
		.Hide = 0
	);
}
//***** ReGameDll *****//
public CBasePlayer_AddPlayerItem_Pre(const this, const pItem)
{
	if(get_member(pItem, m_iId) == CSW_KNIFE) return HC_CONTINUE;
	
	client_print(this, print_center, "В данном режиме оружия запрещены");
	SetHookChainReturn(ATYPE_INTEGER, false);
	return HC_SUPERCEDE;
}
//***** Deathrun Modes *****//
public dr_selected_mode(id, mode)
{
	if(g_iCurMode == g_iModeFree)
	{
		DisableHookChain(g_hAddPlayerItem);
	}
	
	g_iCurMode = mode;
	
	if(mode == g_iModeFree)
	{
		EnableHookChain(g_hAddPlayerItem);
	}
}
