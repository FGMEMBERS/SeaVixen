


###
# ======================== Initialize ========================================
#

###
# Initialize internal values
#
total_port = props.globals.getNode("consumables/fuel/total-fuel-port-lbs", 1);
total_stbd = props.globals.getNode("consumables/fuel/total-fuel-stbd-lbs", 1);

total_port.setDoubleValue(0);
total_stbd.setDoubleValue(0);

var total_used_lbs = 0;
var brightness = 1;
var power_norm = 1;

init = func {
	print ( "Initializing Sea Vixen instrumentation ..." );
	
###
# the purpose of this section is to simulate electrical instruments where FlightGear uses 
# other power sources, or none, as the default
###

###
#switches ("name", "input property", "electrical output property", "output property")
##

	asi = Switch.new("asi",
			"instrumentation/airspeed-indicator/indicated-speed-kt",
			"flight-instruments",
			"instrumentation/airspeed-indicator/indicated-speed-kt[1]");
	altimeter = Switch.new("altimeter",
			"instrumentation/altimeter/indicated-altitude-ft",
			"flight-instruments",
			"instrumentation/altimeter/indicated-altitude-ft[1]");
	gmeter_g = Switch.new("gmeter-g",
			"accelerations/pilot-g-damped",
			"flight-instruments",
			"instrumentation/gmeter/pilot-g-damped");
	flowmeter_flow = Switch.new("flowmeter-flow",
			"consumables/fuel/total-fuel-flow-lbspm",
			"flight-instruments",
			"instrumentation/flowmeter/indicated-fuel-flow-lbspm");
	flowmeter_used = Switch.new("flowmeter-used",
			"consumables/fuel/total-fuel-used-lbs",
			"flight-instruments",
			"instrumentation/flowmeter/indicated-fuel-used-lbs");

# we have finished intitialization, run the updater, and display message			
	settimer( update, 0.3 );
	print ( "Running Sea Vixen instrumentation " );
			
}

### 
## classes
#
Switch = {
	new : func( name, input_prop, electrical_prop, output_prop ){
		var obj = { parents : [Switch]};
		obj.name = name;
		obj.input = props.globals.getNode( input_prop, 1 );
		obj.source = props.globals.getNode( "systems/electrical/outputs", 1 ).getChild( electrical_prop, 0, 1);
		obj.output = props.globals.getNode( output_prop, 1 );
		obj.source.setValue( 0 );
		append(Switch.list, obj); 
		print ( obj.name );
		return obj;
	},
	update : func {
		if( me.source.getValue() > 10 ){
			me.output.setDoubleValue( me.input.getValue() );
		} else {
			me.output.setDoubleValue( 0 );
		}
	},
	list : []
};

Hsi = {
	new : func( name ){
		var obj = { parents : [Hsi]};
		obj.name = name;
		
		append(Hsi.list, obj); 
		return obj;
	},
	
	list : []
};	

###
# This is the main loop which keeps eveything updated
#
update = func {
	
	foreach (var s; Switch.list) {
		s.update();	
	}		

##
# set up properties for the fuel gauges
		
var sum_port = sum_stbd = 0;
		
	for ( var i=0 ; i < 12 ; i = i + 2 ){ #note- pinion and drop tanks are un-gauged
		  	  
			tank = props.globals.getNode("consumables/fuel",1).getChild("tank",i,1);
			contents_port =  tank.getNode("level-lbs", 1).getValue();;
			
			if (contents_port == nil){ contents_port = 0; }
			sum_port += contents_port;
			
			tank = props.globals.getNode("consumables/fuel",1).getChild("tank",i + 1,1);
			contents_stbd =  tank.getNode("level-lbs", 1).getValue();;
			
			if (contents_stbd == nil){ contents_stbd = 0; }
			sum_stbd += contents_stbd;
	}
				
	total_port.setDoubleValue(sum_port);
	total_stbd.setDoubleValue(sum_stbd);
		
# Request that the update fuction be called again next frame
	settimer(update, 0);

}# end update func



# ==================== Undercarriage Indicator Lights =======================

