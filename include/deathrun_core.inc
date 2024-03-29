#if defined _deathrun_core_included
  #endinput
#endif
#define _deathrun_core_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib deathrun_core
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib deathrun_core
	#endif
#else
	#pragma library deathrun_core
#endif

/**
 * Get player index current terrorist.
 * 
 * @return					Player index.
 */
native dr_get_terrorist();

/**
 * Set player who became terrorist in new round.
 * 
 * @param id				Next terrorist index.
 */
native dr_set_next_terrorist(id);

/**
 * Get player who became terrorist in new round.
 * 
 * @return					Player index.
 */
native dr_get_next_terrorist();

/**
 * Forward which called when chosen new terrorist(new round or disconnect).
 * 
 * @param id				Player index.
 */
forward dr_chosen_new_terrorist(id);

/**
 * Forward which called when chosen next terrorist(any time).
 * 
 * @param id				Player index.
 */
forward dr_chosen_next_terrorist(id);

/**
 * Forward which called when warm up(start map or m_bCompleteReset).
 * 
 * @param duration				duration warm up.
 */
forward dr_warm_up(duration);