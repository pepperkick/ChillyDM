# ChillyDM

A sourcemod plugin that works with SoapDM plugin to add new features for it.

- [ChillyDM](#chillydm)
    - [Introduction](#introduction)
    - [Features](#features)
    - [Running](#running)
    - [Known Bugs](#known-bugs)
    - [Changelog](#changelog)

## Introduction
This plugin works with the classic tf2 dm plugin soapdm to add new features for it and allow true free for all dm in tf2.

!!! THIS IS AN EXPERIMENTAL PLUGIN !!!

## Features
- **Free for All Deathmatch**: This plugin allows TF2 DMs to be free for all where every player is against each other.
- **Mode Config**: The plugin executes config depending on which mode it switches to.

## Running
The plugin currently only works when "mp_friendlyfire 1" so the cvar is used for FFA mode enable and disable for now, when the plugin detects FFA gets enabled the plugin executes the config
```
cfg/chillydm/ffa.cfg
```
When FFA gets disabled the plugin executes the following config
```
cfg/chillydm/tdm.cfg
```
All players are moved to RED team for FFA to work and then players can play as a noraml DM round.

## Known Bugs
- Pyro and Spy do not work with FFA mode
- Due to disabling lag compensation on hitscan shots there may be a bit of lag on clients shooting hitscan weapons
    - This can also cause random hud elements to glitch out a tiny bit

## Changelog
- 1.1.0
    - Fixed constant player and server crashing
    - Refactored most of everything
    - Fixed bots (STV / Replay / Other) being moved to red team
    - Made stickybombs properly collide with red teammates
    - Removed useless unhook function from OnClientDisconnect
    - Removed unneccecary includes
    - Fixed K/D on scoreboard going negative
- 1.0.1
    - Player collision auto enables along with FFA
    - Worked around player kills going negative
    - Fixed player respawing when hitscan weapon is used when alone
    - Fixed all players respawing when all shoot at the same time
- 1.0.0
