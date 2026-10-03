# Review: az elevated rails bekötési terv (ELEVATED_RAILS_TERV.md)

Készült: 2026. október 2. — Opus 5.5 review, kód nélkül. A vizsgált dokumentum a mod gyökerében lévő `ELEVATED_RAILS_TERV.md` (md5 `0e5dd4c9…`, a leadott példánnyal bitre azonos, tehát azóta senki nem módosította).

Mivel a tervet ugyanebben a munkamenetben egy korábbi modell (Fable 5.1) írta, ezt a reviewt szándékosan úgy végeztem, mintha idegen munka lenne: minden állítást újra a forrásból ellenőriztem, és ahol a terv tévedett, azt kimondom.

## Mit néztem át

A teljes lokális API-dokumentációt célzottan: a `llm-docs/api-reference` mappa szerkezetét és verzióját (a `runtime/metadata.md` és `prototypes/metadata.md` szerint **2.1.19**, a játékod a log szerint **2.1.20** — az `api-reference/CLAUDE.md` "2.0.73" felirata elavult), és minden rail/elevated/ramp/support/layer/feature-flag találatot a runtime és prototype ágakban. A changelogokat: `CHANGES.md` (3575 sor), `changelog.txt`, `changelog_dzsoker_claude.md` és a `-1` másolat. Az md-fájlokat: `CLAUDE.md`, `CONTRIBUTING.md`, `STYLE-GUIDE.md`, `MIGRATION-2.1.md`, `README.md`, `docs/` és `devdocs/` minden releváns fájlja, `.claude/commands/devplaytesting.md`. A UX-et: `data/input.lua`, `control.lua` VTD- és lock-on kezelői, `scripts/ui/router.lua`, a launcher `config_changes/` rendszere és a te `config/config.ini`-d. Végül két olyan forrást, amelyről a terv nem tudott: a `script-output/data-raw-dump.json` (a teljes vanilla prototípus-dump, 2026-05-21) és a saját `railpoc` git-ágad.

## Összegzés

A terv iránya jó, és a fő architekturális állítása kiállta az ellenőrzést: a geometria tényleg egy motorból kinyert tábla, a bővítés tényleg a kinyerő sémájánál kezdődik, és a támasz-elhelyezés tényleg a mod saját feladata. **Implementálni viszont még nem érett**, három okból. Először: több ténybeli adata téves (főleg a vanilla számértékek, amelyek valójában a prototípus-doksi *alapértékei*, nem a vanilla játék értékei), és ezek pont a legnehezebb részt, a támasz-tervezőt érintik. Másodszor: kimaradt néhány valódi kockázat, amelyek közül egy azonnal ártani tud (a `/railtable` újrafuttatása a te Space Age-es telepítéseden csendben elronthatja a földi geometriát). Harmadszor: néhány döntés még a te asztalodon van, és ezek közül kettő (upstream vagy saját fork; a G-gomb kezelése) a munka sorrendjét is meghatározza.

A jó hír: a nyolc in-game kísérletből kettő (E1, E6) a prototípus-dumpból már most megválaszolható, egy harmadikra (E8) a `railpoc` ágad erős jelet ad, a G-problémára pedig van egy, a projektben már bevett, tiszta megoldás.

---

## 1. Ténybeli hibák a tervben

### H1. A támasz és a rámpa számértékei rosszak — ezek doksi-alapértékek, nem vanilla értékek

A terv 2. fejezete és az 5.1 pont `support_range = 15.0`, `snap_to_spots_distance = 1.0`, "8 irány", "kb. 4×4 ütköződoboz" és "16×4 rámpa" értékekkel számol. Ezek a `RailSupportPrototype.md` / `RailRampPrototype.md` **alapértelmezései**. A tényleges vanilla prototípusok a `script-output/data-raw-dump.json` szerint:

| | terv szerint | valójában (dump) |
|---|---|---|
| `rail-support` `support_range` | 15.0 | **11** |
| `rail-support` `snap_to_spots_distance` | 1.0 | **3** |
| `rail-support` irányok | 8 | **16** (`building-direction-16-way`) |
| `rail-support` ütköződoboz | ~4×4 | **±1.39** (kb. 2.8×2.8) |
| `rail-support` különleges flag | — | **`snap-to-rail-support-spot`** |
| `rail-ramp` `support_range` | 15.0 | **9** |
| `rail-ramp` ütköződoboz | ±1.6 × ±7.6 | **±1.8 × ±7.8** (3.6 × 15.6) |
| `rail-support` `not_buildable_if_no_rails` | "ellenőrizendő" | nincs megadva → **false** |

