// autoAdv is used to automate adventuring *once* in adventure.php zones
// it will (should?) handle the complete adventure from start to finish regardless of
// how many choices or combats it encounters (this is mafia's adv1 behaviour)
// TODO: seems to return false even if it adventures successfully but doesn't cost an adventure (mafia issue?)
// Times we were beaten up in a zone this life, from autoscend's own record of them (auto_beatenUpLocations:
// "day:N:level:N:place:<zone>" entries, cleared with the ascension's settings). Fights where the monster hit us twice in
// a row without us hurting it count too ("day:N:level:N:nodamage:place:<zone>", auto_zeroDamageHandler).
// Entries in a "day:N:level:N:place:<zone>" list property that name this zone.
int auto_zoneEntries(string property, location loc)
{
	int found = 0;
	foreach i, entry in split_string(get_property(property), ",")
	{
		int at = entry.index_of("place:");
		if(at >= 0 && entry.substring(at + 6) == loc.to_string())
		{
			found += 1;
		}
	}
	return found;
}

int auto_zoneDeaths(location loc)
{
	return auto_zoneEntries("auto_beatenUpLocations", loc);
}

// Rests taken for HP when nothing else would restore it (auto_restInDwelling), charged to the zone we were in or about
// to go into (auto_restLocations, same format, cleared with the ascension's settings).
int auto_zoneRests(location loc)
{
	return auto_zoneEntries("auto_restLocations", loc);
}

// One point of the zone's stat bar for every 5 of those rests (user, 2026-11-21): a zone whose fights cost more HP
// than we can get back without resting is too hard for now, even when nothing has beaten us up there.
int auto_zoneRestBump(location loc)
{
	return auto_zoneRests(loc) / 5;
}

// The main stat a zone wants before we go in: KoL's recommendation (which it doesn't enforce) plus one for every time we
// were beaten up there this life (user, 2026-11-20). The recommendation follows the main stat, but what loses fights is
// often another one (a Seal Clubber's Moxie against the Dark Neck's Hellion), so each death raises the bar until
// levelling, which raises every stat, has caught up.
int auto_statNeededFor(location loc)
{
	return loc.recommended_stat + auto_zoneDeaths(loc) + auto_zoneRestBump(loc);
}

boolean auto_statsTooLowFor(location loc)
{
	return auto_statNeededFor(loc) > 0 && my_buffedstat(my_primestat()) < auto_statNeededFor(loc);
}

