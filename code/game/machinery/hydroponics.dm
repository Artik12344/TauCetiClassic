#define HYDRO_RATING_MULTIPLIER 0.50

/obj/machinery/hydroponics
	name = "hydroponics tray"
	icon = 'icons/obj/hydroponics.dmi'
	icon_state = "hydrotray"
	density = 1
	anchored = 1
	var/waterlevel = 100 // The amount of water in the tray (max 100)
	var/maxwater = 100		//The maximum amount of water in the tray
	var/nutrilevel = 10 // The amount of nutrient in the tray (max 10)
	var/maxnutri = 10		//The maximum nutrient of water in the tray
	var/pestlevel = 0 // The amount of pests in the tray (max 10)
	var/weedlevel = 0 // The amount of weeds in the tray (max 10)
	var/yieldmod = 1 //Modifier to yield
	var/mutmod = 1 //Modifier to mutation chance
	var/toxic = 0 // Toxicity in the tray?
	var/age = 0 // Current age
	var/dead = 0 // Is it dead?
	var/health = 0 // Its health.
	var/lastproduce = 0 // Last time it was harvested
	var/lastcycle = 0 //Used for timing of cycles.
	var/cycledelay = 200 // About 10 seconds / cycle
	var/planted = 0 // Is it occupied?
	var/harvest = 0 //Ready to harvest?
	var/obj/item/seeds/myseed = null // The currently planted seed
	var/rating = 1
	var/unwrenchable = 1

	pixel_y=8

/obj/machinery/hydroponics/constructable
	name = "hydroponics tray"
	icon = 'icons/obj/hydroponics.dmi'
	icon_state = "hydrotray3"

