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

## Changelog
- 1.0.0
