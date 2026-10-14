# V15 Max 油门 RGB 灯

[下载两版脚本](https://github.com/vagur1689/helloradio-v15-rgb-throttle/archive/refs/heads/main.zip)

用于 **HelloRadio V15 Max 左圈 16 颗灯珠**，提供两种随油门逐颗点亮的效果。无需刷机；先用 `ledid` 校准左圈，再选择一种灯效。自动化测试使用模拟 EdgeTX API，实际灯圈映射和方向需在遥控器上确认。

## 两种灯效

| 脚本 | 效果 | 油门区间 | 满油门 |
| --- | --- | --- | --- |
| [thrled2.lua](SCRIPTS/RGBLED/thrled2.lua) | 整圈变色，已亮灯珠一起换色 | 1–30% 绿，31–60% 黄，61–100% 红 | 16 颗红灯 |
| [thrled.lua](SCRIPTS/RGBLED/thrled.lua) | 固定色区，保留前面已亮灯珠的颜色 | 1–35% 绿区，36–75% 黄区，76–100% 红区 | 6 绿＋6 黄＋4 红 |

两版都是 0% 熄灭、随油门逐颗点亮，最前端的一颗渐亮；收油门时逐步熄灭。两版可以同时放在 TF 卡上，**同一时间只启用一种**，共用 `thrled.cfg`，切换效果不必重新校准。

固定色区版 `thrled` 的油门行程分配为 **35% 绿、40% 黄、25% 红**：

| 油门 | 灯效（按点亮顺序编号） |
| --- | --- |
| 0% | 熄灭 |
| 1–35% | 第 1–6 颗绿灯逐颗渐亮 |
| 36–75% | 保留 6 颗绿灯，第 7–12 颗黄灯逐颗渐亮 |
| 76–100% | 保留 6 颗绿灯和 6 颗黄灯，第 13–16 颗红灯逐颗渐亮 |

16 颗灯无法精确按 35%／40%／25% 分成整数颗，采用最接近的 6／6／4 颗，并在每个色区内分别计算填充进度：35% 恰好亮满 6 绿，75% 恰好亮满 6 绿＋6 黄，100% 再加满 4 红。每颗灯的颜色固定，随油门变化的是点亮数量和前端亮度。

百分比由摇杆的 `-1024..1024` 读数换算，四舍五入为整数后计算进度。显示的是摇杆行程，不是飞控实际电机输出；灯效只读取 `thr`，不依赖第 3 通道的输出配置。

## 安装

1. 保持飞机断电，在遥控器上停用已有的 RGB 全局功能和 RGB 特殊功能。只调灯时可关闭高频发射。
2. 解压下载的仓库 ZIP，把以下三个 Lua 文件放到遥控器 TF 卡对应位置，保留目录内原有文件：
   - `/SCRIPTS/RGBLED/thrled2.lua`：整圈变色灯效。
   - `/SCRIPTS/RGBLED/thrled.lua`：固定色区灯效。
   - `/SCRIPTS/TOOLS/ledid.lua`：左圈校准工具。
3. 在遥控器的工具列表（Tools）运行 `ledid`。两组灯会分别显示蓝色和绿色，用菜单滚轮选中**左摇杆实际显示的颜色**：`BLUE`（蓝）或 `GREEN`（绿），按下滚轮确认。若同一个灯圈出现混色，先按 EXIT 退出并反馈，不能强行选。
4. 出现 `Saved` 后，应当只有左圈亮绿色。按 EXIT 退出。工具自动将选择写入 `/SCRIPTS/RGBLED/thrled.cfg`；不用手工编辑 Lua。
5. 在“全局功能 / Global Functions”新增一项：开关 `ON`，功能 `RGB LED 灯 / RGB leds`，文件选择 `thrled2`（整圈变色）或 `thrled`（固定色区），启用。如果有重复选项，设为 `On` 持续运行。保持其他会写相同灯珠的 RGB 功能停用。

`thrled.cfg` 是校准工具生成的专用数据文件，仓库不预置它，因此不会用猜测的左右映射覆盖已有校准。工具明确保存后会回读确认；按 EXIT 取消则保留之前的校准。重新选择左右灯圈时，先停用当前油门灯效，再运行 `ledid`。

已经完成校准时，更新对应 Lua 文件并保留 `thrled.cfg`，重启遥控器即可。更换效果时，只需在原来的 RGB 功能项中切换文件名；无需重新校准或刷机。

## 验证与恢复

保持飞机断电，按所选灯效测试：

- `thrled2`：最低油门全灭；30% 已亮灯珠均为绿色；31% 一起变黄；60% 仍为黄色；61% 一起变红；满油门 16 颗红灯全亮。
- `thrled`：35% 亮满 6 绿；36% 开始增加第一颗黄灯；75% 亮满 6 绿＋6 黄；76% 开始增加第一颗红灯；满油门为 6 绿＋6 黄＋4 红。收油门时先减红灯，再减黄灯，最后减绿灯，剩余灯珠保持原色。

本灯效只写已校准的左圈 16 颗灯；右圈在退出校准工具时会熄灭。它不写功能按键灯，不修改通道、混控、模型或高频模块配置。恢复原来灯效时，在原来的 RGB 功能项重新选择原脚本并启用；仅停用脚本可能保留最后一帧。

如果出现 `V15 firmware required` 或 `expected 38 LEDs` / `LED layout differs`，先核对当前固件版本。出现 `run ledid in Tools first` 时先完成校准；出现 `cannot write` 或 `save failed` 时检查 TF 卡是否可写。不要删除这些检查条件来强行运行。

## 核实依据

- 开发时核对的厂商说明书、SD 卡和固件未随本仓库分发。`V15说明书.pdf` 第 8 页确认预装 EdgeTX，第 9 页标明菜单滚轮、SYS 等硬件位置；**官方快速说明书未记载 RGB 油门灯效、灯珠编号或这一 Lua 设置流程**。
- 原厂 `V15-SD卡工厂文件-CN-20260929/SCRIPTS/RGBLED/` 的说明与脚本证明 `/SCRIPTS/RGBLED/`、`setRGBLedColor`、`applyRGBLedColors` 的用法。该目录的 `Red2.lua` 按每圈 10 灯计算，`gimbal.lua` 明确写了 `hardcoded for tx15`，因此本实现通过实机颜色校准左右，不照搬此示例的接线假设。
- EdgeTX [V15 硬件定义](https://github.com/EdgeTX/edgetx/blob/65db64b4890c399b8fcc9cc6a3d002c2b86e4706/radio/src/boards/hw_defs/v15.json) 的装饰灯长度为 32、功能按键灯长度为 6；[Lua API](https://github.com/EdgeTX/edgetx/blob/65db64b4890c399b8fcc9cc6a3d002c2b86e4706/radio/src/lua/api_general.cpp) 将它们映射为 Lua 编号 `0..31` 和 `32..37`。物理灯带偏移由固件处理，脚本不再加 6。左圈是哪个 16 灯分组，由用户在校准时确认。
- 本地 `V15-2.12-20261009EN-NoAi-firmware.uf2` 的 Lua 常量表中，`LED_STRIP_LENGTH = 38`，同时核对了 `LCD_W = 480`、`LCD_H = 272`。这是随附固件的静态证据，不代表已读取用户遥控器当前固件。
- [RGB 特殊功能源码](https://github.com/EdgeTX/edgetx/blob/65db64b4890c399b8fcc9cc6a3d002c2b86e4706/radio/src/gui/colorlcd/model/special_functions.cpp) 和 [Lua 加载器](https://github.com/EdgeTX/edgetx/blob/65db64b4890c399b8fcc9cc6a3d002c2b86e4706/radio/src/lua/interface.cpp) 确认 RGB 功能从 `/SCRIPTS/RGBLED/` 加载脚本并持续调用 `run`。中文标签为“RGB LED 灯”。上述源码用于解释系统机制，不等于随附厂商固件的逐行源码。
- 文件保存使用原厂 SD 卡 `SCRIPTS/RF2/PAGES/helpers/settingsHelper.lua` 已使用的 EdgeTX `io.open`、`io.write`、`io.close` 调用形式，读取采用同一 SD 卡脚本中已有的 `io.read(file, size)`。
- 原厂 `遥控常见问题汇总-中英双语.html` 第 44 条明确说明全局功能和特殊功能同时控制灯光会互相冲突。
- 参考 [btastic/rgb-throttle-edgetx](https://github.com/btastic/rgb-throttle-edgetx/tree/f902afa35802c99fab949d51e40822a22f5254c3) 的逐颗填充思路。其默认 `0..5` 编号和 `getOutputValue(2)` 针对示例布局与第 3 通道，本实现未沿用这些假设。

## 本地验证

在本目录执行：

~~~sh
luac -p SCRIPTS/RGBLED/thrled.lua
luac -p SCRIPTS/RGBLED/thrled2.lua
luac -p SCRIPTS/TOOLS/ledid.lua
lua tests/run.lua
~~~

测试模拟 EdgeTX API 和 TF 卡，检查两版配色边界、增减油门时的灯珠状态、两种效果和左右映射各自全部 2049 个摇杆值的单调性、越界输入、配置缺失、校准保存与取消、写入失败，以及只更新选中的灯圈。**这些检查不能替代真机的颜色选择、旋转方向、实际灯效与菜单验证。**
