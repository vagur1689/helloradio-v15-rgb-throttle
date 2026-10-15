# V15 Max Throttle RGB LEDs

[Download both scripts](https://github.com/vagur1689/helloradio-v15-rgb-throttle/archive/refs/heads/main.zip) · [中文说明](README.zh-CN.md)

Two throttle-driven LED effects for the **HelloRadio V15 Max left gimbal ring (16 LEDs)**. No firmware flashing required. Run `ledid` once to calibrate the left ring, then pick one effect. Automated tests use a simulated EdgeTX API; the actual ring mapping and direction must be confirmed on the radio.

## The two effects

| Script | Behavior | Throttle bands | Full throttle |
| --- | --- | --- | --- |
| [thrled2.lua](SCRIPTS/RGBLED/thrled2.lua) | Whole ring changes color; already-lit LEDs switch together | 1–30% green, 31–60% yellow, 61–100% red | 16 red LEDs |
| [thrled.lua](SCRIPTS/RGBLED/thrled.lua) | Fixed color zones; earlier LEDs keep their color | 1–35% green, 36–75% yellow, 76–100% red | 6 green + 6 yellow + 4 red |

Both start dark at 0%, light up LED by LED as throttle rises, and fade the leading LED in gradually. Lowering throttle turns them off in reverse. Both scripts can live on the TF card at the same time, but **only one may be enabled at a time**. They share `thrled.cfg`, so switching effects does not require recalibration.

The fixed-zone version `thrled` splits the throttle travel as **35% green, 40% yellow, 25% red**:

| Throttle | Effect (numbered in lighting order) |
| --- | --- |
| 0% | Off |
| 1–35% | LEDs 1–6 fade in one by one, green |
| 36–75% | 6 green stay lit; LEDs 7–12 fade in one by one, yellow |
| 76–100% | 6 green + 6 yellow stay lit; LEDs 13–16 fade in one by one, red |

16 LEDs cannot be split into exact 35% / 40% / 25% whole-LED groups, so the closest split of 6 / 6 / 4 is used, and fill progress is computed within each color zone: 35% lights exactly 6 green, 75% exactly 6 green + 6 yellow, and 100% adds the 4 red. Each LED has a fixed color; what changes with throttle is how many are lit and how bright the leading one is.

Percentages are derived from the stick's `-1024..1024` reading, rounded to a whole number before progress is computed. This reflects stick travel, not the flight controller's actual motor output; the effect only reads `thr` and does not depend on how channel 3 is configured.

## Installation

1. Keep the aircraft powered off, and disable any existing RGB global function and RGB special function on the radio. You can turn off RF transmission while only adjusting LEDs.
2. Unzip the downloaded repository and copy these three Lua files to the matching locations on the radio's TF card, keeping the existing files in those directories:
   - `/SCRIPTS/RGBLED/thrled2.lua` — whole-ring color change.
   - `/SCRIPTS/RGBLED/thrled.lua` — fixed color zones.
   - `/SCRIPTS/TOOLS/ledid.lua` — left-ring calibration tool.
3. Run `ledid` from the radio's Tools list. The two LED groups are shown in blue and green respectively; use the menu wheel to select **the color you actually see on the left gimbal**: `BLUE` or `GREEN`, then press the wheel to confirm. If a single ring shows mixed colors, press EXIT to leave and report it — do not force a selection.
4. After `Saved` appears, only the left ring should be lit green. Press EXIT to leave. The tool writes your choice to `/SCRIPTS/RGBLED/thrled.cfg` automatically; no manual Lua editing is needed.
5. In **Global Functions**, add an entry: trigger `ON`, function `RGB leds`, file `thrled2` (whole ring) or `thrled` (fixed zones), enabled. If duplicate options appear, set it to `On` so it runs continuously. Keep any other RGB function that writes the same LEDs disabled.

`thrled.cfg` is a dedicated data file produced by the calibration tool and is not shipped in this repository, so a guessed left/right mapping will never overwrite an existing calibration. The tool reads the value back to confirm after saving; pressing EXIT instead keeps the previous calibration. To re-select the left ring, disable the current throttle effect first, then run `ledid` again.

If you are already calibrated, just update the corresponding Lua file, keep `thrled.cfg`, and reboot the radio. To switch effects, only change the filename in the existing RGB function entry — no recalibration or flashing needed.

## Verification and recovery

Keep the aircraft powered off and test the effect you selected:

- `thrled2`: lowest throttle is fully off; at 30% all lit LEDs are green; at 31% they all turn yellow together; at 60% still yellow; at 61% they all turn red together; at full throttle all 16 LEDs are red.
- `thrled`: at 35% exactly 6 green are lit; at 36% the first yellow appears; at 75% exactly 6 green + 6 yellow are lit; at 76% the first red appears; at full throttle it is 6 green + 6 yellow + 4 red. Lowering throttle removes red first, then yellow, then green, with the remaining LEDs keeping their color.

This effect only writes the calibrated left ring's 16 LEDs; the right ring is turned off when you exit the calibration tool. It does not write the function-key LEDs and does not modify channels, mixes, models, or RF module configuration. To restore your previous lighting, re-select the original script in the original RGB function entry and enable it; merely disabling a script may leave the last frame lit.

If you see `V15 firmware required` or `expected 38 LEDs` / `LED layout differs`, check the current firmware version first. If `run ledid in Tools first` appears, complete calibration first. If `cannot write` or `save failed` appears, check that the TF card is writable. Do not remove these checks to force the script to run.

## Evidence behind this implementation

- The vendor manual, SD card contents, and firmware used during development are not distributed with this repository. Page 8 of `V15说明书.pdf` confirms EdgeTX is preinstalled, and page 9 shows the menu wheel and SYS key locations; **the official quick-start manual does not document RGB throttle effects, LED numbering, or this Lua setup flow.**
- The README and scripts in the stock `V15-SD卡工厂文件-CN-20260929/SCRIPTS/RGBLED/` folder demonstrate the use of `/SCRIPTS/RGBLED/`, `setRGBLedColor`, and `applyRGBLedColors`. That folder's `Red2.lua` assumes 10 LEDs per ring, and `gimbal.lua` explicitly states `hardcoded for tx15`, so this implementation calibrates left/right by actual observed color instead of copying those wiring assumptions.
- The EdgeTX [V15 hardware definition](https://github.com/EdgeTX/edgetx/blob/65db64b4890c399b8fcc9cc6a3d002c2b86e4706/radio/src/boards/hw_defs/v15.json) gives a decorative strip length of 32 and a function-key strip length of 6; the [Lua API](https://github.com/EdgeTX/edgetx/blob/65db64b4890c399b8fcc9cc6a3d002c2b86e4706/radio/src/lua/api_general.cpp) maps these to Lua indices `0..31` and `32..37`. The physical strip offset is handled by the firmware, so the scripts add no extra 6. Which 16-LED group is the left ring is confirmed by the user during calibration.
- In the local `V15-2.12-20261009EN-NoAi-firmware.uf2`, the Lua constant table contains `LED_STRIP_LENGTH = 38`, and `LCD_W = 480` / `LCD_H = 272` were verified as well. This is static evidence from the bundled firmware and does not mean the user's currently installed firmware was read.
- The [RGB special function source](https://github.com/EdgeTX/edgetx/blob/65db64b4890c399b8fcc9cc6a3d002c2b86e4706/radio/src/gui/colorlcd/model/special_functions.cpp) and the [Lua loader](https://github.com/EdgeTX/edgetx/blob/65db64b4890c399b8fcc9cc6a3d002c2b86e4706/radio/src/lua/interface.cpp) confirm that the RGB function loads scripts from `/SCRIPTS/RGBLED/` and calls `run` continuously. The Chinese label is "RGB LED 灯". The sources above explain system mechanics and are not line-by-line source for the bundled vendor firmware.
- File saving uses the same EdgeTX `io.open`, `io.write`, and `io.close` call forms already used by `SCRIPTS/RF2/PAGES/helpers/settingsHelper.lua` on the stock SD card; reading uses `io.read(file, size)`, also already present in scripts on that card.
- Item 44 of the stock `遥控常见问题汇总-中英双语.html` states explicitly that controlling lights from both Global Functions and Special Functions at the same time causes conflicts.
- The per-LED fill approach is inspired by [btastic/rgb-throttle-edgetx](https://github.com/btastic/rgb-throttle-edgetx/tree/f902afa35802c99fab949d51e40822a22f5254c3). Its default `0..5` numbering and `getOutputValue(2)` target that project's example layout and channel 3; this implementation does not carry over those assumptions.

## Local verification

Run these in this directory:

~~~sh
luac -p SCRIPTS/RGBLED/thrled.lua
luac -p SCRIPTS/RGBLED/thrled2.lua
luac -p SCRIPTS/TOOLS/ledid.lua
lua tests/run.lua
~~~

The tests simulate the EdgeTX API and the TF card, covering both color-band boundaries, LED state when throttle rises and falls, monotonicity across all 2049 stick values for both effects and both left/right mappings, out-of-range input, a missing config, calibration save and cancel, write failure, and updating only the selected ring. **These checks cannot replace confirming color selection, rotation direction, actual effect, and menus on a real radio.**