// Whether we can hurt the ghosts (physically immune monsters) in a zone. With prepare, also gets the MP for the spell or
// adds the elemental damage to the maximizer. autoAdv asks first without preparing, so a task can pick another zone
// rather than the pre-adventure script aborting.
boolean auto_canDamageGhosts(location place, boolean prepare)
{
	//if place contains physically immune enemies then we need to be prepared to deal non physical damage.
	if(!is_ghost_in_zone(place))
	{
		return true;		//no ghosts no problem
	}
	if(in_plumber())
	{
		return true;		//these paths either have their own ghost handling. or can always kill ghosts
	}
	if(get_property("youRobotBottom").to_int() == 2)
	{
		return true;		//you robot with a rocket crotch. deals fire damage to kill ghosts.
	}
	//a few iconic spells per avatar is ok. no need to be too exhaustive
	foreach sk in $skills[
		Saucestorm, saucegeyser,	//base classes
		Fist of the Mummy,		    //actually ed the undying
		Boil,						//avatar of jarlsberg
		Bilious Burst,				//zombie slayer
		Heroic Belch,				//avatar of boris
		Smoke Break,				//avatar of sneaky pete
		Fireball Toss,				//path of the plumber
		Chill of the Tomb,			//dark gyffte
		Lavafava, Pungent Mung, Beanstorm,			  //avatar of west of loathing
		Hot Foot, Emmental Elemental, Sax of Violence,//avatar of shadow over loathing
		Bacon Ray, Spicy Meatball	//adventurer meats world
		]
	{
		if(!prepare && auto_have_skill(sk) && my_maxmp() >= mp_cost(sk))
		{
			return true;	//the pre-adventure script will get the MP for it
		}
		if(prepare && auto_have_skill(sk))
		{
			if(my_maxmp() >= 32)
				acquireMP(32, 0);		//make sure we actually have the MP to cast spells
			else acquireMP(my_maxmp() - (my_maxmp() % 6), 0);	//as low_mp_handler: keep a Saucestorm's worth
		}
		if(prepare && canUse(sk)) return true;	//we can kill them with a spell
	}
	if(auto_haveDarts() && dartEleDmg())
	{
		if(prepare) addToMaximize("+equip " + $item[Everfull Dart Holster]); //If we have darts and an elemental damage buff, might as well use that
		return true;
	}
	
	int m_hot = 1;
	int m_cold = 1;
	int m_spooky = 1;
	int m_sleaze = 1;
	int m_stench = 1;
	float [monster] apprates = auto_combat_appearance_rates(place, true);
	foreach idx, mob in get_monsters(place)
	{
		if(apprates[mob] <= 0) continue; //won't show up because banished or req's not fulfilled
		if(mob.physical_resistance >= 80)
		{
			switch(monster_element(mob))
			{
			case $element[hot]:
				m_hot = 0;
				m_sleaze = 2;
				m_stench = 2;
				break;
			case $element[cold]:
				m_cold = 0;
				m_hot = 2;
				m_spooky = 2;
				break;
			case $element[spooky]:
				m_spooky = 0;
				m_hot = 2;
				m_stench = 2;
				break;
			case $element[sleaze]:
				m_sleaze = 0;
				m_cold = 2;
				m_spooky = 2;
				break;
			case $element[stench]:
				m_stench = 0;
				m_sleaze = 2;
				m_cold = 2;
				break;
			}
		}
	}
	
	string max_with;
	int bonus;
	if(m_hot != 0) max_with += "," +10*m_hot+ "hot dmg";
	if(m_cold != 0) max_with += "," +10*m_cold+ "cold dmg";
	if(m_spooky != 0) max_with += "," +10*m_spooky+ "spooky dmg";
	if(m_sleaze != 0) max_with += "," +10*m_sleaze+ "sleaze dmg";
	if(m_stench != 0) max_with += "," +10*m_stench+ "stench dmg";
	
	simMaximizeWith(max_with);
	if(m_hot != 0) bonus += simValue("hot damage");
	if(m_cold != 0) bonus += simValue("cold damage");
	if(m_spooky != 0) bonus += simValue("spooky damage");
	if(m_sleaze != 0) bonus += simValue("sleaze damage");
	if(m_stench != 0) bonus += simValue("stench damage");
	
	if(bonus > 9)
	{
		if(prepare) addToMaximize(max_with);
		return true;
	}
	return false;
}

// A boss we can't beat yet: come back later, once levels or gear have caught up. A first life (a level 5 Seal Clubber
// with no permed skills) met the Knob Goblin King, hit it for 1-3 a round against 60 HP while it hit back for 11, and
// the combat script aborted the day. Two tests, both with what we know before the fight:
//  - hitting it: KoL's to-hit is our hit stat against its defence (plus monster level). Spells don't need it.
//  - outlasting it: its HP over our usual damage a round (auto_damageEstimate, the second-lowest of the last 10
//    rounds of each action) gives the rounds; that many of its hits (expected_damage) must leave us standing.
// The Boss Bat (defence 29, 40 HP) passed at 31 Muscle and was beaten; the Goblin King (defence 47 + 10) fails.
// And after losing to a boss (auto_noteBossLoss), wait until a base stat has risen before the rematch.
void auto_noteBossLoss()
{
	monster boss = get_property("lastEncounter").to_monster();
	if(boss == $monster[none] || !boss.boss)
	{
		return;
	}
	string stats = my_basestat($stat[Muscle]) + "," + my_basestat($stat[Mysticality]) + "," + my_basestat($stat[Moxie]);
	auto_log_info("Lost to " + boss + " at Muscle, Mysticality, Moxie " + stats + ": no rematch until one of them rises.", "blue");
	set_property("auto_lostTo_" + boss, my_ascensions() + ":" + stats);
}

