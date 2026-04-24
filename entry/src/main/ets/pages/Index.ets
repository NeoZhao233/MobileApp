import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import common from '@ohos.app.ability.common';
import { Want } from '@kit.AbilityKit';
import rdb from '@ohos.data.rdb';
import fs from '@ohos.file.fs';
import util from '@ohos.util';

type CompactPanel = 'library' | 'graph';
type NoteSortMode = 'updated' | 'title' | 'category' | 'recent';
type LibraryControlMode = 'category' | 'tag' | 'sort';

interface SortOption {
  label: string;
  value: NoteSortMode;
}

const NOTES_STORAGE_KEY: string = 'obsidian_lite_notes_json';
const NOTES_META_KEY: string = 'obsidian_lite_notes_meta_json';
const NOTE_BODY_PREFIX: string = 'obsidian_lite_note_body_';
const NOTES_DB_NAME: string = 'obsidian_lite.db';
const NOTES_DB_VERSION: number = 2;
const NOTES_TABLE: string = 'notes';
const VAULTS_TABLE: string = 'vaults';
const NOTE_BODY_DIR: string = 'note_bodies';
const FAB_SIZE: number = 50;
const FAB_MARGIN_RIGHT: number = 20;
const FAB_MARGIN_BOTTOM: number = 28;

type InlineTokenKind = 'text' | 'bold' | 'code' | 'link';

type LengthValue = string | number | Resource;

interface Vault {
  id: string;
  name: string;
  description: string;
  color: string;
  createdAt: string;
  updatedAt: string;
}

const VAULTS_STORAGE_KEY = '@obsidian_lite_vaults';

const SAMPLE_VAULTS: Vault[] = [
  {
    id: 'vault-demo',
    name: '默认知识库',
    description: '你的第一个本地知识库，记录灵感与思考',
    color: '#1B6EF3', // THEME.primary
    createdAt: '2026-04-19',
    updatedAt: '2026-04-19'
  }
];

interface InlineToken {
  kind: InlineTokenKind;
  text: string;
}

interface Note {
  id: string;
  vaultId: string;
  title: string;
  category: string;
  body: string;
  bodyLoaded: boolean;
  tags: string[];
  isPinned: boolean;
  createdAt: string;
  lastVisitedAt: string;
  updatedAt: string;
}

interface NoteMeta {
  id: string;
  vaultId: string;
  title: string;
  category: string;
  tags: string[];
  isPinned: boolean;
  createdAt: string;
  lastVisitedAt: string;
  updatedAt: string;
  bodyLoaded?: boolean;
}

interface GraphEdge {
  fromId: string;
  fromTitle: string;
  toId?: string;
  toTitle: string;
}

interface GraphNodePoint {
  x: number;
  y: number;
}

interface PanelSize {
  width: number;
  height: number;
}

interface GraphPhysicsNode {
  x: number;
  y: number;
  vx: number;
  vy: number;
}

type MarkdownBlockType = 'line' | 'code' | 'table';

interface MarkdownBlock {
  type: MarkdownBlockType;
  text: string;
  lines: string[];
}

interface OutlineItem {
  level: number;
  title: string;
  lineIndex: number;
}

interface SearchRankItem {
  note: Note;
  score: number;
}

interface HighlightSegment {
  text: string;
  hit: boolean;
}

interface PdfPageData {
  titleLines: string[];
  bodyLines: string[];
}

interface ShadowToken {
  radius: number;
  color: string;
  offsetX: number;
  offsetY: number;
}

interface ThemeTokens {
  primary: string;
  onPrimary: string;
  primaryContainer: string;
  onPrimaryContainer: string;
  secondary: string;
  onSecondary: string;
  surface: string;
  surfaceVariant: string;
  error: string;
  errorContainer: string;
  onErrorContainer: string;
  outline: string;
  canvas: string;
  canvasTint: string;
  ink: string;
  inkMuted: string;
  accent: string;
  accentDeep: string;
  accentSoft: string;
  card: string;
  cardAlt: string;
  border: string;
  fontTitle: string;
  fontBody: string;
  radiusLarge: number;
  radiusMedium: number;
  radiusSmall: number;
  elevation1: ShadowToken;
  elevation2: ShadowToken;
  elevation3: ShadowToken;
}

const THEME: ThemeTokens = {
  primary: '#1B6EF3',
  onPrimary: '#FFFFFF',
  primaryContainer: '#D7E3FF',
  onPrimaryContainer: '#001B3D',
  secondary: '#5A6B8C',
  onSecondary: '#FFFFFF',
  surface: '#FFFFFF',
  surfaceVariant: '#F1F3F7',
  error: '#B3261E',
  errorContainer: '#F9DEDC',
  onErrorContainer: '#410E0B',
  outline: '#E0E0E0',
  canvas: '#F5F6FA',
  canvasTint: '#E7ECF5',
  ink: '#1A1C1E',
  inkMuted: '#4B4F56',
  accent: '#1B6EF3',
  accentDeep: '#1759C7',
  accentSoft: '#D7E3FF',
  card: '#FFFFFF',
  cardAlt: '#F1F3F7',
  border: '#E0E0E0',
  fontTitle: 'Google Sans',
  fontBody: 'HarmonyOS Sans',
  radiusLarge: 24,
  radiusMedium: 16,
  radiusSmall: 12,
  elevation1: { radius: 6, color: '#1A000000', offsetX: 0, offsetY: 2 },
  elevation2: { radius: 10, color: '#1E000000', offsetX: 0, offsetY: 4 },
  elevation3: { radius: 16, color: '#26000000', offsetX: 0, offsetY: 6 }
};

const SAMPLE_NOTES: Note[] = [
  {
    id: 'n1',
    vaultId: 'vault-demo',
    title: '欢迎来到轻量笔记',
    category: '快速入门',
    body: '# 你好，Obsidian Lite\n\n- 这是一个原型演示\n- 支持 **加粗** 与 `代码`\n- 试试 [[双向链接]] 与 [[标签系统]]\n\n> 记得保持专注与轻盈。\n',
    bodyLoaded: true,
    tags: ['入门', '体验'],
    isPinned: true,
    createdAt: '2026-04-19',
    lastVisitedAt: '2026-04-20',
    updatedAt: '2026-04-19'
  },
  {
    id: 'n2',
    vaultId: 'vault-demo',
    title: '标签系统',
    category: '知识管理',
    body: '## 标签是知识的抽屉\n\n- 标签帮助快速分类\n- 点击标签可筛选\n\n和 [[搜索技巧]] 配合更高效。',
    bodyLoaded: true,
    tags: ['方法', '系统'],
    isPinned: false,
    createdAt: '2026-04-18',
    lastVisitedAt: '2026-04-19',
    updatedAt: '2026-04-18'
  },
  {
    id: 'n3',
    vaultId: 'vault-demo',
    title: '双向链接',
    category: '知识管理',
    body: '## 让笔记彼此对话\n\n把相关概念连在一起：\n- [[标签系统]]\n- [[项目仪表盘]]\n\n> 反向链接会自动出现。',
    bodyLoaded: true,
    tags: ['知识网络'],
    isPinned: false,
    createdAt: '2026-04-18',
    lastVisitedAt: '2026-04-18',
    updatedAt: '2026-04-18'
  },
  {
    id: 'n4',
    vaultId: 'vault-demo',
    title: '搜索技巧',
    category: '知识管理',
    body: '### 全文搜索\n\n你可以搜索标题、正文与标签。\n\n试试搜索 **系统** 或 `链接`。',
    bodyLoaded: true,
    tags: ['方法'],
    isPinned: false,
    createdAt: '2026-04-17',
    lastVisitedAt: '2026-04-18',
    updatedAt: '2026-04-17'
  },
  {
    id: 'n5',
    vaultId: 'vault-demo',
    title: '项目仪表盘',
    category: '工作项目',
    body: '# 项目\n\n- 本周目标\n- 重要里程碑\n- 风险与阻塞\n\n相关笔记：[[双向链接]]',
    bodyLoaded: true,
    tags: ['项目', '看板'],
    isPinned: false,
    createdAt: '2026-04-17',
    lastVisitedAt: '2026-04-17',
    updatedAt: '2026-04-17'
  },
  {
    id: 'n6',
    vaultId: 'vault-demo',
    title: '每日回顾',
    category: '日常记录',
    body: '## 今日小结\n\n- 做得好的事\n- 想要改进的点\n- 明日计划\n\n连接到 [[项目仪表盘]]。',
    bodyLoaded: true,
    tags: ['复盘', '习惯'],
    isPinned: false,
    createdAt: '2026-04-16',
    lastVisitedAt: '2026-04-16',
    updatedAt: '2026-04-16'
  }
];

const SORT_OPTIONS: SortOption[] = [
  { label: '按更新', value: 'updated' },
  { label: '按标题', value: 'title' },
  { label: '按分类', value: 'category' },
  { label: '按最近访问', value: 'recent' }
];

@Entry
@Component
struct Index {
  @State vaults: Vault[] = [];
  @State activeVaultId: string = '';
  @State notes: Note[] = SAMPLE_NOTES;
  @Watch('onActiveNoteIdChanged')
  @State activeNoteId: string = SAMPLE_NOTES[0].id;
  @State searchText: string = '';
  @State searchInBody: boolean = true;
  @State activeTag: string = '';
  @State activeCategory: string = '';
  @State sortMode: NoteSortMode = 'updated';
  @State libraryControlMode: LibraryControlMode = 'category';
  @State showAllLibraryChoices: boolean = false;
  @State showPreview: boolean = true;
  @State isCompact: boolean = true;
  @State compactPanel: CompactPanel = 'library';
  @State newTagText: string = '';
  @State showCreateNotePage: boolean = false;
  @State showVaultEditorPage: boolean = false;
  @State editingVaultId: string = '';
  @State draftVaultName: string = '';
  @State draftVaultDescription: string = '';
  @State draftTitle: string = '';
  @State draftCategory: string = '默认分类';
  @State draftBody: string = '';
  @State draftTagsText: string = '';
  @State isNoteEditing: boolean = false;
  @State showSelectedNoteInCompact: boolean = false;
  @State previewBodySnapshot: string = SAMPLE_NOTES[0].body;
  @State outlineTargetLine: number = -1;
  @State graphZoom: number = 1;
  @State graphFocusedNoteId: string = '';
  @State graphNodePositions: Record<string, GraphNodePoint> = {};
  @State graphPanBase: GraphNodePoint = { x: -600, y: -600 };
  @State graphPanOffset: GraphNodePoint = { x: 0, y: 0 };
  @State draggingNodeId: string = '';
  @State draggingNodeOffset: GraphNodePoint = { x: 0, y: 0 };
  @State isDraggingNode: boolean = false;
  private physicsNodes: Record<string, GraphPhysicsNode> = {};
  private physicsTimer: number = -1;
  private physicsAlpha: number = 0;
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private dragLastOffsetX: number = 0;
  private dragLastOffsetY: number = 0;
  private previewScroller: Scroller = new Scroller();
  private libraryScroller: Scroller = new Scroller();
  private saveTimer: number = -1;
  private bodySaveTimer: number = -1;
  private pendingBodySaveId: string = '';
  private pendingBodySaveText: string = '';
  private rdbStore: rdb.RdbStore | undefined = undefined;
  private bodyDir: string = '';

  async aboutToAppear(): Promise<void> {
    this.initializeNotesStorage();
    await this.ensureDatabaseReady();
    await this.loadVaultsFromDatabase();
    await this.loadNotesFromStorage();
  }

  private startPhysics(): void {
    if (this.physicsTimer !== -1) {
      clearInterval(this.physicsTimer);
    }
    this.physicsAlpha = 1;
    this.physicsTimer = setInterval(() => {
      this.physicsTick();
    }, 16);
  }

  private wakePhysics(): void {
    if (this.physicsTimer === -1 || this.physicsAlpha < 0.1) {
      this.startPhysics();
    } else {
      this.physicsAlpha = 1;
    }
  }

