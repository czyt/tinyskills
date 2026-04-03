#!/usr/bin/env python3
"""
LPK v1 to v2 Converter

Converts LazyCat Package (LPK) from v1 format (zip-based) to v2 format (tar-based).

Requirements:
    pip install pyyaml

Usage:
    python lpk_v1_to_v2.py input.lpk [output.lpk]

If output is not specified, creates input-v2.lpk
"""

import argparse
import os
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml")
    sys.exit(1)


# Static metadata fields that should move from manifest.yml to package.yml
STATIC_METADATA_FIELDS = [
    "package",
    "version",
    "name",
    "description",
    "author",
    "license",
    "homepage",
    "min_os_version",
    "unsupported_platforms",
    "locales",
    "admin_only",
    "permissions",
]

# Runtime structure fields that should stay in manifest.yml
RUNTIME_STRUCTURE_FIELDS = [
    "application",
    "services",
    "ext_config",
    "usage",
]


def load_yaml(content: bytes) -> dict:
    """Load YAML content from bytes."""
    return yaml.safe_load(content.decode("utf-8"))


def save_yaml(data: dict) -> bytes:
    """Save dict to YAML bytes."""
    return yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False).encode("utf-8")


def extract_v1_lpk(lpk_path: str, extract_dir: str) -> dict:
    """
    Extract LPK v1 (zip format) and return manifest content.

    Returns:
        dict with 'manifest', 'content_files', 'meta_files'
    """
    manifest = None
    content_files = []
    meta_files = []

    with zipfile.ZipFile(lpk_path, "r") as zf:
        for name in zf.namelist():
            if name == "manifest.yml":
                manifest = load_yaml(zf.read(name))
            elif name.startswith("content.tar") or name.startswith("content-"):
                content_files.append((name, zf.read(name)))
            elif name.startswith("META/"):
                meta_files.append((name, zf.read(name)))
            else:
                # Extract other files
                zf.extract(name, extract_dir)

    if manifest is None:
        raise ValueError("manifest.yml not found in LPK v1")

    return {
        "manifest": manifest,
        "content_files": content_files,
        "meta_files": meta_files,
    }


def split_manifest(manifest: dict) -> tuple[dict, dict]:
    """
    Split manifest into package.yml (static metadata) and manifest.yml (runtime structure).

    Returns:
        (package_data, manifest_data)
    """
    package_data = {}
    manifest_data = {}

    # Extract static metadata fields
    for field in STATIC_METADATA_FIELDS:
        if field in manifest:
            package_data[field] = manifest[field]

    # Extract runtime structure fields
    for field in RUNTIME_STRUCTURE_FIELDS:
        if field in manifest:
            manifest_data[field] = manifest[field]

    # Handle any remaining fields (put them in manifest_data with a warning)
    for key in manifest:
        if key not in STATIC_METADATA_FIELDS and key not in RUNTIME_STRUCTURE_FIELDS:
            if key not in ["lzc-sdk-version"]:
                print(f"  Warning: Unknown field '{key}', keeping in manifest.yml")
            manifest_data[key] = manifest[key]

    return package_data, manifest_data


def create_v2_lpk(
    output_path: str,
    package_data: dict,
    manifest_data: dict,
    content_files: list[tuple[str, bytes]],
    meta_files: list[tuple[str, bytes]],
    extract_dir: str,
) -> None:
    """
    Create LPK v2 (tar format) with the given data.
    """
    with tarfile.open(output_path, "w") as tf:
        # Add package.yml (static metadata)
        package_content = save_yaml(package_data)
        package_info = tarfile.TarInfo(name="package.yml")
        package_info.size = len(package_content)
        tf.addfile(package_info, io.BytesIO(package_content))
        print(f"  Added: package.yml ({len(package_content)} bytes)")

        # Add manifest.yml (runtime structure)
        manifest_content = save_yaml(manifest_data)
        manifest_info = tarfile.TarInfo(name="manifest.yml")
        manifest_info.size = len(manifest_content)
        tf.addfile(manifest_info, io.BytesIO(manifest_content))
        print(f"  Added: manifest.yml ({len(manifest_content)} bytes)")

        # Add content files
        for name, content in content_files:
            content_info = tarfile.TarInfo(name=name)
            content_info.size = len(content)
            tf.addfile(content_info, io.BytesIO(content))
            print(f"  Added: {name} ({len(content)} bytes)")

        # Add META files
        for name, content in meta_files:
            meta_info = tarfile.TarInfo(name=name)
            meta_info.size = len(content)
            tf.addfile(meta_info, io.BytesIO(content))
            print(f"  Added: {name}")

        # Add other extracted files
        for root, dirs, files in os.walk(extract_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, extract_dir)
                if arcname not in ["manifest.yml", "package.yml"]:
                    tf.add(file_path, arcname=arcname)
                    print(f"  Added: {arcname}")


