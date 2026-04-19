type CompactPanel = 'library' | 'graph';

const NOTES_STORAGE_KEY: string = 'obsidian_lite_notes_json';

type InlineTokenKind = 'text' | 'bold' | 'code' | 'link';

interface InlineToken {
  kind: InlineTokenKind;
  text: string;
}

interface Note {
  id: string;
  title: string;
  body: string;
  tags: string[];
  updatedAt: string;
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

interface GraphPhysicsNode {
  x: number;
  y: number;
  vx: number;
  vy: number;
}

interface ThemeTokens {
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
}

const THEME: ThemeTokens = {
  canvas: '#F7F2EA',
  canvasTint: '#EFE5D8',
  ink: '#2B2724',
  inkMuted: '#6F655C',
  accent: '#F4A950',
  accentDeep: '#E76F51',
  accentSoft: '#FFE3BC',
  card: '#FFFFFF',
  cardAlt: '#FCF8F2',
  border: '#E3D5C4',
  fontTitle: 'Noto Serif SC',
  fontBody: 'HarmonyOS Sans'
};

const SAMPLE_NOTES: Note[] = [
  {
    id: 'n1',
    title: '欢迎来到轻量笔记',
    body: '# 你好，Obsidian Lite\n\n- 这是一个原型演示\n- 支持 **加粗** 与 `代码`\n- 试试 [[双向链接]] 与 [[标签系统]]\n\n> 记得保持专注与轻盈。\n',
    tags: ['入门', '体验'],
    updatedAt: '2026-04-19'
  },
  {
    id: 'n2',
    title: '标签系统',
    body: '## 标签是知识的抽屉\n\n- 标签帮助快速分类\n- 点击标签可筛选\n\n和 [[搜索技巧]] 配合更高效。',
    tags: ['方法', '系统'],
    updatedAt: '2026-04-18'
  },
  {
    id: 'n3',
    title: '双向链接',
    body: '## 让笔记彼此对话\n\n把相关概念连在一起：\n- [[标签系统]]\n- [[项目仪表盘]]\n\n> 反向链接会自动出现。',
    tags: ['知识网络'],
    updatedAt: '2026-04-18'
  },
  {
    id: 'n4',
    title: '搜索技巧',
    body: '### 全文搜索\n\n你可以搜索标题、正文与标签。\n\n试试搜索 **系统** 或 `链接`。',
    tags: ['方法'],
    updatedAt: '2026-04-17'
  },
  {
    id: 'n5',
    title: '项目仪表盘',
    body: '# 项目\n\n- 本周目标\n- 重要里程碑\n- 风险与阻塞\n\n相关笔记：[[双向链接]]',
    tags: ['项目', '看板'],
    updatedAt: '2026-04-17'
  },
  {
    id: 'n6',
    title: '每日回顾',
    body: '## 今日小结\n\n- 做得好的事\n- 想要改进的点\n- 明日计划\n\n连接到 [[项目仪表盘]]。',
    tags: ['复盘', '习惯'],
    updatedAt: '2026-04-16'
  }
];

@Entry
@Component
struct Index {
  @State notes: Note[] = SAMPLE_NOTES;
  @Watch('onActiveNoteIdChanged')
  @State activeNoteId: string = SAMPLE_NOTES[0].id;
  @State searchText: string = '';
  @State activeTag: string = '';
  @State showPreview: boolean = true;
  @State isCompact: boolean = true;
  @State compactPanel: CompactPanel = 'library';
  @State newTagText: string = '';
  @State showCreateNotePage: boolean = false;
  @State draftTitle: string = '';
  @State draftBody: string = '';
  @State draftTagsText: string = '';
  @State isNoteEditing: boolean = false;
  @State showSelectedNoteInCompact: boolean = false;
  @State previewBodySnapshot: string = SAMPLE_NOTES[0].body;
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

