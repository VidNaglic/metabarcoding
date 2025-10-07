# Metabarcoding Workspace

This repository holds metabarcoding workflow, documentation, and snapshots. Scripts are designed to be run one-by-one, with per-run logs captured locally and (optionally) on the ELIXIR cluster.

## Repository Layout

- `scripts/` – processing scripts executed sequentially (e.g., `02_data_processing.sh`, `03_BOLDigger_pipeline.sh`).
- `data/` – raw and processed project data folders (e.g., `mtb_travniki`, `mtb_mag`, `mtb_neretva`).
- `snapshots/` – generated `snapshot.json`, `METHODS.md`, and `RELEASE_METHODS.md` per project.
- `docs/` – reference docs, including ELIXIR access/setup (`ELIXIR_SETUP.md`, `ELIXIR_QUICK_CMDS.md`).
- `tools/` – helper scripts (e.g., `setup_elixir_ssh.ps1`, `generate_methods_snapshot.sh`).
- `TraitDatabase/`, `databases/`, `environment/`, `docs/` – supporting data and notes.

## Typical Local Workflow

1. Run scripts in order, adjusting parameters/paths each time.
2. Each run writes its own log (`bioinfo/run_*/nextseq_processing.log`, `boldigger3.log`).
3. Generate updated snapshot + methods for a project:
   ```bash
   bash tools/generate_methods_snapshot.sh <ProjectName> <ProjectDataDir>
   ```
4. Review results under `snapshots/<project>/`.

## ELIXIR Access (summary)

- Connect explicitly: `ssh -i "C:\Users\vidna\.ssh\id_elixir" -p 22 vn373kis@slurm.elixir-hpc.si`
- WinSCP handles file sync.
- Full instructions and Slurm usage: see `docs/ELIXIR_SETUP.md` and `docs/ELIXIR_QUICK_CMDS.md`.
- Always submit compute via Slurm (`sbatch`/`srun`); avoid heavy work on the login node.

## Notes

- SSH keys remain in stored privately in `C:\Users\vidna\.ssh`.
- When working on new projects, create a matching folder under `data/`, run scripts one-by-one, then refresh snapshots with the helper script.
- keep the scripts clean, organised and hygienic!!!!