def convert_lpk(input_path: str, output_path: str) -> None:
    """
    Convert LPK v1 to v2.
    """
    print(f"Converting: {input_path}")
    print(f"Output: {output_path}")
    print()

    # Create temporary directory
    with tempfile.TemporaryDirectory() as temp_dir:
        extract_dir = os.path.join(temp_dir, "extract")
        os.makedirs(extract_dir)

        # Step 1: Extract LPK v1
        print("Step 1: Extracting LPK v1 (zip format)...")
        try:
            v1_data = extract_v1_lpk(input_path, extract_dir)
        except zipfile.BadZipFile:
            # Might already be tar format
            print("  Note: Input appears to be tar format, checking if it's already v2...")
            with tarfile.open(input_path, "r") as tf:
                names = tf.getnames()
                if "package.yml" in names:
                    print("  Error: Input is already LPK v2 (contains package.yml)")
                    sys.exit(1)
                elif "manifest.yml" in names:
                    print("  Extracting tar format...")
                    tf.extractall(extract_dir)
                    manifest_path = os.path.join(extract_dir, "manifest.yml")
                    with open(manifest_path, "rb") as f:
                        manifest = load_yaml(f.read())
                    v1_data = {
                        "manifest": manifest,
                        "content_files": [],
                        "meta_files": [],
                    }
                else:
                    raise ValueError("Invalid LPK format: no manifest.yml found")
        print("  Done.")
        print()

        # Step 2: Split manifest
        print("Step 2: Splitting manifest into package.yml and manifest.yml...")
        package_data, manifest_data = split_manifest(v1_data["manifest"])
        print(f"  Static metadata fields: {list(package_data.keys())}")
        print(f"  Runtime structure fields: {list(manifest_data.keys())}")
        print("  Done.")
        print()

        # Step 3: Create LPK v2
        print("Step 3: Creating LPK v2 (tar format)...")
        import io
        create_v2_lpk(
            output_path,
            package_data,
            manifest_data,
            v1_data["content_files"],
            v1_data["meta_files"],
            extract_dir,
        )
        print("  Done.")
        print()

    print(f"Success! Converted to: {output_path}")
    print()
    print("Summary:")
    print(f"  Input format:  LPK v1 (zip)")
    print(f"  Output format: LPK v2 (tar)")
    print(f"  package.yml:   {len(package_data)} fields")
    print(f"  manifest.yml:  {len(manifest_data)} fields")


def main():
    parser = argparse.ArgumentParser(
        description="Convert LPK v1 to v2 format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s app.lpk                 # Creates app-v2.lpk
    %(prog)s app.lpk new-app.lpk     # Creates new-app.lpk
    %(prog)s app.lpk ./output/       # Creates output/app-v2.lpk
        """
    )
    parser.add_argument("input", help="Input LPK v1 file path")
    parser.add_argument("output", nargs="?", help="Output LPK v2 file path (optional)")
    args = parser.parse_args()

    # Validate input
    if not os.path.exists(args.input):
        print(f"Error: Input file not found: {args.input}")
        sys.exit(1)

    # Determine output path
    if args.output:
        if os.path.isdir(args.output):
            # Output is a directory, use input filename with -v2 suffix
            input_name = Path(args.input).stem
            output_path = os.path.join(args.output, f"{input_name}-v2.lpk")
        else:
            output_path = args.output
    else:
        # Default: add -v2 suffix
        input_path = Path(args.input)
        output_path = str(input_path.parent / f"{input_path.stem}-v2.lpk")

    # Check if output exists
    if os.path.exists(output_path):
        response = input(f"Output file exists: {output_path}\nOverwrite? (y/N): ")
        if response.lower() != "y":
            print("Cancelled.")
            sys.exit(0)

    # Convert
    try:
        convert_lpk(args.input, output_path)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
