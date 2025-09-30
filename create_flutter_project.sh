#!/usr/bin/env bash
set -euo pipefail

DEFAULT_ORG="com.universales"
DEFAULT_PLATFORMS="android,ios"
VALID_PLATFORMS=(android ios linux macos windows)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="$(pwd)"

if [[ -d "$WORKING_DIR/example/lib" ]]; then
  TEMPLATE_LOCAL_DIR="$WORKING_DIR/example/lib"
else
  TEMPLATE_LOCAL_DIR="$SCRIPT_DIR/example/lib"
fi
TEMPLATE_ARCHIVE_URL="https://github.com/AaronMG-Universales/flutter-generate/releases/download/v1.0.0/flutter_template_v1.0.0.zip"
TEMP_TEMPLATE_DIR=""
TEMPLATE_SOURCE=""
error() {
  echo "Error: $1" >&2
}

cleanup() {
  if [[ -n "$TEMP_TEMPLATE_DIR" && -d "$TEMP_TEMPLATE_DIR" ]]; then
    rm -rf "$TEMP_TEMPLATE_DIR"
  fi
}

trap cleanup EXIT

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "No se encontró el comando '$1'. Asegúrate de tenerlo instalado y en el PATH."
    exit 1
  fi
}

trim() {
  local var="$1"
  # shellcheck disable=SC2001
  echo "$(echo "$var" | sed -e 's/^\s*//' -e 's/\s*$//')"
}

to_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

contains() {
  local needle="$1"
  shift
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

ask_yes_no() {
  local prompt="$1"
  local default_answer="$2" # y o n
  local answer
  local default_hint=""

  if [[ "$default_answer" == "y" ]]; then
    default_hint="[S/n]"
  else
    default_hint="[s/N]"
  fi

  while true; do
    read -r -p "$prompt $default_hint " answer || answer=""
    answer="$(to_lower "$(trim "${answer:-}")")"

    if [[ -z "$answer" ]]; then
      answer="$default_answer"
    elif [[ "$answer" == "si" ]]; then
      answer="s"
    elif [[ "$answer" == "no" ]]; then
      answer="n"
    fi

    case "$answer" in
      s|y)
        echo "y"
        return 0
        ;;
      n)
        echo "n"
        return 0
        ;;
    esac
    echo "Por favor escribe 's' o 'n'."
  done
}

