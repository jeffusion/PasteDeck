# 四语言术语表

## 翻译原则

- 英语是 canonical source，key 语义以英语列为准。
- 简体中文保持当前产品的简洁工具型语气。
- 日语优先采用 macOS 常见菜单和设置用语，不增加不必要敬语。
- 俄语按钮使用简洁动词，名词和数量由上下文及复数规则决定。
- `PasteDeck`、`iCloud`、`GitHub` 不翻译。

## 核心名词

| Key concept | English | 简体中文 | 日本語 | Русский |
| --- | --- | --- | --- | --- |
| Clipboard | Clipboard | 剪贴板 | クリップボード | Буфер обмена |
| Clipboard history | Clipboard History | 剪贴板历史 | クリップボード履歴 | История буфера обмена |
| All | All | 全部 | すべて | Все |
| Text | Text | 文本 | テキスト | Текст |
| Rich text | Rich Text | 富文本 | リッチテキスト | Форматированный текст |
| Image | Image | 图片 | 画像 | Изображение |
| File | File | 文件 | ファイル | Файл |
| Color | Color | 颜色 | カラー | Цвет |
| General | General | 通用 | 一般 | Основные |
| Privacy | Privacy | 隐私 | プライバシー | Конфиденциальность |
| Keyboard Shortcuts | Keyboard Shortcuts | 键盘快捷键 | キーボードショートカット | Сочетания клавиш |
| About | About | 关于 | 情報 | О приложении |
| Accessibility | Accessibility | 辅助功能 | アクセシビリティ | Универсальный доступ |
| Favorite | Favorite | 收藏 | お気に入り | Избранное |
| Pinned | Pinned | 已置顶 | ピン留め済み | Закреплено |
| Source | Source | 来源 | コピー元 | Источник |
| Unknown source | Unknown Source | 未知来源 | 不明なコピー元 | Неизвестный источник |
| Permanent | Forever | 永久 | 無期限 | Бессрочно |

## 核心动作

| Key concept | English | 简体中文 | 日本語 | Русский |
| --- | --- | --- | --- | --- |
| Search | Search | 搜索 | 検索 | Поиск |
| Clear search | Clear Search | 清除搜索 | 検索を消去 | Очистить поиск |
| Copy | Copy | 复制 | コピー | Копировать |
| Copy and Paste | Copy and Paste | 复制并粘贴 | コピーしてペースト | Копировать и вставить |
| Pin to Top | Pin to Top | 置顶 | 一番上にピン留め | Закрепить сверху |
| Unpin | Unpin | 取消置顶 | ピン留めを解除 | Открепить |
| Add to Favorites | Add to Favorites | 添加到收藏 | お気に入りに追加 | Добавить в избранное |
| Remove from Favorites | Remove from Favorites | 取消收藏 | お気に入りから削除 | Удалить из избранного |
| Delete | Delete | 删除 | 削除 | Удалить |
| Settings | Settings | 设置 | 設定 | Настройки |
| Quit | Quit | 退出 | 終了 | Завершить работу |
| Back | Back | 返回 | 戻る | Назад |
| Cancel | Cancel | 取消 | キャンセル | Отмена |
| Confirm | Confirm | 确认 | 確認 | Подтвердить |
| Done | Done | 完成 | 完了 | Готово |
| Open System Settings | Open System Settings | 打开系统设置 | システム設定を開く | Открыть Системные настройки |
| Reset to Defaults | Reset to Defaults | 重置为默认 | デフォルトに戻す | Восстановить настройки по умолчанию |

## 状态与空状态

| Key concept | English | 简体中文 | 日本語 | Русский |
| --- | --- | --- | --- | --- |
| No clipboard history | No Clipboard History | 暂无剪贴板历史 | クリップボード履歴はありません | История буфера обмена пуста |
| No results | No Results Found | 未找到结果 | 結果が見つかりません | Ничего не найдено |
| Authorized | Authorized | 已授权 | 許可済み | Доступ разрешён |
| Not authorized | Not Authorized | 未授权 | 未許可 | Доступ не разрешён |
| Waiting for authorization | Waiting for Authorization… | 正在等待授权… | 許可を待っています… | Ожидание разрешения… |
| Authorization successful | Authorization Successful | 授权成功 | 許可されました | Доступ разрешён |
| Not set | Not Set | 未设置 | 未設定 | Не задано |

## 格式与标点

- 英语使用 sentence case；菜单动作不加句号。
- 简体中文不在短按钮后加标点，说明文本使用全角中文标点。
- 日语说明文本使用 `。`，按钮和菜单不加句号。
- 俄语说明文本使用句号，按钮和菜单不加句号。
- 省略号统一使用 Unicode `…`，不使用三个英文句点 `...`；技术范围 `1...9` 除外。
- 数量、复数和单位不在代码中拼接，最终词形由 `Localizable.stringsdict` 决定。
