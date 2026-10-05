# Roblox Aimbot
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/slxzerxs/roblox-jailbreak-raycast-aimbot/refs/heads/main/roblox-jailbreak-raycast-aimbot.lua"))()
```

A Roblox aimbot that hooks into the game's raycast system to provide silent aim assistance.


## Description
This script intercepts bullet and taser raycasts and redirects them to the nearest valid target (NPC or enemy player) within a 600-stud range.


### Features
- **Activation (Hold X)**: Locks onto targets within a 600-stud radius.
- **Silent Aim**: Redirects projectiles (headshot priority, smart targeting, wall checks) without moving the camera.
- **Weapon Compatibility**: Works with all firearms, Plasmagun, and Plasma Shotgun.
- **Movement Buffs**: While active, increases fall speed and prevents fall damage (anti-ragdoll mechanic).
- **Performance & Safety**: Caches NPCs every 0.3s. Auto-disables on character death or window focus loss.
- **Note**: This is a Roblox exploit script. Use at your own risk.
