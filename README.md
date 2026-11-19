# 拿拍

《拿拍》是一款处于概念设计阶段的 3D 游戏。

当前已确定：游戏中的拍子对应现实球拍，不同球拍承担不同的武器定位；默认采用近距离第三人称视角；本项目不是乒乓球游戏。

## 项目文档

- [产品方向](docs/PRODUCT_DIRECTION.md)
- [产品决策记录](docs/DECISION_LOG.md)
- [未来文明模拟 v0.1](docs/FUTURE_WORLD_SIMULATION_V0_1.md)
- [项目交接状态](docs/HANDOFF_CONTEXT.md)

## 当前原型

`prototype/` 是第一个可运行原型：Godot 4.7.x 3D 测试区、近距离第三人称移动、两个对话 NPC、一个商人 NPC、背包与交易，以及一个可往返的场景入口。

安装 Godot 4.7.x 标准版后导入 `prototype/project.godot` 并运行。Windows 本地默认安装路径为 `%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe`。使用 `WASD` 移动，靠近 NPC 后按 `E` 对话；靠近右侧的“区域传送门”后按 `E`，确认即可进入“中转庭院”，在第二场景按 `Esc` 或返回按钮回到测试区。

靠近商人阿铎后按 `E` 打开商店，可购买或出售物品；右上角显示金钱和物品数量，按 `I` 隐藏或显示背包。运行交易冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_trade.gd
```

运行大门入口冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_gate.gd
```

当前原型仅使用 Godot 内置 3D、物理和 GUI API、GDScript，以及 Compatibility 渲染器；无需额外插件、.NET SDK 或外部运行库。Godot 生成的 `prototype/.godot/` 导入缓存不纳入版本控制。