string auto_bossNotReadyReason(monster boss)
{
	if(boss == $monster[none] || !boss.boss || boss.base_hp <= 0)
	{
		return "";		// not a boss, or one that scales to us
	}
	// lost to it before: no rematch until a base stat is higher than it was then
	string[int] lost = get_property("auto_lostTo_" + boss).split_string(":");
	if(count(lost) == 2 && lost[0].to_int() == my_ascensions())
	{
		string[int] was = lost[1].split_string(",");
		if(count(was) == 3 && my_basestat($stat[Muscle]) <= was[0].to_int() && my_basestat($stat[Mysticality]) <= was[1].to_int()
			&& my_basestat($stat[Moxie]) <= was[2].to_int())
		{
			return "it beat us at Muscle " + was[0] + ", Mysticality " + was[1] + ", Moxie " + was[2]
				+ ", and none of those has risen since";
		}
	}
	int ml = monster_level_adjustment();
	return auto_wouldLoseReason(boss, boss.base_hp + ml, boss.base_defense + ml, my_maxhp());
}

// Whether we can hit a monster with this defence: KoL's to-hit is our hit stat against it. Spells don't need it.
boolean auto_canHit(int defence)
{
	boolean haveSpell = auto_have_skill($skill[Saucestorm]) || auto_have_skill($skill[Saucegeyser]);
	return haveSpell || buffed_hit_stat() >= defence;
}

// Our usual damage a round: the best of our attacks' estimates (auto_damageEstimate), -1 before enough fights to tell.
int auto_damagePerRound()
{
	int perRound = -1;
	foreach key in $strings[attack, Lunge Smack, Thrust-Smack, Lunging Thrust-Smack, Saucestorm, Saucegeyser]
	{
		perRound = max(perRound, auto_damageEstimate(key));
	}
	return perRound;
}

// One-hit kills seen this life, by zone (user, 2026-11-20): auto_oneHitKills holds "location id:results", the results
// a 1 for a fight our first attack or damage skill won and a 0 for one that took more, oldest first, the last 10. A zone
// at the edge of our damage shows a low share, where one estimate across all fights would call it one hit.
string auto_oneHitResults(location loc)
{
	foreach i, entry in split_string(get_property("auto_oneHitKills"), ",")
	{
		string[int] f = split_string(entry, ":");
		if(count(f) == 2 && f[0].to_int() == loc.to_int())
		{
			return f[1];
		}
	}
	return "";
}

// The share of a zone's recorded fights that one hit won, or -1 with fewer than 3 to go on.
float auto_zoneOneHitShare(location loc)
{
	string results = auto_oneHitResults(loc);
	if(length(results) < 3)
	{
		return -1;
	}
	int ones = 0;
	for(int i = 0; i < length(results); i++)
	{
		if(char_at(results, i) == "1") ones += 1;
	}
	return ones.to_float() / length(results);
}

// Notes the fight just won, if it was all attacks and damage skills: an instakill, a stun or an item says nothing about
// our damage. Called after every adventure; _auto_oneHitNoted keeps a fight from being noted twice.
void auto_noteOneHitKill()
{
	string started = get_property("_lastCombatStarted");
	if(started == "" || started == get_property("_auto_oneHitNoted"))
	{
		return;
	}
	set_property("_auto_oneHitNoted", started);
	monster mob = last_monster();
	if(!get_property("_lastCombatWon").to_boolean() || mob == $monster[none] || mob.boss || my_location() == $location[none])
	{
		return;
	}
	int hits = 0;
	foreach i, action in split_string(get_property("_lastCombatActions"), ";")
	{
		if(action == "")
		{
			continue;
		}
		if(!($strings[attack, sk1003, sk1004, sk1005, sk4005, sk4012] contains action))
		{
			return;		// not just Thrust-Smack, Lunge Smack, Lunging Thrust-Smack, Saucestorm or Saucegeyser
		}
		hits += 1;
	}
	if(hits == 0)
	{
		return;
	}
	location loc = my_location();
	string results = auto_oneHitResults(loc) + (hits == 1 ? "1" : "0");
	if(length(results) > 10)
	{
		results = substring(results, length(results) - 10);
	}
	string kept = "";
	foreach i, entry in split_string(get_property("auto_oneHitKills"), ",")
	{
		if(entry != "" && split_string(entry, ":")[0].to_int() != loc.to_int())
		{
			kept += (kept == "" ? "" : ",") + entry;
		}
	}
	set_property("auto_oneHitKills", kept + (kept == "" ? "" : ",") + loc.to_int() + ":" + results);
}

