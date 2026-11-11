<div align="center">

<img src="assets/banner.png" width="760" alt="tern-omp-usage: omp 経由の Claude と Codex の上限を Tern のステータスラインに表示">

[![check](https://github.com/joaodutra88/tern-omp-usage/actions/workflows/check.yml/badge.svg)](https://github.com/joaodutra88/tern-omp-usage/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/joaodutra88/tern-omp-usage?style=flat)](https://github.com/joaodutra88/tern-omp-usage/stargazers)
[![Latest release](https://img.shields.io/github/v/release/joaodutra88/tern-omp-usage)](https://github.com/joaodutra88/tern-omp-usage/releases/latest)

[omp](https://omp.sh) ユーザー向けの [Tern](https://stencil.so/tern) ステータスラインプラグインです。Claude と Codex のサブスクリプション上限、今週の支出予算、今日のトークン数とコストを、1 行で画面に表示し続けます。今日のコストをクリックすると、過去 7 日間のダッシュボードが開きます。

**[インストール](#インストール)** · **[各表示の意味](#各表示の意味)** · **[設定](#設定)** · **[FAQ](#faq)** · **[コントリビュート](#コントリビュート)**

[English](README.md) | [Português](README.pt-BR.md) | [Español](README.es.md) | [简体中文](README.zh-CN.md) | **日本語**

> この日本語版は参考訳です。英語版 README.md が正であり、内容が異なる場合は英語版が優先されます。

<img src="assets/statusline.png" alt="Tern ステータスラインの Claude と Codex の使用量">

</div>

## わかること

すべてステータスラインに表示されるので、作業しながら答えを確認できます。

- **今日、重い処理を実行する余裕はあるか?** 週の作業日予算です。平日ごとに週間クォータの 20% が解放され、祝日分の枠は繰り越されます。
- **今日はいくらかかったか?** 深夜 0 時以降のトークン数と API 価格ベースのコストです。omp が追跡するすべてのプロバイダーが対象です。ダッシュボードでは過去 7 日間と今月の分も確認できます。
- **保存済みのリセットはあるか?** Claude と Codex の保存済み使用量上限リセットを表示します。
- **いつ使い切るか?** 現在のペースで、5h または週のウィンドウがロックされるまでの時間を、それがリセットより先に来る場合に表示します。ウィンドウが 80% に達したとき、ロックされたとき、再び解放されたときにはトーストで通知します。
- **Claude と Codex を並べて表示。** どちらも omp 経由で読み取るため、新たにサインインする必要はありません。

## 各表示の意味

| 見た目 | 意味 |
|---|---|
| <img src="assets/seg-window.png" height="28" alt="5h window"> | 1 つのウィンドウの使用量: 5h、週 (`wk`)、そしてプランに含まれる場合は Fable。各ドットは緑から赤までの独自の色を持ち、パーセンテージは最後に到達したドットの色になります。80%(変更可能)に達すると、パーセンテージは点滅する赤いバッジに変わります。 |
| <img src="assets/seg-reset.png" height="28" alt="reset countdown"> | Claude の 5h ウィンドウがリセットされるまでの時間。30 分未満で、かつ 5h ウィンドウが 80% 以上のとき緑になります。救済が近いことを示します。 |
| `⏳23m` | Claude の 5h または `wk` バーのすぐ後ろに表示されます。そのウィンドウが始まってからの平均ペースで進むと、リセットより前にこの時間で使い切ります。使用量が 50% 以上になると表示されます。アラートはトーストで届きます: ウィンドウが赤いバッジのしきい値に達したとき、ロックされたとき、再び解放されたときです。 |
| <img src="assets/seg-credits.png" height="28" alt="saved resets"> | 保存済みの使用量上限リセット。 |
| <img src="assets/seg-budget.png" height="28" alt="work-week budget"> | 作業週の予算。現在の 7 日間ウィンドウのうち、各作業日(変更しない限り月曜から金曜)が週間クォータの均等な割合を解放します。5 日なら 20% ずつです。`left` は解放済みでまだ使っていないクォータです。`over`(点滅する赤)は、週のペースより先に使いすぎていることを意味します。 |
| <img src="assets/seg-codex.png" height="28" alt="Codex"> | Codex。`×2` は連携済みアカウントの数で、ウィンドウは使い切られたアカウントの割合を示します。 |
| <img src="assets/seg-today.png" height="28" alt="today's tokens and cost"> | 深夜 0 時(ローカル時間)以降のトークン数と API 価格ベースのコスト。すべてのプロバイダーが対象で、`omp stats` から取得します。キャッシュ読み取りもトークンに含まれるため、この数値の大部分はキャッシュです。クリックするとダッシュボードが開きます。 |
| <img src="assets/seg-refresh.png" height="28" alt="refresh"> | 今すぐ更新。使用量のほかのどのセグメントをクリックしても同じ動作になります。 |

### ダッシュボード

**OMP usage: dashboard**(または今日のトークン数かコストのクリック)で、今いるペインの隣にペインが開きます。`omp usage --history` から取得した過去 7 日間の Claude と Codex の 5h・週の使用量を 1 時間ごとに表示し、今日、過去 7 日間、今月の API 価格ベースのコストを日ごとのバー付きで表示します。`r` を押すと履歴を読み直します。

`omp stats` は約 1 日前までしか遡れないため、プラグインが各日の合計を自分で保存します。週と月の集計は、0.4.0 をインストールした日から埋まっていきます。

## 週の経過に伴う表示の変化

これらは用意された `omp` の応答から描画したもので、毎日は起きない状態も確認できます。

**静かな朝。** すべて緑で、予算も十分にあります。

<p align="center"><img src="assets/state-calm.png" alt="calm"></p>

**使用量の上昇。** ウィンドウが 5 分前の読み取りから 3 ポイント以上上がると `↑` が表示されます。

<p align="center"><img src="assets/state-rising.png" alt="rising"></p>

**5h ウィンドウが高止まり。** 86% になるとパーセンテージは赤いバッジになり、救済まで 21 分なのでリセット表示が緑になります。

<p align="center"><img src="assets/state-hot.png" alt="hot"></p>

**週のペースより先行。** 週の 65% を使ったのに解放済みは 40% だけです。`over 25%` は次の平日が追いつくまで点滅します。

<p align="center"><img src="assets/state-over.png" alt="over budget"></p>

**ロック中。** 100% のウィンドウは、解放までの時間と保存済みリセットを示す点滅バッジを表示します。

<p align="center"><img src="assets/state-locked.gif" alt="locked"></p>

## インストール

```sh
tern plugin install https://github.com/joaodutra88/tern-omp-usage
```

Anthropic と / または OpenAI Codex に `omp` でサインインしておく必要があります。ターミナルで `omp usage` が動作することを確認してください。このプラグインは Tern が管理する omp (Windows では `%LOCALAPPDATA%\Tern\omp\bin\omp.exe`、macOS では `~/Library/Application Support/Tern/omp/bin/omp`) を使用し、見つからない場合は `PATH` 上の `omp` にフォールバックします。Tern のデーモンが見つけられない場合は、`OMP_USAGE_BIN` にフルパスを設定してください。

### アップデート

プラグインは 1 日に 1 回、GitHub に新しいリリースがあるか確認します。ある場合は、セグメントの先頭に青い `⬆ 0.5.0` が表示され、トーストで一度だけ通知されます。それをクリックするか **OMP usage: update to the latest version** を実行すると、プラグインはこのリポジトリから自身を再インストールします(`tern plugin install … --force`)。設定と `extras.luau` は引き継がれます。アップデート後はトーストが新しいバージョンを知らせ、**OMP usage: what's new** でそのリリースノートが開きます。

リンクしたチェックアウト(`tern plugin link`)は、代わりに `git pull` で更新します。確認を止めるには、`updates` 表示を非表示にする([設定](#設定) を参照)か、`OMP_USAGE_NO_UPDATE_CHECK=1` を設定してください。

**0.3.x をお使いですか?** これらのバージョンには更新確認がありません。上のインストールコマンドを `--force` 付きで一度実行すれば、0.4.0 以降はプラグイン自身が知らせてくれます。

リリースをメールでも受け取るには、このリポジトリ上部の **Watch → Custom → Releases** を使ってください。

### AI エージェントでインストールする

omp、Claude Code、Codex、またはコマンドを実行できる任意のエージェントに、次を貼り付けます:

```text
Install the Tern plugin https://github.com/joaodutra88/tern-omp-usage for me.
1. Check `omp usage --json -p anthropic` (or `-p openai-codex`) works. If it doesn't, help me sign in with omp first.
2. Run `tern plugin install https://github.com/joaodutra88/tern-omp-usage`.
3. Run `tern plugin list --json` and confirm `omp-usage` has status "ready".
4. If it isn't ready, read the lines containing `omp-usage` in Tern's log
   (`%LOCALAPPDATA%\Tern\Logs\tern.log` on Windows) and the repo's AGENTS.md, then tell me what is wrong.
5. Explain what each part of the status line means, using the README.
```

## 実行するもの、触れるもの

このプラグインは認証情報を読み取りません。omp を実行するほか、独自のネットワークリクエストを 1 つだけ行います:

| コマンド | 実行タイミング |
|---|---|
| `omp usage --json -p anthropic` | 5 分ごと。Anthropic の使用量エンドポイントは約 5 分未満だと 429 を返します。 |
| `omp usage --json -p openai-codex` | 5 分ごと |
| `omp stats --json` | 5 分ごと |
| `omp usage --history --json --days 7` | ダッシュボードを開いたときと、その中で `r` を押したとき |
| `omp usage invalidate` | セグメントをクリックしたとき。omp のキャッシュを回避するため |
| `GET api.github.com/repos/joaodutra88/tern-omp-usage/releases/latest` | マシンごとに 1 日 1 回、トークンなし。`updates` 表示または `OMP_USAGE_NO_UPDATE_CHECK=1` でオフ |
| `tern plugin install https://github.com/joaodutra88/tern-omp-usage --force` | `⬆` をクリックするか、更新コマンドを実行したときのみ |

設定、各日のトークン数とコスト(ダッシュボード用)、最後に確認したリリース、`extras.luau` のコピー(アップデート前に作成)は、プラグインのデータフォルダ(`tern.kv`)に保存され、それ以外の場所には書き込みません。Tern はフォーマッタに 4 ms しか与えないため、ステータス表示のフォーマッタは上記の呼び出しでキャッシュされた値を読み取るだけです。

## 設定

コマンドパレットを開いて `OMP usage` と入力します。設定はプラグインのデータフォルダに保存されるため、アップデートや再インストールをしても保持されます。

| コマンド | 動作 |
|---|---|
| **OMP usage: show or hide a part…** | 表示をオン・オフする部分を入力します: `claude`、`codex`、`today`、`cost`、`budget`、`reset`、`credits`、`fable`、`forecast`(`⏳`)、`alerts`(トースト)、`updates`。 |
| **OMP usage: language…** | `en`、`pt-BR`、`es`、`zh-CN`、`ja`、`de`、`fr`。 |
| **OMP usage: work days per week…** | 月曜から数えて何日が週間クォータを解放するか。既定の `5` は月曜から金曜で、1 日 20% ずつです。 |
| **OMP usage: red badge threshold…** | ウィンドウが点滅する赤いバッジになるパーセンテージ(既定値 80)。 |
| **OMP usage: reset settings** | 既定値に戻します。 |
| **OMP usage: check for updates** | `updates` を非表示にしていても、今すぐ GitHub に確認します。 |
| **OMP usage: dashboard** | ダッシュボードを開きます。このウィンドウにすでにある場合はそこにフォーカスします。 |
| **OMP usage: what's new** | 実行中のバージョンのリリースノートを開きます。 |

Tern のデーモンが `omp` を見つけられない場合は、環境変数 `OMP_USAGE_BIN` にフルパスを設定してください。色は `window.luau` の末尾にある通常の CSS で設定します。各セグメントは `#statusline .sl-plugin[title="plugin.omp-usage.<name>"]` です。

### 言語を変更する

プラグインに表示されるすべての語は `labels.luau` に、言語ごとに 1 つのテーブルとして定義されています。言語を追加するには、`en` をコピーして値を翻訳し、プルリクエストを開いてください。言語で省略されたキーは英語にフォールバックします。

### 独自のセグメント

`window.luau` と同じフォルダに `extras.luau` ファイルがあれば、プラグインはそれを読み込みます。Git はこのファイルを無視するため、個人用のセグメントがリポジトリに入ることはありません。アップデート時にはまずプラグインのデータフォルダにコピーされ、`window.luau` の隣のファイルがなくなった場合はプラグインがそのコピーを読み込みます:

```luau
local M = {}
function M.init(hidden, every) end -- register commands, timers, CSS
function M.segments(out, pane) end -- insert segments before the usage ones
return M
```

## FAQ

**`tern plugin list` でプラグインが `disabled` と表示される。**
Tern は、エラーを起こした、またはステータスフォーマッタが時間予算を超えたプラグインを無効にします。`tern plugin reload` を実行してから、Tern のログ(Windows では `%LOCALAPPDATA%\Tern\Logs\tern.log`)で `omp-usage` を含む行を探し、その行を添えて Issue を開いてください。

**バーに `✻ Claude ?` または `⬢ Codex ?` と表示される。**
直前の `omp usage` 呼び出しが失敗しています。ターミナルで `omp usage --json -p anthropic`(または `-p openai-codex`)が動作するか確認し、動作しなければ omp でサインインしてください。どのセグメントをクリックしても再試行されます。

**何も表示されない。**
ステータスラインがオンになっているか確認してください(Tern の設定で `"status_bar": true`)。オンなのに表示されない場合、Tern のデーモンが `omp` を見つけられていない可能性があります。`OMP_USAGE_BIN` にフルパスを設定し、Tern を再起動してください。

**数値が claude.ai より遅れている。**
同じ使用量エンドポイントから omp 経由で、5 分ごとに取得しているためです。Anthropic は頻繁なポーリングにレート制限をかけるため、この間隔にしています。セグメントをクリックすると、最新の値を強制的に読み取ります。

**今日のトークン数がなぜこんなに多いのか?**
エージェントの入力の大部分を占めるキャッシュ読み取りが含まれているためです。コストは、それらのトークンを API 価格で計算した金額であり、サブスクリプションの請求額ではありません。

**アップデートするには?**
青い `⬆` が表示されたらクリックするか、**OMP usage: update to the latest version** を実行してください。手動の場合: `tern plugin install https://github.com/joaodutra88/tern-omp-usage --force`。0.4.0 より前のバージョンには更新確認がなく、Windows では 0.4.0 の更新が "The process cannot access the file" で失敗するため、これらは一度だけ手動で更新してください。

**アンインストールするには?**
`tern plugin remove omp-usage` を実行してください。

## コントリビュート

このプロジェクトは MIT ライセンスのオープンソースです。使う、フォークする、変更する、配布する、いずれも自由です。Issue とプルリクエストは誰に対しても開かれています。

- `python scripts/check.py` は構文チェック、ユニットテスト、CSS とマニフェストのチェックを実行します。`--integration` は、記録した `omp` と GitHub の応答を使い、模擬 Tern の中でプラグイン全体を実行します。CI はすべての pull request で、この 2 つを Linux、Windows、macOS 上で実行します。`--tern` を付けると、お使いの Tern でプラグインを再読み込みし、そのログも確認します。
- AI エージェントを使っていますか? [AGENTS.md](AGENTS.md) を指定してください。間違えやすいルールと、適切なバグ報告の書き方を説明しています。
- 予定している内容と、変更が守るべきルールは [ROADMAP.md](ROADMAP.md)(英語)にあります。アイデアは [Discussions](https://github.com/joaodutra88/tern-omp-usage/discussions) へどうぞ。**good first issue** の付いた issue は最初の一歩に向いています。
- 詳細は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。参加者は全員 [行動規範](CODE_OF_CONDUCT.md) に従います。セキュリティの問題は [SECURITY.md](SECURITY.md) から報告してください。

## スター履歴

[![Star History Chart](https://api.star-history.com/svg?repos=joaodutra88/tern-omp-usage&type=Date)](https://star-history.com/#joaodutra88/tern-omp-usage&Date)
