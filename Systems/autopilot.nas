# =============================== autopilot =================================
#
# This script provides the Sea Vixen autopilot controls and settings

###
# Initialize internal values
##

yaw = nil;
pitch = nil;
height = nil;
heading = nil;
summer = nil;
autoStabsG = nil;
autoThrottle = nil;
autoOff = nil;
tailplaneGearChange = nil;

#variables
var time = 0;
var dt = 0;
var last_time = 0.0;

##
# Initialize the autopilot system
#

init_autopilot = func {
	print("Initializing Sea Vixen Autopilot ...");

###
# Autostab channel ("name", "lock property", "output property"
#					"control property", initial switch position, )
###

	yaw = Channel.new("yaw-stab",
					"autopilot/locks/yaw-stab",
					"autopilot/internal/rudder-stab",
					"controls/switches/auto-stabs/yaw_channel",
					1);
					
	pitch = Channel.new("pitch-stab",
					"autopilot/locks/pitch-stab",
					"autopilot/internal/elevon-stab",
					"controls/switches/auto-stabs/pitch_channel",
					1);
###
# Autopilot channel ("name", 
#					"hold-name", "hold-name", "hold-name",
#					"target property", 
#					"target property", 
#					"target property",
# 					"lock property", "output property"
#					"control property", initial switch position, )
###	
	heading = APChannel.new("heading",
					"true-heading-hold",,,
					"autopilot/settings/target-heading-deg",,,
					"autopilot/locks/heading",
					"autopilot/internal/rudder-trim",
					"controls/switches/autopilot/heading_channel",
					0);
	height	= APChannel.new("height",
					"speed-with-pitch-trim",
					"mach-with-pitch-trim",
					"altitude-with-pitch-trim",
					"autopilot/settings/target-speed-kt",
					"autopilot/settings/target-mach",
					"autopilot/settings/target-altitude-ft",
					"autopilot/locks/speed",
					"autopilot/internal/elevon-trim",
					"controls/switches/autopilot/height_channel",
					0);
	summer = Summer.new();
	autoStabsG = AutoStabsG.new();
	autoThrottle = AutoThrottle.new();	
	autoOff = AutoOff.new();
	tailplaneGearChange = TailplaneGearChange.new();
		
	setlistener( "controls/switches/auto-stabs/yaw_channel",  
						func { yaw.set_switch(); } );
	setlistener( "controls/switches/auto-stabs/pitch_channel", 
						func { pitch.set_switch(); } );
	setlistener( "controls/switches/autopilot/heading_channel", 
						func { heading.set_switch(); } );
	setlistener( "controls/switches/autopilot/height_channel", 
						func { height.set_switch(); } );
	setlistener( "controls/switches/auto-stabs/yaw_channel",  
						func { heading.set_switch(); } );
	setlistener( "controls/switches/auto-stabs/pitch_channel", 
						func { heading.set_switch(); } );
	setlistener( "controls/switches/auto-throttle", 
						func { autoThrottle.set_switch(); } );
	setlistener( "controls/gear/gear-down", 
						func { autoThrottle.set_switch(); } );
	setlistener( "controls/flight/elevator-trim", 
						func { autoOff.set_switch(); } );
	
# Request that the update fuction be called 
	settimer(update_autopilot, 0.3 );
	
	print ("Running Sea Vixen Autopilot");
				
} #end func



###
# This is the main loop which keeps eveything updated
#
update_autopilot = func {
	time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
	dt = time - last_time;
	last_time = time;

autoStabsG.update();	
summer.update();
autoOff.update();
tailplaneGearChange.update();


#keep the target values up-to-date when not in use		
if ( !heading.status_node.getValue() ){ 
	heading.heading_follower();
	height.height_follower();
	}
		
# Request that the update fuction be called again next frame
	settimer(update_autopilot, 0);
	
} # end func

###
# Setup a timer based call to initialize the autopilot system as
# soon as possible.
settimer(init_autopilot, 0);

###
# ============================ Specify classes ================================
##

