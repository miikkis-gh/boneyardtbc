# Boneyard TBC Special

World of Warcraft -lisäosa **TBC Classic Anniversary Editionille** (2.5.x), joka suunnittelee ja seuraa optimaalisen dungeon-reitin tasolta 58 tasolle 70. Maksimoi sekä kokemuspisteet että fraktioiden maineen heroic-avainten avaamiseksi ja Karazhan-attunement-questien suorittamiseksi.

Inspiroitu Myron leveling-taulukosta ja BiosparksTV:n oppaasta.

## Ominaisuudet

### Reitin optimointi
- **Balanced-tila** — seuraa Myron optimoitua reittiä ja säätää dungeon-kierrosmääriä dynaamisesti tason ja maineen mukaan
- **Leveling-tila** — ahne XP/tunti-maksimoija, joka valitsee parhaan dungeonin tasollesi huomioimatta maine-tavoitteita
- Tunnistaa automaattisesti faktion, rodun, tason ja maineen — nollakonfiguraatio
- Human-rodun 10% maine-bonus lasketaan automaattisesti
- Valinnaiset questiketjut: Karazhan attunement, Arcatraz-avain, Shattered Halls -avain

### Reaaliaikainen seuranta
- **Automaattinen eteneminen** — tunnistaa dungeon-suoritukset, quest-palautukset, aluevaihdot, tasojen nousut ja maineen kasvun
- **XP-palkki** nykyisellä/maksimi-edistymisellä
- **Maine-palkit** fraktioittain värikoodatuilla tasoilla ja edistymisellä kohti tavoitetta
- **Dungeon-laskuri** — "Kierros X / Y" nykyiselle vaiheelle
- **Attunement-tarkistuslista** — heroic-avaimet ja Karazhan-virstanpylväät

### Kelluva overlay
- Kompakti raahattava paneeli:
  - **Instance-lukitus** — X/5 ajastimella, värikoodatut varoitukset
  - **Session-kierrokset** — dungeonit tällä sessiolla
  - **XP/h** ja **Maine/h** — laskettu session-datasta
  - **Keskim. kierrosaika** — keskimääräinen dungeonin kesto
- Vaihda näkyvyyttä minikartan painikkeen oikealla klikillä tai asetuksista

### Älykkäät hälytykset
Chat-viestit ääniefekteillä tärkeissä tapahtumissa:

| Tapahtuma | Ääni |
|-----------|------|
| Dungeon-kierros valmis | Ilmoitusääni |
| Reitin vaihe edennyt | Quest complete -fanfaari |
| Maine-virstanpylväs (uusi taso) | Reputation up |
| Instance-lukitusvaroitus (4/5) | Raid warning |
| Instance-lukitus täynnä (5/5) | Raid warning |
| Kiltaläinen samassa dungeonissa | Ilmoitusääni |

### Killan synkronointi
- Jakaa edistymisen kiltaläisten ja ryhmän jäsenten kanssa näkymättömillä addon-viesteillä
- **Guild-välilehti** kolmella osiolla:
  - **LFG-osumat** — kiltaläiset samassa dungeonissa kuin sinä
  - **Tulostaulukko** — killan jäsenet järjestettynä edistymisen mukaan
  - **Suunnittelunäkymä** — kuka tarvitsee mitäkin dungeonia, ryhmitelty koordinointia varten
- 5 minuutin heartbeat, vanhenemistunnistus, automaattinen rosteri-siivous

## Asennus

1. Lataa tai kloonaa tämä repo
2. Kopioi molemmat kansiot WoW:n AddOns-hakemistoon:
   ```
   World of Warcraft/_anniversary_/Interface/AddOns/BoneyardTBC/
   World of Warcraft/_anniversary_/Interface/AddOns/BoneyardTBC_DungeonOptimizer/
   ```
3. Käynnistä WoW uudelleen tai `/reload`

## Käyttö

- **`/btbc`** — avaa/sulje pääikkuna
- **`/btbc do route`** — tulosta nykyinen vaihe chattiin
- **`/btbc do status`** — tulosta maine-yhteenveto chattiin
- **`/btbc do reset`** — nollaa kaikki edistyminen
- **Minikartan painike** — vasen klikkaus avaa ikkunan, oikea klikkaus vaihtaa overlayn näkyvyyttä

## Projektin rakenne

```
BoneyardTBC/                          # Ydin-addon (moduulijärjestelmä, UI-kehys)
  Core.lua                            # Moduulirekisteri, tallennetut muuttujat, slash-komennot
  UI/Widgets.lua                      # Uudelleenkäytettävät UI-komponentit
  UI/MainFrame.lua                    # Pääikkuna, välilehdet, minikartan painike

BoneyardTBC_DungeonOptimizer/         # Dungeon Optimizer -moduuli
  Data.lua                            # Staattinen data (dungeonit, fraktiot, reitit, XP-taulukot)
  DungeonOptimizer.lua                # Moduulin käynnistys, oletusarvot, elinkaari
  Optimizer.lua                       # Reitinlaskentamoottori (balanced + leveling)
  Tracker.lua                         # Tapahtumapohjainen automaattinen eteneminen
  Sync.lua                            # Kilta/ryhmä-viestiprotokolla
  Overlay.lua                         # Kelluva tilastopaneeli + hälytysjärjestelmä
  UI.lua                              # Kaikki välilehti-UI:t (Setup, Route, Tracker, Guild)
```

## Tuetut fraktiot

| Fraktio | Dungeonit | Heroic-avain tasolla |
|---------|-----------|---------------------|
| Honor Hold | Ramparts, Blood Furnace, Shattered Halls | Revered |
| Cenarion Expedition | Slave Pens, Underbog, Steamvault | Revered |
| The Consortium | Mana-Tombs | Honored |
| Keepers of Time | Old Hillsbrad, Black Morass | Revered |
| Lower City | Auchenai Crypts, Sethekk Halls, Shadow Labyrinth | Revered |
| The Sha'tar | Mechanar, Botanica, Arcatraz | Revered |

## Vaatimukset

- WoW TBC Classic Anniversary Edition (Interface 20505)
- Alliance-hahmo (Horde-reittiä ei ole vielä toteutettu)

## Lisenssi

MIT
