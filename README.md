# 拿拍

《拿拍》是一款处于概念设计阶段的 3D 游戏。

当前已确定：游戏中的拍子对应现实球拍，不同球拍承担不同的武器定位；默认采用近距离第三人称视角；本项目不是乒乓球游戏。

## 项目文档

- [产品方向](docs/PRODUCT_DIRECTION.md)
- [卡牌战斗规则 V0.1](docs/CARD_BATTLE_RULES_V0_1.md)
- [产品决策记录](docs/DECISION_LOG.md)
- [未来文明模拟 v0.1](docs/FUTURE_WORLD_SIMULATION_V0_1.md)
- [项目交接状态](docs/HANDOFF_CONTEXT.md)

## 当前原型

`prototype/` 是第一个可运行原型：Godot 4.7.x 3D 测试区、近距离第三人称移动、对话与商人 NPC、背包与交易、双向场景入口，以及可挑战顾言的简易回合制卡牌战斗。

安装 Godot 4.7.x 标准版后导入 `prototype/project.godot` 并运行。Windows 本地默认安装路径为 `%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe`。使用 `WASD` 移动，靠近 NPC 后按 `E` 对话；靠近任一场景的“区域传送门”后按 `E`，会立即在测试区和“中转庭院”之间来回传送，传送后角色会出现在目标门旁。

靠近商人阿铎后按 `E` 打开商店，可购买或出售物品；右侧 3×3 背包格按 `I` 隐藏或显示，同类物品会叠加数量。点击能量饮料、急救贴或创伤包可分别恢复 6、10、18 点生命；满血和牌战中不能使用。运行交易与背包冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_trade.gd
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_inventory.gd
```

靠近顾言后按 `E` 开始牌战。牌分为行动、防御、资源、战术四类，每回合每类最多打出 1 张；正手、反手和旋球扰乱共享行动额度。战术增幅会强化下一张行动牌伤害 +3；数据回收抽 1 张牌且手牌不超过 5 张。结束回合结算对手攻击后补齐手牌到 5 张。当前固定测试牌组为 14 张、六种卡牌。卡牌采用独立牌面展示，并带有抽牌、出牌、洗牌和悬停动画。运行牌战冒烟测试：

左上角紧凑状态 HUD 和牌战 UI 会显示生命、魔法与经验。生命初始 30，战斗间不会自动回满；每次胜利获得 25 点经验，每 100 点经验升一级。魔法初始 10，目前没有卡牌消耗魔法。

升级会获得 1 个技能点。背包 HUD 中的“技能树”可解锁四种被动技能：行动伤害 +1、战斗开始格挡 +2、战斗外治疗 +2、战术增幅 +1；其中两个技能有前置节点。技能状态目前不保存，重启原型后会重置。运行技能树冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_skills.gd
```

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_battle.gd
```

右上角背包 HUD 提供“牌组”“图鉴”和“装备”入口。装备页包含武器、衣服、鞋子、帽子四个槽位；开局默认装备攻击 +2 的训练球拍，其余槽位为空。正手击打、反手快攻和旋球扰乱的伤害等于卡牌基础伤害加武器攻击，战术增幅再额外叠加 +3。装备暂不支持获取、替换或强化。运行装备与伤害公式测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_equipment.gd
```

牌组页查看当前固定测试牌组，图鉴页查看已实现卡牌的类型、每回合使用上限、效果和是否已加入牌组。运行收藏信息冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_collection.gd
```

运行大门入口冒烟测试：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_gate.gd
```

当前原型仅使用 Godot 内置 3D、物理和 GUI API、GDScript，以及 Compatibility 渲染器；无需额外插件、.NET SDK 或外部运行库。Godot 生成的 `prototype/.godot/` 导入缓存不纳入版本控制。
