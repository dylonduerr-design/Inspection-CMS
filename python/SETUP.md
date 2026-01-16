# Python DOCX Export - Setup Instructions

## Repo Hygiene Note (Read This)

This repo intentionally does **not** track runtime/generated directories in git, including:

- `.venv/` (Python virtual environment)
- `log/`, `tmp/`, `storage/` (Rails runtime + ActiveStorage files)

So if you pull changes and these folders are missing, that's expected — just recreate them locally.

### After pulling changes (quick fix)

```bash
# Ensure runtime dirs exist (safe to run anytime)
mkdir -p log tmp/pids tmp/cache tmp/storage storage

# Recreate Python env + install deps
./python/setup.sh
```

## Prerequisites

### Ubuntu/Debian Systems

Install Python virtual environment support:

```bash
sudo apt update
sudo apt install python3-venv python3-pip
```

### macOS

Python 3 with venv should be included:

```bash
# If needed, install via Homebrew
brew install python3
```

### Other Linux Distributions

```bash
# Fedora/RHEL
sudo dnf install python3-venv python3-pip

# Arch
sudo pacman -S python-virtualenv python-pip
```

## Installation

Once prerequisites are met:

```bash
cd /home/dylon/inspection_cms
./python/setup.sh
```

This will:
1. Create a virtual environment in `.venv/`
2. Install all required Python packages
3. Verify the installation

## Manual Installation (if setup script fails)

```bash
# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate

# Install dependencies
pip install -r python/requirements.txt
```

## Verification

Test the exporter with real report data (replace input path accordingly):

```bash
source .venv/bin/activate

python3 python/export_report.py \
  --input /path/to/your_data.json \
  --template app/assets/Context/inspection_template.docx \
  --output test_output.docx

# Check if file was created
ls -lh test_output.docx
```

## Production Deployment

### Docker

The Dockerfile includes Python setup automatically. No additional steps needed.

### Render/Heroku

Add a `render.yaml` or `Procfile` buildpack:

```yaml
# render.yaml
services:
  - type: web
    buildCommand: |
      bundle install
      python3 -m venv .venv
      .venv/bin/pip install -r python/requirements.txt
      bundle exec rails assets:precompile
```

### Direct Server Deployment

Run setup script during deployment:

```bash
./python/setup.sh
bundle exec rails server
```

## Troubleshooting

### "ensurepip is not available"

Install python3-venv:
```bash
sudo apt install python3-venv
```

### "No module named pip"

Install pip:
```bash
sudo apt install python3-pip
```

### Permission denied on setup.sh

Make script executable:
```bash
chmod +x python/setup.sh
```

### Python version too old

docxtpl requires Python 3.8+. Check version:
```bash
python3 --version
```

Update if needed:
```bash
sudo apt install python3.11  # or latest available
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Setup Python
  uses: actions/setup-python@v4
  with:
    python-version: '3.11'
    
- name: Install Python dependencies
  run: |
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r python/requirements.txt
```

### GitLab CI

```yaml
before_script:
  - apt-get update && apt-get install -y python3-venv
  - python3 -m venv .venv
  - source .venv/bin/activate
  - pip install -r python/requirements.txt
```
