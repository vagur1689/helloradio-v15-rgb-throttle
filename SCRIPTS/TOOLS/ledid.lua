-- V15 LED Setup
-- 先停用已有的 RGB 全局/特殊功能，再按真机左圈颜色保存映射。
local MAP_FILE = "/SCRIPTS/RGBLED/thrled.cfg"
local firstLed = 0
local saved = false

local function clear()
  for id = 0, 31 do
    setRGBLedColor(id, 0, 0, 0)
  end
end

local function init()
  local _, radio = getVersion()
  assert(radio == "v15", "ledid: V15 firmware required")
  assert(type(setRGBLedColor) == "function"
      and type(applyRGBLedColors) == "function",
      "ledid: RGB LED API unavailable")
  assert(LED_STRIP_LENGTH == 38, "ledid: expected 38 LEDs; report firmware version")
  firstLed = 0
  saved = false
  -- 由人观察左右颜色，不根据 TX15 示例猜测左右灯圈的接线顺序。
  for id = 0, 31 do
    if id < 16 then
      setRGBLedColor(id, 0, 0, 50)
    else
      setRGBLedColor(id, 0, 50, 0)
    end
  end
  applyRGBLedColors()
end

local function save()
  local contents = tostring(firstLed) .. "\n"
  local file = assert(io.open(MAP_FILE, "w"), "ledid: cannot write thrled.cfg")
  io.write(file, contents)
  io.close(file)

  -- EdgeTX 使用 io.write(file, text)；重新读取确认落盘，避免显示伪成功。
  file = assert(io.open(MAP_FILE, "r"), "ledid: cannot verify thrled.cfg")
  local written = io.read(file, 8)
  io.close(file)
  assert(written == contents, "ledid: calibration save failed")
  saved = true

  clear()
  for id = firstLed, firstLed + 15 do
    setRGBLedColor(id, 0, 50, 0)
  end
  applyRGBLedColors()
end

local function run(event)
  if event == EVT_VIRTUAL_EXIT then
    clear()
    applyRGBLedColors()
    return 2
  elseif not saved then
    if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_PREV then
      firstLed = 16 - firstLed
    elseif event == EVT_VIRTUAL_ENTER then
      save()
    end
  end

  lcd.clear()
  lcd.drawText(20, 12, "V15 throttle LED setup", MIDSIZE)
  if saved then
    lcd.drawText(20, 68, "Saved. Only the LEFT ring should be green.", 0)
    lcd.drawText(20, 104, "Left LED IDs: " .. firstLed .. ".." .. (firstLed + 15), 0)
    lcd.drawText(20, 144, "Enable thrled in Global Functions > RGB leds.", 0)
    lcd.drawText(20, 204, "EXIT: lights off and close", 0)
  else
    lcd.drawText(20, 62, "Which color is on the LEFT stick?", 0)
    lcd.drawText(36, 102, "BLUE", firstLed == 0 and INVERS or 0)
    lcd.drawText(36, 138, "GREEN", firstLed == 16 and INVERS or 0)
    lcd.drawText(20, 182, "Scroll: choose. ENTER: save. EXIT: cancel.", 0)
    lcd.drawText(20, 216, "Mixed colors on one ring? EXIT without saving.", 0)
  end
  return 0
end

return { init = init, run = run }
