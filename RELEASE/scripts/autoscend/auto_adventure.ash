// autoAdv is used to automate adventuring *once* in adventure.php zones
// it will (should?) handle the complete adventure from start to finish regardless of
// how many choices or combats it encounters (this is mafia's adv1 behaviour)
// TODO: seems to return false even if it adventures successfully but doesn't cost an adventure (mafia issue?)
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
