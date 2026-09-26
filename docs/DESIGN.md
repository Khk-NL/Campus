# Campulse 设计规范 / Design Specification

> 色值不是猜的，取自华东师范大学**官方的《标准色使用规范》**。
> Colour values are not guesses: they come from ECNU's official *Standard Colour
> Specification*.
>
> 来源 / sources:
> - [标准色使用规范](https://www.ecnu.edu.cn/wzcd/xxgk/xxbs/bsxz/jcbf/bzssygf.htm)
> - [校标](https://www.ecnu.edu.cn/info/1086/53318.htm)
> - 官网 logo SVG（`logo3.svg` 中读到 `#A32135`，与官方标准色一致，差异来自 SVG 导出取整）
>   The site's logo SVG contains `#A32135`, matching the official standard colour; the
>   difference is SVG export rounding.

## 1. 标准色 / the standard colour

官方原文 / verbatim from the specification:

> **ECNU标准色为：PANTONE 201C（C0M100Y63K29 / R164G31B53）**

换算为十六进制即 **`#A41F35`**。规范同时规定「标准色经反复推敲、考量后确定，并标准化，
**不得任意更改**」，因此它是本项目的主色，不是可选项。

In hex: **`#A41F35`**. The specification states the standard colour is standardised and
**must not be altered at will**, so it is this project's primary colour rather than a
suggestion.

### 与 §0.3 的 `rgb(143,16,40)` 的差异 / divergence from the colour stated in §0.3

| 来源 | 色值 | 说明 |
| --- | --- | --- |
| 官方标准色 | `#A41F35` = rgb(164,31,53) | PANTONE 201C，规范明确不得更改 |
| §0.3 所述 | `#8F1028` = rgb(143,16,40) | 更深、更暗，属同一色族 |

处理方式：**主色用官方标准色 `#A41F35`**，把 `#8F1028` 作为同色族的**深色**用于按下态、
高对比文字与深色背景变体。两者同族，叠用不会冲突。

Primary is the official `#A41F35`; `#8F1028` becomes the family's **deep** shade for pressed
states, high-contrast text and dark-surface variants. Both belong to one family, so using
both is coherent.

## 2. 减网色阶 / the official tint ramp

规范提供了标准色的 85% / 70% / 55% / 40% / 25% / 10% 减网色，
「只能与标准色同时使用，只能作为标准色的补充和丰富」。按标准色叠白计算：

The specification defines 85/70/55/40/25/10 % tints, to be used only alongside the standard
colour. Computed by compositing the standard colour over white:

| 档位 | 色值 | 用途建议 |
| --- | --- | --- |
| 100%（标准色） | `#A41F35` | 主色：顶部栏、主按钮、选中态 |
| 85% | `#B24153` | 按下态、次级强调 |
| 70% | `#BF6272` | 图表主系列、图标 |
| 55% | `#CD8490` | 分隔强调、次级图形 |
| 40% | `#DBA5AE` | 非活跃态强调 |
| 25% | `#E8C7CD` | 浅色填充、选中项背景 |
| 10% | `#F6E9EB` | 页面/卡片浅底、悬停底色 |

## 3. 反白应用 / reversed (negative) application

官方规范给出了标志的**反底应用**：标准色作**实色块**，标志与文字用白色。
规范同时禁止形态 A、B 以轮廓线形式出现（形态 C 的轮廓线需 ≥0.2pt）。

The specification defines a reversed application: a **solid block** of the standard colour
carrying the mark and text in white. It forbids outline-only renderings of forms A and B
(form C's outline must be ≥0.2pt).

对客户端的含义 / what this means for the client:

- **顶部栏与关键容器用标准色实色块 + 白色内容**，而不是白底配红字。
  The top bar and key containers use a solid standard-colour block with white content,
  rather than a white bar with red text.
- **不要**把校徽做成细线描边图标。
  Do **not** render the university mark as a thin outline.
- 大面积区域仍以**白色为主**，标准色用于强调。官网本身即此结构：白色内容卡片 +
  红色页眉/页脚色块。
  Large areas stay **white-dominant** with the standard colour for emphasis, mirroring the
  official site: white content cards with red header/footer bands.

## 4. 从官网提取的布局语言 / layout language observed on the official site

| 观察 | 落到客户端的做法 |
| --- | --- |
| 顶部为整条实色红带，logo 左上 | 顶部栏：标准色实色 + 白字 + 白色图标 |
| 内容区大量白底卡片，圆角很小 | 卡片白底、小圆角、极淡阴影 |
| 细分隔线（发丝线）而非重投影 | `Divider` 用 10%/25% 减网色 |
| 留白充足，标题层级靠字号与字重 | 增大行高与区块间距，少用重色块堆叠 |
| 正文左对齐、窄栏 | 手机端自然满足；不要居中对齐长文本 |
| 红色只出现在标题装饰、链接、强调块 | 红色是**强调**而非**背景基调** |

## 5. 语义色 / semantic colours

规范只定义了一个品牌色，没有定义语义色。因此成功 / 警告 / 危险等语义色使用 Material 3
默认值，但**与标准色保持色相区隔**，避免与品牌红混淆。

The specification defines a single brand colour and no semantic palette, so success/warning/
danger use Material 3 defaults, kept distinct in hue from the brand red to avoid confusion.

⚠️ 特别注意：品牌色本身偏红，**不要**用红色表示"错误"的高频语义，否则用户无法区分
"这是品牌色"还是"这里出错了"。错误态请用更深的红并配合图标与文案，不要只靠颜色。

⚠️ The brand colour is itself red, so avoid using red for high-frequency error semantics;
users cannot tell "brand" from "something broke". Error states use a deeper red **plus** an
icon and text, never colour alone.

## 6. 字体 / typography

官方标准字体用于印刷与品牌物料，客户端不引入。客户端使用**系统字体栈**，
中文优先 `Noto Sans CJK SC` / `Source Han Sans` / 系统默认，英文与数字用系统 UI 字体。

The official standard typeface targets print and brand collateral and is not bundled. The
client uses the **system font stack**.

理由：Flutter 内置中文字体体积巨大（完整 CJK 字库 10 MB+），而系统字体在各平台上的
渲染质量已经足够；品牌识别主要由色彩与标志承担。

Bundling a full CJK font would add 10 MB+ for no real gain; brand recognition here is carried
by colour and the mark.

## 7. 落地位置 / where this lives in code

| 内容 | 位置 |
| --- | --- |
| 色板常量与 ThemeData | `apps/mobile/lib/core/theme/campus_theme.dart` |
| 高校配置（含名称、域名等） | `apps/mobile/lib/core/config/universities/` |

⚠️ §3.1 的隔离要求同样适用于样式：通用主题**只放色值与排版规则**，不得出现校名、
校徽资源路径等高校专有内容。校徽等资源由高校配置提供。

⚠️ §3.1's isolation rule applies to styling too: the generic theme holds **only colour values
and typography rules**, never a school name or a mark asset path. Those come from the
university config.
