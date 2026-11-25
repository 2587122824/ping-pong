# 实时布阵自动战斗 V0.3 — 实现与平衡基线（候选）

> 最近更新：2026-11-24
> 设计原文：`docs/FORMATION_BATTLE_V0_3.md`（用户提供的 `v0_3_3_7.md` 副本）。
> 本文件记录原型落地情况、实测基线与待验证项；**V0.3 尚未确认为正式方向**，旧 V0.2 布阵原型与回合制牌战仍保留在仓库中。

## 1. 原型文件

| 文件 | 作用 |
| :--- | :--- |
| `prototype/formation_battle_v03.gd` | V0.3 布阵战斗主脚本（Node3D，内含 3D 桌面搭建 + 2D 覆盖层） |
| `prototype/formation_battle_v03.tscn` | 挂载上述脚本的场景 |
| `prototype/tests/smoke_formation_v03.gd` | 冒烟断言：13 卡费用、木棍加成、区域限制、炸弹推动/定时/推底引爆、次数退场、控台 debuff、反拉借力、两个 BOSS 能力、生命结算、时间到判定 |
| `prototype/tests/balance_v03.gd` | 平衡探针：自动布阵 + 战斗中自动补位，两 BOSS 各 8 局，输出胜率/时长/残留血量/在场单位 |
| `prototype/tests/debug_v03.gd` | 单局状态轨迹调试（每 3 秒 dump 双方血量/体力/在场数/三路炸弹位置与伤害收支） |

