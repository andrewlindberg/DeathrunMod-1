#if defined _deathrun_duel_included
  #endinput
#endif
#define _deathrun_duel_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib deathrun_duel
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib deathrun_duel
	#endif
#else
	#pragma library deathrun_duel
#endif

enum CancelType
{
	CType_TimeOver,
	CType_PlayerDisconneced,
	CType_PlayerDied,
	CType_ModeChanged
}

/**
 * Get current duel.
 * 
 * @param name				Duel name, here will be copied the current mode ML key.
 * @param size				Name size.
 * 
 * @return					Duel index.
 */
native dr_get_duel(name, size);

 /**
 * Forward which called before duel start, warm up time
 * 
 * @param duelist_t				Player index.
 * @param duelist_ct			Player index.
 * @param duel_timer			pre duel timer.
 */
forward dr_duel_prestart(duelist_t, duelist_ct, duel_timer);

 /**
 * Forward which called when duel started
 * 
 * @param duelist_t				Player index.
 * @param duelist_ct			Player index.
 * @param duel_timer			end duel timer.
 */
forward dr_duel_start(duelist_t, duelist_ct, duel_timer);

 /**
 * Forward which called when duel overed
 * 
 * @param winner				Player index.
 * @param looser				Player index.
 */
forward dr_duel_finish(winner, looser);

 /**
 * Forward which called when duel canceled
 * 
 * @param type					Cancel type
 */
forward dr_duel_canceled(CancelType:type);