(Megjegyzés: a `RailRampPrototype.md` "hardcoded to `{{-1.6,-7.6},{1.6,7.6}}`" mondata maga sem egyezik a dumppal, tehát a doksi ezen a ponton megbízhatatlan.)

Következmény: a 5.3 képletei rossz számokkal indulnának, és a támasz-tervező jelölt-halmaza is más (lásd K2). Szabály a v2 tervbe: **a hatótávot soha ne kódold be**, futásidőben olvasd a `LuaEntityPrototype.support_range` mezőből (`llm-docs/api-reference/runtime/classes/LuaEntityPrototype.md` 2503. sor, `RailSupport` és `RailRamp` alosztályokon). Ajánlott a dumpot a 2.1.20-on újragenerálni (`--dump-data`), mert a mostani 2026-05-21-i.

### H2. Az E1 kísérlet már eldőlt

A dump szerint a vanilla `rail` item (`rail-planner`) `rails` listája mind a kilenc nevet tartalmazza (`straight-rail`, `curved-rail-a`, `curved-rail-b`, `half-diagonal-rail`, `rail-ramp`, és a négy `elevated-*`), a `support` mezője `rail-support`. A `rail-ramp` item maga is `rail-planner`, ugyanezzel a listával, `place_result = rail-ramp`. Tehát a 4.1/4. lépés ("kell-e saját planner item a kinyeréshez") várhatóan nem kell, és a `scripts/rails/surface-helper.lua` `get_planner_description` (12–55. sor) **már ma is** látja az elevált neveket minden SA-s mentésben — csak csendben eldobja őket.

### H3. Az E6 kockázat ("kölcsönös függés") nagyrészt megszűnt — helyette más jön

Mivel a `not_buildable_if_no_rails` false, a támasz sín nélkül is lerakható; a terv 12. fejezetében leírt "egyik sem rakható a másik nélkül" holtpont nem áll fenn. Helyette egy másik, a terv által nem látott mechanizmus lép be: a támasz **sín-támaszpontra ugrik** (lásd K2). Ez a "támasz előbb, sín utána" sorrendet (terv 5.4) kérdésessé teszi.

### H4. A lock-on viselkedéséről szóló állítás téves, és van mögötte egy már ma élő hiba

A terv 9.4 szerint "az `entity-selection.lua` −1 prioritása miatt átfedésnél a földi sín nyer". Valójában minden sín −1 prioritású, és a döntetlent a `unit_number` dönti el, a régebbi entitás javára (`scripts/entity-selection.lua` 86–130. sor) — tehát az építési sorrend, nem a réteg. A vanilla `selection_priority` (elevált 55, földi 45) itt nem számít, mert a mod saját rendezést használ.

Ennél fontosabb, amit a terv nem vett észre: a rázárás a `get_first_ent_at_tile` **első** entitását nézi, és csak akkor zár rá, ha annak típusa a 4 földi típus egyike (`control.lua` 3267–3274., force: 3518–3529., superforce: 3595–3601. sor). Ha egy tile-on az első entitás elevált sín, rámpa vagy támasz, a kattintás "átesik a normál kattintásra", ami sín-plannerrel a kézben **építési kísérlet**. Ez SA-s mentésben már ma is így van, a bővítéstől függetlenül.

### H5. Az Alt+[ javaslat ütközik

A 9.4 elevált rázárásra Alt+bal zárójelet javasol. Ez foglalt: rázárt állapotban a rail-builder menüt nyitja (`control.lua` 3306–3314. sor, `fa-a-leftbracket`; `docs/features/rails.md` "Building Larger Layouts").

### H6. A tutorial-bővítés téves, a "kapcsold ki" szöveg pedig nem csak az elevated rails-ről szól

A terv 1.3 és 4.8 szerint a `ch12/ch13/ch15` vonatos fejezeteit kell kiegészíteni. A `ch12.txt` első sora szó szerint: "This tutorial doesn't teach trains"; a ch13/ch15 csak mellékesen említ vonatot. Ide nem kell elevált tartalom.