// Why a fight with this monster would be lost, or "": the boss check's two tests, for any monster. Before a fight it
// gets the monster's full HP and our maximum; during one (combat stage 2's retreat) what it has left and what we have.
string auto_wouldLoseReason(monster enemy, int hp, int defence, int ourHp)
{
	if(!auto_canHit(defence) && expected_damage(enemy) > 0)	// one that can't hurt us can't win
	{
		return "our hit stat (" + buffed_hit_stat() + ") is below its defence (" + defence + ")";
	}
	int perRound = auto_damagePerRound();
	if(perRound <= 0 || hp <= 0)
	{
		return "";		// no damage seen yet this ascension to judge by
	}
	int rounds = (hp + perRound - 1) / perRound;
	int taken = expected_damage(enemy) * rounds;
	if(taken >= ourHp)
	{
		return "we'd need about " + rounds + " rounds at " + perRound + " a round for its " + hp + " HP, and its hits ("
			+ expected_damage(enemy) + " each) would take " + taken + " of our " + ourHp + " HP";
	}
	return "";
}

boolean autoAdv(int num, location loc, string option)
{
	if(!zone_isAvailable(loc, true)){
		auto_log_warning("Can't get to " + loc + " right now.", "red");
		return false;
	}
	if(auto_statsTooLowFor(loc))
	{
		auto_log_warning("Our " + my_primestat() + " (" + my_buffedstat(my_primestat()) + ") is below the " + auto_statNeededFor(loc) + " that " + loc + " wants ("
			+ loc.recommended_stat + " recommended, plus " + auto_zoneDeaths(loc) + " for times beaten up or hit twice without hurting it there, and "
			+ auto_zoneRestBump(loc) + " for " + auto_zoneRests(loc) + " rests for HP there), so not going there yet.", "red");
		return false;
	}
	// the pre-adventure script aborts the run in a zone of ghosts we can't hurt, so turn it down here instead and let
	// the task do something else (a first-life Seal Clubber has no spell and no elemental damage for the Billiards Room)
	if(!auto_canDamageGhosts(loc, false))
	{
		auto_log_warning(loc + " has ghosts and we have no spell or elemental damage to hurt them, so not going there yet.", "red");
		return false;
	}
	monster boss = get_property("auto_nextEncounter").to_monster();
	string notReady = auto_bossNotReadyReason(boss);
	if(notReady != "")
	{
		auto_log_warning("Not fighting " + boss + " yet: " + notReady + ". Coming back when we're stronger.", "red");
		set_property("auto_nextEncounter", "");
		return false;
	}

	remove_property("_auto_combatState");
	set_property("auto_diag_round", 0);
	set_property("nextAdventure", loc);
	if(option == "")
	{
		if (isActuallyEd())
		{
			option = "auto_edCombatHandler";
		} else {
			option = "auto_combatHandler";
		}
	}

	// adv1 can erroneously return false for "choiceless" non-combats
	// see https://kolmafia.us/showthread.php?25370-adv1-returns-false-for-quot-choiceless-quot-choice-adventures
	// undo all this when (if?) that ever gets fixed
	string previousEncounter = get_property("lastEncounter");
	int turncount = my_turncount();
	boolean advReturn = adv1(loc, -1, option);
	if (!advReturn)
	{
		auto_log_debug("adv1 returned false for some reason. Did we actually adventure though?", "blue");
		if (get_property("lastEncounter") != previousEncounter)
		{
			auto_log_debug(`Looks like we may have adventured, lastEncounter was {previousEncounter}, now {get_property("lastEncounter")}`, "blue");
			advReturn = true;
		}
		if (my_turncount() > turncount)
		{
			auto_log_debug(`Looks like we may have adventured, turncount was {turncount}, now {my_turncount()}`, "blue");
			advReturn = true;
		}
	}
	return advReturn;
}

boolean autoAdv(int num, location loc)
{
	return autoAdv(num, loc, "");
}

boolean autoAdv(location loc)
{
	return autoAdv(1, loc, "");
}

boolean autoAdv(location loc, string option)
{
	return autoAdv(1, loc, option);
}

boolean autoLuckyAdv(location loc, boolean override)
{
	boolean gotLucky = false;
	if (cloversAvailable(override) > 0)
	{
		cloverUsageInit(override);
		gotLucky = autoAdv(loc);
		if (cloverUsageRestart()) 
		{
			gotLucky = autoAdv(loc);
		}
		cloverUsageFinish();
	}
	return gotLucky;
}