# Class that specifies an autostab channel
# 
Channel = {
	new : func (name, lock, output, control, switch ){
		var obj = { parents : [Channel]};
		obj.name = name;
		obj.lock = props.globals.getNode( lock, 1 );
		obj.output = props.globals.getNode( output, 1 );
		obj.output.setDoubleValue( 0 );
		obj.control = props.globals.getNode( control, 1 );
		obj.control.setBoolValue( switch );
		obj.set_switch();
		print (obj.name);
		return obj;
	},
	set_switch : func () {
		
		print ( "control ", me.control.getValue() );
		if ( me.control.getValue() ) {
			me.set_lock( me.name );
		} else {
			me.set_lock( "" );
		}
	},
	set_lock : func ( name ){
		me.lock.setValue( name );
		if (name == ""){
			me.output.setDoubleValue( 0 );
		}
	},
	get_switch : func {
		return me.control.getValue();
	},
	get_output : func {
		return me.output.getValue();
	},
};	

# Class that specifies an autopilot channel
# 
APChannel = {
	new : func (name, 
				hold, hold1, hold2,
				target, target1, target2,
				lock, output, control, switch, 
				status = "autopilot/settings/status",
				heading = "instrumentation/master-reference-gyro/indicated-hdg-deg",
				speed = "velocities/airspeed-kt",
				mach  = "velocities/mach",
				altitude = "position/altitude-ft", 
				target_roll = "autopilot/settings/target-roll-deg",
				roll = "instrumentation/master-reference-gyro/indicated-roll-deg",
				target_pitch = "autopilot/settings/target-pitch-deg",
				pitch = "instrumentation/master-reference-gyro/indicated-pitch-deg"
				
				){
		var obj = { parents : [APChannel]};
		obj.name = name;
		obj.hold = hold;
		obj.hold1 = hold1;
		obj.hold2 = hold2;
		obj.target = props.globals.getNode( target, 1 );
		obj.target1 = props.globals.getNode( target1, 1 ); 
		obj.target2 = props.globals.getNode( target2, 1 ); 
		obj.lock = props.globals.getNode( lock, 1 );
		obj.output = props.globals.getNode( output, 1 );
		obj.output.setDoubleValue( 0 );
		obj.control = props.globals.getNode( control, 1 );
		obj.control.setIntValue( switch );
		obj.status_node = props.globals.getNode( status, 1);
		obj.status_node.setBoolValue( 0 );
		obj.heading_node = props.globals.getNode( heading, 1 );
		obj.heading_node.setDoubleValue( 0 );
		obj.speed_node = props.globals.getNode( speed , 1 );
		obj.mach_node = props.globals.getNode(mach, 1 );
		obj.altitude_node = props.globals.getNode( altitude, 1 );
		obj.target_roll_node = props.globals.getNode(target_roll, 1 );
		obj.roll_node = props.globals.getNode(roll, 1 );
		obj.target_pitch_node = props.globals.getNode(target_pitch, 1 );
		obj.pitch_node = props.globals.getNode(pitch, 1 );
		
		print (obj.name);
		return obj;
	},
	set_switch : func ( ){
	
	print (	yaw.get_switch(),	
			pitch.get_switch(),
			height.get_switch(),
			heading.get_switch(),
			 );
	
		if ( heading.get_switch() and yaw.get_switch() and pitch.get_switch() 
					and height.get_switch() ) {
			heading.lock.setValue("true-heading-hold");
			heading.target.setValue( me.heading_node.getValue() );
			print ( "heading " , me.heading_node.getValue()) ;
			print ( "height " , height.get_switch()) ;
			if (height.get_switch() == 1) {
				height.lock.setValue( "speed-with-pitch-trim" );
				height.target.setValue( me.speed_node.getValue() );
			} elsif (height.get_switch() == 2){
				height.lock.setValue("mach-with-pitch-trim");
				height.target1.setValue( me.mach_node.getValue() );
			} else{
				height.lock.setValue("height-with-pitch-trim");
				height.target2.setValue( me.altitude_node.getValue() );
				print (me.altitude_node.getValue());
			} 
			me.status_node.setBoolValue( 1 );
			print ( "height lock " , height.lock.getValue()) ; 
		} else {
			heading.lock.setValue("");
			heading.output.setDoubleValue( 0 );
			heading.control.setValue ( 0 );
			height.lock.setValue("");
			height.output.setDoubleValue( 0 );
			me.status_node.setBoolValue( 0 );
			print ( "height " , height.get_switch()) ;
			print ( "height lock " , height.lock.getValue()) ; 
		}
	},
	get_switch : func {
		return me.control.getValue();
	},
	heading_follower : func {
		heading.target.setValue( me.heading_node.getValue() );
		heading.target_roll_node.setValue( me.roll_node.getValue() );
	},
	height_follower : func {
		height.target.setValue( me.speed_node.getValue() );
		height.target1.setValue( me.mach_node.getValue() );
		height.target2.setValue( me.altitude_node.getValue() );
		height.target_pitch_node.setValue( me.pitch_node.getValue() );
	},
};
	
