# Snapshot

Snapshot is a simple command-line utility designed to streamline project inspection and sharing workflows. It helps quickly generate structured views of a project's repository, capture code snippets, and copy detailed project snapshots directly to your clipboard for easy sharing.

## Features:
- Tree View (snapshot tree): Generates a clear, readable project structure listing all tracked files.
- Print: Outputs a structured display of all relevant source code and configuration files in your repository, including file names, paths, and contents.
- Copy (snapshot copy): Instantly copies your project's code snapshot to your clipboard, ready to paste into documentation, notes, or collaboration tools.

## Installation:

```bash
$ git clone https://github.com/hjoncour/snapshot
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
snapshot --print code              # save to file and print to stdout
snapshot --copy --print code       # save, copy to clipboard, and print
snapshot --no-snapshot code        # generate (and optionally copy/print) but skip saving

### Commands & Flags:

tree                            Display the repository structure
code                            Generate a code snapshot # should be removed
archive                         Bundles up previously made snapshots into a zip file
config, -c                      Show the global configuration file
--print                         Print snapshot to stdout
--copy                          Copy snapshot to clipboard
--no-snapshot                   Do not save snapshot to disk
--ignore, -i                    Add one or more ignore patterns
--remove-ignore                 Remove one or more ignore patterns
--remove-all-ignored            Clear both ignore lists
--remove-all-ignored-paths      Clear ignore_path list only
--remove-all-ignored-files      Clear ignore_file list only
--add-type                      Add one or more file extensions to track
--remove-type                   Remove one or more file extensions from tracking
--remove-all-types              Remove ALL tracked-extension entries
--use-gitignore                 Imports ignored files and folders from .gitignore file to settings

## More Examples:

### Snapshots:

Simple snapshot:

```
$ snapshot // Will create a snapshot file like: 1749016514_fix_documentation_110a716.snapshot
```

Snapshot with a name and tags
```
$ backup-before-refactor__[backup,refactor] // Will create a snapshot file like: backup-before-refactor__[backup,refactor].snapshot

```


```

```

### Archive

Bundle old snapshots
```

```

### List:

Getting the list of snapshots (ordered)
```
$ snapshot list
➜  snapshot git:(fix/documentation) ✗ snapshot --list
frontend-w-turnstile-bug
backup-before-refactor
1749016514_fix_documentation_110a716
1749016335_fix_turnstyle-cloudflare-issue_8f52aad
1749015620_fix_documentation_110a716
```

List with details
```
$ snapshot list details
Snapshot                                                 | Branch                                | Date (UTC)          |   Size | Tags                   
-------------------------------------------------------- | ------------------------------------- | ------------------- | ------ | -----------------------
frontend-w-turnstile-bug                                 | frontend-w-turnstile-bug              | 2025-06-04 06:05:56 |  52 KB | -                      
backup-before-refactor                                   | backup-before-refactor                | 2025-06-04 05:56:59 | 108 KB | [backup,refactor]      
1749016514_fix_documentation_110a716                     | fix_documentation                     | 2025-06-04 05:55:14 | 108 KB | -                      
1749016335_fix_turnstyle-cloudflare-issue_8f52aad        | fix_turnstyle-cloudflare-issue        | 2025-06-04 05:52:15 |  52 KB | -                      
1749015620_fix_documentation_110a716                     | fix_documentation                     | 2025-06-04 05:40:20 | 108 KB | -                      
1748927680_fix_typescript_9b8f914                        | fix_typescript                        | 2025-06-03 05:14:40 |  11 KB | -                      
```

List, filtering for tags
```
$ snapshot --list tag test        
1748228507_HEAD_b3d9d8c
1748228474_master_e975a75
1748228461_master_e975a75
1748228330_feature_list-snapshots_14ad0ba```
```

List, filtering for tags, showing details
```
$ snapshot --list tag test details
Snapshot                                  | Branch                 | Date (UTC)          |  Size | Tags               
----------------------------------------- | ---------------------- | ------------------- | ----- | -------------------
1748228507_HEAD_b3d9d8c                   | HEAD                   | 2025-05-26 03:01:47 | 84 KB | test,tag1,test,tag2
1748228474_master_e975a75                 | master                 | 2025-05-26 03:01:14 | 94 KB | test,tag1,test,tag2
1748228461_master_e975a75                 | master                 | 2025-05-26 03:01:01 | 94 KB | test,tag1,test,tag2
1748228330_feature_list-snapshots_14ad0ba | feature_list-snapshots | 2025-05-26 02:58:50 | 96 KB | test,tag1,test,tag2

```

## Running Tests:

From the project root, tests are self-contained and will not overwrite your real config:

```bash
$ chmod +x test.sh
$ bash test.sh
```

## Contributions:
Contributions are very welcome, please read `TODO.md` for inspiration, but don't hesitate to submit a Pull Request if you have other great ideas or improvements.

## Disclaimer:

This is my first project in bash, I'm learning at the same time. I expect the project to go through significant changes over its development.
