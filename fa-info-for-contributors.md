# Info for Factorio Access Contributors

Hello and thank you for your interest in contributing to Factorio Access! Here is some general information about how Factorio mods work, and how this mod in particular works.

## Factorio data lifecycle

Factorio allows mods to run Lua code either during the startup of the game before the main menu loads, or during runtime after a save file loads.

The startup process includes the settings stage where mods are configured, and the prototype stage where mods define new [prototypes](https://lua-api.factorio.com/latest/prototypes.html) for game content such as sound effects, input keybinds, custom buildings, and more.

The runtime stage takes place alongside normal gameplay, and allows interaction with the game world. Code execution is based on [events](https://lua-api.factorio.com/latest/events.html) being fired for mods to react to, with the API functionality being provided via objects of various [classes](https://lua-api.factorio.com/latest/classes.html) that have been defined specifically for mods.

Like other mods, Factorio Access reacts to three types of events: listened in-game events such as an entity taking damage, player input events such as a key being pressed, and scheduled events such as a function scheduled to be called once per second. 

Factorio runs everything on a single main thread so that the game is deterministic, although it is highly optimized to parallelize independent tasks. The game runs with 60 game ticks per second and multiple events can be called on the same tick.

Read more about the data lifecycle on [this official documentation page](https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html).

## Data structures used in Factorio Access

During runtime, the API allows you to reference game objects directly, with read and/or write permissions for their listed properties. Game objects include the `surface`, which is the world made up of `tiles`, and covered in `entities`. Every entity has a `ùnit_number` that is unqiue to it, and a class `name` explaining what it is and what it can do. Usually doing something in the mod begins with referencing an entity or a tile.

When not referencing game objects, the mod has a global data table where persistent variables can be saved in custom tables. The access mod's most extensively used custom table is `global.players`, where mod-related data for each player is stored separately. This table is usually referenced using a variable named "pindex", which is the index number for a particular player.

Other aspects of the runtime can be referenced as well, such as the graphics rendering system, or the remote calls system for interfacing with other mods. Read more about the runtime stage on [the API page for runtime](https://lua-api.factorio.com/latest/index-runtime.html).

## Key mod files

### Standard files

The standard files for Factorio mods include the following:

* `settings.lua` is where mod settings are defined in an API-interfaced way. This file is not added yet for this mod but it will be.

* `settings-updates.lua` is where the settings of other mods are overwritten.
- `data.lua` is where vanilla prototypes are overwritten and mod prototypes are introduced, including sound files, keybinds, and new custom buildings.

- `data-updates.lua` is wheret the prototypes of other mods are overwritten.

- `control.lua` is where all runtime behavior is defined.

### Lua module files

Every other lua file in the Factorio Access folder is for the runtime stage and gets loaded by `control.lua`. The mod uses Lua modules to ogranize much of the runtime code, and so these lua files contain one or two modules each. A few files of interest are the following:

* `fa-utils.lua`contains utility functions that are used across the mod, including position and direction processing, string processing, and the like.

* `building-tools.lua`contains building related functions, including basic functions and advanced helper functions. It is worth noting that the mod does not (and can not?) use any of the built-in smart building features of the base game.

* `graphics-and-mouse.lua`contains mod functions related to drawing things in the world, or updating GUI's, or moving the mouse pointer on the screen. If there are issues related to these features, sighted developers can start debugging here. There are other places where the mod draws stuff but those tend to be simple graphics for debugging assistance.

* `localising.lua`contains the mod's own helper functions for fetching localized strings that can be concatinated, which cannot be done easily with the API alone.

### Config change files

The mod has a number of ".ini" files in the folder named `config_changes`. These files define which game settings are changed by the Factorio Access launcher during game configuration. There are multiple files for backwards compatibility between mod releases.

### Locale files

As noted previously, `localising.lua`contains the mod's own helper functions for fetching localized strings that can be concatinated, which cannot be done easily with the API alone.

The mod has some ".cfg" files in the `locale` folder, where localised strings are defined and stored. Only the English locale is properly available at the moment and we have not yet converted most of the mod from simple strings to localisable strings. Translators will be welcomed to create copies of these files for other languages when the structures of the files are more complete.

## Key mod functions

### API functions

* `on_init()` runs when the mod is loaded for the first time.

* `on_load()` runs when the mod is loaded after the first time.

* `on_tick()` is run on every tick and is used to schedule regularly called functions.

* `game.print(string)` prints a string to the game console for all players, but this is NOT vocalized.

### Mod custom functions

* `schedule(...)` can be called to schedule a particular function after a selected number of ticks.

* `ent_info(pindex, ent, description)` lists info about an entity after it is selected by the cursor.

* `printout(string,pindex)` prints a string to the launcher for the vocalizer to read.

## Mod menu system

Factorio allows every player to open at most one menu window at a time. Based on this, the current menu is tracked in the global variable named `players[pindex].menu`. The following menus have been defined:

* `inventory`: the character GUI sector where the main inventory is browsed.

* `crafting`: the character GUI sector where all available recipes for your force can be browsed.

* `crafting-queue`: the character GUI sector where ongoing crafting requests are listed, and can be canceled before they are completed.

* `player_trash`: the character GUI sector where the character's logistic trash inventory can be browsed after this feature is unlocked.

* `technology`: The technology tree menu, called from the character GUI for convenience.

* `building`: This term applies for the menu of any building that is opened. Has multiple sectors that you can switch between by pressing "TAB".

* `vehicle`: This term applies for the menu of any individual vehicle that is opened.Has multiple sectors that you can switch between by pressing "TAB".

* `building_no_sectors`: This term applies for the menu of any building that is opened but has no sectors.

* `travel`: The menu for the fast travel feature.

* `structure-travel`: The menu for the structure travel feature, also called the B Stride feature.

* `warnings`: The warnings list menu.

* `rail_builder`: The rail builder menu for automatically building rail structures.

* `belt`: The menu for the transport belt analyzer.
- `pump`: The menu for the offshore pump building assitant.
* `train_menu`: The menu for a train (but not its inidivdual vehicles).

* `spider_menu`: The menu for a spidertron.

* `train_stop_menu`: The menu for a train stop.

* `roboport_menu`: The menu for a roboport, also pertaining to its logistic network.

* `blueprint_menu`: The menu for a blueprint item.

* `blueprint_book_menu`: The menu for a blueprint book item (partially implemented).

* `circuit_network_menu`: The menu for a machine in a circuit network, also pertaining to its circuit network in general.

* `signal_selector`: The menu for browsing all available circuit network signals.

Note: The scanner tool does not have its own menu but its features can be used only when no menus are open.

## More resources

All kinds of info about Factorio Access can be found on its own wiki, [linked here](https://github.com/Factorio-Access/FactorioAccess/wiki). 

The Factorio Wiki has some modding tutorials [listed on this page](https://wiki.factorio.com/Tutorials#Modding_tutorials). In particular consider the [Modding Tutorial by Gangsir](https://wiki.factorio.com/Tutorial:Modding_tutorial/Gangsir).

If you would like discuss possible contributions, suggestions, or other topics about the mod, feel free to get in contact on our Discord server, [linked here](https://discord.gg/5EbxnhN5Zp).