# Class that sets/unsets the elevon stroke restrictors, and sums the elevon 
# and and rudder outputs
#
Summer = {
	new : func 	( speed = "instrumentation/airspeed-indicator/indicated-speed-kt[1]",
				restrictor = "controls/flight/elevon_stroke_restrictor",
				elevon = "controls/flight/elevon",
				rudder = "controls/flight/rudder-auto") {
		var obj = { parents : [Summer] };
		obj.speed_node = props.globals.getNode(speed, 1);
		obj.speed_node.setDoubleValue( 0 );
		obj.elevon_stroke_restrictor_node = props.globals.getNode(restrictor, 1);
		obj.elevon_stroke_restrictor_node.setBoolValue( 0 );
		obj.elevon_node = props.globals.getNode(elevon, 1);
		obj.elevon_node.setDoubleValue( 0 );
		obj.rudder_auto_node = props.globals.getNode(rudder, 1);
		obj.rudder_auto_node.setDoubleValue( 0 );
		obj.min = 359;
		obj.max = 369;
		obj.max_elevon = 1.2;
		obj.min_elevon = -1.2;
		obj.update();
		print("summer");
		return obj;
	},
	update : func  {
		var elevon = pitch.output.getValue() + height.output.getValue();
		var rudder = yaw.output.getValue() + heading.output.getValue();
		if ( me.speed_node.getValue() > me.max ) {
			me.elevon_stroke_restrictor_node.setBoolValue(1);
		} elsif ( me.speed_node.getValue() < me.min ) {
			me.elevon_stroke_restrictor_node.setBoolValue(0);
		}
		
		if ( me.elevon_stroke_restrictor_node.getValue() ) {
			if ( elevon > me.max_elevon ) { elevon = me.max_elevon; }
			if ( elevon < me.min_elevon ) { elevon = me.min_elevon; }
		}
		
		me.elevon_node.setDoubleValue( elevon );
		me.rudder_auto_node.setDoubleValue( rudder );
	},
};

# Class that switches off autostabs and autopilot if g limits exceeded
# 
AutoStabsG = {
	new : func 	( pilot_g = "accelerations/pilot-g-damped" ) {
		var obj = { parents : [AutoStabsG] };
		obj.pilot_g_node = props.globals.getNode(pilot_g, 1);
		obj.pilot_g_node.setDoubleValue( 0 );
		obj.g_min = -0.25;
		obj.g_max = 4;
		obj.update();
		print("AutoStabsG");
		return obj;
	},
	update : func {  
		var g = me.pilot_g_node.getValue();
		var pitch_switch = pitch.get_switch();
		var yaw_switch = yaw.get_switch();
		var heading_switch = heading.get_switch();
		var heading_switch = heading.get_switch();
	
		if (pitch_switch) {
			if (g < me.g_min or g > me.g_max) {
				pitch.lock.setValue("");
			} else {
				pitch.lock.setValue("pitch-stab");
			}
		}
			
		if (yaw_switch) {
			if (g < me.g_min or g > me.g_max) {
				yaw.lock.setValue("");
			} else {
				yaw.lock.setValue("yaw-stab");
			}
		}
		
		if (heading_switch) {
			if (g < me.g_min or g > me.g_max) {
				heading.lock.setValue("");
				heading.control.setBoolValue(0);	
			}
		}
	},
};


