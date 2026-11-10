# AGENTS.md

## Project overview
This repository is focused on cleaning and analyzing the THOR Vietnam dataset, with feature extraction and data-analytics workflows. The project is currently lightweight and organized around a small set of scripts and SQL assets.

## Working conventions
- Read the repository state and README before making significant changes.
- Keep changes surgical and targeted to the task at hand.
- Prefer small, readable, reproducible scripts over clever one-off logic.
- Preserve raw dataset inputs and avoid overwriting source data unless explicitly requested.
- Keep generated outputs and intermediate artifacts out of version control unless the project clearly expects them.
- Use existing directories consistently:
  - `scripts/` for processing and utility scripts
  - `sql/` for SQL queries and transformations
  - project root for configuration and repo-level documentation

## Code and data practices
- Favor explicit, maintainable Python and SQL over hidden magic or implicit behavior.
- Document script assumptions, required inputs, and expected outputs in docstrings or comments where helpful.
- Keep any pipeline steps deterministic and easy to rerun.
- If a change affects data semantics, explain the impact and preserve backward compatibility where possible.
- Do not commit secrets, credentials, or local environment state.

## Validation
- Prefer the smallest relevant validation command available.
- For Python changes with no project-specific test suite, use a syntax check such as:
  - `python -m compileall .`
- If tests are later added, run the project’s relevant test command instead of broad suite runs.
- Review the final diff before completion to confirm only intended files changed.

## Communication
- Be concise and specific when reporting changes.
- If a task is ambiguous, clarify assumptions before making data or pipeline changes that could affect downstream analysis.
- Keep the repository easy to understand for future contributors by using clear naming and straightforward structure.
