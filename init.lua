-- Hammerspoon 配置入口
hs.autoLaunch(true)  -- 登录时自动启动，不然换了地方它没在跑
require("hs.ipc")    -- 让命令行 hs 能连进来（排查问题用）

local ok, err = pcall(function()
  windowLayouts = require("window_layouts")
  windowLayouts.start()
  require("menu").start()
end)

-- 中文菜单建好了才隐藏自带的英文菜单；出错时留着英文菜单，还能点 Reload Config、看 Console
hs.menuIcon(not ok)
if not ok then
  print(err)
  hs.alert.show("Hammerspoon 配置加载出错，详见 Console", 5)
end
