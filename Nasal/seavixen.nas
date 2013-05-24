# this script contains a number of utilities for use with the Sea Vixen

#does what it says on the tin
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

# ================================ Initalize ====================================== 
# Make sure all needed properties are present and accounted
# for, and that they have sane default values.

view_number_Node = props.globals.getNode("/sim/current-view/view-number",1);
view_number_Node.setDoubleValue( 0 );

enabledNode = props.globals.getNode("/sim/headshake/enabled", 1);
enabledNode.setBoolValue(1);


controls.fullBrakeTime = 0; 

pilot_g = nil;
headshake = nil;
airbrake = nil;
flaps = nil;
crossfeed = nil;
ailerons = nil;


var time = 0;
var dt = 0;
var last_time = 0.0;

var xDivergence_damp = 0;
var yDivergence_damp = 0;
var zDivergence_damp = 0;

var last_xDivergence = 0;
var last_yDivergence = 0;
var last_zDivergence = 0;

var run_tyresmoke0 = 0;
var run_tyresmoke1 = 0;
var run_tyresmoke2 = 0;

var tyresmoke_0 = aircraft.tyresmoke.new(0,1,0.5);
var tyresmoke_1 = aircraft.tyresmoke.new(1,1,0.5);
var tyresmoke_2 = aircraft.tyresmoke.new(2,1,0.5);

initialize = func {

	print( "Initializing Sea Vixen utilities ..." );
	
	# initialize objects
	pilot_g = PilotG.new();
	headshake = HeadShake.new();
	airbrake = Airbrake.new();
	flaps = Flaps.new();
	ailerons = Ailerons.new();
	aircraft.steering.init();

	#crossfeed = FuelCock.new("crossfeed",
	#						"controls/fuel/crossfeed",
	#						0
	#						);
	
	#set listeners
	setlistener( "controls/flight/speedbrake-lever", func { airbrake.update(); } );
	setlistener( "controls/gear/gear-down", func { airbrake.update(); } );
	setlistener( "controls/flight/flaps", func { flaps.update(); } );

	# set it running on the next update cycle
	settimer( update, 0 );

	print( "running Sea Vixen utilities" );

} # end func

###
# ====================== end Initialization ========================================
###

###
# ==== this is the Main Loop which keeps everything updated ========================
##
update = func {

	pilot_g.update();
	pilot_g.gmeter_update();
	ailerons.update();
	
	if ( enabledNode.getValue() and view_number_Node.getValue() == 0 ) {
		headshake.update();
	}
		
	#print ("run_tyresmoke ",run_tyresmoke);
	
	
	settimer( update, 0 ); 

}# end main loop func

# ============================== end Main Loop ===============================

# ============================== specify classes ===========================



# =================================== fuel tank stuff ===================================
# Class that specifies fuel cock functions 
# 
FuelCock = {
	new : func ( name,
				control,
				initial_pos
				){
		var obj = { parents : [FuelCock] };
		obj.name = name;
		obj.control = props.globals.getNode( control, 1 );
		obj.control.setIntValue( initial_pos );
		
		print ( obj.name );
		return obj;
	},

	set: func ( pos ) {# operate fuel cock
		me.control.setValue( pos );
	},
}; #



	
	
# ========================== end fuel tank stuff ======================================


# =========================== hydraulic stuff ====================================
# Class that specifies airbrake functions 
# 
Airbrake = {
	new : func ( name = "airbrake",
				speedbrake_lever = "controls/flight/speedbrake-lever",
				gear_down = "controls/gear/gear-down",
				speedbrake = "controls/flight/speedbrake", 
				){
		var obj = { parents : [Airbrake] };
		obj.name = name;
		obj.speedbrake_lever = props.globals.getNode( speedbrake_lever, 1 );
		obj.gear_down = props.globals.getNode( gear_down, 1 );
		obj.speedbrake = props.globals.getNode( speedbrake, 1 );
		obj.speedbrake_lever.setBoolValue(0);
		
		print ( obj.name );
		return obj;
	},
	update : func () { # closes the airbrake when gear is down 
		var lever=[0,1];
		
		lever[0]= me.speedbrake_lever.getValue(); 
		lever[1]= me.gear_down.getValue(); 
		
		if ( !lever[0] ) {
			me.speedbrake.setValue( 0 ); 
		} elsif ( lever[0] and !lever[1] ) {
			me.speedbrake.setValue( 1 ); 
		} else {
			me.speedbrake.setValue( 0 );
		} 
	},	
	toggle : func (){             #toggles the lever up-down
		var lever = me.speedbrake_lever.getValue(); 
		lever = !lever;
		me.speedbrake_lever.setBoolValue( lever );
	},
}; 

