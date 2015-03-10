# This is aminor amendment of fuel.nas which changes the logic so that the 
# code no longer changes the selection state of tanks.



# Properties under /consumables/fuel/tank[n]:
# + level-gal_us    - Current fuel load.  Can be set by user code.
# + level-lbs       - OUTPUT ONLY property, do not try to set
# + selected        - boolean indicating tank selection.
# + density-ppg     - Fuel density, in lbs/gallon.
# + capacity-gal_us - Tank capacity 
#
# Properties under /engines/engine[n]:
# + fuel-consumed-lbs - Output from the FDM, zeroed by this script
# + out-of-fuel       - boolean, set by this code.


# =============================== Utility Function ================================

initDoubleProp = func {

	node = arg[0]; prop = arg[1]; val = arg[2];
	if(node.getNode(prop) != nil) {
		val = num(node.getNode(prop).getValue());
	}
	node.getNode(prop, 1).setDoubleValue(val != nil ? val : 0);

}# end func

# =========================== end Utility Function ================================



# ============================= Replace existing function ================================

fuel.fuelUpdate = func{};


# =================================== Fuel Update ========================================


# ================================ Initalize ====================================== 
# Make sure all needed properties are present and accounted
# for, and that they have sane default values.

AllEngines = props.globals.getNode("engines").getChildren("engine");
AllTanks = props.globals.getNode("consumables/fuel").getChildren("tank");
CrossConnected = props.globals.getNode("controls/fuel/crossfeed",1);
Tank = props.globals.getNode("consumables/fuel", 1).getChild("tank", 0, 1);
FlowProp = props.globals.getNode("consumables/fuel/total-fuel-flow-lbspm", 1);
UsedProp = props.globals.getNode("consumables/fuel/total-fuel-used-lbs", 1);

Tank.getNode("density-ppg", 1).setDoubleValue(6.7);

CrossConnected.setBoolValue( 0 );



crossfeed = nil;
portfeed = nil;
stbdfeed = nil;

var availableTanks = [];
var total_used_lbs = 0;
var time = 0;
var dt = 0;
var last_time = 0.0;

initialize = func {
	print("Initializing Sea Vixen Fuel System ...");

	foreach(e; AllEngines) {
		e.getNode("out-of-fuel", 1).setBoolValue(0);
	}
	
	foreach(t; AllTanks) {
		initDoubleProp(t, "level-gal_us", 0);
		initDoubleProp(t, "level-lbs", 0);
		initDoubleProp(t, "capacity-gal_us", 0.01); # Not zero (div/zero issue)
		initDoubleProp(t, "density-ppg", 6.0); # gasoline

		if(t.getNode("selected") == nil) {
		t.getNode("selected", 1).setBoolValue(1);
		}
	}

	crossfeed = Crossfeed.new();
	portfeed  = Sidedfeed.new("port");
	stbdfeed  = Sidedfeed.new("stbd");

	

	

	print("Running Sea Vixen fuel");
	
	# set it running on the next update cylce
	settimer(fuelUpdate,0);
}# end func

# ================================ end Initalize ================================== 

# ==== this is the main loop which keeps everything updated ========================

fuelUpdate = func {
#calculate dt
	time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
	dt = time - last_time;
	#print("dt " , dt);
	last_time = time;

	if(getprop( "/sim/freeze/fuel" )) { return settimer(fuelUpdate, 0.3 ); }
		
	# Build a list of available tanks. An available tank is both selected and has 
	# fuel remaining.  Note the filtering for "zero-capacity" tanks.  The FlightGear
	# code likes to define zombie tanks that have no meaning to the FDM,
	# so we have to take measures to ignore them here. 
	availableTanks = [];
	foreach(t; AllTanks) {
		cap = t.getNode("capacity-gal_us", 1).getValue();
		contents = t.getNode("level-gal_us", 1).getValue();
		if(cap != nil and cap > 0.01 ) {
			if(t.getNode("selected", 1).getBoolValue() and contents > 0) {
				append(availableTanks, t);
			}
		}
	}
	
	#  Calculate Fuel Flowrate - we have to do this before updating

	var total_flow_gph = 0;
	
	foreach(e; AllEngines) {
		if ( e.getNode("fuel-flow-gph", 1).getValue() != nil ) {
			total_flow_gph += e.getNode("fuel-flow-gph").getValue();
			total_used_lbs += e.getNode("fuel-consumed-lbs").getValue();
		#	print ("used ", e.getNode("fuel-consumed-lbs").getValue()  );
		}
		
	}

	ppg = Tank.getNode( "density-ppg", 1 ).getValue();
	FlowProp.setDoubleValue( total_flow_gph * ppg/60 );
	UsedProp.setDoubleValue( total_used_lbs/10 );
	
	################### updates go here ###################
	
	if ( CrossConnected.getValue() > 0 ) {
		crossfeed.update();
	} else {
		portfeed.update();
		stbdfeed.update();
	}
		
	#######################################################	

	# Set properties at the end of each update cycle
	
	# Total fuel properties
	total_gals = total_lbs = total_cap = 0;
	ppg = lbs = 0;
	
	foreach(t; AllTanks) {
		ppg = t.getNode("density-ppg").getValue();
		lbs = t.getNode("level-gal_us").getValue() * ppg;
		t.getNode("level-lbs").setDoubleValue(lbs);
		total_cap += t.getNode("capacity-gal_us").getValue();
		total_gals += t.getNode("level-gal_us").getValue();
		total_lbs += t.getNode("level-lbs").getValue();
	}

	setprop("/consumables/fuel/total-fuel-gals", total_gals);
	setprop("/consumables/fuel/total-fuel-lbs", total_lbs);
	setprop("/consumables/fuel/total-fuel-norm", total_gals/total_cap);
	
	settimer( fuelUpdate, 0.3 ); 

}# end main loop func

