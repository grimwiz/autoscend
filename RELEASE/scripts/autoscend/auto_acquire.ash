// functions that deal with acquiring items. via buying or pulling

boolean haveAny(boolean[item] array)
{
	foreach thing in array
	{
		if(item_amount(thing) > 0)
		{
			return true;
		}
	}
	return false;
}

boolean acquireOrPull(item it)
{
	//this function is for when you want to make sure you have 1 of an item
	//if you have one it returns true. if you don't it will craft one. if it can't it will pull it.
	
	if(possessEquipment(it)) return true;
	if(item_amount(it) > 0)  return true;
	if(retrieve_item(1, it)) return true;
	if(canPull(it))
	{
		if(pullXWhenHaveY(it, 1, 0)) return true;
	}
	
	//special handling via pulling 1 ingredient to craft the item desired
	if($items[asteroid belt, meteorb, shooting morning star, meteorite guard, meteortarboard, meteorthopedic shoes] contains it)
	{
		if(canPull($item[metal meteoroid]))
		{
			if(pullXWhenHaveY($item[metal meteoroid], 1, 0))
			{
				if(retrieve_item(1, it)) return true;
			}
		}
	}
	
	return false;
}

boolean canPull(item it, boolean historical)
{
	if(in_hardcore())
	{
		return false;
	}
	if(in_lol())
	{
		// kol states "Only food, booze, potions, combat and usable items may be pulled on this path."
		if(it.fullness == 0 && it.inebriety == 0 && !it.potion && !it.combat && !it.usable)
		{
			return false;
		}
	}
	if(it == $item[none])
	{
		return false;
	}
	if(!is_unrestricted(it))
	{
		return false;
	}
	if(pulls_remaining() == 0)
	{
		return false;
	}
	if(pulledToday(it))
	{
		return false;
	}
	
	if(storage_amount(it) > 0)
	{
		return true;	//we have it in storage so we can pull it
	}
	else if(!is_tradeable(it))
	{
		return false;	//we do not have it in storage and we can not trade for it. gifts currently not handled
	}

	if(!auto_is_valid(it))
	{
		return false;
	}

	int meat = my_storage_meat();
	if(can_interact())
	{
		meat = max(meat, my_meat() - 5000);
	}
	int curPrice = historical_price(it);
	if(!historical)
	{
		curPrice = auto_mall_price(it);
	}
	if(curPrice < 1)
	{
		return false;	//a 0 or a -1 indicates the item is not available.
	}
	if(curPrice > get_property("autoBuyPriceLimit").to_int())
	{
		return false;
	}
	else if(curPrice < meat)
	{
		return true;
	}
	
	return false;
}

boolean canPull(item it)
{
	return canPull(it, false);
}

boolean pulledToday(item it)
{
	//autoscend property "auto_pulls" tracks pulls made by the script as "(" + my_daycount() + ":" + it
	//kolmafia property "_roninStoragePulls" tracks all pulls made with kolmafia today since 2022 changed to daily limit of one pull for each item
	string [int] allPulls = split_string(get_property("_roninStoragePulls"),",");
	foreach i in allPulls
	{
		if(allPulls[i].to_int() == it.to_int())
		{
			return true;
		}
	}
	return false;
}

int auto_mall_price(item it)
{
	if(isSpeakeasyDrink(it))
	{
		return -1;	//speakeasy drinks are marked as tradeable but cannot be acquired as a physical item to trade.
	}
	if(available_choice_options() contains 0 || available_choice_options() contains 1)	//we are in a choice adventure.
	{
		//mafia returns -1 if we check mall_price() while in a choice adv. better to use historical price even if it is outdated
		return historical_price(it);
	}
	if(is_tradeable(it))
	{
		int retval;
		string it_type = item_type(it);
		if(it_type == "food" || it_type == "booze")
		{
			//autoscend does Bulk cache mall prices for food,booze,hprestore,mprestore so that when asking for mall_price it gets a cached mafia session price
			//directly ask for historical_price here if it exists because if mafia session has to be restarted mafia will do another search despite recent price
			//hprestore and mprestore types corresponding with mall_prices search categories are not available
			retval = historical_price(it);
			if(retval == 0)
			{
				retval = mall_price(it);
			}
		}
		else
		{
			retval = mall_price(it);
		}
		if(retval == -1)
		{
			//0 could be due to item not being tradeable.
			//-1 could be due to tradeable item not found in the mall. Or due to an IO error during lookup
			//-1 is non trivial to fix due to mafia anti abuse code
			//historical price can never be -1. only 0 or a positive number
			//just use the historical price. It will be good enough. it never returns -1. and if it returns 0 it is because this mafia install never happened to look up that item before. which suggests an extreme edge case or that the item is really unavailable
			return historical_price(it);
		}
		return retval;
	}
	return -1;
}

boolean pullXWhenHaveYCasual(item it, int howMany, int whenHave)
{
	//we are either in a casual run. or in postronin. either way pull becomes mallbuy
	if(!can_interact())
	{
		return false;
	}
	if(it == $item[none])
	{
		return false;
	}
	if(!auto_is_valid(it))
	{
		return false;
	}
	if((item_amount(it) + equipped_amount(it)) != whenHave)
	{
		return false;
	}
	if(inAftercore())
	{
		take_storage(storage_amount(it), it);
	}
	int maxprice = get_property("autoBuyPriceLimit").to_int();
	while((item_amount(it) < howMany) && (auto_mall_price(it) < maxprice))
	{
		if(auto_mall_price(it) > my_meat())
		{
			abort("Don't have enough meat to restock, big sad");
		}
		if(buy(1, it, maxprice) == 0)
		{
			auto_log_info("Price of " + it + " exceeded expected mall price of " + maxprice + ".", "blue");
			return false;
		}
	}
	if(item_amount(it) < howMany)
	{
		if(auto_mall_price(it) >= maxprice)
		{
			auto_log_info("Price of " + it + " exceeded expected mall price of " + maxprice + ".", "blue");
		}
		return false;
	}
	return true;
}

// The most worth paying to buy a pull: the turns it saves times a turn's value (auto_turnValue, default 2,000 Meat:
// aftercore farming earns ~800-1,000, and a faster run is worth more), the same turn value the diet uses.
// Turns saved are estimates from run logs; items without one keep autoBuyPriceLimit.
int auto_pullPriceCap(item it)
{
	int limit = get_property("autoBuyPriceLimit").to_int();
	float[item] turnsSaved = {
		$item[smut orc keepsake box] : 4,	// 5 lumber + 4 fasteners; the logging camp gives ~2.3 bridge parts a turn
		$item[Spooky-Gro fertilizer] : 3,	// one Spooky Forest noncombat, every 2-4 turns there
		$item[wet stew] : 12,				// bird rib + lion oil in Whitey's Grove, 10-14 turns at +140% item
		$item[drum machine] : 2				// the Oasis visits for the desert usually drop one anyway
	};
	if(!(turnsSaved contains it))
	{
		return limit;
	}
	int turnValue = get_property("auto_turnValue") == "" ? 2000 : get_property("auto_turnValue").to_int();
	return min(limit, to_int(turnsSaved[it] * turnValue));
}

// When Ronin ends, everything in Hagnk's is free to use: quest items, gear, food, drink and Meat. That is at turn 1000
// or, far more often, when the King is freed. Empty the items once per ascension (the Casual path already does) and
// take the Meat too: with mall access it is the Meat on hand that gets spent.
void auto_emptyStorageWhenFree()
{
	if(!can_interact())
	{
		return;
	}
	if(get_property("lastEmptiedStorage").to_int() != my_ascensions())
	{
		auto_log_info("Out of Ronin: emptying Hagnk's so stored quest items, gear, food and drink can be used.", "blue");
		cli_execute("pull all");
	}
	if(my_storage_meat() > 0)
	{
		auto_log_info("Out of Ronin: taking " + my_storage_meat() + " Meat out of Hagnk's.", "blue");
		cli_execute("pull " + my_storage_meat() + " meat");
	}
	auto_offerLoathingItems();
}

// The Clothing of Loathing is smithed from one Hatred piece (Yog-Urt) and one Violence piece (Shub-Jigguwatt), each
// dropped for one class only, so the halves pile up in Hagnk's over many ascensions. KoLmafia lists these recipes as
// MANUAL, and "currently ignores MANUAL recipes entirely": create() can't make them and get_ingredients() is empty.
// So the pairs are written out here and smithed on the smithing page (needs a tenderizing hammer in inventory).
int[item] auto_loathingHalves(item it)
{
	item[item] hatred = {
		$item[Belt of Loathing] : $item[Girdle of Hatred],
		$item[Goggles of Loathing] : $item[Lens of Hatred],
		$item[Jeans of Loathing] : $item[Pantaloons of Hatred],
		$item[Scepter of Loathing] : $item[Cold Stone of Hatred],
		$item[Stick-Knife of Loathing] : $item[Staff of Simmering Hatred],
		$item[Treads of Loathing] : $item[Fuzzy Slippers of Hatred]
	};
	item[item] violence = {
		$item[Belt of Loathing] : $item[Novelty Belt Buckle of Violence],
		$item[Goggles of Loathing] : $item[Lens of Violence],
		$item[Jeans of Loathing] : $item[Jodhpurs of Violence],
		$item[Scepter of Loathing] : $item[Brand of Violence],
		$item[Stick-Knife of Loathing] : $item[Pigsticker of Violence],
		$item[Treads of Loathing] : $item[Ass-Stompers of Violence]
	};
	int[item] halves;
	if(hatred contains it)
	{
		halves[hatred[it]] = 1;
		halves[violence[it]] = 1;
	}
	return halves;
}

