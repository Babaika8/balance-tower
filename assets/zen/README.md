# Скин «Zen» — сюда кладутся картинки

Положи PNG-файлы в эту папку (`assets/zen/`). Игра подхватит их автоматически
при следующей сборке. Чего нет — заменяется текущим векторным видом.

## Какие файлы нужны

| Файл | Что это | Размер (рекомендация) | Фон |
|------|---------|------------------------|-----|
| `stone.png` | камень, который падает в башню | ~600×200, плоская галька (≈3:1) | прозрачный |
| `stone2.png` | ещё вариант камня (необязательно) | то же | прозрачный |
| `stone3.png` | ещё вариант (необязательно) | то же | прозрачный |
| `stone4.png` | ещё вариант (необязательно) | то же | прозрачный |
| `hand.png` | рука, держащая камень сверху | ~500×500 | прозрачный |
| `background.png` | фон-сцена (вертикальная) | 720×1280 или 1080×1920 | непрозрачный |
| `pedestal.png` | основание башни (необязательно) | ~600×200 | прозрачный |

Важно:
- **Камни и рука — обязательно с прозрачным фоном** (PNG с альфой), иначе будут
  квадраты вокруг.
- Камень рисуй **плоским и широким** (примерно втрое шире высоты) — так он
  ляжет ровно в физику.
- Минимум для теста: `stone.png` + `background.png`. Рука и постамент — бонус.

## Готовые промпты для нейросети (стиль 16-бит, как тебе понравилось)

Камень:
> 16-bit pixel art of a single smooth zen river stone, flat wide pebble seen
> from the side, soft top light, transparent background, game sprite, centered

Рука:
> 16-bit pixel art of a hand holding a small stone from above with fingers,
> transparent background, game sprite, facing down

Фон:
> 16-bit pixel art vertical background, calm Japanese zen garden at warm sunset,
> raked sand, distant pagoda, soft sky, no characters, mobile game background,
> 9:16

После генерации переименуй файлы как в таблице и положи сюда.
