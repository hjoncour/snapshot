#!/usr/bin/env bash
#
# Validate --use-gitignore populates ignore_file & ignore_path correctly.
#
set -euo pipefail

# locate repo root
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q

# write the sample .gitignore
cat > .gitignore <<'EOF'
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
.pybuilder/
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# pdm
.pdm.toml
.pdm-python
.pdm-build/

# PEP 582; used by e.g. github.com/David-OConnor/pyflow and github.com/pdm-project/pdm
__pypackages__/

# Celery stuff
celerybeat-schedule
celerybeat.pid

# SageMath parsed files
*.sage.py

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# pytype static type analyzer
.pytype/

# Cython debug symbols
cython_debug/

# PyPI configuration file
.pypirc

# aws
.aws-sam
EOF

# start with empty global config
echo '{}' > global.json

# install our snapshot stub
mkdir -p src
bash "$repo_root/src/make_snapshot.sh" > src/snapshot.sh
chmod +x src/snapshot.sh

# run the new flag
SNAPSHOT_CONFIG="$tmpdir/global.json" bash src/snapshot.sh --use-gitignore

# verify counts & show helpful diffs on failure
ignore_file_count=$(jq '.ignore_file | length' global.json)
ignore_path_count=$(jq '.ignore_path | length' global.json)

if [ "$ignore_file_count" -ne 29 ]; then
  echo "❌ use-gitignore: expected 29 ignore_file entries, got $ignore_file_count" >&2
  echo "── ignore_file list ──" >&2
  jq -r '.ignore_file[]' global.json >&2
  exit 1
fi

if [ "$ignore_path_count" -ne 51 ]; then
  echo "❌ use-gitignore: expected 51 ignore_path entries, got $ignore_path_count" >&2
  echo "── ignore_path list ──" >&2
  jq -r '.ignore_path[]' global.json >&2
  exit 1
fi

echo "✅ --use-gitignore populated ignore_file ($ignore_file_count) and ignore_path ($ignore_path_count) correctly"
