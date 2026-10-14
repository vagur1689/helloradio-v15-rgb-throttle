-- 在本目录的上一级执行：lua tests/run.lua
local function read(path)
  local file = assert(io.open(path, "r"))
  local source = file:read("*a")
  file:close()
  return source
end

local source = read("SCRIPTS/RGBLED/thrled.lua")
local uniformSource = read("SCRIPTS/RGBLED/thrled2.lua")
local toolSource = read("SCRIPTS/TOOLS/ledid.lua")
local mapPath = "/SCRIPTS/RGBLED/thrled.cfg"
local tests = 0

local function test(name, run)
  run()
  tests = tests + 1
  print("PASS " .. name)
end

local function environment(mapping)
  local state = {
    throttle = -1024, writes = {}, frames = 0, fileWrites = 0,
    mapping = mapping, handles = 0,
  }
  local env = setmetatable({
    LED_STRIP_LENGTH = 38,
    EVT_VIRTUAL_EXIT = 1,
    EVT_VIRTUAL_NEXT = 2,
    EVT_VIRTUAL_PREV = 3,
    EVT_VIRTUAL_ENTER = 4,
    MIDSIZE = 0,
    INVERS = 1,
    getVersion = function() return "test", "v15" end,
    getFieldInfo = function(name)
      assert(name == "thr")
      return { id = 73 }
    end,
    getValue = function(id)
      assert(id == 73, "must use the resolved throttle source")
      return state.throttle
    end,
    getOutputValue = function() error("must not read a model output channel") end,
    setRGBLedColor = function(id, r, g, b)
      assert(id >= 0 and id < 32, "must not write function-button LEDs")
      for _, value in ipairs({r, g, b}) do
        assert(value % 1 == 0 and value >= 0 and value <= 255)
      end
      state.writes[id] = { r, g, b }
      return true
    end,
    applyRGBLedColors = function() state.frames = state.frames + 1 end,
    lcd = {
      clear = function() end,
      drawText = function(x, y) assert(x < 480 and y < 272) end,
    },
    io = {
      open = function(path, mode)
        assert(path == mapPath)
        if mode == "r" and state.mapping == nil then return nil end
        if mode == "w" then
          if state.readOnly then return nil end
          state.mapping = ""
        end
        state.handles = state.handles + 1
        return { mode = mode }
      end,
      read = function(file, count)
        assert(file.mode == "r" and not file.closed)
        return state.mapping:sub(1, count)
      end,
      write = function(file, contents)
        assert(file.mode == "w" and not file.closed)
        state.fileWrites = state.fileWrites + 1
        if not state.dropWrite then state.mapping = contents end
      end,
      close = function(file)
        assert(not file.closed)
        file.closed = true
        state.handles = state.handles - 1
      end,
    },
  }, { __index = _G })
  return env, state
end

local function loadScript(text, env)
  return assert(load(text, "@test-script", "t", env))()
end

local function expectInitError(mapping, change, expected)
  local env, state = environment(mapping)
  if change then change(env) end
  local script = loadScript(source, env)
  local ok, message = pcall(script.init)
  assert(not ok and tostring(message):find(expected, 1, true), tostring(message))
  assert(next(state.writes) == nil and state.frames == 0 and state.handles == 0)
end

test("missing or invalid calibration fails before any LED write", function()
  expectInitError(nil, nil, "run ledid in Tools first")
  for _, mapping in ipairs({"", "32\n", "-1\n", "1.5\n", "0junk", "return 16"}) do
    expectInitError(mapping, nil, "invalid map")
  end
end)

test("wrong radio, missing RGB API and changed layout fail visibly", function()
  expectInitError("0\n", function(e)
    e.getVersion = function() return "test", "tx15" end
  end, "V15 firmware required")
  expectInitError("0\n", function(e) e.setRGBLedColor = false end, "RGB LED API unavailable")
  expectInitError("0\n", function(e) e.LED_STRIP_LENGTH = 20 end, "LED layout differs")
end)

test("missing throttle source does not become a false 50 percent reading", function()
  expectInitError("0\n", function(e)
    e.getFieldInfo = function() return nil end
  end, "throttle source unavailable")
end)

test("fixed green/yellow/red zones persist while throttle rises and falls", function()
  local env, state = environment("16\n")
  local script = loadScript(source, env)
  script.init()
  local channels = { G = {0, 1}, Y = {1, 1}, R = {1, 0} }
  for _, case in ipairs({
    {0, "", 0}, {1, "G", 9}, {35, "GGGGGG", 50},
    {36, "GGGGGGY", 8}, {55, "GGGGGGYYY", 50}, {75, "GGGGGGYYYYYY", 50},
    {76, "GGGGGGYYYYYYR", 8}, {100, "GGGGGGYYYYYYRRRR", 50},
    {76, "GGGGGGYYYYYYR", 8}, {75, "GGGGGGYYYYYY", 50},
    {36, "GGGGGGY", 8}, {35, "GGGGGG", 50}, {0, "", 0},
  }) do
    state.throttle = math.floor(case[1] * 2048 / 100 - 1024 + 0.5)
    state.writes = {}
    script.run()
    for id = 16, 31 do
      local c = assert(state.writes[id])
      local position = id - 16 + 1
      local color = channels[case[2]:sub(position, position)]
      local brightness = position == #case[2] and case[3] or 50
      assert(c[1] == (color and color[1] * brightness or 0)
          and c[2] == (color and color[2] * brightness or 0),
          "wrong color or brightness at " .. case[1] .. "%, LED " .. position)
      assert(c[3] == 0)
    end
  end
end)

