#!/usr/bin/env bash
# Prueba en Windows (Git Bash, el shell que usa Claude Code en Windows) de lo que le falló a Ángel el 20-11:
# el arranque deja ~/daotomata-equipo/bin sin privilegios (antes WinError 1314), lanza la puesta al día sin /bin/sh
# (antes WinError 2) y, con la llave de Docs de una cuenta que no es la de Daniel, sube un HTML de 3 MB con docs.mjs.
# Uso: DOCS_TOKEN_PRUEBA=dk_… bash pruebas/windows-docs.sh   (sin la llave, solo el arranque)
set -euo pipefail
KIT=$(pwd)
H=$(mktemp -d)
export HOME="$H" USERPROFILE="$(cygpath -w "$H")"
mkdir -p "$H/falso"
# Un «claude» falso que apunta cada llamada: la puesta al día tiene que llegar a él.
printf '@echo %%* >> "%%USERPROFILE%%\\llamadas-claude.txt"\r\n' > "$H/falso/claude.cmd"
arrancar() { PATH="$H/falso:$PATH" CLAUDE_PLUGIN_ROOT="$(cygpath -w "$KIT")" python hooks/arranque.py; }

echo "== 1. Arranque (dos veces: la segunda sustituye el enlace de la primera)"
arrancar | tee "$H/arranque1.json"
arrancar | tee "$H/arranque2.json"
if grep -q "falló" "$H/arranque1.json" "$H/arranque2.json"; then echo "MAL: el arranque avisa de un fallo"; exit 1; fi
ls -l "$H/daotomata-equipo/bin/docs.mjs"
cmd //c dir "$(cygpath -w "$H/daotomata-equipo")" | grep -i "junction\|unión" || { echo "MAL: bin no es una unión"; exit 1; }

echo "== 2. La puesta al día llega a claude (sin /bin/sh)"
for i in $(seq 20); do [ -s "$H/llamadas-claude.txt" ] && grep -q "plugin update" "$H/llamadas-claude.txt" && break; sleep 1; done
cat "$H/llamadas-claude.txt"
grep -q "plugin marketplace update daotomata-equipo" "$H/llamadas-claude.txt"
grep -q "plugin update daotomata" "$H/llamadas-claude.txt"

[ -n "${DOCS_TOKEN_PRUEBA:-}" ] || { echo "== sin DOCS_TOKEN_PRUEBA: no se prueba la subida"; echo "BIEN"; exit 0; }

echo "== 3. Llave de la cuenta de prueba donde dice la regla, y un HTML de 3 MB de texto"
mkdir -p "$H/.claude/credentials"
printf 'DOCS_TOKEN=%s\r\n' "$DOCS_TOKEN_PRUEBA" > "$H/.claude/credentials/docs-daotomata.env"
P="$H/kit-comercial.html"
python - "$P" <<'PY'
import sys
cab = '<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Prueba kit Windows</title></head><body><h1>Prueba del kit en Windows</h1>'
fila = '<p>Kit comercial de prueba: texto sin imágenes, como el de Ángel (3.088.065 bytes).</p>\n'
pie = '</body></html>\n'
n = 3_088_065 - len(cab.encode()) - len(pie.encode())
cuerpo = (fila * (n // len(fila.encode()) + 1)).encode()[:n].decode('utf-8', 'ignore')
open(sys.argv[1], 'w', encoding='utf-8', newline='').write(cab + cuerpo + pie)
PY
ls -l "$P"; sha256sum "$P"

echo "== 4. Subirlo como dice la regla del kit"
cd "$H"
node ~/daotomata-equipo/bin/docs.mjs publicar "$P" --titulo "Prueba kit Windows (se borra)" | tee "$H/pub.txt"
URL=$(grep -o 'https://docs.daotomata.io/a/[a-z0-9]*' "$H/pub.txt" | head -1)
[ -n "$URL" ]
echo "== 5. Leerlo de vuelta, idéntico, y borrarlo"
node ~/daotomata-equipo/bin/docs.mjs leer "$URL" 2>&1 | head -5
node ~/daotomata-equipo/bin/docs.mjs leer "$URL" --fichero index.html > "$H/vuelta.html"
sha256sum "$H/vuelta.html"
cmp "$H/vuelta.html" "$P" && echo "idéntico al original"
node ~/daotomata-equipo/bin/docs.mjs borrar "$URL"
echo "URL=$URL"
echo BIEN
