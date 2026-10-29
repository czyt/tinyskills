#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash examples/first-iso.sh --help
  sudo bash examples/first-iso.sh --build --confirm-disposable-vm --output-dir /absolute/new-directory

Builds an educational live ISO from the installed archiso releng profile.
Requires an Arch Linux virtual machine with archiso and arch-install-scripts installed.
The output directory must not exist, and its parent must exist.
No partitioning, USB writing, production installer, signing, or desktop setup is performed.
The inherited releng login policy is live-only; never clone it into an installed system.
Build logs and work files are retained, including on failure.
USAGE
}

build_requested=false
vm_confirmed=false
output_dir=""

while (( $# > 0 )); do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --build)
      build_requested=true
      shift
      ;;
    --confirm-disposable-vm)
      vm_confirmed=true
      shift
      ;;
    --output-dir)
      if (( $# < 2 )); then
        printf '%s\n' 'Missing --output-dir value' >&2
        exit 2
      fi
      output_dir="$2"
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$build_requested" != true || "$vm_confirmed" != true ]]; then
  printf '%s\n' 'Refusing to build without --build and --confirm-disposable-vm.' >&2
  exit 2
fi

if [[ "$output_dir" != /* || "$output_dir" == / || -e "$output_dir" || -L "$output_dir" ]]; then
  printf '%s\n' 'Use an absolute output directory that does not exist.' >&2
  exit 2
fi

if (( EUID != 0 )); then
  printf '%s\n' 'Run the confirmed build as root inside the disposable VM.' >&2
  exit 2
fi

for required_command in mkarchiso pacman systemd-detect-virt sha256sum; do
  command -v "$required_command" >/dev/null
done

if [[ ! -f /etc/arch-release ]] || ! systemd-detect-virt --vm --quiet; then
  printf '%s\n' 'Refusing: this example requires an Arch Linux virtual machine.' >&2
  exit 2
fi

if [[ ! -d /usr/share/archiso/configs/releng || ! -d "$(dirname -- "$output_dir")" ]]; then
  printf '%s\n' 'Missing installed releng profile or output parent directory.' >&2
  exit 2
fi

mkdir -m 0755 -- "$output_dir"
profile_dir="$output_dir/profile"
cp -a -- /usr/share/archiso/configs/releng "$profile_dir"
printf '\nnetworkmanager\n' >> "$profile_dir/packages.x86_64"
printf "\niso_name='arch-lifecycle-lab'\niso_label='ARCH_LIFECYCLE_LAB'\n" >> "$profile_dir/profiledef.sh"
mkdir -p -- "$profile_dir/airootfs/etc"
printf '%s\n' 'Educational live image. Not a production-installed system.' > "$profile_dir/airootfs/etc/motd"
pacman -Q archiso arch-install-scripts systemd > "$output_dir/builder-versions.txt"

if mkarchiso -v -w "$output_dir/work" -o "$output_dir/out" "$profile_dir" > "$output_dir/build.log" 2>&1; then
  shopt -s nullglob
  iso_files=("$output_dir"/out/*.iso)
  if (( ${#iso_files[@]} == 0 )); then
    printf '%s\n' 'mkarchiso returned success but produced no ISO.' >&2
    exit 1
  fi
else
  printf 'Build failed; inspect %s/build.log and residual mounts before cleanup.\n' "$output_dir" >&2
  exit 1
fi

(
  cd -- "$output_dir/out"
  sha256sum -- ./*.iso > SHA256SUMS
)
printf 'ISO files and checksums: %s/out\nBoot/install/recovery validation has NOT been performed.\n' "$output_dir"
