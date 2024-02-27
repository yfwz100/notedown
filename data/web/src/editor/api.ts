export interface SearchOption {
  isCaseSensitive?: boolean;
  isWholeWord?: boolean;
  isRegexp?: boolean;
  selectHighlight?: boolean;
  highlightIndex?: number;
}

export interface ReplaceOption {
  isSingle: boolean;
  isRegexp: boolean;
}

export interface Editor {
  setContent(content: string): void;
  search(value: string, opt?: SearchOption): void;
  find(action: 'previous' | 'next'): void;
  replace(replaceValue: string, opt?: ReplaceOption): void;
  undo(): void;
  redo(): void;
  getMarkdown(): string;
}
