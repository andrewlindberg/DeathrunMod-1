#include <amxmodx>
#include <engine>
#include <reapi>
#include <deathrun_modes>

#define DOOR_CHECK_DISTANCE 280.0

#pragma semicolon 1

public plugin_init()
{
	register_plugin("Deathrun: noclip door arctic", "0.1", "PRoSToG4mer");

	new mapname[32]; rh_get_mapname(mapname, charsmax(mapname), MNT_TRUE);
	if(!equal(mapname, "deathrun_arctic"))
	{
		pause("a"); return;
	}
	
	new ent = rg_find_ent_by_class(-1, "info_player_start", false);
	new Float:origin[3]; get_entvar(ent, var_origin, origin);
	ent = -1;
	while((ent = find_ent_in_sphere(ent, origin, DOOR_CHECK_DISTANCE)))
	{
		new classname[32]; get_entvar(ent, var_classname, classname, charsmax(classname));
		if (equal(classname, "func_door_rotating"))
		{
			set_entvar(ent, var_solid, SOLID_TRIGGER);
			set_entvar(ent, var_movetype, MOVETYPE_NOCLIP);
			rg_set_entity_rendering(ent, kRenderFxGlowShell, .render = kRenderTransAdd, .amount = 100.0);
		}
	}
}

