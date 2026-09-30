# 0xst4ck

Reverse-engineered iOS control app for the WCH/Gyroor/Speedmaster generic
Chinese scooter controller (the one the `Gsic scooter` and `Speed Master`
apps talk to — package `cn.ol.blecommon` / `cn.wch.blecommon`).

Built to replace the ugly official app and to add:

- unclamped tuning sliders (Speed_Limit / Strong_Limit go 0–255, not just
  the 20/22/25/28 the stock UI allows)
- **anti-shortcut**: aggressive 500 ms rebride loop that instantly re-caps
  the controller if someone triggers the physical brake+start combo
- **legal mode** one-tap toggle (caps 20 km/h) + PANIC LEGAL / PANIC LOCK
- **overspeed punish**: auto-lock if measured speed > threshold
- graceful-lock frame pushed at disconnect so the scooter comes back up
  bridled by default
- full live TX/RX log in hex + raw frame injector
- dark cyber look, monospaced everywhere

## Protocol summary (reversed from decompiled `cn.ol.blecommon` v6.0)

**GATT**

| role       | UUID                                 |
| ---------- | ------------------------------------ |
| Service    | `00001101-0000-1000-8000-00805F9B34FB` |
| Write/Read | `0000FFE1-0000-1000-8000-00805F9B34FB` |
| Notify     | `0000FFE4-0000-1000-8000-00805F9B34FB` |

**Frame (fixed 20 bytes)**

```
[0]  0xAA header
[1]  opcode  (CC=config, DD=set pass, EE=auth, FF=ble name, BB=cfg resp)
[2]  arg
[3]  flags   bit0 MPH | bit1 NonZero | bit2 Cruise | bit3 SpeedLimit
[4]  battery_num
[5]  pole_num
[6]  pole_num2
[7]  pole_op_status
[8]  speed_limit (km/h)
[9]  odo_clear
[14] wheel_size (1/10 inch)
[15] strong_limit
[16] config_ok
[17] lock_flag  (1=lock, 2=unlock)
[18] checksum = sum(bytes 0..17) mod 256
[19] 0x55 footer
```

**Auth**: opcode `0xEE`, sends master (4-digit) + slave (6-digit derived) +
guest (6-digit). Slave derivation lives in `BLE/Auth.swift`.

## Build

The GitHub Action at `.github/workflows/build.yml` builds an **unsigned**
`.ipa` on every push to `main`. Download it from the run artifacts and
install with **AltStore**, **Sideloadly** or **TrollStore**.

Locally on a Mac:

```bash
brew install xcodegen
xcodegen generate
open 0xst4ck.xcodeproj
```

## Structure

```
0xst4ck/
├── App.swift
├── Assets.xcassets/
├── BLE/
│   ├── Auth.swift          # slave password derivation
│   ├── BLEManager.swift    # CoreBluetooth central + keepalive loop
│   └── Protocol.swift      # frame builder / parser
├── Models/
│   ├── LogEntry.swift
│   └── ScooterState.swift
├── Theme/
│   └── Theme.swift
└── Views/
    ├── ContentView.swift
    ├── ScanView.swift
    ├── DashboardView.swift
    ├── TuningView.swift
    ├── SecurityView.swift
    └── LogsView.swift
```

## Legal

Riding a derestricted scooter on Swiss public roads is not legal above
20 km/h (art. 18 OETV — see chat notes). Use LEGAL MODE on the road.
Full tuning is your problem, not this repo's.