select_platforms() {
  local choices=( "${VALID_PLATFORMS[@]}" )
  local flags=()
  for plat in "${choices[@]}"; do
    if [[ "$plat" == "android" || "$plat" == "ios" ]]; then
      flags+=(1)
    else
      flags+=(0)
    fi
  done

  while true; do
    echo
    echo "Selecciona las plataformas a incluir:"
    local idx=0
    for plat in "${choices[@]}"; do
      local mark=" "
      if [[ "${flags[$idx]}" -eq 1 ]]; then
        mark="x"
      fi
      printf "  %d) [%s] %s\n" "$((idx + 1))" "$mark" "$plat"
      idx=$((idx + 1))
    done

    local current_selection=()
    for i in "${!choices[@]}"; do
      if [[ "${flags[$i]}" -eq 1 ]]; then
        current_selection+=("${choices[$i]}")
      fi
    done

    if ((${#current_selection[@]} > 0)); then
      printf "Actual: %s\n" "$(IFS=','; echo "${current_selection[*]}")"
    else
      echo "Actual: (ninguna)"
    fi

    echo "Presiona ENTER para continuar con la selección actual."
    echo "Escribe números (por ejemplo \"3\" o \"2 5\") para alternar plataformas."
    local input=""
    read -r -p "> " input || input=""
    input="$(trim "$input")"
    if [[ -z "$input" ]]; then
      PLATFORMS=("${current_selection[@]}")
      if ((${#PLATFORMS[@]} > 0)); then
        PLATFORM_STRING="$(IFS=','; echo "${PLATFORMS[*]}")"
        break
      fi
      echo "Debes seleccionar al menos una plataforma."
      continue
    fi

    IFS=' ,;:' read -r -a tokens <<< "$input"
    local valid_selection=1
    for token in "${tokens[@]}"; do
      [[ -z "$token" ]] && continue
      if [[ ! "$token" =~ ^[0-9]+$ ]]; then
        echo "Ingresa solo números válidos."
        valid_selection=0
        break
      fi
      local index=$((token - 1))
      if (( index < 0 || index >= ${#choices[@]} )); then
        echo "Número fuera de rango: $token"
        valid_selection=0
        break
      fi
      if [[ "${flags[$index]}" -eq 1 ]]; then
        flags[$index]=0
      else
        flags[$index]=1
      fi
    done
    if (( ! valid_selection )); then
      continue
    fi
  done
}

append_block_if_missing() {
  local file="$1"
  local marker="$2"
  local block="$3"
  if ! grep -Fq "$marker" "$file"; then
    printf '\n%s\n' "$block" >> "$file"
  fi
}

prepare_template() {
  if [[ -d "$TEMPLATE_LOCAL_DIR" ]]; then
    TEMPLATE_SOURCE="$TEMPLATE_LOCAL_DIR"
    return
  fi

  if [[ -z "$TEMPLATE_ARCHIVE_URL" ]]; then
    error "No se encontró la plantilla local en '$TEMPLATE_LOCAL_DIR' y no se definió TEMPLATE_ARCHIVE_URL."
    exit 1
  fi

  TEMP_TEMPLATE_DIR="$(mktemp -d)"
  echo "Descargando plantilla desde: $TEMPLATE_ARCHIVE_URL"

  python3 - "$TEMPLATE_ARCHIVE_URL" "$TEMP_TEMPLATE_DIR" <<'PY'
import io
import pathlib
import sys
import urllib.request
import zipfile

url, dest_dir = sys.argv[1:3]
dest = pathlib.Path(dest_dir)

with urllib.request.urlopen(url) as response:
    data = response.read()

with zipfile.ZipFile(io.BytesIO(data)) as archive:
    archive.extractall(dest)
PY

  if [[ -d "$TEMP_TEMPLATE_DIR/lib" ]]; then
    TEMPLATE_SOURCE="$TEMP_TEMPLATE_DIR/lib"
    return
  fi

  TEMPLATE_SOURCE="$(python3 - "$TEMP_TEMPLATE_DIR" <<'PY'
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
for candidate in root.rglob('lib'):
    if candidate.is_dir():
        print(candidate)
        break
PY
)"

  TEMPLATE_SOURCE="$(trim "$TEMPLATE_SOURCE")"

  if [[ -z "$TEMPLATE_SOURCE" || ! -d "$TEMPLATE_SOURCE" ]]; then
    error "No se encontró una carpeta lib/ dentro del archivo descargado."
    exit 1
  fi
}

check_command flutter
check_command python3
prepare_template

# Organización
ORG=""
while true; do
  read -r -p "Organización (reverse domain) [$DEFAULT_ORG]: " ORG || ORG=""
  ORG="$(trim "${ORG:-$DEFAULT_ORG}")"
  ORG="${ORG// /}"
  if [[ "$ORG" =~ ^[A-Za-z_][A-Za-z0-9_.]*$ ]]; then
    break
  fi
  echo "La organización debe usar el formato reverse domain, e.g. com.empresa.app"
done

# Nombre del proyecto
PROJECT_NAME=""
while true; do
  read -r -p "Nombre del proyecto (snake_case, sin espacios): " PROJECT_NAME || PROJECT_NAME=""
  PROJECT_NAME="$(trim "$PROJECT_NAME")"
  if [[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
    break
  fi
  echo "Usa solo minúsculas, números y guion bajo, iniciando con letra."
done

# Plataformas
PLATFORMS=()
PLATFORM_STRING=""
select_platforms

# Gestión de estado
USE_PROVIDER="n"
USE_BLOC="n"

if [[ "$(ask_yes_no "¿Agregar Provider?" "n")" == "y" ]]; then
  USE_PROVIDER="y"
fi

if [[ "$(ask_yes_no "¿Agregar Bloc?" "n")" == "y" ]]; then
  USE_BLOC="y"
fi

PROJECT_DIR="$WORKING_DIR/$PROJECT_NAME"

if [[ -d "$PROJECT_DIR" ]]; then
  error "La carpeta '$PROJECT_DIR' ya existe. Elimina o usa otro nombre."
  exit 1
fi

echo
echo "Resumen:"
echo "  Organización : $ORG"
echo "  Proyecto     : $PROJECT_NAME"
echo "  Plataformas  : $PLATFORM_STRING"
echo "  Provider     : $([[ "$USE_PROVIDER" == "y" ]] && echo "Si" || echo "No")"
echo "  Bloc         : $([[ "$USE_BLOC" == "y" ]] && echo "Si" || echo "No")"
echo

if [[ "$(ask_yes_no "¿Deseas continuar con la creación?" "y")" != "y" ]]; then
  echo "Operación cancelada."
  exit 0
fi

echo "Creando proyecto Flutter..."
flutter create --org "$ORG" --platforms="$PLATFORM_STRING" "$PROJECT_NAME"

echo "Sobrescribiendo estructura de lib con la plantilla..."
rm -rf "$PROJECT_DIR/lib"
mkdir -p "$PROJECT_DIR/lib"
cp -R "$TEMPLATE_SOURCE/." "$PROJECT_DIR/lib"

if [[ "$USE_BLOC" != "y" ]]; then
  rm -rf "$PROJECT_DIR/lib/ui/bloc"
else
  mkdir -p "$PROJECT_DIR/lib/ui/bloc"
  if [[ ! -f "$PROJECT_DIR/lib/ui/bloc/.gitkeep" ]]; then
    touch "$PROJECT_DIR/lib/ui/bloc/.gitkeep"
  fi
fi

mkdir -p "$PROJECT_DIR/lib/core/utils" "$PROJECT_DIR/lib/core/theme"

PROJECT_DISPLAY_NAME="$(python3 - <<PY
import re
name = "$PROJECT_NAME"
words = [w for w in re.split(r'[_-]', name) if w]
print(' '.join(w.capitalize() for w in words) if words else name)
PY
)"

python3 - "$PROJECT_DIR" "$PROJECT_NAME" "$PROJECT_DISPLAY_NAME" <<'PY'
import pathlib
import sys
project_dir = pathlib.Path(sys.argv[1])
package_name = sys.argv[2]
display_name = sys.argv[3]
for path in project_dir.joinpath('lib').rglob('*.dart'):
    text = path.read_text()
    text = text.replace('package:example', f'package:{package_name}')
    target_title = 'Hospital ' + '\u00c1ngeles'
    if target_title in text:
        text = text.replace(target_title, display_name)
    path.write_text(text)
PY

flutter_pub_add() {
  (
    cd "$PROJECT_DIR"
    flutter pub add "$@"
  )
}

echo "Instalando dependencias base..."
flutter_pub_add --sdk=flutter flutter_localizations
flutter_pub_add cupertino_icons
flutter_pub_add get
flutter_pub_add --git-url git@github.com:SegurosUniversales/mobile-modules.git --git-path api --git-ref master api_module

if [[ "$USE_PROVIDER" == "y" ]]; then
  echo "Agregando Provider..."
  flutter_pub_add provider
fi

if [[ "$USE_BLOC" == "y" ]]; then
  echo "Agregando Bloc..."
  flutter_pub_add bloc
  flutter_pub_add flutter_bloc
fi

echo "Agregando dependencias de desarrollo..."
flutter_pub_add --dev flutter_launcher_icons
flutter_pub_add --dev flutter_lints

PUBSPEC_PATH="$PROJECT_DIR/pubspec.yaml"

append_block_if_missing "$PUBSPEC_PATH" "flutter_launcher_icons:" $'flutter_launcher_icons:
  android: true
  ios: true
  image_path: \'assets/icons/ic_main.png\'
  remove_alpha_ios: true
  adaptative_icon_bakcground: #003364'
python3 - "$PUBSPEC_PATH" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text().splitlines()

flutter_block = [
    'flutter:',
    '',
    '  uses-material-design: true',
    '#  assets:',
    '#    - assets/images/',
    '#    - assets/icons/',
    '#  fonts:',
    '#      - family: Akzidenz',
    '#        fonts:',
    '#            - asset: assets/fonts/Akzidenz/Akzidenz_Grotesk_Black.ttf',
    '#            - asset: assets/fonts/Akzidenz/Akzidenz_Grotesk_Bold.ttf',
    '#            - asset: assets/fonts/Akzidenz/Akzidenz_Grotesk_Light_Italic.ttf',
    '#            - asset: assets/fonts/Akzidenz/Akzidenz_Grotesk_Light.ttf',
    '#            - asset: assets/fonts/Akzidenz/Akzidenz_Grotesk_Roman.ttf',
    '#      - family: Berthold_Condensed',
    '#        fonts:',
    '#            - asset: assets/fonts/Berthold_Condensed/Berthold_Condensed.otf',
    '#      - family: Century',
    '#        fonts:',
    '#            - asset: assets/fonts/Century/centurygothic_bold.ttf',
    '#            - asset: assets/fonts/Century/centurygothic.ttf',
]
output = []
i = 0
flutter_found = False
while i < len(lines):
    line = lines[i]
    stripped = line.lstrip()
    if stripped.startswith('#'):
        i += 1
        continue
    if line.startswith('flutter:'):
        flutter_found = True
        if output and output[-1] != '':
            output.append('')
        output.extend(flutter_block)
        i += 1
        while i < len(lines):
            nxt = lines[i]
            if nxt.strip() == '':
                i += 1
                continue
            if nxt.startswith(' '):
                i += 1
                continue
            break
        if output and output[-1] != '':
            output.append('')
        continue
    if line.strip() == '' and (not output or output[-1] == ''):
        i += 1
        continue
    output.append(line)
    i += 1

if not flutter_found:
    if output and output[-1] != '':
        output.append('')
    output.extend(flutter_block)

path.write_text('\n'.join(output).rstrip() + '\n')
PY

mkdir -p "$PROJECT_DIR/assets/icons" "$PROJECT_DIR/assets/images"

(
  cd "$PROJECT_DIR"
  flutter pub get
)

echo
echo "Proyecto '$PROJECT_NAME' creado correctamente en '$PROJECT_DIR'."
echo "Recuerda actualizar los assets y completar los archivos generados según tu necesidad."
