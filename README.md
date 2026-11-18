<p align="center">
  <img src="docs/images/icon.png" width="148" alt="Mac DFU Studio Icon" />
</p>

<h1 align="center">Mac DFU Studio (MacDFUDiagnostics)</h1>

<p align="center">
  <b>1-Click USB-C VDM DFU Controller, BootROM/USB Inspector, Firmware Revive/Restore & Target Disk Diagnostics for Apple Silicon (M1–M6) and Intel T2 / Pre-T2 Macs</b><br/>
  <sub>Native Swift 6 + SwiftUI + C/IOKit (`AppleHPM` & `IOUSBHostDevice`) • 🇮🇹 Italiano & 🇬🇧 English • 🌗 Adaptive Light/Dark Theme</sub>
</p>

<p align="center">
  <a href="#-italiano-documentazione-completa">🇮🇹 Italiano</a> •
  <a href="#-english-full-documentation">🇬🇧 English</a> •
  <a href="#-matrice-di-compatibilità-reale--real-hardware-compatibility-matrix">💻 Hardware Compatibility</a> •
  <a href="#-mappa-porte-dfu-apple-ht120694--dfu-port-map">🔌 DFU Port Map (HT120694)</a> •
  <a href="https://github.com/iCosiSenpai/MacDFUDiagnostics/releases/latest">📦 Download Notarized DMG</a>
</p>

---

## 🇮🇹 Italiano — Documentazione Completa

**Mac DFU Studio** (`MacDFUDiagnostics`) è un'applicazione nativa macOS scritta in **Swift 6, SwiftUI e C (IOKit)** per Mac **Host Apple Silicon**. Permette di mandare in modalità **DFU con 1 clic** (senza combinazioni manuali di tasti sulla tastiera del target), eseguire **Revive / Restore**, attivare la **console seriale hardware UART sui pin SBU**, ispezionare i descrittori **BootROM/USB** a basso livello ed eseguire **diagnostica SMART / APFS in Target Disk Mode (`T`)** sia sui **Mac Apple Silicon (`M1`–`M6`)** sia sui **Mac Intel (`T2` e `Pre-T2`)**.

### ✨ Funzionalità Principali

