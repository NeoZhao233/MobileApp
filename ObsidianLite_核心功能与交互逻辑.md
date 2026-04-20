# Obsidian Lite 核心功能与交互逻辑

版本日期：2026-04-20

## 1. 核心数据模型
- Note 字段
  - id: string
  - title: string
  - category: string
  - body: string
  - tags: string[]
  - isPinned: boolean
  - createdAt: string
  - lastVisitedAt: string
  - updatedAt: string
- 本地存储 Key
  - obsidian_lite_notes_json
- 兼容旧数据的迁移规则
  - category 为空 -> 默认分类
  - isPinned 缺失 -> false
  - createdAt 缺失 -> updatedAt 或当前日期
  - lastVisitedAt 缺失 -> updatedAt 或 createdAt

## 2. 启动与持久化
- aboutToAppear
  - 初始化 PersistentStorage
  - 从 AppStorage 读取并解析
  - 校验数据，失败则回退样例数据
- 数据更新时
  - 立即写回 AppStorage
  - 同步图谱布局（force layout）

## 3. 笔记库（Library）
### 3.1 搜索与过滤
- 搜索入口：顶部搜索框
- 过滤条件
  - 分类过滤 activeCategory
  - 标签过滤 activeTag
- 搜索增强逻辑
  - 精确包含优先
  - 去空格匹配
  - 子序列匹配
  - 相关性评分：标题 > 分类 > 标签 > 正文

### 3.2 模式切换（一级按钮）
- 分类 / 标签 / 排序 / 最近
- 点击切换显示对应的二级按钮

### 3.3 二级按钮逻辑
- 分类模式
  - 全部分类 / 具体分类
  - 点击具体分类 -> activeCategory = 分类名
  - 点击全部分类 -> activeCategory = ''
- 标签模式
  - 全部标签 / 具体标签
  - 点击具体标签 -> activeTag = 标签名
  - 点击全部标签 -> activeTag = ''
- 排序模式
  - 按更新 / 按标题 / 按分类 / 按最近访问
  - sortMode 影响列表排序
- 最近模式
  - 展示最近访问的 4 条笔记
  - 点击直接打开该笔记

### 3.4 列表排序规则
- 置顶优先
- sortMode 规则
  - updated: updatedAt 降序
  - title: 标题拼音排序
  - category: 分类优先，其次更新
  - recent: lastVisitedAt 降序

### 3.5 笔记卡片
- 标题 / 分类 / 摘要 / 标签 / 访问与更新日期
- 搜索命中高亮
  - 标题 / 分类 / 摘要 / 标签均可高亮

## 4. 笔记详情（NotePanel）
### 4.1 浏览态
- 标题 + 分类 + 更新时间
- 标签展示
- Markdown 预览
- 当前链接列表
  - 点击链接直接跳转目标笔记
  - 若不存在则自动创建空笔记

### 4.2 编辑态
- 标题输入
- 分类输入
- 标签新增
- 正文输入
- 任意字段修改 -> 触发保存并更新 updatedAt

### 4.3 快捷操作
- 置顶 / 取消置顶
- 删除笔记
- 编辑 / 完成编辑切换

## 5. 新建笔记流程
- 点击“新建笔记”
- 进入创建页覆盖层
- 默认值
  - 标题：未命名笔记
  - 分类：默认分类
  - 标签：新建
- 创建成功后
  - 进入新笔记
  - 同步预览和图谱

## 6. 双向链接与反链
- 正文内解析 [[link]]
- 生成图谱边关系
- 反向链接列表展示

## 7. 图谱交互
- 节点：笔记标题
- 边：基于双向链接关系
- 交互
  - 拖拽节点
  - 画布平移
  - 缩放
  - 聚焦某一笔记
  - 一键取消聚焦
- 物理引擎
  - 斥力 + 弹簧 + 阻尼

## 8. 搜索增强细则
- 匹配机制
  - 直接包含优先
  - 去空格包含
  - 子序列匹配
- 评分权重
  - 标题 x5
  - 分类 x3
  - 标签 x2
  - 正文 x1
- 高亮
  - 标题 / 分类 / 摘要 / 标签命中

## 9. Markdown 扩展
- 代码块
  - ``` 代码段 ```
- 任务列表
  - - [ ] 未完成
  - - [x] 已完成
- 表格
  - | A | B |
  - | --- | --- |
- 图片
  - ![alt](url)

## 10. 边界与异常处理
- 无笔记时显示空态提示
- 删除最后一条笔记后清空 active 状态
- 解析存储失败则安全回退
- 链接指向不存在笔记自动创建

## 11. 主要状态变量一览
- activeNoteId / isNoteEditing / showPreview
- activeCategory / activeTag / sortMode
- libraryControlMode
- graphZoom / graphFocusedNoteId / graphPanOffset
- previewBodySnapshot

## 12. 当前已完成能力（按维度）
### 用户界面/交互
- 三栏布局（笔记库/笔记详情/图谱）与紧凑模式下的面板切换
- 顶部导航与“新建笔记”入口，创建页覆盖层流程
- 笔记库搜索框与“分类/标签/排序/最近”模式切换及二级按钮
- 笔记详情的浏览/编辑切换与置顶/删除快捷操作
- 图谱画布支持缩放、平移、节点拖拽、聚焦与取消聚焦
- Markdown 预览支持代码块/表格/任务/图片与链接点击跳转

### 核心业务逻辑（如笔记编辑）
- 笔记创建、编辑、删除、置顶与更新时间同步
- 分类/标签过滤与排序（更新/标题/分类/最近访问）
- 搜索增强：相关性评分、模糊匹配、命中高亮
- 最近访问记录与快速入口
- 双向链接解析、反向链接展示、缺失笔记自动创建
- 图谱边生成与力导布局同步

### 数据存储
- AppStorage + PersistentStorage 持久化 notes JSON
- 启动加载、解析校验、失败回退样例数据
- 旧数据迁移：补齐 category/isPinned/createdAt/lastVisitedAt
- 修改即保存并触发图谱更新
