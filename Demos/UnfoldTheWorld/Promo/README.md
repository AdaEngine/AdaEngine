# Promo kit

- `unfold-promo.mp4`: 30-second branded 1080p clip.
- `unfold-demo.gif`: seven-second excerpt showing the map action.
- `unfold-cover.png`: a still from the clip.
- `unfold-raw-final.mp4`: the original window-only recording.
- `posts.md`: English X and Russian Telegram drafts.
- `validation.md` / `validation.json`: test and runtime evidence.

Rebuild the kit on macOS with Python 3 + Pillow and ffmpeg:

```sh
python3 render.py .
```

`render.py` draws typography cards and composites the original recording. It does not synthesize gameplay frames. The recording preserves one world while the preview folds and unfolds. No material has been posted publicly.
