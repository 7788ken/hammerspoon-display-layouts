# hammerspoon-display-layouts

在公司和家之间往返，显示器数量、分辨率都不一样，每次接上显示器都要重新摆一遍窗口。
这套 [Hammerspoon](https://www.hammerspoon.org/) 配置给每一套显示器组合各存一份窗口布局，接上显示器后自动恢复。

## 功能

- **按显示器组合记布局**：用「屏幕名 + 分辨率」区分是哪一套显示器，屏幕左右怎么摆不影响。
- **自动恢复**：显示器插拔、换分辨率、合盖后在另一个地方打开，大约 3 秒后窗口自动归位；2 秒后再补一遍，盖住系统迟到的挪动。
- **窗口配对**：App 没退出过时按窗口 id 精确对应；退出重开过，先按窗口标题对，对不上再按打开的先后顺序。
- **按 App 合并保存**：这次没打开的 App 保留它上次存的位置。
- **同型号多块屏**：macOS 给同型号显示器加的「(1)」「(2)」编号跟位置无关，这里改按从左到右的位置编号，不会左右互换。
- **中文菜单栏菜单**：显示当前显示器组合、这套组合有没有存过布局，保存 / 恢复 / 重新加载配置都在菜单里；图标有四款可选。

## 安装

1. 安装 Hammerspoon：

   ```bash
   brew install --cask hammerspoon
   ```

2. 把本仓库放到 `~/.hammerspoon`（已有配置的话，把 `window_layouts.lua`、`menu.lua`、`icons/` 复制进去，再在你的 `init.lua` 里按本仓库的 `init.lua` 加载）：

   ```bash
   git clone https://github.com/7788ken/hammerspoon-display-layouts.git ~/.hammerspoon
   ```

3. 打开 Hammerspoon，在「系统设置 → 隐私与安全性 → 辅助功能」里打开 Hammerspoon 的开关。刚开的权限通常要**重启一次 Hammerspoon**才生效。

`init.lua` 已经设置了登录时自动启动。

## 使用

| 操作 | 快捷键 | 说明 |
|---|---|---|
| 保存当前布局 | ⌃⌥⌘S | 把当前所有窗口的位置存为「这套显示器」的布局 |
| 恢复布局 | ⌃⌥⌘R | 手动恢复「这套显示器」的布局 |

第一次到一个地方，把窗口摆好后按 ⌃⌥⌘S。之后每次接上这套显示器，窗口会自动归位。只用笔记本屏幕时也可以存一份。

菜单栏图标点开有同样的操作，还有状态行显示当前显示器组合和保存时间。

## 自定义

- **快捷键**：改 `window_layouts.lua` 顶部的 `HYPER`。
- **等待时间**：`window_layouts.lua` 顶部的 `settleSeconds`（显示器变化后等几秒再恢复）、`secondPassSeconds`（补第二遍的间隔）、`startupSeconds`（开机时等 App 把窗口开出来的时间）。
- **菜单栏图标**：改 `menu.lua` 顶部的 `M.icon`，可选 `tiles`（分屏显示器）、`dual`（双屏）、`layout`（分块布局）、`desk`（带鱼屏 + 笔记本）。图标是 `icons/make_icons.py` 生成的矢量 PDF，改完脚本重新运行即可：

  ```bash
  python3 icons/make_icons.py
  ```

改完配置后在菜单里点「重新加载配置」。

## 局限

- 只处理当前桌面（Space）里的窗口；全屏、最小化、隐藏的窗口不动。
- 没打开的 App 不会帮你打开。
- 布局存在 `~/.hammerspoon/window_layouts.json`，里面有窗口标题，已在 `.gitignore` 里排除，不要提交。

## 排查

打开菜单里的「控制台…」，看 `layouts:` 开头的日志：显示器组合什么时候变的、恢复了几个窗口。

## 协议

[MIT](LICENSE)
