# SKILL.md フロントマターへのhooks呼び出しタイミング定義 調査レポート

日時: 2026-04-27

## 対象範囲

- `skills/handover/SKILL.md`（現在の hooks: フロントマター実装）
- `hooks/stop-handover-reminder.sh`, `hooks/precompact-handover.sh`（フック本体）
- `install.sh`（フック依存解決ロジック）
- `~/.claude/settings.json`（現在の呼び出しタイミング設定）
- `~/.claude/plugins/` 配下のプラグイン（比較対象）

## アーキテクチャ概要

現在の仕組みは2ステップに分離している。

**ステップ1: install.sh によるシンボリックリンク生成**
`SKILL.md` フロントマターの `hooks:` フィールドをawkで解析し、リストされたスクリプト名を `~/.claude/hooks/` にシンボリックリンクする。このフィールドはファイル名のみ（例: `stop-handover-reminder.sh`）を含む。呼び出しタイミングの情報はない。

**ステップ2: settings.json による呼び出しタイミング設定**
Claude Codeは `settings.json` の `hooks` セクションを読んで、どのイベント（Stop, PreCompact等）でどのコマンドを実行するかを決定する。このファイルはinstall.shでは更新されない。ユーザーが手動で記述する必要がある。

```
SKILL.md hooks: フィールド
  → install.sh が解析
  → ~/.claude/hooks/*.sh にシンボリックリンク
  （ここで止まる。settings.json は更新されない）

settings.json hooks セクション
  → Claude Code が読み込む
  → Stop / PreCompact 等のイベントで実行
  （手動で記述する必要がある）
```

## プラグインシステムとの比較

Claude Code の公式プラグインシステムでは、`hooks/hooks.json` ファイル1つで呼び出しタイミングとコマンドを両方定義できる。

```json
{
  "description": "...",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/stop.sh\""
          }
        ]
      }
    ],
    "PreCompact": [...]
  }
}
```

Claude Code はプラグインが有効化されているとき `hooks/hooks.json` を自動的に読み込む。`settings.json` への追記は不要。`${CLAUDE_PLUGIN_ROOT}` 変数でプラグインディレクトリへの絶対パスを参照できる。

## 現在の SKILL.md `hooks:` フィールドの性質

vercel-labs/skills CLI（`npx skills`）を調査した結果、**このCLIはhooksフィールドを一切処理していない**。`hooks:` フロントマターはこのリポジトリの `install.sh` が独自に定義したカスタム規約であり、Claude Code本体も vercel-labs/skills も認識しない。

Claude Code はSKILL.md の内容をセッション開始時にテキストとして読み込むが、フロントマターを構造化データとして解析する機構は持っていない（agentの`description:`は例外）。

## 技術的可否の評価

### 方法A: SKILL.md フロントマターの拡張

現在:
```yaml
hooks:
  - stop-handover-reminder.sh
  - precompact-handover.sh
```

拡張案:
```yaml
hooks:
  - event: Stop
    command: stop-handover-reminder.sh
    timeout: 5
  - event: PreCompact
    command: precompact-handover.sh
    timeout: 10
```

**可否: 技術的には可能**。`install.sh` のawkパーサーを拡張してeventとcommandを読み取り、`settings.json` を `jq` で更新する処理を追加すれば実現できる。

制約:
- `settings.json` の更新処理を `install.sh` に追加する必要がある
- settings.json が存在しない場合・存在する場合の両方を安全に処理する必要がある
- 既存の `hooks:` リスト形式との後方互換性を考慮する必要がある
- vercel-labs/skills CLIはこの拡張を認識しないため、npx skills でインストールした場合はsettings.json更新が行われない

### 方法B: スキルディレクトリに hooks.json を追加

プラグインシステムと同じ構造をスキルに持ち込む。

```
skills/handover/
├── SKILL.md
└── hooks.json   ← 新規追加
```

`hooks.json` の内容:
```json
{
  "Stop": {
    "command": "stop-handover-reminder.sh",
    "timeout": 5
  },
  "PreCompact": {
    "command": "precompact-handover.sh",
    "timeout": 10
  }
}
```

`install.sh` がこれを読んで `settings.json` を更新する。

**可否: 技術的には可能**。方法Aより関心の分離が明確。SKILL.md フロントマターは「どのスクリプトをインストールするか」に専念し、hooks.json は「いつ実行するか」を定義する。

## 重要な発見

1. **Claude Code本体はSKILL.mdを構造化データとして処理しない**。フロントマターはスキルのメタデータとして存在するが、`hooks:` フィールドはClaude Codeが読むのではなく `install.sh` が読む。

2. **呼び出しタイミングの一元管理は install.sh の拡張で実現できる**。外部ツール（Claude Code本体、vercel-labs/skills）への依存なしに、このリポジトリ内で完結できる。

3. **プラグインシステムとの整合性**は方法Bのほうが高い。プラグインの `hooks/hooks.json` と同じ発想で `skills/<name>/hooks.json` を作れば、将来プラグイン化する際の移行コストが低い。

4. **settings.json 更新には冪等性が必要**。install.sh を複数回実行しても同じ結果になる設計が必要。`jq` で既存エントリを確認してから追加・上書きする処理が必要になる。

## 注意点・リスク

- `settings.json` は他のフック設定を既に含んでいる可能性があるため、上書きではなくマージが必要
- `jq` のインストールを前提とする（READMEには前提条件として既記載）
- フックスクリプトのパスを `~/.claude/hooks/` への絶対パスで書く必要がある（プラグインの `${CLAUDE_PLUGIN_ROOT}` に相当する変数は通常のhooksには存在しない）
- vercel-labs/skills でインストールする場合はsettings.json更新が行われないため、このルートを使うユーザーへの案内が必要
