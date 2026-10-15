#!/usr/bin/env bash
# =============================================================================
# VeiculoTracker (TCC) — script de execução completa
#
# O que ele faz, nesta ordem:
#   1. Verifica pré-requisitos (PHP 8.2+, Composer, Node/npm)
#   2. Instala as dependências PHP (Composer) e JS (npm)
#   3. Configura o ambiente (.env + APP_KEY) e o banco SQLite
#   4. Copia as capturas de protótipo (Visily) para public/img/prototipos/
#   5. Roda as migrações e os seeders (idempotentes — pode rodar de novo)
#   6. Compila os assets (Vite/Tailwind) e sobe o servidor Laravel
#
# Uso:
#   ./executar.sh
#
# Variáveis opcionais (com valores padrão):
#   IMG_ORIGEM   diretório com os PNGs do Visily (default: /home/eddie/Imagens/visily-multiscreens)
#   HOST         host do servidor          (default: 127.0.0.1)
#   PORT         porta do servidor          (default: 8000)
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

IMG_ORIGEM="${IMG_ORIGEM:-/home/eddie/Imagens/visily-multiscreens}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8000}"
IMG_DESTINO="public/img/prototipos"

log()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m ✔ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m ✖ %s\033[0m\n' "$*" >&2; exit 1; }

# ── 1. Pré-requisitos ────────────────────────────────────────────────────────
log "Verificando pré-requisitos"

command -v php    >/dev/null 2>&1 || fail "PHP não encontrado. Instale o PHP 8.2+."
command -v composer >/dev/null 2>&1 || fail "Composer não encontrado."
command -v node   >/dev/null 2>&1 || fail "Node.js não encontrado."
command -v npm    >/dev/null 2>&1 || fail "npm não encontrado."

PHP_MIN=80200
php -r "exit(version_compare(PHP_VERSION, '8.2.0', '>=') ? 0 : 1);" \
    || fail "Este projeto exige PHP 8.2 ou superior (encontrado: $(php -r 'echo PHP_VERSION;'))."
ok "PHP $(php -r 'echo PHP_VERSION;') · Composer · Node $(node -v) · npm $(npm -v)"

# Algumas distros não habilitam o SQLite por padrão; o projeto traz
# php-ext/sqlite.ini para esse caso. Detectamos e exportamos o scan dir.
if ! php -m | grep -qi '^pdo_sqlite$'; then
    [ -f php-ext/sqlite.ini ] \
        || fail "pdo_sqlite ausente no PHP e php-ext/sqlite.ini não encontrado."
    export PHP_INI_SCAN_DIR="$PWD/php-ext${PHP_INI_SCAN_DIR:+:$PHP_INI_SCAN_DIR}"
    php -m | grep -qi '^pdo_sqlite$' \
        || fail "Não foi possível habilitar o pdo_sqlite via php-ext/sqlite.ini."
    ok "pdo_sqlite habilitado via php-ext/sqlite.ini"
fi

# ── 2. Dependências ──────────────────────────────────────────────────────────
log "Instalando dependências PHP (Composer)"
if [ -f composer.lock ]; then
    composer install --no-interaction --prefer-dist
else
    composer update --no-interaction
fi
ok "Dependências PHP instaladas"

log "Instalando dependências JS (npm)"
if [ ! -d node_modules ]; then
    npm install
else
    ok "node_modules já existe — pulando npm install"
fi

# ── 3. Ambiente e banco ──────────────────────────────────────────────────────
log "Configurando ambiente (.env)"
if [ ! -f .env ]; then
    cp .env.example .env
    ok ".env criado a partir do .env.example"
fi

if ! grep -q '^APP_KEY=base64:' .env; then
    php artisan key:generate --no-interaction
    ok "APP_KEY gerada"
else
    ok "APP_KEY já configurada"
fi

# O projeto usa SQLite (DB_CONNECTION=sqlite no .env)
DB_FILE=$(php -r "echo parse_ini_file('.env')['DB_DATABASE'] ?? 'database/database.sqlite';" 2>/dev/null || echo "database/database.sqlite")
if [ ! -f "$DB_FILE" ]; then
    mkdir -p "$(dirname "$DB_FILE")"
    touch "$DB_FILE"
    ok "Banco SQLite criado em $DB_FILE"
fi

# ── 4. Capturas dos protótipos (Visily) ──────────────────────────────────────
log "Copiando protótipos de $IMG_ORIGEM -> $IMG_DESTINO"
if [ -d "$IMG_ORIGEM" ]; then
    mkdir -p "$IMG_DESTINO"
    cp -f "$IMG_ORIGEM"/*.png "$IMG_DESTINO"/
    ok "$(ls -1 "$IMG_DESTINO"/*.png | wc -l) imagens em $IMG_DESTINO"
else
    ok "Diretório de origem não encontrado — mantendo as imagens já existentes"
fi

# ── 5. Migrações + seeders ───────────────────────────────────────────────────
log "Rodando migrações e seeders (banco de demonstração)"
php artisan migrate --seed --no-interaction
ok "Banco populado (usuários, frota e 12 protótipos)"

# ── 6. Assets + servidor ─────────────────────────────────────────────────────
log "Compilando assets (Vite/Tailwind)"
npm run build
ok "Assets compilados em public/build"

log "Servidor em http://$HOST:$PORT"
echo
echo "   Landing page:  http://$HOST:$PORT/"
echo "   Painel:        http://$HOST:$PORT/dashboard  (login: admin@tcc.com / veiculotracker123)"
echo
php artisan serve --host="$HOST" --port="$PORT"
