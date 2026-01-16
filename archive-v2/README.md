# 📦 Archive V2

This directory contains legacy files moved during the v0.3.0 release cleanup.

## Contents

### `legacy-uc-configs/`
Unity Catalog configuration files that are no longer actively used:
- `patch-uc-deployment.yaml` - UC deployment patches
- `patch-uc-deployment-v2.yaml` - UC deployment patches v2
- `uc-db-patch.yaml` - UC database patches
- `uc-service-8085.yaml` - UC service on port 8085
- `uc-service-dump.yaml` - UC service dump
- `unity-catalog-config.json` - UC configuration

### `legacy-scripts/`
Scripts that were used during development and testing:
- `interpreter_settings.json` - Legacy Zeppelin interpreter settings
- `spark_setting_update.json` - Spark settings update file
- `update_interpreter_settings.py` - Interpreter update script
- `verify_stack_notebook.py` - Stack verification notebook
- `full_stack_verification_notebook.py` - Full verification notebook
- `scripts/` - Legacy UC test and debug scripts:
  - `debug_uc.py`
  - `register_uc_delta*.py`
  - `test_*.py`

## Why Archived?

These files were created during:
1. Unity Catalog experimentation (paused in favor of HMS)
2. Legacy Zeppelin configuration (retired)
3. Development debugging sessions

## Re-activating

If Unity Catalog is re-integrated in v0.4.0, relevant files may be restored to the main directory.
