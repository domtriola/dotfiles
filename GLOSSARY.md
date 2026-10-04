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

## Flagged ambiguities

**Setup**: Was used for the command, the per-profile directory and each step. Now it means only the `setup` command. The directory is the **Profile**, and each unit is a **Setup step**.

**Bootstrap**: Was used for the manual steps and for the first setup step. Now it means only the manual steps. The first setup step is a **Setup step** like any other.

**Package**: Was used for the commands and for system packages. Now it means only system packages.
