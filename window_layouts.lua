-- 按显示器组合保存 / 恢复窗口布局
--
--   ⌃⌥⌘S  把当前窗口位置存为「这套显示器」的布局
--   ⌃⌥⌘R  手动恢复「这套显示器」的布局
--
-- 显示器组合变了（插拔、换分辨率、唤醒后换了一套屏）会自动恢复对应的布局。
-- 保存按 App 合并：这次没露面的 App 保留上次存的位置。
-- 只能看到、挪动当前桌面（Space）里的窗口；全屏、最小化、隐藏的窗口不动。

local M = {}

M.dataPath = hs.configdir .. "/window_layouts.json"
M.settleSeconds = 3      -- 显示器变化后，先等系统自己挪完窗口
M.secondPassSeconds = 2  -- 再补一遍，盖住系统迟到的挪动
M.startupSeconds = 10    -- 开机时换了地方：等 App 把窗口开出来再恢复

local log = hs.logger.new("layouts", "info")

-- 记日志出错（比如 print 被命令行 hs 弄坏）也不能拦住保存和恢复
local function note(fmt, ...)
  pcall(log.f, fmt, ...)
end
local LAST_KEY_SETTING = "window_layouts.lastKey"
local HYPER = { "ctrl", "alt", "cmd" }

local lastKey            -- 上次处理过的显示器组合
local sawChange = false  -- 这一波显示器事件里组合变过没有（哪怕最后又变回来）
local settleTimer

-- 同型号的几块屏，系统会在名字后面加「(1)」「(2)」，但这个编号跟位置无关，插拔顺序一变就可能互换，
-- 所以去掉它，下面改按从左到右的位置编号
local function baseName(s)
  return ((s:name() or s:getUUID()):gsub(" %(%d+%)$", ""))
end

-- 当前所有屏幕；同名的多块屏按从左到右编号成「名字#1」「名字#2」
local function screens()
  local list = hs.screen.allScreens()
  table.sort(list, function(a, b)
    local fa, fb = a:fullFrame(), b:fullFrame()
    if fa.x ~= fb.x then return fa.x < fb.x end
    return fa.y < fb.y
  end)
  local result, seen = {}, {}
  for _, s in ipairs(list) do
    local name = baseName(s)
    seen[name] = (seen[name] or 0) + 1
    local f = s:fullFrame()
    result[#result + 1] = {
      screen = s,
      ref = name .. "#" .. seen[name],
      label = string.format("%s %dx%d", name, math.floor(f.w + 0.5), math.floor(f.h + 0.5)),
    }
  end
  return result
end