A "disable quality, elevated rails, and space age" utasítás pedig az upstream általános álláspontja ("we do not yet support Space Age", `README.md` 12. sor), és öt helyen szerepel a README-ben (12., 72., 89., 99., 115. sor), plusz `ch1.txt` 21., `message-lists.cfg` 28., `docs/tutorial-transcript.md` 25. sor. Az elevated rails támogatása egyedül nem teszi visszavonhatóvá, mert a quality és a Space Age ugyanabban a mondatban van. A terv ezt a pontot túl egyszerűnek mutatta.

### H7. Nem kell új custom-input, de control.lua-kezelő igen

A 4.7 "`data/input.lua` (új custom-input bejegyzések)" pontja felesleges: a `fa-s-comma`, `fa-c-comma`, `fa-cs-comma` már létezik (`data/input.lua` 1296–1330. sor), és ma csak UI-kontextusban él (`scripts/ui/router.lua` 1122–1126. sor; a `register_ui_event` nyitott UI nélkül átengedi az eseményt, 636–644. sor). Ami kell: új WORLD-kezelők a `control.lua`-ban, a meglévő VTD-minta szerint (`control.lua` 4308–4350. sor), mert a `CONTRIBUTING.md` szerint "New event handler registrations belong in control.lua".

Erősítés: a terv billentyűválasztása (comma-család a VTD-ben) **egyezik a projekt szabályával** — a `CONTRIBUTING.md` kimondja, hogy kevés a szabad billentyű, "the exception is m, comma, and dot, which are reserved for context sensitive uses", és a `ch13.txt` 77. sora ugyanezt tanítja a játékosnak. Ezt érdemes a tervben indoklásként szerepeltetni, mert upstream felé ez a legerősebb érv.

### H8. A G-kérdésre van bevett megoldás, a terv nem ismerte

A terv 10/1 kérdésének (b) opciója a `consuming` mező átállítása. A projektben ehelyett a **launcher config change set** a bevett út: a mod `config_changes/` mappájában verziózott `.ini` fájlok vannak (`AB_initial.ini` … `AE_unmap_pipette.ini`), a launcher (`fa_launcher/modify_config.py`) ezeket indításkor felajánlja és alkalmazza. Pontos precedens: `AD_unmap_driving_alternative.ini` — "Unmap toggle-driving-alternative so g can read armor stats"; az `AB_initial.ini` pedig a vanilla `connect-train=` / `disconnect-train=` vonatkapcsolást is ugyanígy üríti ("Mod provides train operations").

A vanilla vezérlő neve `toggle-rail-layer` (`llm-docs/api-reference/prototypes/concepts/LinkedGameControl.md`). A te `config.ini`-d `[controls]` szekciója ezt nem írja felül, tehát nálad most is G-n él. Javaslat a v2-be: egy `AF_unmap_toggle_rail_layer.ini` change set, `toggle-rail-layer=` értékkel és egy egysoros indoklással. Ezzel a G-ütközés a meglévő gombkiosztás érintése nélkül megszűnik, és a #204 vitát sem kell előbb lezárni.

### H9. A beállítás helye

A 9.3 pont "`scripts/ui/menus/settings`" helyet említ. A `CLAUDE.md` szerint a beállítás a `scripts/settings-decls.lua`-ba és a `locale/en/settings.cfg`-be kerül; a beállítás-menü ebből automatikusan épül.

### H10. A "hiba helyett nil" javaslat ellentmond a projekt kódolási elvének

A terv 3. fejezetének 5. sora a `prototype_type_to_rail_type` `error`-ját `nil`-re cserélné, a 4.3 pedig a Traverser `_get_extension`-jét. A `CLAUDE.md` "Defensive Coding" szakasza kifejezetten ezt tiltja ("Excessive validation hides bugs. Let code crash"), és csak UI-belépési pontokon enged ellenőrzést. A v2-ben a mag maradjon hibát dobó; a felhasználó által kiváltható eseteket (rázárás, tile-olvasás, rétegváltás rossz irányból) egy külön, nem dobó lekérdezés kezelje a belépési ponton (pl. "ismert sín-prototípus-e", "lehet-e itt rétegváltás").

