-- HelloRadio V15 Max：左摇杆油门灯。
-- 参考思路：https://github.com/btastic/rgb-throttle-edgetx
-- 先在 Tools 运行 ledid，根据真机左圈的颜色保存编号。
local MAP_FILE = "/SCRIPTS/RGBLED/thrled.cfg"
local LED_COUNT = 16
local BRIGHTNESS = 50 -- 与原厂 green.lua 相同，范围 1..255。

local firstLed
local throttleSource

local function init()
  local _, radio = getVersion()
  assert(radio == "v15", "thrled: V15 firmware required")
  assert(type(setRGBLedColor) == "function"
      and type(applyRGBLedColors) == "function",
      "thrled: RGB LED API unavailable")
  assert(LED_STRIP_LENGTH == 38, "thrled: LED layout differs; run ledid")
  assert(BRIGHTNESS >= 1 and BRIGHTNESS <= 255, "thrled: invalid brightness")

  local file = assert(io.open(MAP_FILE, "r"), "thrled: run ledid in Tools first")
  local mapping = io.read(file, 8)
  io.close(file)
  assert(mapping == "0\n" or mapping == "16\n", "thrled: invalid map; run ledid again")
  firstLed = tonumber(mapping)

  local source = getFieldInfo("thr")
  assert(source, "thrled: throttle source unavailable")
  throttleSource = source.id
end

local function run()
  -- 读取摇杆油门，避免受 CH3 通道顺序、混控或输出限幅影响。
  local throttle = getValue(throttleSource)
  local percent = math.floor((throttle + 1024) * 100 / 2048 + 0.5)
  percent = math.max(0, math.min(100, percent))

  -- 按整数百分比判色：1..30 绿，31..60 黄，61..100 红。
  local red = percent > 30 and 1 or 0
  local green = percent <= 60 and 1 or 0
  local filled = percent * LED_COUNT / 100

  for position = 0, LED_COUNT - 1 do
    -- 最前端的一颗渐亮；低油门为全灭，满油门为整圈全亮。
    local level = math.max(0, math.min(1, filled - position))
    local value = math.floor(BRIGHTNESS * level + 0.5)
    setRGBLedColor(firstLed + position, value * red, value * green, 0)
  end
  applyRGBLedColors()
end

return { init = init, run = run }