/obj/machinery/hydroponics/constructable/New()
	..()
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/hydroponics(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(null)
	component_parts += new /obj/item/weapon/stock_parts/manipulator(null)
	component_parts += new /obj/item/weapon/stock_parts/console_screen(null)
	RefreshParts()

/obj/machinery/hydroponics/constructable/RefreshParts()
	var/tmp_capacity = 0
	for (var/obj/item/weapon/stock_parts/matter_bin/M in component_parts)
		tmp_capacity += M.rating
	for (var/obj/item/weapon/stock_parts/manipulator/M in component_parts)
		rating = HYDRO_RATING_MULTIPLIER * M.rating
	maxwater = tmp_capacity * 50 // Up to 300
	maxnutri = tmp_capacity * 5 // Up to 30
	waterlevel = maxwater
	nutrilevel = 3

/obj/machinery/hydroponics/Destroy()
	if(myseed)
		qdel(myseed)
		myseed = null
	return ..()

/obj/machinery/hydroponics/constructable/attackby(obj/item/I, mob/user)
	if(default_deconstruction_screwdriver(user, "hydrotray3", "hydrotray3", I))
		return

	if(exchange_parts(user, I))
		return

	if(default_pry_open(I))
		return

	if(default_unfasten_wrench(user, I))
		return

	if(istype(I, /obj/item/weapon/crowbar))
		if(anchored==2)
			user << "Unscrew the hoses first!"
			return
		default_deconstruction_crowbar(I, 1)
	..()

/obj/machinery/hydroponics/bullet_act(var/obj/item/projectile/Proj) //Works with the Somatoray to modify plant variables.
	if(!planted)
		..()
		return
	if(istype(Proj ,/obj/item/projectile/energy/floramut))
		mutate()
	else if(istype(Proj ,/obj/item/projectile/energy/florayield))
		if(myseed.yield == 0)//Oh god don't divide by zero you'll doom us all.
			adjustSYield(1 * rating)
			//world << "Yield increased by 1, from 0, to a total of [myseed.yield]"
		else if(prob(1/(myseed.yield * myseed.yield) *100))//This formula gives you diminishing returns based on yield. 100% with 1 yield, decreasing to 25%, 11%, 6, 4, 2...
			adjustSYield(1 * rating)
			//world << "Yield increased by 1, to a total of [myseed.yield]"
	else
		..()
		return

/obj/machinery/hydroponics/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if(air_group || (height==0)) return 1

	if(istype(mover) && mover.checkpass(PASSTABLE))
		return 1
	else
		return 0

/obj/machinery/hydroponics/process()

	var/needs_update = 0 // Checks if the icon needs updating so we don't redraw empty trays every time

	if(myseed && (myseed.loc != src))
		myseed.loc = src

	if(world.time > (lastcycle + cycledelay))
		lastcycle = world.time
		if(planted && !dead)
			// Advance age
			age++
			needs_update = 1

//Nutrients//////////////////////////////////////////////////////////////
			// Nutrients deplete slowly
			if(prob(50))
				adjustNutri(-1 / rating)

			// Lack of nutrients hurts non-weeds
			if(nutrilevel <= 0 && myseed.plant_type != 1)
				adjustHealth(-rand(1,3))

//Water//////////////////////////////////////////////////////////////////
			// Drink random amount of water
			adjustWater(-rand(1,6) / rating)

			// If the plant is dry, it loses health pretty fast, unless mushroom
			if(waterlevel <= 10 && myseed.plant_type != 2)
				adjustHealth(-rand(0,1) / rating)
				if(waterlevel <= 0)
					adjustHealth(-rand(0,2) / rating)

			// Sufficient water level and nutrient level = plant healthy
			else if(waterlevel > 10 && nutrilevel > 0)
				adjustHealth(rand(1,2) / rating)
				if(prob(5))  //5 percent chance the weed population will increase
					adjustWeeds(1 / rating)

//Toxins/////////////////////////////////////////////////////////////////

			// Too much toxins cause harm, but when the plant drinks the contaiminated water, the toxins disappear slowly
			if(toxic >= 40 && toxic < 80)
				adjustHealth(-1 / rating)
				adjustToxic(-rand(1,10) / rating)
			else if(toxic >= 80) // I don't think it ever gets here tbh unless above is commented out
				adjustHealth(-3)
				adjustToxic(-rand(1,10) / rating)

//Pests & Weeds//////////////////////////////////////////////////////////

			else if(pestlevel >= 5)
				adjustHealth(-1 / rating)

			// If it's a weed, it doesn't stunt the growth
			if(weedlevel >= 5 && myseed.plant_type != 1 )
				adjustHealth(-1 / rating)


//Health & Age///////////////////////////////////////////////////////////

			// Plant dies if health <= 0
			if(health <= 0)
				plantdies()
				adjustWeeds(1 / rating) // Weeds flourish

			// If the plant is too old, lose health fast
			if(age > myseed.lifespan)
				adjustHealth(-rand(1,5) / rating)

			// Harvest code
			if(age > myseed.production && (age - lastproduce) > myseed.production && (!harvest && !dead))
				nutrimentMutation()
				if(myseed && myseed.yield != -1) // Unharvestable shouldn't be harvested
					harvest = 1
				else
					lastproduce = age
			if(prob(5))  // On each tick, there's a 5 percent chance the pest population will increase
				adjustPests(1 / rating)
		else
			if(waterlevel > 10 && nutrilevel > 0 && prob(10))  // If there's no plant, the percentage chance is 10%
				adjustWeeds(1 / rating)

		// Weeeeeeeeeeeeeeedddssss

		if (weedlevel >= 10 && prob(50)) // At this point the plant is kind of fucked. Weeds can overtake the plant spot.
			if(planted)
				if(myseed.plant_type == 0) // If a normal plant
					weedinvasion()
			else
				weedinvasion() // Weed invasion into empty tray
			needs_update = 1
		if (needs_update)
			update_icon()
	return

/obj/machinery/hydroponics/proc/nutrimentMutation()
	if (mutmod == 0)
		return
	if (mutmod == 1)
		if(prob(80))		//80%
			mutate()
		else if(prob(75))	//15%
			hardmutate()
		return
	if (mutmod == 2)
		if(prob(50))		//50%
			mutate()
		else if(prob(50))	//25%
			hardmutate()
		else if(prob(50))	//12.5%
			mutatespecie()
		return
	return

obj/machinery/hydroponics/update_icon()
	//Refreshes the icon and sets the luminosity
	overlays.Cut()

	UpdateDescription()

	if(planted)
		var/image/I
		if(dead)
			I = image('icons/obj/hydroponics/growing.dmi', icon_state = "[myseed.species]-dead")
		else if(harvest)
			if(myseed.plant_type == 2) // Shrooms don't have a -harvest graphic
				I = image('icons/obj/hydroponics/growing.dmi', icon_state = "[myseed.species]-grow[myseed.growthstages]")
			else
				I = image('icons/obj/hydroponics/growing.dmi', icon_state = "[myseed.species]-harvest")
		else if(age < myseed.maturation)
			var/t_growthstate = ((age / myseed.maturation) * myseed.growthstages ) // Make sure it won't crap out due to HERPDERP 6 stages only
			I = image('icons/obj/hydroponics/growing.dmi', icon_state = "[myseed.species]-grow[round(t_growthstate)]")
			lastproduce = age //Cheating by putting this here, it means that it isn't instantly ready to harvest
		else
			I = image('icons/obj/hydroponics/growing.dmi', icon_state = "[myseed.species]-grow[myseed.growthstages]") // Same
		I.layer = MOB_LAYER + 0.1
		overlays += I

		if(waterlevel <= 10)
			overlays += image('icons/obj/hydroponics/equipment.dmi', icon_state = "over_lowwater3")
		if(nutrilevel <= 2)
			overlays += image('icons/obj/hydroponics/equipment.dmi', icon_state = "over_lownutri3")
		if(health <= (myseed.endurance / 2))
			overlays += image('icons/obj/hydroponics/equipment.dmi', icon_state = "over_lowhealth3")
		if(weedlevel >= 5 || pestlevel >= 5 || toxic >= 40)
			overlays += image('icons/obj/hydroponics/equipment.dmi', icon_state = "over_alert3")
		if(harvest)
			overlays += image('icons/obj/hydroponics/equipment.dmi', icon_state = "over_harvest3")

	if(istype(myseed,/obj/item/seeds/glowshroom))
		set_light(round(myseed.potency/10))
	else
		set_light(0)

	return

obj/machinery/hydroponics/proc/UpdateDescription()
	desc = null
	if (planted)
		desc = "[src] has <span class='info'>[myseed.plantname]</span> planted."
		if (dead)
			desc += " It's dead."
		else if (harvest)
			desc += " It's ready to harvest."

obj/machinery/hydroponics/proc/weedinvasion() // If a weed growth is sufficient, this happens.
	dead = 0
	var/oldPlantName
	if(myseed) // In case there's nothing in the tray beforehand
		oldPlantName = myseed.plantname
		qdel(myseed)
	else
		oldPlantName = "Empty tray"
	switch(rand(1,18))		// randomly pick predominative weed
		if(16 to 18)
			myseed = new /obj/item/seeds/reishimycelium
		if(14 to 15)
			myseed = new /obj/item/seeds/nettleseed
		if(12 to 13)
			myseed = new /obj/item/seeds/harebell
		if(10 to 11)
			myseed = new /obj/item/seeds/amanitamycelium
		if(8 to 9)
			myseed = new /obj/item/seeds/chantermycelium
		if(6 to 7)
			myseed = new /obj/item/seeds/towermycelium
		if(4 to 5)
			myseed = new /obj/item/seeds/plumpmycelium
		else
			myseed = new /obj/item/seeds/weeds
	planted = 1
	age = 0
	health = myseed.endurance
	lastcycle = world.time
	harvest = 0
	weedlevel = 0 // Reset
	pestlevel = 0 // Reset
	update_icon()
	visible_message("<span class='info'>[oldPlantName] overtaken by [myseed.plantname].</span>")
	return


/obj/machinery/hydroponics/proc/mutate(lifemut = 2, endmut = 5, productmut = 1, yieldmut = 2, potmut = 25) // Mutates the current seed
	if(!planted)
		return
	adjustSLife(rand(-lifemut,lifemut))
	adjustSEnd(rand(-endmut,endmut))
	adjustSProduct(rand(-productmut,productmut))
	adjustSYield(rand(-yieldmut,yieldmut))
	adjustSPot(rand(-potmut,potmut))
	return


obj/machinery/hydroponics/proc/hardmutate() // Strongly mutates the current seed.
	mutate(4, 10, 2, 4, 50)

obj/machinery/hydroponics/proc/mutatespecie() // Mutagent produced a new plant!
	if(!planted || dead)
		return

	var/oldPlantName = myseed.plantname
	if(myseed.mutatelist.len > 0)
		var/mutantseed = pick(myseed.mutatelist)
		qdel(myseed)
		myseed = new mutantseed
	else
		return

	dead = 0
	hardmutate()
	planted = 1
	age = 0
	health = myseed.endurance
	lastcycle = world.time
	harvest = 0
	weedlevel = 0 // Reset

	spawn(5) // Wait a while
	update_icon()
	visible_message("<span class='warning'>[oldPlantName] suddenly mutated into [myseed.plantname]!</span>")


obj/machinery/hydroponics/proc/mutateweed() // If the weeds gets the mutagent instead. Mind you, this pretty much destroys the old plant
	if ( weedlevel > 5 )
		if(myseed)
			qdel(myseed)
		var/newWeed = pick(/obj/item/seeds/libertymycelium, /obj/item/seeds/angelmycelium, /obj/item/seeds/deathnettleseed, /obj/item/seeds/kudzuseed)
		myseed = new newWeed
		dead = 0
		hardmutate()
		planted = 1
		age = 0
		health = myseed.endurance
		lastcycle = world.time
		harvest = 0
		weedlevel = 0 // Reset

		spawn(5) // Wait a while
		update_icon()
		visible_message("<span class='warning'>The mutated weeds in [src] spawned a [myseed.plantname]!</span>")
	else
		usr << "The few weeds in the [src] seem to react, but only for a moment..."
	return


/obj/machinery/hydroponics/proc/plantdies() // OH NOES!!!!! I put this all in one function to make things easier
	health = 0
	harvest = 0
	pestlevel = 0 // Pests die
	if(!dead)
		update_icon()
		dead = 1


/obj/machinery/hydroponics/proc/mutatepest()
	if(pestlevel > 5)
		visible_message("The pests seem to behave oddly...")
		for(var/i=0, i<3, i++)
			new /obj/effect/spider/spiderling(loc)
			//S.grow_as = /mob/living/simple_animal/hostile/giant_spider/hunter
	else
		usr << "The pests seem to behave oddly, but quickly settle down..."


obj/machinery/hydroponics/attackby(var/obj/item/O as obj, var/mob/user as mob)

	//Called when mob user "attacks" it with object O
	if(istype(O, /obj/item/nutrient))
		var/obj/item/nutrient/myNut = O
		user.remove_from_mob(O)
		nutrilevel = 10
		yieldmod = myNut.yieldmod
		mutmod = myNut.mutmod
		user << "You replace the nutrient solution in [src]."
		qdel(O)
		update_icon()

	else if(istype(O, /obj/item/weapon/reagent_containers) )  // Syringe stuff (and other reagent containers now too)
		var/obj/item/weapon/reagent_containers/reagent_source = O
		var/datum/reagents/S = new /datum/reagents()

		S.my_atom = src

		var/obj/target = myseed ? myseed.plantname : src

		if(istype(reagent_source, /obj/item/weapon/reagent_containers/syringe))
			var/obj/item/weapon/reagent_containers/syringe/syr = reagent_source
			if(syr.mode != 1)
				user << "You can't get any extract out of this plant."
				return
		if(!reagent_source.reagents.total_volume)
			user << "<span class='notice'>[reagent_source] is empty.</span>"
			return 1

		if(istype(reagent_source, /obj/item/weapon/reagent_containers/food/snacks) || istype(reagent_source, /obj/item/weapon/reagent_containers/pill))
			visible_message("<span class='notice'>[user] composts [reagent_source], spreading it through [target].</span>")
			reagent_source.reagents.trans_to(S,reagent_source.reagents.total_volume)
			qdel(reagent_source)
		else
			reagent_source.reagents.trans_to(S,reagent_source.amount_per_transfer_from_this)
			if(istype(reagent_source, /obj/item/weapon/reagent_containers/syringe/))
				var/obj/item/weapon/reagent_containers/syringe/syr = reagent_source
				visible_message("<span class='notice'>[user] injects [target] with [syr].</span>")
				if(syr.reagents.total_volume <= 0)
					syr.mode = 0
					syr.update_icon()
			else if(istype(reagent_source, /obj/item/weapon/reagent_containers/spray/))
				visible_message("<span class='notice'>[user] sprays [target] with [reagent_source].</span>")
				playsound(loc, 'sound/effects/spray3.ogg', 50, 1, -6)
			else if(reagent_source.amount_per_transfer_from_this) // Droppers, cans, beakers, what have you.
				visible_message("<span class='notice'>[user] uses [reagent_source] on [target].</span>")

			// Beakers, bottles, buckets, etc.  Can't use is_open_container though.
			if(istype(reagent_source, /obj/item/weapon/reagent_containers/glass/))
				playsound(loc, 'sound/effects/slosh.ogg', 25, 1)

		// There needs to be a good amount of mutagen to actually work
		if(S.has_reagent("mutagen", 5))
			switch(rand(100))
				if(91  to 100)	plantdies()
				if(81  to 90)  mutatespecie()
				if(66	to 80)	hardmutate()
				if(41  to 65)  mutate()
				if(21  to 41)  user << "The plants don't seem to react..."
				if(11	to 20)  mutateweed()
				if(1   to 10)  mutatepest()
				else 			user << "Nothing happens..."

		// Antitoxin binds shit pretty well. So the tox goes significantly down
		if(S.has_reagent("anti_toxin", 1))
			adjustToxic(-round(S.get_reagent_amount("anti_toxin")*2))

		// NIGGA, YOU JUST WENT ON FULL RETARD.
		if(S.has_reagent("toxin", 1))
			adjustToxic(round(S.get_reagent_amount("toxin")*2))

		// Milk is good for humans, but bad for plants. The sugars canot be used by plants, and the milk fat fucks up growth. Not shrooms though. I can't deal with this now...
		if(S.has_reagent("milk", 1))
			adjustNutri(round(S.get_reagent_amount("milk")*0.1))
			adjustWater(round(S.get_reagent_amount("milk")*0.9))

		// Beer is a chemical composition of alcohol and various other things. It's a shitty nutrient but hey, it's still one. Also alcohol is bad, mmmkay?
		if(S.has_reagent("beer", 1))
			adjustHealth(-round(S.get_reagent_amount("beer")*0.05))
			adjustNutri(round(S.get_reagent_amount("beer")*0.25))
			adjustWater(round(S.get_reagent_amount("beer")*0.7))

		// You're an idiot for thinking that one of the most corrosive and deadly gasses would be beneficial
		if(S.has_reagent("fluorine", 1))
			adjustHealth(-round(S.get_reagent_amount("fluorine")*2))
			adjustToxic(round(S.get_reagent_amount("flourine")*2.5))
			adjustWater(-round(S.get_reagent_amount("flourine")*0.5))
			adjustWeeds(-rand(1,4))

		// You're an idiot for thinking that one of the most corrosive and deadly gasses would be beneficial
		if(S.has_reagent("chlorine", 1))
			adjustHealth(-round(S.get_reagent_amount("chlorine")*1))
			adjustToxic(round(S.get_reagent_amount("chlorine")*1.5))
			adjustWater(-round(S.get_reagent_amount("chlorine")*0.5))
			adjustWeeds(-rand(1,3))

		// White Phosphorous + water -> phosphoric acid. That's not a good thing really. Phosphoric salts are beneficial though. And even if the plant suffers, in the long run the tray gets some nutrients. The benefit isn't worth that much.
		if(S.has_reagent("phosphorus", 1))
			adjustHealth(-round(S.get_reagent_amount("phosphorus")*0.75))
			adjustNutri(round(S.get_reagent_amount("phosphorus")*0.1))
			adjustWater(-round(S.get_reagent_amount("phosphorus")*0.5))
			adjustWeeds(-rand(1,2))

		// Plants should not have sugar, they can't use it and it prevents them getting water/ nutients, it is good for mold though...
		if(S.has_reagent("sugar", 1))
			adjustWeeds(rand(1,2))
			adjustPests(rand(1,2))
			adjustNutri(round(S.get_reagent_amount("sugar")*0.1))

		// It is water!
		if(S.has_reagent("water", 1))
			adjustWater(round(S.get_reagent_amount("water")*1))

		// Holy water. Mostly the same as water, it also heals the plant a little with the power of the spirits~
		if(S.has_reagent("holywater", 1))
			adjustWater(round(S.get_reagent_amount("holywater")*1))
			adjustHealth(round(S.get_reagent_amount("holywater")*0.1))

		// A variety of nutrients are dissolved in club soda, without sugar. These nutrients include carbon, oxygen, hydrogen, phosphorous, potassium, sulfur and sodium, all of which are needed for healthy plant growth.
		if(S.has_reagent("sodawater", 1))
			adjustWater(round(S.get_reagent_amount("sodawater")*1))
			adjustHealth(round(S.get_reagent_amount("sodawater")*0.1))
			adjustNutri(round(S.get_reagent_amount("sodawater")*0.1))

		// Man, you guys are retards
		if(S.has_reagent("sacid", 1))
			adjustHealth(-round(S.get_reagent_amount("sacid")*1))
			adjustToxic(round(S.get_reagent_amount("sacid")*1.5))
			adjustWeeds(-rand(1,2))

		// SERIOUSLY
		if(S.has_reagent("pacid", 1))
			adjustHealth(-round(S.get_reagent_amount("pacid")*2))
			adjustToxic(round(S.get_reagent_amount("pacid")*3))
			adjustWeeds(-rand(1,4))

		// Plant-B-Gone is just as bad
		if(S.has_reagent("plantbgone", 1))
			adjustHealth(-round(S.get_reagent_amount("plantbgone")*2))
			adjustToxic(-round(S.get_reagent_amount("plantbgone")*3))
			adjustWeeds(-rand(4,8))

		// Healing
		if(S.has_reagent("cryoxadone", 1))
			adjustHealth(round(S.get_reagent_amount("cryoxadone")*3))
			adjustToxic(-round(S.get_reagent_amount("cryoxadone")*3))

		// Ammonia is bad ass.
		if(S.has_reagent("ammonia", 1))
			adjustHealth(round(S.get_reagent_amount("ammonia")*0.5))
			adjustNutri(round(S.get_reagent_amount("ammonia")*1))

		// This is more bad ass, and pests get hurt by the corrosive nature of it, not the plant.
		if(S.has_reagent("diethylamine", 1))
			adjustHealth(round(S.get_reagent_amount("diethylamine")*1))
			adjustNutri(round(S.get_reagent_amount("diethylamine")*2))
			adjustPests(-rand(1,2))

		// Compost, effectively
		if(S.has_reagent("nutriment", 1))
			adjustHealth(round(S.get_reagent_amount("nutriment")*0.5))
			adjustNutri(round(S.get_reagent_amount("nutriment")*1))

		// Poor man's mutagen.
		if(S.has_reagent("radium", 1))
			adjustHealth(-round(S.get_reagent_amount("radium")*1.5))
			adjustToxic(round(S.get_reagent_amount("radium")*2))
		if(S.has_reagent("radium", 10))
			switch(rand(100))
				if(91  to 100)	plantdies()
				if(81  to 90)  mutatespecie()
				if(66	to 80)	hardmutate()
				if(41  to 65)  mutate()
				if(21  to 41)  user << "The plants don't seem to react..."
				if(11	to 20)  mutateweed()
				if(1   to 10)  mutatepest()
				else 			user << "Nothing happens..."

		// The best stuff there is. For testing/debugging.
		if(S.has_reagent("adminordrazine", 1))
			adjustWater(round(S.get_reagent_amount("adminordrazine")*1))
			adjustHealth(round(S.get_reagent_amount("adminordrazine")*1))
			adjustNutri(round(S.get_reagent_amount("adminordrazine")*1))
			adjustPests(-rand(1,5))
			adjustWeeds(-rand(1,5))
		if(S.has_reagent("adminordrazine", 5))
			switch(rand(100))
				if(66  to 100)  mutatespecie()
				if(33	to 65)  mutateweed()
				if(1   to 32)  mutatepest()
				else 			user << "Nothing happens..."

		S.clear_reagents()
		qdel(S)
		update_icon()
		return 1

	else if ( istype(O, /obj/item/seeds/) )
		if(!planted)
			user.remove_from_mob(O)
			user << "You plant the [O.name]"
			dead = 0
			myseed = O
			planted = 1
			age = 1
			health = myseed.endurance
			lastcycle = world.time
			O.loc = src
			if((user.client  && user.s_active != src))
				user.client.screen -= O
			O.dropped(user)
			update_icon()

		else
			user << "<span class='warning'>[src] already has seeds in it!</span>"

	else if (istype(O, /obj/item/device/analyzer/plant_analyzer))
		if(planted && myseed)
			user << "*** <B>[myseed.plantname]</B> ***" //Carn: now reports the plants growing, not the seeds.
			user << "-Plant Age: \blue [age]"
			user << "-Plant Endurance: \blue [myseed.endurance]"
			user << "-Plant Lifespan: \blue [myseed.lifespan]"
			if(myseed.yield != -1)
				user << "-Plant Yield: \blue [myseed.yield]"
			user << "-Plant Production: \blue [myseed.production]"
			if(myseed.potency != -1)
				user << "-Plant Potency: \blue [myseed.potency]"
			user << "-Weed level: \blue [weedlevel]/10"
			user << "-Pest level: \blue [pestlevel]/10"
			user << "-Toxicity level: \blue [toxic]/100"
			user << "-Water level: <span class='notice'> [waterlevel]/[maxwater]</span>"
			user << "-Nutrition level: <span class='notice'> [nutrilevel]/[maxnutri]</span>"
			user << ""
		else
			user << "<B>No plant found.</B>"
			user << "-Weed level: \blue [weedlevel]/10"
			user << "-Pest level: \blue [pestlevel]/10"
			user << "-Toxicity level: \blue [toxic]/100"
			user << "-Water level: <span class='notice'> [waterlevel]/[maxwater]</span>"
			user << "-Nutrition level: <span class='notice'> [nutrilevel]/[maxnutri]</span>"
			user << ""

	else if (istype(O, /obj/item/weapon/minihoe))
		if(weedlevel > 0)
			user.visible_message("<span class='notice'>[user] uproots the weeds.</span>", "<span class='notice'>You remove the weeds from [src].</span>")
			weedlevel = 0
			update_icon()
		else
			user << "<span class='notice'>This plot is completely devoid of weeds. It doesn't need uprooting.</span>"

	else if ( istype(O, /obj/item/weapon/weedspray) )
		var/obj/item/weedkiller/myWKiller = O
		user.remove_from_mob(O)
		adjustToxic(myWKiller.toxicity)
		adjustWeeds(-myWKiller.WeedKillStr)
		user << "You apply the weedkiller solution into [src]."
		playsound(loc, 'sound/effects/spray3.ogg', 50, 1, -6)
		qdel(O)
		update_icon()

	else if (istype(O, /obj/item/weapon/storage/bag/plants))
		attack_hand(user)
		var/obj/item/weapon/storage/bag/plants/S = O
		for (var/obj/item/weapon/reagent_containers/food/snacks/grown/G in locate(user.x,user.y,user.z))
			if(!S.can_be_inserted(G))
				return
			S.handle_item_insertion(G, 1)
			score["stuffharvested"]++

	else if(istype(O, /obj/item/weapon/wrench) && unwrenchable)
		if(anchored==2)
			user << "Unscrew the hoses first!"
			return

		if(!anchored && !isinspace())
			playsound(loc, 'sound/items/Ratchet.ogg', 50, 1)
			anchored = 1
			user << "You wrench [src] in place."
		else if(anchored)
			playsound(loc, 'sound/items/Ratchet.ogg', 50, 1)
			anchored = 0
			user << "You unwrench [src]."

	else if(istype(O, /obj/item/weapon/wirecutters) && unwrenchable)

		if(anchored)
			if(anchored==2)
				playsound(src.loc, 'sound/items/Wirecutter.ogg', 50, 1)
				anchored = 1
				user << "<span class='notice'>You snip \the [src]'s hoses.</span>"

			else if(anchored==1)
				playsound(src.loc, 'sound/items/Wirecutter.ogg', 50, 1)
				anchored = 2
				user << "<span class='notice'>You reconnect \the [src]'s hoses.</span>"

			for(var/obj/machinery/hydroponics/h in range(1,src))
				spawn()
					h.update_icon()

	else if ( istype(O, /obj/item/weapon/pestspray) )
		var/obj/item/pestkiller/myPKiller = O
		user.remove_from_mob(O)
		adjustToxic(myPKiller.toxicity)
		adjustPests(-myPKiller.PestKillStr)
		user << "You apply the pestkiller solution into [src]."
		playsound(loc, 'sound/effects/spray3.ogg', 50, 1, -6)
		qdel(O)
		update_icon()
	else if(istype(O, /obj/item/apiary))
		if(planted)
			user << "\red The hydroponics tray is already occupied!"
		else
			user.remove_from_mob()
			qdel(O)

			var/obj/machinery/apiary/A = new(src.loc)
			A.icon = src.icon
			A.icon_state = src.icon_state
			A.hydrotray_type = src.type
			qdel(src)
	return

/obj/machinery/hydroponics/attack_tk(mob/user as mob)
	if(harvest)
		myseed.harvest(src)
	else if(dead)
		planted = 0
		dead = 0
		usr << text("You remove the dead plant from the [src].")
		qdel(myseed)
		update_icon()

/obj/machinery/hydroponics/attack_hand(mob/user as mob)
	if(istype(usr,/mob/living/silicon))		//How does AI know what plant is?
		return
	if(harvest)
		if(!user in range(1,src))
			return
		myseed.harvest()
	else if(dead)
		planted = 0
		dead = 0
		user << "<span class='notice'>You remove the dead plant from [src].</span>"
		qdel(myseed)
		update_icon()
	else
		if(planted && !dead)
			user << "[src] has <span class='info'>[myseed.plantname]</span> planted."
			if(health <= (myseed.endurance / 2))
				user << "The plant looks unhealthy."
		else
			user << "[src] is empty."
		user << "Water: [waterlevel]/[maxwater]"
		user << "Nutrient: [nutrilevel]/[maxnutri]"
		if(weedlevel >= 5) // Visual aid for those blind
			user << "[src] is filled with weeds!"
		if(pestlevel >= 5) // Visual aid for those blind
			user << "[src] is filled with tiny worms!"
		user << "" // Empty line for readability.

/obj/item/seeds/proc/getYield()
	var/obj/machinery/hydroponics/parent = loc
	if (parent.yieldmod == 0)
		return min(yield, 1)//1 if above zero, 0 otherwise
	return (yield * parent.yieldmod)

/obj/item/seeds/proc/harvest(mob/user = usr)
	var/produce = text2path(productname)
	var/obj/machinery/hydroponics/parent = loc //for ease of access
	var/t_amount = 0
	var/list/result = list()
	var/output_loc = parent.Adjacent(user) ? user.loc : parent.loc //needed for TK
	var/product_name
	while(t_amount < getYield())
		var/obj/item/weapon/reagent_containers/food/snacks/grown/t_prod = new produce(output_loc, potency)
		result.Add(t_prod) // User gets a consumable
		if(!t_prod)
			return
		t_prod.lifespan = lifespan
		t_prod.endurance = endurance
		t_prod.maturation = maturation
		t_prod.production = production
		t_prod.yield = yield
		t_prod.potency = potency
		t_prod.plant_type = plant_type
		t_amount++
		product_name = t_prod.name
	if(getYield() >= 1)
		feedback_add_details("food_harvested","[product_name]|[getYield()]")
		score["stuffharvested"]++

	parent.update_tray()
	return result

/obj/item/seeds/grassseed/harvest(mob/user = usr)
	var/obj/machinery/hydroponics/parent = loc //for ease of access
	var/t_yield = round(yield*parent.yieldmod)

	if(t_yield > 0)
		var/obj/item/stack/tile/grass/new_grass = new/obj/item/stack/tile/grass(user.loc)
		new_grass.amount = t_yield

	parent.update_tray()

/obj/item/seeds/gibtomato/harvest(mob/user = usr)
	var/produce = text2path(productname)
	var/obj/machinery/hydroponics/parent = loc //for ease of access
	var/t_amount = 0

	while ( t_amount < (yield * parent.yieldmod ))
		var/obj/item/weapon/reagent_containers/food/snacks/grown/t_prod = new produce(user.loc, potency) // User gets a consumable

		t_prod.seed = mypath
		t_prod.species = species
		t_prod.lifespan = lifespan
		t_prod.endurance = endurance
		t_prod.maturation = maturation
		t_prod.production = production
		t_prod.yield = yield
		t_prod.potency = potency
		t_prod.plant_type = plant_type
		t_amount++

	parent.update_tray()

/obj/item/seeds/nettleseed/harvest(mob/user = usr)
	var/produce = text2path(productname)
	var/obj/machinery/hydroponics/parent = loc //for ease of access
	var/t_amount = 0

	while ( t_amount < (yield * parent.yieldmod ))
		var/obj/item/weapon/grown/t_prod = new produce(user.loc, potency) // User gets a consumable -QualityVan
		t_prod.seed = mypath
		t_prod.species = species
		t_prod.lifespan = lifespan
		t_prod.endurance = endurance
		t_prod.maturation = maturation
		t_prod.production = production
		t_prod.yield = yield
		t_prod.changePotency(potency) // -QualityVan
		t_prod.plant_type = plant_type
		t_amount++

	parent.update_tray()

/obj/item/seeds/deathnettleseed/harvest(mob/user = usr) //isn't a nettle subclass yet, so
	var/produce = text2path(productname)
	var/obj/machinery/hydroponics/parent = loc //for ease of access
	var/t_amount = 0

	while ( t_amount < (yield * parent.yieldmod ))
		var/obj/item/weapon/grown/t_prod = new produce(user.loc, potency) // User gets a consumable -QualityVan
		t_prod.seed = mypath
		t_prod.species = species
		t_prod.lifespan = lifespan
		t_prod.endurance = endurance
		t_prod.maturation = maturation
		t_prod.production = production
		t_prod.yield = yield
		t_prod.changePotency(potency) // -QualityVan
		t_prod.plant_type = plant_type
		t_amount++

	parent.update_tray()

/obj/item/seeds/eggyseed/harvest(mob/user = usr)
	var/produce = text2path(productname)
	var/obj/machinery/hydroponics/parent = loc //for ease of access
	var/t_amount = 0

	while ( t_amount < (yield * parent.yieldmod ))
		new produce(user.loc)
		t_amount++

	parent.update_tray()

/obj/machinery/hydroponics/proc/update_tray(mob/user = usr)
	harvest = 0
	lastproduce = age
	if(istype(myseed,/obj/item/seeds/replicapod/))
		user << "<span class='notice'>You harvest from the [myseed.plantname].</span>"
	else if(myseed.getYield() <= 0)
		user << "<span class='warning'>You fail to harvest anything useful!</span>"
	else
		user << "<span class='notice'>You harvest [myseed.getYield()] items from the [myseed.plantname].</span>"
	if(myseed.oneharvest)
		qdel(myseed)
		planted = 0
		dead = 0
	update_icon()

/// Tray Setters - The following procs adjust the tray or plants variables, and make sure that the stat doesn't go out of bounds.///
/obj/machinery/hydroponics/proc/adjustNutri(adjustamt)
	nutrilevel += adjustamt
	nutrilevel = max(nutrilevel, 0)
	nutrilevel = min(nutrilevel, maxnutri)

/obj/machinery/hydroponics/proc/adjustWater(adjustamt)
	waterlevel += adjustamt
	waterlevel = max(waterlevel, 0)
	waterlevel = min(waterlevel, maxwater)
	if(adjustamt>0)
		adjustToxic(-round(adjustamt/4))//Toxicity dilutation code. The more water you put in, the lesser the toxin concentration.

/obj/machinery/hydroponics/proc/adjustHealth(adjustamt)
	if(planted && !dead)
		health += adjustamt
		health = max(health, 0)
		health = min(health, myseed.endurance)

/obj/machinery/hydroponics/proc/adjustToxic(adjustamt)
	toxic += adjustamt
	toxic = max(toxic, 0)
	toxic = min(toxic, 100)

/obj/machinery/hydroponics/proc/adjustPests(var/adjustamt)
	pestlevel += adjustamt
	pestlevel = max(pestlevel, 0)
	pestlevel = min(pestlevel, 10)

/obj/machinery/hydroponics/proc/adjustWeeds(var/adjustamt)
	weedlevel += adjustamt
	weedlevel = max(weedlevel, 0)
	pestlevel = min(pestlevel, 10)

/// Seed Setters ///
/obj/machinery/hydroponics/proc/adjustSYield(var/adjustamt)//0,10
	if(myseed.yield != -1) // Unharvestable shouldn't suddenly turn harvestable
		myseed.yield += adjustamt
		myseed.yield = max(myseed.yield, 0)
		myseed.yield = min(myseed.yield, 10)
		if(myseed.yield <= 0 && myseed.plant_type == 2)
			myseed.yield = 1 // Mushrooms always have a minimum yield of 1.

/obj/machinery/hydroponics/proc/adjustSLife(var/adjustamt)//10,100
	myseed.lifespan += adjustamt
	myseed.lifespan = max(myseed.lifespan, 10)
	myseed.lifespan = min(myseed.lifespan, 100)

/obj/machinery/hydroponics/proc/adjustSEnd(var/adjustamt)//10,100
	myseed.endurance += adjustamt
	myseed.endurance = max(myseed.endurance, 10)
	myseed.endurance = min(myseed.endurance, 100)

/obj/machinery/hydroponics/proc/adjustSProduct(var/adjustamt)//2,10
	myseed.production += adjustamt
	myseed.production = max(myseed.endurance, 2)
	myseed.production = min(myseed.endurance, 10)

/obj/machinery/hydroponics/proc/adjustSPot(var/adjustamt)//0,100
	if(myseed.potency != -1) //Not all plants have a potency
		myseed.potency += adjustamt
		myseed.potency = max(myseed.potency, 0)
		myseed.potency = min(myseed.potency, 100)

///////////////////////////////////////////////////////////////////////////////
/obj/machinery/hydroponics/soil //Not actually hydroponics at all! Honk!
	name = "soil"
	icon = 'icons/obj/hydroponics.dmi'
	icon_state = "soil"
	density = 0
	use_power = 0
	unwrenchable = 0

/obj/machinery/hydroponics/soil/update_icon() // Same as normal but with the overlays removed - Cheridan.
	overlays.Cut()

	UpdateDescription()

	if(planted)
		if(dead)
			overlays += image('icons/obj/hydroponics.dmi', icon_state="[myseed.species]-dead")
		else if(harvest)
			if(myseed.plant_type == 2) // Shrooms don't have a -harvest graphic
				overlays += image('icons/obj/hydroponics.dmi', icon_state="[myseed.species]-grow[myseed.growthstages]")
			else
				overlays += image('icons/obj/hydroponics.dmi', icon_state="[myseed.species]-harvest")
		else if(age < myseed.maturation)
			var/t_growthstate = ((age / myseed.maturation) * myseed.growthstages )
			overlays += image('icons/obj/hydroponics.dmi', icon_state="[myseed.species]-grow[round(t_growthstate)]")
			lastproduce = age
		else
			overlays += image('icons/obj/hydroponics.dmi', icon_state="[myseed.species]-grow[myseed.growthstages]")

	if(!luminosity)
		if(istype(myseed,/obj/item/seeds/glowshroom))
			set_light(round(myseed.potency/10))
	else
		set_light(0)
	return

/obj/machinery/hydroponics/soil/attackby(var/obj/item/O as obj, var/mob/user as mob)
	..()
	if(istype(O, /obj/item/weapon/shovel))
		user << "You clear up [src]!"
		qdel(src)

#undef HYDRO_RATING_MULTIPLIER
