"""Update the Power BI Parquet path to this repository's location."""

import re
import subprocess
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent


def main() -> None:
    repo_root = Path(
        subprocess.run(
            ["git", "-C", str(SCRIPT_DIR), "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    )
    parameter_file = (
        repo_root
        / "THOR_analytics.SemanticModel"
        / "definition"
        / "tables"
        / "PathParquet.tmdl"
    )
    parquet_path = str(repo_root / "THOR_Analysis.parquet").replace('"', '""')
    contents = parameter_file.read_text(encoding="utf-8")

    source_line = re.compile(r"(?m)^([ \t]*Source[ \t]*=[ \t]*).*$")
    if len(source_line.findall(contents)) != 1:
        raise ValueError(f"Expected one Source expression in {parameter_file}")

    updated = source_line.sub(
        lambda match: f'{match.group(1)}"{parquet_path}"',
        contents,
    )
    if updated != contents:
        parameter_file.write_text(updated, encoding="utf-8")

    print(f"PathParquet set to {repo_root / 'THOR_Analysis.parquet'}")


if __name__ == "__main__":
    main()
