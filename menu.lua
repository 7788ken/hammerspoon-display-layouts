-- 菜单栏里的中文菜单，替代 Hammerspoon 自带的英文菜单

local layouts = require("window_layouts")

local M = {}

-- 菜单栏图标，可选：tiles 分屏显示器、dual 双屏、layout 分块布局、desk 带鱼屏 + 笔记本
-- （都在 icons/ 目录里，由 icons/make_icons.py 生成）
M.icon = "tiles"

-- 每次点开菜单时现做，状态行才是最新的
function M.items()
  local key, savedAt, count = layouts.status()
  return {
    { title = "当前显示器：" .. key, disabled = true },
    { title = savedAt and string.format("已保存布局：%d 个窗口（%s）", count, savedAt)
                       or "这套显示器还没保存布局", disabled = true },
    { title = "-" },
    { title = "保存当前布局（⌃⌥⌘S）", fn = function() layouts.save() end },
    { title = "恢复布局（⌃⌥⌘R）", fn = function() layouts.restore("manual") end, disabled = not savedAt },
    { title = "-" },
    { title = "重新加载配置", fn = function() hs.reload() end },
    { title = "打开配置文件夹", fn = function() hs.open(hs.configdir) end },
    { title = "控制台…", fn = function() hs.openConsole() end },
    { title = "偏好设置…", fn = function() hs.openPreferences() end },
    { title = "-" },
    { title = "关于 Hammerspoon", fn = function() hs.openAbout() end },
    { title = "检查更新…", fn = function() hs.checkForUpdates() end },
    { title = "退出 Hammerspoon", fn = function() os.exit(true, true) end,
      tooltip = "退出后，换显示器就不会自动恢复布局了" },
  }
end

function M.start()
  M.bar = hs.menubar.new(true, "hammerspoon_cn_menu")
  -- 图标文件找不到时退回原来的锤子，免得菜单整个看不见（setIcon 遇到坏路径不报错，得先自己加载）
  M.bar:setIcon(hs.image.imageFromPath(hs.configdir .. "/icons/" .. M.icon .. ".pdf")
    or hs.image.imageFromPath(hs.processInfo.bundlePath .. "/Contents/Resources/statusicon.pdf"))
  M.bar:setTooltip("Hammerspoon · 窗口布局")
  M.bar:setMenu(M.items)
end

return M
