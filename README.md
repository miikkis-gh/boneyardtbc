# Boneyard TBC Special

WoW-addon TBC Classic Anniversary Editionille, joka laskee optimaalisen dungeon-reitin tasolta 58 tasolle 70. Tavoitteena maksimoida XP ja reputaatio niin, että heroic-avaimet ja Karazhan-attunement hoituvat samalla.

## Mitä tämä tekee

### Reitin laskenta

- **Balanced-moodi** — seuraa Myronin reittiä ja säätää runien määrää lennosta tason ja repin mukaan
- **Leveling-moodi** — puhdas XP/h-grinderi, valitsee aina parhaan dungeonin tasolle välittämättä repistä
- Tunnistaa automaattisesti faktion, racen, levelin ja repin — ei tarvitse konfiguroida mitään
- Humanin 10% rep-bonus huomioidaan automaattisesti
- Valinnaiset questketjut: Karazhan attunement, Arcatraz-avain, Shattered Halls -avain

### Trackeri

- **Automaattinen eteneminen** — tunnistaa dungeon-clearin, quest-turninit, zone-vaihdot, dingit ja rep-gainin
- XP-palkki current/max-edistymisellä
- Rep-palkit fraktiottain värikoodatuilla rep-tasoilla ja edistymisellä kohti goaleja
- Dungeon-counter: "Run X / Y" nykyiselle phaselle
- Attunement-checklist — heroic-keyt ja Kara-milestonet

### Overlay

Kompakti raahattava paneeli:

- **Instance lock** — X/5 timerilla, värikoodattu warning kun lähestyy lockoutia
- **Session runs** — montako dungeonia tällä sessiolla
- **XP/h ja Rep/h** — laskettu session-datasta
- **Avg run time** — keskimääräinen clearin kesto

Toggletaan minimap-buttonin right-clickillä tai asetuksista.

### Hälytykset

Chat-messaget + äänet tärkeillä eventeillä:

| Eventti | Ääni |
|---------|------|
| Dungeon-run valmis | Notification |
| Reitin phase etenee | Quest complete -fanfaari |
| Rep-milestone (uusi taso) | Reputation up |
| Instance lock warning (4/5) | Raid warning |
| Instance lock täynnä (5/5) | Raid warning |
| Guildie samassa dungeonissa | Notification |

### Guild sync

Jakaa progressin guildien ja party-membereiden kanssa invisible addon-messageilla.

Guild-tab kolmella osiolla:

- **LFG-matchit** — guildiet samassa dungeonissa kuin sinä
- **Leaderboard** — guildin jäsenet rankattuna progressin mukaan
- **Planning** — kuka tarvitsee mitäkin dungeonia, ryhmitelty koordinointia varten

5 min heartbeat, stale-detection, automaattinen roster-cleanup.

## Asennus

1. Lataa tai kloonaa tämä repo
2. Kopioi molemmat kansiot WoW:n AddOns-hakemistoon:
   ```
   World of Warcraft/_anniversary_/Interface/AddOns/BoneyardTBC/
   World of Warcraft/_anniversary_/Interface/AddOns/BoneyardTBC_DungeonOptimizer/
   ```
3. `/reload` tai restarttaa WoW

## Käyttö

| Komento | Toiminto |
|---------|----------|
| `/btbc` | Avaa/sulje pääikkuna |
| `/btbc do route` | Printtaa nykyinen phase chattiin |
| `/btbc do status` | Printtaa rep-yhteenveto chattiin |
| `/btbc do reset` | Resettaa kaiken progressin |

Minimap-button: left-click avaa ikkunan, right-click togglee overlayn.

## Rakenne

```
BoneyardTBC/                          # Core-addon (moduulijärjestelmä, UI-framework)
  Core.lua                            # Moduulirekisteri, saved variables, slash-komennot
  UI/Widgets.lua                      # Uudelleenkäytettävät UI-komponentit
  UI/MainFrame.lua                    # Pääikkuna, tabit, minimap-button

BoneyardTBC_DungeonOptimizer/         # Dungeon Optimizer -moduuli
  Data.lua                            # Staattinen data (dungeonit, fraktiot, reitit, XP-taulut)
  DungeonOptimizer.lua                # Moduulin init, defaultit, lifecycle
  Optimizer.lua                       # Reitinlaskenta (balanced + leveling)
  Tracker.lua                         # Event-pohjainen automaattinen eteneminen
  Sync.lua                            # Guild/party-viestiprotokolla
  Overlay.lua                         # Kelluva statspaneeli + hälytysjärjestelmä
  UI.lua                              # Tab-UI:t (Setup, Route, Tracker, Guild)
```

## Tuetut fraktiot

| Fraktio | Dungeonit | Heroic-key repillä |
|---------|-----------|-------------------|
| Honor Hold | Ramparts, Blood Furnace, Shattered Halls | Revered |
| Cenarion Expedition | Slave Pens, Underbog, Steamvault | Revered |
| The Consortium | Mana-Tombs | Honored |
| Keepers of Time | Old Hillsbrad, Black Morass | Revered |
| Lower City | Auchenai Crypts, Sethekk Halls, Shadow Labyrinth | Revered |
| The Sha'tar | Mechanar, Botanica, Arcatraz | Revered |

## Vaatimukset

- WoW TBC Classic Anniversary Edition (Interface 20505)
- Alliance-hahmot (Horde-reittiä ei ole, eikä tule)

## Lisenssi

MIT
