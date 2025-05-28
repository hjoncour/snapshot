- snapshot --list (list snapshots of current project)
- snapshot --list {project name} (list snapshots of named project)
- snapshot --list-global (overview of )
- snapshot --projects (list projects)

- snapshot tree -> snapshot --tree + fix ignore apply to snapshot --tree
- snapshot ignore revert

- snapshot --history

--- TESTS MISSING:

Settings:
- 
/revert-snapshot)
- project specific config

- Make a linux version of this      (install script)
- Make a windows version of this    (install script)
- Better testing
- eventually rewrite this in rust lol

- add command to update automatically

update installed config.json version

- Fix readme
- "snapshot update"
- track test coverage
- install run test
- snapshot --ignore-tests (ignore test files)


larger refactor
- split .sh files into folders:
    - helpers
    - core
    - ignore
    - regex
    - dispatch

fix tag handling in name 