  private physicsTick(): void {
    if (this.physicsAlpha < 0.001) {
      clearInterval(this.physicsTimer);
      this.physicsTimer = -1;
      return;
    }

    let totalVelocity = 0;
    const edges = this.getGraphEdges();
    const currentNotes = this.getFilteredNotes();

    currentNotes.forEach(n1 => {
      currentNotes.forEach(n2 => {
        if (n1.id === n2.id || n1.id > n2.id) {
          return;
        }
        const p1 = this.physicsNodes[n1.id];
        const p2 = this.physicsNodes[n2.id];
        if (!p1 || !p2) return;

        const dx = p1.x - p2.x;
        const dy = p1.y - p2.y;
        let d = Math.sqrt(dx * dx + dy * dy);
        if (d === 0) { d = 0.1; }
        
        if (d < 500) {
          const force = 4000 / (d * d);
          p1.vx += (dx / d) * force * this.physicsAlpha;
          p1.vy += (dy / d) * force * this.physicsAlpha;
          p2.vx -= (dx / d) * force * this.physicsAlpha;
          p2.vy -= (dy / d) * force * this.physicsAlpha;
        }

        const minDistance = 48;
        if (d < minDistance) {
          const overlap = minDistance - d;
          const nx = dx / d;
          const ny = dy / d;
          if (this.draggingNodeId === n1.id) {
            p2.x -= nx * overlap;
            p2.y -= ny * overlap;
          } else if (this.draggingNodeId === n2.id) {
            p1.x += nx * overlap;
            p1.y += ny * overlap;
          } else {
            p1.x += nx * overlap * 0.5;
            p1.y += ny * overlap * 0.5;
            p2.x -= nx * overlap * 0.5;
            p2.y -= ny * overlap * 0.5;
          }
        }
      });
    });

    edges.forEach(edge => {
      const p1 = this.physicsNodes[edge.fromId];
      const p2 = this.physicsNodes[edge.toId || ''];
      if (!p1 || !p2) {
        return;
      }
      const dx = p2.x - p1.x;
      const dy = p2.y - p1.y;
      let d = Math.sqrt(dx * dx + dy * dy);
      if (d === 0) { d = 0.1; }
      
      const force = (d - 120) * 0.05;
      p1.vx += (dx / d) * force * this.physicsAlpha;
      p1.vy += (dy / d) * force * this.physicsAlpha;
      p2.vx -= (dx / d) * force * this.physicsAlpha;
      p2.vy -= (dy / d) * force * this.physicsAlpha;
    });

    currentNotes.forEach(n1 => {
      const p1 = this.physicsNodes[n1.id];
      if (!p1) return;

      const dx = 1000 - p1.x;
      const dy = 1000 - p1.y;
      let d = Math.sqrt(dx * dx + dy * dy);
      if (d === 0) { d = 0.1; }
      
      p1.vx += (dx / d) * (d * 0.005) * this.physicsAlpha;
      p1.vy += (dy / d) * (d * 0.005) * this.physicsAlpha;

      if (this.draggingNodeId === n1.id) {
        p1.vx = 0;
        p1.vy = 0;
      } else {
        p1.vx *= 0.85;
        p1.vy *= 0.85;
        p1.x += p1.vx;
        p1.y += p1.vy;
      }

      totalVelocity += Math.abs(p1.vx) + Math.abs(p1.vy);
    });

    this.physicsAlpha *= 0.98;

    const nextPos: Record<string, GraphNodePoint> = {};
    const keys = Object.keys(this.physicsNodes);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      const nd = this.physicsNodes[k];
      nextPos[k] = { x: nd.x, y: nd.y };
    }
    this.graphNodePositions = nextPos;
  }

  private initForceDirectedLayout(): void {
    const currentNotes = this.getFilteredNotes();
    const visibleIds = new Set<string>();
    currentNotes.forEach(note => visibleIds.add(note.id));

    if (this.graphFocusedNoteId.length > 0 && !visibleIds.has(this.graphFocusedNoteId)) {
      this.graphFocusedNoteId = '';
    }

    const nextPhysics: Record<string, GraphPhysicsNode> = {};
    Object.keys(this.physicsNodes).forEach((id: string) => {
      if (visibleIds.has(id)) {
        nextPhysics[id] = this.physicsNodes[id];
      }
    });
    this.physicsNodes = nextPhysics;

    const nextPos: Record<string, GraphNodePoint> = {};
    Object.keys(this.graphNodePositions).forEach((id: string) => {
      if (visibleIds.has(id)) {
        nextPos[id] = this.graphNodePositions[id];
      }
    });
    this.graphNodePositions = nextPos;

    if (currentNotes.length === 0) {
      if (this.physicsTimer !== -1) {
        clearInterval(this.physicsTimer);
        this.physicsTimer = -1;
      }
      this.physicsAlpha = 0;
      return;
    }

    currentNotes.forEach(n => {
      if (!this.physicsNodes[n.id]) {
        this.physicsNodes[n.id] = {
          x: 1000 + (Math.random() * 400 - 200),
          y: 1000 + (Math.random() * 400 - 200),
          vx: 0,
          vy: 0
        };
      }
    });

    this.startPhysics();
  }

  private getNodePos(nodeId: string): GraphNodePoint {
    const p = this.graphNodePositions[nodeId];
    if (!p) {
      return { x: 1000, y: 1000 };
    }
    return p;
  }

  private getNodeDegree(nodeId: string): number {
    let degree = 0;
    const edges = this.getGraphEdges();
    edges.forEach(e => {
      if (e.fromId === nodeId || e.toId === nodeId) {
        degree++;
      }
    });
    return degree;
  }

  private initializeNotesStorage(): void {
    PersistentStorage.PersistProp(NOTES_META_KEY, '');
    PersistentStorage.PersistProp(NOTES_STORAGE_KEY, JSON.stringify(SAMPLE_NOTES));
  }

  private async loadNotesFromStorage(): Promise<void> {
    const notesFromDb = await this.loadNotesFromDatabase();
    if (notesFromDb.length > 0) {
      this.notes = notesFromDb;
      const exists = notesFromDb.some(note => note.id === this.activeNoteId);
      this.activeNoteId = exists ? this.activeNoteId : notesFromDb[0].id;
      this.ensureNoteBodyLoaded(this.activeNoteId);
      this.syncPreviewSnapshotFromActive();
      this.initForceDirectedLayout();
      return;
    }

    const stored = AppStorage.Get<string>(NOTES_STORAGE_KEY);
    if (!stored) {
      return;
    }
    if (stored.trim().length === 0) {
      return;
    }
    const parsed = this.parseStoredNotes(stored);
    if (parsed.length === 0) {
      return;
    }
    await this.persistNotesToDatabase(parsed);
    this.notes = parsed;
    const exists = parsed.some(note => note.id === this.activeNoteId);
    this.activeNoteId = exists ? this.activeNoteId : parsed[0].id;
    this.syncPreviewSnapshotFromActive();
    this.initForceDirectedLayout();
  }

  private async ensureDatabaseReady(): Promise<void> {
    await this.ensureBodyDir();
    const store = await this.getRdbStore();
    const sql = `CREATE TABLE IF NOT EXISTS ${NOTES_TABLE} (
      id TEXT PRIMARY KEY,
      vaultId TEXT,
      title TEXT,
      category TEXT,
      tags TEXT,
      isPinned INTEGER,
      createdAt TEXT,
      lastVisitedAt TEXT,
      updatedAt TEXT,
      preview TEXT
    )`;
    await store.executeSql(sql);

    const vaultSql = `CREATE TABLE IF NOT EXISTS ${VAULTS_TABLE} (
      id TEXT PRIMARY KEY,
      name TEXT,
      description TEXT,
      color TEXT,
      createdAt TEXT,
      updatedAt TEXT
    )`;
    await store.executeSql(vaultSql);
  }

  private async getRdbStore(): Promise<rdb.RdbStore> {
    if (this.rdbStore) {
      return this.rdbStore;
    }
    const context = getContext(this) as common.UIAbilityContext;
    const config: rdb.StoreConfig = {
      name: NOTES_DB_NAME
    };
    const store = await rdb.getRdbStore(context, config, NOTES_DB_VERSION);
    this.rdbStore = store;
    return store;
  }

  private async ensureBodyDir(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const dir = `${context.filesDir}/${NOTE_BODY_DIR}`;
    this.bodyDir = dir;
    try {
      fs.mkdirSync(dir);
    } catch {
      return;
    }
  }

  private async loadVaultsFromDatabase(): Promise<void> {
    const store = await this.getRdbStore();
    const resultSet = await store.querySql(
      `SELECT id, name, description, color, createdAt, updatedAt FROM ${VAULTS_TABLE}`
    );
    const loadedVaults: Vault[] = [];
    while (resultSet.goToNextRow()) {
      loadedVaults.push({
        id: resultSet.getString(0),
        name: resultSet.getString(1),
        description: resultSet.getString(2),
        color: resultSet.getString(3),
        createdAt: resultSet.getString(4),
        updatedAt: resultSet.getString(5)
      });
    }
    resultSet.close();

    if (loadedVaults.length === 0) {
      this.vaults = SAMPLE_VAULTS;
      for (const vault of this.vaults) {
        await store.insert(VAULTS_TABLE, {
          id: vault.id,
          name: vault.name,
          description: vault.description,
          color: vault.color,
          createdAt: vault.createdAt,
          updatedAt: vault.updatedAt
        });
      }
    } else {
      this.vaults = loadedVaults;
    }
  }

  private async loadNotesFromDatabase(): Promise<Note[]> {
    const store = await this.getRdbStore();
    const resultSet = await store.querySql(
      `SELECT id, vaultId, title, category, tags, isPinned, createdAt, lastVisitedAt, updatedAt, preview FROM ${NOTES_TABLE}`
    );
    const notes: Note[] = [];
    while (resultSet.goToNextRow()) {
      const id = resultSet.getString(0);
      const vaultId = resultSet.getString(1);
      const title = resultSet.getString(2);
      const category = resultSet.getString(3);
      const tagsRaw = resultSet.getString(4);
      const isPinned = resultSet.getLong(5) === 1;
      const createdAt = resultSet.getString(6);
      const lastVisitedAt = resultSet.getString(7);
      const updatedAt = resultSet.getString(8);
      const preview = resultSet.getString(9);
      notes.push({
        id,
        vaultId: vaultId || 'vault-demo',
        title,
        category,
        body: preview,
        bodyLoaded: false,
        tags: this.parseTagsFromDb(tagsRaw),
        isPinned,
        createdAt,
        lastVisitedAt,
        updatedAt
      });
    }
    resultSet.close();
    return notes;
  }

  private ensureNoteBodyLoaded(noteId: string): void {
    const index = this.notes.findIndex(note => note.id === noteId);
    if (index < 0) {
      return;
    }
    const base = this.notes[index];
    if (base.bodyLoaded) {
      return;
    }
    const body = this.loadNoteBody(noteId);
    const updated: Note = {
      id: base.id,
      vaultId: base.vaultId,
      title: base.title,
      category: base.category,
      body,
      bodyLoaded: true,
      tags: base.tags,
      isPinned: base.isPinned,
      createdAt: base.createdAt,
      lastVisitedAt: base.lastVisitedAt,
      updatedAt: base.updatedAt
    };
    const next = this.notes.slice();
    next[index] = updated;
    this.notes = next;
  }

  private async saveNotesToStorage(): Promise<void> {
    await this.saveNotesMetaToStorage();
  }

  private scheduleNotesSave(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveNotesToStorage();
      this.saveTimer = -1;
    }, 600);
  }

  private scheduleNoteBodySave(noteId: string, body: string): void {
    this.pendingBodySaveId = noteId;
    this.pendingBodySaveText = body;
    if (this.bodySaveTimer !== -1) {
      clearTimeout(this.bodySaveTimer);
    }
    this.bodySaveTimer = setTimeout(() => {
      if (this.pendingBodySaveId.length > 0) {
        this.saveNoteBody(this.pendingBodySaveId, this.pendingBodySaveText);
      }
      this.bodySaveTimer = -1;
    }, 600);
  }

  private getNoteBodyKey(noteId: string): string {
    return `${NOTE_BODY_PREFIX}${noteId}.md`;
  }

  private getBodyPath(noteId: string): string {
    return `${this.bodyDir}/${this.getNoteBodyKey(noteId)}`;
  }

  private saveNoteBody(noteId: string, body: string): void {
    if (this.bodyDir.length === 0) {
      return;
    }
    const path = this.getBodyPath(noteId);
    try {
      const file: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      const data: Uint8Array = new util.TextEncoder().encode(body);
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file);
    } catch {
      return;
    }
  }

  private loadNoteBody(noteId: string): string {
    if (this.bodyDir.length === 0) {
      return '';
    }
    const path = this.getBodyPath(noteId);
    try {
      const stat: fs.Stat = fs.statSync(path);
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      return new util.TextDecoder().decode(new Uint8Array(buffer));
    } catch {
      return '';
    }
  }

  private deleteNoteBody(noteId: string): void {
    if (this.bodyDir.length === 0) {
      return;
    }
    const path = this.getBodyPath(noteId);
    try {
      fs.unlinkSync(path);
    } catch {
      return;
    }
  }

  private sanitizePdfFileName(raw: string): string {
    return raw.replace(/[\\/:*?"<>|]/g, '_').trim();
  }

  private wrapPdfText(text: string, maxChars: number): string[] {
    const lines: string[] = [];
    const rawLines = text.replace(/\t/g, '    ').split(/\r?\n/);
    rawLines.forEach(line => {
      const chars = Array.from(line);
      if (chars.length === 0) {
        lines.push('');
        return;
      }
      for (let i = 0; i < chars.length; i += maxChars) {
        lines.push(chars.slice(i, i + maxChars).join(''));
      }
    });
    return lines;
  }

  private toUtf16BeHex(text: string): string {
    let hex = 'FEFF';
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i);
      hex += code.toString(16).padStart(4, '0').toUpperCase();
    }
    return hex;
  }

  private buildPdfPageContent(titleLines: string[], bodyLines: string[], pageIndex: number, pageCount: number, dateText: string): string {
    const parts: string[] = [];
    const headerX = 72;
    const headerY = 812;
    const footerX = 260;
    const footerY = 40;
    const contentX = 72;
    const contentTopY = 760;
    const pageLabel = `第 ${pageIndex + 1} / ${pageCount} 页`;
    parts.push('BT');
    parts.push('/F1 10 Tf');
    parts.push(`${headerX} ${headerY} Td`);
    parts.push(`<${this.toUtf16BeHex(dateText)}> Tj`);
    parts.push('ET');
    parts.push('BT');
    parts.push('/F1 10 Tf');
    parts.push(`${footerX} ${footerY} Td`);
    parts.push(`<${this.toUtf16BeHex(pageLabel)}> Tj`);
    parts.push('ET');
    parts.push('BT');
    if (titleLines.length > 0) {
      parts.push('/F1 18 Tf');
      parts.push(`${contentX} ${contentTopY} Td`);
      parts.push('22 TL');
      titleLines.forEach((line, index) => {
        parts.push(`<${this.toUtf16BeHex(line)}> Tj`);
        if (index < titleLines.length - 1) {
          parts.push('T*');
        }
      });
      if (bodyLines.length > 0) {
        parts.push('T*');
        parts.push('/F1 12 Tf');
        parts.push('16 TL');
        bodyLines.forEach(line => {
          parts.push(`<${this.toUtf16BeHex(line)}> Tj`);
          parts.push('T*');
        });
      }
    } else {
      parts.push('/F1 12 Tf');
      parts.push(`${contentX} ${contentTopY} Td`);
      parts.push('16 TL');
      bodyLines.forEach(line => {
        parts.push(`<${this.toUtf16BeHex(line)}> Tj`);
        parts.push('T*');
      });
    }
    parts.push('ET');
    return `${parts.join('\n')}\n`;
  }

  private buildPdfPagePlan(note: Note): PdfPageData[] {
    const titleLines = this.wrapPdfText(note.title, 20);
    const bodyLines = this.wrapPdfText(note.body, 42);
    const topY = 760;
    const bottomY = 80;
    const titleLineHeight = 22;
    const bodyLineHeight = 16;
    const available = topY - bottomY;
    const pages: PdfPageData[] = [];
    let titleIndex = 0;
    let bodyIndex = 0;
    while (titleIndex < titleLines.length || bodyIndex < bodyLines.length || pages.length === 0) {
      let remaining = available;
      const pageTitle: string[] = [];
      const pageBody: string[] = [];
      while (titleIndex < titleLines.length && remaining >= titleLineHeight) {
        pageTitle.push(titleLines[titleIndex]);
        titleIndex += 1;
        remaining -= titleLineHeight;
      }
      if (titleIndex >= titleLines.length && bodyIndex < bodyLines.length) {
        if (pageTitle.length > 0 && remaining >= bodyLineHeight) {
          pageBody.push('');
          remaining -= bodyLineHeight;
        }
        while (bodyIndex < bodyLines.length && remaining >= bodyLineHeight) {
          pageBody.push(bodyLines[bodyIndex]);
          bodyIndex += 1;
          remaining -= bodyLineHeight;
        }
      }
      if (pageTitle.length === 0 && pageBody.length === 0) {
        break;
      }
      pages.push({ titleLines: pageTitle, bodyLines: pageBody });
    }
    return pages;
  }

  private buildPdfPages(note: Note): string[] {
    const plan = this.buildPdfPagePlan(note);
    const pageCount = plan.length > 0 ? plan.length : 1;
    const dateText = this.formatDate(new Date());
    return plan.map((page, index) => this.buildPdfPageContent(page.titleLines, page.bodyLines, index, pageCount, dateText));
  }

  private buildPdfBytes(note: Note): Uint8Array {
    const encoder = new util.TextEncoder();
    const pages = this.buildPdfPages(note);
    const pageCount = pages.length > 0 ? pages.length : 1;
    const pageStartId = 3;
    const fontObjId = pageStartId + pageCount;
    const descendantObjId = fontObjId + 1;
    const contentStartId = descendantObjId + 1;
    const kids = pages.map((_, index) => `${pageStartId + index} 0 R`).join(' ');
    const objects: string[] = [];
    objects.push('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
    objects.push(`2 0 obj\n<< /Type /Pages /Kids [${kids}] /Count ${pageCount} >>\nendobj\n`);
    pages.forEach((_, index) => {
      const pageObjId = pageStartId + index;
      const contentObjId = contentStartId + index;
      objects.push(`${pageObjId} 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 ${fontObjId} 0 R >> >> /Contents ${contentObjId} 0 R >>\nendobj\n`);
    });
    objects.push(`${fontObjId} 0 obj\n<< /Type /Font /Subtype /Type0 /BaseFont /STSong-Light /Encoding /UniGB-UCS2-H /DescendantFonts [${descendantObjId} 0 R] >>\nendobj\n`);
    objects.push(`${descendantObjId} 0 obj\n<< /Type /Font /Subtype /CIDFontType0 /BaseFont /STSong-Light /CIDSystemInfo << /Registry (Adobe) /Ordering (GB1) /Supplement 5 >> >>\nendobj\n`);
    pages.forEach((content, index) => {
      const contentObjId = contentStartId + index;
      const contentLength = encoder.encode(content).length;
      objects.push(`${contentObjId} 0 obj\n<< /Length ${contentLength} >>\nstream\n${content}endstream\nendobj\n`);
    });
    const header = '%PDF-1.4\n';
    let offset = encoder.encode(header).length;
    const offsets: number[] = [];
    objects.forEach(obj => {
      offsets.push(offset);
      offset += encoder.encode(obj).length;
    });
    const startXref = offset;
    const xrefLines: string[] = [];
    xrefLines.push('xref');
    xrefLines.push(`0 ${offsets.length + 1}`);
    xrefLines.push('0000000000 65535 f ');
    offsets.forEach(pos => {
      xrefLines.push(`${pos.toString().padStart(10, '0')} 00000 n `);
    });
    const xref = `${xrefLines.join('\n')}\n`;
    const trailer = `trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n${startXref}\n%%EOF\n`;
    const pdf = header + objects.join('') + xref + trailer;
    return encoder.encode(pdf);
  }

  private saveNotePdf(note: Note): string {
    const context = getContext(this) as common.UIAbilityContext;
    const safeTitle = this.sanitizePdfFileName(note.title);
    const baseName = safeTitle.length > 0 ? safeTitle : `note-${note.id}`;
    const filePath = `${context.cacheDir}/${baseName}.pdf`;
    try {
      const file: fs.File = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      const data = this.buildPdfBytes(note);
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file);
      return filePath;
    } catch {
      return '';
    }
  }

  private shareActiveNoteAsPdf(): void {
    const active = this.getActiveNote();
    if (!active) {
      return;
    }
    if (!active.bodyLoaded) {
      this.ensureNoteBodyLoaded(active.id);
    }
    const note = this.getActiveNote();
    if (!note) {
      return;
    }
    const filePath = this.saveNotePdf(note);
    if (filePath.length === 0) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.sendData',
      type: 'application/pdf',
      uri: `file://${filePath}`
    };
    context.startAbility(want).catch(() => {
      return;
    });
  }

  private toNoteMeta(note: Note): NoteMeta {
    return {
      id: note.id,
      vaultId: note.vaultId,
      title: note.title,
      category: note.category,
      tags: note.tags,
      isPinned: note.isPinned,
      createdAt: note.createdAt,
      lastVisitedAt: note.lastVisitedAt,
      updatedAt: note.updatedAt
    };
  }

  private serializeTags(tags: string[]): string {
    return JSON.stringify(tags);
  }

  private parseTagsFromDb(raw: string): string[] {
    try {
      const parsed: string[] = JSON.parse(raw) as string[];
      return Array.isArray(parsed) ? parsed.filter(item => typeof item === 'string') : [];
    } catch {
      return [];
    }
  }

  private async saveNotesMetaToStorage(): Promise<void> {
    const store = await this.getRdbStore();
    await store.executeSql(`DELETE FROM ${NOTES_TABLE}`);
    for (let i = 0; i < this.notes.length; i++) {
      const note = this.notes[i];
      const preview = this.getExcerpt(note.body);
      await store.executeSql(
        `INSERT OR REPLACE INTO ${NOTES_TABLE} (id, vaultId, title, category, tags, isPinned, createdAt, lastVisitedAt, updatedAt, preview) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
        , [
          note.id,
          note.vaultId || 'vault-demo',
          note.title,
          note.category,
          this.serializeTags(note.tags),
          note.isPinned ? 1 : 0,
          note.createdAt,
          note.lastVisitedAt,
          note.updatedAt,
          preview
        ]
      );
    }
  }

  private async persistNotesToDatabase(notes: Note[]): Promise<void> {
    notes.forEach(note => {
      this.saveNoteBody(note.id, note.body);
    });
    this.notes = notes;
    await this.saveNotesMetaToStorage();
  }

  private parseStoredNoteMeta(raw: string): NoteMeta[] {
    try {
      const parsed = JSON.parse(raw) as NoteMeta[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed.map(item => {
        if (typeof item.category !== 'string' || item.category.trim().length === 0) {
          item.category = '默认分类';
        }
        if (typeof item.bodyLoaded !== 'boolean') {
          item.bodyLoaded = true;
        }
        if (typeof item.isPinned !== 'boolean') {
          item.isPinned = false;
        }
        if (typeof item.createdAt !== 'string' || item.createdAt.trim().length === 0) {
          item.createdAt = typeof item.updatedAt === 'string' ? item.updatedAt : this.formatDate(new Date());
        }
        if (typeof item.lastVisitedAt !== 'string' || item.lastVisitedAt.trim().length === 0) {
          item.lastVisitedAt = typeof item.updatedAt === 'string' ? item.updatedAt : item.createdAt;
        }
        if (!Array.isArray(item.tags)) {
          item.tags = [];
        }
        return item;
      }).filter(item => this.isValidNoteMeta(item));
    } catch {
      return [];
    }
  }

  private buildNoteFromMeta(meta: NoteMeta, body: string): Note {
    const note: Note = {
      id: meta.id,
      vaultId: meta.vaultId || 'vault-demo',
      title: meta.title,
      category: meta.category,
      body,
      bodyLoaded: true,
      tags: meta.tags,
      isPinned: meta.isPinned,
      createdAt: meta.createdAt,
      lastVisitedAt: meta.lastVisitedAt,
      updatedAt: meta.updatedAt
    };
    return note;
  }

  private isValidNoteMeta(meta: NoteMeta): boolean {
    return typeof meta.id === 'string'
      && typeof meta.title === 'string'
      && typeof meta.category === 'string'
      && Array.isArray(meta.tags)
      && typeof meta.isPinned === 'boolean'
      && typeof meta.createdAt === 'string'
      && typeof meta.lastVisitedAt === 'string'
      && typeof meta.updatedAt === 'string';
  }

  private parseStoredNotes(raw: string): Note[] {
    try {
      const parsed = JSON.parse(raw) as Note[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed.map(item => {
        if (typeof item.category !== 'string' || item.category.trim().length === 0) {
          item.category = '默认分类';
        }
        if (typeof item.isPinned !== 'boolean') {
          item.isPinned = false;
        }
        if (typeof item.createdAt !== 'string' || item.createdAt.trim().length === 0) {
          item.createdAt = typeof item.updatedAt === 'string' ? item.updatedAt : this.formatDate(new Date());
        }
        if (typeof item.lastVisitedAt !== 'string' || item.lastVisitedAt.trim().length === 0) {
          item.lastVisitedAt = typeof item.updatedAt === 'string' ? item.updatedAt : item.createdAt;
        }
        return item;
      }).filter(item => this.isValidNote(item));
    } catch {
      return [];
    }
  }

  private isValidNote(note: Note): boolean {
    return typeof note.id === 'string' && typeof note.title === 'string' && typeof note.body === 'string'
      && typeof note.bodyLoaded === 'boolean'
      && typeof note.category === 'string'
      && Array.isArray(note.tags)
      && typeof note.isPinned === 'boolean'
      && typeof note.createdAt === 'string'
      && typeof note.lastVisitedAt === 'string'
      && typeof note.updatedAt === 'string';
  }

  private getActiveNote(): Note | undefined {
    return this.notes.find(note => note.id === this.activeNoteId);
  }

  private getFilteredNotes(): Note[] {
    let result = this.notes.filter(note => note.vaultId === this.activeVaultId);
    if (this.activeCategory.trim().length > 0) {
      result = result.filter(note => note.category === this.activeCategory);
    }
    if (this.activeTag.trim().length > 0) {
      result = result.filter(note => note.tags.includes(this.activeTag));
    }
    const query = this.searchText.trim().toLowerCase();
    if (query.length > 0) {
      const ranked: SearchRankItem[] = [];
      result.forEach(note => {
        if (this.searchInBody && !note.bodyLoaded) {
          this.ensureNoteBodyLoaded(note.id);
        }
        const score = this.getSearchScore(note, query, this.searchInBody);
        if (score > 0) {
          ranked.push({ note, score });
        }
      });
      ranked.sort((a, b) => {
        if (a.score !== b.score) {
          return b.score - a.score;
        }
        if (a.note.isPinned !== b.note.isPinned) {
          return a.note.isPinned ? -1 : 1;
        }
        return b.note.updatedAt.localeCompare(a.note.updatedAt);
      });
      return ranked.map(item => item.note);
    }
    return this.getSortedNotes(result);
  }

  private compactSearchText(text: string): string {
    return text.toLowerCase().replace(/\s+/g, '');
  }

  private isSubsequenceMatch(query: string, text: string): boolean {
    if (query.length === 0) {
      return true;
    }
    let j = 0;
    for (let i = 0; i < text.length; i++) {
      if (text[i] === query[j]) {
        j++;
        if (j === query.length) {
          return true;
        }
      }
    }
    return false;
  }

  private getFieldMatchScore(query: string, rawText: string): number {
    const text = rawText.toLowerCase();
    if (text.length === 0) {
      return 0;
    }
    const includeAt = text.indexOf(query);
    if (includeAt >= 0) {
      return 100 - Math.min(includeAt, 40);
    }
    const compactQuery = this.compactSearchText(query);
    const compactText = this.compactSearchText(rawText);
    if (compactQuery.length > 0) {
      const compactIndex = compactText.indexOf(compactQuery);
      if (compactIndex >= 0) {
        return 72 - Math.min(compactIndex, 30);
      }
      if (this.isSubsequenceMatch(compactQuery, compactText)) {
        return 42;
      }
    }
    if (this.isSubsequenceMatch(query, text)) {
      return 28;
    }
    return 0;
  }

  private getSearchScore(note: Note, query: string, includeBody: boolean): number {
    const titleScore = this.getFieldMatchScore(query, note.title) * 5;
    const categoryScore = this.getFieldMatchScore(query, note.category) * 3;
    const bodyScore = includeBody ? this.getFieldMatchScore(query, note.body) : 0;
    let tagsScore = 0;
    note.tags.forEach(tag => {
      tagsScore = Math.max(tagsScore, this.getFieldMatchScore(query, tag) * 2);
    });
    return titleScore + categoryScore + bodyScore + tagsScore;
  }

  private isTagSearchHit(tag: string, query: string): boolean {
    const q = query.trim().toLowerCase();
    if (q.length === 0) {
      return false;
    }
    return this.getFieldMatchScore(q, tag) > 0;
  }

  private getHighlightSegments(content: string, query: string): HighlightSegment[] {
    const text = content;
    const q = query.trim();
    if (q.length === 0) {
      return [{ text, hit: false }];
    }
    const lowText = text.toLowerCase();
    const lowQuery = q.toLowerCase();
    const segments: HighlightSegment[] = [];
    let cursor = 0;
    let hitAt = lowText.indexOf(lowQuery, cursor);
    while (hitAt >= 0) {
      if (hitAt > cursor) {
        segments.push({ text: text.slice(cursor, hitAt), hit: false });
      }
      segments.push({ text: text.slice(hitAt, hitAt + q.length), hit: true });
      cursor = hitAt + q.length;
      hitAt = lowText.indexOf(lowQuery, cursor);
    }
    if (cursor < text.length) {
      segments.push({ text: text.slice(cursor), hit: false });
    }
    if (segments.length === 0) {
      return [{ text, hit: false }];
    }
    return segments;
  }

  private getSearchExcerpt(body: string, query: string): string {
    const cleaned = body.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
    const q = query.trim().toLowerCase();
    if (cleaned.length === 0) {
      return '';
    }
    if (q.length === 0) {
      return this.getExcerpt(cleaned);
    }
    const source = cleaned.toLowerCase();
    const hitAt = source.indexOf(q);
    if (hitAt < 0) {
      return this.getExcerpt(cleaned);
    }
    const start = Math.max(0, hitAt - 18);
    const end = Math.min(cleaned.length, hitAt + q.length + 36);
    const prefix = start > 0 ? '...' : '';
    const suffix = end < cleaned.length ? '...' : '';
    return `${prefix}${cleaned.slice(start, end)}${suffix}`;
  }

  @Builder
  private HighlightedLine(content: string, query: string, fontSize: number, normalColor: string, maxLines: number = 1): void {
    Text() {
      ForEach(this.getHighlightSegments(content, query), (segment: HighlightSegment, index: number) => {
        Span(segment.text)
          .fontColor(segment.hit ? THEME.accentDeep : normalColor)
          .backgroundColor(segment.hit ? '#FFEBCB' : 'transparent')
          .fontWeight(segment.hit ? FontWeight.Medium : FontWeight.Regular);
      }, (segment: HighlightSegment, index: number) => `${content.length}-${segment.hit}-${index}`);
    }
    .fontSize(fontSize)
    .fontFamily(THEME.fontBody)
    .maxLines(maxLines)
    .textOverflow({ overflow: TextOverflow.Ellipsis });
  }

  private getSortedNotes(notes: Note[]): Note[] {
    const next = notes.slice();
    next.sort((a, b) => {
      if (a.isPinned !== b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      if (this.sortMode === 'title') {
        return a.title.localeCompare(b.title, 'zh-Hans-CN');
      }
      if (this.sortMode === 'category') {
        const byCategory = a.category.localeCompare(b.category, 'zh-Hans-CN');
        if (byCategory !== 0) {
          return byCategory;
        }
        return b.updatedAt.localeCompare(a.updatedAt);
      }
      if (this.sortMode === 'recent') {
        const byRecent = b.lastVisitedAt.localeCompare(a.lastVisitedAt);
        if (byRecent !== 0) {
          return byRecent;
        }
        return b.updatedAt.localeCompare(a.updatedAt);
      }
      return b.updatedAt.localeCompare(a.updatedAt);
    });
    return next;
  }

  private getAllCategories(): string[] {
    const set = new Set<string>();
    this.notes.forEach(note => set.add(note.category));
    return Array.from(set.values());
  }

  private getCategoryOptions(): string[] {
    const result: string[] = [];
    result.push('全部分类');
    this.getAllCategories().forEach(cat => result.push(cat));
    return result;
  }

  private getAllTags(): string[] {
    const tagSet = new Set<string>();
    this.notes.forEach(note => note.tags.forEach(tag => tagSet.add(tag)));
    return Array.from(tagSet.values());
  }

  private getTagOptions(): string[] {
    const result: string[] = [];
    result.push('全部标签');
    this.getAllTags().forEach(tag => result.push(tag));
    return result;
  }

  private getCollapsedChoiceCount(): number {
    return 2;
  }

  private getVisibleChoiceOptions(options: string[]): string[] {
    if (this.showAllLibraryChoices || options.length <= this.getCollapsedChoiceCount()) {
      return options;
    }
    return options.slice(0, this.getCollapsedChoiceCount());
  }

  private getVisibleSortOptions(): SortOption[] {
    if (this.showAllLibraryChoices || SORT_OPTIONS.length <= this.getCollapsedChoiceCount()) {
      return SORT_OPTIONS;
    }
    return SORT_OPTIONS.slice(0, this.getCollapsedChoiceCount());
  }

  private updateNoteById(noteId: string, patch: Partial<Note>, touchUpdatedAt: boolean): void {
    const index = this.notes.findIndex(note => note.id === noteId);
    if (index < 0) {
      return;
    }
    const base = this.notes[index];
    const bodyUpdated = patch.body !== undefined;
    const updated: Note = {
      id: base.id,
      vaultId: patch.vaultId ?? base.vaultId,
      title: patch.title ?? base.title,
      category: patch.category ?? base.category,
      body: patch.body ?? base.body,
      bodyLoaded: bodyUpdated ? true : (patch.bodyLoaded ?? base.bodyLoaded),
      tags: patch.tags ?? base.tags,
      isPinned: patch.isPinned ?? base.isPinned,
      createdAt: patch.createdAt ?? base.createdAt,
      lastVisitedAt: patch.lastVisitedAt ?? base.lastVisitedAt,
      updatedAt: touchUpdatedAt ? this.formatDate(new Date()) : (patch.updatedAt ?? base.updatedAt)
    };
    const next = this.notes.slice();
    next[index] = updated;
    this.notes = next;
    if (updated.body !== base.body) {
      this.scheduleNoteBodySave(updated.id, updated.body);
    }
    this.scheduleNotesSave();
    this.initForceDirectedLayout();
  }

  private updateActiveNote(patch: Partial<Note>): void {
    this.updateNoteById(this.activeNoteId, patch, true);
  }

  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private createNote(title: string, category: string, body: string, tags: string[]): void {
    const now = this.formatDate(new Date());
    const id = `n${Date.now()}-${Math.floor(Math.random() * 10000)}`;
    const newNote: Note = {
      id,
      vaultId: this.activeVaultId || 'vault-demo',
      title,
      category,
      body,
      bodyLoaded: true,
      tags,
      isPinned: false,
      createdAt: now,
      lastVisitedAt: now,
      updatedAt: now
    };
    const next = this.notes.slice();
    next.unshift(newNote);
    this.notes = next;
    this.saveNoteBody(id, body);
    this.saveNotesToStorage();
    this.activeNoteId = id;
    this.previewBodySnapshot = body;
    this.compactPanel = 'library';
    this.showSelectedNoteInCompact = this.isCompact;
    this.isNoteEditing = false;
    this.initForceDirectedLayout();
  }

  private openDailyNote(): void {
    const today = this.formatDate(new Date());
    const existing = this.notes.find(note => note.title === today && note.vaultId === this.activeVaultId);
    if (existing) {
      this.openNoteFromLibrary(existing.id);
      return;
    }
    const body = `# ${today}\n\n- [ ] 今日计划\n- [ ] 记录要点\n`;
    this.createNote(today, '日常记录', body, ['每日']);
  }

  private appendSnippetToActiveBody(snippet: string): void {
    const note = this.getActiveNote();
    if (!note) {
      return;
    }
    let next = note.body;
    if (next.length > 0 && !next.endsWith('\n')) {
      next += '\n';
    }
    next += snippet;
    if (!next.endsWith('\n')) {
      next += '\n';
    }
    this.updateActiveNote({ body: next });
  }

  private async insertImageFromGallery(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      if (!result || result.photoUris.length === 0) {
        return;
      }
      const uri = result.photoUris[0];
      const alt = `图片-${this.formatDate(new Date())}`;
      this.appendSnippetToActiveBody(`![${alt}](${uri})`);
    } catch {
      return;
    }
  }

  private openCreateNotePage(): void {
    this.draftTitle = '';
    this.draftCategory = '默认分类';
    this.draftBody = '# 新建笔记\n\n- 写下你的想法\n- 用 [[链接]] 连接知识\n';
    this.draftTagsText = '';
    this.showCreateNotePage = true;
  }

  private closeCreateNotePage(): void {
    this.showCreateNotePage = false;
  }

  private openNoteFromLibrary(noteId: string): void {
    this.updateNoteById(noteId, { lastVisitedAt: this.formatDate(new Date()) }, false);
    this.ensureNoteBodyLoaded(noteId);
    this.syncPreviewSnapshotById(noteId);
    this.activeNoteId = noteId;
    this.outlineTargetLine = -1;
    this.isNoteEditing = false;
    if (this.isCompact) {
      this.showSelectedNoteInCompact = true;
      this.compactPanel = 'library';
    }
  }

  private backToLibraryInCompact(): void {
    this.showSelectedNoteInCompact = false;
    this.isNoteEditing = false;
  }

  private onActiveNoteIdChanged(): void {
    this.syncPreviewSnapshotFromActive();
    this.outlineTargetLine = -1;
  }

  private syncPreviewSnapshotFromActive(): void {
    const note = this.getActiveNote();
    if (note && !note.bodyLoaded) {
      this.ensureNoteBodyLoaded(note.id);
    }
    this.previewBodySnapshot = note ? note.body : '';
  }

  private syncPreviewSnapshotById(noteId: string): void {
    this.ensureNoteBodyLoaded(noteId);
    const target = this.notes.find(item => item.id === noteId);
    this.previewBodySnapshot = target ? target.body : '';
  }

  private parseTagInput(text: string): string[] {
    const parts = text.split(/[，,]/);
    const unique = new Set<string>();
    parts.forEach(item => {
      const tag = item.trim();
      if (tag.length > 0) {
        unique.add(tag);
      }
    });
    return Array.from(unique.values());
  }

  private confirmCreateNote(): void {
    const title = this.draftTitle.trim().length > 0 ? this.draftTitle.trim() : '未命名笔记';
    const category = this.draftCategory.trim().length > 0 ? this.draftCategory.trim() : '默认分类';
    const body = this.draftBody.trim().length > 0 ? this.draftBody : `# ${title}\n\n`;
    let tags = this.parseTagInput(this.draftTagsText);
    if (tags.length === 0) {
      tags = ['新建'];
    }
    this.createNote(title, category, body, tags);
    this.showCreateNotePage = false;
  }

  private addTagToActiveNote(): void {
    const newTag = this.newTagText.trim();
    if (newTag.length === 0) {
      return;
    }
    const note = this.getActiveNote();
    if (!note) {
      return;
    }
    if (note.tags.includes(newTag)) {
      this.newTagText = '';
      return;
    }
    const nextTags = note.tags.slice();
    nextTags.push(newTag);
    this.updateActiveNote({ tags: nextTags });
    this.newTagText = '';
  }

  private togglePinActiveNote(): void {
    const note = this.getActiveNote();
    if (!note) {
      return;
    }
    this.togglePinNoteById(note.id);
  }

  private togglePinNoteById(noteId: string): void {
    const note = this.notes.find(item => item.id === noteId);
    if (!note) {
      return;
    }
    this.updateNoteById(note.id, { isPinned: !note.isPinned }, false);
  }

  private deleteActiveNote(): void {
    this.deleteNoteById(this.activeNoteId);
  }

  private deleteNoteById(noteId: string): void {
    const targetId = noteId;
    if (targetId.length === 0) {
      return;
    }
    const next = this.notes.filter(note => note.id !== targetId);
    this.notes = next;
    this.deleteNoteBody(targetId);

    const nextPhysics: Record<string, GraphPhysicsNode> = {};
    Object.keys(this.physicsNodes).forEach((id: string) => {
      if (id !== targetId) {
        nextPhysics[id] = this.physicsNodes[id];
      }
    });
    this.physicsNodes = nextPhysics;

    const nextPos: Record<string, GraphNodePoint> = {};
    Object.keys(this.graphNodePositions).forEach((id: string) => {
      if (id !== targetId) {
        nextPos[id] = this.graphNodePositions[id];
      }
    });
    this.graphNodePositions = nextPos;

    if (next.length === 0) {
      this.activeNoteId = '';
      this.previewBodySnapshot = '';
      this.isNoteEditing = false;
      this.showSelectedNoteInCompact = false;
      this.saveNotesToStorage();
      return;
    }
    if (this.activeNoteId === targetId) {
      this.activeNoteId = next[0].id;
      this.syncPreviewSnapshotById(this.activeNoteId);
      this.isNoteEditing = false;
      this.showSelectedNoteInCompact = this.isCompact;
    }
    this.saveNotesToStorage();
    this.initForceDirectedLayout();
  }

  private extractLinks(text: string): string[] {
    const result: string[] = [];
    const matcher = /\[\[([^\]]+)\]\]/g;
    let match = matcher.exec(text);
    while (match) {
      result.push(match[1].trim());
      match = matcher.exec(text);
    }
    return result;
  }

  private getGraphEdges(): GraphEdge[] {
    const currentNotes = this.getFilteredNotes();
    const titleMap = new Map<string, string>();
    currentNotes.forEach(note => titleMap.set(note.title, note.id));
    const edges: GraphEdge[] = [];
    currentNotes.forEach(note => {
      const links = this.extractLinks(note.body);
      links.forEach(linkTitle => {
        edges.push({
          fromId: note.id,
          fromTitle: note.title,
          toId: titleMap.get(linkTitle),
          toTitle: linkTitle
        });
      });
    });
    return edges;
  }

  private getGraphRelatedIds(focusId: string): Set<string> {
    const related = new Set<string>();
    if (focusId.length === 0) {
      return related;
    }
    related.add(focusId);
    this.getGraphEdges().forEach(edge => {
      if (edge.fromId === focusId && edge.toId) {
        related.add(edge.toId);
      }
      if (edge.toId === focusId) {
        related.add(edge.fromId);
      }
    });
    return related;
  }

  private getGraphVisibleNotes(): Note[] {
    const filteredNotes = this.getFilteredNotes();
    if (this.graphFocusedNoteId.length === 0) {
      return filteredNotes;
    }
    const related = this.getGraphRelatedIds(this.graphFocusedNoteId);
    return filteredNotes.filter(note => related.has(note.id));
  }

  private getGraphVisibleEdges(): GraphEdge[] {
    if (this.graphFocusedNoteId.length === 0) {
      return this.getGraphEdges();
    }
    const related = this.getGraphRelatedIds(this.graphFocusedNoteId);
    return this.getGraphEdges().filter(edge => {
      if (!related.has(edge.fromId)) {
        return false;
      }
      if (!edge.toId) {
        return edge.fromId === this.graphFocusedNoteId;
      }
      return related.has(edge.toId);
    });
  }



  private increaseGraphZoom(): void {
    this.graphZoom = Math.min(1.8, this.graphZoom + 0.1);
  }

  private decreaseGraphZoom(): void {
    this.graphZoom = Math.max(0.7, this.graphZoom - 0.1);
  }

  private resetGraphView(): void {
    this.graphZoom = 1;
    this.graphFocusedNoteId = '';
  }

  private toggleGraphFocus(noteId: string): void {
    this.graphFocusedNoteId = this.graphFocusedNoteId === noteId ? '' : noteId;
    this.openNoteFromLibrary(noteId);
  }

  private getBacklinks(note: Note | undefined): Note[] {
    if (!note) {
      return [];
    }
    return this.notes.filter(item => {
      if (item.id === note.id) {
        return false;
      }
      return this.extractLinks(item.body).includes(note.title);
    });
  }

  private trimLine(line: string): string {
    return line.trim();
  }

  private lineStartsWith(line: string, prefix: string): boolean {
    return this.trimLine(line).startsWith(prefix);
  }

  private getLineAfterPrefix(line: string, prefix: string): string {
    return this.trimLine(line).slice(prefix.length);
  }

  private isEmptyLine(line: string): boolean {
    return this.trimLine(line).length === 0;
  }

  private getMarkdownLines(body: string): string[] {
    return body.split(/\r?\n/);
  }

  private isCodeFence(line: string): boolean {
    return this.trimLine(line).startsWith('```');
  }

  private isTableLine(line: string): boolean {
    return this.trimLine(line).includes('|');
  }

  private splitTableRow(line: string): string[] {
    let cleaned = this.trimLine(line);
    if (cleaned.startsWith('|')) {
      cleaned = cleaned.slice(1);
    }
    if (cleaned.endsWith('|')) {
      cleaned = cleaned.slice(0, cleaned.length - 1);
    }
    return cleaned.split('|').map(cell => cell.trim());
  }

  private isTableSeparatorLine(line: string): boolean {
    if (!this.isTableLine(line)) {
      return false;
    }
    const cells = this.splitTableRow(line);
    if (cells.length === 0) {
      return false;
    }
    return cells.every(cell => /^:?-{3,}:?$/.test(cell.trim()));
  }

  private getTableRows(lines: string[]): string[][] {
    const rows: string[][] = [];
    for (let i = 0; i < lines.length; i++) {
      if (this.isTableSeparatorLine(lines[i])) {
        continue;
      }
      rows.push(this.splitTableRow(lines[i]));
    }
    return rows;
  }

  private getMarkdownBlocks(body: string): MarkdownBlock[] {
    const lines = this.getMarkdownLines(body);
    const blocks: MarkdownBlock[] = [];
    let inCode = false;
    let codeLines: string[] = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (this.isCodeFence(line)) {
        if (!inCode) {
          inCode = true;
          codeLines = [];
        } else {
          blocks.push({ type: 'code', text: codeLines.join('\n'), lines: [] });
          inCode = false;
        }
        continue;
      }

      if (inCode) {
        codeLines.push(line);
        continue;
      }

      if (this.isTableLine(line) && i + 1 < lines.length && this.isTableSeparatorLine(lines[i + 1])) {
        const tableLines: string[] = [];
        tableLines.push(line);
        tableLines.push(lines[i + 1]);
        i += 2;
        while (i < lines.length && this.isTableLine(lines[i])) {
          tableLines.push(lines[i]);
          i++;
        }
        i -= 1;
        blocks.push({ type: 'table', text: '', lines: tableLines });
        continue;
      }

      blocks.push({ type: 'line', text: line, lines: [] });
    }

    if (inCode) {
      blocks.push({ type: 'code', text: codeLines.join('\n'), lines: [] });
    }
    return blocks;
  }

  private getOutlineItems(body: string): OutlineItem[] {
    const lines = this.getMarkdownLines(body);
    const items: OutlineItem[] = [];
    let inCode = false;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (this.isCodeFence(line)) {
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        continue;
      }
      const trimmed = this.trimLine(line);
      const match = /^(#{1,6})\s+(.+)$/.exec(trimmed);
      if (match) {
        items.push({ level: match[1].length, title: match[2].trim(), lineIndex: i });
      }
    }
    return items;
  }

  private getActiveOutlineItems(): OutlineItem[] {
    const note = this.getActiveNote();
    return note ? this.getOutlineItems(note.body) : [];
  }

  private jumpToOutline(item: OutlineItem): void {
    const offset = item.lineIndex * 26;
    this.previewScroller.scrollTo({ xOffset: 0, yOffset: offset });
  }

  private isTaskLine(line: string): boolean {
    const trimmed = this.trimLine(line).toLowerCase();
    return trimmed.startsWith('- [ ]') || trimmed.startsWith('- [x]');
  }

  private isTaskChecked(line: string): boolean {
    return this.trimLine(line).toLowerCase().startsWith('- [x]');
  }

  private getTaskText(line: string): string {
    const trimmed = this.trimLine(line);
    return trimmed.length > 5 ? trimmed.slice(5).trim() : '';
  }

  private isImageLine(line: string): boolean {
    return /^!\[[^\]]*\]\([^\)]+\)/.test(this.trimLine(line));
  }

  private getImageAlt(line: string): string {
    const match = this.trimLine(line).match(/^!\[([^\]]*)\]\(([^\)]+)\)/);
    return match ? match[1].trim() : '';
  }

  private getImageSource(line: string): string {
    const match = this.trimLine(line).match(/^!\[([^\]]*)\]\(([^\)]+)\)/);
    return match ? match[2].trim() : '';
  }

  private hasActiveNote(): boolean {
    return this.getActiveNote() !== undefined;
  }

  private getActiveNoteUpdatedAt(): string {
    const note = this.getActiveNote();
    return note ? note.updatedAt : '';
  }

  private enterNoteEditMode(): void {
    this.isNoteEditing = true;
  }

  private exitNoteEditMode(): void {
    this.isNoteEditing = false;
    this.syncPreviewSnapshotFromActive();
  }

  private getActiveNoteTitle(): string {
    const note = this.getActiveNote();
    return note ? note.title : '';
  }

  private getActiveNoteCategory(): string {
    const note = this.getActiveNote();
    return note ? (note.category || '未分类') : '未分类';
  }

  private isActiveNotePinned(): boolean {
    const note = this.getActiveNote();
    return note ? note.isPinned : false;
  }

  private getActiveNoteBody(): string {
    const note = this.getActiveNote();
    return note ? note.body : '';
  }

  private getActiveNoteTags(): string[] {
    const note = this.getActiveNote();
    return note ? note.tags : [];
  }

  private getActiveNoteId(): string {
    const note = this.getActiveNote();
    return note ? note.id : '';
  }

  private getActiveLinks(): string[] {
    const note = this.getActiveNote();
    return note ? this.extractLinks(note.body) : [];
  }

  private getActiveBacklinks(): Note[] {
    return this.getBacklinks(this.getActiveNote());
  }

  private openLinkedNote(linkTitle: string): void {
    const targetTitle = linkTitle.trim();
    if (targetTitle.length === 0) {
      return;
    }
    const existed = this.notes.find(note => note.title === targetTitle);
    if (existed) {
      this.openNoteFromLibrary(existed.id);
      return;
    }
    this.createNote(targetTitle, '默认分类', `# ${targetTitle}\n\n`, ['链接']);
  }

  private parseInline(text: string): InlineToken[] {
    // Parse bold, code, and wiki links for the lite markdown preview.
    const tokens: InlineToken[] = [];
    const pattern = /(\*\*[^*]+\*\*|`[^`]+`|\[\[[^\]]+\]\])/g;
    let lastIndex = 0;
    let match = pattern.exec(text);
    while (match) {
      if (match.index > lastIndex) {
        tokens.push({ kind: 'text', text: text.slice(lastIndex, match.index) });
      }
      const value = match[0];
      if (value.startsWith('**')) {
        tokens.push({ kind: 'bold', text: value.slice(2, -2) });
      } else if (value.startsWith('`')) {
        tokens.push({ kind: 'code', text: value.slice(1, -1) });
      } else if (value.startsWith('[[')) {
        tokens.push({ kind: 'link', text: value.slice(2, -2) });
      }
      lastIndex = match.index + value.length;
      match = pattern.exec(text);
    }
    if (lastIndex < text.length) {
      tokens.push({ kind: 'text', text: text.slice(lastIndex) });
    }
    return tokens;
  }

  @Builder
  private renderInlineText(content: string, fontSize: number, color: string): void {
    Text() {
      ForEach(this.parseInline(content), (token: InlineToken, index: number) => {
        if (token.kind === 'bold') {
          Span(token.text)
            .fontWeight(FontWeight.Bold)
            .fontColor(color)
            .fontFamily(THEME.fontBody);
        } else if (token.kind === 'code') {
          Span(token.text)
            .fontColor(THEME.accentDeep)
            .fontFamily('monospace')
            .backgroundColor(THEME.accentSoft)
            .borderRadius(6)
            .padding({ left: 4, right: 4, top: 2, bottom: 2 });
        } else if (token.kind === 'link') {
          Span(token.text)
            .fontColor(THEME.accentDeep)
            .fontWeight(FontWeight.Medium)
            .fontFamily(THEME.fontBody)
            .onClick(() => {
              this.openLinkedNote(token.text);
            });
        } else {
          Span(token.text)
            .fontColor(color)
            .fontFamily(THEME.fontBody);
        }
      }, (token: InlineToken, index: number) => `${this.activeNoteId}-${token.kind}-${index}-${token.text.length}`);
    }
    .fontSize(fontSize)
    .lineHeight(fontSize + 8)
    .fontColor(color);
  }

  @Builder
  private MarkdownCodeBlock(code: string): void {
    Text(code)
      .fontSize(12)
      .fontFamily('monospace')
      .fontColor(THEME.ink)
      .backgroundColor(THEME.cardAlt)
      .border({ width: 1, color: THEME.border })
      .borderRadius(8)
      .padding(10)
      .width('100%')
      .margin({ bottom: 6 });
  }

  @Builder
  private MarkdownTable(lines: string[]): void {
    Column({ space: 6 }) {
      ForEach(this.getTableRows(lines), (row: string[], rowIndex: number) => {
        Row({ space: 8 }) {
          ForEach(row, (cell: string, cellIndex: number) => {
            Text(cell)
              .fontSize(12)
              .fontFamily(THEME.fontBody)
              .fontColor(rowIndex === 0 ? THEME.ink : THEME.inkMuted)
              .backgroundColor(rowIndex === 0 ? THEME.accentSoft : THEME.card)
              .border({ width: 1, color: THEME.border })
              .borderRadius(6)
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .layoutWeight(1);
          }, (cell: string, cellIndex: number) => `table-cell-${rowIndex}-${cellIndex}-${cell.length}`);
        }
      }, (row: string[], rowIndex: number) => `table-row-${rowIndex}-${row.length}`);
    }
    .width('100%')
    .margin({ bottom: 6 });
  }

  @Builder
  private MarkdownImageLine(line: string): void {
    Column({ space: 6 }) {
      Image(this.getImageSource(line))
        .width('100%')
        .height(160)
        .objectFit(ImageFit.Contain)
        .borderRadius(8)
        .border({ width: 1, color: THEME.border })
        .backgroundColor(THEME.card);
      if (this.getImageAlt(line).length > 0) {
        Text(this.getImageAlt(line))
          .fontSize(11)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.inkMuted);
      }
    }
    .margin({ bottom: 6 });
  }

  @Builder
  private MarkdownLine(line: string): void {
    if (this.isImageLine(line)) {
      this.MarkdownImageLine(line);
    } else if (this.isTaskLine(line)) {
      Row() {
        Text(this.isTaskChecked(line) ? '[x]' : '[ ]')
          .fontSize(12)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.accentDeep)
          .padding({ left: 4, right: 4, top: 2, bottom: 2 })
          .backgroundColor(THEME.accentSoft)
          .borderRadius(6)
          .margin({ right: 6 });
        this.renderInlineText(this.getTaskText(line), 14, THEME.ink);
      }
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 6 });
    } else if (this.lineStartsWith(line, '### ')) {
      this.renderInlineText(this.getLineAfterPrefix(line, '### '), 16, THEME.ink);
    } else if (this.lineStartsWith(line, '## ')) {
      this.renderInlineText(this.getLineAfterPrefix(line, '## '), 18, THEME.ink);
    } else if (this.lineStartsWith(line, '# ')) {
      this.renderInlineText(this.getLineAfterPrefix(line, '# '), 20, THEME.ink);
    } else if (this.lineStartsWith(line, '- ')) {
      Row() {
        Text('•')
          .fontSize(14)
          .fontColor(THEME.accentDeep)
          .fontFamily(THEME.fontBody)
          .margin({ right: 6 });
        this.renderInlineText(this.getLineAfterPrefix(line, '- '), 14, THEME.ink);
      }
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 6 });
    } else if (this.lineStartsWith(line, '> ')) {
      Row() {
        Column() {
          this.renderInlineText(this.getLineAfterPrefix(line, '> '), 14, THEME.inkMuted);
        }
      }
      .padding({ top: 6, bottom: 6, left: 12, right: 6 })
      .backgroundColor(THEME.cardAlt)
      .border({ width: { left: 4 }, color: { left: THEME.accent }, style: { left: BorderStyle.Solid } })
      .borderRadius(8)
      .margin({ bottom: 8 });
    } else if (this.isEmptyLine(line)) {
      Blank().height(6);
    } else {
      this.renderInlineText(this.trimLine(line), 14, THEME.ink);
    }
  }

  @Builder
  private MarkdownPreview(): void {
    if (this.previewBodySnapshot.trim().length === 0) {
      Blank().height(0);
    } else {
      Column({ space: 6 }) {
        ForEach(this.getMarkdownBlocks(this.previewBodySnapshot), (block: MarkdownBlock, index: number) => {
          if (block.type === 'code') {
            this.MarkdownCodeBlock(block.text);
          } else if (block.type === 'table') {
            this.MarkdownTable(block.lines);
          } else {
            this.MarkdownLine(block.text);
          }
        }, (block: MarkdownBlock, index: number) => `${this.activeNoteId}-block-${index}-${block.type}-${block.text.length}-${block.lines.length}`);
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%');
    }
  }

  @Builder
  private SegmentButton(label: string, value: CompactPanel): void {
    Text(label)
      .fontSize(13)
      .fontColor(this.compactPanel === value ? THEME.ink : THEME.inkMuted)
      .fontFamily(THEME.fontBody)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.compactPanel === value ? THEME.accentSoft : 'transparent')
      .borderRadius(12)
      .border({ width: 1, color: this.compactPanel === value ? THEME.accent : THEME.border })
      .onClick(() => {
        this.compactPanel = value;
        if (value === 'graph') {
          this.initForceDirectedLayout();
        }
        if (value === 'library') {
          this.showSelectedNoteInCompact = false;
        }
      });
  }

  @Builder
  private TagChip(label: string, active: boolean, onTap: () => void): void {
    Text(label)
      .fontSize(12)
      .fontColor(active ? THEME.ink : THEME.inkMuted)
      .fontFamily(THEME.fontBody)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(active ? THEME.accentSoft : THEME.cardAlt)
      .borderRadius(12)
      .border({ width: 1, color: active ? THEME.accent : THEME.border })
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        onTap();
      });
  }

  @Builder
  private LibraryModeChip(label: string, mode: LibraryControlMode): void {
    Button(label)
      .fontSize(10)
      .fontColor(this.libraryControlMode === mode ? THEME.onPrimaryContainer : THEME.inkMuted)
      .fontWeight(this.libraryControlMode === mode ? FontWeight.Medium : FontWeight.Regular)
      .fontFamily(THEME.fontBody)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(this.libraryControlMode === mode ? THEME.primaryContainer : THEME.surface)
      .borderRadius(8)
      .border({ width: 1, color: this.libraryControlMode === mode ? THEME.primaryContainer : THEME.outline })
      .margin({ right: 4, bottom: 4 })
      .stateEffect(true)
      .onClick(() => {
        this.libraryControlMode = mode;
        this.showAllLibraryChoices = false;
      });
  }

  @Builder
  private LibraryChoiceChip(label: string, active: boolean, onTap: () => void): void {
    Button(label)
      .fontSize(10)
      .fontColor(active ? THEME.onPrimaryContainer : THEME.inkMuted)
      .fontWeight(active ? FontWeight.Medium : FontWeight.Regular)
      .fontFamily(THEME.fontBody)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(active ? THEME.primaryContainer : THEME.surface)
      .borderRadius(8)
      .border({ width: 1, color: active ? THEME.primaryContainer : THEME.outline })
      .shadow(active ? THEME.elevation1 : { radius: 0, color: 'transparent', offsetX: 0, offsetY: 0 })
      .margin({ right: 4, bottom: 4 })
      .stateEffect(true)
      .onClick(() => {
        onTap();
      });
  }

  @Builder
  private FloatingActionButton(): void {
    Button('+')
      .width(FAB_SIZE)
      .height(FAB_SIZE)
      .fontSize(22)
      .fontWeight(FontWeight.Medium)
      .fontFamily(THEME.fontTitle)
      .fontColor(THEME.onPrimary)
      .backgroundColor(THEME.primary)
      .borderRadius(25)
      .shadow(THEME.elevation3)
      .stateEffect(true)
      .padding(0)
      .onClick(() => {
        this.openCreateNotePage();
      });
  }

  @Builder
  private EditorToolChip(label: string, snippet: string): void {
    Button(label)
      .backgroundColor(THEME.cardAlt)
      .fontColor(THEME.ink)
      .fontFamily(THEME.fontBody)
      .fontSize(12)
      .borderRadius(10)
      .border({ width: 1, color: THEME.border })
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .onClick(() => {
        this.appendSnippetToActiveBody(snippet);
      });
  }

  @Builder
  private EditorActionChip(label: string, onTap: () => void): void {
    Button(label)
      .backgroundColor(THEME.cardAlt)
      .fontColor(THEME.ink)
      .fontFamily(THEME.fontBody)
      .fontSize(12)
      .borderRadius(10)
      .border({ width: 1, color: THEME.border })
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .onClick(() => {
        onTap();
      });
  }

  @Builder
  private VaultCard(vault: Vault): void {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(vault.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontFamily(THEME.fontTitle)
            .fontColor(THEME.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(`创建于 ${vault.createdAt}`)
            .fontSize(12)
            .fontColor(THEME.inkMuted)
            .fontFamily(THEME.fontBody);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text(vault.name.charAt(0).toUpperCase())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(THEME.onPrimaryContainer)
          .textAlign(TextAlign.Center)
          .width(40)
          .height(40)
          .backgroundColor(THEME.primaryContainer)
          .borderRadius(20);
      }
      .width('100%');

      Text(vault.description || '暂无描述')
        .fontSize(14)
        .fontFamily(THEME.fontBody)
        .fontColor(THEME.inkMuted)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
        
      Row() {
        Text(`${this.notes.filter(n => n.vaultId === vault.id).length} 篇笔记`)
          .fontSize(12)
          .fontColor(THEME.primary)
          .fontFamily(THEME.fontBody)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(THEME.primaryContainer)
          .borderRadius(8);
      }
      .width('100%')
      .justifyContent(FlexAlign.Start);
    }
    .padding(20)
    .backgroundColor(THEME.surface)
    .borderRadius(THEME.radiusLarge)
    .border({ width: 1, color: THEME.outline })
    .shadow(THEME.elevation1)
    .onClick(() => {
      animateTo({ duration: 400, curve: Curve.Friction }, () => {
        this.activeVaultId = vault.id;
        const vaultNotes = this.getFilteredNotes();
        if (vaultNotes.length > 0) {
          this.activeNoteId = vaultNotes[0].id;
          this.syncPreviewSnapshotFromActive();
        } else {
          this.activeNoteId = '';
          this.previewBodySnapshot = '';
          this.graphFocusedNoteId = '';
        }
        this.initForceDirectedLayout();
      });
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          promptAction.showActionMenu({
            title: `操作: ${vault.name}`,
            buttons: [
              { text: '编辑知识库信息', color: THEME.ink },
              { text: '删除此知识库 (含笔记)', color: THEME.error }
            ]
          }).then(async (data) => {
            if (data.index === 0) {
              this.openEditVaultPage(vault);
              return;
            }
            if (data.index === 1) {
              const confirmResp = await promptAction.showDialog({
                title: '不可逆警告',
                message: `确定要彻底删除知识库吗？操作无法恢复。`,
                buttons: [
                  { text: '取消', color: THEME.ink },
                  { text: '彻底删除', color: THEME.error }
                ]
              });
              if (confirmResp.index === 1) {
                animateTo({ duration: 300 }, () => {
                  this.vaults = this.vaults.filter(v => v.id !== vault.id);
                  this.notes = this.notes.filter(n => n.vaultId !== vault.id);
                });
                const store = await this.getRdbStore();
                const preds = new rdb.RdbPredicates(VAULTS_TABLE);
                preds.equalTo('id', vault.id);
                await store.delete(preds);
                const notePreds = new rdb.RdbPredicates(NOTES_TABLE);
                notePreds.equalTo('vaultId', vault.id);
                await store.delete(notePreds);
                promptAction.showToast({ message: '知识库已彻底删除' });
              }
            }
          }).catch(() => {});
        })
    );
  }

  @Builder
  private VaultsPanel(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 16 }) {
        Text('我的知识库')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink)
          .width('100%')
          .padding({ bottom: 8, top: 8 })
          .border({ width: { bottom: 1 }, color: THEME.outline });
        
        if (this.vaults.length === 0) {
          Column({ space: 16 }) {
            Text('📚')
              .fontSize(64)
            Text('没有任何知识库')
              .fontSize(18)
              .fontColor(THEME.ink)
              .fontWeight(FontWeight.Bold)
            Text('点击右下角加号，创建你的第一个知识库吧')
              .fontSize(14)
              .fontColor(THEME.inkMuted)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Grid() {
              ForEach(this.vaults, (vault: Vault) => {
                GridItem() {
                  this.VaultCard(vault);
                }
              }, (vault: Vault) => vault.id);
            }
            .columnsTemplate(this.isCompact ? '1fr' : '1fr 1fr 1fr')
            .columnsGap(16)
            .rowsGap(16)
            .width('100%');
          }
          .layoutWeight(1)
          .width('100%');
        }
      }
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 24, right: 24, top: 16 })
      .width('100%')
      .height('100%');

      Column() {
        Button() {
          Text('+')
            .fontSize(24)
            .fontColor(THEME.onPrimary)
            .fontWeight(FontWeight.Medium)
        }
        .type(ButtonType.Circle)
        .width(FAB_SIZE)
        .height(FAB_SIZE)
        .backgroundColor(THEME.primary)
        .shadow(THEME.elevation3)
        .stateEffect(true)
        .onClick(() => {
          this.createNewVault();
        });
      }
      .width(FAB_SIZE)
      .height(FAB_SIZE)
      .margin({ right: FAB_MARGIN_RIGHT + 16, bottom: FAB_MARGIN_BOTTOM + 16 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(THEME.surfaceVariant);
  }

  private createNewVault(): void {
    this.openCreateVaultPage();
  }

  private openCreateVaultPage(): void {
    this.editingVaultId = '';
    this.draftVaultName = `新知识库 ${this.vaults.length + 1}`;
    this.draftVaultDescription = '点击以管理该知识库内的笔记';
    this.showVaultEditorPage = true;
  }

  private openEditVaultPage(vault: Vault): void {
    this.editingVaultId = vault.id;
    this.draftVaultName = vault.name;
    this.draftVaultDescription = vault.description;
    this.showVaultEditorPage = true;
  }

  private closeVaultEditorPage(): void {
    this.showVaultEditorPage = false;
  }

  private async confirmVaultEditor(): Promise<void> {
    const name = this.draftVaultName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '知识库名称不能为空' });
      return;
    }
    const description = this.draftVaultDescription.trim().length > 0
      ? this.draftVaultDescription.trim()
      : '点击以管理该知识库内的笔记';
    const now = this.formatDate(new Date());

    try {
      const store = await this.getRdbStore();
      if (this.editingVaultId.length === 0) {
        const newVault: Vault = {
          id: `vault-${Date.now()}`,
          name,
          description,
          color: THEME.primary,
          createdAt: now,
          updatedAt: now
        };
        animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
          this.vaults.push(newVault);
        });
        await store.insert(VAULTS_TABLE, {
          id: newVault.id,
          name: newVault.name,
          description: newVault.description,
          color: newVault.color,
          createdAt: newVault.createdAt,
          updatedAt: newVault.updatedAt
        });
      } else {
        const current = this.vaults.find(item => item.id === this.editingVaultId);
        if (!current) {
          this.closeVaultEditorPage();
          return;
        }
        const updatedVault: Vault = {
          id: current.id,
          name,
          description,
          color: current.color,
          createdAt: current.createdAt,
          updatedAt: now
        };
        animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.vaults = this.vaults.map(item => item.id === updatedVault.id ? updatedVault : item);
        });
        const predicates = new rdb.RdbPredicates(VAULTS_TABLE);
        predicates.equalTo('id', updatedVault.id);
        await store.update({
          name: updatedVault.name,
          description: updatedVault.description,
          updatedAt: updatedVault.updatedAt
        }, predicates);
      }
      this.closeVaultEditorPage();
    } catch (err) {
      promptAction.showToast({ message: '保存知识库失败，请稍后重试' });
    }
  }

  @Builder
  private NoteCard(note: Note, isActive: boolean): void {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        if (note.isPinned) {
          Text('置顶')
            .fontSize(10)
            .fontColor(THEME.primary)
            .fontFamily(THEME.fontBody)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(THEME.primaryContainer)
            .borderRadius(8);
        }
        Text() {
          ForEach(this.getHighlightSegments(note.title, this.searchText), (segment: HighlightSegment, index: number) => {
            Span(segment.text)
              .fontColor(segment.hit ? THEME.primary : THEME.ink)
              .backgroundColor(segment.hit ? THEME.primaryContainer : 'transparent')
              .fontWeight(segment.hit ? FontWeight.Bold : FontWeight.Medium)
              .fontFamily(THEME.fontTitle);
          }, (segment: HighlightSegment, index: number) => `${note.id}-title-seg-${index}`);
        }
        .layoutWeight(1)
        .fontSize(16)
        .fontFamily(THEME.fontTitle)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      this.HighlightedLine(note.category || '未分类', this.searchText, 12, THEME.primary, 1);
      this.HighlightedLine(this.getSearchExcerpt(note.body, this.searchText), this.searchText, 12, THEME.inkMuted, 2);
      Row({ space: 6 }) {
        ForEach(note.tags, (tag: string, index: number) => {
          Text(tag)
            .fontSize(11)
            .fontColor(this.isTagSearchHit(tag, this.searchText) ? THEME.primary : THEME.inkMuted)
            .fontFamily(THEME.fontBody)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.isTagSearchHit(tag, this.searchText) ? THEME.primaryContainer : THEME.surfaceVariant)
            .borderRadius(10)
            .border({ width: 1, color: this.isTagSearchHit(tag, this.searchText) ? THEME.primaryContainer : THEME.outline });
        }, (tag: string, index: number) => `${note.id}-${index}`);
      }
      Text(`访问 ${note.lastVisitedAt} · 更新 ${note.updatedAt}`)
        .fontSize(10)
        .fontColor(THEME.inkMuted)
        .fontFamily(THEME.fontBody);
    }
    .padding(14)
    .backgroundColor(isActive ? THEME.primaryContainer : THEME.surface)
    .borderRadius(THEME.radiusLarge)
    .border({ width: 1, color: isActive ? THEME.primaryContainer : THEME.outline })
    .shadow(THEME.elevation1)
    .onClick(() => {
      this.openNoteFromLibrary(note.id);
    });
  }

  private getExcerpt(body: string): string {
    const cleaned = body.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
    return cleaned.length > 60 ? `${cleaned.slice(0, 60)}...` : cleaned;
  }

  @Builder
  private LibraryPanel(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 12 }) {
        Text('笔记库')
          .fontSize(18)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink);
        Column({ space: 10 }) {
          Row() {
            TextInput({ text: this.searchText, placeholder: '搜索笔记' })
              .fontSize(14)
              .fontFamily(THEME.fontBody)
              .fontColor(THEME.ink)
              .backgroundColor('transparent')
              .border({ width: 0, color: 'transparent' })
              .padding({ left: 14, right: 14, top: 4, bottom: 4 })
              .layoutWeight(1)
              .onChange((value: string) => {
                this.searchText = value;
              });
          }
          .height(44)
          .width('100%')
          .backgroundColor(THEME.surface)
          .borderRadius(THEME.radiusLarge)
          .border({ width: 1, color: THEME.outline })
          .shadow(THEME.elevation1);
        }
        .width('100%');

        Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row, justifyContent: FlexAlign.Start }) {
          this.LibraryModeChip('分类', 'category');
          this.LibraryModeChip('标签', 'tag');
          this.LibraryModeChip('排序', 'sort');
        }
        .width('100%');

        if (this.libraryControlMode === 'category') {
          Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row, justifyContent: FlexAlign.Start }) {
            ForEach(this.getVisibleChoiceOptions(this.getCategoryOptions()), (cat: string, index: number) => {
              this.LibraryChoiceChip(cat, cat === '全部分类' ? this.activeCategory.length === 0 : this.activeCategory === cat, () => {
                this.activeCategory = cat === '全部分类' ? '' : cat;
              });
            }, (cat: string, index: number) => `cat-${cat}-${this.activeCategory}`);
            if (this.getCategoryOptions().length > this.getCollapsedChoiceCount()) {
              this.LibraryChoiceChip(this.showAllLibraryChoices ? '收起' : '更多', false, () => {
                this.showAllLibraryChoices = !this.showAllLibraryChoices;
              });
            }
          }
          .width('100%');
        }

        if (this.libraryControlMode === 'tag') {
          Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row, justifyContent: FlexAlign.Start }) {
            ForEach(this.getVisibleChoiceOptions(this.getTagOptions()), (tag: string, index: number) => {
              this.LibraryChoiceChip(tag, tag === '全部标签' ? this.activeTag.length === 0 : this.activeTag === tag, () => {
                this.activeTag = tag === '全部标签' ? '' : tag;
              });
            }, (tag: string, index: number) => `tag-${tag}-${this.activeTag}`);
            if (this.getTagOptions().length > this.getCollapsedChoiceCount()) {
              this.LibraryChoiceChip(this.showAllLibraryChoices ? '收起' : '更多', false, () => {
                this.showAllLibraryChoices = !this.showAllLibraryChoices;
              });
            }
          }
          .width('100%');
        }

        if (this.libraryControlMode === 'sort') {
          Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row, justifyContent: FlexAlign.Start }) {
            ForEach(this.getVisibleSortOptions(), (option: SortOption, index: number) => {
              this.LibraryChoiceChip(option.label, this.sortMode === option.value, () => {
                this.sortMode = option.value;
              });
            }, (option: SortOption, index: number) => `sort-${option.value}-${this.sortMode === option.value}`);
            if (SORT_OPTIONS.length > this.getCollapsedChoiceCount()) {
              this.LibraryChoiceChip(this.showAllLibraryChoices ? '收起' : '更多', false, () => {
                this.showAllLibraryChoices = !this.showAllLibraryChoices;
              });
            }
          }
          .width('100%');
        }

        Scroll(this.libraryScroller) {
          if (this.getFilteredNotes().length === 0) {
            Column({ space: 16 }) {
              Text('✨')
                .fontSize(48)
              Text(this.searchText.length > 0 ? '没有找到相关笔记' : '知识库空空如也')
                .fontSize(16)
                .fontColor(THEME.ink)
                .fontWeight(FontWeight.Bold)
              Text(this.searchText.length > 0 ? '试试换个关键词关键词' : '点击右下角的加号，写下属于你的第一篇笔记吧！')
                .fontSize(12)
                .fontColor(THEME.inkMuted)
            }
            .width('100%')
            .padding({ top: 60 })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            Grid() {
              ForEach(this.getFilteredNotes(), (note: Note) => {
                GridItem() {
                  this.NoteCard(note, note.id === this.activeNoteId);
                }
              }, (note: Note) => note.id);
            }
            .columnsTemplate(this.isCompact ? '1fr' : '1fr 1fr')
            .columnsGap(12)
            .rowsGap(12)
            .width('100%');
          }
        }
        .layoutWeight(1)
        .width('100%');
      }
      .padding(16)
      .backgroundColor(THEME.surfaceVariant)
      .borderRadius(THEME.radiusLarge)
      .border({ width: 1, color: THEME.outline })
      .shadow(THEME.elevation1)
      .id(`note-panel-${this.getActiveNoteId()}-${this.isNoteEditing ? 'edit' : 'view'}`)
      .height('100%');

      Column() {
        this.FloatingActionButton();
      }
      .width(FAB_SIZE)
      .height(FAB_SIZE)
      .margin({ right: FAB_MARGIN_RIGHT, bottom: FAB_MARGIN_BOTTOM });
    }
    .height('100%')
  }

  @Builder
  private NotePanel(): void {
    Column({ space: 12 }) {
      Row() {
        if (this.isCompact) {
          Button('返回笔记库')
            .backgroundColor(THEME.card)
            .fontColor(THEME.ink)
            .fontFamily(THEME.fontBody)
            .fontSize(12)
            .borderRadius(12)
            .border({ width: 1, color: THEME.border })
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .margin({ right: 8 })
            .onClick(() => {
              this.backToLibraryInCompact();
            });
        }
        Blank().layoutWeight(1);
        if (this.hasActiveNote()) {
          Row({ space: 6 }) {
            Button(this.isActiveNotePinned() ? '取消置顶' : '置顶')
              .backgroundColor(THEME.card)
              .border({ width: 1, color: THEME.border })
              .fontColor(THEME.ink)
              .fontFamily(THEME.fontBody)
              .fontSize(12)
              .borderRadius(12)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => {
                this.togglePinActiveNote();
              });
            Button('分享')
              .backgroundColor(THEME.card)
              .border({ width: 1, color: THEME.border })
              .fontColor(THEME.ink)
              .fontFamily(THEME.fontBody)
              .fontSize(12)
              .borderRadius(12)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => {
                this.shareActiveNoteAsPdf();
              });
            Button('删除')
              .backgroundColor(THEME.errorContainer)
              .fontColor(THEME.onErrorContainer)
              .fontFamily(THEME.fontBody)
              .fontSize(12)
              .borderRadius(12)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => {
                this.deleteActiveNote();
              });
            if (this.isNoteEditing) {
              Button('完成编辑')
                .backgroundColor(THEME.accent)
                .fontColor(THEME.onPrimary)
                .fontFamily(THEME.fontBody)
                .fontSize(12)
                .borderRadius(12)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .onClick(() => {
                  this.exitNoteEditMode();
                });
            } else {
              Button('编辑笔记')
                .backgroundColor(THEME.accent)
                .fontColor(THEME.onPrimary)
                .fontFamily(THEME.fontBody)
                .fontSize(12)
                .borderRadius(12)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .onClick(() => {
                  this.enterNoteEditMode();
                });
            }
          }
          .alignItems(VerticalAlign.Center);
        }
      }
      if (!this.hasActiveNote()) {
        Column() {
          Text('请选择一条笔记')
            .fontSize(14)
            .fontColor(THEME.inkMuted)
            .fontFamily(THEME.fontBody);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        if (this.isNoteEditing) {
          TextInput({ text: this.getActiveNoteTitle(), placeholder: '标题' })
            .fontSize(18)
            .fontFamily(THEME.fontTitle)
            .fontColor(THEME.ink)
            .backgroundColor(THEME.card)
            .border({ width: 1, color: THEME.border })
            .borderRadius(12)
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .onChange((value: string) => {
              this.updateActiveNote({ title: value });
            });
          TextInput({ text: this.getActiveNoteCategory(), placeholder: '分类' })
            .fontSize(14)
            .fontFamily(THEME.fontBody)
            .fontColor(THEME.ink)
            .backgroundColor(THEME.card)
            .border({ width: 1, color: THEME.border })
            .borderRadius(12)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onChange((value: string) => {
              this.updateActiveNote({ category: value });
            });
          Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row, justifyContent: FlexAlign.Start }) {
            this.EditorToolChip('[[ ]]', '[[链接]]');
            this.EditorToolChip('#', '# 标题');
            this.EditorToolChip('##', '## 小标题');
            this.EditorToolChip('Todo', '- [ ] 任务');
            this.EditorToolChip('-', '- 列表项');
            this.EditorToolChip('>', '> 引用');
            this.EditorToolChip('**', '**加粗**');
            this.EditorToolChip('` `', '`代码`');
            this.EditorActionChip('图片', () => {
              this.insertImageFromGallery();
            });
          }
          .width('100%');
          Row({ space: 8 }) {
            TextInput({ text: this.newTagText, placeholder: '新增标签' })
              .fontSize(12)
              .fontFamily(THEME.fontBody)
              .backgroundColor(THEME.card)
              .border({ width: 1, color: THEME.border })
              .borderRadius(10)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .layoutWeight(1)
              .onChange((value: string) => {
                this.newTagText = value;
              });
            Button('添加标签')
              .backgroundColor(THEME.accentSoft)
              .fontColor(THEME.ink)
              .fontFamily(THEME.fontBody)
              .fontSize(12)
              .borderRadius(10)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => {
                this.addTagToActiveNote();
              });
          }
          Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
            ForEach(this.getActiveNoteTags(), (tag: string, index: number) => {
              Text(tag)
                .fontSize(11)
                .fontColor(THEME.inkMuted)
                .fontFamily(THEME.fontBody)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(THEME.cardAlt)
                .borderRadius(10)
                .border({ width: 1, color: THEME.border })
                .margin({ right: 6, bottom: 6 });
            }, (tag: string, index: number) => `${this.getActiveNoteId()}-tag-${index}`);
          }
          .margin({ bottom: 8 });
          TextArea({ text: this.getActiveNoteBody(), placeholder: '开始书写...' })
            .fontSize(13)
            .fontFamily(THEME.fontBody)
            .fontColor(THEME.ink)
            .backgroundColor(THEME.card)
            .border({ width: 1, color: THEME.border })
            .borderRadius(12)
            .padding(12)
            .layoutWeight(1)
            .width('100%')
            .onChange((value: string) => {
              this.updateActiveNote({ body: value });
            });
        } else {
          Column({ space: 8 }) {
            Text(this.getActiveNoteTitle())
              .fontSize(22)
              .fontFamily(THEME.fontTitle)
              .fontColor(THEME.ink)
              .width('100%');
            Text(`[分类] ${this.getActiveNoteCategory()}  |  更新 ${this.getActiveNoteUpdatedAt()}`)
              .fontSize(11)
              .fontFamily(THEME.fontBody)
              .fontColor(THEME.inkMuted)
              .width('100%');
            Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
              ForEach(this.getActiveNoteTags(), (tag: string, index: number) => {
                Text(tag)
                  .fontSize(11)
                  .fontColor(THEME.inkMuted)
                  .fontFamily(THEME.fontBody)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor(THEME.cardAlt)
                  .borderRadius(10)
                  .border({ width: 1, color: THEME.border })
                  .margin({ right: 6, bottom: 6 });
              }, (tag: string, index: number) => `${this.getActiveNoteId()}-view-tag-${index}`);
            }
            .margin({ bottom: 6 })
            .width('100%');
            Scroll(this.previewScroller) {
              Column({ space: 10 }) {
                this.MarkdownPreview();
              }
              .padding(12)
              .width('100%')
              .id(`markdown-body-${this.getActiveNoteId()}-${this.previewBodySnapshot.length}`);
            }
            .id(`preview-${this.getActiveNoteId()}`)
            .backgroundColor(THEME.card)
            .border({ width: 1, color: THEME.border })
            .borderRadius(12)
            .layoutWeight(1)
            .width('100%');
          }
          .layoutWeight(1)
          .width('100%');
        }
        Column({ space: 8 }) {
          Text('当前链接')
            .fontSize(13)
            .fontFamily(THEME.fontBody)
            .fontColor(THEME.inkMuted);
          if (this.getActiveLinks().length === 0) {
            Text('暂无链接')
              .fontSize(12)
              .fontFamily(THEME.fontBody)
              .fontColor(THEME.inkMuted);
          } else {
            Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
              ForEach(this.getActiveLinks(), (link: string, index: number) => {
                Text(link)
                  .fontSize(11)
                  .fontFamily(THEME.fontBody)
                  .fontColor(THEME.accentDeep)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor(THEME.accentSoft)
                  .borderRadius(10)
                  .margin({ right: 6, bottom: 6 })
                  .onClick(() => {
                    this.openLinkedNote(link);
                  });
              }, (link: string, index: number) => `${this.getActiveNoteId()}-link-${index}`);
            }
          }
        }
      }
    }
    .padding(16)
    .backgroundColor(THEME.surfaceVariant)
    .borderRadius(THEME.radiusLarge)
    .border({ width: 1, color: THEME.outline })
    .shadow(THEME.elevation1)
    .height('100%');
  }

  @Builder
  private GraphPanel(): void {
    Column({ space: 12 }) {
      Text('图谱与反链')
        .fontSize(18)
        .fontFamily(THEME.fontTitle)
        .fontColor(THEME.ink);
      Row({ space: 8 }) {
        Button('-')
          .fontFamily(THEME.fontBody)
          .fontSize(13)
          .fontColor(THEME.ink)
          .backgroundColor(THEME.card)
          .border({ width: 1, color: THEME.border })
          .borderRadius(10)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick(() => {
            this.decreaseGraphZoom();
          });
        Text(`缩放 ${Math.round(this.graphZoom * 100)}%`)
          .fontSize(12)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.inkMuted)
          .layoutWeight(1);
        Button('+')
          .fontFamily(THEME.fontBody)
          .fontSize(13)
          .fontColor(THEME.ink)
          .backgroundColor(THEME.card)
          .border({ width: 1, color: THEME.border })
          .borderRadius(10)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick(() => {
            this.increaseGraphZoom();
          });
        Button(this.graphFocusedNoteId.length === 0 ? '聚焦: 全部' : '取消聚焦')
          .fontFamily(THEME.fontBody)
          .fontSize(12)
          .fontColor(THEME.ink)
          .backgroundColor(THEME.accentSoft)
          .borderRadius(10)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick(() => {
            if (this.graphFocusedNoteId.length === 0) {
              this.graphFocusedNoteId = this.activeNoteId;
            } else {
              this.graphFocusedNoteId = '';
            }
          });
        Button('重排图谱')
          .fontFamily(THEME.fontBody)
          .fontSize(12)
          .fontColor(THEME.ink)
          .backgroundColor(THEME.cardAlt)
          .border({ width: 1, color: THEME.border })
          .borderRadius(10)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .onClick(() => {
            this.graphNodePositions = {};
            this.physicsNodes = {};
            this.physicsAlpha = 1;
            this.initForceDirectedLayout();
            this.resetGraphView();
          });
      }
      Stack() {
        Stack() {
          ForEach(this.getGraphVisibleEdges(), (edge: GraphEdge, index: number) => {
            Line()
              .width(2000)
              .height(2000)
              .startPoint([this.getNodePos(edge.fromId).x, this.getNodePos(edge.fromId).y])
              .endPoint([this.getNodePos(edge.toId || '').x, this.getNodePos(edge.toId || '').y])
              .stroke((this.graphFocusedNoteId === edge.fromId || this.graphFocusedNoteId === edge.toId) ? THEME.accentDeep : THEME.border)
              .strokeWidth((this.graphFocusedNoteId === edge.fromId || this.graphFocusedNoteId === edge.toId) ? 2 : 1)
              .opacity(this.graphFocusedNoteId.length > 0 ? 0.8 : 0.4);
          }, (edge: GraphEdge, index: number) => `edge-${edge.fromId}-${edge.toTitle}-${index}-${this.draggingNodeId}`);
          
          ForEach(this.getGraphVisibleNotes(), (note: Note, index: number) => {
            Column({ space: 4 }) {
              Circle({ width: 12 + this.getNodeDegree(note.id) * 3, height: 12 + this.getNodeDegree(note.id) * 3 })
                .fill(note.id === this.graphFocusedNoteId ? THEME.accentDeep : (note.id === this.activeNoteId ? THEME.accent : THEME.inkMuted))
                .opacity(note.id === this.graphFocusedNoteId || note.id === this.activeNoteId ? 1 : 0.8);
              
              Text(note.title)
                .fontSize(10)
                .fontFamily(THEME.fontBody)
                .fontColor(note.id === this.activeNoteId ? THEME.ink : THEME.inkMuted)
                .opacity(this.graphZoom < 0.6 && note.id !== this.activeNoteId && note.id !== this.graphFocusedNoteId ? 0 : 1)
            }
            .position({
              x: this.getNodePos(note.id).x - 50,
              y: this.getNodePos(note.id).y - (12 + this.getNodeDegree(note.id) * 3) / 2
            })
            .width(100)
            .onClick(() => {
              this.toggleGraphFocus(note.id);
            })
            .gesture(
              PanGesture()
                .onActionStart(() => {
                  this.isDraggingNode = true;
                  this.draggingNodeId = note.id;
                  this.dragLastOffsetX = 0;
                  this.dragLastOffsetY = 0;
                  const p = this.physicsNodes[note.id];
                  if (p) {
                    this.dragStartX = p.x;
                    this.dragStartY = p.y;
                    p.vx = 0;
                    p.vy = 0;
                  }
                  this.wakePhysics();
                })
                .onActionUpdate((e) => {
                  const p = this.physicsNodes[note.id];
                  if (p) {
                    p.x = this.dragStartX + e.offsetX / this.graphZoom;
                    p.y = this.dragStartY + e.offsetY / this.graphZoom;
                    const deltaX = (e.offsetX - this.dragLastOffsetX) / this.graphZoom;
                    const deltaY = (e.offsetY - this.dragLastOffsetY) / this.graphZoom;
                    p.vx = deltaX * 0.6;
                    p.vy = deltaY * 0.6;
                  }
                  this.dragLastOffsetX = e.offsetX;
                  this.dragLastOffsetY = e.offsetY;
                  this.wakePhysics();
                })
                .onActionEnd(() => {
                  const p = this.physicsNodes[note.id];
                  if (p) {
                    p.vx *= 1.2;
                    p.vy *= 1.2;
                  }
                  this.isDraggingNode = false;
                  this.draggingNodeId = '';
                  this.wakePhysics();
                })
            );
          }, (note: Note) => `node-${note.id}-${this.draggingNodeId}`);
        }
        .width(2000)
        .height(2000)
        .position({ x: -1000, y: -1000 })
        .translate({
          x: 1000 + this.graphPanBase.x + this.graphPanOffset.x,
          y: 1000 + this.graphPanBase.y + this.graphPanOffset.y
        })
        .scale({ x: this.graphZoom, y: this.graphZoom, centerX: 1000, centerY: 1000 });
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(THEME.canvas)
      .borderRadius(12)
      .border({ width: 1, color: THEME.border })
      .clip(true)
      .gesture(
        PanGesture()
          .onActionStart(() => {
            if (this.isDraggingNode) {
              return;
            }
            this.graphPanOffset = { x: 0, y: 0 };
          })
          .onActionUpdate((e) => {
            if (this.isDraggingNode) {
              return;
            }
            this.graphPanOffset = { x: e.offsetX, y: e.offsetY };
          })
          .onActionEnd(() => {
            if (this.isDraggingNode) {
              return;
            }
            this.graphPanBase = {
              x: this.graphPanBase.x + this.graphPanOffset.x,
              y: this.graphPanBase.y + this.graphPanOffset.y
            };
            this.graphPanOffset = { x: 0, y: 0 };
          })
      );
    }
    .padding(16)
    .backgroundColor(THEME.surfaceVariant)
    .borderRadius(THEME.radiusLarge)
    .border({ width: 1, color: THEME.outline })
    .shadow(THEME.elevation1)
    .height('100%');
  }

  @Builder
  private TopBar(): void {
    Row({ space: 12 }) {
      if (this.activeVaultId !== '') {
        Button('<')
          .backgroundColor(THEME.surfaceVariant)
          .fontColor(THEME.ink)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .width(36)
          .height(36)
          .borderRadius(18)
          .border({ width: 1, color: THEME.outline })
          .stateEffect(true)
          .onClick(() => {
            animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
              this.activeVaultId = '';
            });
          });
      }
      Column({ space: 4 }) {
        Text(this.activeVaultId === '' ? 'Obsidian Lite' : (this.vaults.find(v => v.id === this.activeVaultId)?.name || '未命名知识库'))
          .fontSize(22)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink);
        Text('轻量笔记 · 本地保存')
          .fontSize(12)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.inkMuted);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Row({ space: 8 }) {
        if (this.activeVaultId !== '') {
          Button('今日笔记')
            .backgroundColor(THEME.primaryContainer)
            .fontColor(THEME.onPrimaryContainer)
            .fontFamily(THEME.fontBody)
            .fontSize(12)
            .borderRadius(THEME.radiusMedium)
            .border({ width: 1, color: THEME.primaryContainer })
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .stateEffect(true)
            .onClick(() => {
              this.openDailyNote();
            });
        }
      }
    }
    .padding({ left: 12, right: 16, top: 6, bottom: 6 })
    .backgroundColor(THEME.surface)
    .borderRadius(THEME.radiusLarge)
    .border({ width: 1, color: THEME.outline })
    .shadow(THEME.elevation2);
  }

  private getEdgeLabel(edge: GraphEdge): string {
    const reverseKey = `${edge.toTitle}->${edge.fromTitle}`;
    const edges = this.getGraphEdges();
    const isBidirectional = edges.some(item => {
      return `${item.fromTitle}->${item.toTitle}` === reverseKey;
    });
    return `${edge.fromTitle} -> ${edge.toTitle}${isBidirectional ? ' (双向)' : ''}`;
  }

  @Builder
  private VaultEditorPage(): void {
    Column() {
      Column({ space: 10 }) {
        Text(this.editingVaultId.length === 0 ? '创建知识库' : '编辑知识库')
          .fontSize(24)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink);
        Text('名称和说明会展示在知识库卡片上')
          .fontSize(12)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.inkMuted)
          .margin({ bottom: 6 });
        TextInput({ text: this.draftVaultName, placeholder: '输入知识库名称' })
          .fontSize(17)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink)
          .backgroundColor(THEME.card)
          .border({ width: 1, color: THEME.border })
          .borderRadius(12)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onChange((value: string) => {
            this.draftVaultName = value;
          });
        TextArea({ text: this.draftVaultDescription, placeholder: '输入卡片描述，例如：点击以管理该知识库内的笔记' })
          .fontSize(13)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.ink)
          .backgroundColor(THEME.card)
          .border({ width: 1, color: THEME.border })
          .borderRadius(12)
          .padding(12)
          .height(120)
          .onChange((value: string) => {
            this.draftVaultDescription = value;
          });
        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .backgroundColor(THEME.cardAlt)
            .fontColor(THEME.ink)
            .fontFamily(THEME.fontBody)
            .fontSize(13)
            .borderRadius(12)
            .border({ width: 1, color: THEME.border })
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => {
              this.closeVaultEditorPage();
            });
          Button(this.editingVaultId.length === 0 ? '创建' : '保存')
            .layoutWeight(1)
            .backgroundColor(THEME.accent)
            .fontColor(THEME.onPrimary)
            .fontFamily(THEME.fontBody)
            .fontSize(13)
            .borderRadius(12)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => {
              this.confirmVaultEditor();
            });
        }
      }
      .padding(16)
      .backgroundColor(THEME.surface)
      .borderRadius(THEME.radiusLarge)
      .border({ width: 1, color: THEME.outline })
      .shadow(THEME.elevation3);
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#CCF5F6FA');
  }

  @Builder
  private CreateNotePage(): void {
    Column() {
      Column({ space: 10 }) {
        Text('创建笔记')
          .fontSize(24)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink);
        Text('填写标题、分类、正文与标签后创建')
          .fontSize(12)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.inkMuted)
          .margin({ bottom: 6 });
        TextInput({ text: this.draftTitle, placeholder: '输入笔记标题' })
          .fontSize(17)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink)
          .backgroundColor(THEME.card)
          .border({ width: 1, color: THEME.border })
          .borderRadius(12)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onChange((value: string) => {
            this.draftTitle = value;
          });
        TextInput({ text: this.draftCategory, placeholder: '输入分类（如：日常、知识库等）' })
          .fontSize(13)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.accentDeep)
          .backgroundColor(THEME.card)
          .border({ width: 1, color: THEME.border })
          .borderRadius(12)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onChange((value: string) => {
            this.draftCategory = value;
          });
        TextArea({ text: this.draftBody, placeholder: '输入内容...' })
          .fontSize(13)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.ink)
          .backgroundColor(THEME.card)
          .border({ width: 1, color: THEME.border })
          .borderRadius(12)
          .padding(12)
          .height(300)
          .onChange((value: string) => {
            this.draftBody = value;
          });
        TextInput({ text: this.draftTagsText, placeholder: '标签（逗号分隔）' })
          .fontSize(12)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.ink)
          .backgroundColor(THEME.card)
          .border({ width: 1, color: THEME.border })
          .borderRadius(12)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .onChange((value: string) => {
            this.draftTagsText = value;
          });
        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .backgroundColor(THEME.cardAlt)
            .fontColor(THEME.ink)
            .fontFamily(THEME.fontBody)
            .fontSize(13)
            .borderRadius(12)
            .border({ width: 1, color: THEME.border })
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => {
              this.closeCreateNotePage();
            });
          Button('创建并进入')
            .layoutWeight(1)
            .backgroundColor(THEME.accent)
            .fontColor(THEME.onPrimary)
            .fontFamily(THEME.fontBody)
            .fontSize(13)
            .borderRadius(12)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => {
              this.confirmCreateNote();
            });
        }
      }
      .padding(16)
      .backgroundColor(THEME.surface)
      .borderRadius(THEME.radiusLarge)
      .border({ width: 1, color: THEME.outline })
      .shadow(THEME.elevation3);
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#CCF5F6FA');
  }

  @Builder
  private BackgroundLayer(): void {
    Blank()
      .width('90%')
      .height(220)
      .backgroundColor(THEME.surfaceVariant)
      .borderRadius(48)
      .position({ x: 20, y: -30 })
      .opacity(0.5);
    Blank()
      .width(160)
      .height(160)
      .backgroundColor(THEME.primaryContainer)
      .borderRadius(90)
      .position({ x: -40, y: 120 })
      .opacity(0.45);
    Blank()
      .width(120)
      .height(120)
      .backgroundColor(THEME.primary)
      .borderRadius(32)
      .position({ x: 260, y: 540 })
      .opacity(0.12);
  }

  build() {
    Stack() {
      this.BackgroundLayer();
      Column({ space: 16 }) {
        this.TopBar();
        if (this.activeVaultId === '') {
          this.VaultsPanel();
        } else {
          if (this.isCompact) {
          Row({ space: 10 }) {
            this.SegmentButton('笔记', 'library');
            this.SegmentButton('图谱', 'graph');
          }
          .padding({ left: 8, right: 8 })
          .justifyContent(FlexAlign.Center);
          if (this.compactPanel === 'library') {
            if (this.showSelectedNoteInCompact) {
              Column() { this.NotePanel(); }.layoutWeight(1);
            } else {
              Column() { this.LibraryPanel(); }.layoutWeight(1);
            }
          } else {
            Column() { this.GraphPanel(); }.layoutWeight(1);
          }
        } else {
          Row({ space: 14 }) {
            Column() {
              this.LibraryPanel();
            }
            .layoutWeight(0.32)
            .height('100%');
            Column() {
              this.NotePanel();
            }
            .layoutWeight(0.44)
            .height('100%');
            Column() {
              this.GraphPanel();
            }
            .layoutWeight(0.24)
            .height('100%');
          }
          .layoutWeight(1);
        }
        }
      }
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .width('100%')
      .height('100%');
      if (this.showVaultEditorPage) {
        this.VaultEditorPage();
      }
      if (this.showCreateNotePage && this.activeVaultId !== '') {
        this.CreateNotePage();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(THEME.canvas)
    .onAreaChange((oldValue, newValue) => {
      this.isCompact = newValue.width < 720;
    });
  }
}