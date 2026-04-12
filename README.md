# Omni-Chan Borg Backup System 🛡️

A universal, deduplicating backup engine for JSchan and Vichan instances running in Docker.

## Features
- **Deduplication**: Backs up multiple sites to the same repo; identical files take up zero extra space.
- **Universal DB Support**: Automatically detects and dumps MongoDB or MariaDB/MySQL from containers.
- **De-coupled Config**: Sensitive passwords and IPs live in `.env` files, keeping the main script safe for public repos.
- **Automated Pruning**: Keeps 7 daily, 4 weekly, and 6 monthly archives.

## Project Structure
- `backup_omnichan_borg.sh`: The main engine.
- `fogchan.env`: Config for the JSchan/Mongo instance.
- `netherchan.env`: Config for the Vichan/MariaDB instance.
- `config.env`: The active slot used by the script.

## Installation & Usage

1. **Initialize Borg Repo** (on backup server):
   `borg init --encryption=repokey /path/to/repo`

2. **Configure Environment**:
   Create your `.env` files based on the templates provided. Ensure `DK_APP_DIR` points to your docker-compose folder and any bind-mounted web directories.

3. **Manual Backup**:
   ```bash
   cp fogchan.env config.env && sudo ./backup_omnichan_borg.sh