# ============================== end Fuel Update ===========================

# ============================== specify classes ===========================

# Class that specifies the fuel functions when cross-feeding
# 
Crossfeed = {
	new : func (name = "crossfeed"				
				){
		var obj = { parents : [Crossfeed] };
		obj.name = name;

		print (obj.name );
		return obj;
	},
	
	update : func () {
		# Sum the consumed fuel
	#	print ( "cross conected" );
		total = 0;
		foreach(e; AllEngines) {
			fuel = e.getNode( "fuel-consumed-lbs", 1 );
			#print ("fuel ", fuel.getValue());
			consumed = fuel.getValue();
			if(consumed == nil) { consumed = 0; }
			total += consumed;
			fuel.setDoubleValue(0);
		}
		
		# Subtract fuel from tanks, set auxilliary properties.  Set out-of-fuel
		# when all tanks are dry. 

		outOfFuel = 0;
		#print ("size ", size(availableTanks));
		if(size(availableTanks) == 0) {
			outOfFuel = 1;
		} else {
			fuelPerTank = total / size(availableTanks);
			foreach(t; availableTanks) {
				ppg = t.getNode("density-ppg").getValue();
				# lbs = t.getNode("level-gal_us").getValue() * ppg;
				lbs = t.getNode("level-lbs").getValue();
				lbs = lbs - fuelPerTank;
				print ("lbs ", lbs);
				if(lbs < 0) {
					lbs = 0; 
					# Kill the engines if we're told to, otherwise simply
					# deselect the tank.
					if(t.getNode("kill-when-empty", 1).getBoolValue()) { outOfFuel = 1; }
					else { t.getNode("selected", 1).setBoolValue(0); }
				}
				gals = lbs / ppg;
				t.getNode("level-gal_us").setDoubleValue(gals);
				t.getNode("level-lbs").setDoubleValue(lbs);
			}
		}
		
		#set all engines		
		foreach(a; AllEngines) {
			a.getNode( "out-of-fuel", 1 ).setBoolValue( outOfFuel );
		}
		
	},
};	

# Class that specifies the fuel functions when feeding from each side
# 
Sidedfeed = {
	new : func ( name ){
		var obj = { parents : [Sidedfeed] };
		obj.name = name;
		if (obj.name == "port" ) { obj.number = 0 };
		if (obj.name == "stbd" ) { obj.number = 1 };
		obj.engine = props.globals.getNode("engines").getChild("engine", obj.number);
		obj.fuel = obj.engine.getNode("fuel-consumed-lbs",1);
		obj.tank = props.globals.getNode( "consumables/fuel", 1).getChild( "tank",
													obj.number);
		print ( obj.name, obj.number );
		return obj;
	},
	update : func () {
		#print ("sided", me.name );
		fuel_consumed = me.fuel.getValue();
		if( fuel_consumed == nil) { fuel_consumed = 0; }
		me.fuel.setDoubleValue(0);
		
		# Subtract fuel from this tank, set auxilliary properties.  Set out-of-fuel
		# when this tank is dry. 
		outOfFuel = 0;
		if( me.tank.getNode("level-gal_us").getValue() == 0 and 
			me.tank.getNode("selected").getValue() ) {
			outOfFuel = 1;
		} else {
			ppg = me.tank.getNode("density-ppg").getValue();
		# 	lbs = me.tank.getNode("level-gal_us").getValue() * ppg;
			lbs = me.tank.getNode("level-lbs").getValue();
			lbs = lbs - fuel_consumed;
		#	print ( me.name, " fuel lbs ", lbs , " " , fuel_consumed);
			if(lbs < 0) {
				lbs = 0; 
				# Kill the engine if we're told to, otherwise simply
				# deselect the tank.
				if(me.tank.getNode("kill-when-empty", 1).getBoolValue()) {
					outOfFuel = 1; 
				} else { 
					me.tank.getNode("selected", 1).setBoolValue(0); 
				}
			}
			gals = lbs / ppg;
			me.tank.getNode("level-gal_us").setDoubleValue(gals);
			me.tank.getNode("level-lbs").setDoubleValue(lbs);
		} #endif

		#set this engine
		me.engine.getNode( "out-of-fuel" ).setBoolValue( outOfFuel );

	},
};	

# ============================ end specify classes ===========================


# Fire it up

settimer(initialize,0);

# end