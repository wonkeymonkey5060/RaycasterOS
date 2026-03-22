I HAVE CURRENTLY SET ASIDE THIS PROJECT AND AM NOT PLANNING ON COMING BACK TO IT

This is a bare-metal rendering engine, booting from a usb, like an operating system. It uses raycasting to render walls.
I built this project as a challenge, entirely in x86 assembly from scratch.

A work-in-progress bare-metal assembly raycaster rendering engine

feature log:  
	- Front buffer and back buffer system  
	- Game loop in protected-mode  
	- Keyboard polling  
	- Movable player position using WASD keys  
	- Work-in-progress raycasting code  
	- single colored wall rendering, crappy movement controls

In order to test this you should have qemu installed and added to PATH, then run build.bat.
You can also run it on real hardware but dont blame me if it breaks your computer.
I know it works for me but I do not reccomend trying it because I dont want to be responsible for that if it somehow breaks your computer.