-- 「这套显示器」的指纹：屏幕名 + 分辨率，与屏幕怎么摆放无关
local function configKey(list)
  local labels = {}
  for _, s in ipairs(list) do labels[#labels + 1] = s.label end
  table.sort(labels)
  return table.concat(labels, " + ")
end

function M.currentKey()
  return configKey(screens())
end

-- 读存档；文件在但解析失败时返回 nil，免得保存时把它整个覆盖掉
local function loadLayouts()
  if not hs.fs.attributes(M.dataPath) then return {} end
  local data = hs.json.read(M.dataPath)
  if not data then return nil, "布局文件解析失败，先修好它：\n" .. M.dataPath end
  return data
end

-- 当前这套显示器、它的布局存于何时、存了几个窗口（菜单里显示状态用；没存过时后两项为 nil 和 0）
function M.status()
  local key = M.currentKey()
  local layouts = loadLayouts()
  local layout = layouts and layouts[key]
  local count = 0
  for _, entries in pairs(layout and layout.apps or {}) do count = count + #entries end
  return key, layout and layout.savedAt, count
end

-- 当前桌面里能挪的窗口，按窗口 id 升序（大致就是打开的先后）
local function windows()
  local result = {}
  for _, w in ipairs(hs.window.allWindows()) do
    local app, id = w:application(), w:id()
    local appKey = app and (app:bundleID() or app:name())
    if appKey and id and appKey ~= "org.hammerspoon.Hammerspoon"
      and w:isStandard() and w:isVisible() and not w:isFullScreen() then
      result[#result + 1] = { win = w, app = app, appKey = appKey, id = id, title = w:title() or "" }
    end
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

-- 把存档里某个 App 的窗口（saved）和它现在的窗口（current）一一配对：
-- 先按窗口 id（App 没重启过就完全对得上），再按标题，剩下的按打开先后
function M.match(saved, current)
  local matched, usedSaved, usedCurrent = {}, {}, {}
  local function pass(same)
    for i, s in ipairs(saved) do
      if not usedSaved[i] then
        for j, c in ipairs(current) do
          if not usedCurrent[j] and same(s, c) then
            usedSaved[i], usedCurrent[j] = true, true
            matched[#matched + 1] = { s, c }
            break
          end
        end
      end
    end
  end
  pass(function(s, c) return s.id == c.id end)
  pass(function(s, c) return s.title ~= "" and s.title == c.title end)
  pass(function() return true end)
  return matched
end

function M.save()
  local list = screens()
  local key = configKey(list)
  local layouts, err = loadLayouts()
  if not layouts then
    hs.alert.show(err)
    return 0
  end

  local refOf = {}
  for _, s in ipairs(list) do refOf[s.screen:id()] = s.ref end

  local captured, total = {}, 0
  for _, w in ipairs(windows()) do
    local screen = w.win:screen()
    local ref = screen and refOf[screen:id()]
    if ref then
      local f, origin = w.win:frame(), screen:fullFrame()
      captured[w.appKey] = captured[w.appKey] or {}
      table.insert(captured[w.appKey], {
        id = w.id, title = w.title, screen = ref,
        x = f.x - origin.x, y = f.y - origin.y, w = f.w, h = f.h,
      })
      total = total + 1
    end
  end
  if total == 0 then
    hs.alert.show("当前桌面没有可保存的窗口")
    return 0
  end

  local layout = layouts[key] or {}
  layout.apps = layout.apps or {}
  for appKey, entries in pairs(captured) do layout.apps[appKey] = entries end
  layout.savedAt = os.date("%Y-%m-%d %H:%M")
  layouts[key] = layout
  if not hs.json.write(layouts, M.dataPath, true, true) then
    hs.alert.show("写入失败：" .. M.dataPath)
    return 0
  end
  note("saved %d windows for %s", total, key)
  hs.alert.show(string.format("已保存 %d 个窗口的位置\n%s", total, key))
  return total
end

-- 有些 App（Chrome、Electron 系等）开着 AXEnhancedUserInterface 时，
-- 从外部挪窗口会走动画、尺寸也设不准；挪之前临时关掉，挪完再恢复
local function withoutEnhancedUI(app, fn)
  local ax = hs.axuielement.applicationElement(app)
  local enhanced = ax and ax:attributeValue("AXEnhancedUserInterface")
  if enhanced then ax:setAttributeValue("AXEnhancedUserInterface", false) end
  local ok, err = pcall(fn)
  if enhanced then ax:setAttributeValue("AXEnhancedUserInterface", true) end
  if not ok then note("error: %s", tostring(err)) end
end

local function near(a, b)
  return math.abs(a.x - b.x) < 2 and math.abs(a.y - b.y) < 2
    and math.abs(a.w - b.w) < 2 and math.abs(a.h - b.h) < 2
end

-- mode："manual" 总会提示结果；"auto" 只在挪了窗口或没存过布局时提示；"silent" 不提示
function M.restore(mode)
  mode = mode or "manual"
  local list = screens()
  local key = configKey(list)
  local layouts, err = loadLayouts()
  if not layouts then
    if mode ~= "silent" then hs.alert.show(err) end
    return 0
  end
  local layout = layouts[key]
  if not layout or not layout.apps then
    if mode ~= "silent" then hs.alert.show("这套显示器还没存过布局\n摆好窗口后按 ⌃⌥⌘S 保存") end
    return 0
  end

  local screenOf = {}
  for _, s in ipairs(list) do screenOf[s.ref] = s.screen end

  local byApp = {}
  for _, w in ipairs(windows()) do
    byApp[w.appKey] = byApp[w.appKey] or {}
    table.insert(byApp[w.appKey], w)
  end

  local moved = 0
  for appKey, saved in pairs(layout.apps) do
    local current = byApp[appKey]
    if current then
      withoutEnhancedUI(current[1].app, function()
        for _, pair in ipairs(M.match(saved, current)) do
          local entry, w = pair[1], pair[2]
          local screen = screenOf[entry.screen]
          if screen then
            local origin = screen:fullFrame()
            local target = hs.geometry.rect(origin.x + entry.x, origin.y + entry.y, entry.w, entry.h)
            if not near(w.win:frame(), target) then
              -- 先改尺寸、再挪、再改尺寸：跨屏时目标尺寸可能被原来那块屏限制住
              w.win:setSize(target.size)
              w.win:setTopLeft(target.topleft)
              w.win:setSize(target.size)
              moved = moved + 1
            end
          end
        end
      end)
    end
  end

  note("restored %s: %d windows moved (%s)", key, moved, mode)
  if mode == "manual" or (mode == "auto" and moved > 0) then
    hs.alert.show(moved > 0 and string.format("已恢复 %d 个窗口的位置", moved) or "窗口都已在保存的位置")
  end
  return moved
end

local function restoreWithSecondPass()
  M.restore("auto")
  if M.secondPassTimer then M.secondPassTimer:stop() end
  M.secondPassTimer = hs.timer.doAfter(M.secondPassSeconds, function() M.restore("silent") end)
end

local function onSettled()
  local key = M.currentKey()
  if key == lastKey and not sawChange then return end -- 只是 Dock 之类的变化
  note("displays: %s -> %s", tostring(lastKey), key)
  lastKey, sawChange = key, false
  hs.settings.set(LAST_KEY_SETTING, key)
  restoreWithSecondPass()
end

-- 显示器事件入口：插拔时系统会连发好几个事件，攒到安静下来再统一处理
function M.screensChanged()
  if M.currentKey() ~= lastKey then sawChange = true end
  settleTimer:start()
end

function M.start()
  lastKey = M.currentKey()
  local previous = hs.settings.get(LAST_KEY_SETTING)
  hs.settings.set(LAST_KEY_SETTING, lastKey)

  settleTimer = hs.timer.delayed.new(M.settleSeconds, onSettled)
  M.screenWatcher = hs.screen.watcher.new(M.screensChanged)
  M.screenWatcher:start()
  -- 合盖期间换了显示器，醒来时不一定还有屏幕事件，补查一次
  M.wakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake or event == hs.caffeinate.watcher.screensDidUnlock then
      settleTimer:start()
    end
  end)
  M.wakeWatcher:start()

  hs.hotkey.bind(HYPER, "S", M.save)
  hs.hotkey.bind(HYPER, "R", function() M.restore("manual") end)

  -- 上次关机前接的是另一套显示器：等 App 把窗口开出来再恢复
  if previous and previous ~= lastKey then
    M.startupTimer = hs.timer.doAfter(M.startupSeconds, restoreWithSecondPass)
  end
end

return M
