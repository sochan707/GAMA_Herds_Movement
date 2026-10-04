/**
* Name: SheepsMovement
* Based on the internal empty template. 
* Author: mac
* Tags: 
*/


model SheepsMovement

/* Insert your model definition here */

global {
	int nb_sheeps_init <- 75;
	int nb_obstacles_init <- 5;
	int nb_vegetations_init <- 8;
	int nb_dogs_init <- 1;
	int sheep_exited <- 0;
	geometry dog_free_space;
	
	init {
		create obstacle number: nb_obstacles_init;
		create vegetation number: nb_vegetations_init;
		create exit_gate number: 1 {location <- {98.0,50.0};}
		
		dog_free_space <- copy(shape);
		
		loop o over: obstacle {
		    dog_free_space <- dog_free_space - o.shape;
		}
		
		ask ground_cell {
		    blocked <- !empty(obstacle select (each.shape intersects self.shape));
		}
		
		list<ground_cell> free_cells <- ground_cell where not each.blocked;
		ground_cell start_cell <- free_cells closest_to {1.0, 50.0};
		
		create sheep number: nb_sheeps_init {
		    ground_cell spawn_cell <- one_of(free_cells);
		    location <- spawn_cell.location;
		}
		
		create dog number: nb_dogs_init {
		    location <- start_cell.location;
		}
	}
	
	reflex stop_when_all_exited when: sheep_exited >= nb_sheeps_init {
	    do pause;
	}
}

grid ground_cell width: 50 height: 50 neighbors: 8 {
    int passages <- 0;
    bool blocked <- false;
    float path_intensity <- min([1.0, passages / 100.0]);
    
    aspect base {
        path_intensity <- min([1.0, passages / 100.0]);

	    int red <- int(255 - (115 * path_intensity));
		int green <- int(255 - (155 * path_intensity));
		int blue <- int(255 - (195 * path_intensity));
		
		draw shape color: rgb(red, green, blue);
    }
}

species exit_gate {
	aspect base {
		draw rectangle(4.0, 16.0) color: #orange;
	}
}

species obstacle {
    float width <- 13.0; 
    float height <- 2.0;
    int obstacle_type <- rnd(1, 2);
    
    init {
	    if (obstacle_type = 2) {
	        width <- 20.0;
	        height <- 4.0;
	    }
	    
	    loop while: (location.x > 80.0 and location.y > 30.0 and location.y < 70.0) {
		    location <- any_location_in(world.shape);
		}
	    
	    shape <- rectangle(width, height);
	}

    aspect base {
        draw shape color: #black;
    }
}

species vegetation {
	int grass_type <- rnd(1, 3);
	float grass_amount <- 1.0;
	
	init {
	    int attempts <- 0;
	    loop while: (!empty(vegetation select ((each != self) and (each distance_to self < 8))) and attempts < 100) {
	        location <- any_location_in(world.shape);
	        attempts <- attempts + 1;
	    }
	}
	
	reflex regrow {
	    grass_amount <- min([1.0, grass_amount + 0.001]);
	}
	
	aspect base {
	    rgb grass_color <- rgb(0, 170, 0);
	
	    if (grass_type = 1) {
	        grass_color <- rgb(144, 238, 144);
	    }
	    if (grass_type = 3) {
	        grass_color <- rgb(0, 90, 0);
	    }
	
	    draw square(5.0 * grass_amount) color: grass_color;
	}
}

species dog skills: [moving] {
    float size <- 1.2;
    rgb dog_color <- #grey;
    bool is_awake <- false;
    
    reflex wake_up when: cycle >= 500 {
    	dog_color <- #red;
    	is_awake <- true;
    }
    
    reflex go_behind_sheep when: is_awake{
	    if (!empty(sheep)) {
	        sheep last_sheep <- sheep with_min_of (each.location.x);
	        point target <- {max([1.0, last_sheep.location.x - 4.0]), last_sheep.location.y};
			list<ground_cell> free_cells <- ground_cell where not each.blocked;
			ground_cell target_cell <- free_cells closest_to target;
			do goto target: target_cell.location on: free_cells;			
	    }
	}
	
	reflex show_status when: every(50 #cycles) {
	    write "Cycle: " + cycle + " | Dog: " + location + " | Sheep left: " + length(sheep) + " | Exited: " + sheep_exited;
	}

    aspect base {
        draw circle(size) color: dog_color;
    }
}

