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
The steps a person does by hand before the dotfiles can run on a new machine. Never a setup step.
_Avoid_: Prerequisites, manual setup

**Command**:
A tool from this repo that the user runs by name, such as `setup`, `sync-env` or `doctor`. Most commands are shared, but a profile can own commands that only its machine gets.
_Avoid_: Package

**Package**:
Software that a system package manager installs (for example, Homebrew or apt). Never a command from this repo.
_Avoid_: Dependency, tool
