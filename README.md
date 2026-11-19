# 拿拍

《拿拍》是一款处于概念设计阶段的 3D 游戏。

当前已确定：游戏中的拍子对应现实球拍，不同球拍承担不同的武器定位；默认采用近距离第三人称视角；本项目不是乒乓球游戏。

## 项目文档

- [产品方向](docs/PRODUCT_DIRECTION.md)
- [产品决策记录](docs/DECISION_LOG.md)
- [未来文明模拟 v0.1](docs/FUTURE_WORLD_SIMULATION_V0_1.md)
- [项目交接状态](docs/HANDOFF_CONTEXT.md)

## 当前原型

`prototype/` 是第一个可运行原型：Godot 4.7.x 3D 测试区、近距离第三人称移动、对话与商人 NPC、背包与交易、双向场景入口，以及可挑战顾言的简易回合制卡牌战斗。

安装 Godot 4.7.x 标准版后导入 `prototype/project.godot` 并运行。Windows 本地默认安装路径为 `%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe`。使用 `WASD` 移动，靠近 NPC 后按 `E` 对话；靠近任一场景的“区域传送门”后按 `E`，会立即在测试区和“中转庭院”之间来回传送，传送后角色会出现在目标门旁。

靠近商人阿铎后按 `E` 打开商店，可购买或出售物品；右上角显示金钱和物品数量，按 `I` 隐藏或显示背包。运行交易冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_trade.gd
```

靠近顾言后按 `E` 开始牌战。战斗开始时抽取 5 张牌，每回合有 3 点能量；出牌后不会立即补牌，结束回合、结算对手攻击后才补齐到 5 张。手牌包括攻击、格挡和削弱对手的牌。运行牌战冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_battle.gd
```

右上角背包 HUD 提供“牌组”和“卡牌图鉴”入口：牌组页查看当前固定测试牌组，图鉴页查看已实现卡牌的类型、费用、效果和是否已加入牌组。运行收藏信息冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_collection.gd
```

运行大门入口冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_gate.gd
```

当前原型仅使用 Godot 内置 3D、物理和 GUI API、GDScript，以及 Compatibility 渲染器；无需额外插件、.NET SDK 或外部运行库。Godot 生成的 `prototype/.godot/` 导入缓存不纳入版本控制。