output = props.globals.getNode("systems/electrical/outputs", 1);
supply = output.getChild("gear-pos-indicator",0 ,1 );
supply_emergency = output.getChild("gear-pos-indicator-emergency", 0, 1);
dayNight = props.globals.getNode("controls/switches/dayNight", 1);
noseGear = props.globals.getNode("gear/gear[0]/position-norm", 1);
portGear = props.globals.getNode("gear/gear[1]/position-norm", 1);
stbdGear = props.globals.getNode("gear/gear[2]/position-norm", 1);
changeLamps = props.globals.getNode("controls/switches/changeLamps", 1);
lights = props.globals.getNode("sim/model/lightning/lights/", 1);

dayNight.setBoolValue(1);
noseGear.setDoubleValue(1);
portGear.setDoubleValue(1);
stbdGear.setDoubleValue(1);
changeLamps.setBoolValue(0);

gearLights = func {
	
	volts = supply.getValue();
	volts_mg = supply_emergency.getValue();
	
	if ( volts != nil ){
		power_norm = volts/28;
	} 
	
	if (  volts_mg != nil and volts_mg > volts ) {
		power_norm = volts_mg/28;
	}
	
	brightness = power_norm * (dayNight.getValue() + 0.75);
	

	# Port Gear
	if (portGear.getValue() < 1) {
		lights.getChild( "port-red", 0, 1).setDoubleValue( brightness );
		lights.getChild( "port-green", 0 ,1).setDoubleValue( 0 );
		lights.getChild( "port-green", 1, 1).setDoubleValue( 0 );
	} elsif ( !changeLamps.getValue() ){
		lights.getChild( "port-red", 0, 1).setDoubleValue( 0 );
		lights.getChild( "port-green", 0 ,1).setDoubleValue( brightness );
		lights.getChild( "port-green", 1, 1).setDoubleValue( 0 );
	} else {
		lights.getChild( "port-red", 0, 1).setDoubleValue( 0 );
		lights.getChild( "port-green", 0 ,1).setDoubleValue( 0 );
		lights.getChild( "port-green", 1, 1).setDoubleValue( brightness ); 
	}
	# Nose Leg
	if (noseGear.getValue() < 1) {
		lights.getChild( "nose-red", 0, 1).setDoubleValue( brightness );
		lights.getChild( "nose-green", 0 ,1).setDoubleValue( 0 );
		lights.getChild( "nose-green", 1, 1).setDoubleValue( 0 );
	} elsif ( !changeLamps.getValue() ){
		lights.getChild( "nose-red", 0, 1).setDoubleValue( 0 );
		lights.getChild( "nose-green", 0 ,1).setDoubleValue( brightness );
		lights.getChild( "nose-green", 1, 1).setDoubleValue( 0 );
	} else {
		lights.getChild( "nose-red", 0, 1).setDoubleValue( 0 );
		lights.getChild( "nose-green", 0 ,1).setDoubleValue( 0 );
		lights.getChild( "nose-green", 1, 1).setDoubleValue( brightness );
	}
	# Starboard Leg
	if ( stbdGear.getValue() < 1) {
		lights.getChild( "stbd-red", 0, 1).setDoubleValue( brightness );
		lights.getChild( "stbd-green", 0 ,1).setDoubleValue( 0 );
		lights.getChild( "stbd-green", 1, 1).setDoubleValue( 0 );
	} elsif ( !changeLamps.getValue() ){
		lights.getChild( "stbd-red", 0, 1).setDoubleValue( 0 );
		lights.getChild( "stbd-green", 0 ,1).setDoubleValue( brightness );
		lights.getChild( "stbd-green", 1, 1).setDoubleValue( 0 );
	} else {
		lights.getChild( "stbd-red", 0, 1).setDoubleValue( 0 );
		lights.getChild( "stbd-green", 0 ,1).setDoubleValue( 0 );
		lights.getChild( "stbd-green", 1, 1).setDoubleValue( brightness );
	}

settimer(gearLights, 0.3);

} # End of Function

settimer(gearLights, 0.3);

###
# Setup a timer based call to initialize the instruments as
# soon as possible.
settimer(init, 0);

settimer(gearLights, 0.3);

