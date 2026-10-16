# FLX-Pad

Contrôleur DJ multitouch pour iPad, qui envoie **les mêmes messages MIDI qu'une Pioneer DDJ-FLX4** en Wi-Fi (RTP-MIDI).
La table MIDI vient du mapping officiel de Mixxx (`res/controllers/Pioneer-DDJ-FLX4.midi.xml`), donc le mapping FLX4 de Mixxx marche tel quel, stems compris.

## Installer l'app (SideStore)

**Recommandé : la source**, qui donne les mises à jour directement dans SideStore. Dans SideStore → Sources → **+**, colle :

```
https://github.com/Mathr81/flx-pad/releases/latest/download/source.json
```

Sinon, télécharge `FLXPad.ipa` depuis la dernière [release](https://github.com/Mathr81/flx-pad/releases/latest) et ouvre-le avec SideStore.

Chaque push sur `main` publie une release `v0.1.<n>` avec l'IPA et `source.json`.

Au premier lancement, accepte l'accès au **réseau local** (sinon le MIDI ne passe pas).

## Connecter l'iPad au PC Windows

1. Installe **rtpMIDI** (Tobias Erichsen, gratuit) sur le PC. L'iPad et le PC doivent être sur le même Wi-Fi (5 GHz de préférence).
2. Dans rtpMIDI : « My Sessions » → **+** → coche la session (son nom = le nom du port MIDI vu par les logiciels, ex. `FLX-Pad`).
3. Lance FLX-Pad : l'iPad apparaît dans « Directory » → sélectionne-le → **Connect**. En haut de l'app, le point passe au vert.

## Mixer avec Mixxx (gratuit)

1. Mixxx **2.6** ou plus (stems), sinon 2.4+ pour le reste.
2. Préférences → Contrôleurs → le port rtpMIDI → **Activer** → mapping **Pioneer DDJ-FLX4**.
3. Préférences → Son : choisis ta sortie audio.

## Stems

Sur Mixxx, mode de pads **STEMS** : pads 1-4 = mute des stems, pads 5-8 = effet par stem, SHIFT + pad = solo.
Mixxx ne sépare pas en direct : il lit des fichiers **`.stem.mp4`** que tu prépares à l'avance avec un outil gratuit basé sur Demucs (par ex. `stemgen`).

## rekordbox

Avec le plan **gratuit**, rekordbox n'accepte en mode PERFORMANCE que les appareils Pioneer « Hardware Unlock ». FLX-Pad ne contourne pas ça.
Avec le plan **Core** ou plus : Préférences → Contrôleur → MIDI → choisis le port rtpMIDI → **MIDI LEARN** pour assigner les contrôles.

## Gestes

| Contrôle | Geste |
|---|---|
| Jog, centre | toucher + tourner = scratch (SHIFT = recherche rapide) |
| Jog, bord | tourner = pitch bend |
| Knobs / faders | glisser (relatif) ; **double-tap = centre** (EQ, TEMPO, crossfader…) |
| BROWSE | glisser haut/bas = défiler, tap = PUSH ; SHIFT = zoom waveform |
| Modes de pads | ligne du bas = SHIFT + ligne du haut sur la vraie FLX4 ; chaque pad affiche sa fonction |
| BEAT SYNC | appui long = sync verrouillé (Mixxx) |

## Limites

- Pas de mode PAD FX (non géré par le mapping Mixxx).
- En BEAT JUMP, SHIFT + pads 7/8 change les tailles de saut : les libellés des pads ne suivent pas.
- Pas de pré-écoute casque séparée sans carte son USB à 4 sorties (la FLX4 a la sienne).
- L'app n'envoie rien à la connexion : les positions des faders se synchronisent au premier mouvement.

## Build local (macOS)

```sh
brew install xcodegen && xcodegen generate && open FLXPad.xcodeproj
```