### H11. A polyfill hiányzik a réteghez

A `railutils/` és `syntrax/` a `scripts/`-en kívül van, ezért a `CONTRIBUTING.md` szerint Factorio-API nélkül, offline kell futnia. A `polyfill.lua` csak `defines.direction` és `defines.rail_direction` értékeket ad (36–39. sor), `rail_layer`-t nem. A terv saját `RailLayer` enumja jó irány, de ki kell mondani: string-alapú legyen, vagy a polyfillt bővíteni kell, különben a `railutils-tests.lua` eltörik.

---

## 2. Kimaradt kockázatok és tervezési hiányok

### K1. A `/railtable` újrafuttatása most veszélyes

Mivel a vanilla `rail` planner listájában a `rail-ramp` is benne van (H2), és a `railpoc` ágad kódja arra épült, hogy a `get_rail_extensions("rail")` egy földi kardinális végről a rámpát is visszaadja (lásd K10), a **mostani** kinyerő (`scripts/rails/table-extractor.lua` 266. sor, kulcs csak `goal_direction`) a te SA-s telepítéseden futtatva a földi egyenes kiterjesztést felülírhatja a rámpáéval — a sorrendtől függően, csendben. A jelenlegi `rail-data.lua`-ban nulla "ramp" szó van, tehát az upstream valószínűleg SA nélkül generálta. A v2-ben ez legyen az első szabály: **séma-javítás előtt tilos újragenerálni**, és a kinyerő álljon meg hibával, ha egy `(irány, réteg)` kulcsra két kiterjesztés jönne.

### K2. A támasz ugrik — ez felborítja a sorrendet és a ghost-keresést

A `snap-to-rail-support-spot` flag és a 3 mezős `snap_to_spots_distance` azt jelenti, hogy a játék a támaszt a legközelebbi sín-támaszpontra húzza. Ebből két gond következik, amit a terv nem kezel. Az egyik: ha a támasz-ghost a sínek előtt kerül le (a terv 5.4 javaslata), még nincs támaszpont, amire ugorhatna, így lehet, hogy rossz helyen marad, és a később lerakott sínt nem tartja. A másik: a lerakás utáni ghost-keresés 1 mezős sugárral dolgozik (`scripts/rails/build-helpers.lua` 48. és 69. sor; a VTD másolatában 114. és 135. sor), tehát egy 3 mezőt ugrott támasz-ghostot nem talál meg — a mod "cannot build"-et mond, és egy elárvult ghost marad a pályán.

Valószínűbb helyes sorrend, amit a kísérletnek kell igazolnia: előbb az összes sín-ghost, aztán a támasz-ghostok (ezek ráugranak a pontokra), és **revive-oláskor** fordítva: előbb a támaszok, aztán a sínek. A támasz-ghost megkeresése pedig ne pozíció+sugár alapon történjen, hanem a lerakás előtti és utáni állapot különbségéből, vagy legalább a snap-távolsággal megnövelt sugárral.

### K3. Nem vizsgált alternatíva: egyetlen blueprint az egész elevált futamra

A pipeline már ma is blueprinttel épít (`scripts/blueprint-synthesizer.lua`), csak darabonként egy-entitásosat. Egy elevált futam (rámpák, sínek, támaszok) egyetlen szintetizált blueprintként lerakva a vanilla blueprint-logikára bízná az ugrást és a függőségeket — a látó játékosok így építik a hidakat. Ára: elveszik a darabonkénti alternatíva-próbálgatás (jelzőknél fontos), nehezebb pontos hibát mondani ("a 7. darabnál akadt el"), és a force/superforce módban a "részleges siker" amúgy is nem észlelhető (`CHANGES.md` 0.16.54). A `CONTRIBUTING.md` kifejezetten kéri, hogy egy javaslat legalább két megoldást mérlegeljen; ez a második jelölt a támasz-lerakásra, és a v2-ben össze kell mérni a darabonkénti úttal.

### K4. Kutatási zár

A `LuaForce.rail_planner_allow_elevated_rails` (`llm-docs/.../LuaForce.md` 179. sor) dönti el, hogy a csapat építhet-e elevált sínt; ezt az `elevated-rail` technológia állítja (dump: `rail-planner-allow-elevated-rails` effekt). A `rail_support_on_deep_oil_ocean` a `rail-support-foundations` kutatásé. A terv ezt egyáltalán nem említi. A rétegváltásnak ezt ellenőriznie és bemondania kell, és a kinyerést is kutatott állapotban kell futtatni (nem tudni, hogy a `get_rail_extensions` figyel-e rá).

