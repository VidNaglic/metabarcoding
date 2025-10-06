ELIXIR — Quick Commands (explicit, copy–paste)

Login (explicit key path)
- ssh -i "C:\Users\vidna\.ssh\id_elixir" -p 22 vn373kis@slurm.elixir-hpc.si

File transfer (WinSCP is fine; these are scp equivalents)
- Upload folder → ~/projects/:
  - scp -i "C:\Users\vidna\.ssh\id_elixir" -P 22 -r "C:\Users\vidna\Documents\mtb" vn373kis@slurm.elixir-hpc.si:~/projects/
- Download file → Downloads:
  - scp -i "C:\Users\vidna\.ssh\id_elixir" -P 22 vn373kis@slurm.elixir-hpc.si:~/projects/mtb/snapshots/travniki/METHODS.md "C:\Users\vidna\Downloads\"

Slurm basics (run on the server after login)
- Check partitions:
  - sinfo -s
- Submit tiny test job:
  - echo '#!/usr/bin/env bash
#SBATCH -J hello
#SBATCH -p <partition>
#SBATCH -c 2
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH -o %x-%j.out
hostname; echo CPUs=$SLURM_CPUS_ON_NODE' > test.sbatch
  - sbatch test.sbatch
  - squeue -u $USER
  - less hello-*.out
- Interactive shell (short work only):
  - srun --pty -p <partition> -c 4 --mem 8G --time 01:00:00 bash -l

Warnings
- Do not run heavy code on the login node — always use sbatch/srun via Slurm.
- Use port 22222 if 22 fails.