###
# Class that specifies flap functions 
##
Flaps = {
	new : func ( name = "flap",
				flaps_lever = "controls/flight/flaps-lever",
				flaps = "controls/flight/flaps", 
				tail_flap = "controls/flight/tail-flap"
				){
		var obj = { parents : [Flaps] };
		obj.name = name;
		obj.flaps_lever = props.globals.getNode( flaps_lever, 1 );
		obj.flaps = props.globals.getNode( flaps, 1 );
		obj.tail_flap = props.globals.getNode( tail_flap, 1 );
		obj.flaps_lever.setIntValue(0);
		obj.tail_flap.setDoubleValue(0);
		
		print ( obj.name );
		return obj;
	},
	update : func () {             #adjusts the tail flap up-down
		me.tail_flap.setValue( me.flaps.getValue()  );
	},
}; #  end flap stuff 
	
###
# Class that specifies aileron functions 
##
Ailerons = {
	new : func ( name = "ailerons",
				aileron_input = "controls/flight/aileron",
				aileron_actuator_left = "/systems/hydraulic/outputs/aileron", 
				aileron_actuator_right = "/systems/hydraulic/outputs/aileron[1]"
				){
		var obj = { parents : [Ailerons] };
		obj.name = name;
		obj.input = props.globals.getNode( aileron_input, 1 );
		obj.output_left = props.globals.getNode( aileron_actuator_left, 1 );
		obj.output_right = props.globals.getNode( aileron_actuator_right, 1 );
		obj.output_left.setDoubleValue(0);
		obj.output_right.setDoubleValue(0);
		
		print ( obj.name );
		return obj;
	},
update : func () {             #adjusts the ailerons
	var x = me.input.getValue();
	var y = -0.25 * x * x + 0.75 * x;

	me.output_left.setValue( clamp(y, -1.0, 0.5 ));

	y = 0.25 * x * x + 0.75 * x;
	me.output_right.setValue( clamp(y, -0.5, 1.0 ));
	},
}; #  end aileron stuff 
# =========================== end hydraulic stuff ==============================	

# =============================== Pilot G stuff ================================
# Class that specifies pilot g functions 
# 
PilotG = {
	new : func ( name = "pilot-g",
				acceleration = "accelerations",
				pilot_g = "pilot-g",
				g_timeratio = "timeratio", 
				pilot_g_damped = "pilot-g-damped", 
				g_min = "pilot-gmin", 
				g_max = "pilot-gmax"
				){
		var obj = { parents : [PilotG] };
		obj.name = name;
		obj.accelerations = props.globals.getNode("accelerations", 1);
		obj.pilot_g = obj.accelerations.getChild( pilot_g, 0, 1 );
		obj.pilot_g_damped = obj.accelerations.getChild( pilot_g_damped, 0, 1 );
		obj.g_timeratio = obj.accelerations.getChild( g_timeratio, 0, 1 );
		obj.g_min = obj.accelerations.getChild( g_min, 0, 1 );
		obj.g_max = obj.accelerations.getChild( g_max, 0, 1 );
		obj.pilot_g.setDoubleValue(0);
		obj.pilot_g_damped.setDoubleValue(0); 
		obj.g_timeratio.setDoubleValue(0.0075);
		obj.g_min.setDoubleValue(0);
		obj.g_max.setDoubleValue(0);
		
		print ( obj.name );
		return obj;
	},
	update : func () {
		var n = me.g_timeratio.getValue(); 
		var g = me.pilot_g.getValue();
		var g_damp = me.pilot_g_damped.getValue();
		
		g_damp = ( g * n) + (g_damp * (1 - n));
			
		me.pilot_g_damped.setDoubleValue(g_damp);

		# print(sprintf("pilot_g_damped in=%0.5f, out=%0.5f", g, g_damp));
	},
	gmeter_update : func () {
		if( me.pilot_g_damped.getValue() < me.g_min.getValue() ){
			me.g_min.setDoubleValue( me.pilot_g_damped.getValue() );
		} elsif( me.pilot_g_damped.getValue() > me.g_max.getValue() ){
			me.g_max.setDoubleValue( me.pilot_g_damped.getValue() );
		}
	},
	get_g_timeratio : func () {
		return me.g_timeratio.getValue();
	},
};	



