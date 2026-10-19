"""Create an offline gallery from the rendered Flutter settings screenshots."""
from pathlib import Path
from html import escape

root = Path(__file__).resolve().parent.parent
qa = root / '.project' / 'qa'
files = sorted((qa / 'screenshots').glob('settings-*.png'))
items = '\n'.join(
    f'<a class="shot" href="screenshots/{escape(image.name)}">'
    f'<img loading="lazy" src="screenshots/{escape(image.name)}" '
    f'alt="{escape(image.stem.replace("settings-", "").replace("-", " "))}">'
    f'<span>{escape(image.stem.replace("settings-", "").replace("-", " "))}</span></a>'
    for image in files
)
(qa / 'settings-pages.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Lumi implemented settings pages</title><style>body{margin:0;background:#f4f1e8;color:#292d28;font:16px system-ui,sans-serif;padding:32px}h1{font:36px Georgia,serif;margin-bottom:12px}p{max-width:760px;line-height:1.6}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:24px;margin-top:32px}.shot{display:flex;flex-direction:column;background:#fffcf5;color:inherit;border:1px solid #ddd7c9;border-radius:12px;overflow:hidden;text-decoration:none}.shot img{width:100%;height:320px;object-fit:contain;background:#eae6da}.shot span{padding:16px;text-transform:capitalize}a:focus-visible{outline:3px solid #667a5e;outline-offset:4px}@media(max-width:500px){body{padding:20px}.grid{grid-template-columns:1fr}}</style><h1>Lumi settings, built.</h1><p>Screenshots of the running Flutter release build with disposable review data. Eight sections, light and dark themes, desktop and mobile layouts. Select an image to view it at its original size. These capture the visible viewport; longer settings sections scroll within the app.</p><div class="grid">''' + items + '</div></html>')
print(f'Gallery created with {len(files)} screenshots.')
