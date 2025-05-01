# snapshot# Snapshot

**Snapshot** is a simple command-line utility designed to streamline project inspection and sharing workflows. It helps quickly generate structured views of a project's repository, capture code snippets, and copy detailed project snapshots directly to your clipboard for seamless sharing.

## Features

- **Tree View (`snapshot tree`):** Generates a clear, readable project structure listing all tracked files.
- **Code Snapshot (`snapshot` or `snapshot code`):** Outputs a structured display of all relevant source code and configuration files in your repository, including file names, paths, and contents.
- **Clipboard Copy (`snapshot copy`):** Instantly copies your project's code snapshot to your clipboard, ready to paste into documentation, notes, or collaboration tools.

## Installation

Clone this repository, then run the provided installer script to add `snapshot` to your command-line path:

```bash
git clone <your-repo-url>
cd snapshot
./install_snapshot.sh
```

Ensure you have `tree` installed (required for the `tree` command):

macOS:

```bash
brew install tree
```

Linux (Debian/Ubuntu):

```bash
sudo apt install tree
```

## Usage

```bash
snapshot tree    # Display the repository structure
snapshot         # Output code/config file contents
snapshot copy    # Copy code/config contents directly to clipboard
```

## Contributions

Contributions are very welcome, please read `TODO.md` for inspiration, but don't hesitate to submit a Pull Request if you have other great ideas or improvements.
