from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("Usage: fix-mainactivity-v19.py <MainActivity.java>")

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = """if (webView != null) webView.postDelayed(tone::release, 180);
                    else tone.release();"""
new = """new android.os.Handler(android.os.Looper.getMainLooper())
                        .postDelayed(tone::release, 180);"""

if old in text:
    path.write_text(text.replace(old, new), encoding="utf-8")
elif "postDelayed(tone::release, 180)" not in text:
    raise SystemExit("Expected ToneGenerator release block was not found")
