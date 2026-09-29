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
	
	init {
		create sheep number: nb_sheeps_init;
		create obstacle number: 5;
	}
}

grid ground_cell width: 50 height: 50 {
    int passages <- 0;
    float path_intensity <- min([1.0, passages / 100.0]);
    
    aspect base {
        path_intensity <- min([1.0, passages / 100.0]);

	    int red <- int(255 - (115 * path_intensity));
		int green <- int(255 - (155 * path_intensity));
		int blue <- int(255 - (195 * path_intensity));
		
		draw shape color: rgb(red, green, blue);
    }
}

species obstacle {
    float width <- 13.0;
    float height <- 2.0;

    aspect base {
        draw rectangle(width, height) color: #black;
    }
}

species sheep skills: [moving] {
	float size <- 1.0;
	rgb color <- #blue;
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
	
	aspect base {
		draw circle(size) color: color;
		
		loop n over: neighbors {
			draw line([self.location, n.location]);
		}
		
		if !empty(neighbors) {
	        draw circle(0.3) at: neighbors_center color: #red;
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
//			heading <- too_close_center direction_to self;
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
		else if !empty(neighbors) {

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
		
//		if !empty(nearby_path_cells) {
//		    float direction_to_path <- self direction_to best_path_cell;
//		
//		    path_difference <- direction_to_path - heading;
//		
//		    if path_difference > 180 {
//		        path_difference <- path_difference - 360;
//		    }
//		
//		    if path_difference < -180 {
//		        path_difference <- path_difference + 360;
//		    }
//		
//		    heading <- heading + path_difference * path_following_strength;
//		}
		
		do move;
		
		previous_cell <- current_cell;
		current_cell <- ground_cell closest_to self;
		
		if current_cell != previous_cell {
		    ask current_cell {
		        passages <- passages + 1;
		    }
		}
	}
	
	reflex find_neightbors {
		neighbors <- sheep select ((each != self) and (each distance_to self < 7));
		too_close_neighbors <- sheep select ((each != self) and (each distance_to self<2));
		nearby_obstacles <- obstacle select (each distance_to self < 10);
		nearby_path_cells <- (ground_cell at_distance 5) select (each.passages > 10);
//		nearby_path_cells <- ground_cell select ((each distance_to self < 5) and (each.passages > 10));
		
		if !empty(nearby_path_cells) {
		    best_path_cell <- nearby_path_cells with_max_of each.passages;
		}
		
		if !empty(nearby_obstacles) {
		    nearest_obstacle <- nearby_obstacles with_min_of (each distance_to self);
		}
		
		if !empty(neighbors) {
			neighbors_center <- mean(neighbors collect each.location);
			neighbors_heading <- atan2(mean_dy, mean_dx);
//			neighbors_heading <- mean(neighbors collect each.heading);
	
			mean_dx <- mean(neighbors collect cos(each.heading));
			mean_dy <- mean(neighbors collect sin(each.heading));
		}
		
		if !empty(too_close_neighbors) {
			too_close_center <- mean(too_close_neighbors collect each.location);
		}
		
	}
	
}

experiment sheep_movement type: gui {
	parameter "Initial number of sheeps: " var: nb_sheeps_init min: 1 max: 100 category: "Sheep";
	
	output {
		display View {
			species ground_cell aspect: base;
			species sheep aspect: base;
			species obstacle aspect: base;
		}
	}
}