# Class that specifies an auto-throttle channel
# 
AutoThrottle = {
	new : func (name = "autothrottle", 
				lock = "autopilot/locks/autothrottle", 
				output = "autopilot/settings/target-auto-throttle-speed-kt",
				output1 = "controls/engines/engine[0]/auto-throttle", 
				control = "controls/switches/auto-throttle",
				control1 = "controls/gear/gear-down",
				switch = 0 ){
		var obj = { parents : [AutoThrottle] };
		obj.name = name;
		obj.lock = props.globals.getNode( lock, 1 );
		obj.output = props.globals.getNode( output, 1 );
		obj.output.setDoubleValue( 129 );
		obj.output1 = props.globals.getNode( output1, 1 );
		obj.control = props.globals.getNode( control, 1 );
		obj.control.setBoolValue( switch );
		obj.control1 = props.globals.getNode( control1, 1 );
		obj.set_switch();
		print (obj.name );
		return obj;
	},
	set_switch : func () {
		if (  me.control.getValue() and me.control1.getValue() ) {
			me.set_lock( me.name );
		} else {
			me.set_lock( "" );
		}
	},
	set_lock : func ( name ){
		me.lock.setValue( name );
		if (name == ""){
			me.output.setDoubleValue( 0 );
			me.output1.setDoubleValue( 0 );
		} else {
			me.output.setDoubleValue( 129 );
		}
	},
	get_switch : func {
		return me.control.getValue();
	},
};	

# Class that specifies the auto-off functions
# 
AutoOff = {
	new : func (name = "auto-off",
				control = "controls/gear/brake-left",
				control1 = "controls/gear/brake-right" 
				){
		var obj = { parents : [AutoOff] };
		obj.name = name;
		obj.control = props.globals.getNode( control, 1 );
		obj.control1 = props.globals.getNode( control1, 1 );
		print (obj.name );
		return obj;
	},
	set_switch : func () {
		if (pitch.get_switch()) {
			#elevon_node.setDoubleValue(0);
			pitch.set_lock("");
		} else {
			pitch.set_lock("pitch-stab");
		}
		
		if (yaw.get_switch()) {
			#rudder_auto_node.setDoubleValue(0);
			yaw.set_lock("");
		} else {
			yaw.set_lock("yaw-stab");
		}
		
		if (heading.get_switch()) {
			heading.control.setBoolValue( 0 );
		} 
		
		if (autoThrottle.get_switch()) {
			autoThrottle.set_lock("");
			print ("here");
		}
	},
	update : func () {
		if ( me.control.getValue() or me.control1.getValue() ) {
			me.set_switch();
		} else {
			autoThrottle.set_switch();
		}
	},
};	

# Class that specifies the tailplane gear change functions
# 
TailplaneGearChange = {
	new : func (name = "tailplane gear change",
				altitude = "position/altitude-ft", 
				mach  = "velocities/mach",
				control = "controls/gear/gear-down",
				control1 = "controls/flight/elevator",
				control2 = "controls/flight/elevator[1]",
				control3 = "controls/flight/tailplane-gear-change",
				switch = 2,
				){
		var obj = { parents : [TailplaneGearChange] };
		obj.name = name;
		obj.mach_node = props.globals.getNode(mach, 1 );
		obj.altitude_node = props.globals.getNode( altitude, 1 );
		obj.control = props.globals.getNode( control, 1 );
		obj.control1 = props.globals.getNode( control1, 1 );
		obj.control2 = props.globals.getNode( control2, 1 );
		obj.control2.setDoubleValue( 0 );
		obj.control3 = props.globals.getNode( control3, 1 );
		obj.control3.setIntValue( switch );
		obj.low = 0.5;
		obj.medium = 0.75;
		obj.high = 1;
		print (obj.name );
		return obj;
	},
	set_switch : func () {
		
	},
	update : func () {
		if ( me.control3.getValue() == 2 ) {
			if ( me.altitude_node.getValue() > 20000 and me.mach_node.getValue() > 1.0 ) {
				me.control2.setValue( me.control1.getValue() * me.high);
			} else {
				if ( me.control.getValue() ) {
					me.control2.setValue( me.control1.getValue() * me.medium );
				} else { 
					me.control2.setValue( me.control1.getValue() * me.low);
				}
			}
		} elsif ( me.control3.getValue() == 1 ) {
			me.control2.setValue( me.control1.getValue() * me.medium );
		}
	},
};	







# =============================== end autopilot stuff =================================
	 