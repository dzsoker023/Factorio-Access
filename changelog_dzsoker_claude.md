# FactorioAccess — dzsoker & Claude helyi módosítások changelogja

Ez a fájl a `C:\Users\kovac\AppData\Roaming\Factorio\mods\FactorioAccess` alatt élő, **még commitolatlan** helyi módosításokat listázza a hivatalos upstream git baseline-hoz képest. Cél: amikor eljön az ideje, ebből könnyen ki lehessen válogatni témánként, mi menjen be külön MR/PR-ként.

## Baseline

A mod jelenlegi `info.json`-ja szerint `factorio_version: "2.1"`, `version: "0.16.57"` — ez pontosan megegyezik az upstream repo (`https://github.com/Factorio-Access/FactorioAccess`) `f2.1` branch-ének állapotával:

- `origin/f2.1` HEAD: `7cab9ec6` — "Fix: interrupt renames in trains GUI being silently ignored" (2026-07-02)
- ami maga a `main` branch akkori HEAD-jére (`631eb3f9` — "Add pollution level check command", 2026-03-20) épül rá, plusz az `f2.1` branch saját "2.1 migration" commitjai.
- Az `f2.1` branch **nincs mergelve** a `main`-be (ellenőrizve: `git merge-base --is-ancestor origin/f2.1 main` → nem ancestor).

Minden alábbi diff ehhez az `origin/f2.1` (`7cab9ec6`) commithoz van mérve. Ez a "baseline" ezután a dokumentumban.

**Fontos korlát**: ennek a közös munkának van egy korábbi, már nem rekonstruálható szakasza is (a beszélgetés kontextusa többször kompaktálódott, a legkorábbi nyers részletek elvesztek). Ahol ez érinti a rekonstrukciót, azt az adott szakasznál jelzem — ott a *miért* a kódból/kommentekből lett visszafejtve, nem a beszélgetés-történetből.

## Tag-legenda (erre szűrhetsz majd MR-eknél)

| Tag | Jelentés |
|---|---|
| `[SA-BEVEZETES]` | Space Age (platform/planet/display-panel/ghost-placement) újonnan bevezetett funkció |
| `[SA-REMOTE-NIL]` | Meglévő kód crashelt, mert az SA platform-funkció miatt most már elérhető egy korábban nem létező "remote controller, nincs character" állapot |
| `[SA-QUALITY]` | Space Age Quality (minőség) rendszer UI-támogatása |
| `[F2.1-BREAK]` | Factorio 2.1 engine API-változás miatti törés, javítás |
| `[COMBAT-ANOMALIA]` | Combat közben megfigyelt/jelentett anomália kivizsgálása és javítása (ez a mostani munkamenet fő témája) |
| `[FACTORISSIMO]` | Factorissimo (opcionális 3rd party mod) támogatás/kompatibilitás |
| `[MISC]` | Egyéb, SA-hoz nem köthető funkció/javítás |
| `[NEM-KOD]` | Kutatás/magyarázat, kód nélkül (vagy explicit visszavont kód) |
| `[SKIP]` | Nem changelog-releváns (dev-tooling, holt locale kulcs stb.) |
| `[SA-RESOURCE]` | Space Age bolygók (Vulcanus/Fulgora/Gleba/Aquilo) bányászható resource-entitásainak scanner-regisztrációja, Nauvis rocks mintájára |
| `[LIGHTNING]` | Fulgora lightning-attractor fedettségi rács (20. pont) — coverage grid, warnings, K gomb integráció |
| `[CURSOR-SKIP-GENERIC]` | Cursor-skip (Shift/Ctrl+WASD) generikus terep-kategória felismerése minden bolygóra (víz-szerű + Gleba talaj) és a hozzá kapcsolódó scanner-bejegyzések (21. pont) |
| `[PIPE-SKIP-FIX]` | Pipe-to-ground cursor-skip — git-történelemből visszaállított, korábban már bevált javítás (22. pont) |
| `[LIGHTNING-BUILDING]` | Új, valódi-entitás-alapú warning: konkrét épület védtelen a lightning-rács szerint, a terep-alapú hole/shore-gap threshold-jától függetlenül (23. pont) |
| `[PLATFORMS-NEW-BUTTON]` | Új "New Platform" gomb a világmenü Platforms fülén — bolygó+név választás (24. pont, github #285) |
| `[PLATFORMS-NEW-BUTTON-V2]` | A fenti gomb javítása: nincs szükség meglévő silóra — valódi vanilla "remote view request" mechanikát használ (`create_space_platform` mint logistics-kérés), plusz új "pending platform" szekció (24.5 pont) |
| `[SOLAR-STATUS-FIX]` | Napelem-státusz bemondás (`ent_info_solar`) Nauvis-specifikus óra-küszöbök helyett felszín-saját dawn/morning/evening/dusk mezőket használ (25. pont, github #310) |

---

## 1. `[SA-BEVEZETES]` Space Platform & Planet Travel UI (nagy, önálló funkcióblokk)

Ez a legnagyobb egybefüggő blokk: teljes accessibility-támogatás a Space Age "űrplatform" utazáshoz — platform konfigurálása, ütemezése, indítás/landolás, és szellem- (ghost-) építés platformon utazás közben, amikor nincs elérhető character/inventory.

**Ennek a blokknak a részletes belső "miért"-jei már a mostani session raw-transzkriptumán kívülről (a legkorábbi, már csak összefoglalóból elérhető szakaszból) származnak — a kódban lévő kommentek alapján rekonstruálva, nem szó szerinti beszélgetés-emlékezetből.**

### Új fájlok (teljes fájl = a változás, nincs "helye" a baseline-ban)

- **`scripts/ui/tabs/platform-config.lua`** (117 sor) — új UI tab a `space-platform-hub` entityhez: átnevezés, manuális/automata mód (`platform.paused`), ütemezés-szerkesztő megnyitása, landolás (`player.land_on_planet()`), jelenlegi hely/tranzit-állapot felolvasása (`platform.space_location` / `platform.space_connection`), sérült csempék száma (`#platform.damaged_tiles`).
- **`scripts/ui/tabs/display-panel-config.lua`** (508 sor) — új UI tab a vanilla "display panel" entityhez: statikus üzenet szerkesztése (`entity.display_panel_text`/`icon`) ÉS — ha van control behavior — feltételes üzenet-lista (add/edit/reorder/delete: `get_record`/`set_record`/`add_record`/`remove_record`/`move_record`), combinator-szerű feltétel gyorsbillentyűkkel (M/vessző/pont). Kódban explicit komment: *"CONFIRMED IN-GAME (Factorio 2.1.17): a valódi attribútum/metódusnevek records / records_count / ... A repo helyi llm-docs tükre messages / get_message / set_message-t ír erre az osztályra — az rossz a telepített játékverzióhoz (crashel: 'doesn't contain key messages')."* — vagyis ez saját maga is egy 2.1-es API-eltérés kivédése volt fejlesztéskor.
- **`scripts/ui/tabs/ghost-placement.lua`** (99 sor) — item kiválasztása és beállítása `LuaControl.cursor_ghost`-ként, amikor nincs character (remote view, vagy platformon utazás közben). Komment: *"as of Factorio 2.0.72, LuaPlayer.can_build_from_cursor/build_from_cursor ignore LuaControl.cursor_ghost entirely (confirmed engine bug, fixed for 2.1)."*
- **`scripts/ui/selectors/planet-selector.lua`** (60 sor) — felfedezett/feloldott space location-ök listázása (`prototypes.space_location`, `force.is_space_location_unlocked` + `not location.hidden` szűréssel) platform-ütemezés célpontjaként.
- **`scripts/ui/selectors/platform-selector.lua`** (62 sor) — a force saját platformjainak listázása, szűrve arra, hogy ugyanott parkoljanak, ahol az indító silo van — rakéta-silo launch célpont-választáshoz.
- **`locale/en/ui-platform.cfg`** (31 sor, új) — a platform-config/selector/rocket-silo új szövegei.
- **`locale/en/ui-display-panel.cfg`** (28 sor, új) — a display-panel-config szövegei.

### Meglévő fájlok módosításai (plumbing + integráció)

- **`scripts/ui/tabs/rocket-silo-config.lua`** — 3 hunk (kb. sor 3-34 régi számozás szerint, lásd diff): "Launch cargo to platform" / "Launch self to platform" gomb (megnyitja a `PLATFORM_SELECTOR`-t, majd `entity.launch_rocket(target)` / `launch_rocket(target, player.character)`), "Create platform from starter pack" (`silo.force.create_space_platform(...)`), "Satisfy requests from orbit" checkbox (`entity.use_transitional_requests`), és egy `rocket_is_overloaded` súlyellenőrzés (`LuaInventory.max_weight` ellen) indítás előtt.
- **`scripts/ui/entity-ui.lua`** — 8 hunk (kb. sor 18-266): regisztrálja a `display_panel_config_tab`-ot és `platform_config_tab`-ot; `ENTITY_TYPES_WITH_UI`-hoz adja a `space-platform-hub`-ot és `display-panel`-t (komment: *"confirmed in-game that display-panel's window does not open without an explicit entry here"*); `BLOCKED_GENERIC_INVENTORY_NAMES` — blokkolja a generikus inventory-grid tabot a `rocket_silo_attached_cargo_unit`-nál (indok: kézi berakás ott "megkerülte a rakéta súlykorlátját, így pl. atombombát is fel lehetett tenni rá"); `ALWAYS_SHOWN_EVEN_WHEN_EMPTY` — a `rocket_silo_rocket` látható marad 0 slotnál is (indok: 2.1.7 óta dinamikusan méreteződik, üresen kiszűrve nem lenne mód az első itemet betenni).
- **`scripts/ui/router.lua`** — regisztrálja a `PLATFORM_SELECTOR` és `PLANET_SELECTOR` UI-neveket. Tiszta plumbing.
- **`scripts/ui/schedule-editor.lua`** — 14 hunk (kb. sor 75-1049): a megosztott vonat-ütemező kiterjesztve `space-platform-hub`-ra is: `get_schedule()` most `entity.surface.platform.get_schedule()`-t is néz; `damage_taken` mint új wait-condition/interrupt-trigger típus (aszteroida-sérülés tranzit közben); célpont-választás `PLANET_SELECTOR`-ra route-olva `STOP_SELECTOR` helyett platform hub esetén; több `assert(entity.type == "locomotive")` lazítva `"space-platform-hub"`-ra is.
- **`scripts/ui/menus/main-menu.lua`** — amikor a játékosnak nincs elérhető characterje, de `remote` controlleren van (remote view VAGY platformon utazás közben), a főmenü most "Ghost Placement" szekciót mutat crafting/inventory helyett, és `open_main_menu` többé nem bukik el (`return false`) ebben az állapotban. Komment: *"Remote view, or riding a space platform while it's travelling between locations, both use the 'remote' controller — crafting and personal-inventory access don't work there even though the character entity can still exist."*
- **`control.lua`** — 2 hunk ebből a blokkból: a `platform-selector`/`planet-selector` require-regisztráció, és `open_main_menu` guardja (`p.character == nil` → `p.controller_type == defines.controllers.remote` is megengedve).

---

## 2. `[SA-BEVEZETES]` Ghost-építés motor (cursor_ghost) — szorosan kapcsolódik az 1. ponthoz

Ez teszi lehetővé, hogy a cursoron tartott *ghost* (nem kézben tartott item) alapján is lehessen építeni/forgatni/pipettázni — enélkül a fenti platform-utazás közbeni építés nem működne.

- **`scripts/building-tools.lua`** — 9 hunk (kb. sor 65-1369, a fájl 59876 bájt, elég nagy): `calculate_build_params` most `p.cursor_ghost.name`-re (egy `LuaItemPrototype`-ra) esik vissza, ha nincs érvényes kézben tartott stack; új `mod.place_ghost_via_script` közvetlenül scriptből rakja le a ghostot (`LuaSurface.create_entity({name="entity-ghost"/"tile-ghost", ...})`); `build_item_in_hand_with_params` ezt az utat hívja `using_ghost` esetén, és kihagyja a `prepare_build_area`-t `remote` controlleren; ghost forgatás támogatás; gazdagabb `identify_building_obstacle` (felismeri az `out-of-map` — platform szélén kívüli — csempét is). Kétszer is explicit komment: *"Confirmed upstream Factorio engine bug (as of 2.0.72): LuaPlayer.can_build_from_cursor and build_from_cursor simply ignore LuaControl.cursor_ghost entirely ... A Factorio developer (Genhis) confirmed this on the bug tracker and said 'this is fixed for 2.1'."*
- **`scripts/build-dimensions.lua`** — a stack-forgatásszámláló logika közös `get_rotation_count_for_item_prototype`-ba kiemelve, plusz új `mod.get_rotation_count_for_ghost(item_prototype)` belépési pont ugyanahhoz cursor-ghostra.
- **`scripts/ui/tabs/item-chooser.lua`** — (ebben a fájlban KÉT független dolog van, lásd a 6. pontnál a másikat is) — új `FILTER_TYPES.PLACEABLE` szűrő (`proto.place_result ~= nil or proto.place_as_tile_result ~= nil`), ezt használja a ghost-placement.lua a lerakható item/csempe listázásához.
- **`scripts/cursor-changes.lua`** — pipette (`p.pipette`) most `ent.ghost_prototype`-ot old fel a generikus `entity-ghost`/`tile-ghost` konténer-prototípus helyett ghost pipettázásakor, és átadja `allow_ghost = true`-t (a 3. paraméter, korábban kimaradt, defaultból `false`). Komment: *"pipette's third parameter defaults to false, meaning it silently ignores ghosts entirely unless told otherwise."*
- **`locale/en/building-tools.cfg`** — új kulcsok a fenti hibaágakhoz: `ghost-item-could-not-be-resolved`, `building-tile-cannot-place`, `building-off-platform-edge`, `building-unknown-obstacle`. **Megjegyzés**: ugyanitt van két HOLT kulcs is (`building-surface-check-ok` / `building-surface-check-blocked`) — sehol nincs rájuk hivatkozás a kódban, valószínűleg egy korábban eltávolított debug-segédlet maradványai. Törölhetők, nem funkció.
- **`control.lua`** — a `cursor_ghost.name.localised_name` / `.name.place_result` hunk ide is köthető, de valójában inkább 2.1-es API-fix (lásd 3. pont).

---

## 3. `[F2.1-BREAK]` Factorio 2.1 engine API kompatibilitási javítások

Ezek nem új funkciók, hanem az időközben megváltozott/átnevezett/most már nil-t adó API-khoz való igazodás.

- **`control.lua`** — 5 önálló hunk:
  - `cursor_ghost.localised_name` / `.place_result` → `cursor_ghost.name.localised_name` / `.name.place_result` (a ghost item-prototype mezői `.name` alá kerültek).
  - `driving`/`vehicle` kezelés: most `vehicle ~= nil`-t is ellenőriz, mielőtt új járműbe szállásként kezelné; `storage.players[pindex].last_vehicle` törlődik kiszálláskor/teleportáláskor. Komment: *"driving can be true with a nil vehicle (e.g. LuaPlayer.land_on_planet() toggles the driving state without attaching a real vehicle)."* (Ez a bug technikailag az SA platform-landolás miatt vált elérhetővé, de maga a hiba egy általános `driving`/`vehicle` API-alak probléma.)
  - Pipe-to-ground alagút-ugrás: a régi `entity.fluidbox.get_pipe_connections(n)`-stílusú hozzáférés lecserélve `start.get_fluid_box_pipe_connections(1)`-re, `pcall`-ba csomagolva, dokumentált fallback-kel `start.neighbours`-ön át. Komment: *"in 2.1 it can throw 'LuaEntity doesn't contain key fluidbox' even for a perfectly normal ... pipe-to-ground ... confirmed against the live lua-api.factorio.com docs (the local llm-docs mirror still only documents the old style)."*
  - Underground-belt ugrás: érvénytelen `.neighbours` mező-hozzáférés lecserélve a helyes `start.underground_belt_neighbour` mezőre. Komment: *"LuaEntity has no plain 'neighbours' field for underground belts (crash: 'LuaEntity doesn't contain key neighbours')."*
  - Egy már érvénytelen `---@cast cb LuaGenericOnOffControlBehavior` annotáció eltávolítva egy power-switch control behaviornál; `ent.get_transport_line(tl(1))`/`tl(2)` egyszerűsítve vissza sima `1`/`2` egészekre, egy már felesleges `tl()` wrapper törlésével.
- **`scripts/localising.lua`** és **`scripts/ui/menus/crafting.lua`** — `[SKIP]` — egy-egy üres sor törölve kommentben/deklaráció után, tisztán kozmetikai, nincs funkcionális hatása.

---

## 4. `[SA-REMOTE-NIL]` Remote-view / character nélküli `get_main_inventory()` nil-crash javítások

Közös hibaminta 6+1 fájlban: `LuaControl.get_main_inventory()` `nil`-t ad vissza (nem üres inventoryt), ha nincs elérhető character — pl. remote view-ban, VAGY (az 1-2. pont miatt) platformon utazás közben, VAGY remote view-ból bányászott ghost esetén. Több hívási hely korábban feltétel nélkül hívott rajta metódust, és ezekben az állapotokban crashelt. Ugyanaz az egysoros védő-fix ismétlődik mindenhol.

- **`control.lua`** — `cursor_stack` extra-count lookup védve: `main_inventory and main_inventory.get_item_count(...) or 0`. Komment: *"In remote view (or any state without an accessible character), the player has no main inventory to check."*
- **`scripts/area-operations.lua`** — a terület-tisztító bányászási folyamat "initial" és "final" üres-stack számlálása is védve; explicit megjegyzés, hogy ez "ugyanaz a crash mint a read_hand-é, mivel ghostokat (többek közt) remote view-ból is lehet bányászni."
- **`scripts/crafting.lua`** — a hiányzó-alapanyag ellenőrzés védve.
- **`scripts/fa-commands.lua`** — egy parancs (give-szerű) védve, most `fa.crafting-no-character`-t mond crash helyett.
- **`scripts/player-init.lua`** — `faplayer.hand.max` számítása védve (`#character.get_main_inventory()`).
- **`scripts/quickbar.lua`** — a quickbar item-szám kiolvasás védve.
- **`scripts/sonifiers/vehicle.lua`** — `is_trackable_vehicle` azonnal `false`-t ad, ha `vehicle == nil` — ugyanaz a "driving lehet true jármű nélkül" helyzet, mint a `control.lua`-s fixnél.

**Egy changelog-sor is elég lenne rá összevonva**: *"Több 'attempt to index a nil value' crash javítva inventory-számláláskor remote view-ban vagy egyébként character nélkül (pl. platformon utazás közben)."* — de PR-bontáskor fájlonként is szét lehet szedni, ha kell.

---

## 5. `[SA-QUALITY]` Space Age "Quality" rendszer UI-támogatása

Új kezelőfelület a vanilla minőség-szintekhez (normal/uncommon/rare/epic/legendary) olyan UI-kban, ahol korábban nem volt elérhető.

- **`scripts/ui/tabs/logistics-section-editor.lua`** — `on_toggle_supertype` handler (J / Shift+J) a logisztikai kérés minőség-szűrőjének ciklázásához (`any → normal → uncommon → ... → legendary`, `LuaQualityPrototype.level` szerint rendezve), "Any quality" csak `slot.min == 0` esetén (az API exact quality-t követel, ha a min nem 0).
- **`scripts/ui/tabs/infinity-chest-config.lua`** — ugyanez infinity-chest szűrőkhöz; itt nincs "any" opció (mindig konkrét minőség, alapból `"normal"`), ezért minden filter-set hívás most `quality = current.quality or "normal"`-t is átad.
- **`locale/en/logistics.cfg`** — `logistics-quality-any`, `logistics-quality-feature-disabled`, `logistics-quality-not-applicable` új kulcsok.

---

## 6. `[MISC]` Upgrade planner "No module" támogatás

Az upgrade planner modul-mapper szabályai mostantól tudnak *üres* modul-slotot is reprezentálni (vanilla megengedi "üres → modul" vagy "modul → üres" mappelést, erre eddig nem volt UI-út). Nem SA-specifikus.

- **`scripts/upgrade-planner.lua`** — `get_mapper_name` most `{"fa.upgrade-mapper-no-module"}`-t ad `nil` helyett, ha a mapper létezik de nincs `.name`-je (vanilla "üres slot" placeholder); `is_rule_defined` mostantól `from ~= nil`-t néz `from and from.name ~= nil` helyett.
- **`scripts/ui/planners/upgrade-planner-menu.lua`** — új `module_mapper(name)` helper: `ItemChooser.NO_MODULE_RESULT` → `{type="item"}` (nincs `name` mező = vanilla üres-slot mapper).
- **`scripts/ui/tabs/item-chooser.lua`** — (a másik, ghost-tól független változása ennek a fájlnak) — `mod.NO_MODULE_RESULT` sentinel + "No module" választás mint a fa első/kezdő node-ja `filter_type == MODULE` esetén.
- **`scripts/ui/tree-chooser.lua`** — `TreeChooserBuilder:set_start_key(key)` / `preferred_start_key` — egy fa kikényszerítheti, melyik root node-on nyíljon meg (ez teszi lehetővé, hogy a "No module" legyen a landing node).
- **`locale/en/ui-upgrade-planner.cfg`** — `upgrade-mapper-no-module` új kulcs.

---

## 7. `[FACTORISSIMO]` Factorissimo (opcionális 3rd party mod) támogatás — teljes szál

Mindenhol `remote.interfaces["factorissimo"]` guard mögött, tehát a mod telepítése nélkül teljesen no-op.

### 7a. Élő gyárépület kijelző-felolvasás (korábbi, csak kódból rekonstruálható szakasz)

- **`scripts/fa-info.lua`** — új `ent_info_factorissimo_factory_display` handler: `storage-tank`-típusú entitásoknál meghívja a `"factorissimo"` remote interfészt (`get_factory_by_entity`), és ha a gyárnak van `inside_overlay_controller`-je, felolvassa a rákonfigurált jeleket (`Circuits.constant_combinator_signals_info`). Mindenhol `remote.interfaces[...]` ellenőrzés + `pcall`.
- **`locale/en/entity-info.cfg`** — az ehhez tartozó `factorissimo-factory-display-label=Display` kulcs.

### 7b. Connection-indicator forgatás — kivizsgálva, implementálva, majd **explicit kérésre visszavonva**

- **`scripts/entity-selection.lua`** — `[NEM-KOD]` (nettó nulla változás). Kivizsgálva: a Factorissimo F/R/H/V forgatás-jelzés nem működik FA-ban; kiderült, hogy FA saját H/V billentyűi NEM a valódi blokkoló ok (ezt a felhasználó korrigálta egy korábbi rossz elméletet), hanem `entity-selection.lua` `compare_entities`-e nem veszi figyelembe a `selection_priority`-t, ezért rossz átfedő entitást választ ki. Implementáltam egy `selection_priority`-alapú tiebreaket, deployoltam, majd **a felhasználó explicit kérésére visszavontam** ("Inkább írd vissza biztonság kedvéért, factorissimo userek meg tudják csinálni a többiek meg ne lepődjenek meg esetleges rossz sorrendezésen."). Byte-pontosan visszaállítva az eredeti 8608 bájtos tartalomra. **Végeredmény: nincs kódkülönbség a baseline-hoz képest, de a döntés maga dokumentálva van, ha később újra elő akarod venni.**

### 7c. Power (kW) readout 0-t mutatott Factorissimo gyár mellett — javítva

- **`scripts/electrical.lua`**, `get_electricity_flow_info` (a baseline-ban kb. a 27-60. sor környékén) — a kapacitás-számítás korábban csak `ent.surface`-on keresett termelő entitásokat, ez 0-t adott, ha a valódi termelők más felületen voltak (pl. egy Factorissimo gyár belső felülete a fő felszínen álló generátorokhoz képest), miközben ugyanahhoz az `electric_network_id`-hoz tartoznak. Javítva: `game.surfaces` összes felületén keres; a solar-panel szorzó (`solar_power_multiplier`/`darkness`) is a termelő SAJÁT felületéről jön, nem a lekérdezett entityéből. Egy korábbi, téves első próbálkozás (egy redundáns "consumption"/input_counts kijelzés hozzáadása) a felhasználó korrekciója után vissza lett vonva ("A produced jelenleg a felhasznált a capacity amire 0-t ír."). **Végleges, működő állapot, nincs további panasz rá.**

### 7d. Blueprint / vágás-beillesztés / robot-újraépítés mechanika — csak magyarázat, nincs kód

- `[NEM-KOD]` — Factorissimo blueprint és rekurzív interior-másolás mechanikájának megmagyarázása (`handle_factory_placed`, `copy_entity_ghosts`, `setup_blueprint_tags` — csak akkor másolja rekurzívan a belsőt, ha a forrás gyár még létezik ugyanabban a mentésben).
- `[NEM-KOD]` — miért marad csak "factory ghost" cut-paste után: explicit felhasználói kérésre ("Ne írj kódot csak mond hogy miért") csak elmagyarázva, nem kódolva.
- `[NEM-KOD]` — miért nem építi vissza 200 robot a becsomagolt (packed) gyárat: legjobb magyarázat a `factory-N-instantiated` item `type = "item-with-tags"` (ugyanaz a típus, mint a blueprint/planner itemeknél — azok se robot-építhetők), megerősítve a felhasználó saját empirikus tesztjével (blueprint-ghost ÉS cut-paste-ghost is mindig robot-buildel sikertelen, csak kézi lerakás működik).

### 7e. Becsomagolt gyár kijelző-tartalmának felolvasása item-infóban (a 3 crash-es szál)

Ez a session leghosszabb hibavadászata. **`scripts/item-info.lua`**, a `factorissimo_packed_display_info` funkció (a baseline-hoz képest új blokk, a jelenlegi fájlban kb. a 742-808. sor körül, lásd a diffben a `@@ -741,6 +742,70 @@` és `@@ -777,6 +842,8 @@` hunkokat) + a top-level require-blokk (`local RichText = require("scripts.rich-text")` az új sor).

- **Feature**: egy nem üres Factorissimo gyár felszedésekor/vágásakor kapott `factory-N-instantiated` itemnek van egy `custom_description`-je (a Factorissimo saját maga tölti fel rich-text jel-ikon tagekkel, pl. `[item=iron-plate]`), eddig ez csak látóknak volt olvasható (tooltip). Ez a funkció felolvassa ugyanazt, amit a 7a. pontban lévő élő-épület kijelző is felolvas.
- **1. crash** ("too many C levels", circular require): egy top-level `require("scripts.circuit-network")` körkörös require-t okozott (`item-info.lua → circuit-network.lua → worker-robots.lua → equipment.lua → inventory-transfers.lua → item-info.lua`), az EGÉSZ modot elszállította induláskor. Első javítási kísérlet: a require-t "lazy"-vé tenni (függvényen belülre tenni) — ez tűnt jónak elsőre.
- **2. crash** ("Require can't be used outside of control.lua parsing"): kiderült, hogy Factorio ALAPJÁN tiltja a `require()`-t az induló betöltési fázison kívül — ez Factorio-specifikus szabály, nem sima Lua-körkörösség. A "lazy require" próbálkozás emiatt önmagában is hibás volt.
- **Végleges, jelenleg deployolt megoldás**: a `circuit-network.lua` require teljesen kikerült; helyette a fájl a már biztonságosan (top-level, ciklusmentesen) requirelhető `scripts.rich-text`-et használja, és a `RichText.verbalize_rich_text()` már amúgy is létező, általános célú rich-text-verbalizálóját hívja — ugyanazt, amit tooltipeknél is használ a mod, ahelyett hogy külön parsert írtunk volna.
- **"Display table" hiba**: a `stack.custom_description` kiolvasása nem mindig egyetlen szinten van beágyazva (`{"", raw}`), ezért az egyszintű unwrap után `tostring()` egy TÁBLÁN futott le, és a játékos szó szerint azt hallotta: "table". Javítva egy rekurzív `flatten_localised_string(ls, depth)` függvénnyel, ami tetszőleges mélységű LocalisedString-fát lapít stringgé (max 8 szint, védelemből).
- **3. crash** (`Speech:fragment(" ") is unnecessary`): a Factorissimo `custom_description`-jében volt egy tisztán szóköz-tartalmú LocalisedString elem; ez a rich-text verbalizáláson át egy `" "` fragmentumként landolt a `speech.lua`-ban lévő hard `error()`-on. **Ez a javítás nem csak `item-info.lua`-t érinti**, hanem a megosztott `scripts/rich-text.lua` `verbalize_rich_text`-jét is (2 hívási hely benne, kb. sor 70-110): új `is_blank(s)` guard, ami kihagyja az üres/csak-szóköz chunkokat mindkét fragment-hívási helyen. Ez a fix általánosan védi a `verbalize_rich_text` MINDEN más hívóját is (pl. tooltipeket), nem csak ezt a funkciót. Emellett `item-info.lua`-ban is van egy defenzív trim (`:match("^%s*(.-)%s*$")`) a lapított stringen.

**Jelenlegi státusz: mindhárom crash javítva, deployolva, a felhasználó visszaigazolta hogy működik.**

---

## 8. `[COMBAT-ANOMALIA]` Combat közben megfigyelt anomáliák — ennek a beszélgetésnek a fő témája

A felhasználó explicit kérésére ("ne kódolj még semmit csak vizsgáld meg") előbb tisztán kivizsgálás történt, csak utána (két külön jóváhagyás után: "csináld, nézzük" és az atombomba-kérdésnél egy közvetlen javaslat formájában) készült el a kód.

### 8a. Alapkutatás — nincs kód

- `[NEM-KOD]` — a mod combat-rendszerének általános architektúrája megvizsgálva (pisztoly/géppisztoly/rakétavető/atombomba/railgun/teslagun): megerősítve, hogy egyetlen, teljesen generikus, prototípus-adat-vezérelt rendszer van, nulla fegyvernév-specifikus hardkódolással (`scripts/combat/combat-data.lua`, `scripts/combat/player-weapon.lua`). Azonosítva: a teslagun lánc-villám mechanikája (nem `type="area"` trigger) láthatatlan a mod saját `analyze_triggers()` elemzése előtt (nem crash, csak egy hiányosság a fegyver-elemzésben); a minőség-rendszer (Quality) hatótáv-bónusza engine-szinten nem is kérdezhető le API-ból egyik fegyvernél sem (nem javítható a mod oldaláról).

### 8b. Worm/spawner célzás nem működik rendesen — `[COMBAT-ANOMALIA]` **javítva**

- **`scripts/combat/aim-assist.lua`**, `get_sorted_targets()` (a fájlban kb. sor 184-260) — a spawnerek/wormok keresési területe a képernyő zoom-szintjétől függött (`Zoom.get_search_area`), NEM a fegyver tényleges lőtávjától — bezoomolva a keresési doboz kisebb lehetett, mint a fegyver valós hatótávja, így lőtávolságon belüli worm/spawner is láthatatlan maradt a célzásnak. Javítva: a keresési terület most a fegyver tényleges `max_range`-jéből épül fel (négyzet a kör köré), ugyanúgy, ahogy a rendes ellenségeknél (`find_enemy_units`) is történik. A már feleslegessé vált `local Zoom = require("scripts.zoom")` is eltávolítva.

### 8c. Atombomba safe-fire nem működött kombat módon kívül — `[COMBAT-ANOMALIA]` **javítva (4 körben)**

- **1. kör** — **`scripts/combat.lua`**, `tick_non_combat_mode()` (kb. sor 397-440) — a függvény eddig CSAK akkor futott le (a safe-mode táv-ellenőrzéssel együtt), ha a vanilla Factorio pontosan `shooting_selected` állapotot állított be (precíz kattintás egy entityre). Vak/pontatlan célzásnál a motor szinte mindig `shooting_enemies`-t állít be helyette — erre a függvény eddig azonnal kilépett, tehát a safe-mode min-range ellenőrzés (és ezzel az atombomba önsebzés elleni védelme) sose futott le kombat módon kívül. Javítva: mindkét állapotra lefut ugyanaz a logika (kurzorpozícióhoz kötve, min-range check, majd entity-választás vagy pozícióra lövés — ugyanúgy, mint kombat módban).
- **2. kör — valós tesztben kiderült, hogy ez még mindig nem volt 100%-os**: a felhasználó egy 86 mezőre lévő spawnerre lőtt atombombával, kombat mód NÉLKÜL, és meghalt — a robbanás közvetlenül rá esett, annak ellenére hogy a cél messze volt (a min-range check emiatt helyesen NEM is tiltotta le a lövést). Ok: amikor `EntitySelection.get_first_ent_at_tile(pindex)` talált entityt a kurzor alatt, a kód eddig csak `player.selected = target`-et állított be, de `player.shooting_state`-et (a tényleges célpozíciót) érintetlenül hagyta — az pedig azt az értéket tartalmazta, amit a vanilla Factorio motor adott a `shooting_enemies` állapothoz, ami egy vak/pontatlan (nem kattintásos) célzásnál NEM feltétlenül a ténylegesen megtalált, távoli célpont pozíciója, akár a játékoshoz közeli/hibás is lehet. A safe-mode check ezért helyesen a kurzorpozíciót (86 mező, biztonságos) nézte, de a tényleges robbanás a motor RÉGI, soha újra nem számolt pozícióján történt. Első javítás: talált cél esetén a már létező `shoot_at_selected(player, target)` helper fusson le (ugyanaz, amit kombat mód is használ), ami EGYSZERRE állítja be `player.selected`-et ÉS `player.shooting_state`-et a cél valódi pozíciójára.
- **3. kör — a 2. kör regressziót okozott**: a felhasználó jelezte, hogy a sima "space" (safe-fire, `shooting_enemies`) mostantól friendly (saját) entityre is tüzelhet, pedig eddig csak a "shift+space" (precíz célzás, `shooting_selected`) tudott bármit (frakciótól függetlenül) eltalálni. Ok: `EntitySelection.get_first_ent_at_tile` (`scripts/entity-selection.lua`) NEM szűr force/frakció szerint — bármilyen entityt visszaad a kurzor alatt, sajátot is —, és a 2. körös fix ezt MINDKÉT bejövő állapotra (`shooting_selected` ÉS `shooting_enemies`) egyformán `shoot_at_selected`-del sütötte el, ami a vanilla `shooting_selected` szemantikáját (bármit eltalálhat) ráerőltette a `shooting_enemies`-re is (aminek a vanilla motorban garantáltan SOSE szabadna friendlyt eltalálnia). Javítás: a függvény az EREDETI bejövő állapot szerint ágazik el — `shooting_selected`-nél (shift+space) marad a 2. körös entity-select + `shoot_at_selected` logika; `shooting_enemies`-nél (sima space) csak `shoot_at_position(player, cursor_pos)`-t hív, a célkövetést/friendly-fire elkerülést teljesen a vanilla motorra bízva.
- **4. kör — a 3. kör is csak részben volt igaz, valós tesztben MÉG EGYSZER előfordult friendly-fire (szétlőtt bányafúró)**: kiderült (a Factorio hivatalos wiki dokumentációja alapján ellenőrizve: https://wiki.factorio.com/Keyboard_bindings), hogy a `shooting_enemies` ("Shoot enemy", alap Space) állapot ÖNMAGÁBAN sem garantál mindig csak-ellenség célzást — ez ammó-típustól függ. "Entity"-célzású ammónál (a legtöbb fegyver, pl. lövedékek) a vanilla auto-aim valóban csak ellenséget választ. DE "position"-célzású ammónál (rakéta-vetők lőszerei — rakéta, robbanó rakéta, ATOMBOMBA) a vanilla motor NEM válogat, egyszerűen a nyers kurzorpozícióra lő, bármi is áll ott, akár saját épület. Pontosan ez engedte meg, hogy egy spawner mellé célzott atombomba a mellette álló saját bányafúrót is szétvigye. **Végleges javítás**: `scripts/combat.lua`, `tick_non_combat_mode()`, a `shooting_enemies` ág most a már meglévő `PlayerWeapon.does_auto_aim(pindex)` (`scripts/combat/player-weapon.lua`) segítségével megkülönbözteti a két ammó-típust — auto-aim ammónál marad a régi `shoot_at_position` (vanillára bízva), NEM auto-aim (pozíció-célzású) ammónál viszont a kód maga ellenőrzi `EntitySelection.get_first_ent_at_tile` + `candidate.force.is_enemy(player.force)`-szal, hogy a kurzor alatt tényleg ellenség áll-e, és ha nem, nem tüzel (`stop_shooting` + `fa.aim-no-enemies` figyelmeztetés) ahelyett, hogy vakon lőne. Deployolva, mtime `1789789494507`, 20210 byte. *(Mellékesen ellenőrizve: a `locale/en/combat.cfg` a device-on mindvégig hiánytalanul megvolt, az `fa.aim-no-enemies` kulccsal együtt — a korábbi "hiányzó locale fájl" gyanú egy elavult helyi tükörmásolat téves diffjéből adódott, NEM valós hiba, nincs teendő, nem kell Factorio-újraindítás.)*

### 8d. "Ghost enemy" és össze-vissza pittyegő radar — `[COMBAT-ANOMALIA]` **javítva**

Két különálló, de rokon hibáról van szó, mindkettő a `scripts/sonifiers/combat/` alatt; egyik sem tényleges "örökre beragadt hang" (mindkét fájl helyesen állítja le a már nem aktuális hangazonosítókat minden ciklusban) — inkább hangazonosító-instabilitás, ami "kísértet-jelenségnek" hallatszik.

- **`scripts/sonifiers/combat/spawner-radar.lua`** — a ciklus-index eddig az épp élő spawner-számmal volt modulózva (`% spawner_count`), ami minden alkalommal újrakeverte a sorrendet, amikor egy spawner meghalt vagy belépett/kilépett a látótérből (pl. atombomba után tömegesen). Javítva: fix, nem változó ciklushosszra kötve (`% CYCLE_LENGTH`, `CYCLE_LENGTH = 8`), így egy adott spawner mindig ugyanabban a ritmusban szólal meg.
- **`scripts/sonifiers/combat/enemy-radar.lua`**, `sample_enemies()` — a kód minden tick-en véletlenszerűen választott ki egy ~50%-os mintát az ellenségekből (`math.random() < fraction`), majd a klaszter-hangazonosítót a mintában lévő legkisebb `unit_number`-ű tag alapján képezte. Emiatt ugyanaz a fizikai ellenség-csoport tick-ről tick-re MÁS hangazonosítót kaphatott, valahányszor épp a "vezető" esett ki a véletlen mintából — ez hallatszott kísértet-fel/eltűnésnek. Javítva: determinisztikus mintavétel (`unit_number % keep_every == 0`), így ugyanazok a fizikai lények maradnak bent/kint a mintában, amíg ténylegesen nem változik valami a pályán.
- Kiegészítő megfigyelés (nem kódolt javítás, csak megjegyzés): mindkét radar-fájlban van egy `stop_all()` függvény, amit SOHA semmi nem hív meg a kódban (pl. kombat mód ki/be kapcsolásakor sem) — jelenleg ártalmatlan (a tick-enkénti diff-logika magától korrigál), de érdemes lenne bekötni vagy törölni.

---

### 8e. Vulcanus demolisher + Gleba pentapodok (Space Age) — láthatatlanok voltak a scanner/aim-assist/radar rendszerekben — `[COMBAT-ANOMALIA]` **javítva (4 körben, self-diagnosing biztonsági hálóval)**

**1. kör:**

A felhasználó jelezte, hogy a Vulcanus-bolygó "demolisher" ellensége (és felmerült a Gleba pentapod ellenségek — wriggler/strafer/stomper — kérdése is) nincs regisztrálva "enemy"-ként. Kivizsgálás (hivatalos Factorio Lua API dokumentáció + Factorio hivatalos Friday Facts bejegyzések alapján, mivel ez teljesen Space Age-specifikus, a mod eredeti kódjában nem szerepelt még):

- **Ok**: a demolisher NEM a megszokott `"unit"` prototípus-családba tartozik (mint a bugyk/spitterek), hanem egy külön, Space Age-ben bevezetett `"segmented-unit"`/`"segment"` prototípus-párosba — egy `"segmented-unit"` típusú "fej" entitás plusz akár több tucat `"segment"` típusú testrész-entitás, közös egy `LuaSegmentedUnit` health-poolon osztozva (a motor szintjén ez explicit dokumentált: a `LuaSurface.find_enemy_units()` — amit a mod mindhárom érintett rendszere használt — kifejezetten **csak** `"unit"` típusú entityket ad vissza, ez motor-szintű korlátozás, nem a mi hibánk). Emiatt a demolisher három helyen is "láthatatlan" volt:
  1. **`scripts/scanner/surface-scanner.lua`** — a `BACKEND_LUT` tábla (ami megszabja, mely entity-típusokkal foglalkozik egyáltalán a scanner) nem tartalmazott `"segmented-unit"` kulcsot.
  2. **`scripts/combat/aim-assist.lua`**, `get_sorted_targets()` — a combat-mód auto-célzás `find_enemy_units()`-re épül (+ külön kereséssel spawnerekre/wormokra), de nem keresett `"segmented-unit"` típusra.
  3. **`scripts/sonifiers/combat/enemy-radar.lua`** — a passzív hallgatás-radar ugyanígy csak `find_enemy_units()` + turret-keresést használt.
- **Javítás mindhárom helyen**: egy új, explicit `find_entities_filtered({type = "segmented-unit", force = "enemy"})` keresés hozzáadva a meglévő spawner/turret-keresések mintájára. **Szándékosan csak a `"segmented-unit"` (fej) típusra** szűrve, a `"segment"` (testrész) típusra NEM — így egy demolisher egyetlen enemy-ként jelenik meg mindhárom rendszerben, nem tucatnyi külön testrész-bejegyzésként. Ez összhangban van a felhasználó kérésével ("legyenek egy enemy"), és a `scripts/combat/combat-data.lua`-ban már eddig is létező, de sosem ténylegesen kihasznált `"segmented-unit"` enemy-adat-kinyeréssel (54. és 564. sor — ott a prototípus-adatok, pl. max_health, már ki voltak nyerve, csak a runtime-keresés hiányzott mindenhonnan).
- **Nem érintett/nem szükséges ezúttal**: a demolisher szegmensenkénti (fej/test külön célzás/info, mint a vonat vagonjainál) kezelése — ez explicit később megbeszélendő továbbfejlesztés, a mostani kör csak azt oldja meg, hogy a teljes lény EGYBEN látható/hallható/célozható legyen. A Gleba pentapodok (wriggler/strafer/stomper) API-kutatás alapján valószínűleg már eddig is normál `"unit"` típusúak voltak, tehát feltehetően már működtek — ezt a felhasználó még nem tesztelte élesben, további visszajelzésre vár.
- **Fontos, ellenőrizetlen feltételezés**: a `force = "enemy"` szűrő szó szerinti egyezést keres (ugyanígy, ahogy a meglévő spawner/turret-kód is teszi) — feltételezve, hogy a Vulcanus demolisher ugyanazon az `"enemy"` force-on van, mint a Nauvis-i bugyk. Ha ez tévesnek bizonyulna (pl. a demolisher tényleges force-neve más), ez egysoros javítás lenne innen.

**2. kör — a felhasználó a scanner-oldalt kérte finomítani, a vonatok mintájára**: az 1. kör a scannerben is a generikus `SEB.Unit` backendet használta a fejre, ami minden demolishert egy közös "enemies/demolisher" alkategóriába dobott volna (a prototípus-név szerint csoportosítva, `SEB.Unit` defaultja miatt), NEM egyedi demolisherenként — ellentétben azzal, ahogy a vonatok működnek (`SEB.TrainsNamed`: minden vonat saját alkategóriát kap, `train.id` alapján, és a kocsijai/mozdonya `shift+PageUp/PageDown`-nal (`move_within_subcategory`, `control.lua` `fa-s-pageup`/`fa-s-pagedown`) végigléptethetők). A felhasználó kérése: a demolisher ugyanígy működjön — a fej+test szegmensek EGY demolisher-pépredányon belül legyenek végigléptethetők, a vonat-kocsikhoz hasonlóan.
  - **`scripts/scanner/backends/single-entity.lua`** — új `SEB.Demolisher` backend: `subcategory_callback` a `entity.segmented_unit.unit_number`-t (a demolisher-példány egyedi azonosítóját) használja csoportosító kulcsként, pont úgy, ahogy `TrainsNamed` a `train.id`-t. Ez azt jelenti, hogy MOST MÁR mind a `"segmented-unit"` (fej), mind a `"segment"` (testrész) típusú entitások regisztrálva vannak — az 1. körben szándékosan kihagyott `"segment"` típus mostantól szükséges, hiszen a testszegmenseket is végig kell tudni léptetni. Egy demolisher összes szegmense egyetlen alkategóriába kerül, és a scanner saját, már eddig is létező "N. a M.-ből" bejelentése (`scanner-full-presentation` locale kulcs, ami minden más többelemű alkategóriánál — pl. vonatoknál — is ugyanígy működik, TÁVOLSÁG szerint rendezve, nem fej→farok sorrendben, konzisztensen a vonatokéval) automatikusan kezeli a "hányadik szegmens/hányból" visszajelzést, külön kód nélkül.
  - `readout_callback` megkülönbözteti a fejet ("demolisher head") a testszegmensektől ("demolisher body segment") — mivel ezeknek eltérő a sebzés-ellenállása (fej: 50% fizikai; test: 5-50% fizikai, 99% robbanás-ellenállás a test / 60% a fejen, FFF-429 alapján) — majd a szokásos `Info.ent_info` kiegészíti pozíció/health infóval.
  - **`scripts/scanner/surface-scanner.lua`** — `BACKEND_LUT`: `["segmented-unit"]` ÉS `["segment"]` is most már `SEB.Demolisher`-re mutat (az 1. körben csak `["segmented-unit"] = SEB.Unit` volt).
  - **`locale/en/scanner.cfg`** — ÚJ fájl a mod eredeti tartalmához képest? **Nem** — ez a fájl a device-on mindvégig létezett (1482 byte), csak a helyi tükörmásolatból hiányzott (ugyanaz a jelenség, mint a `combat.cfg`-nél korábban ebben a sessionben — a helyi tükör néhány locale fájl esetén elavult/hiányos volt). A valódi device-fájlt letöltve (`device_stage_files`) lett kiegészítve, NEM felülírva/helyettesítve. Új kulcsok: `scanner-demolisher-announce`, `scanner-demolisher-head`, `scanner-demolisher-body`.
  - **`scripts/combat/aim-assist.lua`** és **`scripts/sonifiers/combat/enemy-radar.lua`** — VÁLTOZATLANOK ebben a körben (a felhasználó kifejezetten csak a scannert kérte finomítani; ott továbbra is csak a fej (`"segmented-unit"`) számít célpontnak/hangforrásnak, a szegmensenkénti célzás/hallgatás explicit későbbre halasztott továbbfejlesztés marad).
  - **FONTOS — teljes Factorio-újraindítás szükséges**: a `locale/en/scanner.cfg` módosítás (új kulcsok hozzáadása) csak indításkor töltődik be, mentés-újratöltés NEM elég (ugyanaz a korlátozás, mint bármely más locale-fájl módosításnál ebben a sessionben).

**3. kör — a felhasználó jelezte, hogy a Gleba pentapodok (strafer, stomper) a scanner számára továbbra is láthatatlanok**, holott vizuálisan/más csatornán észlelte a jelenlétüket ("láttam ilyen lábakat néhol"). Kivizsgálás: a korábbi (2. körös) feltételezés, miszerint a pentapodok sima `"unit"` típusúak és emiatt már eddig is működniük kellett volna, **tévesnek bizonyult** — hivatalos Factorio hibakövetőn talált bug-jelentések (pl. forums.factorio.com t=123538 "Entity.speed crashes when applied to strafer", és egy "Spider-unit prototype" tint-hiba, ami explicit megnevezi: "Modded Stomper pentapods (Spider-Unit-prototype)", "small pentapod strafer unit") megerősítik, hogy a **strafer és stomper pentapodok külön `"spider-unit"` prototípus-típusúak**, nem `"unit"` — a Friday Facts #424 hivatalos Factorio-blogbejegyzés ezt közvetve alá is támasztja ("leggy tech from spidertrons", azaz a spidertronok lábmotorját újrahasznosítják). Ez UGYANAZ a hibaosztály, mint a demolisher esetén: a `find_enemy_units()` motor-szinten kizárólag `"unit"` típust ad vissza, tehát a `"spider-unit"` entitások mindhárom rendszerben (scanner, aim-assist, radar) ugyanígy láthatatlanok voltak. A wriggler pentapod ezzel szemben a Friday Facts szerint "classic spritesheets like biters"-t használ, tehát feltehetően sima `"unit"` típusú és már eddig is működött.
- **Javítás mindhárom rendszerben** (nem csak a scannerben, mivel ugyanaz a gyökér-ok, és az eredeti kérés — "regisztráld be enemyként" — mindhárom rendszerre vonatkozott):
  - **`scripts/scanner/surface-scanner.lua`** — új `["spider-unit"] = SEB.Unit` bejegyzés a `BACKEND_LUT`-ban. FONTOS különbség a demolisherhez képest: egy pentapod strafer/stomper EGYETLEN entitás (csak a lábak MEGJELENÍTÉSE kölcsönzött a spidertron-technológiából, nem több összekapcsolt entitásból áll, mint a demolisher szegmensei), ezért itt a sima, egy-bejegyzéses `SEB.Unit` backend a helyes, NEM a `SEB.Demolisher` csoportosító backend.
  - **`scripts/combat/aim-assist.lua`** és **`scripts/sonifiers/combat/enemy-radar.lua`** — a korábban `"segmented-unit"`-re szűkített külön keresés most `type = {"segmented-unit", "spider-unit"}`-re bővült (a Factorio `find_entities_filtered` elfogad típus-listát is, ugyanúgy, ahogy pl. a `scripts/vehicle-cycler.lua` is listával szűr `{"car", "spider-vehicle"}`-re) — egy keresés fedi most már mindkét Space Age enemy-családot. A lokális változónév `demolishers`-ről `space_age_enemies`-re lett átnevezve, hogy tükrözze a bővített hatókört.
  - **Ellenőrzött, nem-kockázatos részlet**: a fent említett `.speed`-crash bug kifejezetten a `LuaEntity.speed` attribútum futásidejű OLVASÁSÁRA vonatkozik — sem a `fa-info.lua`, sem a most módosított három fájl egyike sem olvassa ezt az attribútumot semmilyen entity-n, tehát ez a hiba (ami egyébként is egy régebbi, 2.0.23-as verzió elleni jelentés, lehet hogy azóta javítva) nem érinti ezt a javítást.
- **Nem érintett**: a "stomper egg shell" (amit a felhasználó szintén említett) egyelőre nem lett külön azonosítva/kezelve — ez feltehetően az egg-raft "kiürült" állapota vagy egy tojás-törmelék entitás, de ennek pontos prototípus-neve/típusa nem lett kikutatva ebben a körben; ha a felhasználó ezt is hiányolja a scannerből, külön kivizsgálást igényel.

**4. kör — a felhasználó visszajelzése szerint a 3. kör NEM hozott változást**: sem strafer, sem stomper nem jelent meg SEMMILYEN scanner-kategóriában, az Enemies alatt továbbra is csak egg-raft és wriggler látszott. Kivizsgálás, két lehetséges ok azonosítva:
  1. **Egy valódi, a 3. körtől független scanner-architektúra hiba, amit itt találtunk meg először**: a scanner `dispatch_entities()` függvénye egy entitást, aminek a `type`-ja NEM szerepel a `BACKEND_LUT`-ban, **csendben eldob** — DE a `scan_chunk()` a `state.seen_entities` bitseten már ekkor "látottnak" jelöli az adott entitást (a dedup-logika ezt FÜGGETLENÜL a tényleges dispatch-sikertől beállítja). Ez azt jelenti, hogy ha a felhasználó a mostani javítások ELŐTT már egyszer bejárta/scannelte a Gleba-i területet (nagyon valószínű, hiszen ott játszik), akkor a MÁR LÁTOTT strafer/stomper példányok véglegesen "elhasználtnak" számítanak ebben a mentésben, és a `BACKEND_LUT` utólagos bővítése ÖNMAGÁBAN nem elég ahhoz, hogy újra feldolgozásra kerüljenek — csak új példányok (amik még sosem lettek "látva") jelentek volna meg helyesen. Ez megmagyarázza, miért nem segített a 3. kör, FÜGGETLENÜL attól, hogy a `"spider-unit"` típus-azonosítás helyes volt-e.
  2. **A `"spider-unit"` típus-azonosítás maga is bizonytalan maradt**: a 3. körben idézett fórum-bejegyzés ("Modded Stomper pentapods (Spider-Unit-prototype)") újraolvasva kiderült, hogy egy MÓDosított (3rd party mod által hozzáadott) entitásról szól, NEM feltétlenül a vanilla Gleba stomperről — ez egy kutatási bizonytalanság, amit a hivatalos Factorio dokumentáció/forráskód (2840 soros GitHub-fájl, a scraper-eszköz csak az első 1000 sort adta vissza, a pentapod-definíciók a fájl további részében vannak) eddig nem sikerült megnyugtatóan tisztázni.
- **Javítás — mindkét problémára, találgatás helyett önmagát diagnosztizáló megoldással**:
  - **`scripts/scanner/surface-scanner.lua`**: a `StorageManager.declare_storage_module` `ephemeral_state_version`-je **12-ről 13-ra emelve** — ez kényszerít egy teljes állapot-visszaállítást (újra-scannelést) a mentés következő betöltésekor, amivel az (1) pontban leírt "már látott, de sose feldolgozott" probléma megoldódik, minden korábban esetlegesen kihagyott entitástípusra nézve.
  - **`scripts/scanner/surface-scanner.lua`** + **`scripts/scanner/backends/single-entity.lua`**: új, tartós **biztonsági háló** — mostantól minden `"enemy"` force-ú entitás, aminek a `type`-ja NEM szerepel a `BACKEND_LUT`-ban, NEM lesz csendben eldobva, hanem egy új `SEB.UnknownEnemy` backendhez kerül, ami az Enemies kategória alatt, "unregistered" alkategóriában megjelenik, és a felolvasásban a NYERS `entity.type` és `entity.name` értéket is bemondja (`scanner-unknown-enemy-announce` új locale kulcs). Ez azt jelenti, hogy (a) a strafer/stomper MOST MÁR biztosan megjelenik valahol az Enemies alatt akkor is, ha a `"spider-unit"` feltételezés téves volt, és (b) a felolvasott nyers típus/név véglegesen, kutatgatás nélkül eldönti a kérdést — ráadásul ez a védőháló minden JÖVŐBENI hasonló hiányosságot (bármilyen más Space Age content vagy 3rd party mod entitást) is azonnal láthatóvá tesz, ahelyett hogy csendben eltűnne.
  - **`locale/en/scanner.cfg`** — új kulcs: `scanner-unknown-enemy-announce`.
- **Következő lépés**: a felhasználónak újra kell töltenie a mentést (a `ephemeral_state_version` csere miatt a scanner-állapot amúgy is nullázódik, egy `rescan` paranccsal érdemes újra bejárni a Gleba-területet), és meg kell néznie, mi jelenik meg most az Enemies kategória "unregistered" alkategóriájában — ha strafer/stomper ott bukkan fel a nyers típusával együtt, abból pontosan tudni fogjuk, milyen `BACKEND_LUT`-bejegyzést kell hozzáadni helyettük (ekkor a `SEB.UnknownEnemy`-ből átkerülnek egy dedikált, rendes backendbe).

**5. kör — sikeres visszajelzés, de zajforrás derült ki**: a felhasználó megerősítette, hogy a strafer/stomper MOST MÁR megjelenik az Enemies alatt (tehát a `"spider-unit"` típus-azonosítás helyesnek bizonyult) — DE az "unregistered" biztonsági háló (4. kör) emellett 25 db különálló "láb" entitást is felszínre hozott, mivel a pentapod lábai (a FFF-425 hivatalos blogbejegyzés szerint szó szerint a spidertron lábmotorját újrahasznosítják: "Pentapods reuse the code that drives Spidertron legs") **külön, valódi `"spider-leg"` típusú entitásokként** léteznek a pályán (ugyanúgy, ahogy egy spidertronnak is vannak külön lábentitásai) — ezek is `"enemy"` force-on vannak, ezért a biztonsági háló befogta őket is, holott ezek csak a MÁR helyesen regisztrált pentapod-test alkatrészei, nem önálló ellenségek. (Mellékesen: 25 láb ÷ 5 láb/pentapod = pontosan 5 pentapod — nem harapta le senki senkinek a lábát, a szám csak azért furcsa mert komponensenként számol, nem lényenként.)
- **Javítás**: `scripts/scanner/surface-scanner.lua` — új `IGNORED_ENEMY_COMPONENT_TYPES = { ["spider-leg"] = true }` tábla, amit a biztonsági háló feltétele figyelembe vesz (`... and not IGNORED_ENEMY_COMPONENT_TYPES[e.type]`) — a `"spider-leg"` típus mostantól szándékosan, dokumentáltan figyelmen kívül van hagyva (nem kerül semmilyen backendbe), pont úgy, ahogy a demolisher `"segment"` testrészei is csak a demolisher-specifikus csoportosításon belül számítanak, nem önálló bejegyzésként. Bővíthető tábla, ha a jövőben más hasonló "alkatrész" típus is felbukkanna.
- **`ephemeral_state_version` ismét emelve (13 → 14)** — ugyanaz az ok, mint a 4. körben: a már regisztrált 25 lábbejegyzés a `seen_entities` bitset miatt enélkül nem tűnne el, amíg a lábak entitásai meg nem semmisülnek (pl. a pentapod halálával).
- **Nincs teendő a locale-fájllal ebben a körben** — ez tisztán Lua-módosítás, elég a mentés visszatöltése, NEM kell teljes Factorio-újraindítás.

**6. kör — demolisher hamufelhő ("ash cloud") kizárása a biztonsági hálóból**: a felhasználó jelezte, hogy a demolisher lélegzet-/üvöltés-támadása után visszamaradó, terjeszkedő hamu-/lehelet-felhő (FFF-429: "expanding ash clouds") is felbukkant az Enemies kategóriában a biztonsági háló miatt — holott ez nem entitás a szó valódi értelmében, nem lőhető, nincs saját teste/élete.
- **Kivizsgálás**: a hivatalos Lua API (`SmokeWithTriggerPrototype`) dokumentációja szerint ez a prototípus-osztály (ami feltehetően a felhő típusa — a pontos prototípus-NÉV nem volt kinyerhető, a forrás Lua-fájl túl nagy volt közvetlen letöltéshez) közvetlenül `EntityPrototype`-ból örököl, NEM `EntityWithHealthPrototype`/`EntityWithOwnerPrototype`-ból — vagyis eleve nem lőhető, nincs élete, nincs "valódi" force-tulajdonosa a prototípus szintjén (a `force = "enemy"` paramétert feltehetően csak létrehozáskor, a `LuaSurface.create_entity()` hívásban kapja meg, hogy a saját lassító/sebző trigger-hatása ne sértse magukat a demolishereket).
- **Javítás**: `scripts/scanner/surface-scanner.lua` — az `IGNORED_ENEMY_COMPONENT_TYPES` táblába új bejegyzés: `["smoke-with-trigger"] = true`. **Fontos korlát**: ez a prototípus-típusnév egy megalapozott, de MEGERŐSÍTETLEN találgatás (a demolisher hamufelhő pontos, szó szerinti típusát nem sikerült elsődleges forrásból kiolvasni) — alacsony a kockázata, mert ha téves, a meglévő önmagát diagnosztizáló biztonsági háló (4. kör) továbbra is bemondja a valódi nyers típust legközelebb, amikor a felhasználó egy lehelő demolishert lát, és akkor egysoros javítással pontosítható. Ha viszont a találgatás helyes, a zaj mostantól eltűnik.
- **`ephemeral_state_version` ismét emelve (14 → 15)** — lásd lentebb, 8g. pont: ugyanazzal az emeléssel egyben a resource-kiterjesztés (8g) is aktiválódik, mivel mindkét változás ugyanabban a fájlban, ugyanabban a körben történt.
- **Nincs teendő a locale-fájllal ebben a körben** — tisztán Lua-módosítás, mentés-visszatöltés elég.

---

## 8f-előelő. `[NEM-KOD]` Decon planner "0 elemű" — valódi UI bug, javítva

A felhasználó élesben tesztelte a decon planner menüt (a 8h. pont alapján adott útmutatás szerint), és azt találta: az Entity filters fülön a whitelist/blacklist kapcsoló + clear gomb sor UTÁN semmi nincs — a fül "teljesen üres", egyetlen "Empty slot" sem jelenik meg, tehát filtert sem lehet hozzáadni.

- **Kivizsgálás**: `scripts/ui/planners/decon-planner-menu.lua`, `render_entities_tab()`/`render_tiles_tab()` — a filter-slotokat renderelő ciklus `for i = 1, planner.entity_filter_count do ... end` (és ugyanígy `tile_filter_count`-tal). A hivatalos Factorio Lua API dokumentáció szövege ("The number of entity filters this deconstruction item has") kétértelmű, DE a felhasználó élesben megfigyelt tünete ("teljesen üres, 0 elemű") pontosan azt igazolja, hogy ez NEM egy fix kapacitás (mint korábban feltételeztük a wiki alapján, ami valószínűleg a Factorio 2.0 előtti, fix 30-rácsos UI-t írja le), hanem az AKTUÁLISAN BEÁLLÍTOTT filterek száma — egy vadonatúj, üres decon planneren ez 0, tehát a ciklus nulla sort renderel, és nincs mód belépési pontot találni egy első filter felvételéhez.
- **Javítás**: mindkét ciklus `planner.entity_filter_count + 1` / `planner.tile_filter_count + 1`-re módosítva — így mindig pontosan EGGYEL több slot jelenik meg, mint ahány filter már be van állítva, azaz mindig van egy üres "következő" slot, amit ki lehet tölteni. Ha kitöltöd, a `entity_filter_count` eggyel nő, és a következő megnyitáskor megint megjelenik egy új üres slot utána — ugyanaz a minta, ahogy a játék saját 2.0+ GUI-ja is működik ennél a listánál (fix rács helyett dinamikusan bővülő lista).
- **Kockázat/nyitott kérdés**: NEM tettünk be felső korlátot (a korábban feltételezett "30 slot" lehet elavult, pre-2.0-ás adat) — ha élesben kiderül, hogy egy bizonyos szám felett a kitöltés csendben nem mentődik el, az a valódi felső korlát, és be kell építeni egy `math.min(...)` sapkát. Ezt élesben kell megerősíteni, itt nincs futó Factorio-példány a teszteléshez.
- **Nem érintett**: az upgrade planner (`upgrade-planner-menu.lua`) NEM ugyanezzel a hibával küzd — ott a 24 slot FIXEN van hardkódolva (`MAX_SLOTS = 24`), nem az aktuális darabszámtól függ, tehát mindig mind a 24 sor megjelenik, függetlenül attól, hány van kitöltve. (Külön, kisebb súlyú megjegyzés a felhasználónak elmondva: ez a hardkódolás viszont saját maga egy másik, enyhe kockázat — van rá élő API, `planner.mapper_count`, amit nem használ ki; jelenleg egyezik a valódi 24-es vanilla értékkel, de ha ez valaha változna, csendben elavulna. Nem lett javítva ebben a körben, csak jelezve.)
- **Nincs teendő a locale-fájllal** — tisztán Lua-módosítás, mentés-visszatöltés elég.

**Kiegészítés — mélyebb hiba találva, JAVÍTVA**: a felhasználó rákérdezett, hogy a hivatalos online API-ban van-e valamilyen "max slot" mező, amit esetleg kihagytunk. Újra átnéztem a `SelectionToolPrototype`, `DeconstructionItemPrototype` és `LuaItemPrototype` dokumentációkat — **nincs ilyen explicit mező** egyiken sem (sem a prototípus-, sem a runtime-oldalon). Viszont a további keresés egy ennél fontosabb, közvetlenül idevágó dolgot hozott fel:

- **Megerősített Wube engine bug** (forum: forums.factorio.com/viewtopic.php?p=698072, bejelentve 2.1.9-en, 2026. július 5.): a `LuaItemStack.set_entity_filter`/`set_tile_filter` metódusok "Index out of bounds" hibát dobnak, ha a megadott index PONTOSAN EGGYEL a jelenlegi `entity_filter_count`/`tile_filter_count` fölött van — vagyis pontosan az az eset, amit a fenti `+1` javítás létrehoz: az újonnan látható üres slot indexe a direkt setter szemszögéből "még nem létezik". A bejelentő idézete: "set_entity_filter (és set_tile_filter) úgy lett megváltoztatva, hogy ha a megadott index nem létezik, 'Index out of bounds' hibát dob. Az egyetlen mód ezek használatára, ha az egész `entity_filters`/`item_filters` tömböt egyszerre írod be, utána a `set_entity_filter` már tud létező indexen módosítani." A Wube fejlesztő (Rseding91) megerősítette bugként, és azt írta, hogy a javítás "a következő kiadásban lesz benne" (2.1.9 után) — **nincs megerősítve**, hogy a mod 2.1.8-as alapja, vagy a felhasználó ténylegesen futó Factorio-verziója, már tartalmazza-e ezt a motorjavítást.
- **A gyakorlati következmény**: a fent leírt `+1` renderelési javítás önmagában NEM elég — anélkül, hogy a most talált motorhibát is kezelnénk, a frissen megjelenő üres slot KITÖLTÉSE (tehát az első filter tényleges hozzáadása) egyes 2.1.x verziókon script-hibával futhatna el, pont ott, ahol a felhasználó a hibát élesben megtalálta.
- **Javítás**: két új helper függvény (`set_entity_filter_safe`, `set_tile_filter_safe`) a `decon-planner-menu.lua` tetején, `get_entity_filter_name` elé — LÉTEZŐ index felülírásánál/törlésénél továbbra is a direkt `set_entity_filter`/`set_tile_filter` hívást használják (ez a bugriport szerint rendben van), de egy ÚJ index (a `count`-on túli) beírásánál a teljes `entity_filters`/`tile_filters` tömböt olvassák ki, módosítják egyetlen elemen, majd írják vissza egyben — ez a bugriport szerint minden verzión működik. Minden hívási pont át lett kötve erre: `render_entity_slot`/`render_tile_slot` `on_clear` és `on_child_result` ágai, valamint mindkét "Clear entities"/"Clear tiles" gomb ciklusa (utóbbi kettő csak létező indexeket törölt eddig is, tehát nem lett volna kötelező, de a konzisztencia kedvéért szintén át lett kötve).
- **Nincs teendő a locale-fájllal** — tisztán Lua-módosítás.
- **NEM ellenőrizhető élesben** — ennek a sessionnek nincs futó Factorio-példánya, tehát sem az eredeti "0 elemű" tünet, sem ez a mélyebb javítás nem lett ténylegesen tesztelve egy éles kliensben. Kérünk élő visszajelzést: (1) meg lehet-e most már nyitni egy első filtert az Entity/Tile Filters fülön egy vadonatúj decon planneren; (2) nem dob-e script-hibát a kitöltés.

**Kiegészítés 2 — a felhasználó ÉLESBEN visszahozta a crash-t, most már a valódi okkal**: a fenti setter-oldali javítás (`set_entity_filter_safe`/`set_tile_filter_safe`) NEM volt elég — a felhasználó a decon planner MEGNYITÁSAKOR (tehát render időben, még mielőtt bármit kattintott volna) kapott non-recoverable crash-t:

```
Error while running event FactorioAccess::fa-rightbracket (ID 365)
Index out of bounds.
stack traceback:
	[C]: in function 'get_entity_filter'
	...decon-planner-menu.lua:85: in function 'get_entity_filter_name'
	...decon-planner-menu.lua:190: in function 'render_entity_slot'
	...decon-planner-menu.lua:283: in function 'render_callback'
	...
```

- **A valódi hibaforrás**: kiderült, hogy a `LuaItemStack.get_entity_filter`/`get_tile_filter` GETTER metódusok is ugyanúgy "Index out of bounds"-ot dobnak, ha a megadott index a jelenlegi `entity_filter_count`/`tile_filter_count` fölött van — NEM csak a setterek (`set_entity_filter`/`set_tile_filter`), amikre az előző körben koncentráltunk. A `render_entities_tab`/`render_tiles_tab` ciklus viszont szándékosan MEGY egy indexszel a darabszám fölé (`+1`, hogy legyen egy üres "következő" slot) — és a slot renderelésekor a `get_entity_filter_name`/a nyers `planner.get_tile_filter(slot_index)` hívás EZT az index-et próbálta kiolvasni, ami az engine szerint még nem létezik. Ez tehát a menü MEGNYITÁSAKOR, minden egyes alkalommal lefutott volna (nem csak kattintáskor), amint a `+1`-es slot renderelésre került — ezért dobott crash-t rögtön nyitáskor.
- **Javítás**: `get_entity_filter_name(planner, index)` elején egy explicit bounds-guard: ha `index > planner.entity_filter_count`, azonnal `nil`-t ad vissza, MEG SEM HÍVJA az engine gettert (nincs is ott mit olvasni). Új, hasonló `get_tile_filter_name(planner, index)` helper ugyanezzel a guarddal a tile-oldalra is (eddig ott nyers `planner.get_tile_filter(slot_index)` hívás volt közvetlenül a render függvényben, most átkötve az új helperre). Mindkét slot-renderelő függvény (`render_entity_slot`, `render_tile_slot`) ezeken a guardolt helpereken keresztül olvas mostantól.
- **Tanulság, elmondva a felhasználónak is**: ez egy külön, a settertől független engine-korlátozás volt — a korábbi kutatás (a fórum-bugriport) kifejezetten a settereket említette, a gettereket nem, ezért maradt ki az első körből. Szintaxis-ellenőrizve (`luac5.3 -p` OK), kiküldve, device-ra mentve (byte-szám egyezés megerősítve). **Ez a javítás sem lett élesben tesztelve** — nincs futó Factorio-példány ebben a sessionben.

---

## 8f-elő. `[SA-RESOURCE]` Demolisher "territory" (terület) állapot — aktív/elhagyott kereső

A felhasználó eredeti kérdése ("territory jelzés — foglalt, szabad, stb") pontosítást kapott: NEM az számít elsődlegesen, hogy egy KONKRÉT, éppen látható demolisher nyugodt vagy agresszív-e (az a morgásából/viselkedéséből amúgy is gyorsan kiderül) — hanem hogy egy ADOTT HELYEN, bármilyen state-ben (akár nincs is éppen látható lény), lekérdezhető legyen: van-e ott aktív, őrzött territórium, vagy már halott/elhagyott terület (pl. miután a játékos megölte az odavaló demolishert).

- **API-kutatás eredménye**: `LuaSurface.get_territory_for_chunk(chunk_position)` ad vissza egy `LuaTerritory`-t egy adott chunkra (vagy `nil`-t, ha nincs ott territórium). `LuaTerritory:get_segmented_units()` adja vissza az aktuálisan azt őrző lényeket — FONTOS, hogy ez a hívás minden alkalommal FRISSEN, élesben fut le, tehát a territórium egy MÁR REGISZTRÁLT bejegyzés lehet üres (०db őrző) is, ha az őrei időközben meghaltak, anélkül hogy a territórium maga megszűnne létezni (`LuaTerritory.valid` továbbra is igaz marad — ezt a `regenerate_segmented_units()` metódus létezése is alátámasztja, aminek csak akkor van értelme, ha territórium őrök nélkül is fennmaradhat).
- **Új fájl**: `scripts/scanner/backends/territory.lua` — új `TerritoryBackend`, ami az `IcebergBackend`/`WaterBackend` már meglévő mintáját követi (chunk-alapú felfedezés a scanner saját, chunkonkénti bejárásába kapcsolódva, `on_new_chunk` hook), NEM entitás-alapú. Egy territórium sok chunkot fedhet le — az első megtalált chunk azonnal "learatja" az összes hozzá tartozó chunkot (`LuaTerritory:get_chunks()`), hogy a bejárás további chunkjai ne hozzanak létre duplikált bejegyzést ugyanahhoz a territóriumhoz.
- **Élő állapot, nem cache**: a `readout_callback`-nak megfelelő `readout_entry` minden egyes lekérdezéskor ÚJRA lehívja a `get_segmented_units()`-t — tehát ha egy territórium őrzője időközben meghal (vagy új demolisher generálódik oda), a scanner AZONNAL a helyes, aktuális állapotot mondja be, nem egy régi, scannelés-idejű pillanatképet.
- **`scripts/scanner/surface-scanner.lua`**: `TerritoryBackend` bekötve a `SurfaceBackends` struktúrába, `scan_chunk()`-ba (a meglévő iceberg/water hook-ok mellé), és `get_entries_snapshot()`-ba (a scanner "N a M-ből" felsorolásához). Kategória: Enemies, alkategória: `"territory"` (minden territórium egy közös alkategórián belül, shift+PageUp/PageDown-nal végigléptethető — pont úgy, mint a vízfelületek/jéghegyek egy-egy közös alkategóriában).
- **`locale/en/scanner.cfg`** — két új kulcs: `scanner-territory-active` ("demolisher territory, active, __1__ guarding" — a létszámmal), `scanner-territory-abandoned` ("demolisher territory, abandoned"). **Teljes Factorio-újraindítás szükséges** ehhez a körhöz (locale-fájl változott).
- **`ephemeral_state_version` 15 → 16 emelve** — ez egy ÚJ ok-osztály az eddigiekhez képest: itt nem az "entitás rossz helyre lett dispatch-elve" probléma áll fenn, hanem hogy a `scan_chunk()`-ban az `on_new_chunk` hook-ok (iceberg/water/territory) csak akkor futnak le egy adott chunkra, ha az MÉG NEM VOLT `state.seen_chunks`-ban rögzítve — mivel a Vulcanus jó eséllyel már be van járva a felhasználó mentésében, a territórium-felfedezés enélkül soha nem futna le a már meglátogatott chunkokra.
- **Kockázat/korlát, amit érdemes élesben ellenőrizni**: (1) a territórium-kulcs (amivel a duplikációt elkerüljük) a territórium legkisebb chunk-koordinátájából épül — ez stabil, amíg a territórium létezik, de sosem lett élesben tesztelve, mivel ennek a sessionnek nincs futó Factorio-példánya; (2) nincs garancia arra, hogy `get_territory_for_chunk`/`get_segmented_units` pontosan úgy viselkedik, ahogy a hivatalos API-dokumentáció alapján feltételeztük — ha a scanner "Enemies > territory" alkategóriája üres marad Vulcanuson rescan után is, az API-feltevés hibás, és vissza kell térni rá.

**Kiegészítés (felhasználói visszajelzés után)**: a felhasználó pontosított — nem elsődlegesen a territóriumok LISTÁZÁSA a lényeg (bár az is hasznos marad), hanem hogy egy adott ponton, AZONNAL lekérdezhető legyen "itt vagyok-e most egy territóriumban". Konkrét példa: a meglévő koordináta-felolvasó "K" gomb (`fa-k`, `control.lua`, `read_coords()`) most azt mondja pl. egy resource patch-nél "center at 65, 65"-öt — ilyesmi, csak röviden a "Guarded"/"Free" szóval kiegészítve lenne kényelmes.
- **Kivizsgálás**: a `fa.coordinates-at`/`fa.coordinates-at-with-location` locale kulcsok NEM voltak megtalálhatók a helyi tükörben — kiderült, hogy a `locale/en/travel-tools.cfg` fájl EGYÁLTALÁN NEM létezett a helyi tükörben (ugyanaz a locale-tükör-elavultsági minta, mint korábban a `combat.cfg`/`scanner.cfg`/`ui-general.cfg` esetén — immár negyedszer/ötödször ugyanez a hiba ebben a sessionben). A valódi device-fájlt letöltve találtam meg a kulcsokat.
- **Javítás**: új `TerritoryBackend.get_status_at(surface, position)` függvény (`scripts/scanner/backends/territory.lua`) — ez EGY FÜGGETLEN, azonnali API-hívás (`surface.get_territory_for_chunk()` + `get_segmented_units()`), NEM a scanner saját, chunk-bejárással felfedezett listájára támaszkodik, tehát bárhol azonnal működik, akkor is, ha a scanner még nem "látta" azt a chunkot. `control.lua`, `read_coords()` — minden koordináta-felolvasáskor (a "K" gomb, és a "Cursor returned" útvonal is) meghívja ezt, és ha a pozíció territórium része, a bemondás elé fűzi: `"Guarded "` (aktív őrző van) vagy `"Free "` (territórium, de nincs élő őrzője) — ha a pozíció nem territórium része (pl. bárhol Nauvison), semmi nem változik, néma marad. Ez pontosan a kért "Free center at 65 65" / "Guarded at 65 66" mintát adja.
- **Nem locale-kulcs, hanem nyers string**: a `"Guarded "`/`"Free "` szöveg direkt nem locale-kulcs, mert a `start_phrase` ebben a függvényben mindvégig nyers Lua string-összefűzéssel épül (lásd a már meglévő `"Cursor returned "` hívási pontot) — ez a függvény már eddig is így működött, nem vezettünk be új mintát.
- **Nincs teendő a locale-fájllal** — tisztán Lua-módosítás (`control.lua` + `territory.lua`), mentés-visszatöltés elég, NEM kell teljes újraindítás.
- **FONTOS ÖNKORREKCIÓ, ami eközben kiderült**: a 8h. pontban ("Deconstruction planner — állapotfelmérés") korábban dokumentált állítás, miszerint "a decon planner menü egyetlen locale kulcsa SINCS lefordítva" — **TÉVES VOLT**, ugyanaz a locale-tükör-elavultsági hiba okozta, mint fent: a `locale/en/ui-decon-planner.cfg` fájl a helyi tükörből hiányzott, DE a device-on létezik és tartalmas (38 sor, `decon-rename`, `decon-trees-rocks-only`, `decon-tiles-mode`, `decon-whitelist` stb. mind megvannak). A kutató subagent ezt nem tudhatta, mert csak a helyi (akkor még hiányos) tükröt látta. **Ez a hiányosság tehát NEM létezik** — a decon planner menü lokalizációja rendben van. A 8h. pontban felsorolt egyéb hiányosságok (skip_fog_of_war, super_forced, planner_description, quality-szűrés, undo-integráció) kutatás-alapúak maradnak, ezeket nem érinti a korrekció.

---

## 8f. `[COMBAT-ANOMALIA]` Railgun ~600 tile-ról is lelőhető volt bármilyen távoli ellenséget — javítva

A felhasználó jelezte, hogy a railgunnal a térkép szinte bármely pontján lévő, ~600 tile távolságra lévő ellenséget is el lehetett találni, jóval a fegyver valódi hatótávolságán (vanilla railgun ≈ 40 tile) túl.

- **Kivizsgálás**: a gyanú elsőre a `scripts/combat/combat-data.lua`-ra esett (esetleg hiányzó/hibás hardkódolt railgun-bejegyzés), de ez kizárva — az a fájl teljesen generikus, prototípus-adatból (`data.raw["gun"]`/`data.raw["ammo"]`) dolgozik, nincs benne fegyvernév szerinti hardkódolás, és a `PlayerWeapon.get_max_range()` a railgunra helyesen a valódi ≈40 tile-t számolja ki. A **valódi ok**: `scripts/combat.lua`, `tick_non_combat_mode()`, a `shooting_selected` ág (a "precíz tüzelés" gomb, alapértelmezetten Shift+Space). Ez az ág az `EntitySelection.get_first_ent_at_tile(pindex)`-szel bármit megtalál a virtuális kurzor pozícióján — a virtuális kurzor pedig (WASD-görgetés, scanner "ugrás az eredményre", könyvjelzők) SEMMILYEN távolsághoz nincs kötve, ellentétben egy valódi egérkurzorral. A talált célpontra ezután közvetlenül `shoot_at_selected()` fut le, ami a `player.shooting_state`-et és a `player.selected`-et közvetlenül állítja be — ez megkerüli azt a normál, hatótáv-korlátos kiválasztási útvonalat, amire a motor a saját belső hatótáv-ellenőrzését alapozná, tehát a lövés egyszerűen elindul, bármekkora távolságra is van a cél.
- **Javítás**: `scripts/combat.lua` — a `shooting_selected` ágban, miután `EntitySelection.get_first_ent_at_tile()` megtalálta a célpontot, most már explicit ellenőrizzük `PlayerWeapon.get_max_range(pindex)` ellen (`util.distance(character.position, target.position) > max_range`). Ha túl messze van: a lövés nem indul el, `stop_shooting()` + a már meglévő `fa.aim-no-enemies` figyelmeztetés hangzik el (nincs új locale kulcs). Fontos, hogy ez a viselkedés-változás **csak** a "célpont volt a kurzor alatt, de túl messze" esetre vonatkozik — ha a kurzor alatt egyáltalán nincs entitás, a kód továbbra is a régi `shoot_at_position()` útvonalra esik (szabad tüzelés üres pozícióra, ami a precíz tüzelés gomb szándékolt, meglévő képessége, ezt nem érintettük).
- **Nem javított, rokon jelenség (későbbre halasztva)**: ugyanebben a fájlban, a `shooting_enemies` ág `does_auto_aim() == false` esetében (rakéta/atombomba) a kód szintén `shoot_at_selected()`-et hív egy `EntitySelection.get_first_ent_at_tile()`-lal talált célpontra, csak `force.is_enemy()` ellenőrzéssel, hatótáv-ellenőrzés nélkül — ugyanaz a hibaosztály, csak nem ezt jelentette a felhasználó. Ha ez is releváns (pl. az atombomba is túl messzire indítható), külön kör kell hozzá.
- **Nincs teendő a locale-fájllal** — tisztán Lua-módosítás, mentés-visszatöltés elég, NEM kell teljes újraindítás.

---

## 8g. `[SA-RESOURCE]` Resource kategória kiterjesztése Vulcanusra, Fulgorára, Glebára, Aquilóra

A felhasználó kérése: a Nauvis-on már meglévő minta (kövek — `big-rock`, `huge-rock` stb. — a scanner Resources kategóriájában jelennek meg, jelezve a játékosnak, hogy bányászhatók és értelmes craft-anyagot adnak) legyen kiterjesztve minden más bolygóra is, amin van ilyen entitás.

- **Forrás**: a hivatalos `wube/factorio-data` repó `space-age/prototypes/decorative/decoratives-{vulcanus,fulgora,gleba,aquilo}.lua` fájljainak közvetlen átvizsgálása — minden `minable = {...}` blokkal rendelkező entitás számít (a puszta dekorációk, pl. a legtöbb Gleba-i gomba/zuzmó, NEM bányászhatók, ezek kimaradtak).
- **Javítás**: `scripts/scanner/surface-scanner.lua`, `BACKEND_NAME_OVERRIDES` — új bejegyzések bolygónként, mind `SEB.Rock`-ra mutatva (ugyanaz a backend, mint a Nauvis-i köveknél):
  - **Vulcanus**: `big-volcanic-rock(-hot)`, `huge-volcanic-rock(-hot)` (kő+vas+réz+volfrámérc) + `vulcanus-chimney*` (5 változat — ezek névleg nem "rock", de adatszinten kőnek számítanak, kő+kén-t adnak).
  - **Fulgora**: `fulgoran-ruin-*` (7 méret-változat, roncsok — ócskavas+acéllemez+vasfogaskerék+vaspálca+rézkábel+kő), `fulgora-sunk-ruin-big`/`-medium-tall`, `fulgurite`/`fulgurite-small` (kő+holmiumérc).
  - **Gleba**: `copper-stromatolite`, `iron-stromatolite` — ez a két egyetlen bányászható, nem fa dekoráció a bolygón.
  - **Aquilo**: `lithium-iceberg-big`/`-huge` — ez a két egyetlen bányászható dekoráció a bolygón (jég+lítium).
- **`ephemeral_state_version` 14 → 15 emelve** — lásd 8e/6. kör: a már korábban bejárt/scannelt bolygórészeken lévő, korábban "Other"/"Terrain" alá dobott kő-entitások enélkül nem kerülnének át a Resources kategóriába, amíg meg nem semmisülnek — teljes állapot-visszaállítás szükséges, hogy azonnal, mentés-visszatöltés után helyesen jelenjenek meg.
- **Bizonytalanság/kockázat**: a fenti nevek a forráskódból közvetlenül lettek kiolvasva (nem találgatás), tehát magas a megbízhatóságuk — de értelemszerűen csak élesben, a felhasználó saját mentésén derül ki, hogy a scanner ténylegesen felismeri-e mindet (elgépelés vagy verzió-eltérés esetén az adott bejegyzés egyszerűen hatástalan marad, nem okoz hibát — ha valamelyik nem működik, jelezze, és pontosítjuk).
- **Nincs teendő a locale-fájllal** — tisztán Lua-módosítás, mentés-visszatöltés elég.

---

## 8h. `[NEM-KOD]` Deconstruction planner — állapotfelmérés (kutatás, kód nélkül)

A felhasználó kérésére áttekintés készült arról, mit tud ma a mod deconstruction planner UI-ja, és mit tud a vanilla játék. Nem történt kódváltoztatás — ez egy tervezési alapdokumentum, amiből a felhasználó választhat, mit érdemes bővíteni.

- **FA jelenlegi állapota** (`scripts/ui/planners/decon-planner-menu.lua`, `scripts/ui/selectors/decon-selector.lua`, `scripts/planner-utils.lua`, `scripts/player-mining-tools.lua`): terület-kijelölés (`[` / `]` gombok, Shift = törlés), 3 fület tartalmazó menü (Settings/Entity Filters/Tile Filters) — átnevezés, "csak fák és kövek" kapcsoló, `tile_selection_mode` (normal/always/never/only), "összes törlése", import/export string, entity- és tile-szűrők (whitelist/blacklist, max `entity_filter_count`/`tile_filter_count` slot), blueprint bookon belüli aktív planner is támogatott.
- ~~**Fontos hiányosság, amit a kutatás talált**: a decon planner menü egyetlen `fa.decon-*`/`fa.planner-*` locale kulcsa SINCS lefordítva sehol a `locale/en/` alatt~~ — **UTÓLAG CÁFOLVA, lásd a fájl végén az "Önkorrekció" bekezdést**: ez a kutató subagent téves állítása volt, a helyi (akkor hiányos) tükör miatt — a `locale/en/ui-decon-planner.cfg` a device-on végig létezett, teljes tartalommal. A decon planner lokalizációja rendben van, ez NEM hiányosság.
- **Vanilla-képességek, amik FA-ban jelenleg NEM érhetők el**: `skip_fog_of_war` kapcsoló (köd-alatti terület bevonása a törlésbe); `super_forced` kapcsoló (más force védett entitásainak kényszerített eltávolítása); külön `planner_description` mező (a rename attól függetlenül létező leírás-string); minőség-alapú (`quality` + `comparator`) entity-szűrés (Space Age); és nem világos, hogy a decon-műveletek be vannak-e kötve FA saját Ctrl+Z undo-rendszerébe (`undo_index` paraméter kihasználatlan).
- **Következő lépés**: ha a felhasználó szeretne ebből bármit bővíteni, érdemes a locale-hiánnyal kezdeni (gyors, nagy hatású), utána sorban a többivel nehézség szerint.

---

## 9. `[NEM-KOD]` A Claude Desktop app saját accessibility-problémája — NEM mod-kód, más téma

A JAWS-szal használt Claude Desktop app üzenetlistája virtualizált és rosszul viselkedik (oda-vissza scrollol, fókusz ugrál). Ez a **kliens alkalmazás saját hibája**, nem a FactorioAccess mod része, és nem is javítható ebből a sessionből (nem a mi kódunk). Azonosítva mint egy már ismert, nyitott GitHub-issue (#83167). Egy közösségi DevTools-alapú JavaScript workaround végig lett vezetve (developer_settings.json a helyes MSIX-virtualizált útvonalon + Ctrl+Alt+I + Ctrl+Shift+J + "allow pasting" + script beillesztés) — működik, de maradék hibákkal (üzenet-duplikáció, néhány üzenet nem jelenik meg amíg nem scrollozol). Anthropic hivatalos visszajelzési csatornája lett javasolva további vakon-patchelés helyett.

---

## 10. `[SKIP]` Egykattintásos API-dokumentáció frissítő script (`update_api_docs.py`, új fájl)

A felhasználó rákérdezett: van-e már kész script a helyi API-referencia (`llm-docs/api-reference/`) frissítésére a legfrissebb dokumentációval.

- **Kiderült: RÉSZBEN igen** — a mod gyökerében már létezik egy `json_to_markdown.py` (+ `README_json_to_markdown.md`), ami a Factorio JÁTÉK SAJÁT telepítésében szállított `doc-html/runtime-api.json`/`prototype-api.json` fájlokat konvertálja markdown-ná — ez hozta létre a jelenlegi `llm-docs/api-reference/`-t is, ami az `index.md` szerint **Factorio 2.0.73**-ra van datálva, tehát a jelenlegi 2.1.x alaphoz képest valóban elavult. **Fontos, korábbi félreértést korrigáló infó**: ezek a JSON dumpok NEM a webről töltendők le — minden Factorio-telepítéssel együtt szállítanak egy `doc-html/` mappát, ami mindig pontosan az adott telepített motorverziót tükrözi. Ez sokkal egyszerűbb, mint amit egy korábbi körben (a 3. eredeti témánál) feltételeztem, amikor a webes letöltést blokkolta a sandbox proxyja — itt szó sincs webes letöltésről, csak a helyi telepítésből kell a két JSON-t megkeresni.
- **Ami hiányzott**: a két többsoros parancs manuális begépelése, a `doc-html` elérési útjának megkeresése, és (a README saját ajánlása szerint) a régi generált fájlok külön törlése, ha azt akarjuk, hogy egy motorfrissítés által törölt API-tag `git diff`-ben törlésként jelenjen meg — ezt automatizálja az új `update_api_docs.py`.
- **Új script működése**: `--factorio-root` (alapértelmezetten ugyanaz a feltételezés, mint a már meglévő `launch_factorio.py`-é: `../..`, azaz hogy a mod mappa a Factorio-telepítés gyökerének közvetlen alkönyvtára), `--clean` kapcsoló (törli a régi `runtime`/`prototypes` alkönyvtárakat a kézzel írt `CLAUDE.md` érintetlenül hagyásával), és egy verzió-riport (a jelenlegi `llm-docs/api-reference/runtime/metadata.md` és az új JSON `application_version`/`api_version` mezőinek összevetése), mielőtt lefuttatja a már meglévő `json_to_markdown.py`-t mindkét (`runtime`, `prototype`) módban. Hibás/hiányzó `doc-html` esetén világos hibaüzenetet ad, konkrét példa-paranccsal.
- **Tesztelve**: szintetikus (üres, de valid) JSON fájlokkal egy elkülönített `/tmp`-es másolaton — a teljes pipeline (verzió-kiolvasás, `--clean`, mindkét konverzió lefuttatása, a metadata.md helyes megjelenése, majd egy második futtatásnál a helyes régi-verzió-kiolvasás) végigfutott hibátlanul.
- **FONTOS, amit a felhasználónak tudnia kell**: ez a session csak a `C:\Users\kovac\AppData\Roaming\Factorio` mappához fér hozzá (ez a szokásos Windows-os `%APPDATA%\Factorio` felhasználói adatmappa — mentések, mod-lista stb.), NEM a tényleges Factorio-telepítéshez (ahol a `bin/`, `data/`, `doc-html/` van — jellemzően a Steam-könyvtárban). A script tehát INNEN nem futtatható le közvetlenül általam — a felhasználónak kell lefuttatnia a saját gépén (a `python update_api_docs.py` parancsot a mod mappájából, esetleg `--factorio-root`-tal, ha a `../..` feltételezés nem talál rá a `doc-html`-re), vagy meg kell adnia a tényleges telepítési útvonalat, hogy azt a mappát is hozzáadhassa a session eléréséhez.
- **Nem érintett**: a `llm-docs/index.md` által hivatkozott, összevont felső szintű fájlok (`classes.md`, `concepts.md`, `runtime-api.md` stb.) — ezek egy korábbi sessionben kézzel lettek összeállítva, nincs hozzájuk automatikus generátor, ezt a script explicit jelzi is a kimenetében.
- **Nincs teendő a locale-fájllal** — tisztán Python dev-tooling script, nincs hatással a futó mod viselkedésére.

**Kiegészítés — felhasználói visszajelzés alapján bővítve**: a felhasználó jelezte, hogy a script ne csak a `../..` relatív feltevésre hagyatkozzon "halálra defaultolva", hanem nézze meg a szokásos Windows telepítési helyeket is, és ha többet is talál (elképzelhető, hogy valakinek van külön dev és játékos telepítése), kérdezzen rá, melyiket használja.

- **Javítás**: a script most 3 helyet néz meg sorban — (1) a `../..` relatív feltevés (ugyanaz, mint a `launch_factorio.py`-é, ez a legspecifikusabb találat erre a repóra), (2) `C:\Program Files\Factorio` (standalone/nem-Steam Windows-telepítő alapértelmezett célja), (3) `C:\Program Files (x86)\Steam\steamapps\common\Factorio` (Steam alapértelmezett). **Apró korrekció a felhasználó saját feltevéséhez képest**: a standalone Windows-telepítő NEM a `Program Files (x86)`, hanem a sima `Program Files\Factorio` mappába telepít alapból — ezt a hivatalos Factorio Wiki "Application directory" oldala erősíti meg, nem a `(x86)`-os változat.
- **Ha egynél több helyen is talál érvényes (mindkét JSON-t tartalmazó) `doc-html`-t**: interaktívan rákérdez, melyiket használja (számozott lista + `input()`), pont a "van dev és játékos verzió is" esetre. Ha a script történetesen NEM interaktív módban fut (pl. automatizálva, nincs valódi terminál), nem akad el örökre bemenetre várva — figyelmeztetéssel az első találatra esik vissza, és jelzi, hogy `--factorio-root`-tal felül lehet írni.
- **Tesztelve**: 4 különálló szintetikus forgatókönyvvel (egy segéd-python-harness-szel, ami monkey-patcheli a jelölt-listát, hogy ne kelljen valódi Windows-elérési utakat szimulálni ezen a Linux-sandboxon) — (1) egyik jelölt sem található, a hibaüzenet mindet felsorolja; (2) pontosan egy jelölt található, automatikusan azt választja; (3) két jelölt, nem-interaktív stdin (pl. átirányított bemenet), az elsőre esik vissza figyelmeztetéssel; (4) két jelölt, valódi tty-t szimulálva (`pty.fork()`), a felhasználó "2"-t ír be, és tényleg a második telepítést választja és azt dolgozza fel. Mind a 4 helyesen viselkedett.

---

## 11. `[MISC]` Remote view újra bekötve (Alt+I), J javítva hogy `physical_position`-t használjon, dokumentáció-frissesség ellenőrizve

Három összefüggő felhasználói kérés egy körben: (1) van-e még eltérés a lokális `llm-docs/api-reference/` és a hivatalos web-doksi között; (2) pontosan mit csinál a `J` gomb, van-e vanilla vagy csak mod-saját mód arra, hogy a remote view-ban egy "anchor pontot" letegyünk valahova; (3) kösse vissza a remote view toggle-t — Alt+I-re, vagy ha nem ütközik semmivel, inkább M-re (vanilla "toggle map" mintájára), de a Tab-ot ne bántsa (túl sokat használjuk a menükben).

### 1. Doksi-frissesség ellenőrzése

- A jelenleg generált `llm-docs/api-reference/runtime/metadata.md` és `prototypes/metadata.md` **Application Version: 2.1.19**-et mutat.
- A ténylegesen telepített/futó játék (`factorio-current.log` első sora): **Factorio 2.1.19 (build 87445, win64, steam, space-age)**, telepítési út: `C:\Program Files (x86)\Steam\steamapps\common\Factorio` — ez pontosan egyezik az előző körben az `update_api_docs.py`-hoz hardkódolt Steam-alapértelmezett jelölttel, tehát az a feltevés helyesnek bizonyult ezen a gépen.
- A hivatalos webes doksi (`lua-api.factorio.com/latest`) fejléce szintén **"Version 2.1.19"**-et mutat.
- **Mind a három egyezik — jelenleg NINCS eltérés.** A korábbi (előző körben tett) "2.0.73-ra van datálva" megállapításom téves volt: az a `llm-docs/api-reference/CLAUDE.md`/`index.md` kézzel írt, statikus PRÓZASZÖVEGÉBŐL jött (ami sosem frissül automatikusan), NEM a ténylegesen generált `metadata.md`-ből — utóbbi már végig 2.1.19-et mutatott. Ezt a korábbi félreértést itt tisztázom.
- **A felhasználó kérése szerint**: mostantól nyugodtan használható elsődleges forrásként a lokális `llm-docs/api-reference/`, webes ellenőrzés nélkül — amíg a fenti verziószámok nem térnek el egymástól (amit az `update_api_docs.py` mostantól minden futtatáskor kiír).

### 2. J ("Cursor returned") pontos működése — kód, majd API alapján

- **Kód szerint** (`control.lua`, `kb_jump_to_player`, a sima `J` gomb, nem a driving/menü-kontextusú túlterhelések): eddig `first_player.position`-t használta a kurzor cél-koordinátájaként.
- **API-kutatás (a friss, 2.1.19-es helyi doksiból)**: `LuaControl::position` ("The current position of the entity") remote view-ban a JELENLEGI TÁVOLI NÉZET pozícióját adja vissza, NEM a valódi karakterét — és mivel semmilyen kódunk nem mozgatja a vanilla remote-view kamerát a saját FA-kurzorunk mozgása után (ellenőrizve: `centered_on`/`set_controller` sehol nincs használva a mod egészében a mostani módosítás előtt), ez a mező remote view-ban gyakorlatilag "befagyva" marad ott, ahova a nézet belépéskor került — tehát J eddig nem a karakterhez, hanem ehhez a befagyott ponthoz ugrott volna vissza. Külön API-mező létezik erre pontosan: `LuaPlayer::physical_position` / `::physical_surface` — "The current position/surface of this player's PHYSICAL controller", ez mindig a valódi karakter (vagy isten-/szerkesztő-mód) tényleges helyét adja, remote view-tól függetlenül.
- **Javítás**: `kb_jump_to_player` mostantól `physical_position`/`physical_surface`-t használ. Ha épp remote view-ban vagyunk és az MÁS felületet mutat, mint ahol a fizikai karakter van, a függvény előbb átállítja a remote view-t a helyes felületre (`set_controller`), utána teszi rá a kurzort — így a J mindig "mutasd, hol vagyok ténylegesen" jelentésű marad, akkor is, ha épp egy másik bolygót/felületet nézegetünk távolról.

### 3. Van-e letehető "anchor pont"? — vanilla vs. már meglévő mod-funkció

- **Vanilla oldalon nincs ilyen "letehető visszatérési pont" koncepció** a karakteren/`physical_position`-ön kívül — a legközelebbi dolog a `LuaPlayer::centered_on` (egy ENTITÁSRA lehet központosítani a remote view-t, nem egy szabad koordinátára), ami nem alkalmas "tegyél le egy pontot a semmi közepén" használatra.
- **A jó hír: a modban ez MÁR LÉTEZIK**, csak nem a J-hez kötve — a `Shift+B` (`kb_s_b`, "Saved cursor bookmark at X, Y") elmenti az aktuális kurzorpozíciót, a sima `B` (`kb_b`) pedig visszaugrik rá. Ez pontosan az, amire a felhasználó aggódott, hogy esetleg hiányzik: egy vak játékos szabadon KIJELÖLHET egy tetszőleges pontot (nem kell hozzá kattintani semmire), és utána visszatérhet rá.
- **Valódi, ezúttal NEM javított hiányosság, amit a kutatás közben találtam**: a `cursor_bookmark` (`scripts/viewpoint.lua`) jelenleg NEM tárolja, melyik FELÜLETEN lett elmentve — csak egy sima x,y párt. Ha valaki Vulcanuson tesz le egy bookmarkot, majd remote view-val vagy utazással átvált Nauvisra, és ott nyomja meg a B-t, azt a Vulcanus-koordinátát fogja alkalmazni a Nauvis felületen — értelmetlen célpontra ugorva. Ez egy mélyebb, a teljes kurzor/viewpoint-rendszert érintő tervezési kérdés (maga a `cursor_pos` sem felület-címkézett jelenleg), ezért ebben a körben NEM nyúltam hozzá — ha a felhasználó szeretné, külön altémaként érdemes megtervezni és javítani, most hogy a remote view ismét aktívan használható lesz több felület között ugrálva.

### 4. Remote view visszakötve — Alt+I

- **M kizárva**: a sima `M` billentyű MÁR FOGLALT a modban (`fa-m`: általános UI "action1" kötés menükben + egy külön akció virtuális vonatvezetésnél) — a felhasználó saját feltétele szerint ("ha nem ütközik semmivel") ez kizárja az M-et.
- **Tab kizárva**: a felhasználó explicit kérésére nem nyúltunk hozzá (Tab/Shift+Tab a tab-list navigáció gerince szinte minden FA-menüben).
- **Megoldás: Alt+I**, ami már korábban is fenn volt tartva pontosan erre a célra (`fa-a-i`, a kód régi kommentje szerint: "remote view toggle, de a Factorio 2.0-ban jelenleg nem működik") — csak a handler évek óta üres stub volt. Most valódi funkcióval töltöttem fel: `LuaPlayer::set_controller{type = defines.controllers.remote, surface, position}` a belépéshez (mindig a fizikai pozícióra/felületre központosítva, hogy a FA-kurzor és a remote view kezdettől egyetértsen abban, hol vagyunk), `LuaPlayer::exit_remote_view()` a kilépéshez (ez a hivatalos API szerint mindig a helyes "fizikai" kontrollerre tér vissza — karakter, isten-mód, szerkesztő stb. —, nem feltételezi kifejezetten, hogy van karakter).
- **A `storage.players[pindex].remote_view` flag életre keltve**: ez a mező már régóta létezett és 6 helyen befolyásolta a hangeffektek lejátszási módját (világ-pozíció vs. játékos-relatív), de sosem lett `true`-ra állítva sehol — holt kód volt. Mostantól az Alt+I be- és kikapcsoláskor helyesen frissíti, tehát ez a 6 call site is életre kel.
- **Új locale-kulcsok** (`locale/en/control-messages.cfg`): `remote-view-entered`, `remote-view-exited`, `remote-view-exit-failed`. **Vezérlőlista-bejegyzés** (`locale/en/controls.cfg`): `fa-a-i=Toggle remote view (Alt+I)` (eddig egyáltalán nem szerepelt ott, mert a gomb funkciótlan volt).
- **FONTOS, nem tesztelhető innen**: ennek a sessionnek nincs futó Factorio-példánya — sem az Alt+I be/kilépés, sem a javított J viselkedés nem lett élesben kipróbálva. Mivel locale-fájl is változott, **teljes Factorio-újraindítás szükséges**.
- **Következő, opcionális lépés, amit FELVETETTEM, de nem indítottam el**: a `cursor_bookmark` felület-címkézése (lásd fentebb a 3. pontban) — szólj, ha szeretnéd, hogy ezt is megcsináljam.

---

## 12. `[MISC]` Rakétasiló "platform selector" crash — üres menü megnyitása, javítva (élesben talált hiba)

A felhasználó élesben (nem az előző körben tett módosításaimmal összefüggésben, tesztelés közben) egy non-recoverable crash-t kapott a rakétasiló-menüben:

```
Error while running event FactorioAccess::fa-leftbracket (ID 354)
__FactorioAccess__/scripts/ui/menu.lua:149: Menus must have at least one item
...
__FactorioAccess__/scripts/ui/tabs/rocket-silo-config.lua:153: in function <...>
```

- **Kivizsgálás**: a `rocket-silo-config.lua` "Launch item"/"Launch player" gombjai megnyitás előtt egy `force_has_platforms(entity.force)` ellenőrzést futtattak, ami CSAK azt nézte, hogy a force-nak van-e EGYÁLTALÁN bármilyen platformja (`next(force.platforms) ~= nil`). A ténylegesen megnyíló `platform-selector.lua` viszont ennél sokkal szigorúbb szűrést alkalmaz: a platformnak (1) kész hub-bal kell rendelkeznie, (2) éppen "parkolva" kell lennie (nem utazás közben), ÉS (3) ugyanazon a helyen (bolygó/pálya) kell lennie, mint a siló. Ha a force-nak VAN platformja, de az épp úton van vagy máshol parkol, az előzetes ellenőrzés hibásan "van elérhető platform"-ot mondott, a selector menü viszont emiatt NULLA opcióval épült fel — a `MenuBuilder:build()` pedig `assert(#self.rows > 0, "Menus must have at least one item")`-tel elszáll egy teljesen üres menün.
- **Javítás (két rétegben, defense-in-depth)**:
  1. **Gyökérok**: `platform-selector.lua`-ban kiemeltem egy közös `is_valid_destination(platform, silo_location)` predikátumot, amit MOST MÁR mindkét hely használ — a tényleges opciólistát építő `get_available_platforms` ÉS egy új, exportált `mod.has_available_platform(force, silo_surface)` függvény. A `rocket-silo-config.lua` mindkét call site-ja (`launch_item`, `launch_player`) a régi, pontatlan `force_has_platforms`-t erre cserélte — mivel most szó szerint ugyanazt a logikát futtatja mindkét hely, a két ellenőrzés soha többé nem térhet el egymástól.
  2. **Védőháló a megosztott komponensben**: `options-selector.lua` (amit a platform selectoron kívül még más választók is használnak, pl. vonat-csoportok, állomáslisták — a fájl saját megjegyzése szerint) mostantól `nil`-t ad vissza (ami a `key-graph.lua` `_rerender` logikája szerint egyszerűen, csendben bezárja a menüt), ha az opciólista üres, ahelyett hogy hagyná a `MenuBuilder:build()`-et elszállni. Ez egy utolsó védvonal ARRA az esetre, ha egy jövőbeli (vagy már meglévő, de még fel nem fedezett) hívó helytelenül vagy egyáltalán nem ellenőrzi előre az elérhetőséget — nem helyettesíti az 1. pontban leírt, konkrét beszélt hibaüzenetet adó előzetes ellenőrzést, csak biztosítja, hogy legrosszabb esetben is csendes bezárás történjen crash helyett.
- **Szintaxis-ellenőrizve** (`luac5.3 -p`, mindhárom fájl), kiküldve, device-ra mentve, byte-szám egyezés megerősítve.
- **NEM ellenőrizhető élesben** — nincs futó Factorio-példány ebben a sessionben. Kérünk visszajelzést, hogy a "Launch item"/"Launch player" gombok most már helyesen viselkednek-e olyankor, amikor van platformod, de az épp úton van vagy más bolygónál parkol (a beszélt "no platforms available" üzenetet kellene adnia crash helyett).
- **Nincs teendő a locale-fájllal** — tisztán Lua-módosítás, nem igényel újraindítást (csak mentés-visszatöltést).

---

## 13. `[MISC]` Remote view: "véletlenszerűen" hiányzó hangok — ok kiderítve, a mod-oldali rész javítva

A felhasználó jelezte: remote view-ban néha hallja, néha nem hallja a hangokat (konkrét példa: alatta megy a platform, de nem hallatszik a "sistergés"). Két, egymástól független kérdés volt benne — ez a pont csak az elsőt (a hang-inkonzisztenciát) fedi le, a második ("válassz látva remote célpontot") még nyitott, lásd alább.

- **Kivizsgálás, kódból**: `scripts/ui/sounds.lua` minden hangja végső soron `LuaPlayer::play_sound`-on vagy `LuaGameScript::play_sound`-on megy át, ha kap egy `position` mezőt. A friss (2.1.19) helyi API-doksi mindkettőnél explicit leírja: *"The sound is not played if its location is not charted for this player"* (`LuaPlayer.md`) / *"...for that player"* (`LuaGameScript.md`) — a "charted" pedig a `LuaForce::chart` szerint a térkép-felfedettséget jelenti (rádió/lövedék/karakter által valaha felfedezett terület), NEM a pillanatnyi kamera-láthatóságot.
- **A tényleges hiba**: `control.lua`-ban 6 helyen (kurzor-mozgatás "kattanás" hangja és a "wrap-around" hang) a kód remote view-ban a kurzor VILÁGKOORDINÁTÁJÁT adta át `position`-ként (`cursor_pos`), amíg nem-remote módban a JÁTÉKOS SAJÁT pozícióját (`p.position`). Ez a különbségtétel eddig ártalmatlan volt, mert a `storage.players[pindex].remote_view` flag holt kód volt (sosem lett `true`-ra állítva) — most, hogy a 11. pontban bekötött Alt+I miatt ÉLESBEN is bejárható a remote view, ez az ág most először fut le ténylegesen. A saját pozíciód szinte mindig charted (ott állsz), de a remote-view kurzor simán bejárhat még fel nem térképezett helyeket (frissen generált platform-padló, most felfedezett bolygórész) — ott a pozícióhoz kötött hang a doksi szerint egyszerűen NEM szólal meg. Ez pontosan "random hiányzó hang"-nak hangzik kívülről.
- Bónuszként a "wrap-around" hang remote view-s ága `sounds.play_sound_at_position` → `game.play_sound(spec)`-et hívott, ami a doksi szerint *"Play sound for **every player** in the game"* — tehát ha valaki más is charted ugyanoda, ő is hallotta volna a te kurzor-hangod. Ez sem szándékos.
- **Javítás** (`control.lua`, mind a 6 call site — sorok kb. 1139/1185/1542/1554/1565/1577): a remote view-s ágakban a `position` mezőt eltávolítottam — `sounds.play_building_placement(p.index, cursor_pos)` → `sounds.play_building_placement(p.index)` (pozíció nélkül a `play_sound_internal`/sima `player.play_sound(sound_spec)` ágra esik, ami NEM chart-függő), és `sounds.play_sound_at_position(..., cursor_pos)` (globális, minden játékosnak) → `sounds.play_sound(p.index, {...})` (csak neked, chart-függetlenül). Egy magyarázó kommentet is hagytam a kódban az első előfordulásnál. A nem-remote ágakat szándékosan NEM bántottam — azok working code, és a fenti "szinte mindig charted" érv miatt élesben nem is jelentkezett rajtuk hiba; ha mégis szeretnéd ugyanígy pozíció-függetlenre venni őket (pl. konzisztencia miatt), szólj.
- **Amit ez NEM magyaráz meg**: a konkrét "platform sistergés" hiányát valószínűleg csak részben — az inkább a VANILLA ambient-hang rendszer (FFF-396: proximity-alapú, "csak akkor szól, ha a játékos egy adott sugáron belül van" trigger-entitások, nem a mi kódunk hívja). Web-keresésben találtam több hivatalos fórum-bugreportot arra, hogy a remote view és a vanilla hangrendszer együttműködése jelenleg is ismerten pontatlan: pl. `[2.0.72] No Sound on remote view after switching from space to planet` (ugyanazon felületen belüli remote-view-váltás néha nem inicializálja újra a hangmotort — javítva 2.0.73-ban) és `[2.0.76] Nauvis sound and remote view is broken` (itt a dev válasza szerint egy hatalmas, ~32000 chunkos chart-hátralék blokkolta a hangokat, amíg le nem futott — direkt megerősítve, hogy a "charted" állapot a vanilla motor szintjén IS gátolja a hangot, nem csak a mi kódunkban). Ez a rész a motor saját, jelenleg is tökéletlen működése — nem tudjuk kódból javítani, csak a fenti mod-oldali részt.
- **Szintaxis-ellenőrizve** (`luac5.3 -p`), kiküldve, device-ra mentve.
- **NEM ellenőrizhető élesben** — nincs futó Factorio-példány ebben a sessionben. Visszajelzést kérünk, hogy a kurzor-mozgatás kattanás/wrap-around hangja most már MINDIG szól-e remote view-ban (a "platform sistergés" ambient hang esetleges további hiánya külön, vanilla-oldali kérdés marad).

Forrás (web-kutatás ehhez a ponthoz):
- [LuaPlayer::play_sound / LuaForce::chart dokumentáció](https://lua-api.factorio.com/latest/classes/LuaPlayer.html) (helyi tükör, 2.1.19)
- [AmbientSound surface binding - Factorio Forums](https://forums.factorio.com/131730)
- [Friday Facts #396 - Sound improvements in 2.0](https://www.factorio.com/blog/post/fff-396)
- [\[2.0.72\] No Sound on remote view after switching from space to planet](https://forums.factorio.com/viewtopic.php?p=685372)
- [\[2.0.76\] Nauvis sound and remote view is broken](https://forums.factorio.com/viewtopic.php?p=690787)

---

## 14. `[MISC]` Új "Platforms" szekció a világmenüben (Alt+W), a Trains mintájára — új fájl

A felhasználó kérése: a világmenübe (Alt+W) kerüljön egy "Platforms" szekció, ami ugyanúgy nézzen ki és viselkedjen, mint a meglévő "Trains" szekció — ez a pont CSAK ezt fedi le, a "válassz látva remote célpontot" rész (ld. 13. pont vége) szándékosan még nincs bekötve ide.

- **Új fájl: `scripts/ui/tabs/platforms-overview.lua`** — szó szerint a `trains-overview.lua` mintáját követi: soronként egy platform, három elemmel egy sorban —
  1. fő kattintható elem (név + jelenlegi hely/tranzit-állapot felolvasása, kattintásra bezárja a menüt és megnyitja a platform saját konfigurációs tabját — `EntityUi.open_entity_ui(pindex, platform.hub)`, ugyanaz a mechanizmus, mint a train-eknél a mozdony UI-jára),
  2. "Move cursor" — a kurzort a platform hub pozíciójára állítja (`Viewpoint:set_cursor_pos`), ugyanúgy, ahogy a train-eknél is,
  3. Manuális/automata mód checkbox (`platform.paused`), ugyanaz a fogalom, mint a `platform-config.lua`-ban már meglévő megfelelője.
- **Eltérés a Trains mintától, szándékosan**: a train-eknél két tab van ("Surface trains" / "All trains", mert egy vonat lehet több felületen is releváns a jelenlegi felületedhez képest) — platformnál ez a megkülönböztetés nem értelmezhető ugyanígy (egy platform MAGA egy felület), ezért itt csak EGY tab van: "All platforms", a force összes platformját listázva, névvel (majd hub `unit_number`-rel tie-break) rendezve.
- **Kihagyva, szándékosan**: a `get_help_metadata` (Ctrl+G-s súgó-üzenetlista) NEM lett bekötve ehhez az új taphoz — a `trains-overview.lua` ezt egy `locale/en/message-lists.cfg`-beli, gépileg generált `--meta=<base64>` kulcs-blokkal oldja meg (`scripts/message-lists.lua` szerint ezt futásidőben `player.request_translation`-nel olvassa vissza), aminek a pontos kódolását kézzel biztonságosan nem tudtam volna reprodukálni — inkább kihagytam, mint hogy egy rosszul kódolt meta-blokkal esetleg hibás állapotot hozzak létre. Ha szeretnéd, ezt külön körben, a helyes generáló mechanizmus kiderítése után pótolhatjuk.
- **Módosított fájlok**:
  - `scripts/ui/menus/world-menu.lua` — `require("scripts.ui.tabs.platforms-overview")` + egy új `"platforms"` szekció a `tabs_callback` szekciólistájában, közvetlenül a `"trains"` szekció után.
  - **Új locale fájl: `locale/en/ui-platforms-overview.cfg`** — az új tab feliratai (`platforms-overview-all-title`, `-no-platforms`, `-click-to-open`, `-move-cursor`, `-cursor-moved`, `-manual-mode`, `-error`) + `section-platforms=Platforms` a menü-szekció címéhez. A hely/állapot-szöveghez (`platform-at-location` / `platform-in-transit` / `platform-location-unknown`) a már meglévő `locale/en/ui-platform.cfg` kulcsait használja újra, nem duplikáltam őket.
- **Szintaxis-ellenőrizve** (`luac5.3 -p`, mindhárom Lua-fájl), kiküldve, device-ra mentve.
- **NEM ellenőrizhető élesben** — nincs futó Factorio-példány ebben a sessionben. Visszajelzést kérünk, hogy Alt+W-ben megjelenik-e a "Platforms" szekció, és hogy a lista/kattintás/kurzor/checkbox helyesen viselkedik-e.

---

## 15. `[MISC]` Új "Vehicles" szekció a világmenüben — tankok/kocsik remote view-ból is vezethetők (új fájl)

A felhasználó kérése: a tankok (és általában a kocsi-típusú járművek) vanillában vezethetők remote view-ból is — ez kerüljön be a világmenübe (Alt+W), surfacenként, hogy blind játékosként is elérhető legyen ez a funkció navigálás nélkül, kattintással.

- **API-oldali kutatás (először a kódból, utána kifelé, a felhasználó korábbi instrukciójának megfelelő sorrendben — itt a "jelenlegi driving-kód" volt az első lépés)**:
  - Átnéztem `scripts/driving.lua`-t és a teljes mod-ot: FA-ban jelenleg SEHOL nincs olyan kód, ami programozottan ültetne be valakit egy járműbe (`nincs .driving = `, `set_driving`, `get_driver`/`set_driver` hívás sehol) — a jelenlegi "beszállás" TISZTÁN a vanilla walk-up-and-press-E mechanikán megy, ami karakterhez (fizikai közelséghez) kötött, tehát remote view-ban eleve nem is működhetett volna eddig.
  - `scripts/vehicle-cycler.lua` (a meglévő "járművek ciklázása" funkció, Tab-hoz hasonló bejáráshoz) SZINTÉN karakter-alapú (`if not character then ... return end`, 100 tile-os körzet a fizikai karakter körül) — ez sem használható remote view-ból, más célra való (közeli járművek gyors bejárása, nem listázás/vezetés-indítás).
  - Friss (2.1.19) helyi API-doksi: `LuaEntity::set_driver(driver)` — beállítja egy jármű vezetőjét KÖZVETLENÜL, "in reach" / fizikai közelség megkötés NÉLKÜL (szemben a `LuaControl.driving` írásával / `LuaControl:set_driving()`-vel, ami a hagyományos "odasétálsz és E-t nyomsz" mechanikát tükrözi, tehát feltehetően reach-alapú). Ez pontosan az a mechanizmus, amire a vanilla saját 2.0+ "remote driving" funkciója is épül (remote view-ban rákattintasz egy járműre és vezeted, fizikai jelenlét nélkül).
  - Web-kutatással megerősítve (hivatalos fórum-bugreportok): a `set_driver` CSAK akkor működik, ha a jármű UGYANAZON a felületen van, mint a játékos jelenlegi controllere (fizikai vagy remote kamera) — felületek között hívva hibát dob (2.0.55-ös motor-javítás explicit ezt rögzítette: *"calling set_driver in cases which would cause character to change surfaces is not supported and should throw an error"*). Egy korábbi bugreport pont ezt a hiányzó szinkronizációt írta le tünetként (*"you will be driving the tank, but your camera will still be on Fulgora"*), ami egyben azt is megerősíti, hogy sikeres `set_driver` után a játékos ténylegesen "beköltözik" a járműbe (a controllere a jármű helyére/felületére vált), nem csak vezérli távolról.
- **Új fájl: `scripts/ui/tabs/vehicles-overview.lua`** — a `trains-overview.lua` mintáját követi (két tab: "Surface vehicles" a jelenlegi fizikai felületre, "All vehicles" az összes felületre — ez alkalommal TÉNYLEGESEN mindkettő be van kötve a világmenübe, mert a felhasználó explicit "surfacenként"-et kért; megjegyzem, hogy a Trains szekciónál a meglévő `surface_trains_tab` valójában sosem volt eddig sehova bekötve, csak az `all_trains_tab` — ezt nem bántottam, külön téma). Kör: `entity.type == "car"` (ez vanillában MIND a sima autót, MIND a tankot lefedi, mivel mindkettő ugyanaz a prototípus-típus) — a `force`-hoz tartozó összes ilyen entitást listázza, felület(ek)ről a `surface.find_entities_filtered({type="car", force=force})`-al gyűjtve (több felület esetén `game.surfaces`-en végigmenve, a `scripts/electrical.lua`/`surface-scanner.lua`-ban is használt mintát követve).
  - **Szándékosan KIMARADT: spidertron** (`type = "spider-vehicle"`) — a spidertronnak már van saját, sokkal gazdagabb vanilla remote-vezérlő rendszere (spidertron remote item: útvonalpontok, "follow", automata célzás), ezt idekeverni redundáns/zavaró lett volna. Ha szeretnéd, ennek is csinálhatok egy hasonló, de a spidertron saját rendszeréhez illeszkedő bejegyzést külön kérésre.
  - **Soronkénti felépítés**: (1) fő kattintható elem — név (`Localising.get_localised_name_with_fallback`, ugyanaz a helper, amit a `vehicle-cycler.lua` is használ), pozíció, "foglalt" jelzés ha már van vezetője, kattintásra megnyitja a jármű saját (meglévő, generikus) entity UI-ját, mint a train-eknél; (2) **"Drive" akció** — ez az új, kért funkció: `drive_vehicle(pindex, vehicle)` ellenőrzi, hogy nem ugyanazt vezeted-e már, nincs-e már más vezetője (ha van, beszélt hibaüzenet, NEM lökjük ki erőszakkal a másik vezetőt), majd ha a jármű felülete eltér a jelenlegi controlleredétől, előbb `set_controller{type=remote, surface=jármű_felülete, position=jármű_pozíciója}`-val átvált oda (ugyanaz a minta, mint az Alt+I-nél), végül `vehicle.set_driver(player)`. Sikeres belülésnél `storage.players[pindex].remote_view = false`-ra állítom (hiszen már ténylegesen "ott vagy", nem remote-nézel), és szinkronizálom a kurzort/grafikát a jármű pozíciójára — ugyanaz a lezáró lépéssor, amit az Alt+I kilépés-ága is használ.
- **Új locale fájl: `locale/en/ui-vehicles-overview.cfg`** — az új tabok/akciók feliratai + `section-vehicles=Vehicles`.
- **Módosított fájl**: `scripts/ui/menus/world-menu.lua` — `require("scripts.ui.tabs.vehicles-overview")` + egy új `"vehicles"` szekció (mindkét taböal: surface + all) a `"platforms"` szekció után.
- **Szintaxis-ellenőrizve** (`luac5.3 -p`, mindhárom Lua-fájl), kiküldve, device-ra mentve.
- **NEM ellenőrizhető élesben** — nincs futó Factorio-példány ebben a sessionben, és ez a funkció (`set_driver` remote view-ból) a legkockázatosabb az eddigi live-teszt nélküli változtatások közül, mivel a felület-váltásos ág pontosan olyan élethelyzetet fed le, amiben a hivatkozott 2.0.41-es motor-hiba is jelentkezett (mielőtt 2.0.55-ben javították) — FONTOS visszajelzést kérünk, hogy (a) egyfelületes esetben (ugyanazon a bolygón vagy már ott állva) a "Drive" tisztán működik-e, (b) többfelületes esetben (pl. remote view-ban vagy egy másik bolygón vagy platformon állva választasz egy másik felületen lévő tankot) a kamera/karakter tényleg helyesen átvált-e a jármű felületére és nem marad-e szinkronban valamelyik a régi helyén.

Forrás (web-kutatás ehhez a ponthoz):
- [LuaEntity::set_driver / get_driver dokumentáció](https://lua-api.factorio.com/latest/classes/LuaEntity.html) (helyi tükör, 2.1.19)
- [\[Lou\]\[2.0.41\] Issues with scripting and remote driving](https://forums.factorio.com/viewtopic.php?p=666415)
- [How to "activate" tank or spidertron in remote view? - Factorio Forums](https://forums.factorio.com/viewtopic.php?p=658560&t=125841)

---

## 16. `[MISC]` Driving-teleport javítva (reach-alapú döntés) + nyilak/surface-váltás ütközés javítva (config.ini-n keresztül)

A felhasználó élesben tesztelte a 15. pontban épített "Drive" gombot, és két problémát talált. Ez a pont mindkettőt kezeli — mindkettő meg lett oldva, bár a másodikat végül nem a mod kódja, hanem egy közvetlen `config.ini`-szerkesztés oldotta meg (részletek lent, b) alpont).

### a) Driving-teleport — JAVÍTVA

**Jelentett hiba**: ha ugyanazon a felületen váltasz vezetésre, a karakter láthatóan be- és kiteleportál. Ennek oka: a `drive_vehicle` korábban a FELÜLET-egyezés alapján döntött, mikor váltson remote view-ba — ha a jármű már a jelenlegi felületeden volt, egyenesen `vehicle.set_driver(player)`-t hívott egy FIZIKAILAG BEÁGYAZOTT (`controller_type == character`) állapotból. A motor ilyenkor TÉNYLEGESEN átteleportálja a fizikai karaktert a jármű ülésébe (majd kiszálláskor vissza) — pontosan úgy, mintha odasétáltál volna, csak reach-ellenőrzés nélkül, ami korábban (a "walk up and press enter" mechanikában) ezt megakadályozta volna nagy távolságra.

**A valódi "remote driving" (teleportálás nélkül) csak akkor történik**, ha a `set_driver` hívás pillanatában a játékos MÁR remote view-ban van (`controller_type == remote`), a kamerája a járműre központosítva — ekkor a fizikai karakter a helyén marad, csak az irányítás kerül át a járműre.

**Javítás** (`scripts/ui/tabs/vehicles-overview.lua`, `drive_vehicle`): a döntési pont mostantól nem a felület-egyezés, hanem a **reach** — ugyanaz a `player.can_reach_entity(vehicle)`, amit az `entity-access.lua` is használ mindenhol máshol a modban (konzisztens a többi entitás-elérési döntéssel). Ha reach-en belül van a jármű → egyenesen `set_driver` (ez lényegében ugyanaz, mint amit egy odasétáló látó játékos is kapna). Ha reach-en KÍVÜL van (akár ugyanazon a felületen, akár máson) → előbb mindig `set_controller{type=remote, surface=jármű felülete, position=jármű pozíciója}`-val remote view-ba állítjuk a játékost a jármű helyére, és CSAK utána hívjuk a `set_driver`-t — így a fizikai karakter sosem mozdul.
- **Szintaxis-ellenőrizve** (`luac5.3 -p`), kiküldve, device-ra mentve.
- **NEM ellenőrizhető élesben.** Kérünk visszajelzést mindkét esetre: (1) közelről (reach-en belülről) a Drive most is olyan gyors/egyszerű-e, mint eddig volt reach-es esetben; (2) távolról (ugyanazon a felületen, de messze, ÉS más felületen) most tényleg NEM teleportál-e a fizikai karakter, csak a nézet vált remote-ra.

### b) Nyilak vs. surface-váltás ütközés vezetés közben — JAVÍTVA (a mod nem tudta, de a valódi helyen igen — lásd lent)

**Jelentett hiba**: vezetés közben a nyilak (fel/le) surface-et váltanak ahelyett, hogy a járművet irányítanák.

**Kivizsgálás (web-kutatás)**: ez NEM az FA kódja — vanilla, hardcode-olt alapértelmezés: remote view-ban (`controller_type == remote`) az Up = "Select previous surface", Down = "Select next surface" (valódi, névvel is azonosítható vanilla control: `next-surface`/`previous-surface`, megerősítve a helyi API-doksi `LinkedGameControl` enum-jában). A jármű-vezetés vanilla alap "steering mode"-ja UGYANEZT a két billentyűt használja (Up/Down = gáz/fék, Left/Right = kormány) — vagyis a motor szintjén a két funkció osztozik a billentyűkészleten, és ez egy ISMERT vanilla probléma (más játékos is pont ugyanezt jelentette egy Steam-fórumon: remote view-ból építve W/S-re ugrál a surface-lista; a vanilla-oldali "megoldás" csak a kézi átbillentyűzés Beállításokban).

**Választott irány (a felhasználó explicit "C" opciót választotta)**: a `next-surface`/`previous-surface` vanilla control alapértelmezett billentyűjét ÁTKÖTJÜK egy modifieres kombóra (ugyanaz a technika, mint amit a `toggle-driving`/`rotate` esetében az `input.lua` már használ — `linked_game_control`), Up/Down pedig örökre felszabadul vezetéshez (és bármi máshoz).

**Kombó-választás**: a felhasználó Ctrl vagy Shift+Ctrl variánst kért, "közel maradva" a nyilakhoz. Átnéztem az `input.lua`-t: **sima Shift+nyíl MÁR foglalt** (`fa-s-up/down/left/right` — épület "nudge"/igazítás), **sima Ctrl+nyíl is MÁR foglalt** (`fa-c-up/down/left/right` — a JÁTÉKOS SAJÁT karakterének egy mezővel odébb-teleportálása, ami érdekes módon már most is vezetés-tudatos: `if p.vehicle then ... return end`). Szabad maradt: **Ctrl+Shift+nyíl** — ezt sem az FA (csak Ctrl+Shift+W/A/S/D foglalt, ami más fizikai billentyű), sem — a fellelhető dokumentáció szerint — a vanilla alapértelmezés nem használja (ez utóbbit nem sikerült 100%-osan megerősíteni írott forrásból, élesben érdemes lesz ellenőrizni).

**A felhasználó jóváhagyta a Ctrl+Shift+nyíl kombót** ("oké, mehet a ctrl shift nyíl"), ezért mostantól: **Ctrl+Shift+Up = előző felület**, **Ctrl+Shift+Down = következő felület**.

**Megvalósítás** — ÚJ, eddig innen kimaradt fájl: `data-updates.lua` (a mod root-jában; a data-stage három fájlja közül ez az, ami már meglévő, MÁS modok/az alapjáték által definiált prototípusokat módosít — pont ez kell ide, hiszen a `next-surface`/`previous-surface` az alapjáték saját, előre definiált `custom-input` prototípusa, nem a miénk). A blokk:
```lua
if data.raw["custom-input"]["previous-surface"] then
   data.raw["custom-input"]["previous-surface"].key_sequence = "CONTROL + SHIFT + UP"
else
   log("FactorioAccess: expected vanilla custom-input 'previous-surface' not found - ...")
end
if data.raw["custom-input"]["next-surface"] then
   data.raw["custom-input"]["next-surface"].key_sequence = "CONTROL + SHIFT + DOWN"
else
   log("FactorioAccess: expected vanilla custom-input 'next-surface' not found - ...")
end
```
A `data.raw["custom-input"][...]` közvetlen módosítás UGYANAZ a technika, amit a fájl már korábban is használt más prototípusokra (pl. `data.raw.character.character.has_belt_immunity`, `data.raw[ent_type]` collision-módosítások) — csak most először a `custom-input` prototípus-táblára alkalmazva. Defenzíven `log()`-ol, ha a várt prototípusnév mégsem létezik (ez esetben az Up/Down továbbra is ütközne, de legalább a `factorio-current.log`-ban látszana, hogy miért).
- **Szintaxis-ellenőrizve** (`luac5.3 -p`), kiküldve, device-ra mentve.

**Kiegészítés — a felhasználó jelezte, hogy ez élesben NEM működött, a probléma kivizsgálva és a helytelen feltevés javítva:**

A `factorio-current.log`-ot lekérve pontosan az látszott, amit a defenzív `log()` hívás előre jelzett — mindkét lekérdezés a "not found" ágra futott:
```
23.598 Script @__FactorioAccess__/data-updates.lua:72: FactorioAccess: expected vanilla custom-input 'previous-surface' not found - ...
23.598 Script @__FactorioAccess__/data-updates.lua:77: FactorioAccess: expected vanilla custom-input 'next-surface' not found - ...
```
Vagyis a `data.raw["custom-input"]["previous-surface"]`/`["next-surface"]` kulcsok alatt NINCS ilyen prototípus — a feltevésem, hogy a `LinkedGameControl` enum-ban szereplő nevek (`next-surface`, `previous-surface`) egyúttal tényleges, szerkeszthető `data.raw["custom-input"]` bejegyzések nevei is, TÉVES volt.

**A helyes magyarázat** (megerősítve a hivatalos API-doksi `LinkedGameControl` oldaláról): ezek a beépített vanilla control-ok (`next-surface`, `previous-surface`, és a többi, a `LinkedGameControl` enum-ban felsorolt név, pl. `move-up` is) **motor-szinten hardkódolt alapértelmezett billentyűkötések, NEM adat-vezérelt `custom-input` prototípusok**. A `linked_game_control` mező csak arra való, hogy egy MOD saját, ÚJ, saját néven és billentyűn definiált `custom-input`-ja — ha megnyomják — TOVÁBBÍTVA kiváltsa a megadott beépített control akcióját (ahogy a fájlban már meglévő `toggle-driving`/`rotate`-hoz kötött bejegyzések is teszik). Ez egy EGYIRÁNYÚ "triggerelés" — nem teszi lehetővé, hogy felülírjuk vagy újradefiniáljuk magát a beépített control ALAPÉRTELMEZETT billentyűjét. Vagyis `data.raw` szerkesztéssel ez a fajta control egyáltalán NEM köthető át — sem ez, sem semmilyen más data-stage trükk nem tudja megváltoztatni, hogy alapból mi van az Up/Down-ra kötve.

**Ez azt jelenti, hogy a mod-oldali (data-stage Lua-s) automatikus megoldás NEM lehetséges** ezzel a megközelítéssel. A `data-updates.lua`-ból a nem-működő blokkot eltávolítottam, és a helyén egy végleges, magyarázó kommentet hagytam (hogy később ne próbálja meg újra ugyanezt bárki, és a teljes indoklás megmaradjon a kódban is, ne csak a changelogban) — kiküldve, device-ra mentve, `luac5.3 -p`-vel szintaxis-ellenőrizve.

**A felhasználó rámutatott, hogy ez mégsem lehet a teljes igazság** ("de nézd meg. Escape is átvan mdodolva, talán még az e is, tstb.") — vagyis a `toggle-menu` (Escape) az ő telepítésén már át volt kötve Shift+Escape-re, ami azt sugallta, hogy a beépített control-ok MÉGIS átköthetők valahogy. Egy szélesebb diagnosztikai dump-pal (`data-updates.lua`-ban ideiglenesen, `factorio-current.log`-ból ellenőrizve) megerősítettem, hogy ez a jelenség NEM cáfolja az előző következtetést: `toggle-menu`, `toggle-driving`, `confirm-gui`, `build`, `mine` — egyik SEM `data.raw["custom-input"]` bejegyzés, ugyanúgy, mint a `next-surface`/`previous-surface`. Vagyis a teljes beépített vanilla control-lista (a `LinkedGameControl` enum egésze) a `data.raw`-on KÍVÜL él — de az Escape mégis át volt kötve valahol, csak nem a moddon keresztül.

**A valódi hely, ahol ez lakik: Factorio saját `config.ini` fájlja** (`C:\Users\kovac\AppData\Roaming\Factorio\config\config.ini` — ezt maga a felhasználó mutatta meg). Ennek van egy `[controls]` szekciója, ami egyszerű `control-name=BILLENTYŰ` sorokban tárolja AZOKAT a control-okat, amiket valaha testre szabtak (nem egy teljes lista minden control-ról — csak azoké, amiket ténylegesen módosítottak). Itt volt már egy `toggle-menu=SHIFT + ESCAPE` sor (egy korábbi, ehhez a munkához nem kapcsolódó testreszabásból) — ez magyarázza a felhasználó megfigyelését. A `next-surface`/`previous-surface` viszont NEM szerepelt itt (soha nem lettek testre szabva, az implicit alapértelmezést használták) — de egy új sor felvétele ide PONTOSAN ugyanazt csinálja, mintha kézzel átállítanánk a Settings → Controls menüben.

**A javítás ezért közvetlenül a `config.ini`-be került** (a felhasználó jóváhagyásával: "hajrá, csinálhatod"), a `[controls]` szekcióba, a `move-right=RIGHT` sor után beszúrva:
```ini
next-surface=CONTROL + SHIFT + DOWN
previous-surface=CONTROL + SHIFT + UP
```
Ez a fájl a **mod könyvtárán KÍVÜL** van (a Factorio Roaming-gyökerén), ezért ezt a mod saját data-stage vagy control-stage kódja SOHA nem tudta volna automatikusan elvégezni — csak közvetlen fájlrendszer-hozzáféréssel volt elvégezhető, egyszeri, ezen a telepítésen történő beavatkozásként (analóg azzal, mintha a felhasználó kézzel állította volna át Settings → Controlsban). A fájlt a felhasználó előbb bezárt Factorióval szerkesztettem (hogy a játék kilépéskor ne írja felül a szerkesztést a saját memóriabeli állapotával), majd a módosított fájlt visszamentettem a device-ra (mtime-guard-dal ellenőrizve, hogy közben más nem nyúlt hozzá).

**Ellenőrzés még hátravan**: a felhasználónak újra kell indítania a Factoriót (a config.ini, hasonlóan a data-stage módosításokhoz, feltehetően csak induláskor töltődik be), és meg kell néznie: (1) Settings → Controls alatt "Select previous surface"/"Select next surface" most Ctrl+Shift+Up/Ctrl+Shift+Down-ra van-e állítva; (2) vezetés közben tényleg megszűnt-e az Up/Down ütközés; (3) hogy a config.ini-s módosítás túléli-e a normál Factorio-kilépést (nincs teljesen kizárva, hogy a motor a legközelebbi bezáráskor felülírja, ha az aktuális memóriabeli állapot nem tartalmazza még ezt a két új kulcsot — ezt csak élesben lehet megerősíteni).

**Ismert, egyelőre külön nem kezelt szélső eset (a felhasználó jelezte, explicit kérésre később)**: ha valamilyen Factorio-launcher a config.ini-t újragenerálja/felülírja verzióváltáskor, ez a testreszabás elveszhet — ezt csak akkor vizsgáljuk, ha ténylegesen felmerül.

Forrás (web-kutatás ehhez a ponthoz):
- [\[Twinsen\]\[2.0.10\] Remapping hotkey for Select next/previous surface does not always prevent arrow keys from working](https://forums.factorio.com/viewtopic.php?t=117188)
- [Keyboard operation during remote view - Steam Community](https://steamcommunity.com/app/427520/discussions/2/715609860235909036/)
- `LinkedGameControl` concept (helyi API-doksi, 2.1.19) — a `next-surface`/`previous-surface` érvényes control-nevek listája
- [LinkedGameControl - Prototype Docs](https://lua-api.factorio.com/latest/types/LinkedGameControl.html) — explicit megerősítés, hogy ezek a control-ok NEM data.raw-ból szerkeszthető prototípusok, csak trigger-célpontok
- élő diagnosztikai `log()` dump (`data-updates.lua`, ideiglenes) + `factorio-current.log` — megerősítette, hogy `toggle-menu`/`toggle-driving`/`confirm-gui`/`build`/`mine` sem `data.raw["custom-input"]` bejegyzés
- `config.ini` (`Roaming/Factorio/config/config.ini`) `[controls]` szekciója — a felhasználó saját fájlja, közvetlenül megvizsgálva és szerkesztve

---

## 17. `[MISC]` Élesben tesztelve: surface-váltás OK, de a jármű mégsem mozdult — `player.driving` javítás + J kontextus-függővé téve

A felhasználó élesben visszajelzett a 16. pontra: **a Ctrl+Shift+Up/Down surface-váltás fix működik** ("legalább elváltogatni már nem váltogat, haladunk") — ez megerősíti, hogy a `config.ini` szerkesztés valóban túlélte az újraindítást és él. Két új probléma került elő ugyanabból a tesztből:

### a) Remote vezetés közben a nyilak "csinálnak valamit", de a tank nem mozdul — JAVÍTVA

**Jelentett hiba**: "fel-le működget. De nem mozdul a tank." — vezetés közben (a 15/16a. pontban épített Drive gombbal, reach-en kívülről, tehát a remote-driving ágon) az Up/Down nyilak regisztrálnak valamit, de a jármű fizikailag nem halad.

**Kivizsgálás**: a `drive_vehicle` (16a. pont) eddig kizárólag `vehicle.set_driver(player)`-re támaszkodott a vezetés "bekapcsolásához". Ez viszont — a hivatalos API-doksi szerint (`LuaControl` osztály) — csak azt dönti el, KI ülhet be a vezetőülésbe; azt, hogy a mozgás-billentyűk ténylegesen a járművet kormányozzák-e (vagyis hogy a `driving` irányítás ténylegesen AKTÍV-e), egy KÜLÖN, írható-olvasható mező dönti el: **`LuaControl.driving`** ("true, ha a játékos egy járműben van/vezet — beállítása bekapcsolja/kikapcsolja a vezetést"). Ezt a mezőt a modban MÁR MÁSHOL is a vezetés valódi jelzőjeként kezelik (a `K` gomb koordináta-felolvasója: `if game.get_player(pindex).driving and ... .vehicle ~= nil then` — csak akkor mondja be a sebességet/irányt, ha `driving` igaz). A `set_driver` hívás fizikailag beült állapotban (reach-en belül, a "walk up and press enter" analóg esetben) feltehetően magával hozza ezt is a motor részéről, de **script-alapú, remote-view-ból történő hozzárendelésnél ez nem garantált** — és élesben ki is derült, hogy nem is történt meg.

**Javítás** (`scripts/ui/tabs/vehicles-overview.lua`, `drive_vehicle`): a `vehicle.set_driver(player)` hívás UTÁN most explicit módon is beállítjuk: `if player.vehicle == vehicle and not player.driving then player.driving = true end`. A sikeresség-ellenőrzés is bővült: eddig csak `player.vehicle == vehicle`-t néztünk, mostantól `player.driving`-ot IS megköveteljük a "vezetés elindult" üzenet előtt.

**Extra, ezzel egy menetben**: mivel ez a hiba pont a "miért nem mozdul" kérdés köré épült, hozzáadtam egy olcsó, hasznos kiegészítő ellenőrzést is — ha a jármű üzemanyag-inventoryja üres (`vehicle.get_fuel_inventory()` és `is_empty()`), a "Now driving X" üzenet helyett egy külön, "...de nincs üzemanyaga" változat szól, hogy ez a triviális ok is azonnal kiderüljön, ne kelljen újra végigmenni ezen a nyomozáson egy egyszerű üres tank miatt. Új locale kulcs: `vehicles-overview-driving-started-no-fuel`.

- **Szintaxis-ellenőrizve** (`luac5.3 -p`), kiküldve, device-ra mentve.
- **NEM ellenőrizhető élesben.** Kérünk visszajelzést: most már mozog-e a tank remote vezetéskor.

Forrás:
- `LuaControl.driving` és `LuaControl.riding_state` dokumentáció (helyi API-doksi, `classes/LuaControl.html`) — `driving`: "true if the player is in a vehicle", írható-olvasható, beállítása be-/kilépteti a vezetésből.
- [\[Lou\]\[2.0.41\] Issues with scripting and remote driving](https://forums.factorio.com/viewtopic.php?p=666415) — 2.0.55-ös motorjavítás: `set_driver` mostantól automatikusan a járműhöz igazítja a controller pozícióját/felületét, de ez nem ugyanaz, mint a `driving` mező aktiválása.
- ["Remote Drive" mod leírása](https://mods.factorio.com/mod/remote-drive) — megerősíti, hogy a tank/spidertron "drive remotely" natívan, mod nélkül is működik vanillában (tehát a mechanika alapból elérhető, a mi hibánk volt hiányos).

### b) J vezetés közben a járműre ugorjon, ne a (távoli, mozdulatlan) fizikai testre — JAVÍTVA

**Jelentett igény**: "ami zavaró a vezetés közben j a járműre kéne hogy ugorjon. Meg amúgy j ugorjon remoteben az anchorpontra." — vagyis: NORMÁL esetben (nem vezetés közben) a J viselkedése (a fizikai pozícióra/"anchorpontra" ugrás) marad, ahogy eddig is volt, ez jó; DE vezetés közben a J célja legyen maga a jármű, ne a fizikai test — pont azért, mert remote vezetésnél a fizikai test messze, mozdulatlanul áll, miközben a jármű halad, és a kurzor semmi mást nem követi automatikusan menet közben.

**Javítás** (`control.lua`, `kb_jump_to_player`): a célpont (pozíció + felület) kiválasztása mostantól feltételes — ha `p.vehicle` létezik (a játékos éppen vezet, akár fizikailag, akár remote-ban), a cél a JÁRMŰ aktuális pozíciója/felülete; egyébként (nem vezet) a cél változatlanul a `physical_position`/`physical_surface`. Ez egyúttal azt is megoldja, hogy vezetés közben a J-vel folyamatosan újra lehet centrálni a kurzort a (mozgó!) járműre, mivel eddig semmi más nem tartotta követve a kurzort menet közben.

- **Szintaxis-ellenőrizve** (`luac5.3 -p`), kiküldve, device-ra mentve.
- **NEM ellenőrizhető élesben.** Kérünk visszajelzést mindkét esetre: (1) vezetés közben J a járműre ugrik-e; (2) nem-vezetés közben J viselkedése változatlan-e (a fizikai pozícióra ugrik, ahogy eddig).

---

## 18. `[MISC]` Vezetés közben kitankolt a hallható zónából — a radar/térbeli hangok referenciapontja mostantól követi a járművet

A felhasználó élesben visszaigazolta a 17. pontot: **a tank most már mozog remote vezetéskor** ("megy mint a golyó") — ezzel a `player.driving` javítás megerősítve működik. Új, ebből fakadó észrevétel: *"a tank kitankolt a hallható zónából... azért hallanám a környezetét"* — vezetés közben (főleg gyors, remote vezetésnél) az ellenség-/spawner-radar és a többi térbeli (pan/hangerő) hang elmarad, mert a hangforrás "hallgatói pozíciója" nem követi a járművet.

**Kivizsgálás**: a mod saját, vanilla-tól FÜGGETLEN térbeli hangrendszere (`scripts/sound-model.lua`, `LauncherAudio`-ra épülő szintetizált hangok — NEM a vanilla ambient-hangmotor, amiről a 13. pontban kiderült, hogy szándékosan a fizikai pozícióhoz van kötve és kódból nem mozdítható) egy közös `SoundModel.get_reference_position(pindex)` függvényt használ "honnan hallgatunk" kérdésre — ezt hívja az `enemy-radar.lua`, a `spawner-radar.lua`, a `grid-sonifier.lua` és a `zoom.lua` is. Ennek két módja van (`CURSOR` — alapértelmezett, vagy `CHARACTER` — pl. combat módban automatikusan bekapcsol), de **vezetésre eddig sehol nem volt eset**:
- `CHARACTER` módban a `player.character.position`-t adja vissza — ez remote vezetésnél a HELYBEN ÁLLÓ fizikai testet jelenti, ami sosem mozdul, miközben a jármű elszáguld mellőle.
- `CURSOR` módban (az alapértelmezett) a kurzor pozícióját adja vissza — ezt a 16a/17a. pont Drive-indításkor egyszer szinkronizálja a jármű helyére, és a 17b. pont J-vel is frissíthető, de FOLYAMATOS, tick-енkénti követés semmi nem biztosította eddig — egy gyors tank simán "lehagyja" a kurzort, ha nem nyomogatod közben a J-t.

**Javítás** (`scripts/sound-model.lua`, `get_reference_position`): új, mindkét módnál ELSŐBBSÉGET élvező ág — ha a játékos éppen vezet (`player.driving` és `player.vehicle` érvényes, akár fizikailag beülve, akár remote-ban, lásd 17a. pont), a referenciapont MINDIG a jármű aktuális pozíciója, függetlenül a cursor/character beállítástól. Ez egyetlen, központi helyen javítja az összeset, ami ezt a függvényt használja — `enemy-radar`/`spawner-radar` (kik/mik vannak közel a járműhöz, mely irányban) és a `grid-sonifier`/`zoom` is automatikusan a jármű köré igazodik, tick-ről tick-re, vezetés közben, anélkül hogy bármelyik sonifiert egyenként kellett volna módosítani.

- **Szintaxis-ellenőrizve** (`luac5.3 -p`), kiküldve, device-ra mentve.
- **Fontos, tudatosan NEM javított rész**: a vanilla saját ambient-hangmotorja (gépzúgás, "platform sistergés" stb., FFF-396) ettől függetlenül továbbra is a fizikai pozícióhoz van kötve — ez a 13. pontban már dokumentált, motor-szintű, kódból nem befolyásolható korlát, ezt a fix nem (és nem is tudja) érinteni. Ami itt javult, az kizárólag a MOD SAJÁT (LauncherAudio-alapú) radar-/térbeli hangjai.
- **NEM ellenőrizhető élesben.** Kérünk visszajelzést: vezetés közben most már hallatszanak-e a közeli ellenségek/spawnerek stb. a jármű körül, folyamatosan követve azt.

**Kiegészítés — a felhasználó megkérdőjelezte ezt a magyarázatot, helyesen**: *"kétlem. Inkább azt tippelném hogy anchorhoz kötött. Mert ahova esik a remote surfacere, azt hallani fizikai nélkül is."* Vagyis: remote view-ban, fizikai jelenlét NÉLKÜL is simán hallható, ami ott történik, ahol éppen a remote kamera/"anchor" áll — ez arra utal, hogy a hallhatóság (legalábbis részben) a remote kamera aktuális pozíciójához van kötve, NEM (csak) a 18a. pontban javított `SoundModel` cursor/character referenciaponthoz.

**Újra-kivizsgálás, ami ezt megerősítette**: a `vehicles-overview.lua`-ban a `drive_vehicle` a remote vezetés indításakor a kamerát (`player.set_controller{type=remote, position=jármű pozíciója}`) **CSAK EGYETLEN EGYSZER** állítja be, a vezetés KEZDETÉN — utána semmi a kódban nem frissíti tovább, ahogy a jármű halad. Tehát a remote kamera ("anchor") ott marad, ahol a vezetés elindult, miközben a jármű (a 17a. pont óta MÁR TÉNYLEGESEN mozogva) egyre messzebb kerül tőle — pontosan ez magyarázza a "kitankolt a hallható zónából" élményt, méghozzá közvetlenebbül, mint a `SoundModel` referenciapont.

**A hiányzó darab**: `LuaPlayer.centered_on` (írható-olvasható, "the entity being centered on in remote view" — hivatalos API-doksi) — ez az a mező, ami a remote kamerát TÉNYLEGESEN, FOLYAMATOSAN egy adott entitáson tartja, nem csak egyszeri pozíció-pillanatfelvételként. A kód eddig sosem nyúlt hozzá.

**Javítás** (`control.lua`, `on_player_driving_changed_state`): mivel ez a vanilla esemény MINDEN vezetés-kezdésre/-végre lefut (a `set_driver`+`player.driving=true` script-alapú útvonalra is, nem csak a natív "odasétálás+enter"-re — ezt a meglévő `land_on_planet()`-es komment is megerősíti), itt, egy központi helyen állítjuk be: vezetés kezdetekor, HA remote view-ban vagyunk (`controller_type == remote`), `player.centered_on = vehicle` — a kamera mostantól folyamatosan a járművet követi, amíg vezetsz. Kilépéskor (vagy ha a `last_vehicle` már nem érvényes) `player.centered_on = nil`-re állítjuk vissza, hogy ne ragadjon egy már irreleváns entitáson.

- **Szintaxis-ellenőrizve** (`luac5.3 -p`), kiküldve, device-ra mentve.
- **A `scripts/sound-model.lua` (18a.) fix NEM lett visszavonva** — az továbbra is helyes és hasznos (a `SoundModel`-t használó radar-sonifierek pan/gain-számítása szempontjából releváns marad, függetlenül attól, hogy a nyers kamera-pozíció most már külön is követi a járművet), csak önmagában nem volt elég a teljes jelenség magyarázatához.
- **NEM ellenőrizhető élesben.** Kérünk visszajelzést: vezetés közben most már folyamatosan hallható-e a jármű környezete, ahogy halad.

Forrás:
- `LuaPlayer.centered_on` dokumentáció (helyi API-doksi, `classes/LuaPlayer.html`) — írható-olvasható, "The entity being centered on in remote view."

**Kiegészítés 2 — élesben ez SEM oldotta meg**: *"ez nem jött össze még mindíg nem így működik. Az anchor maradt a remote bolygó landing pontján."* Vagyis a `control.lua`-beli `on_player_driving_changed_state`-en keresztüli `centered_on` beállítás sem hozta el a várt eredményt — a kamera a felület remote-view alapértelmezett belépési pontján ("landing pont") ragadt, nem a járművön.

**Kétirányú válasz, mert nem lehet biztosan tudni kódból, MELYIK lépés hiúsul meg élesben (nincs futó Factorio ebben a sessionben)**:
1. **Belt-and-suspenders újra-beállítás** (`scripts/ui/tabs/vehicles-overview.lua`, `drive_vehicle`): a `centered_on`-t most a `set_driver()`+`driving=true` hívások UTÁN, a `drive_vehicle` függvényen belül IS explicit újra beállítjuk (nem csak a `control.lua`-s eseménykezelőn keresztül) — arra az esetre, ha a `set_driver` saját belső, 2.0.55-ös "automatikus pozíció/felület-igazítás" viselkedése az eseményjelzés UTÁN futna le, és felülírná a korábban beállított `centered_on`-t egy sima statikus pozícióval.
2. **Ideiglenes DEBUG bemondás** ugyanitt: minden remote Drive-indításkor a mod most Speech-en (SOSEM `game.print`-en) keresztül bemondja a `centered_on` állapotát, a `controller_type`-ot, a kamera pozícióját és a jármű pozícióját. Ez a `factorio-access-speech.log` fájlba (script-output mappa) is bekerül — ez lehetővé teszi, hogy a KÖVETKEZŐ teszt után a naplóból közvetlenül, visszakérdezés nélkül lássuk, pontosan mi történik (sikerül-e egyáltalán beállítani a `centered_on`-t, és ha igen, a kamera pozíciója tényleg követi-e).

- **Szintaxis-ellenőrizve** (`luac5.3 -p`), kiküldve, device-ra mentve.
- **A DEBUG bemondás IDEIGLENES** — a diagnózis után eltávolítjuk.
- **NEM ellenőrizhető élesben.** Kérünk egy rövid remote Drive-tesztet (nem kell semmit visszajelezni a bemondásról — a naplófájlt közvetlenül ellenőrizzük).

**Kiegészítés 3 — az első naplóminta ígéretes, de csak egy pillanatfelvétel**: a felhasználó tesztelt, a `factorio-access-speech.log`-ot közvetlenül kiolvastuk (fájlrendszer-hozzáférésen keresztül, visszakérdezés nélkül). A vezetés-indításkori DEBUG sor:
```
[5318284] [P1] DEBUG centered_on=tank controller_type=7 campos=-49,28 vehiclepos=-49,28
```
Ez azt mutatja, hogy INDÍTÁSKOR a `centered_on` sikeresen "tank"-ra állt, és a kamera pozíciója pontosan egyezett a jármű pozíciójával — ez a 2. Kiegészítésben leírt belt-and-suspenders javítás működését igazolja, ABBAN a pillanatban. Amit ez NEM mutat meg: hogy ez a következő másodpercekben/vezetés közben IS megmarad-e, vagy valami később visszaállítja.

**Javítás/bővítés** (`scripts/sonifiers/vehicle.lua`, `on_tick_per_player`): mivel ez a függvény MINDEN tick-ben lefut minden vezető játékosra (a meglévő jármű-hang sonifier motorja), ide tettem egy MÁSODIK, FOLYAMATOS (kb. másodpercenkénti, `game.tick % 60 == 0`) DEBUG bejegyzést, ami logolja a `centered_on` aktuális értékét, a kamera és a jármű pozícióját, és a kettő közti távolságot ("drift") — ez adja meg a végleges választ arra, hogy a kamera IDŐVEL is követi-e a járművet, vagy csak indításkor volt jó, aztán elszakad. Kérünk egy hosszabb (10-15 másodperces) remote vezetést, utána a naplóból ismét visszajelzünk, visszakérdezés nélkül.

- **Szintaxis-ellenőrizve** (`luac5.3 -p`), kiküldve, device-ra mentve.
- **Ez a DEBUG blokk is IDEIGLENES**, a `Speech` require-jelöléssel együtt eltávolítjuk a diagnózis lezárása után.

**Kiegészítés 4 — a diagnózis lezárva, a jelenség valószínűleg SOSEM VOLT hiba**: a felhasználó tesztelt (10-15 másodperces remote vezetés), a folyamatos naplót kiolvastuk:
```
[5320443] centered_on=tank                          campos=-231,28  vehiclepos=-231,28
[5320620] centered_on=nil  drift=0    campos=-236,28  vehiclepos=-236,28
[5320680] centered_on=nil  drift=0    campos=-247,28  vehiclepos=-247,28
...  (kb. 27 további tick-en át, kb. 30 másodpercen keresztül) ...
[5322240] centered_on=nil  drift=0    campos=-54,28   vehiclepos=-54,28
```
Két meglepő dolog derült ki:
1. **A `drift` a TELJES, ~30 másodperces, ~177 mezős úton MINDVÉGIG pontosan 0 volt** — a kamera pozíciója tick-ről tick-re TÖKÉLETESEN egyezett a jármű pozíciójával, egyetlen egyszer sem tért el. Vagyis a nyers kamera-pozíció követés valójában MINDIG is jól működött.
2. **A `centered_on` viszont pár másodperc után visszaáll `nil`-re**, annak ellenére, hogy a drift közben is 0 marad. A legvalószínűbb magyarázat: a vezetés (`player.driving`) SAJÁT, natív motor-szintű kamera-követést biztosít, ami FÜGGETLEN a `centered_on`-tól, és a `centered_on`-t (ami inkább "nézd ezt az entitást remote view-ban, vezetés nélkül" célra való) az motor valószínűleg automatikusan törli, amint az aktív kormányzás átveszi az irányítást a kamera fölött. A 2-3. Kiegészítésben feltételezett "centered_on a hiányzó darab" elmélet emiatt **TÉVESNEK bizonyult** — de szerencsére a probléma, amit meg akart oldani (kamera nem követi a járművet), a mérés szerint SOSEM állt fenn ebben a formában.

**A felhasználó visszajelzése erről a tesztről**: *"Az utolsó 1-2 tick alatt volt hangja is. Addig nem."* — vagyis a ~30 másodperces sivatagi szakasz nagy részén nem hallott semmit, csak a legvégén. A technikai adatok (0 drift mindvégig) alapján ez valószínűleg **NEM hiba, hanem a helyes viselkedés**: a `sound-model.lua` (18a. pont) óta a radar-sonifierek (enemy-radar, spawner-radar) helyesen a jármű pozíciója körül keresnek — ha az út nagy része üres sivatagon vitt át ellenség/spawner nélkül, a rádiusban egyszerűen NEM VOLT mit sonifikálni, és csak a legvégén, amikor valami a hallótávolságba került, szólalt meg hang. Ez pontosan azt jelenti, hogy a rendszer a jármű KÖRÜL figyel, nem a régi, helyben maradt referenciapont körül — ami maga a kívánt javítás.

**Takarítás**: mindkét IDEIGLENES DEBUG blokk eltávolítva (`scripts/sonifiers/vehicle.lua` — a folyamatos drift-napló + a csak-diagnosztikai `Speech` require; `scripts/ui/tabs/vehicles-overview.lua` — az indításkori egyszeri bemondás). A `centered_on` beállítás MARADT (`control.lua` eseménykezelő + `drive_vehicle` belt-and-suspenders újra-beállítás) — bár a mérés szerint nem ez tartja a kamerát a járművön aktív vezetés közben, ártalmatlan, és fedezheti azt az esetet, amikor a játékos egy kétüléses jármű UTASA (gunner), nem vezetője — ott `player.driving` hamis, tehát a natív vezetés-kamera-követés feltehetően nem lép életbe.

- **Szintaxis-ellenőrizve mindkét megtisztított fájlon** (`luac5.3 -p`), kiküldve, device-ra mentve.
- **Kérünk visszajelzést**: a legutóbbi teszt sivatagi szakaszán tényleg alig/nem volt ellenség vagy spawner a közelben a vég előtt? Ha igen, ez megerősíti, hogy minden a jármű köré igazodik helyesen, és a 18. pont ezzel lezárható. Ha volt a közelben valami, amit mégsem hallottál, szólj, és tovább nézzük.

---

## 19. `[MISC]` Gleba romlás (spoilage) — "spoils in X" bemondás a meglévő item-info rendszerbe kötve

**Előzmény/irányváltás**: a korábbi tervezési kör (lásd a beszélgetés-összefoglalóban) egy önálló "Z" billentyűvel, inventory-szintű MINIMUM-kereséssel (melyik stack romlik meg leghamarabb az egész inventoryban) számolt. A felhasználó ezt élesben leegyszerűsítette: *"amiben inventoryban le tudod kérdezni az item leírását... a stack romlási idejét mondja el és kész. Keresni akkor nem kell."* — vagyis nincs szükség sem külön billentyűre, sem keresésre/minimumra: ahol a mod MA IS bemondja egy stack leírását (kézben tartott tárgy, inventory-slot verbose olvasás, K a földön heverő tárgyon), ott mondja be a SAJÁT stack romlási idejét is, ha van neki.

**Adatalap (megerősítve a korábbi kutatásban)**: a romlás stack-szinten EGYSÉGES (nem elemenként) — a hivatalos wiki szerint összevonáskor a frissesség átlagolódik, és egy stack minden eleme egyszerre romlik meg. Ebből következik, hogy `LuaItemStack.spoil_tick` (0, ha a tárgy nem romlandó) önmagában a teljes, hiteles válasz "mikor romlik meg EZ a stack" kérdésre — nincs szükség `spoil_percent`-re vagy külön minőség-korrekcióra, a `spoil_tick` már figyelembe veszi azt.

**Implementáció**:
- **`scripts/item-info.lua`** — új, EXPORTÁLT (nem `local`) `mod.get_spoil_info(message, stack)` függvény: ha `stack.spoil_tick > 0`, `{"fa.item-info-spoils-in", FaUtils.format_time(spoil_tick - game.tick)}`-et ad hozzá az üzenethez — a MEGLÉVŐ `FaUtils.format_time` segédfüggvényt használja (óra/perc/másodperc formátum), ugyanazt, amit a mod máshol is (pl. üzemanyag-idő) — nem új formátum kitalálva. A `mod.get_item_stack_info(...)` VERBOSE ágában hívva, közvetlenül a Factorissimo factory-display info hívása mellé téve (ugyanaz a hely/minta, amit a felhasználó kért: *"legyen pont úgy mint amit a factory displayhoz írtál, ugyanaz a system legyen"*) — ez automatikusan lefedi a kézben tartott tárgy olvasását (Y, `read_item_in_hand`) ÉS az inventory verbose stack-olvasást (`scripts/ui/inventory-grid.lua`, mindkét `get_item_stack_info` hívás), mivel mindkettő ugyanezen a közös függvényen megy át.
- **`scripts/fa-info.lua`** — `ent_info_item_on_ground` (a K gomb entitás-infó kezelője földön heverő tárgyakra) kiegészítve `ItemInfo.get_spoil_info(ctx.message, ent.stack)` hívással — így K a földre esett (pl. elrohadt Gleba-termény mellett még meglévő, de romlóban lévő) tárgyaknál is bemondja a hátralévő időt, UGYANAZT a függvényt hívva, nem egy második, külön kódolt változatot.
- **`locale/en/item-info.cfg`** — új kulcs: `item-info-spoils-in=spoils in __1__`.

**GitHub issue #294 ("spoiling")**: megnéztem — a hivatalos upstream repo-ban nyitva van, de a leírása minimális ("Yet another 'we just need to announce it' thing. Not sure if there's API access yet."), konkrét terv/megoldás nélkül. Ez a mostani implementáció pontosan ezt oldja meg (bemondás), és nem mond ellent semminek, amit ott terveztek.

- **Szintaxis-ellenőrizve** (`luac -p`) mindhárom érintett fájlon, kiküldve, device-ra mentve.
- **NEM ellenőrizhető élesben** (nincs futó Factorio ebben a sessionben, és Gleba-teszthez romló tárgy kell). Kérünk visszajelzést: kézben tartott/inventoryban lévő romló tárgynál (pl. Gleba-termény) bemondja-e a "spoils in ..." részt Y-nál és inventory-olvasásnál, és K-nál a földön heverő romló tárgyaknál is.

---

## 20. `[LIGHTNING]` Fulgora lightning-attractor coverage grid

This section is written in English, in unusual detail, at dzsoker's explicit
request, specifically so that the whole reasoning chain is auditable in
review without having to reconstruct it from the design conversation. It
covers the problem, every design decision that was made and why, the exact
algorithm, and how it's wired into the existing mod. Code comments in
`scripts/lightning-zones.lua` point back to this section; treat this as the
source of truth for *why*, and the code as the source of truth for *how*
exactly it's implemented.

### 20.1 The problem

On Fulgora, buildings not within a lightning-attractor's protection radius
can be struck and damaged by lightning. A blind player has no way to see the
overlapping protection circles the way a sighted player does at a glance -
there was previously no way to ask "is this spot protected", let alone "is
my whole base protected", short of waiting for a building to actually take
lightning damage and show up in the existing warnings menu (reactive, not
proactive, and only after the fact).

### 20.2 Rejected approach: live circle-distance math

The first idea considered (including a second AI's independently-proposed
"circle covered by union of circles" boundary-arc-sweep algorithm, pasted in
by dzsoker for comparison) was to answer "is point P protected" by directly
testing distance from P to every attractor and comparing against each
attractor's radius, live, per query. dzsoker rejected this outright for a
concrete gameplay reason: K needs to answer instantly on every keypress, and
recomputing distance-to-every-attractor (or worse, a full circle-union
boundary sweep) on every single keypress does not scale as the number of
attractors on an island grows over the course of a playthrough. Quote:
*"csak endre frissüljön. A k baszottul lassítaná."* (paraphrased: "only
refresh on End. K would slow things down badly.")

### 20.3 Chosen approach: a grid, rebuilt on End, cached for reads

Instead, protection is rasterized once onto a tile grid (a plain Lua table
keyed by `"x,y"` tile coordinates) every time the player presses End - which
already triggers a full surface rescan for the scanner menu
(`scripts/scanner/entrypoint.lua`, `do_refresh` / `do_refresh_after_sfx`), so
this piggybacks on an existing "expensive, infrequent, deliberate refresh"
moment instead of adding a new one. Every subsequent read (K, the warnings
menu) is then an O(1) table lookup against whatever was last computed - cheap
enough to run on every keypress, at the cost of being at most one End-press
stale, which dzsoker explicitly accepted as the right trade-off.

A useful side effect of rasterizing to a shared tile grid, discussed at
length before any code was written: two (or more) attractors' circles
overlapping, or failing to overlap and leaving a gap between them, requires
*no special-case logic whatsoever*. A tile is covered if ANY attractor's
circle reached it; a real gap between circles is simply a tile no attractor
ever marked. This directly obsoletes the other AI's proposed boundary-arc
intersection algorithm (which exists specifically to answer "where do two
circle boundaries cross" analytically) - on a grid, that question never
needs to be asked.

### 20.4 What counts as "covered": range_elongation only, no search_radius

Every `lightning-attractor`-type entity (there are three prototypes on
Fulgora: `lightning-rod`, `lightning-collector`, and the decorative,
zero-efficiency `fulgoran-ruin-attractor` found scattered on ruins) has a
`range_elongation` data value (15 / 25 / 20 tiles respectively, confirmed via
`data-raw-dump.json`), readable live and quality-adjusted through
`LuaEntityPrototype:get_attraction_range_elongation(quality)`. This is the
number used as the rasterized circle's radius.

An earlier draft of this design also added Fulgora's planet-level
`lightning_properties.search_radius` (10 tiles, confirmed via
`data-raw-dump.json`; not readable at runtime, only at data stage) to this,
i.e. `radius = search_radius + range_elongation`, mirroring a model dzsoker
had already told me not to bother with ("mi lenne az l+d?"). `search_radius`
governs how far the game searches for a valid attractor target *from the
point an actual lightning bolt lands*, when deciding whether to redirect a
strike to an attractor - it's part of the "does this specific bolt get
redirected" mechanic, not part of "how big is the protection area". dzsoker
caught this reintroduction explicitly ("minek neked a lightning 10-es adat? Az
egyáltalán nem számít csak kizárólag a fedett terület") and it was removed;
the final radius is `range_elongation` alone, with no planet-level constant
involved at all.

### 20.5 Land detection: two iterations

**First attempt (rejected):** test `LuaTile:collides_with("player")` - true
means the player entity would collide there, so treat false as "land". This
correctly excludes the void between Fulgora's scrap islands (`out-of-map`,
`empty-space` - both collide with every layer including `player`), but
dzsoker pointed out this conflates two different questions: whether the
*terrain itself* is solid ground, versus whether *anything currently
standing there* (a building, a rock) blocks movement. It's also wrong in the
opposite direction: Fulgora's oil ocean tiles
(`oil-ocean-shallow`/`oil-ocean-deep`) do NOT collide with the `player`
layer at all - the player can wade into them (shallow at normal speed
penalty, deep even more so per their `walking_speed_modifier` of 0.8/0.5) -
so this test would have wrongly counted oil ocean as "land".

**Final approach:** test the TILE PROTOTYPE's own collision mask directly -
`tile.prototype.collision_mask.layers.water_tile`. This is a pure,
static terrain property, completely unaffected by whatever is built or
growing on top of the tile right now, which resolves dzsoker's
buildings/rocks concern. And, confirmed via `data-raw-dump.json`: every one
of `out-of-map`, `empty-space`, `oil-ocean-shallow`, and `oil-ocean-deep`
happens to carry `water_tile: true` in its collision mask, while every real
Fulgora ground tile (`fulgoran-dust`, `-dunes`, `-sand`, `-rock`, `-paving`,
`-walls`, `-conduit`, `-machinery`) does not. So `not water_tile` is exactly
the "land" test dzsoker asked for (explicitly: exclude void AND both oil
ocean variants), just expressed as one general property check instead of
two hardcoded tile names - which also means it keeps working correctly if a
future game/mod update adds another walkable water-ish tile, without this
code needing to know its name in advance.

`mod.is_land(surface, x, y)` in `scripts/lightning-zones.lua` implements
exactly this one check.

### 20.6 Real attractors vs. ruin attractors: different treatment for two different questions

Fulgora is littered with `fulgoran-ruin-attractor` entities (decorative,
`efficiency = 0`, found on ruins, not built by the player) alongside the
player-placed `lightning-rod`/`lightning-collector`. dzsoker specified two
different, seemingly-opposite rules for them, which turned out to both be
correct once the two separate purposes the grid serves are distinguished:

- **For the *coverage* grid** (the thing K and the warnings menu ultimately
  read to answer "is this tile protected"): ruin attractors count, same as
  real ones. Quote: *"természetesen kell az ancient collector protector mert
  az is véd, nekünk pedig az a lényeg"* - they do project a protection
  circle, and that's the only thing that matters for this question,
  regardless of who placed the attractor.
- **For *island clustering and the analysis threshold*** (deciding which
  groups of attractors are worth running hole/shore-gap detection on at
  all): only `lightning-rod` and `lightning-collector` count. Ruin
  attractors are excluded from this specifically because they're extremely
  common and scattered everywhere - if they counted toward the "is this a
  real, player-relevant cluster" threshold, nearly every scrap patch on the
  map (most of which the player has no base on and no intention of
  protecting) would qualify as an "island" and generate hole/shore-gap
  warnings nobody asked for. Quote: *"A szigeten 1 collector partkör inkább
  ne, mert egy rakást kiad az ancientek miatt fölöslegesen."*

Concretely, in `scripts/lightning-zones.lua`: `build_grid` rasterizes
circles from `attractors` (all three prototypes), but only seeds island
clustering and gap detection from `real_attractors` (rod + collector only).

### 20.7 Islands: real land-connectivity flood fill, not attractor-distance clustering

An earlier idea (discarded once real land detection became necessary anyway
for the shore-gap feature below) was to approximate "these attractors are on
the same island" using pairwise attractor-to-attractor distance
(union-find over pairs closer than the sum of their radii plus some slack).
This was explicitly a workaround for not wanting to deal with real terrain
data. Once a reliable land/non-land test existed (20.5), this approximation
became both unnecessary and strictly worse: two attractors can be close in
straight-line distance while on two different islands separated by ocean, or
far apart while on the same long, thin island - distance is not what
actually determines "same island", land connectivity is.

The final algorithm (`flood_fill_islands` in `scripts/lightning-zones.lua`)
is a single, shared, multi-source flood fill: every real attractor's
position is a seed with its own component id; the fill walks outward over
land tiles only (`mod.is_land`), and whenever two different seeds' fills
touch the same tile, their components are merged via union-find. One bounded
pass (capped at `MAX_LAND_TILES_PER_BUILD` = 150000 tiles total, shared
across the whole surface, as a safety valve rather than an expected limit)
produces both the correct island grouping AND each island's full land tile
set simultaneously - no second pass or separate bounding-box step needed.

### 20.8 Gap detection: interior holes vs. shore gaps, from one diff

For every island with >= 2 real attractors (see 20.9 for why that
threshold), `uncovered = island's land tiles - covered tiles` is computed,
then broken into 4-connected components (`find_gaps` in
`scripts/lightning-zones.lua`, a plain in-memory flood fill over the
`uncovered` set - no further surface queries needed except at a component's
boundary, to disambiguate "real non-land" from "land outside the flood
fill's visited set", see the code comment in `find_gaps`).

Each uncovered component is classified by a single question: does it touch
any non-land tile?

- **No** → it's fully enclosed by protected land - an **interior hole**,
  invisible from outside the coverage area, exactly the "protected p's
  surrounding an unprotected u in the middle" scenario dzsoker illustrated
  with ASCII diagrams earlier in the design conversation. Reported at the
  tile-centroid of the component - per dzsoker's request ("ha lyuk,
  lehetőleg a lyuk közepét adja ki") - which is a cheap approximation of
  "the middle" (arithmetic mean of tile coordinates) rather than a
  geometrically-guaranteed interior point for oddly-shaped holes, but is
  good enough for a "go roughly here" pointer.
- **Yes** → it borders the island's actual edge (void or oil ocean) - a
  **shore gap**: land the player could walk right up to the true coastline
  on without ever triggering a warning from building damage, because there
  may be nothing built there yet to damage. This was dzsoker's key insight
  in the last planning message: relying only on reactive
  warnings/building-damage misses gaps in never-yet-built-on land near the
  shore. Reported with a compass direction (via the EXISTING
  `FaUtils.get_direction_precise` / `FaUtils.direction_lookup` helpers,
  already used elsewhere in the mod for directional reporting - reused
  rather than inventing a second direction system) relative to the island's
  centroid (mean position of its real attractors).

### 20.9 The >= 2 real-attractor threshold, and why it applies to both

Holes and shore gaps are both gated on the same condition: an island's real
(rod/collector) attractor count must be >= 2. Two independent reasons landed
on the same number:

- **Holes**: mathematically exact, not a heuristic. A single circle is
  convex, so by definition it cannot have an interior hole. Below 2 real
  attractors, hole detection is skippable with zero risk of a false
  negative.
- **Shore gaps**: this is a UX/noise call, not a geometric guarantee - a
  single attractor's circle absolutely can fail to reach an island's far
  shore. It was initially planned to run regardless of attractor count, but
  dzsoker cut this back to the same >= 2 threshold for the reason quoted in
  20.6: single-attractor "islands" are extremely common on Fulgora (most
  are just a ruin attractor or a lone collector with no real base), and
  reporting a shore gap for every one of them would be noise, not signal.

### 20.10 Integration points

- **`scripts/lightning-zones.lua`** (new file): the whole engine described
  above - `mod.is_land`, `mod.build_grid`, `mod.is_covered`,
  `mod.get_warning_entries`. Self-contained; the only cross-module
  dependency is `scripts/fa-utils.lua` (for direction reporting).
- **`scripts/scanner/entrypoint.lua`**: `do_refresh_after_sfx` now calls
  `LightningZones.build_grid(player_obj.surface)` right after obtaining the
  player object, alongside (not instead of) the existing per-player scanner
  rescan - same End-key trigger, independent full-surface pass. A no-op
  (single `find_entities_filtered` call that returns empty, dropping any
  stale grid) on any surface with no lightning-attractor entities, i.e.
  everywhere except Fulgora.
- **`scripts/fa-info.lua`**: new `ent_info_lightning_coverage` handler,
  wired into the existing `run_handler(...)` chain inside `mod.ent_info`
  (the function K ultimately calls for entity readouts). It calls
  `LightningZones.is_covered(ent.surface, ent.position)` and speaks up ONLY
  when it returns `false` ("not in lightning protection range") - staying
  silent both on the common "covered" case and when the surface has no grid
  at all (`nil`, meaning lightning protection isn't even a relevant concept
  there). This mirrors the rest of this mod's warning-style readouts, which
  stay quiet unless there's something actionable to say, rather than
  announcing "protected" on every single K press on Fulgora.
- **`scripts/warnings.lua`**: two new `WARNING_TYPES` entries,
  `LIGHTNING_HOLE` and `LIGHTNING_SHORE_GAP`. `scan_for_warnings` pulls
  `LightningZones.get_warning_entries(surf)` and wraps each `{position,
  label}` entry as a lightweight synthetic pseudo-entity
  (`synthetic_warning_entity`: `valid = true`, `position`, `unit_number =
  nil`, `is_synthetic = true`, `label`) - filtered to the same L,H box
  already used for every other warning type here, for consistent behavior.
- **`scripts/ui/menus/warnings.lua`**: `render_warnings`'s item `label`
  callback gained one branch: if `entity.is_synthetic`, use the pre-built
  `entity.label` instead of calling `Localising.get_localised_name_with_fallback`
  on it (there's no real prototype to look up a name for - it's a bare
  position, not a placed entity). Every other part of this file
  (`entity_key` generation, `on_click` cursor-jump, `on_read_coords`,
  distance sorting, the summary line) already worked purely off
  `.valid`/`.position`/`.unit_number`, so needed no changes at all - the
  synthetic records satisfy that shape already.
- **`locale/en/entity-info.cfg`**: new key
  `ent-info-lightning-unprotected=not in lightning protection range`.
- **`locale/en/warnings.cfg`**: new keys `warning-type-lightning-hole`,
  `warning-type-lightning-shore-gap`, `lightning-hole-label`,
  `lightning-shore-gap-label` (takes the compass direction as `__1__`).

### 20.11 What this does NOT do (explicitly out of scope for this round)

- No robot/train inter-island lightning protection - dzsoker explicitly
  deferred this as a later "+1 layer", not needed for v1.
- No "at-a-glance gestalt" summary or sonified sweep of the whole coverage
  shape - explored in the design conversation as a genuinely hard,
  possibly-unsolvable accessibility problem, left open, not part of this
  implementation.
- No exemption-list filtering (some entity types, e.g. rails, walls, trees,
  per `lightning_properties.exemption_rules`, can never actually be struck
  regardless of coverage) - the K readout currently reports coverage status
  for any entity read, not just ones that could plausibly be a lightning
  target. Noted here as a possible future refinement, not requested or
  implemented now.

### 20.12 Verification status

**Syntax-checked** (`luac -p`) on every touched/new Lua file
(`scripts/lightning-zones.lua`, `scripts/scanner/entrypoint.lua`,
`scripts/fa-info.lua`, `scripts/warnings.lua`,
`scripts/ui/menus/warnings.lua`), delivered and saved to device. Every
runtime API call used here (`LuaTilePrototype.collision_mask`,
`LuaEntityPrototype:get_attraction_range_elongation`,
`surface.find_entities_filtered({type = "lightning-attractor"})`) was cross-
checked against the local generated API reference
(`llm-docs/api-reference/`) before being used, specifically to catch a
data-stage-only field being mistaken for a runtime-readable one (this is
exactly what ruled out reading `search_radius` live in 20.4).

**NOT yet verified in a running game** - there is no live Factorio instance
in this session. In particular, untested: whether `get_tile` on an
ungenerated/uncharted chunk actually returns something whose
`collision_mask` resembles `out-of-map` (expected, since that's how the
engine is documented to represent it, but not directly observed here); the
actual visual size/shape of the rasterized coverage circles against what
the game itself shows; and whether the End-key hook fires reliably without
a noticeable extra delay on an island with many attractors. Please test on
Fulgora with at least two lightning-collectors/rods placed with a gap
between their circles (to see a shore-gap or hole warning appear) and report
back what K says standing just outside a circle's edge, and what the
warnings menu shows.

### 20.13 Addendum — crash on opening the warnings menu, fixed

dzsoker tested and hit a non-recoverable mod error the moment the warnings
menu was opened:

```
Error while running event FactorioAccess::fa-p (ID 360)
LuaEntity doesn't contain key is_synthetic.
stack traceback:
	[C]: in function '__index'
	__FactorioAccess__/scripts/ui/menus/warnings.lua:132: in function 'label'
```

**Root cause**: `render_warnings`'s item label callback
(`scripts/ui/menus/warnings.lua`) tried to distinguish a synthetic
lightning-gap entry from a real `LuaEntity` by checking `entity.is_synthetic`
directly. That works fine for the synthetic entries (plain Lua tables return
nil for any key they don't have), but is wrong for every REAL warning entity
(no-fuel, no-power, no-recipe, not-connected) - Factorio's API objects are
not plain tables. Reading an undeclared/unknown field on a `LuaEntity`
raises a hard error ("LuaEntity doesn't contain key X") instead of quietly
returning nil the way a Lua table would. So the very first time the warnings
menu was opened with any ordinary (non-lightning) warning present, checking
`entity.is_synthetic` on that real entity crashed the mod. This is a classic
Factorio-modding gotcha (plain-table duck-typing does not work on engine
objects) and should have been caught before shipping - noted here plainly
rather than glossed over.

**Fix**: check `entity.object_name` instead. `object_name` is itself a real,
documented LuaEntity attribute (confirmed via the local API reference:
"Available even when valid is false"), so reading it is always safe on a
real entity and returns the string `"LuaEntity"`. On our synthetic plain
table it's simply unset, so the same read returns nil (again safe, since
it's a plain table) - `entity.object_name ~= "LuaEntity"` now cleanly
distinguishes the two cases without ever performing an unknown-key read on
a real engine object either way.

- **Syntax-checked** (`luac -p`), delivered and saved to device.
- Also reported at the same time: K "doesn't seem to work". No separate bug
  was found in the K code path itself
  (`ent_info_lightning_coverage`/`LightningZones.is_covered` only touch
  documented LuaEntity fields). The likely explanation is that this is a
  side effect of the crash above: Factorio typically treats a
  "non-recoverable" mod error as fatal for the rest of that session, which
  would explain K going quiet too if it was tested around the same time as
  opening the warnings menu. It's also worth ruling out two non-bug causes
  before assuming K itself is broken: K is silent by design when a spot IS
  protected or when no grid has been built yet (i.e. End was never pressed
  after placing an attractor) - see 20.10 - so standing somewhere already
  covered produces no announcement, which can look identical to "not
  working". Please reload/rejoin the save, press End near the attractors,
  then test K both clearly outside a circle (should say "not in lightning
  protection range") and clearly inside one (should stay silent), and report
  back which of those two it actually does.

### 20.14 Addendum — found it: K genuinely never reached the check

dzsoker retested: the warnings menu now correctly shows an "unprotected
shore" entry (confirming the grid, flood fill, and gap classification are
all actually working), but K still says nothing standing at that spot. This
was a real, separate bug - not a side effect of the earlier crash - and
tracking it down explains exactly why K "worked" in the sense of not
crashing, yet never spoke up.

**Root cause**: the lightning-coverage check was wired into
`ent_info_lightning_coverage`, called from inside `FaInfo.ent_info`
(`scripts/fa-info.lua`). But `ent_info` is only reached when there IS an
entity under the cursor. Tracing the actual K code path
(`scripts/tile-reader.lua`, `mod.read_tile_inner`, which is what both the
`fa-k` custom input and ordinary cursor movement call): when there's no
entity at the tile, it takes a completely separate branch that reads the
TILE name (and shore info for water tiles) and never calls `ent_info` at
all. An unprotected shore gap is, by definition and by design, exactly the
kind of spot nothing has been built on yet - so it always took that no-ent
branch, and the coverage check living only inside `ent_info` never had a
chance to run there. The interior-hole case would have had the same problem
for the same reason. This is the same category of mistake as 20.13 in
spirit: correct-looking code that quietly only covers part of the intended
cases.

There's also existing precedent for this exact shape of check already in
`read_tile_inner`'s sibling function `read_coords`
(`control.lua`, bound to `fa-k`): a live `Territory.get_status_at(surface,
position)` point-query for Vulcanus demolishers, run unconditionally
regardless of what's under the cursor, silent everywhere irrelevant,
explicit ("Free "/"Guarded ") wherever it applies. That's precisely the
shape lightning coverage needed too, and confirms this kind of "is this
exact spot special" check belongs at the tile-read level, not nested inside
entity-only reporting.

**Fix**: moved the check out of `scripts/fa-info.lua` entirely (removed
`ent_info_lightning_coverage` and its `run_handler` wiring, and the now-
unused `LightningZones` require there) and into
`scripts/tile-reader.lua`'s `mod.read_tile_inner`, added unconditionally
right after the ent-vs-no-ent branch (alongside the existing
`Mouse.cursor_visibility_info` call, which is likewise unconditional) -
so it now runs whether or not there's an entity at the cursor, matching
exactly how the warnings menu already reports both hole and shore-gap
positions regardless of what's built there. Not duplicated in `ent_info`
any more, since `read_tile_inner` already calls `ent_info` in the has-ent
branch, and running the check in both places would have announced it
twice whenever an entity was present.

- **Syntax-checked** (`luac -p`) on both changed files, delivered and saved
  to device.
- Please retest the same unprotected-shore spot: K should now say "not in
  lightning protection range" there.

### 20.15 Addendum — 20.14 fixed the wrong function; the real K is `read_coords` in control.lua

dzsoker retested: still nothing from K, even though the warnings menu keeps
showing the shore gap correctly (so the underlying grid data was never in
question - only which code path K actually runs was). They also asked for
this to specifically keep working while holding a lightning-rod/collector
item in hand, since that's the main real use case - checking a spot's
coverage before placing a new attractor there.

**Root cause, this time actually confirmed against the key binding itself**
(`data/input.lua`): `fa-k` is declared with `key_sequence = "K"` - the
literal K key IS `read_coords` in `control.lua`, not
`TileReader.read_tile_inner`. 20.14 added the check to `read_tile_inner`,
which is real code reached by cursor movement and a few other callers, and
not wrong to have fixed - but it is not what the K key itself calls. This
was an assumption I should have verified against `data/input.lua` before
touching any code, instead of inferring "K" from context; noted here so the
same mistake isn't repeated for some other key later.

**Fix**: added the identical `LightningZones.is_covered(...)` point-query
directly into `read_coords` (`control.lua`), right after the existing
Territory (Vulcanus demolisher) Free/Guarded check - same shape of check,
same file, same function, immediately adjacent code, which in hindsight is
where this obviously belonged from the start given the Territory check was
already sitting right there as a precedent. Computed once
(`lightning_covered`), independent of `cursor_stack`, and appended as a
message fragment right before each of `read_coords`'s two `Speech.speak`
call sites (the driving branch and the plain-coordinates branch), so it
fires the same way whether the player is walking, driving, or holding any
item including a lightning-rod/collector - satisfying "especially say
protected/unprotected while a lightning rod is in hand" without needing any
item-specific logic, since the check was already fully general.
`scripts/tile-reader.lua`'s hook from 20.14 was left in place - it's correct
for whatever calls `read_tile_inner`, just wasn't what K itself uses.

- **Syntax-checked** (`luac -p`) on `control.lua`, delivered and saved to
  device.
- Please retest K (the literal K key) standing at the same unprotected shore
  spot, both empty-handed and while holding a lightning-rod/collector stack.

---

## 21. `[CURSOR-SKIP-GENERIC]` Cursor-skip (Shift+WASD / Ctrl+WASD) regisztrálása minden bolygóra: víz, tér-platform szél, Factorissimo fal, Gleba talaj

### 21.1 Előzmény, mit jelentett be a felhasználó

A kutatási fázis (kód-olvasás, nincs benne módosítás) kimutatta, hogy a
`cursor_skip_iteration` (`control.lua`) entitás-alapú megállása (fa, szikla,
cliff, stb.) **már teljesen generikus és bolygó-független** — ezt három
kódrétegen (`cursor_skip_iteration` → `compute_current`/
`EntitySelection.iterate_selected_ents` → `get_ents_on_tile`/
`should_include_entity`/`Consts.EXCLUDED_ENT_NAMES`) végigkövetve igazoltam,
és csak a `highlight-box` entitásnév van kizárva bárhol — ez az egyetlen
kivétel. A resource-ok felvétele (korábbi kör) szintén megoldotta a "semmi
sem működik" panasz nagy részét.

Ami viszont **ténylegesen hiányzott**, a felhasználó pontos felsorolása
szerint:
1. Víz-féle csempék felismerése csak Nauvisra volt bekötve
   (`Consts.WATER_TILE_NAMES`), Vulcanuson/Fulgorán/Glebán/Aquilón nem állt
   meg a skip.
2. Space platform szélén (`space-platform-foundation` → `empty-space`)
   nem állt meg.
3. Factorissimo (3rd party mod) gyár-belsőben a padlóról (`factory-floor`)
   a térképen kívülre (`out-of-map`) kilépve nem állt meg — vagy a
   `factory-wall`-on állna meg, ami "elegánsabb lenne, ill. mindkettőre".
4. Glebán a `zselé` (jellynut) és a `jumákó` (yumako) talaj-csempéin
   (artificial + natural) nem állt meg a skip, és a scannerben sem szerepel
   sem a két növény (resource kategóriában), sem a talaj-csempék (terrain
   vagy other kategóriában) külön bejegyzésként.

Ez a szakasz mind a négy pontot lefedi, egyetlen közös, generikus
mechanizmussal az 1-3. pontra, és egy kiegészítő "soil" kategóriával a
4. pontra.

### 21.2 A kulcsfelismerés: `collision_mask.layers.water_tile` — nem csak a szó szerinti víz

A `tile_is_water` (`scripts/fa-utils.lua`) régi implementációja egy
kézzel karbantartott névlistát (`Consts.WATER_TILE_NAMES`, csak Nauvis
csempéket) használt `surface.find_tiles_filtered`-del. Ez pontosan az a
minta, amit a korábbi Lightning-funkció (20. pont) `LightningZones.is_land`
függvénye már kiváltott a `tile.prototype.collision_mask.layers.water_tile`
futásidőben olvasható zászlóval — ugyanezt a mintát alkalmaztam itt is,
megfordítva.

**Ellenőrzés `data-raw-dump.json`-on keresztül** (a teljes 182 csempe-
prototípus collision_mask-jának lekérdezésével): pontosan **42 csempe** van
`water_tile=true`-ra állítva a teljes játékban, és ez a lista **véletlenül
pontosan lefedi mind a négy kért esetet, plusz bónuszként az 5.-et is**:

- Nauvis: `water`, `deepwater`, `water-green`, `deepwater-green`,
  `water-shallow`, `water-mud`, `water-wube` (a régi lista pontos
  megfelelője)
- Vulcanus: `lava`, `lava-hot`
- Fulgora: `oil-ocean-deep`, `oil-ocean-shallow`
- Gleba: `gleba-deep-lake`, `wetland-blue-slime`, `wetland-dead-skin`,
  `wetland-green-slime`, `wetland-jellynut`, `wetland-light-dead-skin`,
  `wetland-light-green-slime`, `wetland-pink-tentacle`,
  `wetland-red-tentacle`, `wetland-yumako`
- Aquilo: `ammoniacal-ocean`, `ammoniacal-ocean-2`, `brash-ice`
- `special-tiles` alcsoport: **`empty-space`**, **`out-of-map`**,
  `water-wube`
- `factorissimo-tiles` alcsoport (a 3rd party Factorissimo mod, amit ez a
  mod egyébként nem igényel, de a generikus zászló-ellenőrzés automatikusan
  felismeri, ha telepítve van): `factory-entrance`, **`factory-wall-1`**,
  **`factory-wall-2`**, **`factory-wall-3`**, `space-factory-entrance`,
  `space-factory-wall-1/2/3` (+ ezek `-frozen` Aquilo-változatai)

Vagyis: a `space-platform-foundation` maga **nincs** `water_tile`-ra
állítva (csak `ground_tile` rétege van), de az `empty-space`, amire a
platform szélén kilépve érkezel, **igen** — a határ tehát pontosan ott húz
egy generikus stop-pontot, kód-változtatás nélkül a 2. pontra. Ugyanígy a
`factory-floor` (`factorissimo-tiles`) **nincs** `water_tile`-ra állítva,
de a `factory-wall-1/2/3` ÉS az `out-of-map` **mindkettő** igen — vagyis a
3. pont mindkét változatát ("wall-ra vagy out-of-map-ra, esetleg
mindkettőre") egyetlen, ugyanazon generikus flag-ellenőrzés lefedi, extra
speciális eset nélkül.

**Implementáció** (`scripts/fa-utils.lua`, `mod.tile_is_water`): a
`find_tiles_filtered` + névlista lecserélve `surface.get_tile(pos.x,
pos.y)` + `tile.prototype.collision_mask.layers.water_tile` ellenőrzésre.
A függvény neve maradt (`tile_is_water`), mert ennek egyetlen hívója a
`cursor_skip_iteration` (`control.lua`) — ellenőrizve `grep`-pel, nincs más
hívási hely —, viszont a kommentben explicit figyelmeztetés van, hogy a
"water" elnevezés innentől félrevezető lehet (lávát, gyárfalat is "vizes"-
nek jelez), és hogy a `mod.identify_water_shores` (a "you are standing in
water" beszédhez) szándékosan **nem** ezt, hanem továbbra is a szó szerinti
`Consts.WATER_TILE_NAMES` listát használja — tehát a beszélt szövegben nem
fog "víz"-ként bemondódni a láva vagy a gyárfal.

`scripts/consts.lua` **nem** lett módosítva ehhez a ponthoz — a régi
`WATER_TILE_NAMES`/`WATER_TILE_NAMES_SET` listák megmaradtak
változatlanul, mert más helyek (pl. `identify_water_shores`) még mindig
ezekre támaszkodnak a szó szerinti "ez víz" jelentéshez.

### 21.3 A `cursor_skip_iteration` általánosítása kategóriára (nem csak boolean vízre)

`control.lua`, `cursor_skip_iteration`: a korábbi `start_tile_is_water`
boolean logikát egy `start_terrain_category` string-kategóriára cseréltem
(`FaUtils.get_cursor_skip_terrain_category(surface, pos)` — új függvény,
lásd 21.4), ami `nil`, `"water"` vagy `"soil"` lehet:

- A vízszerű ág (a régi `elseif start_tile_is_water then`) most
  `elseif start_terrain_category ~= nil then` — ugyanaz az "alagút a teljes
  régión át egy skip-ben" logika, csak most bármelyik kategóriára
  (víz-szerű VAGY Gleba-talaj) fut, és a megállás feltétele
  `selected_terrain_category ~= start_terrain_category` (nem csak
  "vízből kiléptünk", hanem "kategóriát váltottunk" — pl. jumákó talajról
  sík Gleba-talajra is megáll).
- Az entitás-összehasonlító ciklus "mindkettő nil" ága (ahol se induló, se
  jelenlegi csempén nincs entitás) szintén generalizálva: a régi
  "ha vizes csempe, állj meg" helyett most "ha bármilyen speciális terep-
  kategóriába léptünk, állj meg" — ugyanaz a mechanizmus, csak nem csak
  vízre.

A ruler-igazítás (audio ruler) ellenőrzések változatlanok maradtak mindkét
ágban.

### 21.4 Gleba talaj-csempék mint második, nem-víz kategória

A `space-platform-foundation`/`factory-wall` bónuszokkal ellentétben a
Gleba talaj-csempék (`artificial-yumako-soil`, `natural-yumako-soil`,
`artificial-jellynut-soil`, `natural-jellynut-soil` — a felhasználó által
kért négy, plusz `overgrowth-yumako-soil`/`overgrowth-jellynut-soil`, egy
harmadik növekedési állapot, amit a `data-raw-dump.json` lekérdezésekor
találtam, a kérésben nem szerepelt, de ugyanabba a kategóriába tartozik,
lásd lentebb) **nem** `water_tile`-osak — teljesen járható föld, amin a
játékos szabadon sétál. Ezért nem eshetnek bele a 21.2 generikus vízszerű
ellenőrzésbe: külön kategóriát kaptak.

Új export `scripts/fa-utils.lua`-ban:
- `mod.CURSOR_SKIP_SOIL_TILE_NAMES_SET` — a 6 csempe-név halmaza (mind a
  két növény, mind a 3 állapot).
- `mod.get_cursor_skip_terrain_category(surface, pos)` — visszaadja
  `"water"`-t (ha `tile_is_water` igaz), `"soil"`-t (ha a csempe neve
  szerepel a fenti halmazban), különben `nil`-t. Ezt hívja a
  `cursor_skip_iteration` mindkét megváltoztatott ága (21.3).

**Miért "soil" egyetlen közös kategória, nem 6 külön?** Ha egy farmon az
artificial és natural talaj közvetlenül egymás mellett van, egyetlen
skip-nyomással a teljes talaj-folt szélére akarsz érni, nem 4-6 külön
megállással minden altípus-váltásnál. Ugyanaz a döntés, mint amit a
víznél már eddig is alkalmazott a kód (egy tó minden vízcsempéje egy
kategória, függetlenül attól, hogy pl. `water` vagy `water-shallow`).

**Az "overgrowth" bevonásáról**: a kérés kifejezetten "artificial és
natural"-t említett, az "overgrowth-*-soil" csempéket csak most, a
`data-raw-dump.json` lekérdezésekor fedeztem fel (recept és csempe szinten
is létező, önálló, minelhető Gleba-talaj altípus). Mivel ugyanabba a
kategóriába tartozik (Gleba növény-talaj, nem `water_tile`), és a kihagyása
azt jelentené, hogy a farm egy harmadik altípusú sávján a skip csendben
átsiklana, bevontam — de ez saját döntés, nem explicit kérés volt, ezért
itt külön jelölve, hogy review-nál könnyen kivehető legyen, ha nem kívánt.

### 21.5 Scanner: `yumako-tree` / `jellystem` felvétele a Resources kategóriába

`data-raw-dump.json` lekérdezéssel kiderült: a `yumako-tree` és `jellystem`
entitások prototípus-`type`-ja **`"plant"`** — ez a típus **sehol** nem
szerepelt a `scripts/scanner/surface-scanner.lua` `BACKEND_LUT` táblájában
(szemben pl. `"resource"`, `"tree"`, stb. típusokkal), és nincs az
"enemy" force-on sem, tehát az ismeretlen-ellenség védőháló sem kapta el —
**teljesen csendben eldobta őket a scanner**, semmilyen bejegyzés nem
készült róluk.

Javítás: `BACKEND_NAME_OVERRIDES`-ba (`surface-scanner.lua`) felvéve
`["yumako-tree"] = SEB.Rock` és `["jellystem"] = SEB.Rock` — ugyanaz a
backend, amit a mod már eddig is használt minden más bolygó "minelhető
dekoráció" jellegű dolgára (Vulcanus vulkáni sziklák, Fulgora romok, Gleba
sztromatolitok, Aquilo lítium-jéghegyek) — tehát ez a bevett minta
folytatása, nem új koncepció. Ezzel a két növény külön bejegyzésként
jelenik meg a Resources kategóriában, prototípus-névvel (yumako-tree /
jellystem) csoportosítva.

`ephemeral_state_version` `16 → 17`-re emelve (`surface_state`
`StorageManager.declare_storage_module` hívás) — enélkül a már beszkennelt
chunk-okon lévő, korábban eldobott yumako/jellynut növények csak akkor
kerülnének elő, ha a chunk valahogy újra szkennelődne; a version-bump
kikényszeríti a teljes friss szkennelést.

### 21.6 Scanner: Gleba talaj-csempék külön Terrain bejegyzésként

Új fájl: `scripts/scanner/backends/gleba-soil.lua` — a meglévő
`backends/iceberg.lua` mintáját követi szorosan (egy `TileClusterer`
minden újonnan látott chunk-on begyűjti az illő csempéket, közelség
alapján csoportosítva jelenti be őket), azzal a különbséggel, hogy **két
külön `TileClusterer`-t** futtat egy objektumon belül — egyet a yumako, egyet
a jellynut talajra —, hogy egy egymás melletti yumako- és jellynut-folt
két külön bejegyzésként jelenjen meg ("külön bejegyzést... a zselére és a
jumákóra" — szó szerint kérve).

- `scripts/scanner/scanner-consts.lua`: új `mod.YUMAKO_SOIL_PROTOS` és
  `mod.JELLYNUT_SOIL_PROTOS` listák (mindkettő a 3-3 állapotváltozatot
  tartalmazza, lásd 21.4).
- Mindkét folt a `TERRAIN` kategóriába kerül (ugyanoda, ahova a cliff és
  az iceberg) — a felhasználó "terrain vagy other alá mindenképp" kérésének
  megfelelően a Terrain-t választottam, mert ez pontosan olyan jellegű
  dolog (terep-típus, nem gyártott/épített objektum).
- Bejelentés szövege: `"Yumako soil __1__ by __2__"` / `"Jellynut soil
  __1__ by __2__"` (`locale/en/scanner.cfg`, új `scanner-yumako-soil` /
  `scanner-jellynut-soil` kulcsok) — ugyanaz a "X szélesség by magasság"
  minta, mint a `scanner-water`/`scanner-iceberg` bejegyzéseknél.
- `surface-scanner.lua`-ba bekötve: `require`, `GlebaSoilBackend.new`
  hozzáadva `instantiate_backends`-hez, `on_new_chunk` hívás a
  `scan_chunk`-ban (a víz/iceberg/territory backend hívásai mellé), és
  `dump_entries_to_callback` hívás a `get_entries_snapshot`-ban. Ugyanaz a
  `ephemeral_state_version` bump (17) fedi ezt is, mert ez is egy új,
  chunk-onkénti backend-hook.

### 21.7 Hatókörön kívül / nem változtatott

- A `fa-s-up/left/down/right` (Shift+nyilak) billentyűk **nem**
  cursor-skip-hez tartoznak — ezek a `BuildingTools.nudge_key`-hez vannak
  kötve (épület-igazítás), egy teljesen más funkció. Egy korábbi
  Explore-subagent tévesen jelentette, hogy ezek is cursor-skip-et
  indítanak — közvetlen kódolvasással (`control.lua` 1637-1776 körül)
  megcáfolva, ide most csak tájékoztatásul jegyzem fel.
- `on_player_changed_surface` (`control.lua`) nem szinkronizálja a cursor
  pozíciót bolygóváltáskor — ez egy külön, ezúttal nem érintett
  potenciális hiba-forrás (a cursor pozíció bolygónként nem tárolt,
  csak játékosonként), nem lett módosítva, mert nem szerepelt a
  konkrét kérések között.
- Az `EXCLUDED_ENT_NAMES` (`scripts/consts.lua`) változatlan maradt — az
  entitás-alapú megállás, ahogy a 21.1-ben leírtam, már eddig is teljesen
  generikus volt, semmi nem hiányzott belőle.

### 21.8 Verifikációs állapot

- **Szintaxis-ellenőrizve** (`luac -p`) minden érintett fájlon: siker.
- Élesben még nem tesztelt. Kérlek teszteld le:
  1. Shift+WASD víz/láva/olaj-óceán/mocsár/ammónia-óceán fölött (bármely
     bolygón) — egy nyomásra a teljes vízfolt túlsó szélére kell érnie.
  2. Shift+WASD egy space platform szélén (foundation → üres tér) — meg
     kell állnia a platform szélén.
  3. Shift+WASD Factorissimo gyár-belsőben padlóról a fal/határ felé — meg
     kell állnia.
  4. Shift+WASD egy Gleba yumako/jellynut talaj-folton — egy nyomásra a
     talaj-folt túlsó szélére kell érnie, plusz megállás, ha a folton
     belül artificial/natural/overgrowth váltás van.
  5. Scannerben (Resources kategória): yumako-tree / jellystem most
     szerepel-e önálló bejegyzésként Glebán.
  6. Scannerben (Terrain kategória): yumako-soil / jellynut-soil folt
     most szerepel-e önálló bejegyzésként Glebán.

---

## 22. `[PIPE-SKIP-FIX]` Pipe-to-ground skip még mindig nem ugrott a szomszédra a crash-javítás után — git-archeológiával megtalált, korábban már bevált javítás visszaállítva

### 22.1 A jelentés

A felhasználó visszajelzése: az underground-belt és a pipe-to-ground
cursor-skip korábban átugrott a kapcsolat túlsó felére, ha a skip iránya
egyezett a föld alatti kapcsolat irányával. A 2.1-es motorváltás miatt ez
lecrashelt (`LuaEntity doesn't contain key fluidbox`), amit egy korábbi
körben javítottam (19. pont körüli munkamenet) - de a crash elmúltával
kiderült, hogy a pipe-to-ground **nem ugrik többé a szomszédra**, csak
csendben nem csinál semmit.

### 22.2 Git-archeológia: a hiba nem az enyém volt, hanem egy elveszett upstream javítás

A mod gyökerében **valódi git repó van, teljes upstream történelemmel**
(`git log --oneline -- control.lua`). Ez lehetővé tette, hogy ne
találgatással, hanem tényleges korábbi, bevált kóddal javítsam a
problémát:

- `6500afbe` **"2.1: migrate removed/renamed runtime APIs"** (a mod eredeti
  szerzőjétől, Austin Hicks-től) — ez a hivatalos 2.1-migrációs commit.
  Saját commit-üzenete explicit leírja: *"PipeConnection::target is now the
  connected LuaEntity (was a LuaFluidBox)"* — vagyis 2.1-ben a
  `PipeConnection.target` mező típusa **LuaFluidBox-ról LuaEntity-re
  változott**. Ez a commit átnevezte `start.fluidbox.get_pipe_connections(1)`
  → `start.get_fluid_box_pipe_connections(1)`-re és
  `start.neighbours` → `start.underground_belt_neighbour`-ra, **de**
  egy másik, ugyanide tartozó hívást — `con.target.get_pipe_connections(1)
  [1].position` — akkor még nem javított.
- `2aeb947d` **"Fix skipping pipe to ground"** (szintén Austin Hicks-től,
  ezt a fenti commit után) — pontosan ezt a kimaradt hívást fejezte be:
  `con.target.get_pipe_connections(1)[1].position` →
  `con.target.get_fluid_box_pipe_connections(1)[1].position`. Ez a commit
  `git merge-base --is-ancestor` szerint **a jelenlegi ág őse** — tehát
  valaha be lett olvasztva.
- **Viszont** a jelenlegi `HEAD` állapotában (a saját szerkesztéseim előtti
  bázis-verzió) a `control.lua` ezen a ponton **a `2aeb947d` ELŐTTI,
  pre-2.1 kódot tartalmazta** (`start.fluidbox.get_pipe_connections(1)`,
  `con.target.get_pipe_connections(1)[1].position`) — vagyis egy **későbbi
  branch-merge (`git log` szerint egy "merge"/"wip"/"init" jellegű commit)
  visszaállította ezt a fájlrészt egy régebbi állapotra**, elvesztve mind a
  `6500afbe`, mind a `2aeb947d` javítását. Ez okozta a crash-et, amit egy
  korábbi körben észleltem és javítottam — de **csak a crash-et**, mert
  akkor még nem tudtam a `2aeb947d` commit létezéséről, és a saját, új
  javításom (`con.target_position` mező használata) más utat választott,
  ami — mint kiderült — nem ugrik megbízhatóan a szomszédra.

### 22.3 A tényleges, most visszaállított javítás

`control.lua`, a `pipe-to-ground` ág `cursor_skip_iteration`-ben: a
`con.target_position` (egy dokumentált, de a gyakorlatban nem megbízhatóan
működő `PipeConnection` mező — "the absolute position of the connection's
intended target") mindenhol lecserélve
`con.target.get_fluid_box_pipe_connections(1)[1].position`-ra — azaz a
TÁVOLI (target) entitás saját fluidbox-kapcsolat-listájának első elemének
pozíciójára. Ez pontosan a `2aeb947d` commit által már egyszer bevált és
tesztelt megoldás, csak a 2.1-es API-névre frissítve (`get_pipe_connections`
→ `get_fluid_box_pipe_connections`, ugyanaz az átnevezés, mint
`start`-nál). A `con.target`-en hívott metódus is `pcall`-ba csomagolva
(defenzív, ha egy módosított/moddolt entitásnak esetleg nincs ilyen
kapcsolata).

A "last-resort fallback" (`LuaEntity.neighbours`, ha minden más
meghiúsulna) változatlan maradt — továbbra is védőhálóként ott van, bár a
fő javítás után valószínűleg sosem fut le.

### 22.4 Underground belt — újra-ellenőrizve, nem változtatva

A felhasználó együtt jelentette az underground-belt és a pipe-to-ground
ugrást. Az underground-belt ágat (`start.underground_belt_neighbour`,
majd `other_end.position` közvetlen használata) összevetve a `6500afbe`
commit saját, hivatalos javításával: **szóról szóra egyezik** — ez már a
helyes, 2.1-kompatibilis mintát követi, nincs benne `con.target_position`-
szerű buktató. Nem módosítottam. Ha élesben mégis nem ugrik, az egy más
okú, még fel nem tárt hiba lenne — ebben az esetben kérlek írd meg pontosan
(melyik irányba haladva, melyik oldalán az undergroundnak), mert kód-szinten
nem találtam rá magyarázatot.

### 22.5 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`): siker.
- Kérlek teszteld: állj rá egy pipe-to-ground-ra (aminek van párja a föld
  alatt), és nyomj Shift+[a párja felé eső irány]-t — a cursornak most a
  párja pozíciójára kell ugrania, nem csak simán léptetnie egyet.

### 22.6 Kiegészítés — teljes audit: van-e MÁS elveszett 2.1-javítás?

A felhasználó kérése: "nézzd át a 2.1-es változásokat van még bármi amit
felülírtam?" Mivel a 22.2 pontban leírt jelenség (egy régebbi branch-merge
visszaállított egy már javított hunkot a 2.1-migráció előtti állapotra)
elvileg bárhol megtörténhetett volna, nem csak a pipe-to-ground résznél,
szisztematikusan átnéztem **mindhárom** valódi (nem csak dokumentum-)
2.1-migrációs commitot:

- **`6500afbe`** ("2.1: migrate removed/renamed runtime APIs") — 10 fájlt
  érintett (`control.lua` + 9 script). Mindegyiket összevetve a jelenlegi
  HEAD-del (`git diff 6500afbe HEAD -- <fájl>`): **9 fájl** vagy szó szerint
  megegyezik, vagy csak TOVÁBBI, rátett javításokat tartalmaz (pl.
  `scripts/quickbar.lua`-nál a teljes `describe_quick_bar_slot` átírás, ami
  a `1df4c17c` "2.1: announce all quick bar slot kinds" commitból jött, csak
  előre halad, nem visszafelé). **1 fájl** (`control.lua`) mutatott
  visszaállítást — de csak a pipe-to-ground hunkban, semmi másban (a
  `start.underground_belt_neighbour`, a `disabled_by_script`, a
  `cursor_ghost.name`-alapú javítások stb. mind sértetlenek voltak).
- **`c6281059`** ("2.1: make the mod load and pass tests") — 9 fájlt
  érintett. Mindegyik vagy szó szerint megegyezik a HEAD-del, vagy (a
  `locale/en/control-behaviors.cfg` esetében) csak a már ténylegesen
  halott, átnevezett kulcsokat (`cb-field-circuit-exclusive-mode-of-
  operation`, `cb-field-include-fuel`, stb.) takarította ki — ellenőrizve,
  hogy az ÚJ kulcsok (`cb-field-read-fuel`, `cb-field-read-contents`,
  `cb-field-set-requests`) megvannak és be vannak kötve
  `scripts/control-behavior-descriptors.lua`-ban. Nincs regresszió.
- **`1df4c17c`** ("2.1: announce all quick bar slot kinds") — csak
  `scripts/quickbar.lua`-t érintette, a HEAD csak továbbfejleszti (nil-guard
  hozzáadva `get_main_inventory()`-ra), nem ront vissza semmit.

**A hiba forrásának pontos beazonosítása**: `git log --oneline -- control.lua`
+ célzott `git diff`-ek alapján a visszaállítás pontosan a `c309d558` "init"
commitban történt (dzsoker saját, 2026-09-04-i kezdő commitja ezen a
munkamenet-ágon) — ennek szülője (`631eb3f9` "Add pollution level check
command") egy a 2.1-migráció ELŐTTI állapotból ágazott le, és amikor ez az
ág később összeolvadt a 2.1-migrált fő ággal (a `git log`-ban látható
"merge"/"wip" commitok), a pipe-to-ground hunknál a régebbi (dzsoker-ági)
verzió maradt meg a 3-utas merge során, feltehetően mert mindkét oldal
módosította ugyanazt a néhány sort, és a konfliktus-feloldás a rossz oldalt
választotta. A `c309d558` commit egyébként csak 10 fájlt érintett
(túlnyomó részt platform-selector/SA saját munka, új fájlok) — ezek közül
csak a `control.lua` pipe-to-ground hunkja mutatott tényleges API-
regressziót.

**Következtetés**: a 2.1-migráció visszaállítása **kizárólag** a
pipe-to-ground hunkra korlátozódott, és ezt a 22.3 pont már javította.
Semmilyen más elveszett 2.1-javítást nem találtam a három migrációs commit
egyikében érintett egyetlen fájlban sem. (A `804b6689` "Add Factorio 2.1
migration plan" és `54a7b7fa` "Regenerate API docs" commitok csak
dokumentációt érintettek — a `MIGRATION-2.1.md` tervdokumentumot, illetve a
`llm-docs/` API-referenciát — ezekben kód-regresszió fogalmilag sem
lehetséges.)

---

## 23. `[LIGHTNING-BUILDING]` Új warning: konkrét, védtelen épület — nem csak terep-alapú "hole"/"shore gap"

### 23.1 A hiányzó eset

A meglévő `LIGHTNING_HOLE`/`LIGHTNING_SHORE_GAP` warningok (20., 21-22.
pont közötti munka) tisztán TEREP-alapúak: a `build_grid`
(`lightning-zones.lua`) csak azokra a szigetekre (union-find komponensekre)
számol lyukat/partszakasz-rést, amelyeknek **legalább 2 valódi**
(lightning-rod/collector) attraktoruk van — ez szándékos, dokumentált
döntés (egyetlen kör konvex, nem lehet belső lyuka, és egy magányos
attraktor minden apró roncs-foltját "shore gap"-ként jelenteni tiszta zaj
lenne, lásd 20.9 pont).

**Ebből viszont egy valódi vakfolt következik**: ha egy épület egy olyan
szigeten áll, aminek **0 vagy 1** valódi attraktora van (pl. egyáltalán
nincs a közelben collector/rod, csak romok), a `build_grid` ehhez a
szigethez **egyáltalán nem** számol se `holes`-t, se `shore_gaps`-et — tehát
egy teljesen védtelen épület a sziget közepén **sosem** kapott warningot,
függetlenül attól, mennyire véletlenül áll ott. Pontosan ez volt a
felhasználó jelentése: "üresen áll egy sziget közepén, minden collectortól
függetlenül".

### 23.2 A megoldás: közvetlen épület-ellenőrzés, a threshold megkerülésével

`scripts/warnings.lua`, `mod.scan_for_warnings`: új `LIGHTNING_UNPROTECTED_
BUILDING` warning-típus. Ahelyett, hogy a terep-alapú lyuk-detektálást
próbálná bővíteni (ami a fenti threshold-ot is megváltoztatná, zajt okozva
minden apró roncs-foltnál), ez a check **közvetlenül minden valódi,
lehelyezett épületet leellenőriz** `LightningZones.is_covered(surf,
ent.position)`-nal — ez a függvény a nyers `covered` körhalmazt nézi,
teljesen függetlenül a sziget-csoportosítástól és a 2-attraktoros
threshold-tól. Így egy magányos épület egy 0-1-attraktoros szigeten is
azonnal, megbízhatóan warningot kap, ha `is_covered` explicit `false`-t ad
vissza (a `nil` - "nincs is rács ezen a felszínen" - továbbra sem számít
warningnak, ahogy eddig sem).

**Melyik entitás-halmazon fut**: a meglévő `entity_types` globális
(`control.lua`) a tüzelőanyag/áram/lőszer-fogyasztó prototípusokra + a
konténerekre van szűkítve (ez kell a NO_FUEL/NO_POWER/NOT_CONNECTED/
NO_RECIPE warningokhoz) — egy sima fal, vasúti jelző vagy beacon nincs
benne, pedig villám simán eltalálhatja. Ehelyett a szintén `control.lua`-ban
már készen álló, de eddig sehol nem használt `building_types` globálist
használtam (minden `prototype.is_building == true` prototípus-típus,
ugyanaz a felfedezési minta, mint `entity_types`-nál) — ez most kapta meg
az első tényleges felhasználását. A `"character"` típust explicit
kizártam belőle (a `building_types` tartalmazza, mert `control.lua` egy
másik, nem-kapcsolódó okból teszi bele) — a játékos saját magát nem
akarjuk "védtelen épületként" bejelenteni, ráadásul szinte mindig a
térképen tartózkodik, ami állandó zajt jelentene.

### 23.3 Megjelenítés

Ellentétben a `LIGHTNING_HOLE`/`LIGHTNING_SHORE_GAP`-pal (amik szintetikus,
nem-valódi "pozíció" bejegyzések, lásd `synthetic_warning_entity`), ez a
warning **valódi `LuaEntity`-t** ad át — a ténylegesen ott álló épületet.
A warnings-menü megjelenítő kódja (`scripts/ui/menus/warnings.lua`,
`render_warnings`) ezt minden külön kód nélkül helyesen kezeli: az
`entity.object_name ~= "LuaEntity"` ág (a korábbi crash-javításból, 20.13
pont) ide nem lép be, tehát a normál `Localising.get_localised_name_with_
fallback(entity)` út fut, és az épület a saját prototípus-nevével +
pozíciójával jelenik meg — pontosan úgy, mint egy NO_FUEL vagy NO_POWER
bejegyzés.

Új lokalizációs kulcs: `locale/en/warnings.cfg`,
`warning-type-lightning-unprotected-building=Unprotected building` — nincs
külön "label" kulcs szükséges (mint a hole/shore-gap-nél), mert valódi
entitásról van szó, aminek már van neve.

### 23.4 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`): siker.
- Kérlek teszteld: helyezz egy épületet (pl. egy chestet) egy Fulgora
  scrap-folt közepére, ami messze van minden collectortól/rod-tól (esetleg
  csak romok vannak a közelben, vagy semmi) — a warnings menüben most meg
  kell jelennie egy "Unprotected building" kategóriának, ami közvetlenül
  arra az épületre mutat.
- Érdemes azt is ellenőrizni, hogy egy MÁR meglévő, jól védett épület
  (collector hatótávolságán belül) NEM jelenik-e meg tévesen ebben a
  kategóriában.

### 23.5 Kiegészítés — élesben túl sok zaj: `building_types` neutral-force dolgokat is elkapott

Élesben tesztelve a felhasználó jelezte: a warning tényleg működik, DE nem
csak a valódi (player-force) épületekre jelez, hanem a Fulgora természetes
`fulgurite`/`fulgurite-small` ércrögökre és a `fulgoran-ruin-*` romokra is
— ezeket viszont nem lehet és nem is kell "védeni", tiszta zaj minden
egyes védtelen roncs-foltnál.

**Ok**: a `building_types` (`control.lua`, `ent.is_building == true` minden
prototípuson) szélesebb, mint "amit a játékos épített" — a fulgurite és a
romok prototípusai is `is_building = true`-ra vannak állítva (feltehetően
valamilyen szerkesztő/blueprint-belső okból, nem azért mert tényleges
épületek), így a scanner-nél már korábban látott mintával ellentétben
(`SEB.Rock`, resource-kategória) itt simán átcsúsztak a szűrőn.

**Javítás**: `scripts/warnings.lua`, a `LIGHTNING_UNPROTECTED_BUILDING`
blokk — a `find_entities_filtered` hívás mostantól explicit `force =
game.get_player(pindex).force`-ot is átad (natívan, a motor szűri, nem Lua-
oldali utó-ellenőrzés) — ugyanaz a minta, mint amit `scripts/building-
tools.lua:669` már használ (`ent.force == game.get_player(pindex).force`),
illetve amit `scripts/electrical.lua` is használ `find_entities_filtered`
force-paraméterként. Természetes/neutral-force erőforrások és romok sosem
egyeznek a játékos force-ával, tehát mostantól automatikusan kimaradnak -
minden valódi, lehelyezett épület (beleértve az underground beltet is,
amit a felhasználó kifejezetten jónak talált) továbbra is player force-on
van, változatlanul bejelentve marad.

- **Szintaxis-ellenőrizve** (`luac -p`): siker.
- Kérlek teszteld újra: ugyanazon a védtelen szigeten most már csak a
  ténylegesen lehelyezett épületek (pl. underground belt) jelenjenek meg,
  a fulgurite/romok ne.

---

## 24. `[PLATFORMS-NEW-BUTTON]` Új "New Platform" gomb a világmenü Platforms fülén (github #285)

### 24.1 A kérés és a korlátja

A felhasználó kérése: a világmenü Platforms fülén legyen egy gomb, ahol
kiválasztható melyik bolygóra és milyen néven jöjjön létre egy új space
platform, és ez "beküldi a requestet" — a github #285 issue szellemében
("ha megoldható persze").

**Ami NEM oldható meg, és nem is szabad**: `LuaForce.create_space_platform`
mindig egy valódi `space-platform-starter-pack` itemet igényel a platform
"magjaként" — ugyanúgy, mint a vanilla "indítás pályára" folyamat. A
játékban sehol nincs ingyenes/költség nélküli platform-létrehozás, és ha a
mod bevezetne egyet a világmenüből, az gameplay-csalás lenne, nem
accessibility-javítás. Tehát a gomb nem "varázsol" platformot a semmiből —
azt automatizálja, hogy a játékosnak ne kelljen kézzel megkeresnie és
megnyitnia egy konkrét, már felépített, starter packkel megtöltött
rakétasilót (ez volt az egyetlen eddigi út, lásd `rocket-silo-config.lua`
`create_platform` mezője) — helyette a világmenüből egy bolygó
kiválasztásával a mod maga megkeresi az első megfelelő silót azon a
bolygón.

### 24.2 Megvalósítás

`scripts/ui/tabs/platforms-overview.lua` — új `build_new_platform_row`,
mindig hozzáadva a lista végéhez (üres platform-lista esetén is, hiszen
pont akkor a leghasznosabb).

Két lépéses folyamat, a meglévő `Menu`/`KeyGraph` `on_child_result`
mintáját követve (lásd `logistic-group-selector.lua`, egylépéses
változatért):

1. Kattintásra megnyílik a meglévő `scripts/ui/selectors/planet-selector.lua`
   (`Router.UI_NAMES.PLANET_SELECTOR`) — ez már készen állt, minden
   felfedezett/feloldott space location-t listáz.
2. A visszakapott bolygónévre `find_eligible_silo(force, planet_name)`
   megkeresi az adott bolygó felszínén (`game.get_surface(planet_name)`) az
   első player-force rakétasilót, aminek a rakéta-inventoryjában van egy
   `space-platform-starter-pack` típusú item (ugyanaz a keresési logika,
   mint `rocket-silo-config.lua` `new_platform_from_silo`-jában, csak itt
   kell előbb magát a silót is megtalálni, nem csak felhasználni). Ha nincs
   ilyen siló, a játékos kap egy világos üzenetet ("No rocket silo with a
   loaded starter pack found on X"), és a folyamat itt megáll — nincs
   crash, nincs hamis siker.
3. Ha van megfelelő siló, megnyílik egy névbekérő textbox
   (`ctx.controller:open_textbox`).
4. A visszakapott névre a siló friss újra-keresésével (nem a korábbi
   `unit_number`-t bízva, mert időközben változhatott) létrejön a platform
   (`silo.force.create_space_platform{name=..., planet=silo.surface.planet.
   name, starter_pack=pack}`).

A két lépés megkülönböztetése ugyanahhoz a menüponthoz (`node =
"new_platform"`) tér vissza mindkétszer — ezt a `child_context.step`
mezővel ("planet" vs "name") oldottam meg, amit a `open_child_ui`/
`open_textbox` harmadik (context) paramétereként adok át, és amit a Graph
motor (`scripts/ui/key-graph.lua` `on_child_result`) `wrapped_ctx.
child_context`-ként ad vissza — ez már létező, dokumentált mechanizmus, nem
új motor-funkció.

### 24.3 Új lokalizációs kulcsok

`locale/en/ui-platforms-overview.cfg`:
- `platforms-overview-new-platform` — a gomb címkéje
- `platforms-overview-no-eligible-silo` — nincs megfelelő siló az adott
  bolygón
- `platforms-overview-created` — sikeres létrehozás bejelentése

A "név üres" hibaüzenethez a már létező `fa.platform-name-cannot-be-empty`
kulcsot (`locale/en/ui-platform.cfg`) használtam újra, a "nincs starter
pack" hibaüzenethez pedig a már létező `fa.rocket-silo-no-starter-pack`-et
(elvileg elérhetetlen ág, mert `find_eligible_silo` már ellenőrizte, de
`create_platform_from_silo` újra-ellenőriz, ha időközben eltűnt a pack —
védőháló).

### 24.4 Verifikáció (az eredeti, siló-kereső V1 verzióra vonatkozott — lásd 24.5, ez a rész azóta elavult)

- **Szintaxis-ellenőrizve** (`luac -p`): siker.
- ~~Kérlek teszteld: nyisd meg a világmenü Platforms fülét, válaszd a "New
  platform" sort, válassz egy bolygót, ahol van egy silód betöltött starter
  packkel, adj neki nevet — az új platformnak meg kell jelennie a lista
  tetején. Próbáld ki azt is, hogy olyan bolygót választasz, ahol nincs
  megfelelő siló (vagy egyáltalán nincs siló) — ekkor egy világos
  hibaüzenetet kell kapnod, platform létrehozása nélkül.~~ (V1 viselkedés,
  lásd lent)

### 24.5 Kiegészítés — helyes irány: nincs is szükség silóra (`[PLATFORMS-NEW-BUTTON-V2]`)

A felhasználó jelezte, hogy ez nem feltétlen egyezik a vanilla működéssel:
*"Elvileg, lehet olyat csinálni, hogy felküldöd a requestet, a siló pedig
requestel logistic egy starter packet, és felküldi"* — és emlékezett egy
"delayed create" függvényre force/surface/platform kapcsán. Két körben
vizsgáltam:

**1. kör — API-archeológia**: `git log --all -p -S"create_space_platform"`
a mod git-történetében egy régi (fejlesztői/beta) doksi-snapshotban egy
MÁSODIK, `instantly_create_space_platform` nevű függvényt is mutatott a
`create_space_platform` mellett. Ez gyanús volt ("instantly" = azonnali,
szemben egy nem-azonnali változattal), de a jelenlegi, a telepített
játékverzióból generált `llm-docs` doksi-tükörben (`LuaForce.md`) ez a
függvény **sehol nem szerepel** — csak a sima `create_space_platform`. Ez
önmagában nem volt döntő (nem tudtam elérni a tényleges Steam-telepítés
`doc-html/runtime-api.json`-ját innen, csak a mod mappáját), úgyhogy ezt az
utat egyelőre nyitva hagytam.

**2. kör — a felhasználó belinkelte a Factorio wikit**
(https://wiki.factorio.com/Space_platform), ami egyértelműen leírja a
VALÓDI vanilla mechanikát:

> "players may order the creation of a space platform from the remote view
> through the list on the top-left corner of the screen, in which case the
> necessary space platform starter pack is treated as a **request** from a
> not-yet-existing space platform around the specified planet."

Vagyis vanilla is pontosan ezt tudja: remote view-ból, SILÓ NÉLKÜL is
lehet platformot "megrendelni" — a starter pack ilyenkor egy logistics
requestté válik egy még nem is létező platform részéről. Ez visszaigazolta
a felhasználó emlékét, csak nem egy külön "delayed" API-függvényről van szó,
hanem arról, hogy maga a `create_space_platform` MÁR ELEVE ezt csinálja, ha
nem egy konkrét, meglévő itemre (LuaItemStack) hivatkozva hívod meg, hanem
csak egy item-NÉV stringgel:

- `starter_pack` paraméter típusa (`ItemWithQualityID`) elfogadja simán egy
  `string`-et (item-nevet), nem csak egy valódi `LuaItemStack`-et vagy
  inventory-bejegyzést.
- `defines.space_platform_state`-ben létezik `waiting_for_starter_pack`,
  `starter_pack_requested`, `starter_pack_on_the_way` — pontosan ez a
  "még nincs kész, várja a starter packet" közbenső állapot.
- `LuaSpacePlatform:apply_starter_pack()` — *"Applies the starter pack [...]
  if it hasn't already been applied"* — vagyis a starter pack alkalmazása
  külön, később megtörténő lépés.
- `LuaSpacePlatform.hub` explicit optional — *"does not exist if the
  platform has not had the starter pack applied"* — tehát a platform OBJEKTUM
  már létezik (`force.create_space_platform` visszaadja), csak a hub
  (a fizikai épület) nem, amíg a kérés nem teljesül.

**Következtetés**: a `create_space_platform` hívás MINDIG "kérés" jellegű —
akár van már fizikailag ott egy pack (akkor gyorsan teljesül), akár nincs
(akkor a normál logistics-hálózat szállítja ki, ahogy egy requester
chestnél). Ez azt jelenti, hogy **egyáltalán nem kell silót keresni** — a
V1 verzió (24.1-24.4 pont, `find_eligible_silo` és társai) egy téves
feltevésre épült, és most már felesleges.

**A V2 megvalósítás** (`scripts/ui/tabs/platforms-overview.lua`):
- `find_eligible_silo`/`get_loaded_starter_pack`/`create_platform_from_silo`
  törölve — nincs rájuk szükség.
- Új `find_starter_pack_item_name()` — csak azt nézi meg, LÉTEZIK-e
  egyáltalán `space-platform-starter-pack` típusú item-prototípus (típus
  szerint keresve, nem névre hardcodeolva — ugyanaz a védekező minta, mint
  a régi `rocket-silo-config.lua`-beli keresésben).
- `build_new_platform_row`: kattintásra előbb gyors ellenőrzés
  (`force.is_space_platforms_unlocked()`, van-e starter pack item-
  prototípus), utána bolygó-, majd névválasztás, végül egyetlen hívás:
  `force.create_space_platform({name=, planet=, starter_pack=<item-név
  string>})` — se siló, se meglévő item nem kell hozzá.
- **Új rész**: mivel a frissen kért platformnak még nincs hubja (tehát a
  meglévő `build_platform_rows`/`get_sorted_platforms` — ami `platform.hub`-
  ra épül — kihagyja), új `get_pending_platforms`/`build_pending_platform_
  rows` jelenít meg egy külön szekciót a még függőben lévő kérésekhez: név +
  állapot-szöveg (`waiting for starter pack` / `starter pack requested from
  logistics` / `starter pack on the way`, a `defines.space_platform_state`
  alapján), Ctrl+Backspace-re lemondható (`LuaSpacePlatform:destroy()` —
  hub nélkül is működik, *"Schedules this space platform for deletion"*).
  Enélkül a játékos leadna egy kérést, és utána a listában semmi nem
  jelezné, hogy egyáltalán regisztrálódott — rossz élmény lenne,
  főleg vakon.

**Új/módosított lokalizációs kulcsok**
(`locale/en/ui-platforms-overview.cfg`): a V1-es `-no-eligible-silo` kulcs
törölve (feleslegessé vált), helyette `-not-unlocked`,
`-no-starter-pack-item`, `-create-failed`, `-pending-waiting`,
`-pending-requested`, `-pending-on-the-way`, `-pending-cancelled`; a
`-created` szövege pontosított ("Platform __1__ requested, waiting for its
starter pack" — nem állítja hamisan, hogy a platform már készen van).

- **Szintaxis-ellenőrizve** (`luac -p`): siker.
- Kérlek teszteld: nyisd meg a Platforms fület, válassz "New platform"-ot
  egy TETSZŐLEGES bolygóra (nem kell hozzá siló!), adj nevet — a listában
  meg kell jelennie egy függőben lévő bejegyzésnek az állapotával együtt.
  Ha van elérhető logistics-hálózat/gyártás a bolygón, idővel automatikusan
  létre kell jönnie a valódi platformnak (hub megjelenik, átkerül a normál
  lista tetejére). Próbáld ki a Ctrl+Backspace-es lemondást is egy még
  függőben lévő kérésen.

---

## 25. `[SOLAR-STATUS-FIX]` Napelem-státusz bemondás Nauvis-specifikus óra-küszöbök helyett felszín-saját mezőkkel (github #310)

### 25.1 A két bejelentett hardcode és mi lett velük

A github #310 issue két helyet nevez meg:

1. **Kapacitás-képlet** (`cap_add = cap_add * ent.surface.solar_power_
   multiplier * (1 - ent.surface.darkness)`) — jelenleg egyetlen helyen
   található, `scripts/electrical.lua`, `mod.get_electricity_flow_info`.
   **Ellenőriztem: ez már helyes** — mindkét tényező (`surface.solar_power_
   multiplier`, `surface.darkness`) a ténylegesen érintett `power_ent.
   surface`-ről olvasódik ki (a kód `game.surfaces`-en iterál, és minden
   találatnál a saját felszínét használja, lásd a Factorissimo/space-
   platform cross-surface javítás kommentje a függvény elején) — nincs
   Nauvis-ra hardcodeolt érték, ez már bolygófüggetlenül működik. Nem
   nyúltam hozzá.
2. **Idő-alapú napelem-státusz** (`ent_info_solar`, `scripts/fa-info.lua`)
   — ez tényleg hibás volt, lásd 25.2.

### 25.2 A hibás rész és a javítás

A régi kód: `local s_time = ent.surface.daytime * 24` majd fix 6/11/13/18
küszöbök egy kommenttel — *"We observed 18 = peak solar start, 6 = peak
solar end, 11 = night start, 13 = night end"* — vagyis ezek a számok
Nauvison **megfigyelt** (nem dokumentált) értékek voltak, "óra" egységre
átszámolva. A `LuaSurface.daytime` API-dokumentáció szerint ez csak egy
[0,1) tartományú, felszínenként eltérő ciklusú óra — a `dawn`/`morning`/
`evening`/`dusk` mezők (szintén `LuaSurface`, mindegyik "The daytime when X
starts") viszont pontosan az adott felszín SAJÁT átmeneti pontjait adják
meg. Tehát a Nauvis-on megfigyelt 6/11/13/18 más bolygókon (Vulcanus,
Fulgora, Gleba, Aquilo, egy space platform stb.) érvénytelen — ez
pontosan az, amit az issue nyitója is sejtett ("won't work on planets
other than Nauvis").

**Javítás**: a fix küszöbök helyett a felszín saját `dawn`/`morning`/
`evening`/`dusk` mezőit használom. A dokumentáció szerint ezek egy teljes
nap-ciklus (`[0,1)`) négy szakaszát jelölik ki:
- `[dawn, morning)` — világosodik (napkelte) → "increasing"
- `[morning, evening)` — teljes nappali fény → "full production"
- `[evening, dusk)` — sötétedik (napnyugta) → "evening"
- `[dusk, dawn)` (1 fölött visszafordulva 0-ra) — teljes éjszaka → "night"

— ez pontosan ugyanaz a négy kategória, amit a régi kód is bemondott, csak
a döntés alapja lett bolygófüggetlen (a felszín saját mezői, nem
hardcodeolt óraszám).

**Új védőháló**: ha `surface.solar_power_multiplier <= 0` (pl. egy jövőbeli
vagy másik mod által hozzáadott felszín, ahol a napelem elvileg sem
termelhet), a függvény ezt külön jelzi ("no solar power available on this
surface") ahelyett, hogy a négy ciklus-kategória valamelyikébe tévesen
besorolná.

### 25.3 Új lokalizációs kulcs

`locale/en/entity-info.cfg`: `ent-info-solar-no-power=no solar power
available on this surface`. A meglévő négy kulcs (`ent-info-solar-
increasing/full-production/evening/night`) változatlan maradt — csak az
eldöntési logika változott, a szövegek nem.

### 25.4 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`): siker.
- Kérlek teszteld: nézz meg egy napelemet Nauvison különböző napszakokban
  (ellenőrzés: ugyanazt kell mondania, mint korábban, hiszen Nauvis
  dawn/morning/evening/dusk értékei megegyeznek a régi megfigyelt
  6/11/13/18 órákkal) — majd ha van rá mód, egy másik bolygón (pl.
  Vulcanus vagy Fulgora) is, ahol a régi kód feltehetően rosszul mondta be
  a státuszt.

---

## 26. `[CURSOR-SKIP-GHOST-FIX]` + `[LOGISTICS-EXACT-TOGGLE]` Ghost-azonosság javítás a cursor-skipben, és az `exact` logisztikai kapcsoló pótlása

Ez a szakasz a user kétszeres jóváhagyása után írt két KÓD-módosítást
dokumentálja (`"az exact és a skipping mehet"`), a `platform-config`/
`rocket-silo-config`/logisztika-szekció alapos vanilla-újraátvizsgálásával
együtt, amit a user ugyanabban az üzenetben csak VÁLASZKÉNT kért (lásd
27. pont — az ott adott válaszok NEM jártak kódmódosítással).

### 26.1 `[CURSOR-SKIP-GHOST-FIX]` — cursor-skip ghost-azonosság

**A bejelentett hiba**: Shift+WASD/Ctrl+WASD cursor-skip közben, ha egymás
mellett KÜLÖNBÖZŐ prototípusú ghostok vannak (pl. egy kemence-ghost majd
egy összeszerelő-ghost, azonos irányba nézve), a skip átugrott rajtuk,
mintha ugyanaz a dolog folytatódna — vagyis nem állt meg a két különböző
ghost határán.

**Gyökérok** (`control.lua`, `cursor_skip_iteration`, az azonosság-
összehasonlító fő ág, kb. 1505. sor): a kód `start.name ~= current.name`
alapján döntött arról, hogy két szomszédos entitás "ugyanaz" (folytatható
a skip) vagy "más" (meg kell állni). Ghost entitásra azonban a `.name`
(és a `.type`) MINDIG a szó szerinti ghost-placeholder prototípus neve
(`"entity-ghost"`), SOSEM az, amit a ghost valójában ábrázol — az a valódi
azonosság a `.ghost_name`/`.ghost_type` mezőkben van (API-dok: "Name of
the entity or tile contained in this ghost", Subclasses: Ghost). Emiatt a
régi kód szerint MINDEN ghost "ugyanaz a név" volt, függetlenül attól, mit
ábrázolnak — ha még az irányuk is egyezett (gyakori eset: minden ghost
alapállásban észak-néző), a skip átment rajtuk.

**Javítás**: új helyi függvény, `entity_skip_identity(ent)`, ami ghostra
`"ghost:" .. ent.ghost_name`-t ad vissza, egyébként a sima `ent.name`-t —
és az összehasonlítás ezt használja `start.name ~= current.name` helyett.
Ez három esetet garantál helyesen:
1. Két ELTÉRŐ prototípusú ghost → eltérő kulcs → megáll (ez volt a
   bejelentett hiba, most javítva).
2. Két AZONOS prototípusú ghost (folytatódó ghost-sor) → azonos kulcs →
   skip folytatódik, amíg irány is egyezik — ezt már korábban is jól
   csinálta, most is jól csinálja.
3. Valódi (megépült) entitás és egy ugyanolyan prototípusú ghost egymás
   mellett → a `"ghost:"` előtag miatt a kulcsok MINDIG különböznek → megáll
   — ezt a régi kód is helyesen csinálta (mert `"entity-ghost" ~=
   "stone-furnace"` már eredetileg is igaz volt), a javítás ezt nem
   rontja el.

**A user második felvetése** ("ha egybefüggő ghostról leér") — ez, mint a
kódot alaposan átvizsgálva kiderült, MÁR EDDIG IS helyesen működött: a
`current == nil` / `start == nil` ág (amikor a kurzor egy ghost-ról üres
talajra, vagy üres talajról egy ghost-ra ér) mindkét irányban azonnal
megállítja a skipet, mert egy ghost egy érvényes `LuaEntity`, tehát a
"nil → valós entitás" és "valós entitás → nil" átmenetek eddig is
"megállás"-t jelentettek, ghostra és valódi entitásra egyaránt. Ehhez a
részhez NEM kellett kód-módosítás, csak az ellenőrzés, hogy tényleg jól
működik (megerősítve: `control.lua` 1505 körüli ág struktúrája már eddig
is helyesen kezelte a nil-átmeneteket).

A belt-szomszéd-alakzat különleges ág (`start.type == "transport-belt"`)
szándékosan a NYERS `.type`-ot nézi, nem az effektív azonosságot — ghostra
ez sosem `"transport-belt"`, tehát ghostokra ez az ág eddig sem futott és
most sem fut (ghostoknak nincs `belt_neighbours`-uk, hibázna rá).

### 26.2 `[LOGISTICS-EXACT-TOGGLE]` — hiányzó `exact` kapcsoló

`LuaLogisticPoint.exact` (r/w boolean): *"If this logistic point is using
the exact mode. In exact mode robots never over-deliver requests."* —
ez egy valódi, játékos által elérhető vanilla beállítás (a logisztikai
kérés-sor "E" gombja/checkboxa a vanilla GUI-ban), amit ez a mod eddig
sehol nem tett elérhetővé — teljes mod-szintű grep-pel megerősítve nulla
találat volt `exact`-ra a módosítás előtt.

**Hozzáadva**: `scripts/ui/tabs/logistics-unified.lua`, az entitás-szintű
"toggles" sorba, a `trash_unrequested` melletti új `exact` checkbox-item,
ugyanazon feltétellel (`has_requester and #requester_points > 0`), az
első requester/buffer pont `.exact` mezőjéhez kötve (get/set). Új
lokalizációs kulcs: `locale/en/logistics.cfg` →
`logistics-exact=exact requests, don't over-deliver`.

### 26.3 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`): mindkét fájl (`control.lua`,
  `scripts/ui/tabs/logistics-unified.lua`) sikeresen fordult.
- Kérlek teszteld: (a) helyezz el egymás mellé két KÜLÖNBÖZŐ típusú
  blueprint-ghostot azonos irányba nézve, és Shift+WASD-dal futtasd át a
  kurzort rajtuk — most a két ghost határán meg kell állnia; (b) nyiss meg
  egy logisztikai kérés-fület (Ctrl+L) egy requester ládán vagy karakteren,
  és keresd meg az új "exact requests, don't over-deliver" checkboxot a
  meglévő "trash unrequested" mellett.

---

## 27. Vanilla-viselkedés újraátvizsgálás — csak válasz, kód nélkül (a user explicit kérésére)

Ez a szakasz a user pontos kérésére NEM tartalmaz kódot — a mögötte lévő
fájlokban (`platform-config.lua`, `control-behavior-descriptors.lua`,
`logistics-config.lua` stb.) semmi nem változott ezen a ponton. Csak a
válaszok dokumentálása, mert a `factorioaccess-changelog` skill szerint
minden olyan fordulóban frissül a changelog, amiben mod-fájl módosult (l.
26. pont), és ez a válasz-anyag ugyanahhoz a fordulóhoz tartozik.

**1. "Minek akarnék törölni egy platformot? Van ilyen vanillában?"** — a
user jogos kritikája alapján visszavontam ezt a javaslatot. A `destroy`/
`cancel_deletion`/`scheduled_for_deletion` API léte önmagában nem
bizonyítja, hogy ez egy értékes, gyakran használt vanilla GUI-funkció —
csak azt, hogy LÉTEZIK a lehetőség (pl. egy rossz helyre vagy rossz
starter pack-kel megrendelt, még függőben lévő platform visszamondására,
vagy egy már elavult, minden legényét kiürített platform végleges
megszüntetésére). Nincs önálló indoklásom arra, hogy ez gyakori/fontos
művelet lenne — ezért NEM javaslom felvételre, amíg nincs konkrét
használati eset rá.

**2. "A transitional request miért lenne érdekes? Lőjjön ahova akar, úgyse
én vezérlem."** — egyetértek, ez indokolt visszavonás.
`transitional_request_target` egy READ-ONLY mező (melyik platformnak
requestel épp automatikusan a siló) — nincs semmi, amit a játékos ezzel
tenni tudna, csak megnézni. Info-label formában sem ad új, cselekvésre
alkalmas információt azon felül, amit az `auto_satisfy_requests`
checkbox állapota már jelez ("a siló automatikusan requestel-e"). Nem
javaslom.

**3. "Minek elrejteni egy platformot? Van ilyen vanillaban?"** — átnézve a
`LuaSpacePlatform.hidden` API-dokját ("hidden from remote view surface
list") — ez a leírás alapján inkább egy MODDING/scripting célú mező (pl.
egy másik mod ideiglenesen el akar rejteni egy platformot a remote view
listából valamilyen script-cél miatt), nem egy olyan kapcsoló, amit
vanillában a JÁTÉKOS a platform saját GUI-jából állítana. Nem találtam
bizonyítékot arra, hogy a vanilla platform-konfigurációs GUI-ban létezne
ilyen checkbox. Visszavonom ezt a javaslatot is.

**4. "A logisticnél tuti kimaradt egy, a request from planet szekció."** —
ez a user helyes észrevétele volt, és a mélyebb átvizsgálás megerősítette:
a hiba a szekció-SZERKESZTŐ oldalon van, nem a belépési ponton. A Ctrl+L
(`fa-c-l`) billentyű már eddig is generikusan bármelyik entitásra megnyílik,
amire `entity.get_logistic_point()` nem nil (`control.lua`, ~4290-4327.
sor) — a space-platform-hub saját resupply-request pontja tehát elérhető.
A tényleges hiány: `scripts/ui/logistics-config.lua`, `build_logistics_
tabs` KIZÁRÓLAG `entity.get_logistic_sections()`-t hívja, nincs pont-szintű
alternatívája. Ezzel szemben `scripts/ui/tabs/logistics-unified.lua`-ban
VAN egy ilyen alternatíva ("ha `entity.get_logistic_sections()` nil, essen
vissza az első requester/buffer pont saját `.sections`/`.add_section`-jára").
Egy TÖBB-PONTOS entitásnál (rocket silo, platform hub) `entity.get_
logistic_sections()` minden valószínűség szerint `nil`-t ad — hiszen nincs
mód eldönteni "melyik pont szekcióit" kérnéd egy entitás-szintű hívással
(ezt megerősíti a `LuaLogisticSection` dokja is: egy szekció mindig egy
KONKRÉT `LuaLogisticPoint`-hoz vagy `LuaConstantCombinatorControlBehavior`-
hoz tartozik, nem "az entitáshoz" általában). Eredmény: a játékos a
overview fülön (a fallback miatt) TUD hozzáadni egy szekciót a hub
requester pontjához, de a szekció-szerkesztő al-fülek mindig a "nincs
szekció" placeholder-t mutatják utána, mert `all_sections` üres marad —
a szekció tartalma (item/min/max) SOHA nem válik szerkeszthetővé.
**Élesben még nem tesztelt, de erős, mechanizmus-szintű hipotézis.** A
javítás (NEM írva, csak leírva, mert a user csak választ kért): a
`build_logistics_tabs` bővítése úgy, hogy ha `entity.get_logistic_
sections()` nil, essen vissza minden ponton, ahol `supports_sections(point.
mode)` igaz, és pontonként építsen szekció-szerkesztő fület — pont-
indexszel megjelölve, hogy a `logistics-section-editor.lua`
`create_section_tab`-ja tudja, melyik ponton hívja a slot-módosító
metódusokat.

**5. Rocket silo és platform hub — teljes control-behavior/prototype
újraátvizsgálás.**

- **Rocket silo körvezérlés** (`LuaRocketSiloControlBehavior`): egyetlen
  mezője van, `read_mode` (`logistic_inventory`/`none`/`orbital_requests`
  választó) — ez a `scripts/control-behavior-descriptors.lua`
  `[defines.control_behavior.type.rocket_silo]` bejegyzésében TELJESEN
  implementálva van, mindhárom választási lehetőséggel és lokalizációval.
  Itt nincs hiány.
- **Platform hub körvezérlés** (`LuaSpacePlatformHubControlBehavior`): 8
  mezőből 7 implementálva van (`read_contents`, `send_to_platform`,
  `read_moving_from`, `read_moving_to`, `read_speed`+`speed_signal`,
  `read_damage_taken`+`damage_taken_signal`). **Hiányzik: `set_requests`**
  (boolean, r/w) — a hivatalos API-dok ehhez a mezőhöz nem ad leírószöveget
  (üres/hiányzó description), de a név alapján ez valószínűleg azt
  vezérli, hogy a circuit hálózat felülírhatja-e/beállíthatja-e a platform
  logisztikai kéréseit (hasonlóan ahhoz, ahogy más entitásoknál egy
  "set requests via circuit network" kapcsoló szokott működni — pl.
  requester ládáknál a `circuit_set_filters`/hasonló mintát). **Nem
  100%-osan megerősített a pontos futásidejű hatás**, mert az API-dok maga
  sem részletezi — élesben tesztelve tudnám csak biztosan megmondani, mit
  csinál. Javítás (NEM írva, csak leírva): egy új BOOLEAN mező-bejegyzés a
  `space_platform_hub` descriptor-hoz, `set_requests` névvel, a meglévő
  `read_contents` stílusú BOOLEAN mezőkkel azonos mintát követve.
- **Circuit network fül-vezérlés generikussága**: `scripts/ui/tabs/
  circuit-network.lua` (`is_available`, `add_control_behavior_fields`,
  `render_circuit_network`) és `scripts/ui/entity-ui.lua`
  (`build_circuit_network_tabs`, ~301-388. sor) teljesen generikus,
  `entity.get_control_behavior()` + a típus szerinti descriptor alapján
  működik, ENTITÁSTÍPUS-allowlist NÉLKÜL — tehát ez a fül már ma is eléri
  mindkét entitástípust, csak a hub esetén a `set_requests` mező hiányzik
  belőle. Ez nem egy "elérhetetlen" kapcsoló volt, csak egy hiányzó mező.
- **Prototype-szintű mezők** (`RocketSiloPrototype`, `SpacePlatformHubPrototype`):
  a fejléc-szintű átnézés alapján a többség grafika/animáció/hang jellegű,
  fixen a prototípusban rögzített (nem játékos által állítható runtime
  kapcsoló) — pl. `lift_weight`, `cargo_station_parameters`,
  `circuit_wire_max_distance`, `build_grid_size`, `weight`,
  `platform_repair_speed_modifier`. Ezek nem "kimaradt kapcsolók", hanem
  eleve nem játékos-vezérelt, tervezési paraméterek — nem találtam köztük
  olyat, ami egy hiányzó UI-elemre utalna. Ez a rész nem lett kimerítően,
  soronként átvizsgálva (csak a fejléceket néztem át), tehát ha van benne
  mégis valami releváns, az elkerülhette a figyelmemet — szólj, ha van
  konkrét gyanús mező, amit külön megnézzek.

---

## 28. `[CURSOR-SKIP-GHOST-FIX]` kiegészítés (tile-ghost) + a valódi kimaradt logisztikai mező: `import_from`/`request_from`/`minimum_delivery_count`

A user rámutatott, hogy a 26-27. pont még nem volt teljes: (a) a ghost-
azonosság javítás csak entity-ghostra volt kész, tile-ghostra nem, és
(b) a "request from planet" témában a VALÓDI hiányzó dolog nem a
szekció-szerkesztő fül elérhetősége volt, hanem egy konkrét, minden
kérés-slotra vonatkozó mező (pl. "Piercing round: melyik bolygóról
kérje").

### 28.1 `[CURSOR-SKIP-GHOST-FIX]` kiegészítés — `tile-ghost`

A 26.1 pontban írt `entity_skip_identity` helper csak `ent.type ==
"entity-ghost"`-ot kezelte. Kiderült: Factorio-ban a TILE-ghost (egy
tervezett, még nem épült csempe — pl. `space-platform-foundation`,
`landfill`, `refined-concrete` — blueprint-ből lerakva) egy KÜLÖN,
azonos "placeholder" jellegű típus, `ent.type == "tile-ghost"`, aminek a
`.name`-je ugyanúgy mindig a szó szerinti `"tile-ghost"`, a valódi
tervezett csempe neve pedig ugyanúgy `.ghost_name`-ben van — ezt ez a mod
már máshol (`scripts/entity-selection.lua`, `scripts/cursor-changes.lua`,
`scripts/fa-info.lua`) következetesen `entity-ghost`-tal egy családként
kezeli, csak a cursor-skip javítás első köre hagyta ki. **Javítás**:
`entity_skip_identity` mostantól `ent.type == "entity-ghost" or ent.type
== "tile-ghost"` esetén ad `"ghost:" .. ent.ghost_name`-t — tehát egy
`space-platform-foundation` tile-ghost és egy melléje tervezett
`landfill` tile-ghost most helyesen két különböző dolognak számít, és a
skip megáll a határukon.

### 28.2 A "ghost → space" megállás: mit találtam, és mire van szükségem

A user konkrét jelentése: ha egy ghoston állva a kurzor space-be
(üres/beépíthetetlen területre) ér, a skip NEM áll meg. A kód alapos
újraolvasása után (`cursor_skip_iteration`, a `current == nil` ág): ha
`current` (az új pozíción talált entitás) `nil`, ÉS `start` (az induló
entitás) NEM `nil` — ami egy ghoston állva mindig igaz —, a kód
**feltétel nélkül**, a terep-kategória rendszertől (víz/soil, lásd 21.
pont) függetlenül azonnal visszatér (`return moved`), tehát a
sztatikus kód-olvasás szerint EZ AZ ÁG MÁR MOST megállna, amint a
`current` valóban `nil`-lé válik.

Ez azt jelenti, hogy a hiba gyökere valószínűleg NEM ebben az ágban van,
hanem abban, hogy a `current` **nem lesz `nil`** ott, ahol a user szerint
kellene — pl. mert:
- egy nagy (több-csempés) ghost szelekciós doboza a valódi lábnyomán túl
  is "talál" még entitást 1-2 csempével tovább (bounding-box átfedés a
  `find_entities_filtered`-ben), vagy
- a `Viewpoint` a platform szélén valamilyen módon limitálja/klemmeli a
  kurzor pozícióját, és a kurzor valójában nem is mozog tovább, csak a
  `moved` számláló nő, amíg el nem éri a 100-as limitet (ez kívülről
  "nem áll meg, csak a limit-nél" hangként hallható, nem egy éles
  megállásként).

**Ehhez konkrét visszajelzés kellene, hogy pontosan tudjam, melyik ágat
javítsam** (ezt még NEM írtam meg, mert találgatás lenne): (1) a skip a
100 csempés limitig fut (a "nem található változás" hang jön), vagy
megáll, csak túl későn/túl korán? (2) a "ghost" itt egy sima entity-ghost
(pl. egy épület-ghost a platform szélén) vagy egy tile-ghost (pl.
foundation-terv), amiről space-be lépsz? (3) a "space" itt a platform
tényleges széle (nincs több foundation), vagy egy szándékos "lyuk" a
foundation-tervben (aszteroida-gyűjtéshez hagyott rés)?

### 28.3 A valódi kimaradt mező: `LogisticFilter.import_from` / `request_from` / `minimum_delivery_count`

A user pontosított: nem a szekció-fül elérhetősége hiányzik (azt a 27.4
pontban jól azonosítottam, az élő is), hanem egy PER-SLOT mező, ami
megmondja, MELYIK bolygóról/forrásból kérje egy adott itemet (pl.
"Piercing round: preferred/csak Vulcanusról"). Ez a `LuaLogisticSection`
`get_slot`/`set_slot` által kezelt `LogisticFilter` táblának **három**,
eddig teljesen érintetlen mezője (API-dok szerint):

- **`import_from`** (`SpaceLocationID`, opcionális) — "The space location
  to import from." Ez a KONKRÉT bolygó/space-location, amiről az adott
  slotnak importálnia kell (space platform hub requestjeinél).
- **`request_from`** (`RequestFromLocation`: `"planet"` | `"platforms"` |
  `"all"`, opcionális, alapértelmezett `"planet"`) — a forrás TÍPUSA:
  csak bolygóról, csak más platformról, vagy bármelyikről kérje.
- **`minimum_delivery_count`** (`ItemCountType`, opcionális) — a
  minimális mennyiség, amit egyszerre szállítanak egy platformnak (pl.
  "ne szállíts 1 db lövedéket egyesével, csak ha legalább 50 van rajta a
  siló-rakétán").

**Ellenőrzés, hol hiányzik ez a mod-ból**: teljes mod-szintű grep
(`request_from`, `import_from`, `minimum_delivery_count`) nulla találatot
adott a `scripts/`/`control.lua` fákban ezen a körön előtti állapotban.
Konkrétan:
- **Írás oldal** (`scripts/ui/tabs/logistics-section-editor.lua`,
  `render_section`): a per-slot szerkesztő sor jelenleg csak
  `slot.value` (item+quality), `slot.min`, `slot.max` mezőket olvas/ír
  `get_slot`/`set_slot`-tal — `slot.import_from`/`slot.request_from`/
  `slot.minimum_delivery_count` sosincs érintve, tehát a játékos ma
  SEMMILYEN módon nem tudja beállítani, melyik bolygóról kérjen egy adott
  itemet.
- **Olvasás/bemondás oldal** (`scripts/worker-robots.lua`,
  `push_compiled_filter_readout`): a `CompiledLogisticFilter`-ből csak
  `filter.name`/`filter.quality`/`filter.count`/`filter.max_count`
  kerül bemondásra — `filter.request_from`/`filter.minimum_delivery_count`
  sosem, tehát még csak MEG SEM tudod hallani, ha egy meglévő requesten
  már beállítva van (pl. blueprintből importált slot esetén).

**Ez egy valódi, jelentős, teljesen hiányzó funkció** — nem csak egy
elérhetőségi hiba, mint a section-editor fül, hanem egy teljesen
implementálatlan mező-pár mindkét irányban. NEM ÍRTAM MEG (kódot csak
explicit jóváhagyás után írok) — várom a user döntését, hogy ez most
kerüljön-e implementálásra, és ha igen, milyen UI-formában (pl. egy új
gomb a slot-sorban, "preferred source", ami egy `PLANET_SELECTOR`-hoz
hasonló választót nyit `import_from`-hoz, plusz egy 3-állású választó
`request_from`-hoz, plusz egy `minimum_delivery_count` textbox).

### 28.4 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`) a `control.lua` tile-ghost
  kiegészítésre: siker.
- A 28.2 és 28.3 pontokhoz NINCS kód-módosítás ezen a körön — csak
  vizsgálat/válasz, ahogy eddig is, amíg nincs explicit jóváhagyás.

---

## 29. `[LOGISTICS-EXACT-TOGGLE-FIX]` KRITIKUS crash-javítás + `[LOGISTICS-PLATFORM-REQUEST-FIELDS]` target planet / custom minimum payload

### 29.1 KRITIKUS: az `exact` checkbox lecrashelte a játékot — `LuaLogisticPoint::exact is read only`

A user élesben kapott crash-t: `fa-leftbracket` lenyomására (a menürendszer
generikus "aktiválás" gombja) a 26.2 pontban írt `exact` checkbox
`point.exact = v`-t próbált futtatni, és a motor `LuaLogisticPoint::exact
is read only` hibával nem-helyreállítható crash-be küldte a jelenetet.

**A hiba oka bennem**: a 26.2 pontban `LuaLogisticPoint.exact`-ot "read/
write boolean"-ként írtam le. Ez HIBÁS volt — visszaellenőrizve az
API-dokot (`LuaLogisticPoint.md`) pontosan, az `exact` mező bejegyzése
KIZÁRÓLAG egy "**Read type:** `boolean`" sort tartalmaz, "Write type"
sort NEM — ezzel szemben a közvetlenül alatta lévő `trash_not_requested`
mezőnek MINDKÉT sora megvan. Összekevertem a kettőt. Az `exact` tehát a
valós vanilla GUI-ban játékos által kapcsolható, de a scripting API-n
keresztül CSAK OLVASHATÓ — mod nem tudja beállítani, akkor sem, ha a
valódi GUI-ban ott a checkbox.

**Javítás**: `scripts/ui/tabs/logistics-unified.lua` — az `exact` mostantól
NEM `Controls.checkbox` (nincs `set`), hanem egy sima, csak-olvasható
`menu:add_item` label (ugyanaz a "checked"/"unchecked" + szöveg vizuális
formátum, mint egy checkboxnál, csak `on_click` nélkül — tehát nincs mit
elrontania, ha valaki rákattint, egyszerűen nem csinál semmit). Ugyanez a
minta, mint a fájlban már meglévő `section_info` item (csak-label, nincs
`on_click`).

**Verifikáció**: `luac -p` siker; device-oldali olvasással megerősítve,
hogy a `point.exact = v` sor véglegesen eltűnt a fájlból.

### 29.2 `[LOGISTICS-PLATFORM-REQUEST-FIELDS]` — target planet + custom minimum payload

A user pontosította a 28.3 pontban feltárt hiányt egy vanilla-leírással:
minden platform-hub kérésnek van egy **cél bolygója** (alapértelmezetten
az item fő receptjének bolygója, általában Nauvis, csak a platform saját
UI-jából állítható), és egy **"custom minimum payload"** kapcsolója
(alapból kikapcsolva = a rakéta csak teljesen megpakolva indul; ha be van
kapcsolva, egy megadott minimális mennyiséggel is elindulhat). Ez pontosan
a `LogisticFilter.import_from` (cél space-location) és
`LogisticFilter.minimum_delivery_count` (egyedi minimum) mezőknek felel
meg (lásd 28.3).

**Kérés**: csak akkor jelenjen meg, ha a jelenlegi entitás egy space
platform hub — MÁSHOL (requester láda, karakter stb.) ne legyen látható.

**Implementáció** (`scripts/ui/tabs/logistics-section-editor.lua`,
`render_section`): új `is_platform_hub = entity.type ==
"space-platform-hub"` flag; ha igaz, minden request-sorhoz (a meglévő
item/min/max/delete oszlopok közé, a delete elé) két új oszlop kerül:

- **`_target_planet`**: bemondja a jelenlegi cél bolygót (`slot.
  import_from`, lokalizált néven) vagy "default target planet"-et, ha
  nincs beállítva. Kattintásra megnyitja a meglévő `PLANET_SELECTOR`
  UI-t (ugyanaz, amit a platform-schedule szerkesztő is használ
  cél-választásra) — a visszaadott érték egy sima string (space-location
  név), pontosan az `import_from` (`SpaceLocationID` = string) elvárt
  formátuma. Backspace-re (`on_clear`) visszaáll `nil`-re (alapértelmezett
  bolygó).
- **`_min_payload`**: bemondja a jelenlegi egyedi minimumot (`slot.
  minimum_delivery_count`) vagy "default (full rocket)"-et. Kattintásra
  szövegmezőt nyit, ugyanazzal a validációval, mint a meglévő `max`
  mező (nem-negatív, `INT32_MAX`-ig). Backspace-re visszaáll `nil`-re
  (teljes rakéta-kapacitás szükséges, a vanilla alapértelmezés).

Mindkét mező `section.get_slot(i)`/`section.set_slot(i, slot)`-tal
íródik, ugyanazzal a mintával, mint a meglévő min/max mezők.

**Új lokalizációs kulcsok** (`locale/en/logistics.cfg`):
`logistics-target-planet-for`, `logistics-target-planet-default-for`,
`logistics-target-planet-default`, `logistics-min-payload-for`,
`logistics-min-payload-default-for`, `logistics-min-payload-default`,
`logistics-enter-min-payload`.

**Nyitott kérdés (nem ezen a körön)**: a 27.4 pontban feltárt gyanú
(`entity.get_logistic_sections()` esetleg `nil`-t ad több-pontos
entitásra, például egy platform hubra, és ezért a szekció-szerkesztő fül
egyáltalán nem is nyílik meg neki) még nincs élesben megerősítve vagy
megcáfolva. Ha a user azt találja, hogy a platform hub szekció-szerkesztő
füle "no sections" placeholder-t mutat és ez az új két mező sosem látszik,
az pontosan ez a korábban leírt, még nem javított gap — jelezze, és
külön megjavítom.

### 29.3 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`): `logistics-unified.lua` (29.1) és
  `logistics-section-editor.lua` (29.2), mindkettő siker.
- Device-oldali olvasással megerősítve mindhárom fájl (`logistics-
  unified.lua`, `logistics-section-editor.lua`, `logistics.cfg`) valódi
  tartalma.
- Kérlek teszteld: (1) az `exact` sor most már csak bemondja az
  állapotot, nem crashel, ha rákattintasz; (2) egy platform hub kérés-
  során most megjelenik-e a "target planet" és "custom minimum payload"
  oszlop, és nem jelenik-e meg egy requester ládán/karakteren.

---

## 30. `[SOLAR-STATUS-FIX]` kiegészítés (`always_day`) + `[LAUNCH-PLAYER-INVENTORY-CHECK]` — a silóból saját magad kilövése nem ellenőrizte a karakter tárgyait

### 30.1 `[SOLAR-STATUS-FIX]` kiegészítés — `always_day` felszínek (space platform)

A user jelentése: egy space platformon a napelem "no production, night
time"-ot mond, miközben a platformon állandó nappal van, és a panel
ténylegesen termel is.

**Gyökérok**: a 25. pontban írt javítás a Nauvis-specifikus 6/11/13/18
órás hardcode-ot lecserélte a felszín saját `dawn`/`morning`/`evening`/
`dusk` mezőire — ez helyes volt SIMA bolygókra, de nem vette figyelembe
a `LuaSurface.always_day` mezőt ("When set to true, the sun will always
shine"). Egy space platform felszín `always_day = true` — nincs valódi
nappal/éjszaka ciklusa, a sötétség mindig 0, a panel MINDIG teljes
erővel termel. A `dawn`/`morning`/`evening`/`dusk` viszont ettől
FÜGGETLEN, önálló felszín-paraméterek (nem `always_day`-hez kötöttek) —
tehát a `daytime` óra simán kieshetett a `[morning, evening)`
tartományból egy always_day felszínen is, és a kód tévesen "night"-ot
mondott egy olyan helyen, ahol sosincs éjszaka.

**Javítás** (`scripts/fa-info.lua`, `ent_info_solar`): új korai
ellenőrzés — ha `surface.always_day`, a függvény rögtön "full
production"-t mond, a `daytime`-alapú négy-ágú logika előtt, anélkül
hogy hozzáérne. Sima bolygókon (ahol `always_day` mindig `false`)
semmi nem változott.

### 30.2 `[LAUNCH-PLAYER-INVENTORY-CHECK]` — a "launch self to platform" nem ellenőrizte a karakter tárgyait

A user jelentése: úgy tűnik, a siló "launch player" (magad kilövése egy
platformra) funkciója nem nézi, mi van nálad — miközben a vanilla ezt
korlátozza. Kérte: nézzek utána wikin/fórumon/dokumentációban.

**Webes kutatás eredménye** (wiki.factorio.com/Rocket_silo, "Travel to
platform" szakasz, szó szerint idézve): *"the rocket will launch to any
orbiting platform with the player as its sole payload. The player can
only bring any equipped armor, their installed modules, and any
weapons, but no ammo for those weapons."* — tehát a valós vanilla
szabály: a felszerelt páncél (és annak saját equipment gridje/moduljai)
és a fegyverek (de LŐSZER nélkül) mehetnek, a fő inventory ("zsebek")
tartalma viszont NEM.

**A hiányzó ellenőrzés megerősítve helyben is**: a mod által hívott
`LuaEntity.launch_rocket(destination, character)` API-dokja
(`LuaEntity.md`) semmit nem mond a karakter tárgyairól — csak egy
opcionális `character` paramétert vesz át, és `true`/`false`-t ad vissza
arról, hogy megtörtént-e a kilövés. Ez egy tisztán a vanilla GUI oldalán
érvényesített előfeltétel, amit a script API saját maga NEM kényszerít
ki — pontosan úgy, ahogy a user sejtette: "az ellenőrzést nekünk kell
lerendezni". Emellett egy fórum-szál címe is megerősíti ezt közvetve
("[space-age] allow player with inventory travel to space" —
forums.factorio.com/viewtopic.php?t=120204, feature-kérésként, ami arra
utal, hogy alapból NEM lehet tárgyakkal utazni).

**Megjegyzés a bizonytalanságról**: nem találtam elsődleges forrást
pontosan arra, hogy mi történik, ha valaki script-ből (nem a vanilla
gombbal) próbál tárgyakkal kilőni magát — elveszhetnek a tárgyak, vagy
csak egy nem-támogatott állapot jönne létre. Mivel ez potenciálisan
tárgy-vesztéssel járhat, a biztonságos megoldást választottam: a kilövést
MEGAKADÁLYOZOM, ha a karakternél tiltott dolog van, pontosan úgy, ahogy
a valódi vanilla gomb is tenné — nem próbálok automatikusan
áthelyezni/eldobni semmit.

**Implementáció** (`scripts/ui/tabs/rocket-silo-config.lua`): új
`character_has_unlaunchable_items(character)` helper — ellenőrzi, hogy a
`character_main` (fő inventory) és a `character_ammo` (töltény-szektor)
inventory-k ÜRESEK-e. Ha bármelyik nem üres, a kilövés nem indul el, a
user egy beszélt üzenetet kap. Az ellenőrzés KÉT helyen fut, ugyanazzal
a mintával, mint a meglévő "fizikailag jelen kell lenni" ellenőrzés: (1)
a `launch_player` gomb `on_click`-jában, MIELŐTT a platform-választó
megnyílna; (2) a `on_child_result`-ban, MIUTÁN a platform-választóból
visszatért az eredmény (arra az esetre, ha időközben tárgyat vett fel).
A felszerelt páncél (`character_armor`), annak modulja, és a fegyverek
(`character_guns`) SZÁNDÉKOSAN nincsenek ellenőrizve — ezek a wiki
szerint megengedettek.

**Új lokalizációs kulcs** (`locale/en/ui-platform.cfg`):
`rocket-silo-must-empty-inventory-to-launch-self=You must empty your
main inventory and any ammo before launching yourself. Only equipped
armor, its modules, and weapons can travel with you.`

### 30.3 Kiegészítés: kivétel a blueprint-könyvtár eszközöknek

A user kérése: a blueprint, blueprint book, deconstruction planner és
upgrade planner tárgyak maradhassanak a fő inventoryban, ne blokkolják a
kilövést.

**Indoklás** (a user szavaival: "api limitations, library access",
kifejtve): ezek az eszközök valójában a játékos személyes Blueprint
Library-jába mutató hivatkozások — bárhonnan elérhetők, nem a fizikai
példányhoz kötöttek —, nem hagyományos rakomány. A scripting API-nak
nincs eszköze arra, hogy megállapítsa, egy adott blueprint-tárgy tartalma
már biztonságban van-e elmentve oda. Emiatt szigorúnak lenni velük
szemben csak felesleges súrlódás lenne, valódi konzisztencia-előny
nélkül — tehát kivételt kapnak.

**Implementáció** (`scripts/ui/tabs/rocket-silo-config.lua`): új
`LAUNCH_ALLOWED_MAIN_INVENTORY_ITEM_TYPES` halmaz (`blueprint`,
`blueprint-book`, `deconstruction-item`, `upgrade-item` — az item-
prototípus `type` mezője, nem a névre hardcode-olva, hogy modolt
variánsokra is működjön) + új `main_inventory_has_blocking_items(main_inv)`
helper, ami `get_contents()`-en végigmenve (ugyanaz az iterációs minta,
mint a fájl elején lévő `new_platform_from_silo`-ban) minden tárgyra
ellenőrzi a prototípus-típusát a halmaz ellen. `character_has_
unlaunchable_items` mostantól ezt hívja a puszta "üres-e" ellenőrzés
helyett — tehát a fő inventory tartalmazhat blueprint-eket/könyveket/
plannereket, bármi mást viszont még mindig blokkol.

**Frissített lokalizációs szöveg**: `rocket-silo-must-empty-inventory-
to-launch-self=You must empty your main inventory and any ammo before
launching yourself. Only equipped armor, its modules, weapons, and
blueprint-library items can travel with you.`

### 30.4 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`): `scripts/fa-info.lua` és
  `scripts/ui/tabs/rocket-silo-config.lua`, mindkettő siker.
- Kérlek teszteld: (1) egy space platformon a napelem most "full
  production"-t mond-e éjjel-nappal; (2) próbáld meg kilőni magad egy
  siló-fülből úgy, hogy van valami a fő inventoryban vagy lőszered —
  most üzenetet kell kapnod ahelyett, hogy elindulna a kilövés; üres
  inventoryval (csak páncél/fegyver) továbbra is működnie kell; (3)
  ugyanez blueprinttel/blueprint bookkal/decon plannerrel/upgrade
  plannerrel a fő inventoryban — ezekkel most már el kell tudnod indulni.

**Sources** (webes kutatás):
- [Rocket silo - Official Factorio Wiki](https://wiki.factorio.com/Rocket_silo)
- [[space-age] allow player with inventory travel to space - Factorio Forums](https://forums.factorio.com/viewtopic.php?t=120204)

---

## 31. `[BLUEPRINT-LIBRARY-TAB]` Új "Blueprint Library" szekció az inventory viewban — game blueprints / my blueprints fülek

### 31.1 A kérés

A user kérése: legyen egy új tab az inventory view-ban (E gomb), benne a
blueprint library-vel — első a "game blueprints", második a "my
blueprints", elérve Ctrl+Tabbal a szekcióhoz, onnan sima Tabbal a két fül
között. Emellett explicit kérdés: működik-e elvileg a game blueprint
library scriptből olvasva/írva (rw)?

### 31.2 A válasz a kérdésre: igen, de a két polc nem egyforma

A helyi API-doksi (`LuaGameScript.md`, `LuaPlayer.md`, `LuaRecord.md`)
szerint a Blueprint Library ténylegesen KÉT külön polcból áll:

- **`game.blueprints`** (`LuaGameScript.blueprints`, `Array[LuaRecord]`) —
  ez a "game blueprints" fül, mentésen belül megosztott. A `LuaRecord`
  doksija explicit kimondja: az itteni rekordok **read/write**-ok — tehát
  pl. `record.label = "új név"` működik.
- **`player.blueprints`** (`LuaPlayer.blueprints`, `Array[LuaRecord]`) —
  ez a "my blueprints" fül, játékosonkénti. Ugyanaz a doksisor kimondja:
  ezek a rekordok **read-only**-k — írási kísérlet (pl. átnevezés)
  hibázna, ezért ezt a UI meg sem kínálja fel erre a polcra.

Tehát: a game blueprints polc RW-sége elvileg működik, a my blueprints
polcé nem — pontosan ez a különbség vezérli lent a `writable` paramétert.

### 31.3 Két felfedezett API-korlátozás, amit érdemes tudni

Kutatás közben (a korábbi, `exact`-mező crash után tudatosan "van-e
tényleg Write type" fegyelemmel átnézve minden érintett mezőt/metódust)
két valódi korlátozás jött elő:

1. **Nincs élő hivatkozás a kurzorba.** `LuaControl.cursor_record` doksija
   csak `**Read type:** LuaRecord`-ot ad meg, `Write type` sort NEM —
   tehát `player.cursor_record = record` NEM lehetséges, ellentétben pl.
   a szomszédos `cursor_ghost`-tal, aminek van Write type-ja is. Emiatt a
   "megnyitás" itt csak egy FÜGGETLEN MÁSOLATOT tud a kézbe tenni, nem
   élő linket a könyvtári bejegyzésre.
2. **Nincs egyedi törlés.** A `LuaRecord` osztály teljes metódus-listáján
   (export/import, blueprint/entity/tile lekérdezések-beállítások,
   deconstruct/upgrade mapperek stb.) sehol nincs `delete`/`destroy`-
   szerű metódus. Az egyetlen törlés-jellegű API az egész mod-ban
   `LuaGameScript.delete_blueprint_library(player)` — ez viszont a
   TELJES polcot törli egy adott játékosnak, nem egyetlen bejegyzést,
   így túl durva ahhoz, hogy "töröld ezt az egy blueprintet" akcióhoz
   használjuk. Emiatt a UI-ban NINCS delete gomb egyik polcon sem.

### 31.4 A megvalósítás

**Új fájl: `scripts/ui/tabs/blueprint-library.lua`** — a fájl tetején egy
`[BLUEPRINT-LIBRARY-TAB] api limitations, library access` komment (a user
korábbi, 30.3-as kérésének stílusában) foglalja össze a fenti két
korlátozást, közvetlenül a kódban is, nem csak itt a changelogban.

- `record_label(record)` / `describe_record(record)` — rövid, illetve
  típus szerint (blueprint / blueprint-book / deconstruction-planner /
  upgrade-planner) részletesebb felolvasott leírás egy rekordról.
  `record.type` értékei (`"blueprint"`, `"blueprint-book"`,
  `"deconstruction-planner"`, `"upgrade-planner"`) közvetlenül item-NEVEK
  (nem a prototípus-típusok, ellentétben a 30.3-as
  `LAUNCH_ALLOWED_MAIN_INVENTORY_ITEM_TYPES` halmazzal), így közvetlenül
  használhatók `set_stack({name = record.type, ...})`-ban.
- `activate_record(pindex, record)` — a 31.3/1. pontban leírt másolat-
  alapú "megnyitás": `cursor_stack.set_stack({name = record.type, count =
  1})`, majd `cursor_stack.import_stack(record.export_record())`. Ez a
  pontos két lépéses minta már bizonyítottan működik a kódbázisban
  (`scripts/blueprints.lua`: `mod.apply_blueprint_import`,
  `mod.set_stack_bp_from_data`), csak itt egy könyvtári rekordból
  exportálva táplálja be, nem a vágólapról beillesztett szövegből. Előtte
  ellenőrzi, hogy a kéz üres-e (`cursor_stack.valid_for_read`) — ha nem,
  külön üzenetet ad, nem írja felül a kéz tartalmát.
- `render_shelf(records, writable, empty_message)` — közös listázó: minden
  érvényes (`record.valid`) rekordhoz egy sor: kattintható "megnyitás"
  (Enter → `activate_record`), és ha `writable`, egy külön "átnevezés"
  sor (textbox + `record.label = result`, csak a game blueprints polcon).
  `record.is_preview` (megosztott, előnézeti bejegyzés) esetén a
  megnyitás blokkolva van, külön üzenettel.
- `render_game_blueprints`/`render_my_blueprints` → `game.blueprints`
  (`writable = true`) illetve `player.blueprints` (`writable = false`)
  polcra hívja meg `render_shelf`-et.
- `mod.game_blueprints_tab`/`mod.my_blueprints_tab` — `KeyGraph.
  declare_graph({...})`-pal exportálva, KÜLÖN `TabList`/`UiRouter.
  register_ui` hívás NÉLKÜL — ugyanaz a "beágyazható tab" minta, mint
  `scripts/ui/tabs/equipment-overview.lua` `mod.equipment_overview_tab`-ja
  (szemben a `blueprint-book-menu.lua`/`blueprints-menu.lua` saját popup
  UI-t regisztráló mintájával, ami itt nem alkalmazható, mert ez nem
  kurzor-tartalom-függő popup, hanem a mindig nyitva lévő inventory view
  egy állandó szekciója).

**`scripts/ui/menus/main-menu.lua`** — új `local blueprint_library =
require("scripts.ui.tabs.blueprint-library")`, és egy új, MINDIG
látható (nem `is_remote`/`player.character`-hez kötött) szekció a
`sections` tömbben, a research szekció elé beszúrva:
```lua
table.insert(sections, {
   name = "blueprint_library",
   title = { "fa.section-blueprint-library" },
   tabs = {
      blueprint_library.game_blueprints_tab,
      blueprint_library.my_blueprints_tab,
   },
})
```
Azért mindig látható (nem a crafting/inventories mintája szerint karakter-
függő), mert a könyvtár böngészése/átnevezése nem igényel fizikai
jelenlétet vagy karaktert — távoli nézetben (remote view) is ugyanúgy
működik, mint közelről.

**`locale/en/ui-general.cfg`** — új `section-blueprint-library` szekció-
cím kulcs, plusz egy új blokk: `blueprint-library-game-title`,
`blueprint-library-mine-title`, `blueprint-library-game-empty`,
`blueprint-library-mine-empty`, `blueprint-library-preview`,
`blueprint-library-preview-cannot-open`, `blueprint-library-activate-
hint`, `blueprint-library-opened`, `blueprint-library-open-failed`,
`blueprint-library-hand-not-empty`, `blueprint-library-rename`,
`blueprint-library-renamed`. (A rekord-leírásokhoz újrahasznált, MÁR
LÉTEZŐ kulcsok: `fa.unnamed`, `fa.unnamed-book`, `fa.unknown-item`,
`item-name.deconstruction-planner`, `item-name.upgrade-planner` — ezeket
nem kellett újra felvenni.)

### 31.5 Hatókörön kívül / tudatosan kihagyva

- **Nincs törlés** egyik polcon sem — lásd 31.3/2. pont, nincs rá API.
- **Nincs átrendezés/reorder** a game blueprints polcon (a
  blueprint-book-menu.lua drag-up/drag-down mintájával ellentétben) — a
  `LuaGameScript.blueprints` tömb sorrendje nem a mi kezünkben van
  kezelhető módon dokumentáltan, ez egy lehetséges jövőbeli finomítás.
- **Nincs "hozzáadás a könyvtárhoz a kézből"** akció ebben a körben (pl.
  egy tartott blueprint bekerülése a game blueprints polcra) — a user
  kérése kifejezetten a BÖNGÉSZÉSRE/megnyitásra vonatkozott, ez egy
  természetes következő lépés, ha kell.

### 31.6 Kiegészítés — user visszakérdezés: van-e mégis egyedi törlés, és lehet-e "elrakáskor" automatikusan létrehozni egy game blueprints rekordot? Válasz: nem, egyik sem — csak válasz, kód nélkül

A user két dolgot kérdőjelezett meg a 31. pont után: (1) "a recordban lévő
blueprinten közvetlen van delete nem?" — és (2) hogy ha egy blueprintet
elrakok és még nincs a game blueprintsben, a mod tegye oda az
inventory helyett. Mindkettőt újra, a device-en élő doksin frissen
átnézve (nem csak a korábbi kutatásra hagyatkozva):

**1. Egyedi törlés — továbbra sincs, és ez most még alaposabban meg van
erősítve.** A `LuaRecord.md` teljes `### ` fejléc-listáját kigyűjtve
(minden attribútum és metódus, 47 tétel) nincs köztük semmi delete/
destroy/remove-szerű — csak három "clear" metódus van
(`clear_blueprint`, `clear_deconstruction_data`, `clear_upgrade_data`),
ezek viszont a rekord TARTALMÁT ürítik ki (üres blueprinttá teszik),
magát a bejegyzést nem szüntetik meg a polcról. Az egyetlen tényleges
törlés-API változatlanul `LuaGameScript.delete_blueprint_library(player)`,
ami az EGÉSZ polcot törli.

Van viszont egy érdekes találat: a `defines.input_action` enumban
(motorszintű, belső akció-azonosítók, amiket pl. a replay/input-log
rendszer használ) LÉTEZIK `delete_blueprint_record`, `drop_blueprint_
record`, `grab_blueprint_record`, `setup_single_blueprint_record` —
ezek pontosan azok a lépések, amiket a vanilla GUI küld a motornak, amikor
a JÁTÉKOS ténylegesen húzogatja/dobja a blueprintet a könyvtár-ablakban.
DE: a `LuaBootstrap` (`script`) teljes metódus-listáját is átnézve, a
mod-oknak elérhető `raise_*` hívások szigorúan felsorolt, zárt listát
alkotnak (`raise_event`, `raise_console_chat`, `raise_player_crafted_
item`, `raise_player_fast_transferred`, `raise_biter_base_built`,
`raise_market_item_purchased`, `raise_script_built/destroy/revive/
teleported/set_tiles/destroy_segmented_unit`) — ebben NINCS benne semmi
blueprint-record-related, és nincs is általános "küldj egy tetszőleges
input_action-t" hívás. Tehát ezek az input_action értékek csak
AZONOSÍTÓK (pl. eseménynaplózáshoz), nem hívható API-k — egy mod nem
tudja szintetizálni őket. Változatlan a következtetés: **nincs script-
ből elérhető egyedi törlés.**

**2. Automatikus game-blueprints-be helyezés elrakáskor — ez API szinten
egyáltalán nem megvalósítható, függetlenül attól, hogy hova kötném be.**
Ez egy új, fontosabb felismerés, ami a 31. pontban leírtakon is pontosít:
a `LuaGameScript.blueprints` ÉS a `LuaPlayer.blueprints` doksi-blokkja
KIZÁRÓLAG `**Read type:** Array[LuaRecord]`-ot ad meg — **nincs melléjük
`Write type` sor**. Ez azt jelenti, hogy maga a lista (a polc) nem
írható/bővíthető scriptből — nincs `game.create_blueprint_record(...)`
vagy ezzel egyenértékű gyártó-metódus SEHOL a teljes API-ban (kerestem
"create.*record"/"add.*librar" mintákra minden `classes/*.md` fájlban,
nulla találat a `LuaRecord`/`LuaGameScript`/`LuaPlayer`/`LuaControl`
saját önhivatkozásain kívül). A 31.2 pontban leírt "game blueprints
rekordok read/write-ok" állítás VALÓS, de csak a MÁR LÉTEZŐ rekordok
mezőire vonatkozik (pl. `record.label = "új név"`) — nem arra, hogy új
bejegyzést lehetne indítani a polcon.

Gyakorlati következmény: az egyetlen mód, ahogyan egy bejegyzés
ténylegesen bekerül a "game blueprints" polcra, a JÁTÉKOS saját
kézmozdulata a natív vanilla blueprint-library GUI-ban (ráhúzza a
blueprintet a könyvtár-ablakra) — ez egy tisztán kliens-oldali GUI-
interakció, aminek nincs script-hívható megfelelője. A FactorioAccess
viszont pont ezt a natív GUI-t kerüli meg a saját, akadálymentes
menürendszerével (`inventory-grid.lua` "elrakás" logikája jelenleg
`cursor_stack.swap_stack(inv_stack)`-kel egy konkrét inventory-
SLOT-ba teszi az elrakott tárgyat) — tehát ezen a ponton NINCS mit
átirányítani, mert a célpont (egy új library-rekord) scriptből nem
hozható létre. Emiatt ezt a funkciót nem lehet megépíteni; a 31. pontban
elkészült fül (böngészés/átnevezés/kézbe-másolás a MÁR LÉTEZŐ
bejegyzésekre) a scriptelhetőség tényleges felső határa.

Nem lett fájl módosítva ehhez a ponthoz — a `factorioaccess-changelog`
skill előírása szerint mégis rögzítve van, mert ugyanahhoz a
funkció-kéréshez tartozó, jövőbeli munkát befolyásoló kutatási
eredmény (megelőzi, hogy egy jövőbeli forduló újra nekifusson
ugyanennek a — most már bizonyítottan API-korlát miatt lezárt —
ötletnek).

### 31.8 Kiegészítés — user rámutatott: natívan húzni egérrel nem lehet vakon, tehát a "game blueprints" polc gyakorlatilag sosem tölthető fel innen

A user szomorú, de teljesen jogos észrevétele a 31.6 pont után: a natív
vanilla könyvtár-ablakba húzás — ami a 31.6 pont szerint az EGYETLEN mód,
ahogy egy új bejegyzés valaha bekerül a "game blueprints"/"my blueprints"
polcra — egérrel/látással működő interakció, ami vakon nem elérhető.
Ez azt jelenti, hogy a most elkészült fül gyakorlatban a legtöbb
egyjátékos esetben mindig ÜRESEN fog megjelenni — hacsak nem multiplayer
session, ahol egy MÁSIK (látó) játékos tölti fel a megosztott "game
blueprints" polcot, vagy a bejegyzések már korábbról, más úton
léteznek.

**Változtatás** (`scripts/ui/tabs/blueprint-library.lua`): mindkét fül
mostantól egy mindig látható, első "shelf-info" label-t ad
(`render_shelf` új `info_message` paramétere), ami előre elmagyarázza a
korlátot — nem csak üres polc esetén, hanem akkor is, ha vannak benne
bejegyzések (hogy világos legyen: ÚJAT nem tudsz idehozni, csak a
meglévőket böngészni/átnevezni/kézbe másolni). A szöveg konkrétan a
blueprint bookot ajánlja alternatívaként, mert az (a
`blueprint-book-menu.lua`-n keresztül) teljesen billentyűzet/
képernyőolvasó-barát módon támogat rendezést, átnevezést, hozzáadás-
eltávolítást — pontosan azt a "saját gyűjtemény" funkciót adja, amit a
"game blueprints" polc nem tud biztosítani vakon. A fájl tetején lévő
`[BLUEPRINT-LIBRARY-TAB]` komment is pontosított: az első bekezdés most
explicit kimondja, hogy `LuaRecord` a saját doksija szerint is "a
reference to a record IN the blueprint library" — tehát garantáltan
sosem egy még nem létező bejegyzés létrehozására szolgál —, és a
törlés-korlátozáshoz hozzáadva, hogy a `defines.input_action.delete_
blueprint_record`/`drop_blueprint_record` bejegyzések léteznek ugyan az
enumban, de a `script`/`LuaBootstrap` zárt `raise_*` listája nem
tartalmazza őket, tehát ezek sem hívhatók mod-ból.

**Új/frissített lokalizációs kulcsok** (`locale/en/ui-general.cfg`): új
`blueprint-library-game-info`/`blueprint-library-mine-info` (mindig
megjelenő, blueprint bookra mutató magyarázat); `blueprint-library-
game-empty`/`blueprint-library-mine-empty` szövege változatlan maradt
(rövid, csak akkor jelenik meg, ha a polc tényleg üres — a hosszabb
magyarázat az "info" labelben van, nem duplikálva).

### 31.7 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`): `scripts/ui/tabs/blueprint-
  library.lua` (új fájl, majd a 31.8 kiegészítés után újra) és
  `scripts/ui/menus/main-menu.lua`, mindkettő siker.
- Kérlek teszteld: (1) E-vel nyisd meg az inventory viewot, Ctrl+Tabbal
  keresd meg a "Blueprint Library" szekciót; (2) sima Tabbal válts "Game
  Blueprints" és "My Blueprints" között; (3) mindkét fülön elsőként
  halld a magyarázó "info" mondatot (blueprint book-ra utalva); (4)
  nevezz el egy blueprintet és rakd el (ez a vanilla-viselkedés szerint a
  game blueprints polcra kerül, HA egyáltalán bekerül — lásd 31.8) —
  jelenjen meg a Game Blueprints fülön, legyen átnevezhető; (5) próbáld
  meg "megnyitni" (Enter) egy bejegyzést üres kézzel — kerüljön a
  kezedbe egy használható másolat; (6) próbáld meg tele kézzel — kapj
  "üres kell legyen a kezed" üzenetet felülírás helyett.

---

## 32. `[SINGLE-FLUID-BOX-CRASH-FIX]` KRITIKUS crash-javítás: `LuaSingleFluidBoxControlBehavior doesn't contain key read_contents` Ctrl+Tab-nál

### 32.1 A jelentés

Élesben kapott crash-log (nem a user saját szavaival, hanem a nyers hibaüzenet
beillesztve):

```
Error while running event FactorioAccess::fa-c-tab (ID 303)
LuaSingleFluidBoxControlBehavior doesn't contain key read_contents.
```

A stack trace `circuit-network.lua:59` → `controls.lua:41` →
`key-graph.lua` `search_hint` → `tab-list.lua` `search_hint` →
`router.lua` `refresh_search_cache`/`suggest_search_rehint` →
`tab-list.lua` `_set_active_tab`/`_cycle_section` útvonalon fut — vagyis
a crash a Ctrl+Tab-bal (`fa-c-tab`) való szekció-váltáskor keletkezik,
amikor a router minden regisztrált fülhöz újraszámolja a keresési
hint-et (ehhez minden fül label-függvényét lefuttatja, függetlenül
attól, melyik fül aktív éppen). Ha a játékos épp egy pipe/pipe-to-ground/
storage-tank entitást nézett a circuit network fülön (vagy csak az volt
kiválasztva), ez a crash azonnal, megbízhatóan bekövetkezett.

### 32.2 A hibás rész

**Ugyanaz a hibaosztály, mint a 29.1 pontban (`exact` mező)**: a
`scripts/control-behavior-descriptors.lua` `[defines.control_behavior.
type.single_fluid_box]` bejegyzése egy `read_contents` nevű BOOLEAN
mezőt deklarált — ez a mező viszont EGYÁLTALÁN NEM LÉTEZIK a
`LuaSingleFluidBoxControlBehavior` osztályon (pipe, pipe-to-ground,
storage-tank). A helyi API-dokot (`LuaSingleFluidBoxControlBehavior.md`)
frissen átnézve a valódi, teljes mezőlista: `circuit_exclusive_mode_of_
operation` (enum — `defines.control_behavior.single_fluid_box.
exclusive_mode`: `none`/`send_contents`/`send_segment_contents`),
`read_temperature` (boolean), `temperature_signal` (signal). A
`read_contents` name egyszerűen elírás/tévesztés volt — vélhetően más
entitástípusok (pl. `transport_belt`, `container`) tényleg meglévő
`read_contents` mezőjével keveredett össze.

### 32.3 A javítás

`scripts/control-behavior-descriptors.lua`: a `single_fluid_box`
bejegyzés lecserélve a valódi mezőkre — egy `CHOICE` típusú
`circuit_exclusive_mode_of_operation` mező (három választási lehetőség:
none/send_contents/send_segment_contents, a `roboport`/`transport_belt`
bejegyzéseknél már bevált `choices = {{value=..., label=...}, ...}`
mintát követve), plusz `read_temperature` (BOOLEAN) és
`temperature_signal` (SIGNAL) — ugyanaz a három mező-minta, mint a
`reactor` bejegyzésnél. `[SINGLE-FLUID-BOX-CRASH-FIX]` tag-elve, a
kódban is elmagyarázva, miért.

**Új/újrahasznált lokalizációs kulcsok**
(`locale/en/control-behaviors.cfg`): új `cb-field-single-fluid-box-
exclusive-mode`, `cb-choice-single-fluid-box-exclusive-mode-none/-send-
contents/-send-segment-contents`; a `read_temperature`/`temperature_
signal` mezőkhöz a MÁR LÉTEZŐ `cb-field-read-temperature`/`cb-field-
temperature-signal` kulcsok kerültek újrahasznosításra (ugyanazok, amiket
a `reactor` bejegyzés is használ).

### 32.4 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`): `scripts/control-behavior-
  descriptors.lua`, siker.
- Végignéztem az ÖSSZES `defines.control_behavior.type` bejegyzést a
  `llm-docs/api-reference/runtime/defines/control_behavior/type.md`
  fejléc-listájában — a `single_fluid_box` az EGYETLEN típus, ami
  `LuaSingleFluidBoxControlBehavior`-ra mutat (nincs külön "storage_tank"
  típus), tehát a javítás lefedi mindhárom érintett entitást (pipe,
  pipe-to-ground, storage-tank) egyetlen helyen.
- Kérlek teszteld: (1) állj egy pipe-hoz/pipe-to-ground-hoz/storage-
  tankhoz, nyisd meg a circuit network fülét (Ctrl+L), és Ctrl+Tabbal
  válts másik szekcióra/vissza — ne crasheljen; (2) magán a fülön
  próbáld ki mindhárom "circuit contents reading mode" választást, a
  "read temperature" kapcsolót, és a temperature signal beállítását.

---

## 33. Kutatás + terv: ghost item request (pl. ammo egy gun turret ghostba) — vanillában igen, jelenlegi mod UX-ban NINCS — csak terv, kód nélkül

### 33.1 A kérdés

A user kérdése: vanillában lehet-e módosítani egy ghostot úgy, hogy pl.
ammót "rakjunk" egy gun turret ghostba (mielőtt megépülne) — és meg
tudjuk-e ezt csinálni a jelenlegi mod UX-szal? Kifejezetten csak tervet
kért, kódot nem.

### 33.2 Vanilla válasz: igen, ez egy valós, scriptelhető mechanizmus

A `LuaEntity.insert_plan` mező ("The insert plan for this ghost or item
request proxy", Subclasses: EntityGhost, ItemRequestProxy) **Read ÉS
Write type**-tal is rendelkezik (`Array[BlueprintInsertPlan]`) — tehát
biztonságosan írható, ellentétben a korábbi `exact`/`cursor_record`-féle
csapdákkal. Egy bejegyzés alakja:

```lua
ghost.insert_plan = {
   {
      id = { name = "firearm-magazine", quality = "normal" },
      items = {
         in_inventory = {
            { inventory = defines.inventory.turret_ammo, stack = 0, count = 10 },
         },
      },
   },
}
```

(`defines.inventory.turret_ammo` létező define — ugyanígy van
`artillery_turret_ammo`, `artillery_wagon_ammo`, `car_ammo`,
`spider_ammo` más ammo-tároló ghostokhoz.) Ez pontosan az a mechanizmus,
amit a natív vanilla ghost-GUI használ, amikor a játékos kézzel behúz egy
itemet a ghost előnézeti szlotjába — az így beállított kérést az
építőrobotok automatikusan kielégítik, amikor felépítik a ghostot. A
`LuaEntity.item_requests` (csak Read) ennek a kész, kiszámolt listája —
olvasásra jó, írásra az `insert_plan`-t kell használni. Fontos: az
`insert_plan` mindig a TELJES tömböt cseréli le, tehát egy új kérés
hozzáadásakor a régi tartalmat is újra bele kell írni (nem additív).

A cél-szlot típusát a `LuaEntityPrototype.get_inventory_size(index,
quality)` metódussal lehet előre ellenőrizni — `nil`-t ad vissza, ha az
adott `defines.inventory` egyáltalán nem létezik az adott ghost-
prototípuson (pl. egy lézertoronynak nincs `turret_ammo`-ja), tehát ezzel
védhető ki, hogy rossz entitástípusra próbáljunk kérést írni — ugyanaz az
elővigyázatosság, mint a 29.1/32. pontban tanultak.

### 33.3 Jelenlegi mod-állapot: teljesen hiányzik, méghozzá az UI belépési
pontnál már elakad

Átnézve a teljes kódbázist `item_requests`/`insert_plan`-re — NULLA
találat bárhol a `scripts/` alatt. A ghostokkal kapcsolatos meglévő kód
(`entity-selection.lua`, `cursor-changes.lua`, `entity-access.lua`,
`fa-info.lua`, `rails/*.lua`, `transport-belts.lua`) mind csak
AZONOSÍTÁSRA/OLVASÁSRA használja a ghostokat (K infó, cursor-skip,
sínek), sosem az `insert_plan` írására.

Ennél is fontosabb: a `scripts/ui/entity-ui.lua` `mod.has_ui(entity)`
függvénye (ami eldönti, hogy Enter-re megnyílik-e egy entitás
konfigurációs UI-ja) az `entity-ghost` TÍPUST egyáltalán nem ismeri fel —
sem az `ENTITY_TYPES_WITH_UI` halmazban nincs benne, sem a
`entity.operable and entity.prototype.is_building` fallback nem talál rá
(egy ghost `operable` mezője vélhetően `false`). Tehát ma egy ghost
kiválasztásakor Enter-re EGYSZERŰEN NEM NYÍLIK MEG SEMMILYEN
konfigurációs UI — ez nem egy hiányzó mező egy meglévő fülön, hanem
teljesen hiányzó belépési pont.

### 33.4 Tervezett megoldás (MVP-först, entitás-kategóriák szerint bontva)

**Új tab-fájl** (a `*-config.lua` minta szerint, pl. `scripts/ui/tabs/
ghost-requests-config.lua`), ami:
- felsorolja a ghoston MÁR beállított kéréseket (`entity.item_requests`-
  ből olvasva: item név, mennyiség, quality, cél-inventory emberi néven);
  soronként engedi törölni/mennyiséget módosítani (`insert_plan`
  újraírásával);
- "kérés hozzáadása" akció: a játékos válasszon egy itemet (elsőként a
  SAJÁT kezéből/inventoryjából, nem egy absztrakt katalógusból — ez
  gyorsabb és konzisztens azzal, ahogy pl. az `ammo-selector.lua` már ma
  is a JÁTÉKOS BIRTOKÁBAN lévő tárgyakból szűr), majd `insert_plan`-be
  írja a megfelelő `defines.inventory`/`stack`/`count` hármassal.

**Belépési pont**: `entity-ui.lua` `has_ui()`/`build_entity_sections()`
bővítése úgy, hogy `entity.type == "entity-ghost"` esetén — ha a ghost
alatta lévő prototípusnak van legalább egy kérés-képes inventoryja
(`get_inventory_size` teszt) — bekerüljön ez az új fül a szekciók közé.
Alternatíva: a meglévő `ghost-placement.lua`-ba integrálni, mivel az már
kifejezetten ghost-specifikus logikát tartalmaz — ELDÖNTENDŐ kérdés,
melyik illik jobban a router-struktúrába.

**Első körben támogatandó kategóriák** (a user saját példája, "ammo egy
gun turretbe", ezt már lefedi):
1. **Ammo-szlotos ghostok**: turretek (gun-turret és társai),
   artillery-turret/wagon, car, spidertron — `defines.inventory.
   turret_ammo`/`artillery_turret_ammo`/`artillery_wagon_ammo`/
   `car_ammo`/`spider_ammo`, `get_inventory_size`-zal ellenőrizve
   entitásonként (pl. lézertoronynak nincs).
2. (Következő körre javasolt, NEM ebben a körben): modul-szlotos ghostok
   (assembling-machine, furnace, mining-drill, lab, beacon) és
   üzemanyag-szlotos ghostok (burner entitások, mozdony) — hasonló minta,
   csak más `defines.inventory` és más item-szűrés (modul-kompatibilitás/
   tüzelőanyag-kategória).
3. (Külön, bonyolultabb, később): equipment grid kérések (páncél/jármű
   ghostok) — rács-pozíció matek kell hozzá, nagyobb munka.

### 33.5 A user döntései (AskUserQuestion) — a terv ezek szerint véglegesítve

- **Kategória-scope**: AMMO + MODUL + FUEL egyszerre, egy körben (nem
  csak ammo-val indulunk).
- **Belépési pont**: `entity-ui.lua` bővítése, hogy ghostokra ugyanaz az
  Enter nyissa meg az új fület, mint egy megépült entitásnál (nem külön
  akció a `ghost-placement.lua`-ban).
- **Item-forrás**: TELJES KATALÓGUS (minden, az adott szlotba elvileg
  beleillő item típus, függetlenül attól, van-e belőle a játékosnál) —
  NEM csak a saját kéz/inventory, ellentétben az `ammo-selector.lua`
  mintájával. Ez azt jelenti, hogy egy ÚJ, katalógus-alapú szűrő kell
  (pl. `prototypes.item` végigjárása ammo-kategória/modul-kategória/
  tüzelőanyag-kategória szerint), nem használható közvetlenül a meglévő,
  csak-a-birtokodban-lévő-tárgyakat mutató selectorok.

Kódot ehhez a ponthoz még NEM írtam — ez a forduló is csak terv volt,
a véglegesített scope-pal, a következő fordulóban indulhat a tényleges
implementáció.

---

## 34. `[GHOST-ITEM-REQUESTS]` A 33. pont terve megvalósítva: ammo/modul/fuel kérések ghostokra, teljes katalógusból, ugyanaz az Enter mint épült entitásnál

### 34.1 Áttekintés

A 33. pontban vázolt terv a user "oké, mehet, csináld" jóváhagyása után,
a döntött scope szerint (ammo+modul+fuel egyszerre, ugyanaz az Enter mint
épült entitásnál, teljes katalógus item-forrásként) megvalósítva.

### 34.2 Új fájl: `scripts/ui/tabs/ghost-item-requests.lua`

- `AMMO_INVENTORIES`/`MODULE_INVENTORIES`/`FUEL_INVENTORIES` — jelölt
  `defines.inventory` listák request-típusonként (pl. ammo:
  `turret_ammo`, `artillery_turret_ammo`, `artillery_wagon_ammo`,
  `car_ammo`, `spider_ammo`; modul: `crafter_modules`, `beacon_modules`,
  `lab_modules`, `mining_drill_modules`, `agricultural_tower_modules`;
  fuel: `fuel`) — mind a `llm-docs/api-reference/runtime/defines/
  inventory.md` teljes listájából ellenőrizve, nem kitalálva.
- `find_inventory(prototype, quality, candidates)` — a [SINGLE-FLUID-BOX-
  CRASH-FIX] tanulsága szerint `LuaEntityPrototype.get_inventory_size(
  index, quality)`-vel ELLENŐRZI, létezik-e az adott inventory a
  ghost-on, mielőtt bármit feltételezne róla (nem `nil` → létezik).
- `ammo_categories_set`/`fuel_categories_set` — `prototype.
  attack_parameters.ammo_categories` (Array→Dictionary konvertálva) és
  `prototype.burner_prototype.fuel_categories` (már Dictionary) —
  mindkettő a helyi API-dokból frissen megerősítve. Modulra a meglévő
  `prototype.allowed_module_categories` mezőt használja közvetlenül
  (már Dictionary).
- `get_request_slots(entity)` — az adott ghostra visszaadja, mely
  kérés-típusok (ammo/modul/fuel) alkalmazhatók rá, a fenti ellenőrzések
  alapján. Autó/spidertron ammo esetén (nincs `attack_parameters` az
  ilyen entitásokon — a fegyver maga egy még nem elhelyezett tárgy)
  `categories = nil` = "bármilyen ammo tárgy felajánlva", dokumentálva
  mint tudatos egyszerűsítés.
- `entity.insert_plan` — közvetlenül ez a mező kerül olvasásra ÉS
  írásra (a 33.2 pontban megerősített, mindkét iránnyal rendelkező
  API), NEM az `item_requests` (ami csak egy összesített, pozíció-
  információ nélküli olvasási nézet lenne). `remove_request`/
  `add_request` mindig a TELJES tömböt olvassa újra és írja vissza
  (mert az `insert_plan` írás felülír, nem additív — lásd 33.2).
- `find_free_stack` — megkeresi az első szabad (0-alapú) stack-indexet
  egy adott inventoryban, a jelenlegi `insert_plan` pozíciói alapján.
- UI: kérés-típusonként (ammo/modul/fuel) egy címke + a jelenlegi
  kérések listája (Backspace = törlés, `EntityAccess.
  can_write_to_entity` ellenőrzéssel, mint minden író műveletnél) + egy
  "kérés hozzáadása" akció, ami az `ItemChooser`-t (item_chooser.lua)
  nyitja meg a megfelelő szűrővel/kategóriákkal, és a visszakapott
  itemet a következő szabad slotba írja be alapértelmezett
  mennyiséggel (`default_request_count`: modulnál 1, ammo/fuelnél az
  item saját `stack_size`-a). Mennyiség utólagos módosítása NEM
  támogatott ebben a körben — töröld és vedd fel újra másik választással
  (dokumentálva a fájl tetején is, mint tudatos egyszerűsítés).

### 34.3 `scripts/ui/tabs/item-chooser.lua` bővítése — új AMMO/FUEL
szűrőtípusok, paraméterezhető szűrők

A meglévő `FILTERS` táblát flat `function(proto)` függvényekről
FACTORY függvényekre (`function(params) return function(proto) ... end
end`) állítottam át — ugyanaz a `(proto, params)` minta, amit az
`entity-chooser.lua` `SAME_FAST_GROUP` szűrője már használt, csak itt a
`SignalHelpers.add_item_signals` egyargumentumos `extra_filter`
elvárása miatt egy közbülső factory-lépéssel. Új `FILTER_TYPES.AMMO`/
`FILTER_TYPES.FUEL`, mindkettő opcionális `params.categories`
(Dictionary[string,true]) paraméterrel — hiányzó categories = nincs
szűkítés. A meglévő `MODULE` szűrő is megkapta ugyanezt a `categories`
paramétert (visszafelé kompatibilis: a felső planner hívásai nem adnak
categories-t, tehát a viselkedésük változatlan marad).

**Mellékhatás, amit kezelni kellett**: a `MODULE` szűrő eddig
FELTÉTEL NÉLKÜL felajánlotta a "No module" választást (ez az upgrade
planner modul-csere szabályaihoz kell, ahol egy szlotot "üresre"
lehet állítani). Mivel a ghost-kérések is a MODULE szűrőt használják,
és ott a "No module" fogalmilag értelmetlen (egy ghost-kérés vagy
létezik, vagy egyszerűen nincs felvéve — nincs "kérj semmit" opció),
ezt egy explicit `params.offer_no_module` flag mögé tettem, amit csak
az `scripts/ui/planners/upgrade-planner-menu.lua` két hívása állít be
(`filter_type = MODULE, offer_no_module = true` mindkét helyen) —
enélkül minden más hívás (beleértve az újakat) nem kapja meg ezt az
opciót.

### 34.4 `scripts/ui/entity-ui.lua` — belépési pont

- Új require: `ghost_item_requests_tab`.
- `mod.has_ui(entity)`: az összes meglévő ellenőrzés ELŐTT egy explicit
  `if entity.type == "entity-ghost" then return ghost_item_requests_tab.
  is_available(entity) end` ág — korábban egy ghost sosem ért el idáig
  igaz eredménnyel (`ENTITY_TYPES_WITH_UI` nem tartalmazza, `entity.
  operable` egy ghostra feltehetően hamis), tehát Enterre EGYÁLTALÁN
  NEM nyílt semmi (lásd 33.3).
- `build_entity_sections(pindex, entity)`: a függvény elején egy külön
  ág ghostokra — TELJESEN KIKERÜLI az összes "normál entitásra" írt
  logikát (`sort_inventories`, `build_configuration_tabs`,
  `build_circuit_network_tabs`, `build_equipment_tabs`), amik
  `entity.prototype.type`-ot (egy ghostra ez mindig `"entity-ghost"`,
  SOSEM a valódi típus — az a `entity.ghost_prototype.type`-ban van)
  vagy `entity.get_control_behavior()`-t (ghostra `nil`) ellenőrzik.
  Ehelyett közvetlenül visszaadja a `ghost-item-requests` szekciót +
  a meglévő `get_player_inventory_section()`-t (ugyanaz a kényelmi
  szekció, amit minden más entitás UI is megkap a végén).
- **Ellenőrzött, hogy ez biztonságos**: az `open_entity_ui` további
  kódja (`InventoryUtils.get_main_inventory`, `entity.get_max_
  inventory_index()`) is lefut ghostokra útközben, mielőtt a
  `build_entity_sections` ághoz érne — ezeket külön megnézve: `LuaEntity`
  `Parent: LuaControl`, és a `get_max_inventory_index()` doksija szerint
  mindig számot ad vissza (nem opcionális), tehát egy inventory nélküli
  ghostra biztonságosan `0`-t ad (nem `nil`-t, ami `for i=1,nil`
  hibát okozna) — a ciklus egyszerűen nem fut le. `get_inventory_safe`
  pedig eleve `nil`-biztos minden nem létező inventory indexre. Tehát
  ghostokra ez a kód-út crash nélkül, üres paraméterekkel megy át.

### 34.5 Új/módosított lokalizációs fájlok

- **Új fájl** `locale/en/ghost-item-requests.cfg`: `ghost-requests-
  title`, `ghost-requests-kind-ammo/-module/-fuel`, `ghost-requests-
  item-row`, `ghost-requests-none-for-kind`, `ghost-requests-add`,
  `ghost-requests-removed`, `ghost-requests-added`, `ghost-requests-
  slot-full`.
- `locale/en/ui-general.cfg`: új `section-ghost-requests` kulcs a
  szekció-címekhez.

### 34.6 Hatókörön kívül / tudatosan kihagyva (lásd 33.4/33.5 is)

- Equipment grid kérések (páncél/jármű ghostok) — rács-pozíció matek
  kellene hozzá, nem ebben a körben.
- Autó/spidertron ammo pontos kategória-szűrése — nincs `attack_
  parameters` ezeken az entitásokon script-oldalról (a fegyver maga egy
  tárgy, ami még nincs elhelyezve), ezért minden ammo tárgy fel van
  ajánlva náluk, nem csak a ténylegesen kompatibilis.
  szűrve rá.
- Mennyiség utólagos szerkesztése — törlés + újrafelvétel váltja ki.
- Item minőség (quality) választás a kéréshez — mindig `"normal"`,
  nincs quality-selector bekötve ebben a körben.

### 34.7 Verifikáció

- **Szintaxis-ellenőrizve** (`luac -p`), mind sikerrel: `scripts/ui/
  tabs/ghost-item-requests.lua` (új), `scripts/ui/tabs/item-chooser.lua`,
  `scripts/ui/planners/upgrade-planner-menu.lua`, `scripts/ui/
  entity-ui.lua`.
- Kérlek teszteld: (1) rakj le egy gun turret ghostot (pl. törd le vagy
  blueprintből), nyisd meg Enterrel — jelenjen meg az "Ammo requests"
  cím, "Request an item for this slot" akció; válassz egy tölténytípust
  — kerüljön be a listába, Backspace törölje; (2) ugyanez egy
  assembling machine ghosttal (modul) és egy burner mining drill/kocsi
  ghosttal (fuel); (3) építsd fel a ghostot robotokkal (vagy magad) — a
  kért tárgyaknak tényleg bele kell kerülniük a megfelelő szlotba; (4)
  ellenőrizd, hogy a nem kérés-képes ghostok (pl. fal, szállítószalag)
  Enterre változatlanul NEM nyitnak semmit; (5) az upgrade planner
  modul-szabály szerkesztése (a "No module" opciónak ott továbbra is
  meg kell jelennie) nem tört el.

---

## 35. `[GHOST-REQUESTS-MODULE-ALIAS-FIX]` + darabszám szerkesztés a ghost kéréseknél — a 34. pont két felhasználói hibajelentése alapján

**35.1 Az első jelentés: gun turret ghostnál modul kérés jött fel, pedig neki nincs is modulja.**

A user szó szerint: "gunturretnél feldobta a modulet. Tuttommal neki ilyen nincs."

Igaza volt — ez egy valódi bug volt, nem félreértés. Utánanéztem a Factorio
fórumon, és megerősítést kaptam: a `defines.inventory` értékei NEM
egyediek jelentés szerint — a motor ugyanazt a nyers egész számot
újrahasznosítja különböző entitástípusok inventoryjaihoz (pl.
`defines.inventory.character_ammo` és
`defines.inventory.assembling_machine_modules` is lehet ugyanaz a szám —
egyszerűen csak két név ugyanarra a "4-es szlotra", ami entitástípusonként
mást jelent). A `get_request_slots` korábban öt különböző "modul"
definíciót (`crafter_modules`, `beacon_modules`, `lab_modules`,
`mining_drill_modules`, `agricultural_tower_modules`) próbált ki
`LuaEntityPrototype.get_inventory_size()`-zal a gun turret prototípuson
is — és mivel az egyik ilyen definíció nyers száma egybeesett a turret
valódi ammo-inventoryjának számával, a motor hamisan "igen, van ilyen
inventory"-t válaszolt.

**Javítás:** a `get_request_slots` most nyomon követi (`used_indices`),
melyik nyers `defines.inventory` számokat foglalta már le egy korábban
megtalált, biztosan valódi szlot (ammo mindig elsőként van vizsgálva),
és egy modul/fuel jelölt, ami ugyanarra a számra esik, automatikusan
kimarad — akkor is, ha a `get_inventory_size` hívás önmagában "létezik"
választ adna rá. Ez kódszinten garantáltan helyes (egy entitásnak nem
lehet két különböző jelentése ugyanazon a nyers indexen), nem függ
bizonytalan API mezőnevektől.

**35.2 A második jelentés: miért 1 stack (pl. 100 urán ammo) a default, és miért nem lehet megadni, hogy pontosan mennyit kérjek (pl. 6-ot)?**

A user szó szerint: "miért 1 stack a defaultja és miért nem tudom megadni
mennyit requesteljen? Nem 100 urán ammóval akarom beinitelni a turretet
hanem 6-tal."

Jogos igény — az előző verzióban egy kérés darabszámát csak törléssel és
újra-kéréssel lehetett "módosítani" (ami mindig visszaállt a defaultra).
Most a sor (Enter/kattintás) megnyit egy szövegdobozt, ahol tetszőleges
darabszám megadható (a jelenlegi érték van előre kitöltve, tehát elég
csak felülírni, pl. 100 helyett 6-ot beírni). A darabszám 1 és az item
stack_size-a közé van szorítva (egy szlot fizikailag nem tud több mint
egy stacket tartani), és ha a beírt szám ennél nagyobb, a mod jelzi hogy
a maximumra állította, nem csendben vág vissza. A default kérési
mennyiség (ammo/fuel: teljes stack, modul: mindig 1) változatlan maradt
— ez csak a kiindulópont, amit most már könnyen felül lehet írni.

Modul-szlotoknál a darabszám-szerkesztés szándékosan NINCS bekapcsolva
(minden modul saját szlotot foglal, tehát a "darabszám" ott mindig
pontosan 1) — ott a sor csak törölhető (Backspace), nem szerkeszthető.
Ez egyértelműen jelezve van a felolvasott szövegben is (a modul-sorok
nem mondják, hogy "Enter a darabszám módosításához").

**35.3 Érintett fájlok**

- `scripts/ui/tabs/ghost-item-requests.lua`: `find_inventory` és
  `get_request_slots` kiegészítve a `used_indices` kereszt-ellenőrzéssel
  (35.1); új `set_request_count` helper és a kérés-sorok
  `on_click`/`on_child_result` kezelője a darabszám szerkesztéséhez
  (35.2, csak ammo/fuel szlotoknál).
- `locale/en/ghost-item-requests.cfg`: új kulcsok —
  `ghost-requests-item-row-module`, `ghost-requests-enter-count`,
  `ghost-requests-count-updated`, `ghost-requests-count-clamped`; az
  `ghost-requests-item-row` és `ghost-requests-added` szövege kiegészítve
  az Enter-rel-szerkeszthető utalással.

**35.4 Ellenőrzés**

`luac -p` mindkét érintett fájlon (csak a `.lua` esetében releváns) —
hibátlan. A javítás syntaktikailag ellenőrzött, de az in-game tesztet
(főleg a 35.1 alias-javítást — pl. gun turret ghost most tényleg NE
ajánljon fel modult, viszont artillery turret/wagon, ha van neki valódi
modul inventoryja, azt továbbra is ajánlja fel) a usernek kell elvégeznie
játékban.

---

## 36. `[TRAIN-COUPLE-RESTORE]` Vonat kocsik össze/lekapcsolása — visszahozott funkció, kutatás + terv + implementáció

**36.1 A jelentés**

A user: "nézzd át a player dokumentációt, mindent, volt régen valami g
shift g ctrl shift g whatever vonathoz. Most mintha nem menne, nézz
utána" — majd később: "csináld".

**36.2 Kutatás eredménye**

Végignéztem a teljes `CHANGES.md`-t. Kiderült, hogy ez egy valódi,
dokumentált regresszió volt, nem félreértés:

- Régebben létezett: `G` = életerő/pajzs lekérdezés, `SHIFT+G` = kijelölt
  vasúti kocsi lekapcsolása, `CONTROL+G` = kijelölt vasúti kocsi
  összekapcsolása ("Changed keybinds for health checking and train wagon
  connecting").
- A 0.16.34-es verzióban (2025-12-13, a nagy equipment/fegyverzet
  átalakításnál) ezt írták: "Remove shift+g. This is now in the equipment
  overview." — a `G`-billentyűcsalád át lett hangolva az új equipment
  overview menühöz, és `SHIFT+G` kikerült. A `CONTROL+G`-ről (kocsi
  összekapcsolás) a changelogban említés sincs — az feltehetően ugyanekkor,
  de dokumentálatlanul veszett el.
- Jelen kódban (mielőtt hozzányúltam) csak simán `G` létezett
  (`fa-g` → `kb_read_health_and_armor_stats`), `SHIFT+G`/`CONTROL+G`
  egyáltalán nem volt bekötve semmihez, és a `connect_rolling_stock`/
  `disconnect_rolling_stock` API sehol nem volt meghívva a scriptek
  között (csak a mellékelt API-dokumentációban szerepelt referenciaként).

**36.3 A felhasználó döntése a visszaállítás módjáról**

Egyetlen nyitott tervezési kérdés volt: a `connect_rolling_stock`/
`disconnect_rolling_stock` API egy irányt (`defines.rail_direction.front`
vagy `.back`) vár paraméterül. A user választása: "Próbálja mindkét
irányt automatikusan" — tehát egy gombnyomásra mindkét irányban
megpróbáljuk, és a visszajelzés elmondja, hogy melyik oldalon (vagy
oldalakon) történt tényleges változás.

**36.4 Implementáció**

- `control.lua`: új `EntityAccess` require; új `kb_couple_train_wagon(event,
  connecting)` helper — a `player.selected` (ugyanaz a fogalom, amit a
  kódbázis más egykulcsos entitás-akciói, pl. `kb_mine_access_sounds`,
  már használnak) kijelölt entitáson dolgozik, ellenőrzi hogy az valóban
  gördülőállomány-e (`Consts.ROLLING_STOCK_TYPES`), ellenőrzi az írási
  jogosultságot (`EntityAccess.can_write_to_entity`, ugyanaz a minta mint
  a ghost-requestsnél), majd mindkét irányban meghívja a megfelelő API-t,
  és a két visszatérési érték (`front_ok`/`back_ok`) alapján pontos
  visszajelzést ad (mindkét oldalon / csak az egyiken / sehol sem történt
  változás). Két új `EventManager.on_event` regisztráció: `fa-s-g`
  (lekapcsolás) és `fa-c-g` (kapcsolás).
- `data/input.lua`: két új `custom-input` — `fa-s-g` (SHIFT+G) és `fa-c-g`
  (CONTROL+G), közvetlenül a meglévő `fa-g` mellé, a régi (jelenleg teljesen
  szabad) billentyűkombinációkkal.
- `scripts/consts.lua`: új `mod.ROLLING_STOCK_TYPES` halmaz (locomotive/
  cargo-wagon/fluid-wagon/artillery-wagon) — szándékosan szűkebb, mint a
  meglévő `mod.VEHICLE_TYPES`, ami autót és spidertront is tartalmaz; azok
  nem futnak síneken és nem támogatják a rolling-stock API-t, szóval nem
  akarjuk hogy a gomb rájuk is lefusson.
- `locale/en/train-coupling.cfg` (új fájl): a hét visszajelzés-szöveg
  (nincs kijelölés / mindkét oldalon kapcsolva-lekapcsolva / csak egy
  oldalon / nincs mit kapcsolni-lekapcsolni).
- `locale/en/controls.cfg`: a két új gomb leírása a control-list menühöz.

**36.5 Ellenőrzés**

`luac -p` mindhárom érintett `.lua` fájlon (`control.lua`, `data/input.lua`,
`scripts/consts.lua`) — hibátlan. Az in-game tesztet a usernek kell
elvégeznie: (1) állj egy mozdony vagy kocsi mellé úgy hogy az legyen
kijelölve, próbáld `CONTROL+G`-vel összekapcsolni egy szomszédos kocsival,
majd `SHIFT+G`-vel szétkapcsolni; (2) próbáld ki kijelölés nélkül vagy más
entitáson (pl. egy falon) — ne csináljon semmit, csak jelezze hogy nincs
kijelölve vasúti jármű; (3) próbáld olyan kocsin, aminek nincs szomszédja
egyik irányban sem — jelezze hogy nincs mit kapcsolni.

---

## Függelék: fájl → tag gyors index

| Fájl | Tag(ek) |
|---|---|
| `control.lua` | `[SA-BEVEZETES]`, `[F2.1-BREAK]`, `[SA-REMOTE-NIL]` (több különálló hunk, lásd fent) + `[SA-RESOURCE]` (8f-elő. pont — Free/Guarded a K gombban) + `[MISC]` (11. pont — Alt+I remote view, J javítás; 13. pont — remote view hangok chart-függetlenítve; 17b. pont — J vezetés közben a járműre ugrik; 18. pont Kiegészítés — `player.centered_on` a remote kamera folyamatos jármű-követéséhez) + `[LIGHTNING]` (20.15 pont — a valódi K gomb (`read_coords`) most is ellenőrzi a villám-fedettséget, a Free/Guarded check mellé téve) + `[CURSOR-SKIP-GENERIC]` (21.3 pont — `cursor_skip_iteration` `start_tile_is_water`/`selected_tile_is_water` boolean logikája generalizálva `start_terrain_category`/`selected_terrain_category` kategóriára) + `[PIPE-SKIP-FIX]` (22. pont — pipe-to-ground skip `con.target_position` helyett `con.target.get_fluid_box_pipe_connections(1)[1].position`-t használ, git-archeológiával megtalált, korábban már bevált javítás visszaállítva) + `[CURSOR-SKIP-GHOST-FIX]` (26.1 pont — új `entity_skip_identity` helper, ghostra `.ghost_name`-t használ `.name` helyett az azonosság-összehasonlításban; 28.1 pont — kiegészítve `tile-ghost`-ra is, ami az első körben kimaradt) |
| `scripts/fa-utils.lua` | `[CURSOR-SKIP-GENERIC]` (21.2, 21.4 pont — `tile_is_water` generikus `collision_mask.layers.water_tile` zászlóra átírva; új `CURSOR_SKIP_SOIL_TILE_NAMES_SET` és `get_cursor_skip_terrain_category`) |
| `scripts/sound-model.lua` | `[MISC]` (18. pont — `get_reference_position` vezetés közben mindig a jármű pozícióját adja vissza cursor/character helyett) |
| `scripts/ui/tabs/platforms-overview.lua` | `[MISC]` (14. pont — új fájl, Platforms szekció a világmenübe) + `[PLATFORMS-NEW-BUTTON]` (24. pont — új `build_new_platform_row`, mindig hozzáadva a listához) + `[PLATFORMS-NEW-BUTTON-V2]` (24.5 pont — siló-keresés törölve, request-alapú `create_space_platform`, új pending-platform szekció) |
| `locale/en/ui-platforms-overview.cfg` | `[MISC]` (14. pont — új fájl) + `[PLATFORMS-NEW-BUTTON]` (24. pont) + `[PLATFORMS-NEW-BUTTON-V2]` (24.5 pont — `-no-eligible-silo` törölve, új `-not-unlocked`/`-no-starter-pack-item`/`-create-failed`/`-pending-*` kulcsok) |
| `scripts/ui/tabs/vehicles-overview.lua` | `[MISC]` (15. pont — új fájl, Vehicles szekció, remote driving; 16a. pont — driving-teleport javítás, reach-alapú döntés; 17a. pont — `player.driving` explicit beállítása + no-fuel figyelmeztetés) |
| `locale/en/ui-vehicles-overview.cfg` | `[MISC]` (15. pont — új fájl; 17a. pont — `vehicles-overview-driving-started-no-fuel` kulcs) |
| `scripts/ui/menus/world-menu.lua` | `[MISC]` (14. pont — Platforms szekció; 15. pont — Vehicles szekció bekötve) |
| `data-updates.lua` | `[MISC]` (16b. pont — kísérlet a `next-surface`/`previous-surface` átkötésére, kiderült hogy adat-oldalról nem moddolható, visszavonva, csak egy végleges magyarázó komment maradt a helyén) |
| *(mod könyvtárán kívül)* `config.ini` (`Roaming/Factorio/config/config.ini`) | `[MISC]` (16b. pont — a nyilak/surface-váltás ütközés VALÓDI javítása: `next-surface`/`previous-surface` átkötve Ctrl+Shift+Up/Down-ra a `[controls]` szekcióban; nem mod-fájl, közvetlen fájlrendszer-szerkesztés, ellenőrzés a felhasználó Factorio-újraindítása után) |
| `locale/en/control-messages.cfg` | `[MISC]` (11. pont — remote view üzenetek) |
| `locale/en/controls.cfg` | `[MISC]` (11. pont — fa-a-i vezérlőlista-bejegyzés) |
| `launch_factorio.py` | `[SKIP]` — csak lua-language-server lint-beállítás, nem játék-kód |
| `update_api_docs.py` | `[SKIP]` (10. pont — új fájl, egykattintásos API-doksi frissítő) |
| `locale/en/building-tools.cfg` | `[SA-BEVEZETES]` (+ 2 holt kulcs, `[SKIP]`) |
| `locale/en/entity-info.cfg` | `[FACTORISSIMO]` + `[LIGHTNING]` (20. pont — új `ent-info-lightning-unprotected` kulcs) + `[SOLAR-STATUS-FIX]` (25. pont — új `ent-info-solar-no-power` kulcs) |
| `locale/en/item-info.cfg` | `[MISC]` (19. pont — új `item-info-spoils-in` kulcs) |
| `locale/en/logistics.cfg` | `[SA-QUALITY]` + `[LOGISTICS-EXACT-TOGGLE]` (26.2 pont — új `logistics-exact` kulcs) + `[LOGISTICS-PLATFORM-REQUEST-FIELDS]` (29.2 pont — új `logistics-target-planet-*`/`logistics-min-payload-*`/`logistics-enter-min-payload` kulcsok) |
| `scripts/ui/tabs/logistics-unified.lua` | `[LOGISTICS-EXACT-TOGGLE]` (26.2 pont — új `exact` item az entitás-szintű toggles sorban) + `[LOGISTICS-EXACT-TOGGLE-FIX]` (29.1 pont — KRITIKUS: checkbox (`set`) → csak-olvasható label, mert `LuaLogisticPoint.exact` írása crashelt élesben) |
| `scripts/ui/tabs/logistics-section-editor.lua` | `[SA-QUALITY]` + `[LOGISTICS-PLATFORM-REQUEST-FIELDS]` (29.2 pont — új `_target_planet`/`_min_payload` oszlopok minden request-sorban, `is_platform_hub`-ra gate-elve) |
| `locale/en/ui-upgrade-planner.cfg` | `[MISC]` |
| `locale/en/ui-platform.cfg` | `[SA-BEVEZETES]` (új fájl) + `[LAUNCH-PLAYER-INVENTORY-CHECK]` (30.2 pont — új `rocket-silo-must-empty-inventory-to-launch-self` kulcs) |
| `locale/en/ui-display-panel.cfg` | `[SA-BEVEZETES]` (új fájl) |
| `scripts/area-operations.lua` | `[SA-REMOTE-NIL]` |
| `scripts/build-dimensions.lua` | `[SA-BEVEZETES]` |
| `scripts/building-tools.lua` | `[SA-BEVEZETES]` |
| `scripts/combat.lua` | `[COMBAT-ANOMALIA]` |
| `scripts/combat/aim-assist.lua` | `[COMBAT-ANOMALIA]` |
| `scripts/crafting.lua` | `[SA-REMOTE-NIL]` |
| `scripts/cursor-changes.lua` | `[SA-BEVEZETES]` |
| `scripts/electrical.lua` | `[FACTORISSIMO]` |
| `scripts/entity-selection.lua` | `[FACTORISSIMO]`, `[NEM-KOD]` (visszavonva, nulla nettó diff) |
| `scripts/fa-commands.lua` | `[SA-REMOTE-NIL]` |
| `scripts/fa-info.lua` | `[FACTORISSIMO]` + `[MISC]` (19. pont — `ent_info_item_on_ground` most a K-nál is bemondja a romlásig hátralévő időt) + `[LIGHTNING]` (20. pont — `ent_info_lightning_coverage` handler hozzáadva, majd 20.14-ben eltávolítva/áthelyezve `tile-reader.lua`-ba) + `[SOLAR-STATUS-FIX]` (25. pont — `ent_info_solar` felszín-saját dawn/morning/evening/dusk mezőket használ Nauvis-hardcode helyett; 30.1 pont — kiegészítve `surface.always_day` korai ellenőrzéssel, space platformokra) |
| `scripts/tile-reader.lua` | `[LIGHTNING]` (20.14 pont — `read_tile_inner` most feltétel nélkül, entitástól függetlenül ellenőrzi a villám-fedettséget) |
| `scripts/item-info.lua` | `[FACTORISSIMO]` + `[MISC]` (19. pont — új exportált `get_spoil_info`, bekötve `get_item_stack_info` VERBOSE ágába) |
| `scripts/lightning-zones.lua` | `[LIGHTNING]` (20. pont — új fájl, a teljes fedettségi rács motor: `is_land`, `build_grid`, `is_covered`, `get_warning_entries`) |
| `scripts/scanner/entrypoint.lua` | `[LIGHTNING]` (20. pont — `do_refresh_after_sfx` most meghívja `LightningZones.build_grid`-et End-nél) |
| `scripts/warnings.lua` | `[LIGHTNING]` (20. pont — két új `WARNING_TYPES`: `LIGHTNING_HOLE`, `LIGHTNING_SHORE_GAP`, szintetikus bejegyzések) + `[LIGHTNING-BUILDING]` (23. pont — új `LIGHTNING_UNPROTECTED_BUILDING`, valódi entitás-alapú, `building_types`-ot használja) |
| `scripts/ui/menus/warnings.lua` | `[LIGHTNING]` (20. pont — `render_warnings` label-ága kezel szintetikus, nem-`LuaEntity` bejegyzéseket) |
| `locale/en/warnings.cfg` | `[LIGHTNING]` (20. pont — új típus- és címke-kulcsok) + `[LIGHTNING-BUILDING]` (23. pont — új `warning-type-lightning-unprotected-building` kulcs) |
| `scripts/localising.lua` | `[SKIP]` |
| `scripts/player-init.lua` | `[SA-REMOTE-NIL]` |
| `scripts/quickbar.lua` | `[SA-REMOTE-NIL]` |
| `locale/en/scanner.cfg` | `[COMBAT-ANOMALIA]` (Vulcanus demolisher, 8e. pont, 2. kör — kiegészítve, nem új fájl) + `[CURSOR-SKIP-GENERIC]` (21.6 pont — új `scanner-yumako-soil`/`scanner-jellynut-soil` kulcsok) |
| `scripts/rich-text.lua` | `[FACTORISSIMO]` |
| `scripts/scanner/backends/single-entity.lua` | `[COMBAT-ANOMALIA]` (Vulcanus demolisher, 8e. pont, 2. kör) |
| `scripts/scanner/surface-scanner.lua` | `[COMBAT-ANOMALIA]` (Vulcanus demolisher, 8e. pont) + `[SA-RESOURCE]` (8g. és 8f-elő. pont) + `[CURSOR-SKIP-GENERIC]` (21.5, 21.6 pont — `yumako-tree`/`jellystem` felvéve `BACKEND_NAME_OVERRIDES`-ba SEB.Rock-ra; `GlebaSoilBackend` bekötve; `ephemeral_state_version` 16→17) |
| `scripts/scanner/backends/gleba-soil.lua` | `[CURSOR-SKIP-GENERIC]` (21.6 pont — új fájl, Gleba yumako/jellynut talaj-csempék Terrain-kategóriás scanner backendje, két külön `TileClusterer`) |
| `scripts/scanner/scanner-consts.lua` | `[CURSOR-SKIP-GENERIC]` (21.6 pont — új `YUMAKO_SOIL_PROTOS`/`JELLYNUT_SOIL_PROTOS` listák) |
| `scripts/scanner/backends/territory.lua` | `[SA-RESOURCE]` (8f-elő. pont, új fájl) |
| `scripts/ui/planners/decon-planner-menu.lua` | `[NEM-KOD]` (8f-előelő. pont, valódi UI bugfix) |
| `scripts/sonifiers/combat/enemy-radar.lua` | `[COMBAT-ANOMALIA]` |
| `scripts/sonifiers/combat/spawner-radar.lua` | `[COMBAT-ANOMALIA]` |
| `scripts/sonifiers/vehicle.lua` | `[SA-REMOTE-NIL]` + `[MISC]` (18. pont Kiegészítés 3-4 — ideiglenes drift-DEBUG hozzáadva, majd a diagnózis lezárása után eltávolítva) |
| `scripts/ui/entity-ui.lua` | `[SA-BEVEZETES]` |
| `scripts/ui/menus/crafting.lua` | `[SKIP]` |
| `scripts/ui/menus/main-menu.lua` | `[SA-BEVEZETES]` + `[BLUEPRINT-LIBRARY-TAB]` (31.4 pont — új `blueprint_library` require + mindig látható "Blueprint Library" szekció a `sections` tömbben) |
| `scripts/ui/tabs/blueprint-library.lua` | `[BLUEPRINT-LIBRARY-TAB]` (31. pont — új fájl, `game_blueprints_tab`/`my_blueprints_tab`, `game.blueprints` RW / `player.blueprints` read-only polcok böngészése, másolat-alapú "megnyitás" a kézbe) |
| `locale/en/ui-general.cfg` | `[BLUEPRINT-LIBRARY-TAB]` (31.4 pont — új `section-blueprint-library` + `blueprint-library-*` kulcsok) |
| `scripts/control-behavior-descriptors.lua` | `[SINGLE-FLUID-BOX-CRASH-FIX]` (32.3 pont — KRITIKUS: a `single_fluid_box` bejegyzés hibás `read_contents` BOOLEAN mezője lecserélve a valódi `circuit_exclusive_mode_of_operation` CHOICE + `read_temperature`/`temperature_signal` mezőkre) |
| `locale/en/control-behaviors.cfg` | `[SINGLE-FLUID-BOX-CRASH-FIX]` (32.3 pont — új `cb-field-single-fluid-box-exclusive-mode` + `cb-choice-single-fluid-box-exclusive-mode-*` kulcsok) |
| `scripts/ui/planners/upgrade-planner-menu.lua` | `[MISC]` |
| `scripts/ui/router.lua` | `[SA-BEVEZETES]` |
| `scripts/ui/schedule-editor.lua` | `[SA-BEVEZETES]` |
| `scripts/ui/selectors/planet-selector.lua` | `[SA-BEVEZETES]` (új fájl) |
| `scripts/ui/selectors/platform-selector.lua` | `[SA-BEVEZETES]` (új fájl) + `[MISC]` (12. pont — has_available_platform, crash-javítás) |
| `scripts/ui/selectors/options-selector.lua` | `[MISC]` (12. pont — üres opciólista védőháló) |
| `scripts/ui/tabs/display-panel-config.lua` | `[SA-BEVEZETES]` (új fájl) |
| `scripts/ui/tabs/ghost-placement.lua` | `[SA-BEVEZETES]` (új fájl) |
| `scripts/ui/tabs/infinity-chest-config.lua` | `[SA-QUALITY]` |
| `scripts/ui/tabs/item-chooser.lua` | `[SA-BEVEZETES]` + `[MISC]` (két független rész ugyanabban a fájlban, lásd 2. és 6. pont) |
| `scripts/ui/tabs/platform-config.lua` | `[SA-BEVEZETES]` (új fájl) |
| `scripts/ui/tabs/rocket-silo-config.lua` | `[SA-BEVEZETES]` + `[MISC]` (12. pont — pontos platform-elérhetőség ellenőrzés, crash-javítás) + `[LAUNCH-PLAYER-INVENTORY-CHECK]` (30.2 pont — új `character_has_unlaunchable_items` helper, blokkolja a "launch self" gombot, ha a fő inventory vagy lőszer nem üres) |
| `scripts/ui/tree-chooser.lua` | `[MISC]` |
| `scripts/upgrade-planner.lua` | `[MISC]` |

**Nem érintett, de a diffelés során ellenőrzött**: `CHANGES.md` — teljesen megegyezik a baseline-nal, semmilyen helyi változás nincs benne (ezek a fixek sosem lettek hivatalos changelog-bejegyzésbe felvéve).

---

## Módszertani megjegyzés (miért van két "hang" ebben a dokumentumban)

Ez a dokumentum két forrásból épült:

1. **A közvetlenül dokumentált rész** (8. Combat-anomália szakasz + a 7e./7c./7b. Factorissimo-szál) — ezt a jelenlegi és az azt megelőző beszélgetés-összefoglalóból ismerem pontos "miért"-tel, üzenetről üzenetre.
2. **A csak kódból/kommentekből rekonstruált rész** (1-6. pont, plusz a 7a. alszakasz) — ennek a nyers beszélgetés-előzménye már nem elérhető (többszöri kontextus-kompaktálás miatt elveszett). Ez a rész egy `git diff origin/f2.1` + a diffek automatizált átvizsgálása alapján készült: a *mit* garantáltan pontos (tényleges kódkülönbség), a *miért* ott, ahol a kódban explicit komment volt rá, szó szerint/közel szó szerint idézve van, egyébként a legjobb ésszerű következtetés a diff tartalmából.

Ha egy adott pontnál mélyebb indoklás kell PR-íráshoz, érdemes lehet visszakérdezni rá — a kód maga (kommentekkel együtt) minden esetben ott van a mostani mirror-ban.
