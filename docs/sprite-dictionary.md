# 像素深渊 — 素材词典

记录项目中使用或可用的像素精灵素材，方便快速查找和复用。

---

## Tiny Creatures（CC0 公共领域）

**来源：** [clintbellanger.itch.io/tiny-creatures](https://clintbellanger.itch.io/tiny-creatures)  
**原始文件：** `tmp/tiny-creatures/tiny-creatures/`  
**规格：** 16×16 像素，与 Kenney Tiny Dungeon 风格完全一致  
**授权：** CC0 1.0 Universal，可商用，无需署名  

Tilesheet 布局：10列 × 18行，共 180 个精灵，间距 1px。

### 已鉴定精灵（tile_0001 ~ tile_0030）

| 编号 | 描述 | 当前用途 |
|------|------|---------|
| tile_0001 | 普通骷髅（绿眼） | — |
| tile_0002 | 普通骷髅（白色） | — |
| tile_0003 | 红色披风骷髅（首领气质） | ✅ **骷髅队长 Boss** → `boss_skeleton_captain.png` |
| tile_0004 | 火焰史莱姆（橙红火焰球） | ✅ **烈焰元素 Boss** → `boss_fire_elemental.png` |
| tile_0005 | 带斗篷的亡灵法师（黑紫色） | ✅ **亡灵法师 Boss** → `boss_necromancer.png` |
| tile_0006 | 眼球怪物（蓝色大眼） | ✅ **熔岩/亡灵主题普通敌人** → `eye_monster.png` |
| tile_0007 | 巨大的手（灰色） | — |
| tile_0008 | 蛇发女妖 / 头上长蛇的怪物 | — |
| tile_0009 | 食人植物（绿色） | ✅ **森林主题普通敌人** → `carnivorous_plant.png` |
| tile_0010 | 绿帽人形生物（矮人/精灵？） | — |
| tile_0011 | 人形小象动物（象鼻人） | — |
| tile_0012 | 哥布林（绿色小妖） | ✅ **石窟/熔岩主题普通敌人** → `goblin.png` |
| tile_0013 | 不明生物（像乘号/星形） | — |
| tile_0014 | 蘑菇怪（红色蘑菇头） | ✅ **森林主题普通敌人** → `mushroom.png` |
| tile_0015 | 白色傀儡（雪人/布偶形态） | — |
| tile_0016 | 鹿人（棕色，有鹿角） | ✅ **森林主题小Boss** → `boss_deer.png` |
| tile_0017 | 铁绿斗篷傀儡（绿色机甲） | — |
| tile_0018 | 蓝色斗篷傀儡 | — |
| tile_0019 | 红色斗篷傀儡 | — |
| tile_0020 | 带兜帽的人（黑色连帽） | — |
| tile_0021 | 牛头人/红色恶魔（小恶魔/魔鬼） | ✅ 已复制 → `demon.png`（熔岩主题预留） |
| tile_0022 | 猴子/灵长类动物 | — |
| tile_0023 | 棕色猿人/原始人 | — |
| tile_0024 | 灰色狼/狗 | — |
| tile_0025 | 灰色狼人/狗 | — |
| tile_0026 | 绿色女青蛙人/蜥蜴人 | — |
| tile_0027 | 蓝色水系生物（女鱼人/女妖/美人鱼？） | — |
| tile_0028 | 美人鱼/精灵/公主 | — |
| tile_0029 | 女人马/女战马 | — |
| tile_0030 | 橙色猫人/狐狸人/猫女 | — 
| tile_0031 | 灰色飞龙（西方神话龙） | — |
| tile_0032 | 篮色飞龙/冰龙/水龙（西方神话龙） | — |
| tile_0033 | 暗灰色飞龙（西方神话龙） | — |
| tile_0034 | 红色飞龙/火龙（西方神话龙） | — |
| tile_0035 | 绿色飞龙（西方神话龙） | — |
| tile_0036 | 女天使/天使 | — |
| tile_0037 | 宝宝天使 | — |
| tile_0038 | 上帝 | — |

> **待鉴定：** tile_0031 ~ tile_0180（主要是动物类：兔、猫、狗、马、熊等）

---

### 候选用途建议

| 精灵 | 建议用途 |
|------|---------|
| tile_0009 食人植物 | 第2主题（地下森林）普通敌人 |
| tile_0012 哥布林 | 替换或补充普通敌人（已复制） |
| tile_0006 眼球怪 | 深层地牢远程普通敌人（已复制） |
| tile_0014 蘑菇怪 | 地下森林主题小怪 |
| tile_0021 红色恶魔 | 熔岩主题普通敌人 |
| tile_0022 牛头人 | 小Boss候选（未来主题） |
| tile_0016 鹿人 | 地下森林 Boss 候选 |
| tile_0017 铁绿斗篷傀儡 | 深层地牢 Boss 候选 |
| tile_0008 蛇发女妖 | 特殊关卡 Boss 候选 |

---

## 当前项目使用的敌人精灵

| 文件 | 来源 | 类型 | 用途 |
|------|------|------|------|
| `assets/sprites/enemies/slime.png` | Kenney Tiny Dungeon | 普通敌人 | 史莱姆（1.8x放大+绿色=巨型史莱姆Boss） |
| `assets/sprites/enemies/skeleton.png` | Kenney Tiny Dungeon | 普通敌人 | 骷髅 |
| `assets/sprites/enemies/boss_dark_knight.png` | Kenney Tiny Dungeon | 大Boss | 暗黑骑士（第3层） |
| `assets/sprites/enemies/boss_skeleton_captain.png` | Tiny Creatures tile_0003 | 小Boss | 骷髅队长（第1、4、7...层） |
| `assets/sprites/enemies/boss_necromancer.png` | Tiny Creatures tile_0005 | 大Boss | 亡灵法师（第6层） |
| `assets/sprites/enemies/boss_fire_elemental.png` | Tiny Creatures tile_0004 | 大Boss | 烈焰元素（第9层） |
| `assets/sprites/enemies/goblin.png` | Tiny Creatures tile_0012 | 普通敌人 | 哥布林（森林/熔岩主题，快速近战） |
| `assets/sprites/enemies/eye_monster.png` | Tiny Creatures tile_0006 | 普通敌人 | 眼球怪（熔岩/亡灵主题，远程浮游） |
| `assets/sprites/enemies/mushroom.png` | Tiny Creatures tile_0014 | 普通敌人 | 蘑菇怪（森林主题，孢子AoE） |
| `assets/sprites/enemies/carnivorous_plant.png` | Tiny Creatures tile_0009 | 普通敌人 | 食人植物（森林主题，固定远程） |
| `assets/sprites/enemies/boss_deer.png` | Tiny Creatures tile_0016 | 小Boss | 鹿人（森林主题，冲锋+横扫） |
| `assets/sprites/enemies/demon.png` | Tiny Creatures tile_0021 | 预留 | 红色恶魔（熔岩主题预留） |

---

## 更新日志

| 日期 | 内容 |
|------|------|
| 2026-03-11 | 初始创建，鉴定 Tiny Creatures tile_0001~0030，集成 4 个精灵 |
| 2026-03-11 | 接入 4 个新普通敌人（哥布林/眼球怪/蘑菇怪/食人植物）+ 鹿人小Boss，实现 4 区主题系统 |