boolean autoLuckyAdv(location loc)
{
	// overload to not override clover usage by default as this is the general case
	return autoLuckyAdv(loc, false);
}


// autoAdvBypass is used to automate adventuring *once* in non-adventure.php zones
// it will (should?) handle the complete adventure from start to finish regardless of
// how many choices or combats it encounters
boolean autoAdvBypass(int urlGetFlags, string[int] url, location loc, string option)
{
	if(!zone_isAvailable(loc, true))
	{
		// reinstate this check for now. Didn't fix the War boss fight outside of Ed & KoE,
		// will work around that by passing Noob Cave as location until this is refactored.
		auto_log_warning("Can't get to " + loc + " right now.", "red");	
		return false;	
	}
	
	set_property("nextAdventure", loc);
	cli_execute("auto_pre_adv");
	remove_property("_auto_combatState");
	set_property("auto_diag_round", 0);

	if(option == "")
	{
		if (isActuallyEd())
		{
			option = "auto_edCombatHandler";
		} else {
			option = "auto_combatHandler";
		}
	}

	if (isActuallyEd())
	{
		ed_handleAdventureServant(loc);
	}

	auto_log_info("About to start a combat indirectly at " + loc + "... (" + count(url) + ") accesses required.", "blue");
	string page;
	foreach idx, it in url
	{
		if((urlGetFlags & 1) == 1)
		{
			page = visit_url(it, false);
		}
		else
		{
			page = visit_url(it);
		}
		urlGetFlags /= 2;
	}

	// handle the initial combat or choice the easy way.
	string combatPage = ">Combat";
	if(in_pokefam()) {
		combatPage = ">Fight!";
	}
	if (contains_text(page, combatPage)) {
		auto_log_info("autoAdvBypass has encountered a combat! (param: '" + option + "')", "green");
		run_combat(option);
	} else {
		int choice_id = last_choice();
		auto_log_info("autoAdvBypass has encountered a choice: "+choice_id, "green");
		run_choice(-1);
	}

	// this should handle stuff like Ed's resurrect/fight loop
	// and anything else that chains combats & choices in any order
	while (fight_follows_choice() || choice_follows_fight() || in_multi_fight() || handling_choice()) {
		if ((fight_follows_choice() || in_multi_fight()) && (!choice_follows_fight() && !handling_choice())) {
			auto_log_info("autoAdvBypass has encountered a combat! (param: '" + option + "')", "green");
			run_combat(option);
		}
		if (choice_follows_fight() || handling_choice()) {
			int choice_id = last_choice();
			auto_log_info("autoAdvBypass has encountered a choice: "+choice_id, "green");
			run_choice(-1);
		}
	}

	cli_execute("auto_post_adv");

	// Encounters that need to generate a false so we handle them manually should go here.
	if(get_property("lastEncounter") == "Travel to a Recent Fight")
	{
		return false;
	}
	if(get_property("lastEncounter") == "Rationing out Destruction")
	{
		return false;
	}
	if(get_property("lastEncounter") == "Rainy Fax Dreams on your Wedding Day")
	{
		return false;
	}
	return true;
}

boolean autoAdvBypass(string url, location loc)
{
	return autoAdvBypass(url, loc, "");
}

boolean autoAdvBypass(string url, location loc, string option)
{
	string[int] urlConvert;
	urlConvert[0] = url;
	return autoAdvBypass(0, urlConvert, loc, option);
}

boolean autoAdvBypass(int snarfblat, location loc)
{
	string page = "adventure.php?snarfblat=" + snarfblat;
	return autoAdvBypass(page, loc);
}

boolean autoAdvBypass(int snarfblat, location loc, string option)
{
	string page = "adventure.php?snarfblat=" + snarfblat;
	return autoAdvBypass(page, loc, option);
}

boolean autoAdvBypass(int snarfblat)
{
	return autoAdvBypass(snarfblat, $location[Noob Cave]);
}

boolean autoAdvBypass(string url)
{
	return autoAdvBypass(url, $location[Noob Cave]);
}

boolean autoAdvBypass(int snarfblat, string option)
{
	return autoAdvBypass(snarfblat, $location[Noob Cave], option);
}

boolean autoAdvBypass(string url, string option)
{
	return autoAdvBypass(url, $location[Noob Cave], option);
}
