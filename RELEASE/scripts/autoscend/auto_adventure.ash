// autoAdv is used to automate adventuring *once* in adventure.php zones
// it will (should?) handle the complete adventure from start to finish regardless of
// how many choices or combats it encounters (this is mafia's adv1 behaviour)
// TODO: seems to return false even if it adventures successfully but doesn't cost an adventure (mafia issue?)
// A boss that beat us: no rematch until a base stat has risen (auto_noteBossLoss records the loss, from
// beatenUpResolution). The loss is the evidence: a damage estimate from other fights doesn't carry across weapons or
// monster defences, and on 2026-11-23 one read 11 a round against a usual 200, so there's no check before the first try.
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
