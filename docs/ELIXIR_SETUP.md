ELIXIR (Slurm) — Access, Setup, and Safe Usage

This repo keeps a concise, copy‑pasteable record of how to access ELIXIR and run jobs with Slurm. No passwords are stored here. Replace ports or paths as needed.

Account and First Login
- Host: slurm.elixir-hpc.si
- Username: vn373kis
- Ports: 22 (use 22222 if 22 fails)
- First login (change expired/temporary password if prompted):
  - PowerShell (Windows):
    - ssh -p 22 vn373kis@slurm.elixir-hpc.si

SSH Key (recommended; avoids password on every connect)
1) Create a key locally (Windows PowerShell):
   - New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" -Force | Out-Null
   - ssh-keygen -t ed25519 -C "elixir-hpc" -f "$env:USERPROFILE\.ssh\id_elixir"
2) Install the public key on ELIXIR (enter your ELIXIR password once):
   - ssh -p 22 vn373kis@slurm.elixir-hpc.si "mkdir -p ~/.ssh; chmod 700 ~/.ssh"
   - type "$env:USERPROFILE\.ssh\id_elixir.pub" | ssh -p 22 vn373kis@slurm.elixir-hpc.si "cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"
   - If port 22 fails, repeat with -p 22222.
3) Optional: cache the key passphrase on Windows:
   - Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent
   - ssh-add "$env:USERPROFILE\.ssh\id_elixir"

Explicit Connection (no SSH config needed)
- Login: ssh -i "C:\Users\vidna\.ssh\id_elixir" -p 22 vn373kis@slurm.elixir-hpc.si
- Upload (example): scp -i "C:\Users\vidna\.ssh\id_elixir" -P 22 -r "C:\Users\vidna\Documents\mtb" vn373kis@slurm.elixir-hpc.si:~/projects/
- Download (example): scp -i "C:\Users\vidna\.ssh\id_elixir" -P 22 vn373kis@slurm.elixir-hpc.si:~/projects/mtb/snapshots/travniki/METHODS.md "C:\Users\vidna\Downloads\"

VS Code (optional)
- Install the "Remote – SSH" extension.
- Command Palette → "Remote‑SSH: Add New SSH Host…" and paste:
  - ssh -i "C:\Users\vidna\.ssh\id_elixir" -p 22 vn373kis@slurm.elixir-hpc.si
- Then use "Remote‑SSH: Connect to Host…" and pick the saved entry.

WinSCP (file management)
- Protocol SFTP; Host slurm.elixir-hpc.si; Port 22; User vn373kis.
- Private key: C:\Users\vidna\.ssh\id_elixir (or convert to .ppk via PuTTYgen if WinSCP requests it).
- You can set Synchronize or Keep remote directory up to date for convenience.

Very Important — Run with Slurm (never heavy jobs on the login node)
- Check partitions: sinfo -s
- Submit a small test job:
  - Create test.sbatch:
    - #!/usr/bin/env bash
      #SBATCH -J hello
      #SBATCH -p <partition>
      #SBATCH -c 2
      #SBATCH --mem=4G
      #SBATCH --time=00:05:00
      #SBATCH -o %x-%j.out
      echo "Node: $(hostname)"; echo "CPUs: $SLURM_CPUS_ON_NODE"; lscpu | egrep 'Model name|CPU\(s\):'
  - sbatch test.sbatch
  - squeue -u $USER
  - less hello-<jobid>.out
- Interactive compute shell (for quick exploration only):
  - srun --pty -p <partition> -c 4 --mem 8G --time 01:00:00 bash -l
- ELIXIR guidance: long/CPU‑intensive work must go through Slurm. Use containers if required by their policies.

Data Locations and Sync Tips
- Keep a project root on the cluster, e.g. ~/projects/mtb.
- For large/temporary work, stage to scratch if provided and copy results back at job end.
- WinSCP Synchronize or scp/rsync (when available) are both fine.

Troubleshooting
- "Could not resolve hostname": use the explicit command; no SSH config needed.
- "Permission denied (publickey)": reinstall the public key and ensure permissions: chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys
- Try port 22222 if 22 is blocked on your network.