boolean auto_smithLoathing(item it)
{
	int[item] halves = auto_loathingHalves(it);
	if(count(halves) != 2 || item_amount($item[tenderizing hammer]) == 0)
	{
		return false;
	}
	string url = "craft.php?action=craft&mode=smith&pwd&qty=1";
	string ab = "a";
	foreach half in halves
	{
		if(item_amount(half) == 0)
		{
			return false;
		}
		url += "&" + ab + "=" + half.to_int();
		ab = "b";
	}
	int before = item_amount(it);
	visit_url(url);
	return item_amount(it) > before;
}

// The parts of something craftable: KoLmafia's recipe, or a Loathing pair once there is a hammer to smith it with.
int[item] auto_craftParts(item it)
{
	int[item] parts = get_ingredients(it);
	if(count(parts) == 0 && item_amount($item[tenderizing hammer]) > 0)
	{
		parts = auto_loathingHalves(it);
	}
	return parts;
}

boolean auto_craftOne(item it)
{
	if(count(get_ingredients(it)) == 0 && count(auto_loathingHalves(it)) > 0)
	{
		return auto_smithLoathing(it);
	}
	return create(1, it);
}

// Once Hagnk's is emptied, ask (once per ascension) whether to make each Loathing item that isn't owned yet and whose
// two halves are both in hand.
void auto_offerLoathingItems()
{
	if(get_property("auto_loathingOffered").to_int() == my_ascensions())
	{
		return;
	}
	set_property("auto_loathingOffered", my_ascensions());
	foreach it in $items[Belt of Loathing, Goggles of Loathing, Jeans of Loathing, Scepter of Loathing, Stick-Knife of Loathing, Treads of Loathing]
	{
		if(available_amount(it) + storage_amount(it) + display_amount(it) > 0)
		{
			continue;
		}
		string halves = "";
		boolean haveBoth = true;
		foreach half in auto_loathingHalves(it)
		{
			halves += (halves == "" ? "" : " + ") + half;
			haveBoth = haveBoth && item_amount(half) > 0;
		}
		if(!haveBoth)
		{
			continue;
		}
		if(item_amount($item[tenderizing hammer]) == 0)
		{
			auto_log_info("You can make " + it + " from " + halves + ", but smithing it needs a tenderizing hammer in inventory.", "blue");
			continue;
		}
		if(!user_confirm("You have " + halves + ". Make " + it + " from them (this uses both up)? Will default to 'No' in 60 seconds.", 60000, false))
		{
			auto_log_info("Not making " + it + " (from " + halves + ").", "blue");
		}
		else if(auto_smithLoathing(it))
		{
			auto_log_info("Made " + it + ".", "blue");
		}
		else
		{
			auto_log_warning("Smithing " + it + " didn't work; it can be made on the smithing page (needs an adventure and a tenderizing hammer).", "red");
		}
	}
}

// Make an item from ingredients in inventory or Hagnk's instead of pulling or buying it, when its mall price is more
// than auto_pullValue (1,000) Meat per pull the ingredients need. A stored item counts at its price too: pulling a
// 6,000 Meat wet stew uses up 6,000 Meat of stock, where bird rib + lion oil cost 2 pulls. Ingredients already in
// inventory need no pulls, so those are always used. Plain recipes only (meat paste, cooking with an oven, mixing
// with a cocktail kit), one level deep, and ingredients are never bought.
boolean auto_craftInsteadOfPull(item it, int howMany)
{
	string how = craft_type(it);
	boolean haveOven = get_property("auto_haveoven").to_boolean() || (auto_get_campground() contains $item[Dramatic&trade; range]);
	if(!(how == "Meatpasting" || (how == "Cooking" && haveOven) || (how == "Mixing" && get_property("hasCocktailKit").to_boolean())))
	{
		return false;
	}
	int[item] ingredients = get_ingredients(it);
	if(count(ingredients) == 0)
	{
		return false;
	}
	int[item] toPull;
	int pulls = 0;
	foreach ing, amt in ingredients
	{
		int need = amt * howMany - item_amount(ing);
		if(need <= 0)
		{
			continue;
		}
		if(storage_amount(ing) < need || !canPull(ing))
		{
			return false;
		}
		toPull[ing] = need;
		pulls += need;
	}
	if(pulls_remaining() >= 0 && pulls > pulls_remaining())	// -1 means unlimited
	{
		return false;
	}
	int price = auto_mall_price(it);
	int pullValue = get_property("auto_pullValue") == "" ? 1000 : get_property("auto_pullValue").to_int();
	if(pulls > 0 && price <= pulls * pullValue)
	{
		return false;
	}
	auto_log_info("Making " + howMany + " " + it + " (" + how + ", " + pulls + " pull(s) of ingredients) rather than pulling or buying it at " + price + " Meat.", "blue");
	foreach ing, need in toPull
	{
		if(!take_storage(need, ing))
		{
			return false;
		}
		for(int i = 0; i < need; ++i)
		{
			handleTracker(ing, "auto_pulls");
		}
	}
	return create(howMany, it);
}

// Get a wet stew's worth by pulling rather than buying. Bird rib + lion oil cook into wet stew for free
// (makeWetStuntNutStew does it), so ingredients in Hagnk's cost 2 pulls instead of a 4,000-6,000 Meat stew,
// and one ingredient held halves the Whitey's Grove farm for the other. Buys a stew only when neither is stored.
boolean auto_pullWetStew()
{
	if(item_amount($item[wet stew]) > 0 || (item_amount($item[bird rib]) > 0 && item_amount($item[lion oil]) > 0))
	{
		return false;
	}
	if(storage_amount($item[wet stew]) > 0)
	{
		return pullXWhenHaveY($item[wet stew], 1, 0);
	}
	boolean pulled = false;
	foreach it in $items[bird rib, lion oil]
	{
		if(item_amount(it) == 0 && storage_amount(it) > 0)		// in storage, so this pulls and never buys
		{
			pulled = pullXWhenHaveY(it, 1, 0) || pulled;
		}
	}
	if(pulled || item_amount($item[bird rib]) > 0 || item_amount($item[lion oil]) > 0)
	{
		return pulled;	// farm whatever is still missing rather than buying a whole stew
	}
	return pullXWhenHaveY($item[wet stew], 1, 0);
}

boolean pullXWhenHaveY(item it, int howMany, int whenHave)
{
	if(can_interact())
	{
		return pullXWhenHaveYCasual(it, howMany, whenHave);
	}
	if(!canPull(it))
	{
		return false;
	}
	if((item_amount(it) + equipped_amount(it)) == whenHave)
	{
		if(auto_craftInsteadOfPull(it, howMany))
		{
			return true;
		}
		int lastStorage = storage_amount(it);
		while(storage_amount(it) < howMany)
		{
			int oldPrice = historical_price(it) * 1.2;
			int curPrice = auto_mall_price(it);
			int meat = my_storage_meat();
			int priceLimit = auto_pullPriceCap(it);
			boolean getFromStorage = true;
			if(can_interact() && (meat < curPrice))
			{
				meat = my_meat() - 5000;
				getFromStorage = false;
			}
			if(curPrice >= priceLimit)
			{
				auto_log_warning(it + " is too expensive at " + curPrice + " meat (worth up to " + priceLimit + "), we're gonna skip buying one in the mall.", "red");
				break;
			}
			if((curPrice <= oldPrice) && (curPrice < priceLimit) && (meat >= curPrice))
			{
				if(getFromStorage)
				{
					buy_using_storage(howMany - storage_amount(it), it, curPrice);
				}
				else
				{
					howMany -= buy(howMany - storage_amount(it), it, curPrice);
				}
			}
			else
			{
				if(curPrice > oldPrice)
				{
					auto_log_warning("Price of " + it + " may have been mall manipulated. Expected to pay at most: " + oldPrice, "red");
				}
				if(my_storage_meat() < curPrice)
				{
					auto_log_warning("Do not have enough meat in Hagnk's to buy " + it + ". Need " + curPrice + " have " + my_storage_meat() + ".", "blue");
				}
			}
			if(lastStorage == storage_amount(it))
			{
				break;
			}
			lastStorage = storage_amount(it);
		}

		if(storage_amount(it) < howMany)
		{
			auto_log_warning("Can not pull what we don't have. Sorry");
			return false;
		}

		auto_log_info("Trying to pull " + howMany + " of " + it, "blue");
		boolean retval = take_storage(howMany, it);
		if(item_amount(it) != (howMany + whenHave))
		{
			auto_log_warning("Failed pulling " + howMany + " of " + it, "red");
		}
		else
		{
			for(int i = 0; i < howMany; ++i)
			{
				handleTracker(it, "auto_pulls");
			}
		}
		return retval;
	}
	return false;
}

