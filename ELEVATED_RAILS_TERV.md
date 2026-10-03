# Elevated rails bekötése a FactorioAccess modba — tervdokumentum

Készült: 2026. október 1. — Fable 5.1 tervezési munka, kód nélkül.
Alap: a FactorioAccess 0.16.57 (factorio_version 2.1) forrás a `C:\Users\kovac\AppData\Roaming\Factorio\mods\FactorioAccess` mappában, a mellé csomagolt `llm-docs/` API-dokumentáció, a `docs/features/*.md` és `devdocs/rail-geometry.md` leírások, valamint a megbízóval közösen már leellenőrzött motor-tények (lásd a prompt Fázis 3–4 anyagát).

Minden fájlhivatkozás a mod gyökeréhez képest értendő. A sorszámok a jelenlegi (2026-10-01-i) állapotra vonatkoznak.

---

## 0. Vezetői összefoglaló

1. A mod sín-kezelése NEM kézzel hardcode-olt geometria, hanem egy egyszer lefuttatott, motorból kinyert tábla (`railutils/rail-data.lua`), amelyet a `scripts/rails/table-extractor.lua` + `/railtable` parancs állít elő a motor saját `LuaRailEnd:get_rail_extensions()` API-jából. Az elevated rails hiánya ezért elsősorban **adathiány**, nem architekturális akadály: a kinyerés seed-listája (`table-extractor.lua` 106–111. sor) csak a 4 földi típust tartalmazza.
2. Ugyanakkor a tábla **sémája** sem elég az elevált világhoz: a kiterjesztések kizárólag `goal_direction` szerint vannak kulcsolva (`table-extractor.lua` 261–274. sor, `railutils/queries.lua` 174–226. sor, `railutils/traverser.lua` `_get_extension`, 130–158. sor). Egy földi egyenes vég előre-irányú kiterjesztése kétféle lehet (egyenes sín VAGY felfelé rámpa), és egy elevált végé is (elevált egyenes VAGY lefelé rámpa) — ezek ugyanarra a kulcsra esnének, és a kinyerés **csendben felülírná** egyiket a másikkal. A sémát ki kell egészíteni a **cél-réteggel** (`RailExtensionData.goal.rail_layer`), amit a kinyerő ma eldob.
3. A 4-típus korlát kb. tíz jól körülhatárolt ponton él (3. fejezet táblázata). Ezek közül a legfontosabb a `scripts/rails/surface-helper.lua` `get_planner_description` (12–55. sor), a `railutils/rail-info.lua` `RailType` enum (10–15. sor), a `railutils/queries.lua` kétirányú táblái (73–82. sor), a `scripts/consts.lua` `RAIL_TYPES` (95–103. sor) és a `railutils/surface-impls/game-surface.lua` `RailPlannerDescription` struktúra (12–16. sor).
4. A rámpa és a támasz két **nem-sín** fogalom a Syntrax/VTD szemszögéből: a rámpa úgy viselkedik, mint egy nagyon hosszú egyenes, amely réteget vált (a Traverser számára "4. kiterjesztés" a meglévő három — egyenes/bal/jobb — mellett, és CSAK kardinális végről indulhat, mert a rámpa 4-irányú); a támasz pedig nem a pálya része, hanem **előfeltétele**: az elevált sín (ghostként és valódiként egyaránt) függ attól, hogy legyen alatta/hatótávon belül támasz vagy rámpa. Ezért a jelenlegi "minden ghost lerakása program-sorrendben, majd minden revive egyben" pipeline (`scripts/rails/syntrax-runner.lua` 135–200. sor) elevált szakaszon **építési sorrend-függő** lesz: támasz/rámpa előbb, sín utána.
5. A támasz-elhelyezéshez nincs motor-shortcut (a vanilla planner automatizmusa kliens-oldali), ezért a modnak saját "support-tervezőre" van szüksége. Ezt egy új, mindkét építési út (Syntrax és a manuális M/,/. virtuális vonat) által közösen használt modulként javaslom (`scripts/rails/support-planner.lua`), amely a VM-kimenet **utófeldolgozásaként** szúr be támasz-elhelyezéseket, a jelölt pozíciókat `LuaSurface.can_place_entity` hívással ellenőrizve. Három algoritmus-vázlatot adok (5. fejezet), a megbízó "ramp + 20 s + ramp → a mod maga rakja le a 3–4 támaszt" ötletét ezek közül az (i) és (ii) változat fedi le, a (iii) pedig a kézi felülbírálás nyelve.
6. A beszéd-oldal (`railutils/rail-describer.lua` → `scripts/rails/announcer.lua` → `scripts/fa-info.lua` / `scripts/tile-reader.lua`) ma **nem tud rétegről**: a leíró csak `RailType`-ot kap, a tile-olvasó a `Consts.RAIL_TYPES` szűrővel az elevált síneket észre sem veszi (ezek a generikus entitás-olvasáson át, a vanilla lokalizált nevükkel jönnek át — ez az, amit a megbízó "már működik"-nek érzékelt). Ráadásul elevált és földi sín **ugyanazon a tile-on** átfedhet (ez az elevált sín fő értelme), ezért a tile-olvasásnak rétegenként, külön mondatban kell beszélnie.
7. A billentyű-kérdés a legégetőbb UX-döntés: a vanilla "Toggle rail layer" G-je háromszorosan foglalt a modban (`fa-g`, `fa-s-g`, `fa-c-g`, `data/input.lua` 772–792. sor), és az upstream #204 vita lezáratlan. A tervben **nem** G-családbeli kombinációt javaslok a rétegváltásra, hanem a virtuális vonat saját billentyű-klaszterébe illeszkedő, a világ-kontextusban ma nem használt kombinációkat (`Shift + Comma` rétegváltás, `Ctrl + Shift + Comma` kézi támasz; részletek a 9. fejezetben), és külön döntési pontként hagyom nyitva, hogy a vanilla G-toggle-t a mod egyáltalán támogassa-e vagy explicit letiltsa.
8. A dokumentáció (`docs/features/rails.md`) egy ponton ellentmond a kódnak (Ctrl vs. Shift a jelző/lánc-jelző választásnál — lásd 1.3.), ezt a bővítéssel egy menetben érdemes rendbe tenni.
9. Munkaméret: a geometria-bővítés (A fázis) néhány napos, mechanikus; a típusrendszer és a Traverser-réteg (B–C fázis) egy-két hetes, de jól tesztelhető offline (a `railutils/tests/` és `syntrax/tests/` meglévő keretei dry-run `test-surface.lua`-val futnak); a support-tervező (E fázis) az egyetlen valódi kutatás-fejlesztés, in-game kísérletezéssel; a beszéd-réteg (F) és a VTD-UX (G) a végén jön.
10. A tervet egy **in-game ellenőrző lista** zárja (11. fejezet): hat olyan motor-viselkedés van, amit dokumentációból nem lehet eldönteni, és amelyek a tervezési döntéseket érdemben befolyásolják (pl. a vanilla `rail` planner `.rails` listája tartalmazza-e az elevált neveket; ghost-elevált-sín lerakható-e támasz-ghost nélkül; a jelző-blueprintnek kell-e `rail_layer` mező). Ezeket a kódolás ELŐTT érdemes lefuttatni.

---

## 1. Kiindulási állapot: a mod jelenlegi sín-architektúrája

### 1.1. A két építési út és a közös gerinc

A felhasználó két módon épít sínt, mindkettő ugyanarra a geometriai gerincre támaszkodik:

**Manuális út — "virtuális vonat" (VTD).** `docs/features/rails.md` "Basic Rail Building: The Virtual Train" szakasza; kód: `scripts/rails/virtual-train-driving.lua` (995 sor). A játékos sín-planner itemmel a kézben rákattint egy sínre (bal zárójel), ezzel "rázár" (`mod.lock_on_to_rail`, 538–602. sor), majd Comma/M/Period billentyűkkel egyesével rakja le a következő darabot (`control.lua` 4216/4250/4279. sor → `mod.on_kb_descriptive_action_name`, 880–951. sor → `extend_forward/left/right`, 661–686. sor → `move_in_direction`, 618–659. sor). Minden lépés: a jelenlegi állapotból Traverser-t épít, lépteti, az új pozíción/irányon megpróbálja lerakni a sínt (`try_build_rail`, 313–320. sor → `try_build_entity`, 154–246. sor), és a lépést a `moves[]` verembe tolja (undo/bookmark alapja).

**Programozott út — Syntrax.** `docs/features/syntrax.md`; kód: `syntrax/lexer.lua` → `syntrax/parser.lua` → `syntrax/compiler.lua` → `syntrax/vm.lua`, majd a futásidejű végrehajtó `scripts/rails/syntrax-runner.lua`. A VM nem rak le semmit: egy **elhelyezés-listát** állít elő (`syntrax.vm.PlacementGroup[]`, `vm.lua` 92–93. sor), amelyben minden csoport több alternatívát tartalmazhat (jelzőknél: normál pozíció vs. alternatív pozíció). A runner csoportonként végigpróbálja az alternatívákat, ghostokat rak, és a végén — normál módban — egyben revive-olja mindet (`syntrax-runner.lua` 135–200. sor). A Syntrax mindig a VTD aktuális állapotából indul (`virtual-train-driving.lua` `execute_syntrax`, 975–993. sor), tehát a VTD-re rázárás előfeltétel; ugyanez igaz a rail-builder menüre (`scripts/ui/menus/rail-builder.lua`, 53–60. sor hívja a `VTD.execute_syntrax`-ot).

**Közös gerinc — `railutils/`.** A `Traverser` (`railutils/traverser.lua`) egy négy mezős állapot: `_rail_type`, `_placement_direction`, `_position`, `_end_direction` (24–27. sor). Három mozgása van: `move_forward/move_left/move_right`, amelyek a `rail-data.lua` tábla `extensions[goal_direction]` bejegyzéseit olvassák, ahol `goal_direction = end_direction + {0, -1, +1} mod 16` (`_get_extension`, 130–158. sor; `move_forward/left/right` 160–174. sor). A jelző-pozíciókat is a tábla adja (`signal_locations.in_signal/out_signal/alt_*`). A `rail-describer.lua` ugyanerről a tábláról és egy `RailsSurface` absztrakcióról (`railutils/rails-surface.lua`, implementációk: `surface-impls/game-surface.lua` éles, `surface-impls/test-surface.lua` teszt) dolgozik.

### 1.2. Hogyan kerül egy sín a világba (lerakási pipeline)

