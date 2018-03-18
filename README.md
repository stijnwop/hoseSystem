# HoseSystem for Farming Simulator 17

## Why is the HoseSystem not working!?
The HoseSystem is currently conflicting with these known mods/scripts:
- [Ground Modification](http://farming-simulator.com/mod.php?lang=en&country=gb&mod_id=75812)
- RealisticBeacons script

To make fully use of the HoseSystem please make sure to remove those mods from your mod folder.

***This list will stay till the creators updated their mod.***

## Warning!
Please be aware that this is a ***DEVELOPMENT VERSION***!

If you are planning to use a copy of the current development branch, please understand that the development version can break the game!

## Global features
- Player controlled
- Player restrictions
- Helper text on target nodes
- Pump from/to vehicle to vehicle
- Pump from/to the manure pit
- Pump from/to station
- Real filling [it always fills up to 97~99%]
- Pump directions [in/out]
- Toggle lock and manure flow state
- Dynamic parking position [only define the start parking node and set an offset if needed.. the script will do the rest]
  - If applicable you could use animation on the park function for moving some arms/levers around
- Effects/particle system when emptying in manure pit
- Different hose lengths
- Extend your hoses with the extendable hose type for larger ranges with the extendable configuration
- Real hose dirt shader
- Pit plane shader (get's updated real-time)
- Multiply fillType support
- Docking support
- Fillarm support
- Empty object slowly when manure flow is open

## How to use the HoseSystem on your mod?
Easy! Add the HoseSystemVehicle specialization to your mod and set the XML entries.

***The latest version of the HoseSystemVehicle.lua can be found in the _modding directory of this repository!***

Full tutorial can be found in the this [Manual](https://github.com/stijnwop/hoseSystem/blob/master/_modding/HoseSystemTutorial.pdf) pdf file.

## Copyright
Copyright (c) 2017 Stijn Wopereis
All rights reserved.