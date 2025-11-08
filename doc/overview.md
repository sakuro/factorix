# Factorix Reimplementation Plan - Project Overview

## Overview

Create a CLI tool named factorix.

## Purpose

Manage the Factorio game itself and MODs.

## Features

The tool will have the following features:

### 1. Game Information Feature
- Retrieve directory information related to the game

### 2. Game Launch Feature
- Launch the game
- Pass options to Factorio
- Prevent multiple simultaneous launches
- Automatically wait for termination for certain commands

### 3. Local MOD Management Feature
- Display MOD list (name, version, state, etc.)
- Install MODs
- Uninstall MODs
- Enable MODs
- Disable MODs
- Load and dump settings files

### 4. MOD Release Feature
- Upload MODs
- Publish new MODs
- Edit MOD information

## Implementation Phases

(Details to be determined through dialogue)

## Related Documentation

- [Architecture](architecture.md) - Overall system design
- [Technology Stack](technology-stack.md) - Technologies and libraries used
- [Component Details](components/) - Detailed design of each component
