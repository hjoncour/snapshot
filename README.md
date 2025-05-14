# Snapshot

Snapshot is a simple command-line utility designed to streamline project inspection and sharing workflows. It helps quickly generate structured views of a project's repository, capture code snippets, and copy detailed project snapshots directly to your clipboard for seamless sharing.

## Features:
- Tree View (snapshot tree): Generates a clear, readable project structure listing all tracked files.
- Code Snapshot (snapshot or snapshot code): Outputs a structured display of all relevant source code and configuration files in your repository, including file names, paths, and contents.
- Clipboard Copy (snapshot copy): Instantly copies your project's code snapshot to your clipboard, ready to paste into documentation, notes, or collaboration tools.

## Installation:

```bash
$ git clone <your-repo-url>
$ cd snapshot
$ ./install_snapshot.sh
```

### Dependencies

Ensure you have tree installed (required for the tree command):

#### macOS:
```bash
$ brew install tree
```

#### Linux:

```bash
$ sudo apt install tree
```

## Usage Examples:

snapshot tree
snapshot code
snapshot --print code              # save to file and print to stdout
snapshot --copy --print code       # save, copy to clipboard, and print
snapshot --no-snapshot code        # generate (and optionally copy/print) but skip saving

### Commands & Flags:

tree                            Display the repository structure
code                            Generate a code snapshot # should be removed
--print                         Print snapshot to stdout
--copy                          Copy snapshot to clipboard
--no-snapshot                   Do not save snapshot to disk
--config, -c                    Show the global configuration file
--ignore, -i                    Add one or more ignore patterns
--remove-ignore                 Remove one or more ignore patterns
--remove-all-ignored            Clear BOTH ignore lists
--remove-all-ignored-paths      Clear ignore_path list only
--remove-all-ignored-files      Clear ignore_file list only
--add-type                      Add one or more file extensions to track
--remove-type                   Remove one or more file extensions from tracking
--remove-all-types              Remove ALL tracked-extension entries
--use-gitignore                 Imports ignored files and folders from .gitignore file to settings

## Running Tests:

From the project root, tests are self-contained and will not overwrite your real config:

```bash
$ chmod +x test.sh
$ bash test.sh
```

## Contributions:
Contributions are very welcome, please read `TODO.md` for inspiration, but don't hesitate to submit a Pull Request if you have other great ideas or improvements.

test