运行冒烟：

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path prototype --script res://tests/smoke_formation_v03.gd
```

## 2. 已落地机制（对应设计章节）

- **3 路 × 7 排站桩纵深**：`LANES=3`、`ROWS=7`；近台 `[0,1]`、中台 `[2,3,4]`、远台 `[5,6]`（`ZONE_ROWS`）。单位部署后固定不动，只出手，不向前推进。
- **单位去生命值化**：出手次数耗尽、持续时间到期、被克制逼退、被换阵覆盖四种退场；单位字典无 HP 字段。
- **全场单颗主炸弹拔河**：取消三路各一颗，改为共享一颗（`bomb_pos` 中线 0，负=我方半场、正=敌方半场；`bomb_lane` 记录视觉所在路）；我方出手推 `+`、敌方推 `-`，三路推力汇总到同一颗。
  - 定时引爆：`BOMB_TIMER=7.0` 秒一轮，炸当前所在半场，`BOMB_DAMAGE=15`；停在中线 ±0.3 内无人受伤。
  - 推底引爆：`bomb_pos` 到 ±`BOMB_RANGE=7.0` 立即引爆，`BASELINE_DAMAGE=22`，随后炸弹回中线。
- **双方主体生命**：玩家 `PLAYER_MAX_HP=100`；BOSS 独立血量；生命归零判负；`BATTLE_LIMIT=90.0` 秒到时按剩余血量判定。
- **四类克制链**（`COUNTER` 倍率表，攻方行 × 守方列）：
  - fast 快攻：克 spin 1.5，被 counter 0.6；
  - spin 弧圈：克 fast 1.3、control 0.7、counter 0.5；
  - control 控台：克 spin 0.9；
  - counter 反击：克 spin 1.4、fast 0.8。
- **武器「木棍」**：玩家 fast 卡费用 -2（最低 5）、fast 出手 +1；其余类型不吃加成。
- **BOSS 能力**：
  - `kid` 小孩哥（童子功）：敌方 fast 出手 +1、间隔 ×0.95、费用 -3；开局三单位 `tt_sub`(0,0) / `tt_main`(1,0) / `tt_rip`(2,0)。
  - `elder` 小区大爷（极致球感）：玩家 heavy 招式推进时被在场敌方单位卸力反推 50%；开局 `tt_long`(0,5) / `tt_defense`(1,2) / `tt_serve`(2,5)。

## 3. 13 张招式牌（V0.3 口径，费用 10–35）

| id | 名称 | 费 | 类型 | 区域 | 退场/节奏 | 关键特性 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `tt_sub` | 正手快带 | 10 | fast | 近台 | 3 出手 / 1.0s / 推 0.8 | 低费抢中线 |
| `tt_main` | 正手快攻 | 15 | fast | 近台 | 4 出手 / 1.1s / 推 1.0 | 同路另一个正手 +0.4 推力 |
| `tt_rip` | 反手快攻 | 15 | fast | 近/中 | 3 出手 / 1.0s / 推 0.9 | 入场免费推一次 |
| `tt_short` | 摆短 | 15 | control | 近台 | 持续 8s | debuff spin：推力 ×0.5、间隔 ×1.5 |
| `tt_long` | 劈长 | 15 | control | 远台 | 持续 8s | debuff fast：推力 ×0.6、间隔 ×1.3 |
| `tt_serve` | 转不转发球 | 15 | control | 远台 | 持续 8s | 每 3s +3 体力；吃转反推首次来球 |
| `tt_tear` | 反手快撕 | 20 | counter | 中台 | 3 出手 / 1.2s / 推 1.0 | 反射 fast；克制时多耗敌方 1 次出手 |
| `tt_loop` | 前冲弧圈球 | 25 | spin | 中台 | 3 出手 / 1.5s / 推 1.5 | heavy |
| `tt_spin` | 加转弧圈球 | 25 | spin | 中/远 | 3 出手 / 1.6s / 推 1.2 | heavy；drain |
| `tt_defense` | 正手反拉 | 25 | counter | 中台 | 2 出手 / 1.0s / 推 1.3 | 反射 spin |
| `tt_backhand_counter` | 反手反拉 | 25 | counter | 中台 | 2 出手 / 1.0s / 推 1.1 | 反射 fast |
| `tt_smash` | 正手扣杀 | 30 | counter | 中/远 | 1 出手 / 2.6s / 推 2.0 | heavy；炸弹在敌方半场时直接推底引爆 |
| `tt_tactic` | 霸王拧 | 35 | counter | 近/中 | 2 出手 / 1.3s / 推 1.6 | heavy；无视控台压制 |

> 注意：本表 id 与回合制牌战 `main.gd` 的卡表不同（牌战用 `tt_chop/tt_control/...` 等），两套脚本各自独立字典，互不引用。

## 4. 平衡基线（`balance_v03.gd`，每关 8 局，自动布阵代理）

当前档位：玩家体力回复 `REGEN_AMOUNT=5`/秒、敌方 `ENEMY_REGEN_AMOUNT=1`/秒、开局体力 100、手牌 5、敌方补位间隔 2.4s。

| 关卡 | 胜场 | 胜率 | 平均时长 | 玩家残留血 | 敌方残留血 | 玩家在场 | 敌方在场 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `CH0-B01` 小孩哥 | 0/8 | 0% | 24.0s | 0.0 | 41.3 | 1.3 | 0.8 |
| `CH0-B02` 小区大爷 | 5/8 | 63% | 56.2s | 11.9 | 3.0 | 1.3 | 0.0 |

### 4.1 已做过的单变量尝试

1. **体力回复**：玩家回复 2 → 3 → 5/秒。提到 5 后大爷关从 0% 翻到 63–75%，小孩哥关仍 0%（敌方残留血从 58.9 降到 41.3）。
2. **敌方回复**：从双方同速改为敌方 1/秒。大爷关单位很快耗尽，但玩家仍会先被炸弹磨死；说明大爷关的瓶颈是玩家阵地持续，不是敌方刷怪。
3. **自动布阵 AI 打分**：初版按行优先占位，5 张全挤一路；改为两波布阵（先每路一张、优先攻击型，再填空位），打分综合进攻克制倍率、被克制扣分、反射/debuff 匹配。
4. **童子功攻速**：fast 间隔 ×0.85 放宽到 ×0.95，胜率数字无变化，攻速不是小孩哥关的瓶颈。

### 4.2 现状判断

- 大爷关（慢节奏、卸力反制）在当前代理 AI 下基本能打；小孩哥关（快攻 swarm）仍是墙，玩家通常在 20–24 秒被三路炸弹磨穿。
- 以上胜率由**占位自动 AI** 打出，不是真人操作；真人会主动针对同路类型摆反射/控台，实际难度可能低于探针数字。**必须真人试玩后再动数值**，避免把代理 AI 的构筑缺陷误调成 BOSS 数值。
- 单局调试常见轨迹：开局铺 4–5 张后体力见底，fast 单位 3–4 秒退场，补位只够每 3–4 秒补一张；两路失控后被定时/推底炸弹连续扣血。

## 5. 待验证清单（对应设计 §7）

1. **单颗共享炸弹 vs 三路各一颗**：已按单颗共享落地（三路净推力汇总到一颗主炸弹，沿 X 轴压到对应半场格子，Z 跟随最后一路）；视觉焦点与倒计时清晰度待真人试玩确认。
2. **100 体力 + 10–35 费曲线**：开局铺 4–5 张符合预期；前 20 秒能否稳定触发 2–3 次互克与 1 次引爆，待真人对局统计。
3. **无血退场节奏**：次数耗尽 + 克制逼退能否把 3×7 空位率保持在 40%–60%，探针只记录了在场单位总数，尚未做空位率统计。
4. **跨路支援**：设计 §2.2「本路敌方全空时多余攻势向相邻路偏移」**尚未实现**，当前索敌只看本路。
5. **主动换阵覆盖**：设计 4.2 第 4 种退场（拖牌覆盖返还体力/入场推力）**尚未实现**，目前覆盖会直接顶掉旧单位。
6. **炸弹冲击波**：设计 3.2 提到引爆后清理/重置受波及前排招式，**尚未实现**。

## 6. 工作区遗留与处置

- 旧 V0.2 HP 单位体系（`formation_battle.gd/.tscn`、`formation_unit.gd`、`formation_card_view.gd`、`formation_slot_view.gd`）及全部旧探针/测试（`smoke_formation.gd`、`smoke_formation_tt.gd`、`balance_tt.gd`、`balance_formation.gd`、`balance_tuning.gd`、`level1_probe.gd`、`refill_probe.gd`）已于 2026-11-24 删除；`main.gd` 的布阵入口（F2 / 布阵按钮）改挂 `formation_battle_v03.tscn`。
- 历史设计文档 `FORMATION_BATTLE_V0_1.md` / `FORMATION_BATTLE_V0_2.md` / `BALANCE_BASELINE_V0_1.md` 保留为历史记录，对应原型代码已不在仓库。
- 回合制牌战线（`main.gd` + `smoke_battle.gd` 等）与 V0.3 布阵重构互不依赖。
- 布阵原型打开时（`_open_formation_battle`）收起探索常驻 HUD：左侧 `player_status_hud`、右侧 `economy_hud`、顶部 `interaction_hint`；关闭（`_close_formation_battle`）后全部恢复可见。回归测试 `smoke_hud.gd` 校验显隐与恢复。
- 布阵原型由节点自身 `_process(delta)` 驱动 `tick()`（`auto_tick=false` 时关闭，供 headless 测试手动推进）；此前真实窗口开战後时间/炸弹不走，已修复。
- 界面层 2026-11-24 重写：棋盘按设计 §2 分半场（我方远→近 / 炸弹 / 敌方近→远），表头标注近/中/远台；单位按 fast/spin/control/counter 四色描边，手牌卡片显示费用·区域·出手/持续·可出状态；双方生命条与我方体力条分行展示。战斗逻辑、常量与卡表未改动。
- 2026-11-24 界面二轮打磨：炸弹改为自绘球体控件（引信/高光/半场描边色/方向箭头/位置与倒计时，`BombView`）；棋盘伪纵深 2.5D（远台槽位更小更暗、近台更大，车道横带与中线炸弹槽背景 `BoardBg`）；选中手牌后我方槽位三态高亮——绿框可放空槽、琥珀框可覆盖已有单位、压暗为不符合区域（`_apply_slot_highlight`，冒烟 `smoke_highlight.gd`）；再点同一张牌取消选中。
- 2026-11-24 炸弹反馈补全：球体按 `pos` 在轨道上实际左右滑动（±7 格映射 ±34px）；引爆时 `BombView` 播放 0.6s 扩散冲击环 + 白色闪光，结束后炸弹回中线；`_detonate` 触发 `play_explosion()`。
- 2026-11-24 升级为真 3D 桌面战场：根节点改 Node3D，自建斜俯视相机、环境光 + 平行光、台面与 3×7 双侧槽位面板；部署单位为站在槽位上的胶囊棋子（四色），单颗主炸弹为球体 + 引信火花，引爆播放扩散冲击环（`boom_node`/`boom_time`）。槽位点选走 `_input` 射线检测 `Area3D` 元数据；2D 覆盖层只保留生命/体力条、手牌、按钮与日志，覆盖层根 `mouse_filter=IGNORE` 让点击穿透到 3D。主壳关闭布阵时恢复主相机 `camera.current=true`。旧 2D `BombView`/`BoardBg` 内类已移除；冒烟断言改为读 `bomb_pos/bomb_timer/boom_time`。
- 2026-11-25 场景隔离：主壳新增 `_set_world_visible(visible)`，打开布阵前隐藏除 `formation_battle` 外全部 `Node3D` 子节点（地面/NPC/传送门/灯光环境），关闭后恢复，消除局内棋盘与探索世界重叠；`smoke_hud.gd` 补 3D 节点显隐断言。
- 2026-11-25 手牌拾取 + 拖拽部署：手牌 Button 不再挂 `pressed` 信号，改由 `_input` 统一分流——左键按下经 `gui_get_hovered_control` 命中带 `hand_index` 元数据的手牌则记录拖拽起点；位移超 10px 进入拖拽态并显示跟随光标的卡名标签（`drag_label`，IGNORE 过滤）；抬起时射线命中我方槽位则 `try_deploy`，未超位移视为点按切换选中（`_on_hand_pressed`）。`_pick_slot` 用 `battle_camera.get_screen_ray` + `PhysicsRayQueryParameters3D.create`，`collide_with_areas=true`，从 Area3D 的 `side/lane/row` 元数据取槽位。
- 2026-11-25 界面与 3D 美化：手牌卡片圆角 10、类型色描边（选中提亮 2px、非选中压暗 0.35、体力不足灰底）；顶部状态行包一层半透明深色圆角 `PanelContainer`；关卡/操作按钮统一深色圆角样式；台面加深蓝并加外框底座，分区配色提亮，棋子加底座圆盘，炸弹改金属质感（metallic 0.6 / roughness 0.35）；相机收至 fov 50、位置 (0,12.5,10.5)。
- 2026-11-25 棋盘与手牌分离 + 棋子实名：3D 场景迁入独立 `SubViewport`（1240×330），由 `SubViewportContainer` 固定在顶部带状区域，手牌/按钮/日志在其下方，不再互相遮挡；射线拾取坐标经 `_to_viewport_local` 换算到视口本地坐标系，物理空间用 `board_viewport.world_3d`。棋子头顶挂 `Label3D`，显示卡牌名 + 剩余出手次数（`×N`），描边深色、billboard 朝向相机；车道 Z 间距收紧到 ±1.6，台面/槽位深度同步收窄。相机 `look_at_from_position` 构造（节点入树前不能用 `look_at`）。
- 2026-11-25 修复槽位拾取失效：Godot 4.7.2 的 `Camera3D`/`SubViewport` 均无 `get_screen_ray` 方法，射线改为 `project_ray_origin(screen)` + `project_ray_normal(screen)` 手工构造；`SubViewport.world_3d` 在未独立建世界时为 null，物理空间回退 `get_world_3d().direct_space_state`。探针投影 9 个我方槽位世界坐标回屏幕再拾取，side/lane/row 全部命中，符合区域的牌 `try_deploy` 成功。
- 2026-11-25 棋盘放大：车道 Z 间距收紧到 ±1.2（槽位/台面/中线深度同步收窄），相机拉近到 (0,7.5,0.8)，棋盘铺满顶部视口带状区域，棋子与卡名标签清晰可读。
- 2026-11-25 修复炸弹位置异常：① 布阵阶段开局单位的 `entry_push`（`tt_rip` 入场免费推击）会在开战前就把主炸弹推离中线，现仅在 `phase=="battle"` 时触发，布阵阶段炸弹固定在中线 0；② 炸弹 Z 向不再跟随最后推球单位在车道间跳变（`_push` 不再改写 `bomb_lane`，固定中路）；③ 炸弹 X 向改为视觉缓动（`bomb_vis_x`，`move_toward` 速度 10/s），不再按每次推力直接瞬移。`bomb_lane` 语义改为固定中路记录位。
