
/obj/item/device/integrated_circuit_printer
	name = "integrated circuit printer"
	desc = "A portable(ish) machine made to print tiny modular circuitry out of metal."
	icon = 'icons/obj/electronic_assemblies.dmi'
	icon_state = "circuit_printer"
	w_class = ITEMSIZE_LARGE
	var/metal = 0
	var/max_metal = 100
	var/metal_per_sheet = 10 // One sheet equals this much metal.

	var/upgraded = FALSE		// When hit with an upgrade disk, will turn true, allowing it to print the higher tier circuits.
	var/can_clone = FALSE		// Same for above, but will allow the printer to duplicate a specific assembly.
	var/static/list/recipe_list = list()
	var/current_category = null
	var/obj/item/device/electronic_assembly/assembly_to_clone = null
	var/static/list/ic_tool_list = list(
		/obj/item/device/integrated_electronics/wirer,
		/obj/item/device/integrated_electronics/debugger,
		/obj/item/weapon/card/data
	)

/obj/item/device/integrated_circuit_printer/upgraded
	upgraded = TRUE
	can_clone = TRUE

/obj/item/device/integrated_circuit_printer/initialize()
	. = ..()
	if(!recipe_list.len)
		// Unfortunately this needed a lot of loops, but it should only be run once at init.

		// First loop is to seperate the actual circuits from base circuits.
		var/list/circuits_to_use = list()
		for(var/obj/item/integrated_circuit/IC in all_integrated_circuits)
			if((IC.spawn_flags & IC_SPAWN_DEFAULT) || (IC.spawn_flags & IC_SPAWN_RESEARCH))
				circuits_to_use.Add(IC)

		// Second loop is to find all categories.
		var/list/found_categories = list()
		for(var/obj/item/integrated_circuit/IC in circuits_to_use)
			if(!(IC.category_text in found_categories))
				found_categories.Add(IC.category_text)

		// Third loop is to initialize lists by category names, then put circuits matching the category inside.
		for(var/category in found_categories)
			recipe_list[category] = list()
			var/list/current_list = recipe_list[category]
			for(var/obj/item/integrated_circuit/IC in circuits_to_use)
				if(IC.category_text == category)
					current_list.Add(IC)

		// Now for non-circuit things.
		var/list/assembly_list = list()
		assembly_list.Add(
			new /obj/item/device/electronic_assembly(null),
			new /obj/item/device/electronic_assembly/medium(null),
			new /obj/item/device/electronic_assembly/large(null),
			new /obj/item/device/electronic_assembly/drone(null),
			new /obj/item/weapon/implant/integrated_circuit(null),
			new /obj/item/device/assembly/electronic_assembly(null)
		)
		recipe_list["Assemblies"] = assembly_list

		var/list/tools_list = list()
		tools_list.Add(
			new /obj/item/device/integrated_electronics/wirer(null),
			new /obj/item/device/integrated_electronics/debugger(null)
		)
		recipe_list["Tools"] = tools_list


/obj/item/device/integrated_circuit_printer/attackby(var/obj/item/O, var/mob/user)
	if(istype(O,/obj/item/stack/material))
		var/obj/item/stack/material/stack = O
		if(stack.material.name == DEFAULT_WALL_MATERIAL)
			var/num = min((max_metal - metal) / metal_per_sheet, stack.amount)
			if(num < 1)
				to_chat(user, "<span class='warning'>\The [src] is too full to add more metal.</span>")
				return
			if(stack.use(num))
				to_chat(user, "<span class='notice'>You add [num] sheet\s to \the [src].</span>")
				metal += num * metal_per_sheet
				interact(user)
				return TRUE

	if(istype(O,/obj/item/integrated_circuit))
		to_chat(user, "<span class='notice'>You insert the circuit into \the [src]. </span>")
		user.unEquip(O)
		metal = min(metal + O.w_class, max_metal)
		qdel(O)
		interact(user)
		return TRUE

	if(istype(O,/obj/item/weapon/disk/integrated_circuit/upgrade/advanced))
		if(upgraded)
			to_chat(user, "<span class='warning'>\The [src] already has this upgrade. </span>")
			return TRUE
		to_chat(user, "<span class='notice'>You install \the [O] into  \the [src]. </span>")
		upgraded = TRUE
		interact(user)
		return TRUE

	if(istype(O,/obj/item/weapon/disk/integrated_circuit/upgrade/clone))
		if(can_clone)
			to_chat(user, "<span class='warning'>\The [src] already has this upgrade. </span>")
			return TRUE
		to_chat(user, "<span class='notice'>You install \the [O] into  \the [src]. </span>")
		can_clone = TRUE
		interact(user)
		return TRUE

	return ..()

