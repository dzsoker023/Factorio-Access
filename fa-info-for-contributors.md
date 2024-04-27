# Info for Factorio Access Contributors

Hello and thank you for your interest in contributing to Factorio Access! Here is some general information about how Factorio mods work, and how this mod in particular works.

## Dev environment setup

Our normal way to receive your proposed code changes is via a GitHub pull request, but you can get in touch with us on Discord about alternatives. These instructions assume a default setup where you fork the mod's repository and use Visual Studio Code. Lots of setup variations are possible though, so take these instructions with a grain of salt, and ask for help with deviations, if needed.

1. Create a fork on github, which gives you your own copy of the repository.
2. Replace the FactorioAccess mod folder in "`%appdata%\Factorio\mods\`" with a clone of your fork, so that your changes can be tested in game right away.
3. Ensure you have a somewhat up to date version of VS Code installed.
4. Open a new VS Code window, and from there open that newly created FactorioAccess folder.
5. VS Code may or may not prompt you to install some extentions, in either case install the recommended extensions. You can find recommended extensions in the "`Extensions`" tab, under the "`Recommended`" section. We generally recommend using the "`Factorio Modding Toolkit (FMTK)`" and "`Factorio Lua API autocomplete`".
6. Save your VS Code workspace with the "`Save Workspace As...`" menu option, under the "`File`" tab. You can save it anywhere you'll remeber and you should use that file to reopen your VS Code workspace whenever you want to restart working on Facotrio Access. This workspace file is used to store your VS Code settings that are not shared by different developers, like folder locations. 
7. Update your working branch of the repository, using either the "`main`" branch or the "`next-update`" branch. We usually reserve the `main` branch for stable releases while ongoing work is collected on the `next-update` branch after it has been (mostly) tested and intended for the next release. 
8. The code is now ready for editing but we recommend setting up VS Code for testing as well. If you'd like to do live debugging while still hearing what's going on, you'll need a special version of the mod launcher that doesn't have a console. You can find that [linked here](https://github.com/Factorio-Access/Factorio-Access-Launcher/releases). It should be placed next to facotrio.exe in the folder "`Facotrio\bin\x64\` ".
9. To get the Factorio Modding Tool Kit (FMTK) working you'll need to select your Factorio version to use for testing in VS Code. Rather than pointing to "`facotorio.exe`", you should set it to the launcher downloaded in the previous step. This can be achomplished using `ctrl + shift + P` and typing in the option for "`Facotrio: select version`".
10. Pick a save file of yours that you'd like to do your debugging on and rename it to "`test.zip`".
11. Back in VS Code, open up any lua file you'd like to debug, set any breakpoints you'd like, and press F5 to run it. Hopefully, you'll hear Hello Facotrio like usual and be dumped into your test game.

## Factorio data lifecycle

Factorio allows mods to run Lua code either during the startup of the game before the main menu loads, or during runtime after a save file loads.

The startup process includes the settings stage where mods are configured, and the prototype stage where mods define new [prototypes](https://lua-api.factorio.com/latest/prototypes.html) for game content such as sound effects, input keybinds, custom buildings, and more.

The runtime stage takes place alongside normal gameplay, and allows interaction with the game world. Code execution is based on [events](https://lua-api.factorio.com/latest/events.html) being fired for mods to react to, with the API functionality being provided via objects of various [classes](https://lua-api.factorio.com/latest/classes.html) that have been defined specifically for mods.

Like other mods, Factorio Access reacts to three types of events: listened in-game events such as an entity taking damage, player input events such as a key being pressed, and scheduled events such as a function scheduled to be called once per second. 

Factorio runs everything on a single main thread so that the game is deterministic, although it is highly optimized to parallelize independent tasks. The game runs with 60 game ticks per second and multiple events can be called on the same tick.

Read more about the data lifecycle on [this official documentation page](https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html).

## Data structures used in Factorio Access

During runtime, the API allows you to reference game objects directly, with read and/or write permissions for their listed properties. Game objects include the `surface`, which is the world made up of `tiles`, and covered in `entities`. Every entity has a `unit_number` that is unqiue to it, and a class `name` explaining what it is and what it can do. Usually doing something in the mod begins with referencing an entity or a tile.

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

The mod has a number of ".ini" files in the folder named `config_changes`. These files define which game settings are changed by the Factorio Access launcher during game configuration. There are multiple files to allow for existing players to only get the new changes when they update while not clobering any customisations. If you want to change a setting between releases, it should go into a new file, that way players that are up to date with all the previous suggestions will recieve the new setting. If you want to update a setting that was already changed, it should still go in a new file, and ideally that setting wold be deleted from the old file that set it. That way new players don't have to have that setting changed twice which would be annoying if they're doing it interactively. Removal of settings is the only substantial change that should be made to old files, but comments can be updated anytime. All new setting changes for a particular release can go into one new file and the first two letters of that file should start with the next alphabetical options ie. AG_whatever.ini follows AF_something_or_other.ini and BA_wow_the_two_letters_was_a_good_idea.ini follows AZ_another_non_descript_name.ini.

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