Mindkét út ugyanazt a trükköt használja (`scripts/rails/build-helpers.lua` `place_ghost`, 88–151. sor; a VTD saját, csaknem azonos másolata: `virtual-train-driving.lua` `try_build_entity`, 154–246. sor):

1. A játékos kezét ideiglenes inventoryba menti (`swap_stack`), a kézbe egy üres blueprintet tesz.
2. A `scripts/blueprint-synthesizer.lua` (35 sor) egy **egyetlen entitást** tartalmazó blueprint-stringet gyárt (`name`, `position={0,0}`, `direction`), ezt importálja a kézbe.
3. `player.can_build_from_cursor` + `player.build_from_cursor` a célpozícióra, a kívánt `build_mode`-dal (normal/forced/superforced) — ez a játék saját ütközés- és elhelyezhetőség-ellenőrzését futtatja, de mindig **ghostot** rak.
4. Kéz visszaállítása.
5. A keletkezett ghost megkeresése (`find_expected_ghost`), majd normál módban `ghost.silent_revive()`; forced/superforced módban a ghost marad (robotok építik).

Következmények az elevált világra: (a) a blueprint-szintetizátor generikus, bármilyen entitásnévvel működik, tehát rámpa/támasz/elevált sín szintetizálásához elvben nem kell módosítani — DE a jelzőknél felmerül, hogy az elevált sínhez tartozó jelző blueprint-bejegyzésének kell-e réteg-mező (lásd 11. fejezet, E3 kérdés); (b) a `build_from_cursor` egyetlen entitást épít, semmilyen vanilla planner-automatizmust nem futtat; (c) a `build-helpers.lua` és a VTD párhuzamos másolata két helyen tartja ugyanazt a logikát — a bővítéskor érdemes a VTD-t a `build-helpers`-re terelni, hogy a sorrend-kezelés egy helyen legyen.

A `scripts/building-tools.lua` 227–234. sorában dokumentált motorhiba (a `build_from_cursor` 2.0.72-ig figyelmen kívül hagyta a `cursor_ghost`-ot) itt nem érint minket közvetlenül, mert a sín-pipeline valódi blueprintet tesz a kézbe; a megjegyzés szerint a hiba 2.1-ben javítva van, és az `info.json` már 2.1-et céloz.

### 1.3. A felhasználói dokumentáció és a billentyűzet mai állapota (Fázis 1 eredménye)

- `locale/en/controls.cfg`: a VTD billentyűk nem szerepelnek benne (a `fa-m`/`fa-comma`/`fa-dot` generikus "UI action" bindingek, a VTD-jelentésük csak a `docs/features/rails.md`-ben van leírva). A jelzőlerakó kombinációk igen: 28–31. sor (`fa-c-m` = chain signal left, `fa-s-m` = regular signal left, `fa-c-dot` = chain right, `fa-s-dot` = regular right).
- **Ellentmondás:** `docs/features/rails.md` "Keys" szakasza és a "Basic Rail Building" bekezdése azt írja, hogy Ctrl = normál jelző, Shift = lánc-jelző; a kód (`virtual-train-driving.lua` 923–935. sor: `fa-c-m` → `place_signal(pindex, "left", true)` ahol a harmadik paraméter `is_chain`) és a `controls.cfg` szerint Ctrl = lánc, Shift = normál. A dokumentáció a téves. Ezt a bővítéssel együtt javítani kell, mert az elevált jelzőkre ugyanezek a billentyűk vonatkoznak majd.
- `locale/en/virtual-train-driving.cfg`: a VTD összes üzenete (rázárás, speculation, bookmark, undo, jelző, Syntrax hiba/siker). Itt kell majd az új réteg-üzeneteknek helyet adni.
- `locale/en/rail-announcer.cfg`: a sín-leírás szókincse (vertical/horizontal, 12 átlós irány, kanyar-fallbackok, 90 fokos fordulók 4 pozíciója, ghost/lonely/junction/jelző kulcsok). Nincs benne semmi rétegre, rámpára, támaszra.
- `locale/en/syntrax-program-names.cfg` + `scripts/ui/menus/rail-builder.lua` 19–46. sor: a beépített Syntrax programok (fordulók, elágazások, jelzőpárok). Ide kerülhetnek az elevált alapminták (pl. "fel-rámpa", "le-rámpa", "híd N egyenes").
- `locale/en/tutorial/ch1.txt` 21. sor és `locale/en/message-lists.cfg` 28. sor: a játékost arra kéri, kapcsolja ki az elevated rails-t. A projekt végén ezt kell visszavonni, és a `ch12/ch13/ch15` vonatos fejezeteit (ezek említenek sínt/vonatot) kiegészíteni.
- `docs/features/syntrax.md`: a nyelv teljes leírása — itt kell majd az új szavakat dokumentálni; a "Basic Commands" lista és a chord-szabályok szakasza érintett.
- `devdocs/rail-geometry.md` (588 sor): fejlesztői geometria-referencia, amely a "minden sínvégről pontosan 3 kiterjesztés" szabályt 64/64 esetre igazolja. Az elevált bővítés ezt a szabályt **megváltoztatja** (kardinális végeken 4 kiterjesztés lesz: + rámpa), ezért a devdoc frissítése is a terv része.

---

## 2. Az elevated rails a motor szemszögéből (a tervezés alapjául elfogadott tények)

Ezeket a prompt Fázis 3 anyaga és a mellékelt `llm-docs/` igazolta; itt csak a tervezéshez szükséges következményekkel egészítem ki.