boolean pulverizeThing(item it)
{
	if(!have_skill($skill[Pulverize]))
	{
		return false;
	}
	if(item_amount($item[Tenderizing Hammer]) == 0)
	{
		if(my_meat() < npc_price($item[Tenderizing Hammer]))
		{
			return false;
		}
	}

	if(item_amount(it) == 0)
	{
		if(closet_amount(it) == 0)
		{
			return false;
		}
		take_closet(1, it);
	}
	if(item_amount(it) == 0)
	{
		return false;
	}
	cli_execute("pulverize 1 " + it);
	return true;
}

boolean buyableMaintain(item toMaintain, int howMany)
{
	return buyableMaintain(toMaintain, howMany, 0, true);
}

boolean buyableMaintain(item toMaintain, int howMany, int meatMin)
{
	return buyableMaintain(toMaintain, howMany, meatMin, true);
}

boolean buyableMaintain(item toMaintain, int howMany, int meatMin, boolean condition)
{
	if((!condition) || (my_meat() < meatMin) || in_wotsf())
	{
		return false;
	}

	return auto_buyUpTo(howMany, toMaintain);
}

boolean auto_buyUpTo(int num, item it)
{
	if(is_werewolf())
	{
		return false; //can't buy anything as a werewolf
	}
	if(item_amount(it) >= num)
	{
		return true;	//we already have the target amount
	}
	if(($items[Ben-Gal&trade; Balm, Hair Spray] contains it) && !isGeneralStoreAvailable())
	{
		return false;
	}
	if(($items[Blood of the Wereseal, Cheap Wind-Up Clock, Turtle Pheromones] contains it) && !isMusGuildStoreAvailable())
	{
		return false;
	}

	int missing = num - item_amount(it);
	int maxprice = get_property("autoBuyPriceLimit").to_int();
	if(can_interact() && shop_amount(it) > 0 && mall_price(it) < maxprice)	//prefer to buy from yourself
	{
		take_shop(min(missing, shop_amount(it)), it);
		missing = num - item_amount(it);
	}
	if(missing > 0)
	{
		buy(missing, it, maxprice);
		if(item_amount(it) < num)
		{
			auto_log_warning("Could not auto_buyUpTo(" + num + ") of " + it + ". Maxprice: " + maxprice, "red");
		}
	}
	return (item_amount(it) >= num);
}

float npcStoreDiscountMulti()
{
	//calculates a multiplier to be applied to store prices for our current discount for NPC stores.
	//does not bother with sleaze jelly or Post-holiday sale coupon
	
	float retval = 1.0;
	
	if(auto_have_skill($skill[Five Finger Discount]))
	{
		retval -= 0.05;
	}
	if(possessEquipment($item[Travoltan trousers]) && auto_is_valid($item[Travoltan trousers]))
	{
		retval -= 0.05;
	}
	
	return retval;
}

boolean acquireGumItem(item it)
{
	if(!isGeneralStoreAvailable())
	{
		return false;
	}

	if(!($items[Disco Ball, Disco Mask, Helmet Turtle, Hollandaise Helmet, Mariachi Hat, Old Sweatpants, Pasta Spoon, Ravioli Hat, Saucepan, Seal-Clubbing Club, Seal-Skull Helmet, Stolen Accordion, Turtle Totem, Worthless Gewgaw, Worthless Knick-Knack, Worthless Trinket] contains it))
	{
		return false;
	}

	int have = item_amount(it);
	auto_log_info("Gum acquisition of: " + it, "green");
	while((have == item_amount(it)) && (my_meat() >= npc_price($item[Chewing Gum on a String])))
	{
		auto_buyUpTo(1, $item[Chewing Gum on a String]);
		use(1, $item[Chewing Gum on a String]);
	}

	return (have + 1) == item_amount(it);
}

