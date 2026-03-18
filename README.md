# H42N42

## About

H42N42 is a project from the 42 School. The goal of this project is to create a small game in a web environment using Ocaml and thus the Ocsigen tool that allow Ocaml to Javascript compilation in addition to the Eliom module that allows the creation of a web application.

## The Game

The game is about little creets that move in random direction and get contaminated when going in intoxicated river. Your goal is to cure the creets before every creets is contaminated.

## How to play

The toxic river is located on top of the screen in green and you can cure the creets by putting them in the clear blue river at the bottom of the screen. Just use your mouse to drag and drop the creets away from the toxic river and in the clear one to cure them.

## How to install

### Prerequisites

To run this project you will need `docker` and `docker-compose` installed. 

### Installation and startup

After cloning the repostory, you can use the `make` command to build and run the project. You can use `make stop` to stop then server and `make clean` and `make fclean` to remove the container. Or just use the basic docker-compose commands (`docker-compose up --build`).

## Technical aspect

The subject wanted us the use the parallelism with the lwt library and create a thread for each creet's collisions and input handling. Once i set up a loop that launches every thread for each creet i then simply defined a creet class and added every function for collisions, input, movements, sprites updates, etc.
**You can browse the creet code in the `creets.eliom` file**
After that i updated my controller (which you can find in the `h42n42.eliom` file) to add the necessary html elements and add all the controls to remove and add creets.
I also written a file `config.eliom` where you can find every variables that define the game behavior and the creets' parameters.
After a bit of messing around with sprites and styling i ended up with a very simple but nice looking and playable game !
And that pretty much it !