# Class that specifies head movement functions under the force of gravity
# 
#  - this is a modification of the original work by Josh Babcock

HeadShake = {
	new : func ( name = "headshake",
				x_accel_fps_sec = "x-accel-fps_sec",
				y_accel_fps_sec = "y-accel-fps_sec",
				z_accel_fps_sec = "z-accel-fps_sec",
				x_max_m = "x-max-m",
				x_min_m = "x-min-m",
				y_max_m = "y-max-m",
				y_min_m = "y-min-m",
				z_max_m = "z-max-m",
				z_min_m = "z-min-m",
				x_threshold_g = "x-threshold-g",
				y_threshold_g = "y-threshold-g",
				z_threshold_g = "z-threshold-g",
				x_config = "z-offset-m", 
				y_config = "x-offset-m",
				z_config = "y-offset-m",
				time_ratio = "time-ratio",
				){
		var obj = { parents : [HeadShake] };
		obj.name = name;
		obj.accelerations = props.globals.getNode( "accelerations/pilot", 1 );
		obj.xAccelNode = obj.accelerations.getChild(  x_accel_fps_sec, 0, 1 );
		obj.yAccelNode = obj.accelerations.getChild(  y_accel_fps_sec, 0, 1 );
		obj.zAccelNode = obj.accelerations.getChild(  z_accel_fps_sec, 0, 1 );
		obj.sim = props.globals.getNode( "sim/headshake", 1 );
		obj.xMaxNode = obj.sim.getChild( x_max_m, 0, 1 );
		obj.xMaxNode.setDoubleValue( 0.025 );
		obj.xMinNode = obj.sim.getChild( x_min_m, 0, 1 );
		obj.xMinNode.setDoubleValue( -0.01 );
		obj.yMaxNode = obj.sim.getChild( y_max_m, 0, 1 );
		obj.yMaxNode.setDoubleValue( 0.01 );
		obj.yMinNode = obj.sim.getChild( y_min_m, 0, 1 );
		obj.yMinNode.setDoubleValue( -0.01 );
		obj.zMaxNode = obj.sim.getChild( z_max_m, 0, 1 );
		obj.zMaxNode.setDoubleValue( 0.01 );
		obj.zMinNode = obj.sim.getChild( z_min_m, 0, 1 );
		obj.zMinNode.setDoubleValue( -0.03 );
		obj.xThresholdNode = obj.sim.getChild(x_threshold_g, 0, 1 );
		obj.xThresholdNode.setDoubleValue( 0.5 );
		obj.yThresholdNode = obj.sim.getChild(y_threshold_g, 0, 1 );
		obj.yThresholdNode.setDoubleValue( 0.5 );
		obj.zThresholdNode = obj.sim.getChild(z_threshold_g, 0, 1 );
		obj.zThresholdNode.setDoubleValue( 0.5 );
		obj.time_ratio_Node = obj.sim.getChild( time_ratio , 0, 1 );
		obj.time_ratio_Node.setDoubleValue( 0.5 );
		obj.config = props.globals.getNode("/sim/view/config", 1);
		obj.xConfigNode = obj.config.getChild( x_config , 0, 1 );
		obj.yConfigNode = obj.config.getChild( y_config , 0, 1 );
		obj.zConfigNode = obj.config.getChild( z_config , 0, 1 );
		
		obj.seat_vertical_adjust_Node = props.globals.getNode( "/controls/seat/vertical-adjust", 1 );
		obj.seat_vertical_adjust_Node.setDoubleValue( 0 );
		
		print ( obj.name );
		return obj;
	},
	update : func () {

		# There are two coordinate systems here, one used for accelerations, 
		# and one used for the viewpoint.
		# We will be using the one for accelerations.
		
		var n = pilot_g.get_g_timeratio(); 
		var seat_vertical_adjust = me.seat_vertical_adjust_Node.getValue();
		
		var xMax = me.xMaxNode.getValue();
		var xMin = me.xMinNode.getValue();
		var yMax = me.yMaxNode.getValue();
		var yMin = me.yMinNode.getValue();
		var zMax = me.zMaxNode.getValue();
		var zMin = me.zMinNode.getValue();

		#work in G, not fps/s
		var xAccel = me.xAccelNode.getValue()/32;
		var yAccel = me.yAccelNode.getValue()/32;
		var zAccel = (me.zAccelNode.getValue() + 32)/32; # We aren't counting gravity
 
		var xThreshold =  me.xThresholdNode.getValue();
		var yThreshold =  me.yThresholdNode.getValue();
		var zThreshold =  me.zThresholdNode.getValue();
		
		var xConfig = me.xConfigNode.getValue();
		var yConfig = me.yConfigNode.getValue();
		var zConfig = me.zConfigNode.getValue();
		
		# Set viewpoint divergence and clamp
		# Note that each dimension has its own special ratio and +X is clamped at 1cm
		# to simulate a headrest.

		if (xAccel < -1) {
			xDivergence = ((( -0.0506 * xAccel ) - ( 0.538 )) * xAccel - ( 0.9915 ))
										 * xAccel - 0.52;
		} elsif (xAccel > 1) {
			xDivergence = ((( -0.0387 * xAccel ) + ( 0.4157 )) * xAccel - ( 0.8448 )) 
											* xAccel + 0.475;
		} else {
			xDivergence = 0;
				}

		if (yAccel < -0.5) {
			yDivergence = ((( -0.013 * yAccel ) - ( 0.125 )) * yAccel - (  0.1202 )) * yAccel - 0.0272;
		} elsif (yAccel > 0.5) {
			yDivergence = ((( -0.013 * yAccel ) + ( 0.125 )) * yAccel - (  0.1202 )) * yAccel + 0.0272;
		} else {
			yDivergence = 0;
		}

		if (zAccel < -1) {
			zDivergence = ((( -0.0506 * zAccel ) - ( 0.538 )) 
						* zAccel - ( 0.9915 )) * zAccel - 0.52;
		} elsif (zAccel > 1) {
			zDivergence = ((( -0.0387 * zAccel ) + ( 0.4157 )) 
						* zAccel - ( 0.8448 )) * zAccel + 0.475;
		} else {
			zDivergence = 0;
		}
		
		xDivergence_total = ( xDivergence * 0.25 ) + ( zDivergence * 0.25 );
		
		if (xDivergence_total > xMax){ xDivergence_total = xMax; }
		if (xDivergence_total < xMin){ xDivergence_total = xMin; }
		if (abs(last_xDivergence - xDivergence_total) <= xThreshold){
			xDivergence_damp = ( xDivergence_total * n) + ( xDivergence_damp * (1 - n));
		#	print ("x low pass");
		} else {
			xDivergence_damp = xDivergence_total;
		#	print ("x high pass");
		}

		last_xDivergence = xDivergence_damp;

		#print (sprintf("x total=%0.5f, x min=%0.5f, x div damped=%0.5f", xDivergence_total,
		# xMin , xDivergence_damp));	

		yDivergence_total = yDivergence;
		if ( yDivergence_total >= yMax ){ yDivergence_total = yMax; }
		if ( yDivergence_total <= yMin ){ yDivergence_total = yMin; }

		if (abs(last_yDivergence - yDivergence_total) <= yThreshold){
			yDivergence_damp = ( yDivergence_total * n) + ( yDivergence_damp * (1 - n));
	#	 	print ("y low pass");
		} else {
			yDivergence_damp = yDivergence_total;
	#		print ("y high pass");
		}

		last_yDivergence = yDivergence_damp;

	#	print (sprintf("y=%0.5f, y total=%0.5f, y min=%0.5f, y div damped=%0.5f",
	#						yDivergence, yDivergence_total, yMin , yDivergence_damp));
	
		zDivergence_total =  xDivergence + zDivergence;
		if ( zDivergence_total >= zMax ){ zDivergence_total = zMax; }
		if ( zDivergence_total <= zMin ){zDivergence_total = zMin; }

		if (abs(last_zDivergence - zDivergence_total) <= zThreshold){ 
			zDivergence_damp = ( zDivergence_total * n) + ( zDivergence_damp * (1 - n));
		#	print ("z low pass");
		} else {
			zDivergence_damp = zDivergence_total;
		#	print ("z high pass");
		}
	
		last_zDivergence = zDivergence_damp;
	
	#	print (sprintf("z total=%0.5f, z min=%0.5f, z div damped=%0.5f", 
	#										zDivergence_total, zMin , zDivergence_damp));
	
		setprop( "/sim/current-view/z-offset-m", xConfig + xDivergence_damp );
		setprop( "/sim/current-view/x-offset-m", yConfig + yDivergence_damp );
		setprop( "/sim/current-view/y-offset-m", zConfig + zDivergence_damp 
																+ seat_vertical_adjust );
				
		},
	};

# ======================================= end Pilot G stuff ============================

# Fire it up

settimer(initialize,0);

# end 