boolean acquireTotem()
{
	//this function checks if you have a valid totem for casting turtle tamer buffs with. Returning true if you do. If you don't, it will attempt to acquire one in a reasonable manner.

	//check if there is a valid totem in inventory or equipped, return true if there is.
	//check the closet from best to worst. If found in closet, uncloset 1 and return true
	
	foreach totem in $items[primitive alien totem, flail of the seven aspects, chelonian morningstar, mace of the tortoise, ouija board\, ouija board, turtle totem]
	{
		if(possessEquipment(totem))
		{
			return true;
		}
		if(0 < closet_amount(totem))
		{
			take_closet(1, totem);
			return true;
		}
	}

	boolean want_totem = false;
	foreach sk in $skills[Empathy of the Newt, Astral Shell, Ghostly Shell, Tenacity of the Snapper, Spiky Shell, Reptilian Fortitude, Jingle Bells, Curiosity of Br\'er Tarrypin]
	{
		if(auto_have_skill(sk))
		{
			want_totem = true;
		}
	}
	if(want_totem)
	{	
		//try fishing in the sewer for a turtle totem
		if(acquireGumItem($item[turtle totem]))
		{
			return true;
		}
	}
	
	//did not get a totem. Give up
	return false;
}

boolean auto_hermit(int amt, item it)
{
	//workaround for this bug https://kolmafia.us/threads/27105/
	if(it != $item[11-Leaf Clover])
	{
		return hermit(amt, it);
	}
	int initial = item_amount(it);
	catch hermit(amt, it);
	return item_amount(it) == initial + amt;
}

boolean acquireHermitItem(item it)
{
	if(!isHermitAvailable())
	{
		return false;
	}
	
	if((item_amount($item[Hermit Permit]) == 0) && (my_meat() >= npc_price($item[Hermit Permit])))
	{
		auto_buyUpTo(1, $item[Hermit Permit]);
	}
	if(item_amount($item[Hermit Permit]) == 0)
	{
		return false;
	}
	if(!($items[Banjo Strings, Catsup, Chisel, Figurine of an Ancient Seal, Hot Buttered Roll, Jaba&ntilde;ero Pepper, Ketchup, Petrified Noodles, Seal Tooth, 11-Leaf Clover, Volleyball, Wooden Figurine] contains it))
	{
		return false;
	}
	if((it == $item[Figurine of an Ancient Seal]) && (my_class() != $class[Seal Clubber]))
	{
		return false;
	}
	if(it == $item[11-leaf clover] && get_property("_cloversPurchased") >= 3) {
		return false;
	}
	if(!isGeneralStoreAvailable())
	{
		return false;
	}
	int have = item_amount(it);
	auto_log_info("Hermit acquisition of: " + it, "green");
	while((have == item_amount(it)) && ((my_meat() >= npc_price($item[Chewing Gum on a String])) || ((item_amount($item[Worthless Trinket]) + item_amount($item[Worthless Gewgaw]) + item_amount($item[Worthless Knick-knack])) > 0)))
	{
		if((item_amount($item[Worthless Trinket]) + item_amount($item[Worthless Gewgaw]) + item_amount($item[Worthless Knick-knack])) > 0)
		{
			if(!auto_hermit(1, it))
			{
				return false;
			}
		}
		else
		{
			if(is_werewolf())
			{
				return false; //can access the hermit, but can't buy chewing gum as a Werewolf
			}
			auto_buyUpTo(1, $item[Chewing Gum on a String]);
			use(1, $item[Chewing Gum on a String]);
		}
	}

	return (have + 1) == item_amount(it);
}

boolean pull_meat(int target)
{
	//pulls meat to reach the desired target amount. preferentially will pull items and autosell them.
	if(my_meat() >= target)
	{
		return true;	//already have target meat
	}
	if(pulls_remaining() < 1)		//hardcore returns 0. casual returns -1. both are < 1
	{
		return false;	//can not pull
	}
	if(in_wotsf())
	{
		return false;	//can not pull meat & autoselling items just donates them
	}
	
	//pull and autosell items, except in adventurer meats world
	while(my_meat() < target && pulls_remaining() > 0 && !in_amw())
	{
		boolean fail = true;		//if true an item was not pulled and sold this loop
		foreach it in $items[1\,970 carat gold]
		{
			if(fail && storage_amount(it) > 0 && is_unrestricted(it))
			{
				if(pullXWhenHaveY(it, 1, 0) && autosell(1, it))		//pull and sell
				{
					fail = false;
				}
			}
		}
		if(fail) break;
	}
	
	//pull meat directly
	if(my_meat() < target && my_storage_meat() >= target)
	{
		float meat_pulls = target - my_meat();					//how much meat we need to pull. converted to float
		meat_pulls = ceil(meat_pulls / 1000.0);					//how many pulls it will require to get.
		meat_pulls = min(pulls_remaining(), meat_pulls);		//limit by remaining pulls
		int meat_pull_int = meat_pulls * 1000;		//we want to round it up to nearest 1000
		if(meat_pulls > 0)
		{
			cli_execute("pull " +meat_pull_int+ " meat");
		}
	}
	
	return my_meat() >= target;
}

// Low on meat in Ronin: pull an unblemished pearl and autosell it, one pull for 11,037 Meat (pulling Meat itself
// takes a pull per 1,000). Below auto_pearlMeatBelow Meat (default 2000); auto_pearlForMeat = false turns it off.
// Only ever pulls a pearl already in Hagnk's, never buys one.
boolean auto_pearlForMeat()
{
	item pearl = $item[unblemished pearl];
	int below = get_property("auto_pearlMeatBelow") == "" ? 2000 : get_property("auto_pearlMeatBelow").to_int();
	if(get_property("auto_pearlForMeat") == "false" || in_hardcore() || can_interact() || my_meat() >= below
		|| pulls_remaining() == 0 || storage_amount(pearl) == 0 || !auto_is_valid(pearl))
	{
		return false;
	}
	if(!pullXWhenHaveY(pearl, 1, item_amount(pearl) + equipped_amount(pearl)) || item_amount(pearl) == 0)
	{
		return false;
	}
	auto_log_info("Only " + my_meat() + " Meat: pulled an unblemished pearl to autosell for " + autosell_price(pearl) + ".", "blue");
	return autosell(1, pearl);
}

// Fights left in the run, for valuing gear that pays a little every fight. A run is about auto_expectedRunTurns turns
// (900: run 99 took 894), and about 93% of turns are fights (run 100 day 2: 197 fights in 211 turns).
float auto_fightsLeft()
{
	int runTurns = get_property("auto_expectedRunTurns") == "" ? 900 : get_property("auto_expectedRunTurns").to_int();
	return max(0, runTurns - my_turncount()) * 0.93;
}

// What one maximizer point is worth in Meat over the rest of the run. The default statement prices a point at +1% Meat
// Drop, and a fight drops about auto_baseMeatPerFight Meat before bonuses (35: run 100 days 2-3, 230 fights).
float auto_scorePointMeat()
{
	float baseMeat = get_property("auto_baseMeatPerFight") == "" ? 35.0 : get_property("auto_baseMeatPerFight").to_float();
	return auto_fightsLeft() * baseMeat / 100.0;
}

// The gain a pulled piece of gear must show to pay for its pull (auto_pullValue, 1,000 Meat). Gear earns every fight
// it's worn, so the bar is low early (3.4 points at turn 0) and climbs as the run ends (6.4 at turn 420, 31 at turn
// 800). auto_levelUpPullMinScore fixes it instead.
float auto_pullMinScore()
{
	if(get_property("auto_levelUpPullMinScore") != "")
	{
		return get_property("auto_levelUpPullMinScore").to_float();
	}
	float pullValue = get_property("auto_pullValue") == "" ? 1000.0 : get_property("auto_pullValue").to_float();
	float pointMeat = auto_scorePointMeat();
	return pointMeat <= 0.0 ? 999999.0 : pullValue / pointMeat;
}

// The familiar's equipment slot: once a day in Ronin, the best stored item the familiar can wear is pulled if what it
// adds over what the familiar is wearing now, over the rest of the run, beats a pull's value (auto_pullMinScore). It
// doesn't wait for a level-up or compete with the level's gear pull. KoLmafia's maximizer doesn't offer familiar
// equipment from Hagnk's (checked: maximize("2familiar weight", 0, 0, 2, "") returns no familiar suggestion), which
// left the slot empty all of runs 99 and 100, so each item is scored here with the default statement's weights, on
// what it does for this familiar at this weight (a filthy child leash's +5 lb is +8% Item Drop on a 35 lb fairy). Meat
// the item collects itself counts as well (ant tools: 12.5 Meat on 40% of the familiar's actions), but the familiar
// only acts in rounds the monster survives: auto_familiarActionsPerFight, 0.3 (run 100 day 2: 85% of 197 fights ended
// on the first hit). Compared with what's worn, not only an empty slot: run 101 day 2 kept an anniversary tiny latex
// mask (+1 lb) on all day while the check waited for an empty slot. auto_familiarEquipPulls = false turns it off.
void auto_familiarEquipPull()
{
	if(get_property("auto_familiarEquipPulls") == "false" || in_hardcore() || can_interact())
	{
		return;
	}
	string key = my_ascensions() + ":" + my_daycount();
	if(get_property("auto_familiarEquipPullDone") == key)
	{
		return;
	}
	familiar fam = my_familiar();
	item worn = equipped_item($slot[familiar]);
	if(fam == $familiar[none])
	{
		// not today's check yet: it waits for a familiar. Say so once per start.
		if(!auto_familiarEquipPullExplained)
		{
			auto_familiarEquipPullExplained = true;
			auto_log_info("Familiar item pull is waiting for a familiar.", "blue");
		}
		return;
	}
	set_property("auto_familiarEquipPullDone", key);
	int reserve = get_property("auto_levelUpPullReserve") == "" ? 5 : get_property("auto_levelUpPullReserve").to_int();
	if(pulls_remaining() <= reserve)
	{
		auto_log_info("Familiar item pull: only " + pulls_remaining() + " pulls are left, keeping them.", "blue");
		return;
	}
	float baseMeat = get_property("auto_baseMeatPerFight") == "" ? 35.0 : get_property("auto_baseMeatPerFight").to_float();
	float actions = get_property("auto_familiarActionsPerFight") == "" ? 0.3 : get_property("auto_familiarActionsPerFight").to_float();
	// the familiar's weight without what it's wearing now, so each item is scored on the same base
	int weight = familiar_weight(fam) + weight_adjustment() - numeric_modifier(worn, "Familiar Weight").to_int();
	float[string] modWeight;
	modWeight["Item Drop"] = 5.0;
	modWeight["Meat Drop"] = 1.0;
	modWeight["Monster Level"] = 1.0;
	float score(item it)
	{
		if(it == $item[none])
		{
			return 0.0;
		}
		float total = 2 * numeric_modifier(it, "Familiar Weight");
		foreach mod, w in modWeight
		{
			total += w * (numeric_modifier(fam, mod, weight, it) - numeric_modifier(fam, mod, weight, $item[none]));
		}
		return total + numeric_modifier(it, "Meat Bonus") * numeric_modifier(it, "Sporadic Damage Aura") * actions * 100.0 / baseMeat;
	}
	float wornScore = score(worn);
	item best = $item[none];
	float bestGain = auto_pullMinScore();
	item runnerUp = $item[none];
	float runnerUpGain = -999999.0;
	foreach it, n in get_storage()
	{
		if(to_slot(it) != $slot[familiar] || !(boolean_modifier(it, "Generic") || familiar_equipment(fam) == it) || !auto_is_valid(it))
		{
			continue;
		}
		float gain = score(it) - wornScore;
		if(gain > bestGain)
		{
			best = it;
			bestGain = gain;
		}
		if(gain > runnerUpGain)
		{
			runnerUp = it;
			runnerUpGain = gain;
		}
	}
	string wearing = worn == $item[none] ? "nothing" : worn + " (+" + wornScore + ")";
	if(best == $item[none])
	{
		auto_log_info("Familiar item pull: nothing in Hagnk's beats " + wearing + " on " + fam + " by enough to pay for a pull (best is "
			+ runnerUp + " at +" + runnerUpGain + ", a pull needs +" + auto_pullMinScore() + ").", "blue");
		return;
	}
	auto_log_info("Familiar item pull: " + best + " beats " + wearing + " on " + fam + " by +" + bestGain + ", worth about "
		+ (bestGain * auto_scorePointMeat()).to_int() + " Meat over the rest of the run. Pulling it.", "blue");
	cli_execute("pull 1 " + best + "; equip familiar " + best);
}

// The maximizer can only score gear you own, so gear that would have to be made first is scored here: each term of a
// maximizer statement ("5item, meat, 0.5initiative, 0.2mp 1000max, ...") times the item's modifier. Close to the
// maximizer's own score for plain modifiers; derived ones (HP from Muscle, and so on) are left out on both sides of a
// comparison. Caps ("N max") are applied to the character's current total. Unknown terms are skipped.
float auto_statementScore(string statement, item it)
{
	string[string] alias = {
		"item" : "Item Drop", "items" : "Item Drop", "meat" : "Meat Drop", "init" : "Initiative", "initiative" : "Initiative",
		"da" : "Damage Absorption", "dr" : "Damage Reduction", "hp" : "Maximum HP", "mp" : "Maximum MP",
		"ml" : "Monster Level", "exp" : "Experience", "familiar exp" : "Familiar Experience", "adv" : "Adventures",
		"adventures" : "Adventures", "fites" : "PvP Fights", "crit" : "Critical Hit Percent", "spell crit" : "Spell Critical Percent"
	};
	float score = 0.0;
	foreach i, raw in split_string(statement, ",")
	{
		string term = raw.trim().to_lower_case();
		if(term == "" || term.starts_with("+") || term.starts_with("-equip") || term.starts_with("-tie") || term == "-fumble" || term == "effective")
		{
			continue;
		}
		matcher m = create_matcher("^(-?[0-9.]*)\\s*([a-z][a-z %']*?)\\s*(?:(-?[0-9.]+)\\s*max)?\\s*(?:(-?[0-9.]+)\\s*min)?$", term);
		if(!m.find())
		{
			continue;
		}
		float w = m.group(1) == "" ? 1.0 : (m.group(1) == "-" ? -1.0 : m.group(1).to_float());
		string key = m.group(2).trim();
		float value = 0.0;
		float current = 0.0;
		boolean plain = false;
		if(key == "mainstat" || key == "mus" || key == "muscle" || key == "myst" || key == "mysticality" || key == "mox" || key == "moxie")
		{
			stat st = key == "mainstat" ? my_primestat() : (key.starts_with("mus") ? $stat[Muscle] : (key.starts_with("mys") ? $stat[Mysticality] : $stat[Moxie]));
			value = numeric_modifier(it, st.to_string()) + numeric_modifier(it, st + " Percent") * my_basestat(st) / 100.0;
		}
		else if(key == "all res" || key == "all resistance" || key == "elemental damage")
		{
			string suffix = key == "elemental damage" ? " Damage" : " Resistance";
			foreach el in $strings[Hot, Cold, Spooky, Stench, Sleaze]
			{
				value += numeric_modifier(it, el + suffix);
			}
		}
		else if(key == "mp regen" || key == "hp regen")
		{
			string which = key == "mp regen" ? "MP" : "HP";
			value = (numeric_modifier(it, which + " Regen Min") + numeric_modifier(it, which + " Regen Max")) / 2.0;
		}
		else
		{
			string mod = alias contains key ? alias[key] : key;
			value = numeric_modifier(it, mod);
			current = numeric_modifier(mod);
			plain = true;
		}
		if(plain && m.group(3) != "")
		{
			// capped: only the part that still fits under the cap counts
			float cap = m.group(3).to_float();
			value = min(current + value, cap) - min(current, cap);
		}
		score += w * value;
	}
	return score;
}

// Gear that can be made from items in Hagnk's (and inventory): KoLmafia's maximizer offers what can be made from
// inventory, and what can be pulled whole, but never "pull the parts, then make it". Only recipes KoLmafia can make
// right now count (a tenderizing hammer for smithing, jewelry-making pliers for jewelry, and so on), one level deep.
// Returns the best one whose gain over what's worn in its slot pays for its pulls and crafting turns, with what it
// is worth net in Meat; $item[none] if none does.
item auto_bestStorageCraft(string statement, int pullsFree, float pullValue, float turnValue, float pointMeat, float[item] netMeat, int[item] pullsNeeded)
{
	item best = $item[none];
	float bestNet = 0.0;
	foreach it in $items[]
	{
		slot sl = to_slot(it);
		if(!($slots[hat, weapon, off-hand, back, shirt, pants, acc1] contains sl) || available_amount(it) > 0 || !can_equip(it) || !auto_is_valid(it))
		{
			continue;
		}
		int[item] parts = auto_craftParts(it);
		if(count(parts) == 0)
		{
			continue;
		}
		int pulls = 0;
		boolean ok = true;
		// the finished item already in Hagnk's is one pull and no crafting (run 101 made a Mark IV Steam-Hat from two
		// pulls with one in Hagnk's)
		boolean whole = storage_amount(it) > 0 && canPull(it);
		if(whole)
		{
			pulls = 1;
		}
		else
		{
			foreach part, qty in parts
			{
				int missing = max(0, qty - item_amount(part));
				if(missing > 0 && (storage_amount(part) < missing || !canPull(part)))
				{
					ok = false;
				}
				pulls += missing;
			}
		}
		// nothing to pull: the maximizer already offers it as "make"
		if(!ok || pulls == 0 || pulls > pullsFree)
		{
			continue;
		}
		float worn;
		if(sl == $slot[acc1])
		{
			worn = 999999.0;
			foreach acc in $slots[acc1, acc2, acc3]
			{
				worn = min(worn, auto_statementScore(statement, equipped_item(acc)));
			}
		}
		else if(sl == $slot[weapon] && weapon_hands(it) > 1)
		{
			worn = auto_statementScore(statement, equipped_item($slot[weapon])) + auto_statementScore(statement, equipped_item($slot[off-hand]));
		}
		else if(sl == $slot[off-hand] && weapon_hands(equipped_item($slot[weapon])) > 1)
		{
			continue;
		}
		else
		{
			worn = auto_statementScore(statement, equipped_item(sl));
		}
		float gain = auto_statementScore(statement, it) - worn;
		// smithing a Loathing pair is a manual recipe KoLmafia can't time: count it as one adventure
		int turns = whole ? 0 : (count(get_ingredients(it)) > 0 ? max(0, creatable_turns(it, 1, true)) : 1);
		float net = gain * pointMeat - pulls * pullValue - turns * turnValue;
		if(net > bestNet)
		{
			best = it;
			bestNet = net;
			netMeat[it] = net;
			pullsNeeded[it] = pulls;
		}
	}
	return best;
}

// Pull the item if Hagnk's has it whole; otherwise pull the missing parts and make it. Then wear it.
boolean auto_makeStorageCraft(item it)
{
	if(storage_amount(it) > 0 && canPull(it))
	{
		if(!take_storage(1, it))
		{
			return false;
		}
	}
	else
	{
		foreach part, qty in auto_craftParts(it)
		{
			int missing = max(0, qty - item_amount(part));
			if(missing > 0 && !take_storage(missing, part))
			{
				return false;
			}
		}
		if(!auto_craftOne(it))
		{
			return false;
		}
	}
	slot sl = to_slot(it);
	if(sl == $slot[acc1])
	{
		// replace the accessory that adds least
		float least = 999999.0;
		string statement = get_property("auto_maximize_current");
		foreach acc in $slots[acc1, acc2, acc3]
		{
			float score = auto_statementScore(statement, equipped_item(acc));
			if(score < least)
			{
				least = score;
				sl = acc;
			}
		}
	}
	return equip(sl, it);
}

// Once per level in Ronin: ask the maximizer, with Hagnk's included, whether pulling one piece of equipment would
// improve the gear autoscend is currently after, and pull and wear the best one. Items pulled at level 1 are often
// outgrown by level 7, so this keeps the gear current as the run goes. Keeps auto_levelUpPullReserve pulls (5) for
// planned pulls, needs a score gain that pays for the pull (auto_pullMinScore), never buys (no "buy & pull").
// The familiar slot is auto_familiarEquipPull's. auto_levelUpPulls = false turns it off.
void auto_levelUpPull()
{
	if(get_property("auto_levelUpPulls") == "false" || in_hardcore() || can_interact())
	{
		return;
	}
	string key = my_ascensions() + ":" + my_level();
	if(get_property("auto_levelUpPullDone") == key)
	{
		return;
	}
	set_property("auto_levelUpPullDone", key);
	int reserve = get_property("auto_levelUpPullReserve") == "" ? 5 : get_property("auto_levelUpPullReserve").to_int();
	string statement = get_property("auto_maximize_current");
	if(pulls_remaining() <= reserve || statement == "")
	{
		return;
	}
	// The maximizer scores each suggestion as a gain over what is worn in that slot right now, so first wear the best
	// owned gear in every slot. Otherwise a leftover from the last zone is the yardstick: run 100's level 11 check
	// found a giant artisanal rice peeler (worn for spell damage) in the weapon slot and scored Pigsticker of Violence
	// +146 against it, with the far better legendary seal-clubbing club in inventory.
	maximize(statement, false);
	// Then, for every slot, the best item in Hagnk's and how much it beats that. Pull and wear the single biggest gain,
	// if it pays for the pull (auto_pullMinScore): one a level (auto_levelUpPullMax), or the day's pulls would be gone
	// by level 5. Keeps the reserve.
	float minScore = auto_pullMinScore();
	int maxPulls = get_property("auto_levelUpPullMax") == "" ? 1 : get_property("auto_levelUpPullMax").to_int();
	// With dynamic ML, gear pays back mostly as the extra ML it makes safe (stats every fight). When survival is what
	// holds ML down, max HP and damage reduction also count for the ML they would unlock, at the statement's weight
	// for ML (1 if it has none), in both the maximizer's suggestions and the made-from-Hagnk's scores.
	float[string] unlock = auto_mlUnlockPerPoint(my_location());
	if(count(unlock) > 0)
	{
		float mlWeight = 1.0;
		matcher mlTerm = create_matcher("(?:^|,)\\s*(-?[0-9.]*)\\s*ml(?:\\s|,|$)", statement.to_lower_case());
		if(mlTerm.find() && mlTerm.group(1) != "" && mlTerm.group(1) != "-")
		{
			mlWeight = mlTerm.group(1).to_float();
		}
		if(mlWeight > 0)
		{
			foreach keyword, per in unlock
			{
				statement = auto_addStatementWeight(statement, keyword, per * mlWeight);
			}
			auto_log_info("Level " + my_level() + ": ML in " + my_location() + " is held at " + get_property("auto_MLSafetyLimit")
				+ " by max HP, so max HP and damage reduction also count for the ML they would unlock.", "blue");
		}
	}
	float[slot] slotBest;
	string[slot] slotCommand;
	string[slot] slotWhat;
	// The maximizer gives only its best suggestion per slot. With autoSatisfyWithMall on, that can be "buy & pull" (mall
	// to Hagnk's, then pull), which is skipped here, and the slot's best pull-only item is never seen: run 101's level
	// 9 hat slot offered only a Space Soldier Helmet to buy, hiding the Mark IV and V Steam-Hats in Hagnk's. So ask
	// with mall buying off.
	string mallSetting = get_property("autoSatisfyWithMall");
	set_property("autoSatisfyWithMall", "false");
	try
	{
		foreach i, entry in maximize(statement, 0, 0, 2, "equip")
		{
			if(!entry.command.contains_text("pull ") || entry.command.contains_text("buy") || entry.score <= minScore)
			{
				continue;
			}
			matcher m = create_matcher("equip (\\S+) ", entry.command);
			slot sl = m.find() ? m.group(1).to_slot() : $slot[none];
			// an empty off-hand beside a two-handed weapon is empty on purpose; so is the familiar slot with no familiar
			if(sl == $slot[none] || (sl == $slot[off-hand] && weapon_hands(equipped_item($slot[weapon])) > 1)
				|| (sl == $slot[familiar] && my_familiar() == $familiar[none]))
			{
				continue;
			}
			if(entry.score > slotBest[sl])
			{
				slotBest[sl] = entry.score;
				slotCommand[sl] = entry.command;
				slotWhat[sl] = entry.display;
			}
		}
	}
	finally
	{
		set_property("autoSatisfyWithMall", mallSetting);
	}
	// Gear that has to be made from parts in Hagnk's competes for the level's pick on Meat net of its pulls and crafting
	// turns (a pair of Loathing halves costs two pulls), against the best single pull's net.
	float pullValue = get_property("auto_pullValue") == "" ? 1000.0 : get_property("auto_pullValue").to_float();
	float turnValue = get_property("auto_turnValue") == "" ? 2000.0 : get_property("auto_turnValue").to_float();
	float pointMeat = auto_scorePointMeat();
	float singleNet = 0.0;
	foreach sl, score in slotBest
	{
		singleNet = max(singleNet, score * pointMeat - pullValue);
	}
	float[item] craftNet;
	int[item] craftPulls;
	item craft = auto_bestStorageCraft(statement, pulls_remaining() - reserve, pullValue, turnValue, pointMeat, craftNet, craftPulls);
	if(craft != $item[none] && craftNet[craft] > singleNet)
	{
		string how = "pulling " + craft + " (1 pull)";
		if(storage_amount(craft) == 0)
		{
			string parts = "";
			foreach part in auto_craftParts(craft)
			{
				parts += (parts == "" ? "" : " + ") + part;
			}
			how = "making " + craft + " from " + parts + " (" + craftPulls[craft] + " pulls)";
		}
		auto_log_info("Level " + my_level() + ": best gain is " + how + " from Hagnk's, worth about " + craftNet[craft].to_int()
			+ " Meat net; the best single pull the maximizer offered nets " + singleNet.to_int() + ".", "blue");
		if(auto_makeStorageCraft(craft))
		{
			return;
		}
		auto_log_warning("Couldn't make " + craft + "; taking the best single pull instead.", "red");
	}
	for(int n = 0; n < maxPulls && pulls_remaining() > reserve; n++)
	{
		slot pick = $slot[none];
		foreach sl, score in slotBest
		{
			if(pick == $slot[none] || score > slotBest[pick])
			{
				pick = sl;
			}
		}
		if(pick == $slot[none])
		{
			break;
		}
		auto_log_info("Level " + my_level() + ": best gain from Hagnk's is " + slotWhat[pick] + " (" + pick + ", score +" + slotBest[pick] + ").", "blue");
		cli_execute(slotCommand[pick]);
		remove slotBest[pick];
	}
}

// Day 2 prep. Day 1 is short of Meat and pulls; by day 2 there is some leeway, so set up the tools that let autoscend
// make things rather than pull them: a tenderizing hammer for smithing (the Nemesis quest needs one later anyway, and
// Hagnk's usually has one, so it is pulled, never bought here), an oven for cooking and a cocktailcrafting kit for
// mixing (General Store, about 1,000 Meat each). With them, smithed gear, cooked food and mixed drinks count among
// what can be made.
void auto_day2Prep()
{
	item hammer = $item[tenderizing hammer];
	if(available_amount(hammer) == 0 && storage_amount(hammer) > 0 && canPull(hammer))
	{
		auto_log_info("Day 2 prep: pulling a tenderizing hammer so gear can be smithed.", "blue");
		pullXWhenHaveY(hammer, 1, 0);
	}
	ovenHandle();
	cocktailKitHandle();
}

int handlePulls(int day)
{
	if(item_amount($item[Astral Six-Pack]) > 0)
	{
		use(1, $item[Astral Six-Pack]);
	}
	if(item_amount($item[Astral Hot Dog Dinner]) > 0)
	{
		use(1, $item[Astral Hot Dog Dinner]);
	}
	if(item_amount($item[[10882]carton of astral energy drinks]) > 0)
	{
		use(1, $item[[10882]carton of astral energy drinks]);
	}

	if(in_hardcore())
	{
		return 0;
	}

	if(day == 1)
	{
		set_property("lightsOutAutomation", "1");
		# Do starting pulls:
		if((pulls_remaining() != 20) && !in_hardcore() && (my_turncount() > 0))
		{
			auto_log_info("I assume you've handled your pulls yourself... who knows.");
			return 0;
		}
		if(auto_turbo())
		{
			//Pull expensive organ cleansers first if you are running turbo and you own them
			foreach it in $items[Spice Melange, Ultra Mega Sour Ball, Alien plant pod, Alien animal milk]
			{
				if(storage_amount(it) > 0 && auto_is_valid(it) && !pulledToday(it))
				{
					if(user_confirm("Pulling a " + it + ". If you are ok with this, you have 15 seconds to hit 'Yes'", 15000, false))
					{
						pullXWhenHaveY(it, 1, 0);
					}
				}
			}
			//Make sure we have the legendary pizzas if we want to/can consume them so we take full advantage of the dieting pills
			if(!get_property("auto_dontConsumeLegendPizzas").to_boolean())
			{
				foreach it in $items[Pizza of Legend, Calzone of Legend, Deep Dish of Legend]
				{
					if(canEat(it) && !pulledToday(it))
					{
						pullXWhenHaveY(it, 1, 0);
					}
					// Pull at least one early dieting pill if we've acquired a legendary pizza
					if (item_amount(it) > 0 && !pulledToday($item[Dieting Pill]))
					{
						pullXWhenHaveY($item[Dieting Pill], 1, 0);
					}
				}
			}
			
			// get a wet stew, or its ingredients
			if (!pulledToday($item[wet stew]))
			{
				auto_pullWetStew();
			}
		}

		// pulls for small path
		auto_SmallPulls();
		// pulls for 11THIAU path
		iluh_pulls();
		// pulls for Avant Guard path
		ag_pulls();
		// pulls for Z is for Zootomist path
		zoo_startPulls();

		// generic pulls for any path are below
		if(auto_is_valid($item[etched hourglass]))
		{
			pullXWhenHaveY($item[etched hourglass], 1, 0);
		}
		
		// generic pull for any path, but unusable in KoE
		if(!in_koe() && auto_is_valid($item[Infinite BACON Machine]))
		{
			pullXWhenHaveY($item[Infinite BACON Machine], 1, 0);
		}

		// things we would always pull but cannot pull due to LoL usage restrictions
		if(!in_lol())
		{
			if((storage_amount($item[mafia thumb ring]) > 0) && auto_is_valid($item[mafia thumb ring]))
			{
				pullXWhenHaveY($item[mafia thumb ring], 1, 0);
			}
			if((storage_amount($item[can of rain-doh]) > 0) && auto_is_valid($item[Can Of Rain-Doh]) && (pullXWhenHaveY($item[can of Rain-doh], 1, 0)))
			{
				if(item_amount($item[Can of Rain-doh]) > 0)
				{
					use(1, $item[can of Rain-doh]);
					put_closet(1, $item[empty rain-doh can]);
				}
			}
			if(storage_amount($item[Buddy Bjorn]) > 0 && auto_is_valid($item[Buddy Bjorn]) && pathHasFamiliar())
			{
				pullXWhenHaveY($item[Buddy Bjorn], 1, 0);
			}
			if((storage_amount($item[Camp Scout Backpack]) > 0) && !possessEquipment($item[Buddy Bjorn]) && auto_is_valid($item[Camp Scout Backpack]))
			{
				pullXWhenHaveY($item[Camp Scout Backpack], 1, 0);
			}
			if(!possessEquipment($item[Astral Shirt]))
			{
				boolean getPeteShirt = true;
				if(!hasTorso())
				{
					getPeteShirt = false;
				}
				if((my_primestat() == $stat[Muscle]) && get_property("loveTunnelAvailable").to_boolean())
				{
					getPeteShirt = false;
				}
				if(in_glover())
				{
					getPeteShirt = false;
				}
				if(storage_amount($item[Sneaky Pete\'s Leather Jacket]) == 0 && storage_amount($item[Sneaky Pete\'s Leather Jacket (Collar Popped)]) == 0)
				{
					getPeteShirt = false;
				}
				if(getPeteShirt)
				{
					pullXWhenHaveY($item[Sneaky Pete\'s Leather Jacket], 1, 0);
					if(item_amount($item[Sneaky Pete\'s Leather Jacket]) == 0)
					{
						pullXWhenHaveY($item[Sneaky Pete\'s Leather Jacket (Collar Popped)], 1, 0);
					}
					else
					{
						auto_fold($item[Sneaky Pete\'s Leather Jacket (Collar Popped)]);
					}
				}
			}
			if((equipped_item($slot[folder1]) == $item[folder (tranquil landscape)]) && (equipped_item($slot[folder2]) == $item[folder (skull and crossbones)]) && (equipped_item($slot[folder3]) == $item[folder (Jackass Plumber)]) && auto_is_valid(wrap_item($item[Over-The-Shoulder Folder Holder])))
			{
				pullXWhenHaveY($item[over-the-shoulder folder holder], 1, 0);
			}
			if(auto_have_skill($skill[Summon Smithsness]))
			{
				pullXWhenHaveY($item[hand in glove], 1, 0);
			}
			pullLegionKnife();
		}

		// pulls excluding a handful of paths are below
		if(!in_heavyrains() && pathHasFamiliar())
		{	// heavy rains familiars largely need miniature life preserver
			if(!possessEquipment($item[Snow Suit]) && !possessEquipment($item[Astral Pet Sweater]) && auto_is_valid($item[Snow Suit]))
			{
				pullXWhenHaveY($item[snow suit], 1, 0);
			}
			boolean famStatEq = possessEquipment($item[fuzzy polar bear ears]) || possessEquipment($item[miniature goose mask]) || possessEquipment($item[tiny glowing red nose]);
			
			if(!possessEquipment($item[Snow Suit]) && !possessEquipment($item[Filthy Child Leash]) && !possessEquipment($item[Astral Pet Sweater]) &&
			!famStatEq && auto_is_valid($item[Filthy Child Leash]))
			{
				pullXWhenHaveY($item[Filthy Child Leash], 1, 0);
			}
		}
		if(!in_pokefam() && auto_is_valid($item[Replica Bat-oomerang]))
		{	// cannot use combat items in pokefam
			pullXWhenHaveY($item[Replica Bat-oomerang], 1, 0);
		}
		if((my_primestat() == $stat[Muscle]) && !in_wotsf() && !in_heavyrains() && !in_lol())
		{	// no need for shields in WotSF; cannot pull them in LoL
			if(possessEquipment($item[familiar scrapbook]) && auto_is_valid($item[familiar scrapbook]) && my_class() != $class[Turtle Tamer])
			{
				// familiar scrapbook will probably be equipped in preference to Fake Washboard
			}
			else if((closet_amount($item[Fake Washboard]) == 0) && auto_is_valid($item[Fake Washboard]))
			{
				pullXWhenHaveY($item[Fake Washboard], 1, 0);
			}
			if((item_amount($item[Fake Washboard]) == 0) && (closet_amount($item[Fake Washboard]) == 0))
			{
				if (!auto_turbo())
				{
					pullXWhenHaveY($item[numberwang], 1, 0);
				}
			}
			else
			{
				if(get_property("barrelShrineUnlocked").to_boolean())
				{
					put_closet(item_amount($item[Fake Washboard]), $item[Fake Washboard]);
				}
			}
		}
		else
		{
			pullXWhenHaveY($item[Numberwang], 1, 0);
		}
		if(((my_class() == $class[Sauceror]) || (my_class() == $class[Pastamancer])) && !in_wotsf() && !in_lol())
		{	// no need for offhands in WotSF; cannot pull items in LoL
			if((item_amount(wrap_item($item[Deck of Every Card])) == 0) && !auto_have_skill($skill[Summon Smithsness]))
			{
				pullXWhenHaveY($item[Thor\'s Pliers], 1, 0);
			}
			if(auto_is_valid($item[Basaltamander Buckler]))
			{
				pullXWhenHaveY($item[Basaltamander Buckler], 1, 0);
			}
		}

// path specific pulls are below
		if(in_wotsf())
		{
			pullXWhenHaveY($item[Bittycar Meatcar], 1, 0);
		}
		if((in_picky() || !canChangeFamiliar()) && !get_property("auto_dontConsumeKeyLimePies").to_boolean() && (item_amount(wrap_item($item[Deck of Every Card])) == 0) && (fullness_left() >= 4))
		{
			if((item_amount($item[Boris\'s Key]) == 0) && canEat($item[Boris\'s Key Lime Pie]) && !contains_text(get_property("nsTowerDoorKeysUsed"), $item[Boris\'s Key]))
			{
				pullXWhenHaveY($item[Boris\'s Key Lime Pie], 1, 0);
			}
			if((item_amount($item[Sneaky Pete\'s Key]) == 0) && canEat($item[Sneaky Pete\'s Key Lime Pie]) && !contains_text(get_property("nsTowerDoorKeysUsed"), $item[Sneaky Pete\'s Key]))
			{
				pullXWhenHaveY($item[Sneaky Pete\'s Key Lime Pie], 1, 0);
			}
			if((item_amount($item[Jarlsberg\'s Key]) == 0) && canEat($item[Jarlsberg\'s Key Lime Pie]) && !contains_text(get_property("nsTowerDoorKeysUsed"), $item[Jarlsberg\'s Key]))
			{
				pullXWhenHaveY($item[Jarlsberg\'s Key Lime Pie], 1, 0);
			}
		}
		if(in_picky())
		{
			pullXWhenHaveY($item[gumshoes], 1, 0);
		}
		if(in_pokefam())
		{
			pullXWhenHaveY($item[Ring Of Detect Boring Doors], 1, 0);
			pullXWhenHaveY($item[Pick-O-Matic Lockpicks], 1, 0);
			pullXWhenHaveY($item[Eleven-Foot Pole], 1, 0);
		}
		if(in_darkGyffte())
		{
			auto_log_info("You are a powerful vampire who is doing a softcore run. Turngen is busted in this path, so let's see how much we can get.", "blue");
			pullXWhenHaveY($item[mime army shotglass], 1, 0);
		}
		if(in_lol())
		{	// some items that can be pulled to help accelerate runs
			pullXWhenHaveY($item[portable pantogram], 1, 0);
			pullXWhenHaveY($item[SpinMaster&trade; lathe], 1, 0);
			pullXWhenHaveY($item[Asdon Martin keyfob (on ring)], 1, 0);		
		}
	}
	else if(day == 2)
	{
		if((closet_amount($item[Fake Washboard]) == 1) && get_property("barrelShrineUnlocked").to_boolean())
		{
			take_closet(1, $item[Fake Washboard]);
		}
		// pulls for Avant Guard path
		ag_pulls();
		zoo_d2Pulls();
		auto_day2Prep();
	}

	// do this regardless of day if we still need to complete the bridge -- but only once the Orc Chasm is the quest
	// (level 9), not from day 1, days before the bridge, spending a pull that day's quests could use
	if(my_level() >= 9 && canPull($item[smut orc keepsake box]) && (get_property("chasmBridgeProgress").to_int() + min(lumberCount(),fastenerCount()) < bridgeGoal()))
	{
		if(pullXWhenHaveY($item[smut orc keepsake box], 1, 0))
		{
			use(1, $item[smut orc keepsake box]);
		}
	}

	return pulls_remaining();
}

boolean LX_craftAcquireItems()
{
	if((get_property("lastGoofballBuy").to_int() != my_ascensions()) && (internalQuestStatus("questL03Rat") >= 0))
	{
		visit_url("place.php?whichplace=woods");
		auto_log_info("Gotginb Goofballs", "blue");
		visit_url("tavern.php?place=susguy&action=buygoofballs", true);
		put_closet(item_amount($item[Bottle of Goofballs]), $item[Bottle of Goofballs]);
	}

	auto_floundryUse();

	// Snow Berries can be acquired out of standard by using Van Keys from NEP. We need to check to make sure they are usable.
	if(auto_is_valid($item[snow berries]))
	{
		if((item_amount($item[snow berries]) == 3) && (my_daycount() == 1) && get_property("auto_grimstoneFancyOilPainting").to_boolean())
		{
			cli_execute("make 1 snow cleats");
		}

		if((item_amount($item[snow berries]) > 0) && (my_daycount() > 1) && (get_property("chasmBridgeProgress").to_int() >= bridgeGoal()) && (my_level() >= 9))
		{
			visit_url("place.php?whichplace=orc_chasm");
			if(get_property("chasmBridgeProgress").to_int() >= bridgeGoal())
			{
				#if(in_hardcore() && isGuildClass())
				if(isGuildClass())
				{
					if((item_amount($item[Snow Berries]) >= 3) && (item_amount($item[Ice Harvest]) >= 3) && (item_amount($item[Unfinished Ice Sculpture]) == 0))
					{
						cli_execute("make 1 Unfinished Ice Sculpture");
					}
					if((item_amount($item[Snow Berries]) >= 2) && (item_amount($item[Snow Crab]) == 0))
					{
						cli_execute("make 1 Snow Crab");
					}
				}
				#cli_execute("make " + item_amount($item[snow berries]) + " snow cleats");
			}
			else
			{
				abort("Bridge progress came up as >= 30 but is no longer after viewing the page.");
			}
		}
	}

	if(knoll_available() && (item_amount($item[Detuned Radio]) == 0) && (my_meat() >= npc_price($item[Detuned Radio])) && auto_is_valid($item[Detuned Radio]) && (!in_amw() || my_level() >= 7))
	{
		auto_buyUpTo(1, $item[Detuned Radio]);
		auto_setMCDToCap();
	}

	if((my_adventures() <= 3) && (my_daycount() == 1) && in_hardcore())
	{
		if(LX_meatMaid())
		{
			return true;
		}
	}

	#Can we have some other way to check that we have AT skills? Checking all skills just to be sure.
	if((item_amount($item[Antique Accordion]) == 0) && (item_amount($item[Aerogel Accordion]) == 0) && isUnclePAvailable() && (my_meat() >= npc_price($item[Antique Accordion])) && (auto_predictAccordionTurns() < 10) && !in_glover())
	{
		boolean buyAntiqueAccordion = false;

		foreach SongCheck in ATSongList()
		{
			if(have_skill(SongCheck.to_skill()))
			{
				buyAntiqueAccordion = true;
			}
		}

		if(buyAntiqueAccordion)
		{
			auto_buyUpTo(1, $item[Antique Accordion]);
		}
	}

	if(item_amount($item[Seal Tooth]) == 0 && auto_is_valid($item[Seal Tooth]))
	{
		//saucerors want to use sealtooth to delay so that mortar shell delivers final blow for weaksauce MP explosion
		//TODO: add delaying for mortar for other classes in combat and then remove the sauceror requirement here.
		if(my_meat() > 7500 || (my_class() == $class[Sauceror] && canUse($skill[Stuffed Mortar Shell])))
		{
			acquireHermitItem($item[Seal Tooth]);
		}
	}
	

	if(my_class() == $class[Turtle Tamer] && !in_wotsf()) // no need for shields in way of the surprising fist
	{
		if(!possessEquipment($item[Turtle Wax Shield]) && (item_amount($item[Turtle Wax]) > 0))
		{
			use(1, $item[Turtle Wax]);
		}
		if(have_skill($skill[Armorcraftiness]) && !possessEquipment($item[Painted Shield]) && (my_meat() > 3500) && (item_amount($item[Painted Turtle]) > 0) && (item_amount($item[Tenderizing Hammer]) > 0))
		{
			// Make Painted Shield - Requires an Adventure
		}
		if(have_skill($skill[Armorcraftiness]) && !possessEquipment($item[Spiky Turtle Shield]) && (my_meat() > 3500) && (item_amount($item[Hedgeturtle]) > 1) && (item_amount($item[Tenderizing Hammer]) > 0))
		{
			// Make Spiky Turtle Shield - Requires an Adventure
		}
	}
	if((get_power(equipped_item($slot[pants])) < 70) && !possessEquipment($item[Demonskin Trousers]) && (my_meat() >= npc_price($item[Pants Kit])) && (item_amount($item[Demon Skin]) > 0) && (item_amount($item[Tenderizing Hammer]) > 0) && knoll_available())
	{
		auto_buyUpTo(1, $item[Pants Kit]);
		autoCraft("smith", 1, $item[Pants Kit], $item[Demon Skin]);
	}
	if(!possessEquipment($item[Tighty Whiteys]) && (my_meat() >= npc_price($item[Pants Kit])) && (item_amount($item[White Snake Skin]) > 0) && (item_amount($item[Tenderizing Hammer]) > 0) && knoll_available())
	{
		auto_buyUpTo(1, $item[Pants Kit]);
		autoCraft("smith", 1, $item[Pants Kit], $item[White Snake Skin]);
	}

	if(!possessEquipment($item[Grumpy Old Man Charrrm Bracelet]) && (item_amount($item[Jolly Roger Charrrm Bracelet]) > 0) && (item_amount($item[Grumpy Old Man Charrrm]) > 0))
	{
		use(1, $item[Jolly Roger Charrrm Bracelet]);
		use(1, $item[Grumpy Old Man Charrrm]);
	}

	if(!possessEquipment($item[Booty Chest Charrrm Bracelet]) && (item_amount($item[Jolly Roger Charrrm Bracelet]) > 0) && (item_amount($item[Booty Chest Charrrm]) > 0))
	{
		use(1, $item[Jolly Roger Charrrm Bracelet]);
		use(1, $item[Booty Chest Charrrm]);
	}

	if((item_amount($item[Magical Baguette]) > 0) && !possessEquipment($item[Loafers]))
	{
		visit_url("inv_use.php?pwd=&which=1&whichitem=8167");
		run_choice(2);
	}
	if((item_amount($item[Magical Baguette]) > 0) && !possessEquipment($item[Bread Basket]))
	{
		visit_url("inv_use.php?pwd=&which=1&whichitem=8167");
		run_choice(3);
	}
	if((item_amount($item[Magical Baguette]) > 0) && !possessEquipment($item[Breadwand]))
	{
		visit_url("inv_use.php?pwd=&which=1&whichitem=8167");
		run_choice(1);
	}

	if(knoll_available() && (have_skill($skill[Torso Awareness]) || have_skill($skill[Best Dressed])) && (item_amount($item[Demon Skin]) > 0) && !possessEquipment($item[Demonskin Jacket]))
	{
		//Demonskin Jacket, requires an adventure, knoll available doesn\'t matter here...
	}

	if(in_koe())
	{
		if((creatable_amount($item[Antique Accordion]) > 0 && !possessEquipment($item[Antique Accordion])) && auto_predictAccordionTurns() < 10)
		{
			retrieve_item(1, $item[Antique Accordion]);
		}
		if(creatable_amount($item[low-pressure oxygen tank]) > 0 && !possessEquipment($item[low-pressure oxygen tank]))
		{
			retrieve_item(1, $item[low-pressure oxygen tank]);
		}
	}

	LX_dolphinKingMap();
	auto_mayoItems();
	auto_checkTakerSpace();

	if(item_amount($item[Metal Meteoroid]) > 0 && !in_tcrs())
	{
		item it = $item[Meteorthopedic Shoes];
		if(!possessEquipment(it))
		{
			int choice = 1 + to_int(it) - to_int($item[Meteortarboard]);
			string temp = visit_url("inv_use.php?pwd=&which=3&whichitem=9516");
			temp = visit_url("choice.php?pwd=&whichchoice=1264&option=" + choice);
		}

		it = $item[Meteortarboard];
		if(!possessEquipment(it) && (get_power(equipped_item($slot[Hat])) < 140) && (get_property("auto_beatenUpCount").to_int() >= 5))
		{
			int choice = 1 + to_int(it) - to_int($item[Meteortarboard]);
			string temp = visit_url("inv_use.php?pwd=&which=3&whichitem=9516");
			temp = visit_url("choice.php?pwd=&whichchoice=1264&option=" + choice);
		}

		it = $item[Meteorite Guard];
		if(!possessEquipment(it) && !possessEquipment($item[Kol Con 13 Snowglobe]) && (get_property("auto_beatenUpCount").to_int() >= 5))
		{
			int choice = 1 + to_int(it) - to_int($item[Meteortarboard]);
			string temp = visit_url("inv_use.php?pwd=&which=3&whichitem=9516");
			temp = visit_url("choice.php?pwd=&whichchoice=1264&option=" + choice);
		}
	}

	{
		if(item_amount($item[Portable Pantogram]) > 0)
		{
			switch(my_daycount())
			{
			case 1:
				pantogramPants(my_primestat(), $element[hot], 1, 1, 1);
				break;
			default:
				pantogramPants(my_primestat(), $element[cold], 1, 2, 1);
				break;
			}
		}
		#set_property("_dailyCreates", true);
	}

	return false;
}