test("whole-ring colors switch at 30/31 and 60/61 percent", function()
  local channels = { G = {0, 1}, Y = {1, 1}, R = {1, 0} }
  for _, first in ipairs({0, 16}) do
    local env, state = environment(tostring(first) .. "\n")
    local script = loadScript(uniformSource, env)
    script.init()
    for _, case in ipairs({
      {0, 0, "G", 0}, {1, 1, "G", 8}, {30, 5, "G", 40},
      {31, 5, "Y", 48}, {60, 10, "Y", 30}, {61, 10, "R", 38},
      {100, 16, "R", 50}, {60, 10, "Y", 30}, {30, 5, "G", 40}, {0, 0, "G", 0},
    }) do
      state.throttle = math.floor(case[1] * 2048 / 100 - 1024 + 0.5)
      state.writes = {}
      script.run()
      local color = channels[case[3]]
      for position = 1, 16 do
        local c = assert(state.writes[first + position - 1])
        local brightness = position < case[2] and 50
            or position == case[2] and case[4] or 0
        assert(c[1] == color[1] * brightness and c[2] == color[2] * brightness and c[3] == 0,
            "wrong whole-ring color or brightness at " .. case[1] .. "%")
      end
      for id in pairs(state.writes) do assert(id >= first and id < first + 16) end
      assert(state.fileWrites == 0)
    end
  end
end)

test("both effects and calibrated rings fill monotonically over all 2049 stick values", function()
  for _, case in ipairs({{source, 0}, {source, 16}, {uniformSource, 0}, {uniformSource, 16}}) do
    local text, first = case[1], case[2]
    local env, state = environment(tostring(first) .. "\n")
    local script = loadScript(text, env)
    script.init()
    local previous = 0
    for raw = -1024, 1024 do
      state.throttle = raw
      state.writes = {}
      script.run()
      local total, count, ended = 0, 0, false
      for id = first, first + 15 do
        local c = assert(state.writes[id])
        local brightness = math.max(c[1], c[2], c[3])
        assert(not ended or brightness == 0, "noncontiguous fill")
        if brightness == 0 then ended = true end
        total = total + brightness
      end
      for id in pairs(state.writes) do
        assert(id >= first and id < first + 16, "must only write the chosen ring")
        count = count + 1
      end
      assert(count == 16)
      assert(total >= previous, "brightness decreased while advancing throttle")
      previous = total
    end
    assert(state.frames == 2049 and previous == 800 and state.fileWrites == 0)
    state.throttle = -1024
    script.run()
    for _, c in pairs(state.writes) do assert(c[1] + c[2] + c[3] == 0) end
  end
end)

test("out-of-range input matches the fully off or full tricolor endpoint", function()
  local env, state = environment("0\n")
  local script = loadScript(source, env)
  script.init()
  for _, raw in ipairs({-2000, 2000}) do
    state.throttle = raw < 0 and -1024 or 1024
    state.writes = {}
    script.run()
    local endpoint = state.writes
    state.throttle = raw
    state.writes = {}
    script.run()
    for id = 0, 15 do
      local c, expected = state.writes[id], endpoint[id]
      assert(c[1] == expected[1] and c[2] == expected[2] and c[3] == expected[3])
    end
  end
end)

test("calibration paints blue/green groups and cancel preserves the saved map", function()
  local env, state = environment("16\n")
  local script = loadScript(toolSource, env)
  script.init()
  for id = 0, 31 do
    local c = assert(state.writes[id])
    assert(c[1] == 0)
    assert(c[2] == (id >= 16 and 50 or 0))
    assert(c[3] == (id < 16 and 50 or 0))
  end
  assert(script.run(0) == 0)
  assert(script.run(env.EVT_VIRTUAL_EXIT) == 2)
  for _, c in pairs(state.writes) do assert(c[1] + c[2] + c[3] == 0) end
  assert(state.mapping == "16\n" and state.fileWrites == 0)
end)

test("both color choices persist and the throttle script reads that same map", function()
  for _, first in ipairs({0, 16}) do
    local env, state = environment()
    local setup = loadScript(toolSource, env)
    setup.init()
    if first == 16 then setup.run(env.EVT_VIRTUAL_NEXT) end
    setup.run(env.EVT_VIRTUAL_ENTER)
    assert(state.mapping == tostring(first) .. "\n" and state.handles == 0)
    setup.run(env.EVT_VIRTUAL_ENTER)
    assert(state.fileWrites == 1, "must not write calibration on every frame")
    for id = 0, 31 do
      local c = assert(state.writes[id])
      assert(c[2] == (id >= first and id < first + 16 and 50 or 0))
      assert(c[1] == 0 and c[3] == 0)
    end
    assert(setup.run(env.EVT_VIRTUAL_EXIT) == 2)
    state.writes = {}
    local throttle = loadScript(source, env)
    throttle.init()
    state.throttle = 1024
    throttle.run()
    for id in pairs(state.writes) do assert(id >= first and id < first + 16) end
  end
end)

test("save failures remain visible instead of reporting success", function()
  for _, failure in ipairs({"readOnly", "dropWrite"}) do
    local env, state = environment()
    state[failure] = true
    local setup = loadScript(toolSource, env)
    setup.init()
    local ok, message = pcall(setup.run, env.EVT_VIRTUAL_ENTER)
    assert(not ok and tostring(message):find("ledid:", 1, true))
    assert(state.handles == 0)
  end
end)

print(string.format("%d tests passed; physical ring/color selection still requires the radio.", tests))