  aboutToAppear(): void {
    this.initializeNotesStorage();
    this.loadNotesFromStorage();
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

    this.notes.forEach(n1 => {
      this.notes.forEach(n2 => {
        if (n1.id === n2.id) {
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

    this.notes.forEach(n1 => {
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
    if (Object.keys(this.graphNodePositions).length === this.notes.length && Object.keys(this.physicsNodes).length === this.notes.length) {
      this.wakePhysics();
      return;
    }
    
    this.notes.forEach(n => {
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
    PersistentStorage.PersistProp(NOTES_STORAGE_KEY, JSON.stringify(SAMPLE_NOTES));
  }

  private loadNotesFromStorage(): void {
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
    this.notes = parsed;
    const exists = parsed.some(note => note.id === this.activeNoteId);
    this.activeNoteId = exists ? this.activeNoteId : parsed[0].id;
    this.syncPreviewSnapshotFromActive();
    this.initForceDirectedLayout();
  }

  private saveNotesToStorage(): void {
    const jsonText = JSON.stringify(this.notes);
    AppStorage.SetOrCreate<string>(NOTES_STORAGE_KEY, jsonText);
  }

  private parseStoredNotes(raw: string): Note[] {
    try {
      const parsed = JSON.parse(raw) as Note[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed.filter(item => this.isValidNote(item));
    } catch {
      return [];
    }
  }

  private isValidNote(note: Note): boolean {
    return typeof note.id === 'string' && typeof note.title === 'string' && typeof note.body === 'string'
      && Array.isArray(note.tags) && typeof note.updatedAt === 'string';
  }

  private getActiveNote(): Note | undefined {
    return this.notes.find(note => note.id === this.activeNoteId);
  }

  private getFilteredNotes(): Note[] {
    let result = this.notes;
    if (this.activeTag.trim().length > 0) {
      result = result.filter(note => note.tags.includes(this.activeTag));
    }
    const query = this.searchText.trim().toLowerCase();
    if (query.length > 0) {
      result = result.filter(note => {
        const inTitle = note.title.toLowerCase().includes(query);
        const inBody = note.body.toLowerCase().includes(query);
        const inTags = note.tags.some(tag => tag.toLowerCase().includes(query));
        return inTitle || inBody || inTags;
      });
    }
    return result;
  }

  private getAllTags(): string[] {
    const tagSet = new Set<string>();
    this.notes.forEach(note => note.tags.forEach(tag => tagSet.add(tag)));
    return Array.from(tagSet.values());
  }

  private updateActiveNote(patch: Partial<Note>): void {
    const index = this.notes.findIndex(note => note.id === this.activeNoteId);
    if (index < 0) {
      return;
    }
    const base = this.notes[index];
    const updated: Note = {
      id: base.id,
      title: patch.title ?? base.title,
      body: patch.body ?? base.body,
      tags: patch.tags ?? base.tags,
      updatedAt: this.formatDate(new Date())
    };
    const next = this.notes.slice();
    next[index] = updated;
    this.notes = next;
    this.saveNotesToStorage();
    this.initForceDirectedLayout();
  }

  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private createNote(title: string, body: string, tags: string[]): void {
    const id = `n${this.notes.length + 1}`;
    const newNote: Note = {
      id,
      title,
      body,
      tags,
      updatedAt: this.formatDate(new Date())
    };
    const next = this.notes.slice();
    next.unshift(newNote);
    this.notes = next;
    this.saveNotesToStorage();
    this.activeNoteId = id;
    this.previewBodySnapshot = body;
    this.compactPanel = 'library';
    this.showSelectedNoteInCompact = this.isCompact;
    this.isNoteEditing = false;
    this.initForceDirectedLayout();
  }

  private openCreateNotePage(): void {
    this.draftTitle = '';
    this.draftBody = '# 新建笔记\n\n- 写下你的想法\n- 用 [[链接]] 连接知识\n';
    this.draftTagsText = '';
    this.showCreateNotePage = true;
  }

  private closeCreateNotePage(): void {
    this.showCreateNotePage = false;
  }

  private openNoteFromLibrary(noteId: string): void {
    this.syncPreviewSnapshotById(noteId);
    this.activeNoteId = noteId;
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
  }

  private syncPreviewSnapshotFromActive(): void {
    const note = this.getActiveNote();
    this.previewBodySnapshot = note ? note.body : '';
  }

  private syncPreviewSnapshotById(noteId: string): void {
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
    const body = this.draftBody.trim().length > 0 ? this.draftBody : `# ${title}\n\n`;
    let tags = this.parseTagInput(this.draftTagsText);
    if (tags.length === 0) {
      tags = ['新建'];
    }
    this.createNote(title, body, tags);
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
    const titleMap = new Map<string, string>();
    this.notes.forEach(note => titleMap.set(note.title, note.id));
    const edges: GraphEdge[] = [];
    this.notes.forEach(note => {
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
    if (this.graphFocusedNoteId.length === 0) {
      return this.notes;
    }
    const related = this.getGraphRelatedIds(this.graphFocusedNoteId);
    return this.notes.filter(note => related.has(note.id));
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
    this.createNote(targetTitle, `# ${targetTitle}\n\n`, ['链接']);
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
  private MarkdownLine(line: string): void {
    if (this.lineStartsWith(line, '### ')) {
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
        ForEach(this.getMarkdownLines(this.previewBodySnapshot), (line: string, index: number) => {
          this.MarkdownLine(line);
        }, (line: string, index: number) => `${this.activeNoteId}-${index}-${line.length}`);
      }
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
  private NoteCard(note: Note, isActive: boolean): void {
    Column({ space: 6 }) {
      Text(note.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(THEME.ink)
        .fontFamily(THEME.fontTitle);
      Text(this.getExcerpt(note.body))
        .fontSize(12)
        .fontColor(THEME.inkMuted)
        .fontFamily(THEME.fontBody)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Row({ space: 6 }) {
        ForEach(note.tags, (tag: string, index: number) => {
          Text(tag)
            .fontSize(11)
            .fontColor(THEME.inkMuted)
            .fontFamily(THEME.fontBody)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(THEME.cardAlt)
            .borderRadius(10)
            .border({ width: 1, color: THEME.border });
        }, (tag: string, index: number) => `${note.id}-${index}`);
      }
      Text(`更新 ${note.updatedAt}`)
        .fontSize(10)
        .fontColor(THEME.inkMuted)
        .fontFamily(THEME.fontBody);
    }
    .padding(12)
    .backgroundColor(isActive ? THEME.accentSoft : THEME.card)
    .borderRadius(16)
    .border({ width: 1, color: isActive ? THEME.accent : THEME.border })
    .shadow({ radius: 8, color: '#14000000', offsetX: 0, offsetY: 4 })
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
    Column({ space: 12 }) {
      Text('笔记库')
        .fontSize(18)
        .fontFamily(THEME.fontTitle)
        .fontColor(THEME.ink);
      TextInput({ text: this.searchText, placeholder: '搜索标题 / 正文 / 标签' })
        .fontSize(13)
        .fontFamily(THEME.fontBody)
        .backgroundColor(THEME.card)
        .border({ width: 1, color: THEME.border })
        .borderRadius(12)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .onChange((value: string) => {
          this.searchText = value;
        });
      Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row, justifyContent: FlexAlign.Start }) {
        this.TagChip('全部', this.activeTag.length === 0, () => {
          this.activeTag = '';
        });
        ForEach(this.getAllTags(), (tag: string, index: number) => {
          this.TagChip(tag, this.activeTag === tag, () => {
            this.activeTag = this.activeTag === tag ? '' : tag;
          });
        }, (tag: string, index: number) => `tag-${index}`);
      }
      .width('100%');
      List({ space: 10 }) {
        ForEach(this.getFilteredNotes(), (note: Note) => {
          ListItem() {
            this.NoteCard(note, note.id === this.activeNoteId);
          }
        }, (note: Note) => note.id);
      }
      .width('100%')
      .layoutWeight(1);
    }
    .padding(16)
    .backgroundColor(THEME.cardAlt)
    .borderRadius(20)
    .border({ width: 1, color: THEME.border })
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 6 })
    .id(`note-panel-${this.getActiveNoteId()}-${this.isNoteEditing ? 'edit' : 'view'}`)
    .height('100%');
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
        Text('笔记详情')
          .fontSize(18)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink)
          .layoutWeight(1);
        if (this.hasActiveNote()) {
          if (this.isNoteEditing) {
            Button('完成编辑')
              .backgroundColor(THEME.accent)
              .fontColor(THEME.ink)
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
              .fontColor(THEME.ink)
              .fontFamily(THEME.fontBody)
              .fontSize(12)
              .borderRadius(12)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => {
                this.enterNoteEditMode();
              });
          }
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
            Text(`更新 ${this.getActiveNoteUpdatedAt()}`)
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
            Scroll() {
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
    .backgroundColor(THEME.cardAlt)
    .borderRadius(20)
    .border({ width: 1, color: THEME.border })
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 6 })
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
                  const p = this.physicsNodes[note.id];
                  if (p) {
                    this.dragStartX = p.x;
                    this.dragStartY = p.y;
                  }
                  this.wakePhysics();
                })
                .onActionUpdate((e) => {
                  const p = this.physicsNodes[note.id];
                  if (p) {
                    p.x = this.dragStartX + e.offsetX / this.graphZoom;
                    p.y = this.dragStartY + e.offsetY / this.graphZoom;
                  }
                  this.wakePhysics();
                })
                .onActionEnd(() => {
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
    .backgroundColor(THEME.cardAlt)
    .borderRadius(20)
    .border({ width: 1, color: THEME.border })
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 6 })
    .height('100%');
  }

  @Builder
  private TopBar(): void {
    Row() {
      Column({ space: 4 }) {
        Text('Obsidian Lite')
          .fontSize(22)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink);
        Text('轻量笔记 · 本地保存')
          .fontSize(12)
          .fontFamily(THEME.fontBody)
          .fontColor(THEME.inkMuted);
      }
      .layoutWeight(1);
      Row({ space: 8 }) {
        Button('新建笔记')
          .backgroundColor(THEME.accent)
          .fontColor(THEME.ink)
          .fontFamily(THEME.fontBody)
          .fontSize(12)
          .borderRadius(12)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.openCreateNotePage();
          });
      }
    }
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor(THEME.card)
    .borderRadius(16)
    .border({ width: 1, color: THEME.border })
    .shadow({ radius: 10, color: '#10000000', offsetX: 0, offsetY: 4 });
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
  private CreateNotePage(): void {
    Column() {
      Column({ space: 10 }) {
        Text('创建笔记')
          .fontSize(24)
          .fontFamily(THEME.fontTitle)
          .fontColor(THEME.ink);
        Text('填写标题、正文与标签后创建')
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
            .fontColor(THEME.ink)
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
      .backgroundColor(THEME.cardAlt)
      .borderRadius(18)
      .border({ width: 1, color: THEME.border })
      .shadow({ radius: 12, color: '#16000000', offsetX: 0, offsetY: 8 });
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#CCF7F2EA');
  }

  @Builder
  private BackgroundLayer(): void {
    Blank()
      .width('90%')
      .height(220)
      .backgroundColor(THEME.canvasTint)
      .borderRadius(40)
      .position({ x: 20, y: -30 })
      .opacity(0.8);
    Blank()
      .width(160)
      .height(160)
      .backgroundColor(THEME.accentSoft)
      .borderRadius(80)
      .position({ x: -40, y: 120 })
      .opacity(0.7);
    Blank()
      .width(120)
      .height(120)
      .backgroundColor(THEME.accent)
      .borderRadius(24)
      .position({ x: 260, y: 540 })
      .opacity(0.25);
  }

  build() {
    Stack() {
      this.BackgroundLayer();
      Column({ space: 16 }) {
        this.TopBar();
        if (this.isCompact) {
          Row({ space: 10 }) {
            this.SegmentButton('笔记', 'library');
            this.SegmentButton('图谱', 'graph');
          }
          .padding({ left: 8, right: 8 })
          .justifyContent(FlexAlign.Center);
          if (this.compactPanel === 'library') {
            if (this.showSelectedNoteInCompact) {
              this.NotePanel();
            } else {
              this.LibraryPanel();
            }
          } else {
            this.GraphPanel();
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
          .height('100%');
        }
      }
      .padding(16)
      .width('100%')
      .height('100%');
      if (this.showCreateNotePage) {
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