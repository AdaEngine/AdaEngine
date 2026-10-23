# Spine runtime visual preview

Export 240 real poses of the official Spineboy example with the new
`AdaSpineRuntime`, including skinned/clipped geometry and bone endpoints:

```powershell
$env:ADAENGINE_HEADLESS = '1'
swift run SpinePreview C:/path/to/spine-preview
python -m http.server 8769 --bind 127.0.0.1 --directory C:/path/to/spine-preview
```

Open `http://127.0.0.1:8769`. Select walk, run or jump; show the skeleton, pause,
change playback speed or scrub individual frames.

The Swift executable samples the production player. The browser only draws the
exported triangles and bone endpoints; it does not implement or imitate Spine
animation. This is a portable WebGL preview, **not proof of AdaEngine's native GPU
draw pass**. The production headless integration tests cover extraction and GPU
buffer preparation separately. See `Documentation/Spine2D.md` for engine usage.

The example character, skeleton and atlas are official Esoteric Software assets
from the pinned upstream commit. Source and license notices are included in the
exported preview directory. No generated animation data is checked into the repo.