/obj/item/device/integrated_circuit_printer/attack_self(var/mob/user)
	interact(user)

/obj/item/device/integrated_circuit_printer/interact(mob/user)
	var/window_height = 600
	var/window_width = 500

	if(isnull(current_category))
		current_category = recipe_list[1]

	var/HTML = "<center><h2>Integrated Circuit Printer</h2></center><br>"
	HTML += "Metal: [metal/metal_per_sheet]/[max_metal/metal_per_sheet] sheets.<br>"
	HTML += "Circuits available: [upgraded ? "Regular":"Advanced"]."
	HTML += "Assembly Cloning: [can_clone ? "Available": "Unavailable"]."
	if(assembly_to_clone)
		HTML += "Assembly '[assembly_to_clone.name]' loaded."
	HTML += "Crossed out circuits mean that the printer is not sufficentally upgraded to create that circuit.<br>"
	HTML += "<hr>"
	HTML += "Categories:"
	for(var/category in recipe_list)
		if(category != current_category)
			HTML += " <a href='?src=\ref[src];category=[category]'>\[[category]\]</a> "
		else // Bold the button if it's already selected.
			HTML += " <b>\[[category]\]</b> "
	HTML += "<hr>"
	HTML += "<center><h4>[current_category]</h4></center>"

	var/list/current_list = recipe_list[current_category]
	for(var/obj/O in current_list)
		var/can_build = TRUE
		if(istype(O, /obj/item/integrated_circuit))
			var/obj/item/integrated_circuit/IC = O
			if((IC.spawn_flags & IC_SPAWN_RESEARCH) && (!(IC.spawn_flags & IC_SPAWN_DEFAULT)) && !upgraded)
				can_build = FALSE
		if(can_build)
			HTML += "<A href='?src=\ref[src];build=[O.type]'>\[[O.name]\]</A>: [O.desc]<br>"
		else
			HTML += "<s>\[[O.name]\]: [O.desc]</s><br>"

	user << browse(jointext(HTML, null), "window=integrated_printer;size=[window_width]x[window_height];border=1;can_resize=1;can_close=1;can_minimize=1")

/obj/item/device/integrated_circuit_printer/Topic(href, href_list)
	if(..())
		return 1

	add_fingerprint(usr)

	if(href_list["category"])
		current_category = href_list["category"]

	if(href_list["build"])
		var/build_type = text2path(href_list["build"])
		if(!build_type || !ispath(build_type))
			return 1

		var/cost = 1
		if(ispath(build_type, /obj/item/device/electronic_assembly))
			var/obj/item/device/electronic_assembly/E = build_type
			cost = round( (initial(E.max_complexity) + initial(E.max_components) ) / 4)
		else if(ispath(build_type, /obj/item/integrated_circuit))
			var/obj/item/integrated_circuit/IC = build_type
			cost = initial(IC.w_class)
		else if(!(build_type in ic_tool_list))
			log_and_message_admins("[key_name(usr)] attempted to href exploit with the integrated electronics printer.")
			return

		if(metal - cost < 0)
			to_chat(usr, "<span class='warning'>You need [cost] metal to build that!.</span>")
			return 1
		metal -= cost
		new build_type(get_turf(loc))

	interact(usr)

// FUKKEN UPGRADE DISKS
/obj/item/weapon/disk/integrated_circuit/upgrade
	name = "integrated circuit printer upgrade disk"
	desc = "Install this into your integrated circuit printer to enhance it."
	icon = 'icons/obj/electronic_assemblies.dmi'
	icon_state = "upgrade_disk"
	item_state = "card-id"
	w_class = ITEMSIZE_SMALL
	origin_tech = list(TECH_ENGINEERING = 3, TECH_DATA = 4)

/obj/item/weapon/disk/integrated_circuit/upgrade/advanced
	name = "integrated circuit printer upgrade disk - advanced designs"
	desc = "Install this into your integrated circuit printer to enhance it.  This one adds new, advanced designs to the printer."

// To be implemented later.
/obj/item/weapon/disk/integrated_circuit/upgrade/clone
	name = "integrated circuit printer upgrade disk - circuit cloner"
	desc = "Install this into your integrated circuit printer to enhance it.  This one allows the printer to duplicate assemblies."
	icon_state = "upgrade_disk_clone"
	origin_tech = list(TECH_ENGINEERING = 5, TECH_DATA = 6)