- **Réteg:** `defines.rail_layer = {ground, elevated}`. Az eleváció nem egy entitás-mező, hanem a **prototípus-típus** része: 8 síntípus (4 földi + 4 `elevated-*`), plusz `rail-ramp` (a `RailPrototype` leszármazottja, tehát a motor sínként kezeli: van két vége, `get_rail_end` működik rajta) és `rail-support` (NEM sín: `EntityWithOwnerPrototype`, nincs vége, nem jelenik meg kiterjesztésként).
- **Kiterjesztések:** `LuaRailEnd:get_rail_extensions(planner_item)` → `RailExtensionData{name, position, direction, goal=RailLocation{position, direction, rail_layer}}`. A `goal.rail_layer` az egyetlen hely, ahol a réteg-információ megjelenik; a mod jelenlegi kinyerője ezt **nem menti el** (`table-extractor.lua` 266–273. sor csak `prototype/position/direction/goal_position/goal_direction`-t ír). Ez a séma-hiány a 0. fejezet 2. pontja.
- **Rámpa:** 16×4 mező, 4 irány (kardinális), első 4 mezője szilárd talajon; nem lehet rajta jelző/megálló; `support_range` 15.0 alapértelmezés. A rámpa egyik vége földi, másik elevált réteg — a kinyerésben ezért a rámpa két végének `RailLocation.rail_layer`-je **különböző** lesz; ez a sémában külön eset.
- **Támasz:** `support_range` 15.0, `snap_to_spots_distance` 1.0, `elevated_selection_boxes` 8 doboz, 8 irány, kb. 4×4 ütköződoboz (FFF #378). Wiki: egy támasz kb. 5 egyenes szakaszt (≈10 mező) tart egy irányban, vagy 2 kanyart, vagy 1 kanyar + 3 egyenes keverékét. Vízen/olajtengeren lerakható, bármikor eltávolítható. `not_buildable_if_no_rails` alapértelmezetten false (a vanilla támaszon ennek értéke in-game ellenőrzendő, lásd 11. fejezet E6).
- **Függőség és sorrend:** az elevált sín létezése függ a hatótávon belüli támasztól/rámpától; a boskid-féle hibajegy-magyarázat szerint a blueprint-építés nem tud "ideiglenes állványt" tartani a köztes állapotokhoz. A mod számára ez azt jelenti: a támasz/rámpa ghostját és valódi entitását is **a tőle függő sínek előtt** kell létrehozni, és undo/backspace esetén **utánuk** szabad eltávolítani (különben az eltávolítás kaszkádban viheti a síneket).
- **Nincs planner-API:** a vanilla automatikus támasz-elhelyezés kizárólag az interaktív, húzásos eszközben él. `build_from_cursor` egyetlen entitást épít. A `LuaSurface.can_place_entity{name, position, direction, force, build_check_type, forced, inner_name}` viszont rendelkezésre áll (llm-docs `LuaSurface.md` 346–362. sor), és a `defines.build_check_type` értékei (`manual`, `manual_ghost`, `script`, `script_ghost`, `blueprint_ghost`, `ghost_revive`) lehetővé teszik, hogy a mod a játék saját elhelyezhetőség-logikáját kérdezze meg egy jelölt támasz-pozícióról. Ez a support-tervező alapeszköze.

### 2.1. Mi változik a geometriai modellben

A `devdocs/rail-geometry.md` "Universal Extension Rule"-ja (minden végről pontosan 3 kiterjesztés: egyenes, bal, jobb) elevált világban így módosul:

- Minden **nem-kardinális** végről továbbra is 3 kiterjesztés van, ugyanazon a rétegen (elevált végről elevált darabok, földiről földiek).
- Minden **kardinális** végről 4 kiterjesztés van: a 3 ismert + 1 **rámpa**, amely a réteget váltja (földi végről felfelé rámpa, elevált végről lefelé rámpa). A rámpa `goal.direction`-je megegyezik az egyenes kiterjesztésével — ezért kell a `(goal_direction, goal_layer)` páros kulcs.
- A rámpa saját két végéről: a földi végéről a 3 szokásos földi kiterjesztés, az elevált végéről a 3 szokásos elevált kiterjesztés indul (rámpa rámpára valószínűleg nem fűzhető; ezt a kinyerés egyértelműen megmondja majd).
- A Traverser állapotához egy ötödik mező jön: `_layer` (ground/elevated). Mivel a `RailType` jelenleg szó szerint a prototípus-típusnév, két modellezési lehetőség van (részletesen a 4.2-ben): (A) 9 értékű `RailType` (4 földi + 4 elevált + RAMP), ahol a réteg a típusból következik; (B) 4+1 értékű `RailType` + külön `layer` mező, és a prototípus-nevet a `(RailType, layer)` pár adja. A tervben a (B)-t javaslom alapnak, mert a leíró rendszer (describer) szókincse réteg-független ("vertical", "left of north"…), és így a 4 földi típusra írt összes leíró-logika változatlanul újrahasznosítható; a rámpát viszont saját `RailType.RAMP` értékként célszerű kezelni, mert geometriája egyedi.

---

## 3. A "csak 4 földi típus" korlát pontos előfordulásai

| # | Fájl és hely | Mi korlátoz | Kinek fáj | Javasolt irány |
|---|---|---|---|---|
| 1 | `scripts/rails/table-extractor.lua` 106–111. (`RAIL_PROTOTYPE_NAMES`) | a kinyerés seed-listája | mindenki (adathiány) | 4 → 8 név + `rail-ramp`; külön kezelni, hogy a rámpa csak 4 irányban rakható (`PLACEMENT_DIRECTIONS` 114. sor 8 irányt próbál — a rámpánál a páratlan/átlós irányok `create_entity`-je várhatóan `nil`-t ad, ezt a ciklus már ma is tolerálja: `if rail then`) |
| 2 | `table-extractor.lua` 261–274. (`extensions[goal_dir_str] = …`) | kulcs csak irány; `goal.rail_layer` eldobva | Traverser, Syntrax, VTD | kulcs `(goal_dir, goal_layer)`; `goal_layer` és a saját vég `layer`-je mentve; rámpa két végének eltérő rétege rögzítve |
| 3 | `railutils/rail-data.lua` (generált) | nincs elevált/rámpa adat; régi séma | ugyanaz | újragenerálás a 1–2. után; a jelenlegi tábla → `defines.direction` kulcsú konverzió lépését (a `script-output/rail-table.lua` kimenetből) dokumentálni/automatizálni kell — ma ez a lépés nincs a repóban, csak a `devdocs/rail-geometry.md` utal `railtable.lua`/`validate_rail_patterns.lua` fájlokra, amelyek a repóban nem találhatók |
| 4 | `railutils/rail-info.lua` 10–15. (`RailType`) | 4 érték, egyben prototípusnév | minden fogyasztó | 4.2 szerinti modell (B): +`RAMP`, és réteg külön |
| 5 | `railutils/queries.lua` 73–82. (`RAIL_TYPE_TO_PROTOTYPE`, `PROTOTYPE_TO_RAIL_TYPE`) és a 88–101. sor hibát dobó függvényei | 4 bejegyzés; `error("Unknown prototype")` | VTD `lock_on_to_rail` (`virtual-train-driving.lua` 564. sor; továbbá 471. és 507.), `fa-info.lua` 1406., `tile-reader.lua` 72./94. | `(RailType, layer) ↔ prototype-type` leképezés; az `error` helyett `nil` + hívói kezelés (a VTD 472., 508. és 565. sora `if not rail_type` ágra számít, de a függvény sosem ad `nil`-t, hanem `error`-t dob — látens hiba) |
| 6 | `railutils/queries.lua` 112–226. (`get_adjusted_position`, `get_end_directions`, `get_extensions_from_end`) | `RailData[prototype_type][dir][end]` sémát feltételez | Traverser, describer, primary-finder | séma-bővítés követése; `get_extensions_from_end` adjon vissza `goal_layer`-t is |
| 7 | `railutils/traverser.lua` 24–27. (állapot), `_get_extension` 130–158., `_apply_extension` 49–55., `clone` 218. | 4 mezős állapot; kiterjesztés = irány-offset | VM, VTD, primary-finder | `_layer` mező; `_get_extension(offset, target_layer?)`; új `move_change_layer()`; `clone()` másolja a réteget |
| 8 | `railutils/surface-impls/game-surface.lua` 12–16. (`RailPlannerDescription`), 47–59. (`entity_name_to_rail_type`), 74–79. (`rail_names` lista a `get_rails_at_point`-ban, 63.) | 4 név; tile-lekérdezés csak 4 névre | describer, tile-olvasás | 9 mező (4 földi, 4 elevált, rámpa); `entity_name_to_rail_type` → `(RailType, layer)`; a `get_rails_at_point` eredménye hordozza a réteget |
| 9 | `scripts/rails/surface-helper.lua` 12–55. (`get_planner_description`), 74–104. (`wrap_surface_vanilla`, `wrap_surface_vanilla_ghosts`) | `.type ==` csak 4 név; a nem ismert típusok csendben kimaradnak; validáció csak a 4-re | VTD rázárás, Syntrax runner, fa-info, tile-reader | elevált/rámpa típusnevek felvétele; validáció két szintje: "földi teljes" kötelező, "elevált teljes" opcionális (ha a planner nem tartalmaz elevált síneket — pl. DLC nélkül —, a mod földi módban marad és ezt be is mondja) |
| 10 | `scripts/consts.lua` 95–103. (`RAIL_TYPES`, `RAIL_TYPES_SET`) | 4 típus | `virtual-train-driving.lua` 35–36., 447.; `tile-reader.lua` 51., 54., 124–125.; `control.lua` 3270., 3521–3525., 3595–3599. | két lista: `GROUND_RAIL_TYPES`, `ELEVATED_RAIL_TYPES` (+ `rail-ramp`), és egy egyesített `RAIL_TYPES`; a hívók döntsék el, melyik kell |
| 11 | `scripts/fa-info.lua` 1380–1385. (`is_rail_type`) | 4 név | entitás-leírás | egyesített lista |
| 12 | `scripts/rails/syntrax-runner.lua` 34–48. (`map_rail_type`), 52–70. (`convert_placement`) | 4 ág + `error` | Syntrax | `(RailType, layer)` → név a bővített `RailPlannerDescription`-ből; új placement-típusok (`ramp`, `support`) konverziója |
| 13 | `syntrax/vm.lua` 78–93. (placement osztályok), 116–118. (`dedup_key`), 187–220. (`place_rail`) | `rail_type` string a 4 közül; nincs réteg | Syntrax | `RailPlacement.layer`; új `RampPlacement`, `SupportPlacement`; `dedup_key` réteggel |
| 14 | `scripts/rails/virtual-train-driving.lua` 313–320. (`try_build_rail`: `Queries.rail_type_to_prototype_type`) | a VTD **mindig a vanilla típusnevet** építi, nem a planner nevét (a `planner_description` mezőt rázáráskor elmenti, de építéskor nem használja) | VTD | a Syntrax runnerrel azonos név-leképezés használata (mellékesen ez javítja a nem-vanilla planner-ekkel való viselkedést is) |
| 15 | `scripts/entity-selection.lua` 35–43., `scripts/scanner/surface-scanner.lua` 89–92., 133., 136. | már ismerik az elevált neveket (−1 prioritás; `SEB.TrainsSimple`) | — | nincs teendő; a −1 prioritás miatt viszont elevált sín **kiválasztása** (rázáráshoz) nehéz lesz ott, ahol földi sín is van alatta — lásd 9.4 |

Megjegyzés a 3. sorhoz: a `table-extractor.lua` kimenete irány-NEVEKKEL (`"north"`) kulcsolt tábla a `script-output/rail-table.lua` fájlban, míg a `railutils/rail-data.lua` `defines.direction.north` kulcsokat használ. A kettő közti átalakítás eszköze nincs a repóban (git-történet: "First pass extraction… /railtable", majd "Get a compressed summary…", majd "Initial version of railutils", 2025-11-06/07). Az A fázis első teendője ezt az átalakítót újraírni vagy a kinyerőt közvetlenül a végleges sémára átállítani, különben az újragenerálás kézi munkává válik.

---

## 4. (a) Érintett fájlok, sorrend és változtatási mélység — fázisolt terv

A fázisok úgy vannak sorrendbe rakva, hogy mindegyik önmagában is lezárható, tesztelhető állapotot adjon, és a nagy kockázatú rész (támasz-tervező) a már stabil geometriára épüljön.

### 4.1. A fázis — geometria-adat bővítése (a "könnyű" fele)

Cél: a `rail-data.lua` tartalmazza mind a 9 síntípus (8 + rámpa) teljes kiterjesztés- és jelzőhely-adatát, réteg-információval.

Teendők, sorrendben:

1. **Seed-lista bővítése** — `scripts/rails/table-extractor.lua` 106–111. sor: a 4 név mellé `elevated-straight-rail`, `elevated-half-diagonal-rail`, `elevated-curved-rail-a`, `elevated-curved-rail-b`, `rail-ramp`. A fejléc-komment (23–27. sor: "Factorio 2.0 has four rail piece types") és a `/railtable` dokumentáló kommentje (`scripts/fa-commands.lua` 110–118. sor, 113.: "Places each of the 4 rail types…") frissítendő.
2. **Réteg rögzítése a sémában** — a 261–274. sor kiterjesztés-ciklusa jelenleg `end_data.extensions[goal_dir_str] = {…}` alakú. Két egyenértékű megoldás: (a) kétszintű kulcs `extensions[goal_dir_str][goal_layer_str]`; (b) a kulcs marad, de az érték egy LISTA, és minden elem hordozza a `goal_layer`-t. Az (a) illeszkedik jobban a Traverser `_get_extension(offset)` lekérdezéséhez (a cél-réteg egy második index). Emellett minden `end_data`-ba fel kell venni a vég saját rétegét (`rail_end.location.rail_layer`), mert a rámpa két vége eltérő rétegen van.
3. **Elevált darab létrehozhatósága a kinyeréskor** — a kinyerő `surface.create_entity`-vel rakja le a darabot az origóba (139–145. sor). Kérdéses, hogy elevált sín/rámpa `create_entity`-je támasz nélkül sikerül-e (script-lerakás általában megkerüli a build-check-et, de a támasz-függőség lehet, hogy nem build-check, hanem létezési feltétel). Terv: a kinyerés elevált típusoknál előbb egy `rail-support`-ot rak az origó közelébe (vagy a kinyerést a `rail-ramp` elevált végéről indítja), és ezt a lépést a 11. fejezet E2 kísérlete dönti el. Ha a `create_entity` `nil`-t ad, a jelenlegi `if rail then` ág csendben kihagyja a típust — ezt a kinyerőnek hangosan jeleznie kell (a `/railtable` parancs `Speech.speak`-en át jelent, `fa-commands.lua` 133. sor).
4. **A planner-paraméter** — a 261. sor `get_rail_extensions("rail")` hívása a vanilla `rail` item `.rails` listájától függ. Ha az E1 kísérlet (11. fejezet) azt mutatja, hogy a `rail` item listája nem tartalmazza az elevált neveket, a kinyerőnek a megfelelő vanilla planner itemet (várhatóan `rail-ramp`, amely boskid fórum-válasza szerint maga is rail-planner típusú item) vagy egy, a mod által csak a kinyerés idejére definiált saját planner itemet kell átadnia. Ez utóbbi tiszta megoldás, mert így a kinyerés független a DLC item-elrendezésétől.
5. **Kimenet → `rail-data.lua` konverzió** — a kinyerő irány-NEVEKET ír, a `rail-data.lua` `defines.direction` kulcsokat használ (lásd 3. fejezet megjegyzése). Döntés: a kinyerő írjon közvetlenül a végleges sémára (direction-defines-ként kiírt, `require`-elhető Lua), vagy legyen egy kis offline konvertáló. Bármelyik elfogadható, de **a repóban kell lennie**, hogy a következő játékfrissítésnél (a devdoc "after game updates" indoka) újrafuttatható legyen.
6. **Verifikáció** — a `devdocs/rail-geometry.md` "Verification" szakaszához hasonló ellenőrzések az új adatokon: elevált végekről 3 kiterjesztés ugyanazon a rétegen; kardinális végekről +1 rámpa a másik rétegre; rámpa két vége eltérő rétegű; jelző-irány szabály (in = végirány, out = ellentétes) elevált végeken is áll-e; rámpa végein van-e egyáltalán jelzőhely (a wiki szerint a rámpán nem lehet jelző — a `LuaRailEnd.in_signal_location` ettől még adhat pozíciót a rámpa végén túl, ez tisztázandó).

Kimenet: új `rail-data.lua`, frissített `devdocs/rail-geometry.md` ("Universal Extension Rule" → 2.1 szerinti módosítás), a `railutils/tests/` kiegészítése elevált esetekkel (a tesztek a `test-surface.lua` dry-run felületen futnak, játék nélkül).

### 4.2. B fázis — típusrendszer

Cél: a `RailType`/`RailPlannerDescription`/`Consts` hármas rétegtudatos legyen, a 3. fejezet 4–5., 8–11., 14. sorai szerint.

**Modellezési döntés (A vs. B):**

- (A) 9 értékű `RailType` (a prototípus-típusnév marad az érték). Előny: a `rail-data.lua` kulcsa és a `RailType` továbbra is azonos string, a kinyerő→tábla→Traverser lánc nem igényel leképezést. Hátrány: a describer `classify_simple_rail`, `detect_turn`, `get_curve_fallback` (`rail-describer.lua` 67–232. sor) minden `RailType.X` összehasonlítását duplázni kell (vagy "normalizálni" kell előtte), és a `RailKind` szókincs (vertical, left-of-north…) réteg-független marad — a két fogalom keveredne.
- (B) 5 értékű `RailType` (`STRAIGHT`, `CURVE_A`, `CURVE_B`, `HALF_DIAGONAL`, `RAMP`) + külön `railutils.RailLayer` (`GROUND`, `ELEVATED`), a prototípus-típusnév a `(RailType, RailLayer)` párból képződik (`RAMP` esetén rétegtől független). A `rail-data.lua` kulcsa maradhat a prototípus-típusnév, a `queries.lua` leképezői kapnak egy `layer` paramétert. Előny: a describer és az announcer logikája **változatlan** a 4 alaptípusra, a réteg csak prefixként jelenik meg a beszédben; a Traverser állapota egy mezővel nő. Hátrány: a `RailType` ma literálisan egyenlő a típusnévvel, és néhány hely ezt kihasználja (pl. `syntrax-runner.lua` `map_rail_type` string-összehasonlítása, `vm.lua` `RailPlacement.rail_type` dokumentációja) — ezeket át kell írni.

**Javaslat: (B).** Indok: a felhasználói élmény szempontjából az eleváció egy jelző ("elevált vízszintes", "elevált kelet–észak forduló teteje"), nem új alakzat; a leíró-rendszer újrahasznosítása sokkal több kódot ment meg, mint amennyit a leképezés visz. A rámpa viszont valódi új alakzat, saját `RailType` értéket kap, saját `RailKind` szókinccsel ("rámpa fel észak felé" / "rámpa le dél felé").

Konkrét érintett helyek: `rail-info.lua` (+`RailLayer` enum, +`RailType.RAMP`, +`RailKind.RAMP_UP_*`/`RAMP_DOWN_*` 4-4 irányra); `queries.lua` leképezők és `get_*` függvények (paraméter: réteg; a `error` → `nil` váltás a 97–101. sornál, mert a VTD és a tile-reader hívói `nil`-re számítanak); `consts.lua` (`GROUND_RAIL_TYPES`, `ELEVATED_RAIL_TYPES`, `RAIL_RAMP_TYPE`, egyesített `RAIL_TYPES`); `game-surface.lua` (`RailPlannerDescription` 9 mezős; `entity_name_to_rail_type` → `(type, layer)`; `get_rails_at_point` eredmény `layer` mezővel); `surface-helper.lua` (`get_planner_description` két szintű validációval, 4.4 szerint); `fa-info.lua` `is_rail_type`; `syntrax-runner.lua` `map_rail_type`; `virtual-train-driving.lua` `try_build_rail` (a planner-név használata a vanilla típusnév helyett — 3. fejezet 14. sor).

### 4.3. C fázis — Traverser réteg-állapot és rétegváltás

Cél: a `railutils/traverser.lua` tudjon rétegről, és legyen egy negyedik mozgása.

- Állapot: `_layer` mező (24–27. sor mellé); `mod.new(...)` kap `layer` paramétert (alapértelmezés `GROUND`, hogy a meglévő hívók/tesztek ne törjenek); `clone()` (218. sor) másolja; `flip_ends()` (175. sor) rámpán a réteget is váltja (a rámpa másik vége a másik rétegen van), különben nem.
- `_get_extension(direction_offset)` (130–158. sor) kap egy opcionális `target_layer` paramétert; alapértelmezés = a jelenlegi réteg. Ha a tábla `(goal_dir, target_layer)` kulcsán nincs kiterjesztés → **ne `error`-t dobjon**, hanem adjon `nil`-t és egy ok-kódot (`NOT_CARDINAL`, `NO_RAMP_FROM_HERE`, `ALREADY_ON_LAYER`), mert a VTD ma "Let it crash if it fails" alapon hívja (`virtual-train-driving.lua` 626. sor), és rétegváltásnál a hiba a felhasználó szokásos tévesztése lesz, nem programhiba.
- Új mozgás: `move_change_layer()` — csak kardinális `_end_direction` mellett érvényes; a `(end_direction, other_layer)` kulcsú kiterjesztést alkalmazza (ez a rámpa), és az `_apply_extension` után a `_layer`-t a rámpa túlsó végének rétegére állítja. Ezután a következő `move_forward` már az új réteg egyenesét adja.
- `_apply_extension` (49–55. sor): a réteg frissítése a kiterjesztés `goal_layer`-éből (ne a kérésből), hogy a tábla legyen az igazság forrása.
- Megfontolandó segédfüggvények a support-tervezőnek: `get_layer()`, `is_on_ramp()`, és egy "távolság az utolsó támasztól" számláló NEM a Traverserbe való (az állapot-mentes maradjon), hanem a tervezőbe (5. fejezet).

Tesztek: `railutils/tests/traverser.lua` bővítése dry-run esetekkel: földi egyenes → rétegváltás → 3 elevált egyenes → rétegváltás → földi; rétegváltás átlós végről → hiba-kód; rámpán `flip_ends` → réteg vált.

### 4.4. D fázis — Syntrax nyelvi kiterjesztés

Részletesen a 6. fejezetben. Érintett fájlok és a bővítés "útja" egy új szónál (ez a minta minden új szóra azonos): `syntrax/lexer.lua` `TOKEN_TYPE` enum (100–127. sor) + a szöveg→token ág (281–330. sor) + chord-minta ha chordolható (149–160. sor); `syntrax/parser.lua` token→AST ág (133–193. sor); `syntrax/ast.lua` node-kind; `syntrax/compiler.lua` `compile_node` ág (57–131. sor) → `syntrax/vm.lua` `BYTECODE_KIND` (31–52. sor) + `execute_instruction` ág (407–483. sor) + új placement-osztály(ok) (78–93. sor); `syntrax/tests/` (lexer/parser/compiler/vm tesztek); `docs/features/syntrax.md`.

### 4.5. E fázis — lerakási pipeline: sorrend, támasz-tervező, jelzők

- `syntrax-runner.lua` `convert_placement` (52–70. sor): új ágak `ramp` és `support` placementre; a név a bővített `RailPlannerDescription`-ből, a támasz neve a planner `support` mezőjéből (`LuaItemPrototype.support`, `LuaEntityPrototype` típusú, opcionális — `llm-docs/api-reference/runtime/classes/LuaItemPrototype.md` 527–533. sor; a runtime tehát kiteszi, nem kell konstans).
- **Sorrend:** a VM kimenete ma program-sorrendű. Elevált szakaszon a runner/tervező garantálja, hogy egy elevált sín csoportja ELŐTT szerepeljen az őt tartó támasz/rámpa csoportja. Ezt a legegyszerűbb a támasz-tervező utófeldolgozásában megoldani: a tervező a támasz-elhelyezéseket mindig **a lefedett szakasz első síne elé** szúrja be (5.4). A revive (`build-helpers.lua` `revive_ghosts`, 195. sor) ugyanebben a sorrendben fut, tehát a támasz valódi entitása is előbb jön létre.
- **Visszavonás/hibakezelés sorrendje:** a runner hibánál a saját ghostjait rombolja (`destroy_ghosts(all_created)`), tetszőleges sorrendben — elevált ghostoknál ezt **fordított sorrendben** kell tenni (sín előbb, támasz utána), hogy ne kaszkádoljon; ugyanez a VTD `backspace`/`pop_move` (`virtual-train-driving.lua` 804–840., 348–401. sor) útján.
- **Jelzők elevált sínen:** a VTD `place_signal` (842–878. sor) és a VM `place_signal*` a tábla jelzőhelyeit használja; a blueprint-szintetizátor csak `name/position/direction`-t ír. In-game ellenőrzendő (11. fejezet E3), hogy egy elevált sín melletti jelző-blueprint réteg-mező nélkül a földi vagy az elevált sínhez kapcsolódik-e; ha a motor a közelebbi/első találatot veszi, a jelző rossz rétegre kerülhet ott, ahol földi és elevált pálya átfed. Ha kell réteg-mező, a `blueprint-synthesizer.lua` kap egy opcionális extra-mező paramétert (a `control_behavior` mintájára, 11–17. sor).
- **VTD ↔ build-helpers egységesítés:** a `try_build_entity` (VTD 154–246.) és a `place_ghost` (build-helpers 88–151.) duplikáció megszüntetése, hogy a sorrend- és réteg-logika egy helyen éljen.

### 4.6. F fázis — leírás és beszéd

Részletesen a 8. fejezetben: `rail-describer.lua` (`RailDescription` +`layer`, +rámpa-kind), `announcer.lua` (réteg-előtag, rámpa- és támasz-mondatok), `fa-info.lua` 1380–1412. (típus-szűrő, planner-független wrap), `tile-reader.lua` 38–100. (rétegenkénti olvasás, támasz említése), `locale/en/rail-announcer.cfg` (új kulcsok), `locale/en/virtual-train-driving.cfg` (VTD réteg-üzenetek).

### 4.7. G fázis — manuális építés UX (VTD)

Részletesen a 9. fejezetben: `virtual-train-driving.lua` (`on_kb_descriptive_action_name` új ágak; `move_in_direction` elé ellenőrzés; `vtd.Move` +`layer`, +`support_entities`; `lock_on_to_rail` elevált sínre; `announce_rail` réteg), `data/input.lua` (új custom-input bejegyzések), `locale/en/controls.cfg`.

### 4.8. H fázis — dokumentáció és tutorial

`docs/features/rails.md` (új "Elevated rails" szakasz + a Ctrl/Shift ellentmondás javítása), `docs/features/syntrax.md` (új szavak), `locale/en/tutorial/ch1.txt` 21. sor és `message-lists.cfg` 28. sor (az "elevated rails kikapcsolása" kérés visszavonása), `devdocs/rail-geometry.md`, `CHANGES.md`.

---

## 5. (b) A támasz-elhelyezés problémája és az automatikus támasz-tervező

Ez a terv legfontosabb fejezete, mert erre nincs motor-oldali segítség.

### 5.1. A probléma pontos megfogalmazása

Adott egy **elevált futam**: elhelyezések sorozata (a VM kimenetében vagy a VTD lépéseiben), amely egy **horgonynál** kezdődik (rámpa elevált vége VAGY egy már létező támasz VAGY egy már létező, megtámasztott elevált sín vége), elevált síndarabokon halad, és egy másik horgonynál (rámpa, meglévő támasz) vagy "nyitottan" (a program vége) zárul. Keresendő támasz-pozíciók és -irányok olyan halmaza, hogy:

1. **Lefedettség:** minden elevált síndarab a hatótávján belül legyen legalább egy horgonynak (rámpa `support_range`, támasz `support_range`; alapértelmezés 15.0 mindkettőnél).
2. **Elhelyezhetőség:** minden támasz a játék szerint lerakható legyen (`LuaSurface.can_place_entity`, `build_check_type = manual_ghost` ghost-módban, `manual` normál módban; a `forced` flag a force/superforce módokhoz).
3. **Takarékosság:** a támaszok száma minimális, vagy legalább nem pazarló.
4. **Kiszámíthatóság a felhasználó számára:** ugyanaz a program ugyanott ugyanazt a támasz-elrendezést adja (a vanilla "inkonzisztens spacing" hibajegye pont ezt a tulajdonságot sérti — a mod ebben lehet jobb a vanillánál).

Két tisztázatlan modell-paraméter, amelyeket a 11. fejezet E4–E5 kísérletei adnak meg: (i) a `support_range` **mit mér** — a támasz középpontjától a sín valamely pontjáig vett távolságot, vagy pálya menti hosszat; a wiki "5 egyenes / 2 kanyar / 1 kanyar + 3 egyenes" szabálya pálya menti hosszra utal (5 egyenes = 10 mező ≈ a 15.0 fele-kétharmada… vagy a 15.0 a két oldalra együtt értendő), tehát a modell valószínűleg "pálya menti távolság a támasz csatlakozási pontjától", de ezt mérni kell; (ii) a támasz hová illeszkedik (`snap_to_spots_distance` 1.0): a támasz feltehetően **a sín alá, a sín egy végpontjára** illeszkedik (a sín-végpontok a 2×2 rács egész koordinátáin vannak, lásd `devdocs/rail-geometry.md` "Advanced Form"), nem tetszőleges helyre. Ha így van, a jelölt pozíciók halmaza **diszkrét és kicsi**: az elevált futam síndarabjainak végpontjai. Ez óriási egyszerűsítés: nem a síkot kell keresni, hanem a futam végpontjait sorban végigpróbálni.

### 5.2. Miért a VM-kimenet utófeldolgozása a jó hely

Három lehetséges hely a tervező számára: (1) a VM-ben, lerakáskor; (2) a VM-kimenet és a runner között, utófeldolgozásként; (3) a runnerben, ghost-lerakás közben "ha nem sikerül, tegyél támaszt".

A (2) a javasolt, mert: a VM nem ismeri a felületet (szándékosan tiszta, offline tesztelhető — `syntrax/tests/`), a támasz-ellenőrzéshez viszont `can_place_entity` kell; a (3) reaktív és nem tud takarékos lenni (mindig az első lehetséges helyre tenne); a (2) látja a **teljes futamot** (hány darab, hol a két horgony), ezért tud egyenletesen elosztani. Ugyanez a modul hívható a VTD-ből is lépésenként, egy "futam-eddig" állapottal (9. fejezet).

A tervező bemenete: a `PlacementGroup[]` lista + a kezdő Traverser-állapot + a felület; kimenete: ugyanaz a lista, `SupportPlacement` csoportokkal kiegészítve a megfelelő helyeken, vagy hiba a felhasználónak (5.5).

### 5.3. Három algoritmus-vázlat

**(i) Egyenletes elosztás + csúsztatás.** Egy futamra: határozd meg a horgonyok közti pálya menti hosszat `L` (darabhosszak összege; a tábla `occupied_tiles`/végpont-távolságok ebből számolhatók), a támasz effektív fedési hosszát `R` (a mérésből: pl. 2×támasz_hatótáv, ha a támasz mindkét irányban tart), és a rámpa fedését `R_ramp`. Szükséges támaszszám `n = ceil((L − R_ramp_start − R_ramp_end) / R)`, ha pozitív. Oszd el `n` jelölt pontot egyenletesen a futam végpontjai között (a legközelebbi síndarab-végpontra kerekítve). Minden jelöltre `can_place_entity`; ha nem rakható, csúsztasd a legközelebbi szomszédos végpontra felváltva előre/hátra, amíg a lefedettség még teljesül (a csúsztatás korlátja: a két szomszédos horgony hatótávjának metszete). Ha elfogy a játéktér → hiba. Előny: szép, kiszámítható eredmény; hátrány: a lefedettség-ellenőrzést a csúsztatás után újra kell futtatni.

**(ii) Mohó "legtávolabbi még lefedett pont".** Indulj az első horgonytól; menj előre a futamon addig a legtávolabbi síndarab-végpontig, amelyet az aktuális horgony még lefed; onnan visszafelé lépkedve keresd az első olyan végpontot, ahová támasz rakható (`can_place_entity`); rakd le (ez az új horgony); ismételd a következő horgonyig. Előny: minimális támaszszám, egyszerű, mindig helyes lefedettséget ad; hátrány: a támaszok "hátra tömörödnek", ami vizuálisan nem számít (vak felhasználó), de a visszafelé keresésnél a kezdő horgony hatótávján belül kell maradni, különben lyuk keletkezik — ez a feltétel egyszerűen ellenőrizhető. **Ez a javasolt alapértelmezés**, mert a helyesség bizonyítható és a vanilla planner viselkedésére hasonlít a legjobban.

**(iii) Kézi felülbírálás a nyelvben.** A felhasználó explicit támaszt kér (`sup` szó, 6. fejezet) vagy tilt egy pontot (`nosup`), és egy futam-szintű kapcsoló (`autosup off`) kikapcsolja a tervezőt. A tervező az explicit támaszokat horgonyként kezeli, és csak a köztük maradt lefedetlen szakaszokra fut le (ii)-vel. Ez adja meg a power usernek a kontrollt (pl. ha egy támaszt szándékosan egy később épülő másik pálya alá akar tenni).

Kiegészítő (iv): **irányválasztás.** A támasz 8 irányú; a pálya iránya adott, de hogy a támasz irányának egyeznie kell-e a sín irányával (vagy merőlegesnek kell lennie), az E5 kísérlet kérdése. A jelölt-ellenőrzésnek ezért irány-listát is végig kell próbálnia (első körben: a sín iránya, majd +4/−4).

### 5.4. Beszúrási pont és építési sorrend

A tervező a `SupportPlacement` csoportot a futam azon síndarabja ELÉ szúrja a listába, amelyik elsőként szorul rá (a (ii) algoritmusnál: az új horgony által lefedett első darab elé). Így a runner meglévő, sorrendtartó ghost-lerakása és revive-ja automatikusan jó sorrendet ad. A rámpa a programban ott áll, ahol a felhasználó írta (ez maga is a futam horgonya). A támasz-csoportnak **egyetlen alternatívája** van (a jelzőktől eltérően nem kell pozíció-alternatíva, mert a tervező már ellenőrzött pozíciót ad), vagy — robusztusabban — a tervező **több jelöltet** ad alternatívaként (az első rakható, utána a csúsztatottak), és a runner meglévő "próbáld sorban az alternatívákat" logikája (`syntrax-runner.lua` 156–162. sor) kezeli a futásidejű eltérést a `can_place_entity` és a tényleges `build_from_cursor` között. Ez utóbbi a javasolt forma, mert ingyen jön a meglévő architektúrából.

Visszavonásnál (runner-hiba, VTD backspace) a `SupportPlacement`-hez tartozó ghost/entitás a tőle függő sínek **után** rombolható; a VTD `vtd.Move` rekordja ezért kapjon `support_entities` listát külön a `entities`-től, és a `pop_move` előbb a síneket, utána a támaszokat távolítsa el.

### 5.5. Hibaesetek és visszajelzés

- "Nem találok támasz-helyet a(z) N. és M. darab között" — a Syntrax `syntrax-error` csatornán (`virtual-train-driving.cfg` `syntrax-error`), a `format_placement_error` mintájára (`syntrax-runner.lua` 74–85. sor), de **koordinátával és darabszámmal** (a vak felhasználó ebből tudja, hol kell terepet rendeznie).
- "A futam túl hosszú egyetlen támasz nélkül, és a tervező ki van kapcsolva" — ha `autosup off` mellett lefedetlen szakasz marad, a runner ne próbálja a sínt lerakni (úgyis elbukna), hanem előre mondja meg.
- "Rámpa csak kardinális irányból indítható" — a C fázis ok-kódja alapján, a Syntrax span-nel (sor/oszlop) együtt.
- Részleges siker tilos: a runner ma is "mindent vagy semmit" (hibánál minden saját ghostot visszavon) — ezt az elevált futamra is meg kell tartani, különben megtámasztatlan fél-hidak maradnak.

### 5.6. Megjegyzés a vanilla viselkedésről

A vanilla planner "kb. 5 egyenesenként" rak támaszt, de a fórum-hibajegyek (2.0.21 spacing, 2.0.73 ghost-kaszkád) azt mutatják, hogy ez nem determinisztikus referencia. A mod célja ne a vanilla elrendezés reprodukálása legyen, hanem egy **saját, kiszámítható szabály** ("mindig a lehető legtávolabbi rakható végpontra"), amelyet a felhasználó fejben is követni tud — ez illik a mod filozófiájához ("the mod opts for control and precision", `docs/features/rails.md`).

---

## 6. (c) A Syntrax nyelvi kiterjesztése

### 6.1. Új szavak (javaslat)

| Szó | Rövid alak / chord | Jelentés | Bytecode |
|---|---|---|---|
| `up` | `u` (chordolható) | rétegváltás felfelé: rámpa lerakása a jelenlegi kardinális végről, a Traverser elevált rétegre áll | `CHANGE_LAYER` (cél: elevated) |
| `down` | `d` (chordolható) | rétegváltás lefelé | `CHANGE_LAYER` (cél: ground) |
| `elev` / `toggle`? | — | a megbízó eredeti ötlete: "nézze meg a réteget és negálja". Egyetlen szó egyszerűbb, de a program olvasásakor nem látszik, merre megyünk; ezért a tervben `up`/`down` az elsődleges, és az `elev` opcionális alias, amely a jelenlegi réteg alapján dönt | ugyanaz, cél = másik réteg |
| `sup` | — | kézi támasz a jelenlegi végpontnál (horgony a tervezőnek) | `SUPPORT` |
| `nosup` | — | tiltja a tervezőnek, hogy ide támaszt tegyen | `SUPPORT_FORBID` (marker) |
| `autosup on` / `autosup off` | — | futam-szintű kapcsoló; alapértelmezés `on` | `AUTOSUP` |

Megfontolások: az `u`/`d` chord-betűk ma szabadok (a chord-minták: `l90 r90 l45 r45 l r s f m ;` — `lexer.lua` 149–160. sor); a `d` nem ütközik semmivel, az `u` sem. A `mark` chord-alakja `m` — ezt érdemes tudni, hogy a dokumentációban ne keverjük a VTD `M` billentyűjével (ami balra fordul); ez már ma is így van. Az `x N` ismétlés az `up`/`down` után értelmetlen (két rámpa egymás után nem fűzhető), ezért a parser korlátozott ismétlés-listájába (`docs/features/syntrax.md` "Repetitions": csak `l s r l45 r45 l90 r90` ismételhető zárójel nélkül) nem kerülnek be.

### 6.2. Szemantika

- `up`/`down` csak kardinális végről érvényes; különben fordítási idő helyett **futási idejű** hiba (a VM tudja a végirányt): "rétegváltás csak észak/kelet/dél/nyugat irányból lehetséges, itt: észak-északkelet". A span-nel együtt (`Errors.error_builder`, `vm.lua` 373. sor mintájára).
- `up` elevált rétegen / `down` földi rétegen: hiba ("már az elevált rétegen vagy"), vagy no-op? Javaslat: hiba, mert a program olvasója másra számít; az `elev` alias viszont definíció szerint negál.
- A réteg a Traverser állapot része, ezért a `mark/reset` és `rpush/rpop` (a Traverser `clone()`-ját használják, `vm.lua` 358–398. sor) automatikusan megőrzik → egy `up … reset` után a földi rétegre térünk vissza, pontosan ahogy a felhasználó várja.
- `flip` (`f`) rámpán: a másik végre lép, és réteget is vált (C fázis). Dokumentálni kell, mert meglepő lehet.
- A rámpa a VM-ben egy új `RampPlacement {type="ramp", position, direction, from_layer, to_layer}`; a `dedup_key` (`vm.lua` 116–118. sor) kapja meg a réteget is, mert földi és elevált egyenes azonos pozícióban/irányban **egyszerre létezhet** (hídon átmenő földi pálya) — ma a kulcs `pos,dir,rail_type`, ami ilyenkor hamis dedupot adna.
- `sup` → `SupportPlacement {type="support", position, direction, explicit=true}`; a tervező ezt horgonyként kezeli. `nosup` nem rak semmit, csak egy marker-elhelyezést ad a listába, amelyet a tervező elolvas és eldob (a runner felé nem jut el).

### 6.3. Példák (csak illusztráció a dokumentációhoz, nem kód)

- Egyszerű híd 10 egyenessel, automatikus támaszokkal: `up s x 10 down` — a tervező a 10 egyenes alá a mérések szerint 1–2 támaszt szúr.
- Kézi vezérlés: `autosup off up s x 4 sup s x 5 sup s x 4 down`.
- Elágazás a hídon: `up s x 6 mark l45 … reset r45 …` — a `reset` a hídra (elevált rétegre) tér vissza.

### 6.4. Érintett tesztek és dokumentáció

`syntrax/tests/lexer.lua`, `parser.lua`, `compiler.lua`, `vm.lua`, `chord.lua` (új chord-betűk), `syntrax/tests/rail-stack.lua` (réteg megőrzése rpush/rpop-nál); `docs/features/syntrax.md` "Basic Commands", "Chords", "Mark and Reset" szakaszai; `scripts/ui/menus/rail-builder.lua` + `locale/en/syntrax-program-names.cfg`: új kategória "elevated" beépített programokkal (`up`, `down`, "híd 10", "híd 20").

---

## 7. (d) A `surface-helper.lua` rései és a minimális javítás

**Rés 1 — `get_planner_description` (12–55. sor).** A ciklus `type ==` ágai csak a 4 földi típust ismerik; az elevált és rámpa prototípusokat csendben átlépi; a validáció (41–50. sor) csak a 4 földi nevet követeli meg. Következmény: ha a kézben lévő planner elevált síneket is tud, a mod ezt nem tudja meg. Minimális javítás: a `RailPlannerDescription` kiegészítése az `elevated_straight_rail_name`, `elevated_curved_rail_a_name`, `elevated_curved_rail_b_name`, `elevated_half_diagonal_rail_name`, `ramp_name`, `support_name` mezőkkel; a ciklus további 5 ága; **kétszintű validáció**: a 4 földi név továbbra is kötelező (különben `nil`, mint ma), az 5 elevált/rámpa név együtt vagy mind megvan ("elevált képes planner"), vagy egy sem (földi planner), a részleges állapot hiba. A `support_name` forrása a `LuaItemPrototype.support` mező (`LuaEntityPrototype`, opcionális; `llm-docs/api-reference/runtime/classes/LuaItemPrototype.md` 527–533. sor) — ha egy planner-nek nincs, a mod a `prototypes.entity` `type = "rail-support"` szűrésére esik vissza.

**Rés 2 — `wrap_surface_vanilla` / `wrap_surface_vanilla_ghosts` (74–104. sor).** Hardcode-olt 4 vanilla név; ezeket a `fa-info.lua` és a `tile-reader.lua` használja passzív olvasáshoz, ahol **nincs planner a kézben** (a játékos csak sétál). Minimális javítás: a két függvény a 9 mezős leírást adja vissza a vanilla nevekkel (`elevated-*`, `rail-ramp`, `rail-support`); hosszabb távon a passzív olvasás ne a "vanilla nevek" feltételezésre épüljön, hanem a `prototypes.entity` futásidejű szűrésére típus szerint (`type = "straight-rail"` stb.), mert így a nem-vanilla sín-modok is működnének — ez a mai `-- hardcoded to vanilla for now` komment (`fa-info.lua` 1396. sor) feloldása.

**Rés 3 — `wrap_surface_for_player` (57–71. sor).** Ma nem használt sehol (grep szerint csak definiálva); a bővítés után ez lehet a VTD és a Syntrax közös belépési pontja a rétegtudatos felülethez.

A `game-surface.lua` oldalán a `get_rails_at_point` (63–112. sor) a 9 névre kérdezzen, és az eredmény `RailInfo` rekordja kapjon `layer` mezőt; az `entity_name_to_rail_type` (47–59. sor) `(RailType, RailLayer)` párt adjon. A `rails-surface.lua` interfész-dokumentáció (19 sor) és a `test-surface.lua` ugyanígy bővül, hogy a describer-tesztek rétegeket is tudjanak szimulálni.

---

## 8. (e) A leíró- és beszédrendszer bővítése (rail-describer, announcer, fa-info, tile-reader)

### 8.1. Mi történik ma, ha a játékos egy elevált sínre lép

- `scripts/tile-reader.lua` `read_tile_rails` (38–100. sor) a `Consts.RAIL_TYPES` (4 földi típus) szűrővel keres síneket a tile-on (50–55. sor) → elevált sín **nem** sín számára. A tile-on lévő elevált sín ezután a generikus entitás-olvasáson át jelenik meg, a vanilla lokalizált nevével ("Elevated straight rail"), geometriai leírás nélkül. Az `entity-selection.lua` −1 prioritása miatt, ha a tile-on földi sín is van, az elevált sín a kurzor-kiválasztásban a földi mögé kerül.
- `scripts/fa-info.lua` 1380–1412.: `is_rail_type` a 4 típusra; a `prototype_type_to_rail_type` hívás (1406. sor) elevált névre `error`-t dobna — ez ma csak azért nem történik meg, mert az `is_rail_type` előbb kiszűri.
- `railutils/rail-describer.lua` `describe_rail` (241. sor): `RailDescription{kind, end_direction, lonely, junctions}` (20–24. sor) — nincs réteg; a `detect_turn` és a junction-keresés a `RailsSurface.get_rails_at_point` lekérdezésre épül, amely ma csak a planner 4 nevét látja → egy elevált kanyar szomszédjait nem találná, "lonely"-nak mondaná.
- `scripts/rails/announcer.lua` `announce_rail` (72. sortól): `prefix_rail`, `is_ghost`, jelző- és állomás-információ; nincs réteg-előtag.

### 8.2. Javasolt változtatások

1. `RailDescription` kap `layer` (ground/elevated) és `ramp` (nil | {from_layer, to_layer, direction}) mezőt. A `describe_rail` a `(RailType, layer)` párt kapja (B modell), és a `RailsSurface`-t **ugyanazon a rétegen** kérdezi (a `get_rails_at_point` eredményét réteg szerint szűri), hogy a kanyar-felismerés és a junction-logika ne keverje a két réteget. A rámpa saját `RailKind` értékeket kap (4 irány × fel/le), és a describer a rámpa két végét úgy írja le, hogy "rámpa fel, észak felé; alsó vége dél, felső vége észak".
2. `announcer.lua`: réteg-előtag ("elevated" / "elevált") minden elevált leírás elé, a `rail-ghost-prefix` mintájára (`rail-announcer.cfg` "Modifiers" szakasz); rámpa-mondat; és — új — **támasz-említés**: ha a sín alatt/mellett a tile-on támasz van, ezt a leírás végén jelezze ("on support" / "támaszon"), mert a vak felhasználónak ez a hídépítés egyetlen tapintható visszajelzése.
3. `tile-reader.lua`: a sín-keresés az egyesített típuslistával fut, és az eredményt **két mondatra** bontja: előbb a földi réteg, utána az elevált (vagy fordítva, a kurzor "rétegétől" függően — lásd 9.4), mindkettő saját előtaggal. A `PrimaryFinder.deduplicate_secondary_rails` (`scripts/rails/primary-finder.lua`, Traverser-alapú) rétegenként külön fusson. A tile-on lévő `rail-support` entitás külön tételként ("rail support, facing north") jelenjen meg, mert a támasz nem sín.
4. `fa-info.lua`: `is_rail_type` az egyesített listára; a `wrap_surface_vanilla*` helyett a 7. fejezet szerinti futásidejű, típus-alapú leírás; a `rail-ramp` és `rail-support` entitás-leírása külön (a támasz esetén hasznos: hány sín támaszkodik rá — ez a `LuaEntity` API-ból nem közvetlenül olvasható, de a tile-lekérdezéssel becsülhető; első körben elhagyható).
5. Lokalizáció: `locale/en/rail-announcer.cfg` új kulcsok (réteg-előtag, rámpa 8 kulcs, támasz 1–2 kulcs); `locale/en/virtual-train-driving.cfg` VTD-üzenetek (lásd 9.5).

### 8.3. A "mod már jelzi" félreértés tisztázása a dokumentációban

A scanner (`surface-scanner.lua` 89–92., 133., 136. sor) és az entitás-kiválasztás (`entity-selection.lua` 35–43.) tényleg ismeri az elevált neveket, ezért a szkenner-listában "Elevated straight rail" megjelenik. Ez azonban csak **létezés-jelzés**; a geometriai leírás (merre megy, kanyar-e, elágazás-e) és az építési visszajelzés hiányzik. A `docs/features/rails.md` "Overview of Track Reporting" szakaszában érdemes ezt a különbséget leírni a felhasználóknak is, hogy tudják, mit várhatnak a bővítés előtt és után.

---

## 9. (g) A manuális M/,/. (virtuális vonat) építés és az eleváció

### 9.1. Mi a VTD ma, és miért érinti ugyanaz a rés

A VTD (`scripts/rails/virtual-train-driving.lua`) a Syntrax "kézi" párja: ugyanazt a Traverser-t lépteti egy-egy billentyűre (`extend_forward/left/right`, 661–686. sor), ugyanazt a lerakási pipeline-t használja (`try_build_entity`, 154–246.), a rázáráskor a `SurfaceHelper.get_planner_description`-t hívja (548. sor), és a `Queries.prototype_type_to_rail_type` 4-nevű leképezését (564. sor). Minden, ami a B–C fázisban a Traverserrel és a típusrendszerrel történik, automatikusan a VTD-re is hat. Ami **nem** automatikus, az a billentyűzet és a felhasználói visszajelzés.

### 9.2. Rétegváltás billentyűje — javaslat és a G-probléma kezelése

Tények: a vanilla "Toggle rail layer" = G; a modban `fa-g` (páncél/életerő), `fa-s-g`, `fa-c-g` (vonatkapcsolás) foglalt, mind `consuming = "none"` (`data/input.lua` 772–792. sor); az upstream #204 vita nyitott. A VTD saját billentyű-klasztere: Comma (előre), M (bal), Period (jobb), Alt+Comma (flip), Ctrl/Shift+M/Period (jelzők), Slash (speculation), Shift+B / B (bookmark), Backspace (undo), K (állapot) — `on_kb_descriptive_action_name`, 880–951. sor. A világ-kontextusban **nem** használt, de a modban már definiált kombinációk: `Shift + Comma` (`fa-s-comma`), `Ctrl + Comma` (`fa-c-comma`), `Ctrl + Shift + Comma` (`fa-cs-comma`), `Alt + M`, `Alt + Period` — ezeket ma csak a UI-router köti menü-akciókhoz (`scripts/ui/router.lua` 1117–1132. sor), VTD-ben (nyitott menü nélkül) szabadok.

Javaslat:

- **`Shift + Comma` = rétegváltás (rámpa lerakása előre).** Mnemonika a meglévő dokumentáció logikájával ("a vonat a comma; Shift-tel megemeled"). Ugyanaz a billentyű fel és le (a Traverser rétege dönti el), így a felhasználónak egy gombot kell megjegyeznie, és a viselkedés megegyezik a Syntrax `elev` aliasával.
- **`Ctrl + Shift + Comma` = kézi támasz lerakása a jelenlegi végpontnál** (Syntrax `sup`).
- **`Ctrl + Comma` = automatikus támasz-javaslat elfogadása** (lásd 9.3) — opcionális, ha a 9.3 "kérdező" változata mellett döntünk.
- A vanilla G-toggle-t a VTD-ben **nem** használjuk (a VTD nem a vanilla plannerrel épít, a vanilla toggle állapota a modból nem olvasható — nincs runtime API rá, lásd a prompt Fázis 3 "nem derült ki" pontját és a LuaPlayer-doksi negatív grep-jét). Külön döntés (10. fejezet 1. kérdés), hogy a `fa-g` → `consuming` váltással a mod **elnyomja-e** a vanilla toggle-t, hogy a sín-plannerrel a kézben véletlenül megnyomott G ne váltson csendben réteget a vanilla oldalon (ami a mod számára láthatatlan, de a `build_from_cursor` viselkedését NEM befolyásolja, mert a mod blueprintet épít — ezt az E7 kísérlet erősítse meg).

### 9.3. Proaktív figyelmeztetés: "ide már támasz kell"

Mechanizmus (a `move_in_direction`, 618–659. sor elé illesztett ellenőrző lépés):

1. A `vtd.State` kap egy `elevated_run` rekordot: az utolsó horgony (rámpa elevált vége vagy támasz) pozíciója és az azóta megtett pálya menti hossz (`distance_since_anchor`), plusz a jelenlegi réteg. Ezt minden sikeres elevált lépés növeli a lerakott darab hosszával (a tábla `occupied_tiles`/végpont-távolsága), `backspace` csökkenti (a `moves[]` verem rekordjaiba mentve, hogy a visszavonás pontos legyen).
2. Lépés előtt: ha a réteg elevált, és `distance_since_anchor + következő_darab_hossza > effektív_hatótáv`, akkor a lépés NEM hajtódik végre, hanem a mod bemondja: "támasz kell, mielőtt továbbmész — Ctrl+Shift+Comma rak egyet ide, vagy Ctrl+Comma elfogadja a javasolt helyet" (szöveg a `virtual-train-driving.cfg`-be). Ez a "mielőtt lerakná, ne utólag" követelmény.
3. A javasolt hely a támasz-tervező (5. fejezet, (ii) algoritmus) **egy-lépéses** hívása: a jelenlegi futam végpontjai közül visszafelé az első rakható (`can_place_entity`). Így a VTD és a Syntrax ugyanazt a modult használja, csak más bemenettel (teljes futam vs. futam-eddig).
4. Két üzemmód, beállításként (`scripts/ui/menus/settings` / `locale/en/settings.cfg` kiegészítésével): **"kérdez"** (fenti viselkedés) vagy **"automatikus"** (a mod a lépés előtt csendben lerakja a javasolt támaszt, és a tile-olvasásban jelzi "támasz lerakva (x, y)"). Vak felhasználónak a "kérdez" a biztonságosabb alapértelmezés, mert a támasz költséggel jár és a terepet is foglalja; a "automatikus" a tapasztalt felhasználóé.
5. A `vtd.Move` rekord (53–59. sor) kap `support_entities` listát; a `pop_move` (348–401.) előbb a sínt, utána a támaszokat távolítja el (5.4 sorrend-szabály).

### 9.4. Rázárás elevált sínre, és a kurzor "rétege"

- `lock_on_to_rail` (538–602.): az `is_rail_entity` (33–38.) és a típus-leképezés bővítése után elevált sínre is rázárható. Gond: a `player.selected` kiválasztás az `entity-selection.lua` −1 prioritása miatt földi és elevált átfedésnél a földit adja. Javaslat: a VTD rázárásnál, ha a tile-on mindkét réteg van, a mod **kérdezzen** ("földi vagy elevált sín?" — két gomb: bal zárójel = földi, Shift+bal zárójel már foglalt (force), ezért pl. Alt+bal zárójel = elevált), VAGY vezessen be egy "kurzor-réteg" kapcsolót, amely a tile-olvasás sorrendjét és a rázárás célját is meghatározza. Az utóbbi általánosabb (a 8.2/3. tile-olvasás is használja), de egy új állapotot ad a felhasználó fejébe; ezt a 10. fejezet 4. kérdése hagyja nyitva.
- `announce_rail` (403–420.): a réteg bemondása ("building rails, elevated, facing north"); rámpán állva "on ramp, going up".
- Rámpa lerakása után a VTD automatikusan a rámpa elevált végére áll (a Traverser `move_change_layer` ezt adja), a tile-olvasás pedig a rámpa felső végét írja le.

### 9.5. Új VTD-üzenetek (locale, javaslat)

`virtual-train-driving.cfg`: rétegváltás sikeres ("now elevated, facing north" / "now on ground"); rétegváltás elutasítva, ok-kóddal ("can only change layer from north, east, south or west"); támasz kell ("support needed here before continuing"); támasz lerakva; támasz javasolt helye nem található ("no valid support position between here and the last support — clear the area or go back"); rázárás réteg-kérdés.

### 9.6. Közös vagy külön logika?

Közös. Mindkét út a Traverser-t és a lerakási pipeline-t használja; a támasz-tervező egyetlen modulja (`scripts/rails/support-planner.lua`) két belépési ponttal (teljes futam / inkrementális) lefedi mindkettőt, és a hibaüzenet-szövegek is közösek lehetnek. Az egyetlen szándékos különbség a **döntési pont**: a Syntrax egyben tervez (a program végén tudja a teljes futamot), a VTD lépésenként kérdez. Ez nem két algoritmus, hanem ugyanannak az algoritmusnak két hívási mintája.

---

## 10. (f) Nyitott kérdések — döntési pontok a megbízó számára

1. **G-gomb.** (a) Marad minden a helyén, és az elevált funkciók a 9.2 szerinti Comma-kombinációkra mennek — a vanilla G-toggle a mod számára láthatatlan marad, de nem is zavar (ha az E7 kísérlet igazolja, hogy a mod blueprint-építését nem befolyásolja). (b) A `fa-g` `consuming` értékének váltásával a mod elnyomja a vanilla toggle-t sín-planner mellett (tiszta, de a #204 vita miatt upstream egyeztetést igényel). (c) A `fa-s-g`/`fa-c-g` vonatkapcsolást a #204 szellemében máshová költöztetjük, és a G-család egy részét felszabadítjuk — ez a legnagyobb változás, és a mostani session-ben épp visszaállított funkciót érinti. Javaslat: (a) most, (c) upstream-egyeztetés után.
2. **UX-visszajelzés gyakorisága.** Syntraxban minden rétegváltásról külön mondat, vagy csak összefoglaló a végén ("placed 23 rails, 2 ramps, 3 supports")? Javaslat: összefoglaló + a `syntrax-placed` üzenet bővítése darabtípusonként; a hibák továbbra is azonnal.
3. **Túl hosszú futam támasz nélkül.** Automatikus tervezés alapértelmezés (`autosup on`) — ekkor a kérdés nem merül fel; `autosup off`-nál előzetes hiba (5.5). Döntendő: legyen-e egyáltalán `autosup off`, vagy csak `nosup` pont-tiltás.
4. **Kurzor-réteg állapot.** Bevezessünk-e egy globális "melyik réteget nézem/építem" kapcsolót (tile-olvasás sorrendje, rázárás célja, szkenner-szűrő), vagy minden helyen kontextuális kérdés legyen? A kapcsoló konzisztensebb, de egy új, elfelejthető állapot.
5. **`up`/`down` vs. egyetlen `elev`.** A tervben mindkettő szerepel; dönteni kell, melyik az elsődleges a dokumentációban és a chord-betűnél (`u`/`d` vs. `e`).
6. **A támasz iránya.** Ha az E5 kísérlet szerint a támasz irányának a sín irányával egyeznie kell, a tervező egyszerűsödik; ha bármely irány jó, a jelölt-ellenőrzés irány-listát is próbál.
7. **`get_rail_extensions` elevált végekről.** Az E1–E2 kísérlet dönti el, kell-e saját planner item a kinyeréshez.
8. **DLC nélküli játék.** A mod továbbra is fusson elevated-rails nélkül: a `get_planner_description` kétszintű validációja (7. fejezet) ezt biztosítja; a tutorial szövegét két változatban kell tartani (DLC-vel/anélkül)?
9. **Jelzők rétege a blueprintben.** E3 kísérlet.

---

## 11. In-game ellenőrző lista (a kódolás ELŐTT futtatandó kísérletek)

Ezek dokumentációból nem dönthetők el; mindegyik egy-egy rövid in-game próba (konzol, editor vagy a `/railtable` futtatása). Az eredmény a fenti fejezetek jelölt pontjait véglegesíti.

| # | Kérdés | Hogyan | Melyik döntést érinti |
|---|---|---|---|
| E1 | A vanilla `rail` item `.rails` listája tartalmazza-e az `elevated-*` és `rail-ramp` neveket? Van-e `support` mezője? | konzolról a `prototypes.item["rail"].rails` és `.support` kiíratása; ugyanez a `rail-ramp` itemre | 4.1/4. pont (kinyerő planner-paramétere), 7. fejezet validáció |
| E2 | Elevált sín és rámpa `create_entity`-vel létrehozható-e támasz nélkül (a kinyeréshez)? Ghostja `build_from_cursor`-ral lerakható-e támasz-ghost nélkül? | editor-felületen próbalerakás; majd egy egy-entitásos blueprinttel | 4.1/3. pont; 5.4 sorrend-szigorúság (ha a ghost sem rakható, a támasz-ghost mindig előbb kell) |
| E3 | Jelző elevált sín mellé: kell-e a blueprint-entitásba réteg-mező, és átfedő földi/elevált pályánál melyik sínhez kapcsolódik? | két átfedő pálya építése, jelző-blueprint lerakása, `LuaEntity.rail_layer` olvasása a jelzőn | 4.5 jelző-pont |
| E4 | A `support_range` pálya menti vagy légvonalbeli távolság-e, és hány egyenes/kanyar fér egy támasz két oldalára? | rámpa + egyenesek egyesével, `can_place_entity`/lerakás próbálgatva, amíg elutasít | 5.1 modell, 5.3 képletek |
| E5 | A támasz hová illeszkedik (sín-végpontra? bármely 2×2 rácspontra?) és kell-e iránynak egyeznie a sínnel? | támasz lerakása különböző pozíciókra/irányokra meglévő elevált sín alá; `snap_to_spots_distance` hatásának megfigyelése | 5.1 jelölt-halmaz, 5.3 (iv) |
| E6 | A vanilla `rail-support` `not_buildable_if_no_rails` értéke; lerakható-e üres terepre (a tervező a sín ELŐTT rakja) | `prototypes.entity["rail-support"]` mezői; próbalerakás üres helyre | 5.4 sorrend: ha a támasz nem rakható sín nélkül ÉS a sín nem rakható támasz nélkül, csak **ghost-pár + együttes revive** működik — ez a pipeline-t érdemben alakítja |
| E7 | A vanilla G-toggle állapota befolyásolja-e a mod blueprint-alapú `build_from_cursor` építését? | sín-planner a kézben, G megnyomása, majd VTD-lépés; a lerakott entitás neve | 9.2, 10/1. kérdés |
| E8 | `get_rail_extensions` egy elevált végről és a rámpa két végéről pontosan mit ad (darabszám, `goal.rail_layer`)? | `/railtable` bővített seed-listával, a kimenet átnézése | 2.1, 4.1/6. verifikáció |

---

## 12. Kockázatok és munkaméret

- **Legnagyobb kockázat:** E6 kimenetele. Ha a támasz és az elevált sín kölcsönösen függ egymástól (egyik sem rakható a másik nélkül valódi entitásként), a jelenlegi "ghost → silent_revive egyesével" pipeline nem elég, és ghost-párok együttes revive-ja kell. Ez a runner és a VTD lerakási kódját mélyebben érinti, mint a terv többi része.
- **Közepes kockázat:** a `rail-data.lua` újragenerálásának hiányzó konverziós lépése (3. fejezet megjegyzése) — ha nem kerül a repóba, a következő játékfrissítésnél a tábla elavul, és a hiba nehezen diagnosztizálható.
- **Alacsony kockázat, de sok érintett hely:** a `RailType` (B modell) átvezetése — mechanikus, de a `railutils/tests/` és `syntrax/tests/` dry-run tesztjei jól fogják.
- **UX-kockázat:** a G-gomb kérdés nem a kód, hanem a közösségi egyeztetés miatt húzódhat; a 9.2 javaslat ettől függetlenül szállítható.

Becsült sorrend és méret (egy fejlesztő, részmunkaidőben): A fázis 2–4 nap (a kísérletekkel együtt); B+C 1–2 hét; D 3–5 nap; E (támasz-tervező) 1–2 hét kísérletezéssel; F 3–5 nap; G 3–5 nap; H 1–2 nap. A fázisok A→B→C→D→E→F→G→H sorrendje a függőségeket követi, de F (beszéd) és G (VTD-UX) egy része már C után, az E-vel párhuzamosan elkezdhető.

---

## Függelék: hivatkozott fájlok listája

`control.lua` (3270., 3521–3525., 3595–3599., 4216., 4250., 4279.); `data/input.lua` (772–792., 1264–1362. billentyű-bejegyzések); `scripts/consts.lua` (95–103.); `scripts/entity-selection.lua` (30–43.); `scripts/scanner/surface-scanner.lua` (89–92., 133., 136.); `scripts/fa-commands.lua` (110–134.); `scripts/fa-info.lua` (1378–1412.); `scripts/tile-reader.lua` (38–100., 124–125.); `scripts/blueprint-synthesizer.lua`; `scripts/building-tools.lua` (227–234.); `scripts/rails/build-helpers.lua` (45–206.); `scripts/rails/surface-helper.lua`; `scripts/rails/syntrax-runner.lua`; `scripts/rails/table-extractor.lua` (1–30., 80–145., 204–285.); `scripts/rails/virtual-train-driving.lua` (25–41., 53–66., 85–93., 154–246., 313–401., 403–420., 538–602., 618–686., 804–878., 880–951., 955–993.); `scripts/rails/primary-finder.lua`; `scripts/rails/announcer.lua` (72.); `scripts/ui/menus/rail-builder.lua` (19–60.); `scripts/ui/router.lua` (1117–1132.); `railutils/rail-info.lua`; `railutils/queries.lua`; `railutils/traverser.lua`; `railutils/rail-describer.lua` (16–24., 67–232., 241.); `railutils/rails-surface.lua`; `railutils/surface-impls/game-surface.lua`; `railutils/surface-impls/test-surface.lua`; `railutils/rail-data.lua`; `railutils/tests/*`; `syntrax/lexer.lua` (100–127., 149–160., 281–330.); `syntrax/parser.lua` (133–193.); `syntrax/ast.lua`; `syntrax/compiler.lua` (57–131.); `syntrax/vm.lua` (31–52., 78–93., 116–118., 187–220., 358–398., 407–483.); `syntrax/tests/*`; `docs/features/rails.md`; `docs/features/syntrax.md`; `devdocs/rail-geometry.md`; `locale/en/controls.cfg`; `locale/en/virtual-train-driving.cfg`; `locale/en/rail-announcer.cfg`; `locale/en/syntrax-program-names.cfg`; `locale/en/message-lists.cfg` (28.); `locale/en/tutorial/ch1.txt` (21.); `llm-docs/api-reference/runtime/classes/LuaRailEnd.md`, `LuaEntity.md`, `LuaSurface.md` (346–362.), `LuaItemPrototype.md` (517–533.); `llm-docs/api-reference/runtime/concepts/RailLocation.md`, `RailExtensionData.md`; `llm-docs/api-reference/runtime/defines/rail_layer.md`, `build_check_type.md`; `llm-docs/api-reference/prototypes/prototype/RailRampPrototype.md`, `RailSupportPrototype.md`, `RailPlannerPrototype.md`.