### K5. Space Age felismerése

A terv 10/8 kérdése ("DLC nélküli játék") megválaszolható: `script.feature_flags.rail_bridges` (`LuaBootstrap.md` 25. sor, `FeatureFlags.md`). Vigyázat: a dumpban `dummy-elevated-*`, `dummy-rail-ramp`, `dummy-rail-support` prototípusok is vannak, tehát a "létezik-e ilyen típus" vizsgálat félrevezethet; a név szerinti `prototypes.entity["rail-ramp"]` vagy a feature flag a biztos.

### K6. A "távolság az utolsó támasz óta" számláló törékeny

A 9.3 egy VTD-állapotba írt számlálóval akarja megmondani, kell-e támasz. Ez több úton elcsúszik. A Syntrax nem lépteti a virtuális vonatot: a `VTD.execute_syntrax` csak visszaadja a lerakott entitásokat, a VTD a kiinduló ponton marad (`scripts/ui/menus/rail-builder.lua` 53–62., `scripts/ui/internal/syntrax-input.lua` 39. sor). Újra-rázáráskor a számláló nulláról indul. Robotok, a játékos vagy egy másik játékos bármikor elbonthat egy támaszt. Javaslat: a lefedettség-ellenőrzés legyen **állapotmentes**, minden lépés előtt a világból számolva (a következő darab körül a legnagyobb `support_range` sugarán belüli valódi és ghost támaszok/rámpák), a lépés-verem pedig csak a visszavonáshoz kelljen.

### K7. Jelzők és állomások egymás feletti pályákon

Egymás felett futó földi és elevált pálya jelzőhelyei XY-ban egybeeshetnek. A `scripts/rails/signal-station-classifier.lua` `get_signal_type_at` (39–46. sor) csak pozíció alapján keres (`surface.find_entity("rail-signal", position)`), tehát a másik réteg jelzőjét is a sajátjának mondhatja. Megoldás: a jelző `rail_layer` mezőjét (`LuaEntity.md` 1883. sor, csak jelzőkön) össze kell vetni a sínvég `location.rail_layer`-jével. A vonatmegállónak nincs elevált változata (dump: a `train-stop` prototípusban nincs elevált kulcs), tehát a `has_adjacent_station` egy állomás feletti elevált sínre ne mondja, hogy "at station". A `stop-preview.lua` a motor `LuaRailEnd` bejárását használja, az réteg-független, rendben van. Ezek a fájlok hiányoznak a terv 3. fejezetének táblázatából.

### K8. Teljesítmény

A `railutils/surface-impls/game-surface.lua` `get_rails_at_point` névenként külön `find_entities_filtered` hívást végez (74–79. sor). A terv szerint ez 4-ről 9 névre nő, és a leíró egy tile leírásához (forduló-felismerés, elágazás-keresés) sokszor hívja, tehát a kurzormozgatás minden lépésén többszöröződik. A `find_entities_filtered` név-tömböt is elfogad, ezt egy hívásra kell összevonni. A `CONTRIBUTING.md` kifejezetten figyelmeztet a gyakran futó utakra.

### K9. Duplikált geometria

A dump szerint az elevált sínek ütköződoboza bitre azonos a földiekével, és a prototípus-doksi szerint öröklik is őket (pl. `ElevatedCurvedRailAPrototype` szülője `CurvedRailAPrototype`). A terv B-modellje (alaptípus + külön réteg) ehhez illik, de a 4.1 a seed-listát egyszerűen megduplázná, és ezzel a 6506 soros tábla kb. kétszeresére nőne haszon nélkül. Javaslat: a kinyerés mindkét réteget mérje ki, egy offline teszt igazolja az egyezést, és a tábla a geometriát egyszer tárolja, kiegészítve kardinális végenként egy "rámpa fel" és egy "rámpa le" kiterjesztéssel (a kettő pozíciója nem azonos, ezért kell mindkettő).

### K10. Előzmény, amit a terv nem ismert: a `railpoc` ágad

