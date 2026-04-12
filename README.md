Omni-Chan Borg Backup System
A universal, deduplicating backup engine for JSchan (Fogchan) and Vichan (Netherchan) instances running in Docker.

Features
Deduplication: Backs up multiple sites to the same repo; identical files take up zero extra space.

Universal DB Support: Automatically detects and dumps MongoDB or MariaDB/MySQL from containers.

De-coupled Config: Sensitive passwords and IPs live in .env files, keeping the main script safe for public repos.

Automated Pruning: Keeps 7 daily, 4 weekly, and 6 monthly archives.

Project Structure
backup_omnichan_borg.sh: The main engine.

fogchan.env: Config for the JSchan/Mongo instance.

netherchan.env: Config for the Vichan/MariaDB instance.

config.env: The active slot used by the script.

Installation and Usage
Initialize Borg Repo (on backup server):

Bash
borg init --encryption=repokey james@192.168.2.51:/home/james/backups/omnichan
Configure Environment:
Create .env files for each site. Ensure DK_APP_DIR points to your docker-compose folder and any bind-mounted web directories.

Manual Backup:

Bash
cp fogchan.env config.env && sudo ./backup_omnichan_borg.sh
Automation:
Add to sudo crontab -e:

Plaintext
0 3 * * * cd /home/netherchan/omnichan-backup && cp fogchan.env config.env &&