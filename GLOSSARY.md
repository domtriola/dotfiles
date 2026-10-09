# Dotfiles

The configuration that turns a new machine into a usable one for its purpose.

## Language

**Profile**:
What a machine is for, which decides what is installed and copied onto it. A machine has exactly one profile.
_Avoid_: Setup, machine type, OS

**Setup step**:
One ordered, automated unit of work that belongs to a single profile.
_Avoid_: Setup, script

**Bootstrap**:
The steps a person does by hand to make a machine ready for its profile, before or after the setup steps run. Never a setup step.
_Avoid_: Prerequisites, manual setup, manual steps

**Command**:
A program from this repo that the user runs by name, such as `setup`, `sync-env` or `doctor`. Most commands are shared, but a profile can own commands that only its machine gets.
_Avoid_: Package, tool, helper, script

**Package**:
Software that a system package manager installs (for example, Homebrew or apt). Never a command from this repo.
_Avoid_: Dependency, tool

**Dotfile**:
A file or directory from this repo that `sync-env` copies into the home directory, such as the shell or tmux configuration.
_Avoid_: Environment file, config file

**Manifest**:
A profile's list of the dotfiles and commands that `sync-env` copies onto its machine.
_Avoid_: env.manifest, the list

**Sync record**:
What `sync-env` stores about each file that it copied, so that a later run can tell when the copy in the home directory changed.
_Avoid_: State file, lock file, checksums

**Drift**:
A change in the home directory, since the last sync, to a file that the next sync would overwrite or delete.
_Avoid_: Local changes, diff, divergence

**Checkout**:
The copy of this repo on a machine, from which the commands read the profiles and the dotfiles.
_Avoid_: Clone, repo, dotfiles dir

**Check**:
One test that `doctor` runs to show whether a machine matches its profile.
_Avoid_: Test, health check

**Skill**:
A packaged set of instructions that an agent loads for one kind of task. A tracked skill is in Git. A local skill is not, and it shadows a tracked skill of the same name.
_Avoid_: Prompt, command

### Sandboxes

**Sandbox**:
One running Docker Sandbox, started for one project and branch. Never a kit.
_Avoid_: Container, VM, sbx

**Kit**:
A packaged definition that Docker Sandboxes uses to build a sandbox. A kit is either a sandbox kit or a mixin.

**Sandbox kit**:
The kit that decides which agent a sandbox runs, and how. A sandbox uses exactly one.
_Avoid_: Agent kit, agent

**Mixin**:
A kit that adds one capability to any sandbox kit, such as the dotfiles or the agent skills.
