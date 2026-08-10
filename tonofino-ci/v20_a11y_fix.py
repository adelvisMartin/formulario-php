from pathlib import Path
import sys

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('tonofino-android')
p = root / 'app/src/main/assets/public/js/app.js'
s = p.read_text(encoding='utf-8')
replacements = [
    ('<button data-route="guided">${icon(\'arrow_forward\')}</button>', '<button data-route="guided" aria-label="Abrir afinación guiada">${icon(\'arrow_forward\')}</button>'),
    ('<button data-route="metronome">${icon(\'arrow_forward\')}</button>', '<button data-route="metronome" aria-label="Abrir metrónomo">${icon(\'arrow_forward\')}</button>'),
    ('<button data-route="tone">${icon(\'arrow_forward\')}</button>', '<button data-route="tone" aria-label="Abrir diapasón digital">${icon(\'arrow_forward\')}</button>'),
    ('<button data-route="fretboard">${icon(\'arrow_forward\')}</button>', '<button data-route="fretboard" aria-label="Abrir mástil interactivo">${icon(\'arrow_forward\')}</button>'),
    ('<button id="tuner-mic-state" class="studio-device-pill ${micReady ? \'is-live\' : permissionProblem ? \'is-error\' : \'\'}" data-action="${state.audio.running ? \'stop-audio\' : \'start-audio\'}">', '<button id="tuner-mic-state" class="studio-device-pill ${micReady ? \'is-live\' : permissionProblem ? \'is-error\' : \'\'}" data-action="${state.audio.running ? \'stop-audio\' : \'start-audio\'}" aria-label="${micReady ? \'Detener micrófono\' : permissionProblem ? \'Revisar permiso de micrófono\' : \'Activar micrófono\'}">'),
    ('data-action="play-theory-note" data-note="${cell.name}4"><i></i>', 'data-action="play-theory-note" data-note="${cell.name}4" aria-label="Nota ${cell.name}, traste ${cell.fret}"><i></i>'),
]
for old, new in replacements:
    s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
print('TonoFino v2 accessibility button labels applied')