species sheep skills: [moving] {
	float size <- 1.0;
	rgb color <- #blue;
	bool prefers_grass <- flip(0.35);
	bool going_to_exit <- false;
	
	float heading <- rnd(360);
	float attraction_strength <- 0.9;
	float alignment_strength <- 0.3;
	float separation_strength <- 0.2;
	float obstacle_avoidance_strength <- 0.6;
	float path_following_strength <- 0.15;
	
	list<sheep> neighbors;
	list<sheep> too_close_neighbors;
	point neighbors_center;
	point too_close_center;
	float neighbors_heading;
	
	float mean_dx;
	float mean_dy;
	
	float heading_difference;
	float attraction_difference;
	float separation_difference;
	float obstacle_difference;
	float path_difference;
	
	list<obstacle> nearby_obstacles;
	obstacle nearest_obstacle;
	
	ground_cell current_cell;
	ground_cell previous_cell;
	list<ground_cell> nearby_path_cells;
	ground_cell best_path_cell;
	
	list<vegetation> nearby_grass;
	vegetation nearest_grass;
	int preferred_grass_type <- rnd(1, 3);
	int grazing_steps_left <- 0;
	int grass_cooldown_steps_left <- 0;
	
	aspect base {
		draw circle(size) color: color;
		
		loop n over: neighbors {
			draw line([self.location, n.location]);
		}
		
		if !empty(neighbors) {
	        draw circle(0.3) at: neighbors_center color: #red;
	    }
	}
	
	reflex find_neightbors {
		neighbors <- sheep select ((each != self) and (each distance_to self < 7));
		too_close_neighbors <- sheep select ((each != self) and (each distance_to self<2));
		nearby_obstacles <- obstacle select (each distance_to self < 1);
		nearby_path_cells <- (ground_cell at_distance 10) select ((each.passages > 10) and (each != current_cell) and (cos((self direction_to each) - heading) > 0));
		nearby_grass <- vegetation select ((each distance_to self < 15) and (each.grass_type = preferred_grass_type) and (each.grass_amount >= 0.1));
		
		if !empty(nearby_path_cells) {
		    best_path_cell <- nearby_path_cells with_max_of (each.passages * cos((self direction_to each) - heading));
		}
		
		if !empty(nearby_obstacles) {
		    nearest_obstacle <- nearby_obstacles with_min_of (each distance_to self);
		}
		
		if !empty(nearby_grass) {
			nearest_grass <- nearby_grass with_min_of (each distance_to self);
		}
		
		if !empty(neighbors) {
			neighbors_center <- mean(neighbors collect each.location);
	
			mean_dx <- mean(neighbors collect cos(each.heading));
			mean_dy <- mean(neighbors collect sin(each.heading));
			neighbors_heading <- atan2(mean_dy, mean_dx);
		}
		
		if !empty(too_close_neighbors) {
			too_close_center <- mean(too_close_neighbors collect each.location);
		}
		
	}
	
	reflex moving {
		if !empty(nearby_obstacles) {

		    float direction_away_obstacle <- nearest_obstacle direction_to self;
		
		    obstacle_difference <- direction_away_obstacle - heading;
		
		    if obstacle_difference > 180 {
		        obstacle_difference <- obstacle_difference - 360;
		    }
		
		    if obstacle_difference < -180 {
		        obstacle_difference <- obstacle_difference + 360;
		    }
		
		    heading <- heading + obstacle_difference * obstacle_avoidance_strength;
		}
//==============================================================================

		else if !empty(too_close_neighbors) {
			float direction_away <- too_close_center direction_to self;

		    separation_difference <- direction_away - heading;
		
		    if separation_difference > 180 {
		        separation_difference <- separation_difference - 360;
		    }
		
		    if separation_difference < -180 {
		        separation_difference <- separation_difference + 360;
		    }
		
		    heading <- heading + separation_difference * separation_strength;
		}
		else if (!empty(neighbors) and !(prefers_grass and !empty(nearby_grass))) {

			float direction_to_group <- self direction_to neighbors_center;

			attraction_difference <- direction_to_group - heading;
			
			if attraction_difference > 180 {
			    attraction_difference <- attraction_difference - 360;
			}
			
			if attraction_difference < -180 {
			    attraction_difference <- attraction_difference + 360;
			}
			
			heading <- heading + attraction_difference * attraction_strength;
//=====================================================================================

			heading_difference <- neighbors_heading - heading;

			if heading_difference > 180 {
			    heading_difference <- heading_difference - 360;
			}
			
			if heading_difference < -180 {
			    heading_difference <- heading_difference + 360;
			}
			
			heading <- heading + heading_difference * alignment_strength;
		}
		
		if (empty(nearby_obstacles) and empty(too_close_neighbors) and !empty(nearby_path_cells)) {
		    float direction_to_path <- self direction_to best_path_cell;
		
		    path_difference <- direction_to_path - heading;
		
		    if path_difference > 180 {
		        path_difference <- path_difference - 360;
		    }
		
		    if path_difference < -180 {
		        path_difference <- path_difference + 360;
		    }
		
		    heading <- heading + path_difference * path_following_strength;
		}
		
		if (prefers_grass and !empty(nearby_grass) and empty(nearby_obstacles) and empty(too_close_neighbors)) {
		    float direction_to_grass <- self direction_to nearest_grass;
		    float grass_difference <- direction_to_grass - heading;
		
		    if grass_difference > 180 {
		        grass_difference <- grass_difference - 360;
		    }
		    if grass_difference < -180 {
		        grass_difference <- grass_difference + 360;
		    }
		
		    heading <- heading + grass_difference * 0.3;
		}
		
		if (empty(nearby_path_cells) and empty(nearby_obstacles) and empty(too_close_neighbors)) {
			heading <- heading + rnd(-5.0, 5.0);
		}
		
// =========================================================================================================
		bool dog_nearby <- !empty(dog select (each.is_awake and (each distance_to self < 8)));

		if (dog_nearby) {
		    going_to_exit <- true;
		}
		
		if (going_to_exit) {
		    grazing_steps_left <- 0;
		}
		
		if (grazing_steps_left = 0 and grass_cooldown_steps_left = 0 and prefers_grass and !empty(nearby_grass) and (self distance_to nearest_grass < 3) and !going_to_exit) {
		    grazing_steps_left <- 10;
		    grass_cooldown_steps_left <- 125;
		    
		    ask nearest_grass {
			    grass_amount <- max([0.0, grass_amount - 0.1]);
			}
		}
		
		if (!empty(dog)) {
		    dog closest_dog <- dog with_min_of (each distance_to self);
		    if (self distance_to closest_dog < 2.0) {
		        grazing_steps_left <- 0;
		        heading <- closest_dog direction_to self;
		    }
		}
		
		if (grazing_steps_left > 0) {
		    grazing_steps_left <- grazing_steps_left - 1;
		} else {
		    if (going_to_exit) {
			    list<ground_cell> free_cells <- ground_cell where not each.blocked;
			    ground_cell exit_cell <- free_cells closest_to {98.0, 50.0};
			    do goto target: exit_cell.location on: free_cells;
			} else {
			    do move bounds: dog_free_space;
			}
			
		    if (grass_cooldown_steps_left > 0) {
		        grass_cooldown_steps_left <- grass_cooldown_steps_left - 1;
		    }
		}
		
		previous_cell <- current_cell;
		current_cell <- ground_cell closest_to self;
		
		if current_cell != previous_cell {
		    ask current_cell {
		        passages <- passages + 1;
		    }
		}
		
		if (location.x >= 96.0 and location.y >= 42.0 and location.y <= 58.0) {
		    ask world {
		        sheep_exited <- sheep_exited + 1;
		    }
		    do die;
		}
	}
	
}

experiment sheep_movement type: gui {
	parameter "Initial number of sheeps: " var: nb_sheeps_init min: 1 max: 100 category: "Sheep";
	parameter "Initial number of obstacles: " var: nb_obstacles_init min: 1 max: 10 category: "Obstacles";
	parameter "Initial number of vegetations: " var: nb_vegetations_init min: 0 max: 100 category: "Vegetations";
	parameter "Initial number of dogs: " var: nb_dogs_init min: 1 max: 3 category: "Dog";
	
	output {
		display View {
			species ground_cell aspect: base;
			species exit_gate aspect:base;
			species vegetation aspect: base;
			species dog aspect: base;
			species sheep aspect: base;
			species obstacle aspect: base;
		}
		
		monitor "Sheep exited" value: sheep_exited;
	}
}