A `railpoc` ágon (`scripts/railplan.lua`, 307 sor, commitok 2025-11-07 és 2025-11-11 között: "rail forward done", "first rail iteration done", "partialy working state") már van egy `extend_ramp`, amely a `get_rail_extensions("rail")` eredményei közül azt választja, ahol `chosen_end.location.rail_layer ~= ext.goal.rail_layer`, a "forward" ág pedig kifejezetten azonos rétegre szűr. Ez erős jel (de nem bizonyíték, mert a commitüzenetek szerint a kód csak részben működött, és nem tudni, a rámpa-ág lefutott-e) arra, hogy a rámpa kiterjesztésként visszajön (K1 és a terv 0/2. pontja), és hogy a `RailLocation.rail_layer` a sínvégeken olvasható. A támaszt az a próbálkozás sem kezelte. Te emlékszel rá, hogy az `extend_ramp` működött-e? Ha igen, az E11 kísérlet elhagyható. A v2 hivatkozzon rá mint előzményre.

### K11. Egyéb kisebb pontok

A régi (`legacy-straight-rail`, `legacy-curved-rail`) sínek léteznek a dumpban és az `entity-selection.lua`-ban; a tervnek ki kell mondania, hogy ezek kívül esnek a hatókörön. A rámpán nem lehet jelző: a Syntrax `up` után közvetlenül kiadott `sig` legyen érthető hibaüzenet, ne a lerakásnál bukjon el. A költség rendben van: az `InventoryUtils` a `items_to_place_this` mezőből dolgozik (`scripts/inventory-utils.lua` 121–186. sor), így a rámpa és a támasz itemje automatikusan levonódik, az elevált sín pedig a földivel azonos darabszámú `rail` itembe kerül (1/3/3/2). A force build a `CHANGES.md` 0.16.26 szerint feltöltést is rak le víz fölé; nem tudni, hogy egy elevált sín blueprintje víz felett feltöltést kér-e (lásd E9). Az új locale-kulcsoknak át kell menniük a `lint_localisation.py`-n, és követniük a `CLAUDE.md` beszéd-szabályait (az eltérő információ elöl, kettőspont és zárójel nélkül — a terv réteg-előtagos megoldása ennek megfelel).

---

## 3. Folyamati előfeltétel: upstream vagy saját fork?

A `CONTRIBUTING.md` szerint funkció-PR előtt egyeztetni kell, és a javaslatnak tartalmaznia kell az indoklást, a mérlegelt alternatívákat, egy rövid "x-et csinálja, y-nal indítod" összefoglalót és a rendszer-kölcsönhatásokat; felhasználói történeteket is kér. Az upstream jelenleg kimondottan nem támogatja a Space Age-et (`README.md` 12. sor), és a `MIGRATION-2.1.md` is kizárta a hatókörből. A te `changelog_dzsoker_claude.md`-d szerkezete arra utal, hogy a módosításaidat később témánként akarod MR-ként leadni.

Ezért implementálás előtt el kell dönteni: ez upstream-be szánt funkció (akkor kell egy rövid, felhasználói történetekkel kiegészített javaslat és egy Discord-egyeztetés, és a SA-támogatás kérdése is előkerül), vagy a forkodban él (akkor a terv mostani formája elég, csak a v2 javításaival). A terv jelenleg csak a technikai részt tartalmazza.

---

## 4. Mi kell még ahhoz, hogy implementálható legyen

### 4.1. Döntések, amelyek a tiéd

