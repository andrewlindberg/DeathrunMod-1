#include <amxmodx>
#include <engine>
#include <reapi>

#define PLUGIN "Deathrun: Teleport Spot"
#define VERSION "Re 1.0.2"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define RETURN_DAMAGE_TO_ATTACKER
#define TP_CHECK_DISTANCE 64.0

#define IsPlayer(%1) (%1 && %1 <= g_iMaxPlayers)

new player_solid[33], g_iMaxPlayers;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	new ent = rg_find_ent_by_class(-1, "info_teleport_destination");
	
	if(!is_entity(ent))
	{
		log_amx("Map doesn't have any teleports.");
		pause("a"); return;
	}
	
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", 0);
	
	g_iMaxPlayers = get_member_game(m_nMaxPlayers);
}
public CBasePlayer_TakeDamage_Pre(const this, pevInflictor, pevAttacker, Float:flDamage, bitsDamageType)
{
	if(this != pevAttacker && IsPlayer(pevAttacker) && get_member(this, m_iTeam) != get_member(pevAttacker, m_iTeam))
	{
		new Float:origin[3]; get_entvar(this, var_origin, origin);
		new ent = -1;
		while((ent = find_ent_in_sphere(ent, origin, TP_CHECK_DISTANCE)))
		{
			new classname[32]; get_entvar(ent, var_classname, classname, charsmax(classname));
			if(equal(classname, "info_teleport_destination"))
			{
				if(is_user_alive(pevAttacker)) slap(pevAttacker);
				if(is_user_alive(this)) slap(this);

#if defined RETURN_DAMAGE_TO_ATTACKER
				SetHookChainArg(1, ATYPE_INTEGER, pevAttacker);
				SetHookChainArg(3, ATYPE_INTEGER, this);
#else
				SetHookChainReturn(ATYPE_INTEGER, 0);
				return HC_SUPERCEDE;
#endif
			}
		}
	}
	return HC_CONTINUE;
}
slap(id)
{
	new solid = get_entvar(id, var_solid);
	if(solid != SOLID_NOT) player_solid[id] = solid;
	
	set_entvar(id, var_solid, SOLID_NOT);
	
	user_slap(id, 0);
	user_slap(id, 0);
	
	remove_task(id);
	set_task(0.3, "restore_solid", id);
}
public restore_solid(id)
{
	if(is_user_alive(id)) set_entvar(id, var_solid, player_solid[id]);
}