1. **⚡ 1-Click DFU Automatico via USB-PD VDM (Apple Silicon + Fallback Intel T2)**
   - Comunica direttamente con il driver IOKit `AppleHPM` (`com.apple.driver.AppleHPM`) del Mac Host Apple Silicon per inviare pacchetti **Structured Vendor-Defined Messages (VDM, SVID `0x05AC`)** sul pin CC del cavo USB-C.
   - **Fix per Mac Intel T2 integrato**: a differenza di `macvdmtool` standard (che invia solo l'azione `0x106 / 0x80010000`, rifiutata con `NAK` da molti Mac Intel T2), `Mac DFU Studio` prova prima il comando Apple Silicon (`0x106`) e, se riceve `NAK`, esegue **automaticamente il fallback al comando VDM specifico per chip T2 (`0x105` con flag `0x80020000` — *PMU Reset + DFU Hold*)**.
   - Supporta inoltre: **Riavvio Remoto (`0x105 / 0x80000000`)**, **Console Seriale Hardware UART su pin SBU1/SBU2 (`0x01840306` + `DVEn` $\rightarrow$ `/dev/cu.debug-console` @ `115200 8N1`)**, **Debug USB (`KIS 05ac:1881`)** e **Probe non distruttivo delle porte `AppleHPM` (`RID`)**.

2. **🩺 Diagnostica USB, BootROM, Cavo & Target Disk Mode (`T`)**
   - Rileva e decodifica in tempo reale **8 stati hardware USB (`idVendor 0x05AC`)**:
     - `0x1227` — **SoC / T2 DFU Mode (SecureROM)**: estrae `CPID`, `BDID`, `ECID`, `SRTG` (versione iBoot in ROM) e identifica automaticamente il modello esatto di Mac o chip `iBridge2,x`.
     - `0xf014` — **Port DFU Mode**: rileva quando il firmware del controller USB-C (Ace/CD3217) del target è corrotto e decodifica `CPID` e `BDID` impacchettati nel campo `BDID` a 64 bit.
     - `0x1881` — **Debug USB (KIS — Kanzi In-System)**.
     - `0x1280 / 0x1281` — **Recovery / iBoot Mode**: legge `SRNM` (Serial Number hardware del Mac) e `SRTG`.
     - `0x1338 / 0x1339` — **Restore Ramdisk Mode**.
     - `0x1902` — **Mac Acceso in macOS (`RemoteXPC / USB NCM Gadget`)**: identifica il modello esatto del Mac target **anche mentre è acceso normalmente in macOS**, decodificando il suffisso numerico in BCD dal campo USB `bcdDevice` (es. `0x1701` $\rightarrow$ `17,1` $\rightarrow$ `MacBookPro17,1`; `0x1606` $\rightarrow$ `16,6` $\rightarrow$ `Mac16,6`).
     - `0x7304` — **USB Billboard Device (Diagnostica Errore Cavo / Thunderbolt Alt-Mode)**: avvisa immediatamente quando il cavo o la porta non riesce a negoziare l'Alternate Mode.
   - **Scanner Target Disk Mode (`T` all'avvio) & Verifica SMART**: per i Mac Intel (sia **con T2** sia **Pre-T2 2015–2019** che non supportano il DFU), rileva l'SSD montato via USB-C/Thunderbolt ed esegue `diskutil verifyDisk` e ispezione **SMART** con 1 clic.

3. **🛠️ Integrazione `cfgutil` per Revive (Salva Dati) e Restore (Formatta)**
   - Gestisce automaticamente la differenza architetturale tra:
     - **Mac Apple Silicon**: verifica lo spazio libero sull'Host (~55 GB per decomprimere l'immagine) e utilizza un file `UniversalMac_..._Restore.ipsw` locale o scaricato dai server Apple.
     - **Mac Intel T2 (`iBridge2,1`–`iBridge2,22`)**: in DFU il target è il coprocessore **Apple T2 (`CPID 0x8012`)**, non la CPU Intel. L'app esegue il Revive/Restore di **`bridgeOS`** (~500 MB scaricati automaticamente da `cfgutil` senza bisogno di un IPSW UniversalMac) e guida l'utente al successivo avvio in **Internet Recovery (`Option-Command-R`)** nel caso di Restore completo.

4. **🎨 Interfaccia Moderna Bilingue (Automatica / 🇮🇹 IT / 🇬🇧 EN), Impostazioni (`⌘,`) & Aggiornamento Obbligatorio Automatico**
   - **Sezione Impostazioni Dedicata (`⌘,`)**: accessibile dalla sidebar, dal pulsante ingranaggio nella toolbar o con la scorciatoia nativa macOS **`Cmd + ,`**.
   - **Selezione Lingua (`Automatica di Sistema`, `🇮🇹 Italiano`, `🇬🇧 English`) e Tema (`Automatico`, `Chiaro`, `Scuro`)**.
   - **🔄 Sistema di Aggiornamento Obbligatorio via GitHub Releases (`UpdateManager`)**: all'avvio (o premendo *"Verifica Aggiornamenti Ora"* nelle Impostazioni) interroga l'API di GitHub Releases. Se è presente una versione più recente, mostra una finestra modale obbligatoria non chiudibile con le note di rilascio e il pulsante **"Aggiorna e Riavvia App"**, che scarica il pacchetto notarizzato da Apple, verifica la firma digitale Developer ID (`codesign --verify --deep --strict`), sostituisce l'app e la riavvia automaticamente.
   - **Rilevamento Automatico della Porta DFU del Mac Host**: legge la scheda logica del Mac Host (`IOPlatformExpertDevice`, es. `J813AP` $\rightarrow$ *MacBook Air 13" M5*) e disegna direttamente in dashboard la **mappa visiva della porta DFU del Mac Host**, accompagnata dai pulsanti rapidi per aprire le pagine ufficiali Apple Support **[HT120694](https://support.apple.com/it-it/120694)** e **[HT108900](https://support.apple.com/it-it/108900)**.
   - **Opzioni Avanzate per Tecnici**: feedback sonoro all'ingresso in DFU, selezione automatica del controller `AppleHPM (RID)` dell'Host, blocco standby del Mac Host, doppia conferma di sicurezza per il Restore, scansione automatica dei file `.ipsw` nella cartella predefinita e apertura con 1 clic della console seriale UART in `Terminal.app` (`screen /dev/cu.debug-console 115200`).

---

## 🇬🇧 English — Full Documentation

**Mac DFU Studio** (`MacDFUDiagnostics`) is a native macOS utility built with **Swift 6, SwiftUI, and C (IOKit)** for **Apple Silicon Host Macs**. It enables **1-Click DFU entry over USB-C** (eliminating physical keyboard gymnastics), **Firmware Revive & Restore**, **SBU UART Hardware Serial Console activation**, **low-level BootROM/USB inspection**, and **Target Disk Mode (`T`) SMART/APFS diagnostics** across **Apple Silicon (`M1`–`M6`)**, **Intel T2 (`2017–2020`)**, and **Pre-T2 Intel (`2015–2019`)** Macs.

### ✨ Key Features

- **⚡ 1-Click Automatic DFU Entry (Apple Silicon `0x106` + Intel T2 `0x105` Fallback)**: Talks directly to `AppleHPM` (`com.apple.driver.AppleHPM`) over IOKit to send USB-PD Structured VDMs (SVID `0x05AC`). Automatically falls back from Apple Silicon DFU (`0x106 / 0x80010000`) to Intel T2 DFU (`0x105 / 0x80020000` *PMU Reset + DFU Hold*) when a T2 target replies with `NAK`.
- **🔄 Remote Reboot, SBU UART Serial Console & Debug USB (KIS)**: Remotely reboot a stuck target Mac out of DFU (`0x105 / 0x80000000`), mux hardware UART onto the USB-C SBU1/SBU2 pins (`/dev/cu.debug-console` @ `115200 8N1`), or switch into Debug USB (`KIS 05ac:1881`).
- **🔍 Live 8-State USB & BootROM Inspector**: Detects `0x1227` (SoC/T2 DFU), `0xf014` (Port DFU with packed 64-bit `BDID` decoding), `0x1881` (KIS), `0x1281` (Recovery/iBoot), `0x1338` (Restore Ramdisk), `0x1902` (Booted macOS RemoteXPC Gadget with BCD `bcdDevice` model decoding), and `0x7304` (USB Billboard cable/Alt-Mode negotiation failure).
- **💾 Target Disk Mode (`T`) & SMART Verification**: Inspects and verifies external disks from Intel T2 and Pre-T2 Intel Macs booted in Target Disk Mode (`T`).
- **🌍 Bilingual UI (IT/EN) & Adaptive Light/Dark Theme**: Instant language and theme switching in the toolbar, plus an interactive visual USB-C port map for 55+ Mac models.

---

## 💻 Matrice di Compatibilità Reale / Real Hardware Compatibility Matrix

Non tutti i Mac con porte USB-C supportano la modalità DFU. La tabella seguente (integrata nel database dell'app in `CompatibilityCatalog.swift`) distingue con precisione assoluta le **3 categorie hardware**:

| Categoria / Architettura | Modelli Inclusi | DFU & VDM 1-Click | Cosa Ripristina il DFU | Target Disk Mode (`T`) / Diagnostica Disco |
| :--- | :--- | :---: | :--- | :--- |
| **1. Apple Silicon (`M1`–`M6`)**<br/>*(2020 – Oggi)* | • **MacBook Air** (M1 2020 $\rightarrow$ M5)<br/>• **MacBook Pro** 13"/14"/16" (M1 $\rightarrow$ M6)<br/>• **MacBook Neo** (`Mac17,5`)<br/>• **iMac 24"** (M1 $\rightarrow$ M6)<br/>• **Mac mini** (M1 $\rightarrow$ M6)<br/>• **Mac Studio** (M1 $\rightarrow$ M5 Max/Ultra)<br/>• **Mac Pro** (2023 M2 Ultra) | ✅ **SÌ**<br/>*(VDM `0x106 / 0x80010000`)* | **Firmware iBoot/SFR + `recoveryOS` + intero `macOS`** tramite file `UniversalMac_..._Restore.ipsw` (~15 GB) | Usa **Condividi Disco (Share Disk)** da macOS Recovery o **Thunderbolt Bridge (`bridge0`)** |
| **2. Intel con Chip Apple T2**<br/>*(2017 – 2020, `CPID 0x8012`, `iBridge2,1`–`2,22`)* | • **iMac Pro (2017)** (`iBridge2,1` / `J137AP`)<br/>• **iMac 27" 5K (2020)** (`iBridge2,19` / `2,20`)<br/>• **MacBook Pro 13"/15"/16" (2018–2020)** (`iBridge2,3`, `2,4`, `2,7`, `2,10`, `2,14`, `2,16`, `2,21`, `2,22`)<br/>• **MacBook Air 13" (2018–2020 Intel)** (`iBridge2,8`, `2,12`, `2,15`)<br/>• **Mac mini (2018)** (`iBridge2,5` / `J174AP`)<br/>• **Mac Pro (2019)** (`iBridge2,6` / `J160AP`) | ✅ **SÌ**<br/>*(VDM Fallback `0x105 / 0x80020000` o tasti 3 sec)* | **Ripristina `bridgeOS` sul chip T2** (~500 MB automatici via `cfgutil`, **non** accetta IPSW UniversalMac). Dopo un Restore, macOS va installato da **Internet Recovery (`Option-Command-R`)** | ✅ **SÌ** — Tenendo premuto **`T`** all'avvio sul Mac Intel, l'SSD viene montato sull'Host Silicon per verifica APFS e SMART |
| **3. Intel Pre-T2 con USB-C / TB3**<br/>*(2015 – 2019, SENZA chip T2)* | • **MacBook 12" Retina (2015–2017)** (`MacBook8,1`, `9,1`, `10,1`)<br/>• **MacBook Pro 13"/15" (2016–2017, con o senza Touch Bar T1)** (`MacBookPro13,x`, `14,x`)<br/>• **iMac 21.5" & 27" (2017 e 2019)** (`iMac18,x`, `19,x`) | ❌ **NO**<br/>*(Nessun chip T2; il chip T1 del 2016–2017 gestisce solo Touch ID/Touch Bar)* | **Non supporta DFU**. Non può essere flashato con Apple Configurator o IPSW | ✅ **SÌ** — Tenendo premuto **`T`** all'avvio, l'app esegue **Verifica File System (`diskutil verifyDisk`) e controllo SMART** via cavo USB-C/TB3 |

---

## 🔌 Mappa Porte DFU (Apple HT120694) / DFU Port Map

Per entrare in modalità DFU (e per inviare comandi VDM), il cavo USB-C **deve essere collegato alla porta DFU specifica**:

| Modello Mac | Posizione Esatta Porta DFU (Apple Support `HT120694`) |
| :--- | :--- |
| **MacBook Pro 14" & 16"** *(M1/M2/M3/M4/M5 Pro & Max, e 14" M3 base)* | Lato sinistro: la porta USB-C **più a SINISTRA** (vicina alla cerniera/schermo, subito accanto a MagSafe 3). |
| ⚠️ **ECCEZIONE: MacBook Pro 14" con chip M4, M5 o M6 BASE** *(non Pro/Max!)* | Lato sinistro: la porta USB-C **più a DESTRA** (più vicina al trackpad/fronte, **NON** quella vicina a MagSafe!). |
| **MacBook Air & MacBook Pro 13"** *(M1, M2, M3 — 2020–2024)* | Lato sinistro: la porta USB-C **più a SINISTRA** (più vicina alla cerniera/schermo). |
| ⚠️ **ECCEZIONE: MacBook Air 2025 o successivi** *(M4, M5)* | Lato sinistro: la porta USB-C **più a DESTRA** (più vicina al trackpad/fronte). |
| **MacBook Pro & MacBook Air INTEL con Chip T2** *(2018–2020)* | Lato sinistro: la porta Thunderbolt 3 (USB-C) **più a DESTRA** (più vicina al trackpad/fronte). |
| **Mac mini Apple Silicon** *(M1, M2, M2 Pro — 2020–2023)* | Retro (visto da dietro): la porta Thunderbolt/USB-C **più a SINISTRA** (vicina al cavo di alimentazione). |
| ⚠️ **ECCEZIONE: Mac mini M4 / M4 Pro / M5 Pro / M6** *(fine 2024 / 2025+)* | Retro (visto da dietro): la porta Thunderbolt/USB-C **CENTRALE** (quella in mezzo delle 3 porte posteriori). |
| **Mac mini INTEL con Chip T2** *(2018)* | Retro (visto da dietro): la porta Thunderbolt 3 (USB-C) **più a DESTRA** (accanto alla porta HDMI). |
| **iMac** *(Tutti i 24" Apple Silicon, iMac 27" 2020 T2 e iMac Pro 2017 T2)* | Retro (visto da dietro): la porta Thunderbolt/USB-C **più a DESTRA**. |
| **Mac Studio** *(Tutti i modelli M1–M5 Max & Ultra)* | Retro (visto da dietro): la porta Thunderbolt/USB-C **più a DESTRA**. |
| **Mac Pro** *(2019 Intel T2 & 2023 M2 Ultra)* | **Tower**: sopra, porta USB-C **più lontana** dal tasto d'accensione.<br/>**Rack**: sul fronte, porta USB-C **più vicina** al tasto d'accensione. |

### 🧵 Regole sui Cavi (USB-C Dati vs SuperSpeed vs Thunderbolt 3)
* **Per DFU (VDM, Revive, Restore)**: Usa un cavo **USB-C dati e ricarica** (es. il cavo Apple USB-C Charge Cable bianco o un cavo USB 3.x Type-C) collegato **direttamente senza hub**. **NON usare un cavo Thunderbolt 3 attivo** (non supportato da Apple per il DFU).
* **Per Console Seriale Hardware UART (`/dev/cu.debug-console`)**: I segnali UART viaggiano sui pin **SBU1/SBU2**, assenti nei cavi USB 2.0 di sola ricarica. È necessario un cavo **USB 3.1/3.2 SuperSpeed o USB4 / Thunderbolt 4** completo di tutti i conduttori.

---

## 🚀 Compilazione e Avvio / Build & Run

### Requisiti / Requirements
- **Mac Host con Apple Silicon** (`M1` o successivo) e **macOS 15.0+**
- **Xcode Command Line Tools** (`xcode-select --install`)
- **Apple Configurator** (gratuito sul Mac App Store, necessario per `cfgutil` durante le operazioni di Revive/Restore)

### Compilazione del Bundle `.app` / Building the `.app` Bundle

```bash
git clone https://github.com/iCosiSenpai/MacDFUDiagnostics.git
cd MacDFUDiagnostics
./build-app.sh
open MacDFUDiagnostics.app
```

Lo script `./build-app.sh`:
1. Genera automaticamente l'icona multi-risoluzione `Resources/AppIcon.icns` tramite CoreGraphics (`Tools/GenerateIcon.swift` + `iconutil`).
2. Compila in modalità `Release` sia l'app SwiftUI `MacDFUDiagnostics` sia l'helper CLI `macdfu-vdm-helper` (con il bridge C IOKit `CHPMBridge`).
3. Assembla e firma ad-hoc il bundle nativo `MacDFUDiagnostics.app`.

### Uso da Terminale dell'Helper VDM / CLI VDM Helper Usage

Puoi anche usare direttamente l'eseguibile CLI `macdfu-vdm-helper` compilato dentro il bundle:

```bash
# Ingresso DFU automatico (prova Apple Silicon 0x106, poi fallback Intel T2 0x105/0x80020000)
sudo ./MacDFUDiagnostics.app/Contents/MacOS/macdfu-vdm-helper dfu --rid 0

# Riavvio remoto del Mac target (uscita da DFU)
sudo ./MacDFUDiagnostics.app/Contents/MacOS/macdfu-vdm-helper reboot --rid 0

# Attiva console seriale UART su SBU (/dev/cu.debug-console @ 115200 8N1)
sudo ./MacDFUDiagnostics.app/Contents/MacOS/macdfu-vdm-helper serial --rid 0

# Test non distruttivo del controller AppleHPM (DBMa Probe)
sudo ./MacDFUDiagnostics.app/Contents/MacOS/macdfu-vdm-helper probe --rid 0 --json
```

---

## 🙏 Crediti & Riferimenti / Credits & References

- **[AsahiLinux/macvdmtool](https://github.com/AsahiLinux/macvdmtool)** & **[osy/ThunderboltPatcher](https://github.com/osy/ThunderboltPatcher)** per le strutture dell'interfaccia IOKit `AppleHPMLib` (Apache-2.0).
- **[fcjr/restorekit](https://github.com/fcjr/restorekit)** per la documentazione del fallback VDM Intel T2 (`0x105 / 0x80020000`), la decodifica BCD `bcdDevice` sui Mac avviati (`05ac:1902`) e il mapping `uart-hpm-rids`.
- **[BartoX360/DFU-Pulse](https://github.com/BartoX360/DFU-Pulse)** & **[SampsiH/target-mac-dfu](https://github.com/SampsiH/target-mac-dfu)** per i pattern di integrazione `cfgutil`.
- **Apple Support**: [HT120694](https://support.apple.com/en-us/120694), [HT108900](https://support.apple.com/en-us/108900), [HT103265](https://support.apple.com/en-us/103265).