Az első és legfontosabb az előző fejezet: upstream vagy fork. A második a G-gomb: javaslom az `AF_unmap_toggle_rail_layer.ini` change setet (H8), mert precedensen alapul és semmi meglévőhöz nem nyúl. A harmadik a Syntrax szókészlete: `up`/`down` (olvashatóbb) vagy egyetlen `elev` (a te eredeti ötleted, "negálja a réteget"), és ezzel együtt a chord-betűk; a lexer ellenőrzése alapján az `u` és `d` szabad, és a régi mentett programokat nem törik el, mert ismeretlen szó ma is hibát ad (`syntrax/parser.lua` 250. sor). Egy szabály kell hozzá: új kulcsszó nem állhat csupa chord-betűből. A negyedik a VTD-billentyűk (Shift+Comma rétegváltás, Ctrl+Shift+Comma kézi támasz, Ctrl+Comma javaslat elfogadása) — ezek a projekt szabályával egyeznek. Az ötödik a támasz-mód alapértéke a manuális építésnél ("kérdez" vagy "automatikus"). A hatodik az, hogy átfedő rétegeknél hogyan válasszon a rázárás, most már Alt+[ nélkül (H5).

### 4.2. Kísérletek, amelyek még nyitottak

A terv 11. fejezetéből az E1 eldőlt (H2), az E6 nagyrészt (H3), az E8-ra erős jel van (K10), az E7 pedig okafogyottá válik, ha a G-t a change set kiveszi. Ami marad: E2 (elevált sín ghostja lerakható-e támasz nélkül, és a kinyerő `create_entity`-je működik-e elevált darabra), E3 (a jelző-blueprintnek kell-e réteg-mező — a `BlueprintEntity.md` itt csak az általános mezőket sorolja, ebből nem dönthető el), E4 (a `support_range` légvonalban vagy pálya mentén mér-e, és honnan), E5 (hová ugrik a támasz, és milyen sorrend működik — K2), plusz három új: E9 (force build elevált sínnél víz felett kér-e feltöltést), E10 (a `get_rail_extensions` figyel-e a kutatási zárra), E11 (a `railpoc` eredményének megismétlése: egy földi kardinális végről pontosan hány és milyen kiterjesztés jön vissza, `goal.rail_layer`-rel).

Ezek mind egy rövid játékbeli alkalommal lefuttathatók. Minden feltétel adott hozzá: a speech-log szerint mindkét kutatás kész ("Elevated rail research complete", "Rail support foundations research complete"), és van nálad 10 rámpa és 20 támasz. A `devplaytesting.md` szerint a `/fac` paranccsal Lua-részleteket futtathatsz és a kimenetet beszédben kapod vissza; a következő lépés ezért egy kész `/fac`-sorozat összeállítása lehet, kísérletenként egy-egy sorral.

### 4.3. A terv javítása (v2)

A H1–H11 és K1–K11 pontokat bele kell dolgozni. A legfontosabbak: a számértékek cseréje futásidejű olvasásra; a `/railtable` védelme; a támasz-lerakás sorrendjének és ghost-keresésének újratervezése a snap-mechanizmus szerint, a többentitásos blueprint alternatívával összemérve; az állapotmentes lefedettség-ellenőrzés; a kutatási zár és a SA-felismerés; a jelző-réteg szűrés; a lekérdezések összevonása; a geometria egyszeri tárolása; a "let it crash" elvhez igazított hibakezelés; és a hiányzó fájlok felvétele a 3. fejezet táblázatába (`signal-station-classifier.lua`, `control.lua` lock-on ágai, `config_changes/`, `polyfill.lua`, `README.md`).

### 4.4. Tesztelési terv

Ebben a terv jól látott: van offline tesztkör a geometriára és a nyelvre (`railutils-tests.lua`, `syntrax-tests.lua`, `launch_factorio.py --lua-tests`), és a Traverser/VM/leíró bővítései itt játék nélkül ellenőrizhetők. Két dolgot érdemes hozzáírni. A gépeden a mod mappájában nincs `lua52.exe` (csak a `luaunit.lua`), tehát vagy telepíteni kell, vagy az offline teszteket a felhőben kell futtatni. Az in-game tesztekhez (`--run-tests`) pedig a játéknak be kell zárva lennie, mert egyszerre csak egy példány futhat; ezt a kísérletek és a tesztek ütemezésénél figyelembe kell venni.

---

## 5. Javasolt sorrend innen

Először a két stratégiai döntés (upstream vagy fork; G change set). Utána egy kísérleti alkalom a fenti `/fac`-sorozattal. Ezután a terv v2, a kísérleti eredményekkel és a fenti javításokkal. Ha ez megvan, az A fázis (a kinyerő sémájának javítása, védelem, offline ellenőrzés) önállóan elkezdhető, mert semmi más rendszerhez nem nyúl; a támasz-tervező (E fázis) csak a K2 és K3 kérdés eldőlése után.

Röviden: az irány jó, de most még nem kezdeném el. Egy kísérleti alkalom, két döntés és a v2 kell hozzá.
