# ==================================== fuel tank stuff ===================================

###
# Initialize internal values
##

	


#variables
var amount_port = amount_stbd  = 0;
var amount_2_port = amount_2_stbd = 0;
var amount_3_port = amount_3_stbd = 0;
var amount_4_port = amount_4_stbd = 0;
var flowrate_lbs_hr = 9000; 
var time = 0;
var dt = 0;
var last_time = 0.0;

##
# Initialize the fuel system
#

init_fuel_system = func {
	print("Initializing Sea Vixen Fuel System");


###
#tanks ("name", number, initial connection stauus)
###

	tank_1_port 	= Tank.new		( "tank_1_port", 0, 1 );
	tank_1_stbd 	= Tank.new		( "tank_1_stbd", 1, 1 );
	tank_1a_port 	= Tank.new		( "tank_1a_port", 2, 0);
	tank_1a_stbd 	= Tank.new		( "tank_1a_stbd", 3, 0 );
	tank_2_port 	= Tank.new		( "tank_2_port", 4, 0 );
	tank_2_stbd 	= Tank.new		( "tank_2_stbd", 5, 0 );
	tank_3_port 	= Tank.new		( "tank_3_port", 6, 0 );
	tank_3_stbd 	= Tank.new		( "tank_3_stbd", 7, 0 );
	tank_4_port 	= Tank.new		( "tank_4_port", 8, 0 );
	tank_4_stbd 	= Tank.new		( "tank_4_stbd", 9, 0 );
	pinion_port 	= Tank.new		( "pinion_port", 10, 0 );
	pinion_stbd 	= Tank.new		( "pinion_stbd", 11, 0 );

registerTimer(fuelTrans);

print ("running Sea Vixen tank sequencer");

} # end intitialization

Tank = {
	new : func ( name, number, connect) {
		var obj = { parents : [Tank]};
		obj.prop = props.globals.getNode(("consumables/fuel").getChild("tank",number);
		obj.capacity = obj.prop.getNode("capacity-gal_us", 1).getValue();
		obj.ppg = obj.prop.getNode("density-ppg", 1).getValue();
		obj.level_gal_us = obj.prop.getNode("level-gal_us", 1);
		obj.level_lbs = obj.prop.getNode("level-lbs", 1);
		obj.prop.getChild("selected")setBoolValue( connect );
		append(Tank.list, obj); 
		return obj;
	},
	update : func() {
		me.level_lbs.setDoubleValue(me.level_gal_us.getValue() * me.ppg);
	},
	get_capacity : func {
		return me.capacity; 
	},
	get_level : func {
		return me.level_gal_us.getValue();	
	},
	set_level : func (gals_us){
		me.level_gal_us.setDoubleValue(gals_us);
		me.level_lbs.setDoubleValue(gals_us * me.ppg);
	},
	get_ppg : func {
		return me.ppg
	},
	list : [],
};

# tranfer fuel

fuelTrans = func {


	# if fuel consumption is frozen, skip it
	if(getprop("/sim/freeze/fuel")) { return registerTimer(fuelTrans); }

	# update 
	foreach (var t; Tank.list) {
			t.update();	
		}		
	
	# transfer 2 to 1a
	if ( tank_1a_port.get_capacity() > (tank_1a_port.get_level() + 59.4)) {
		if ( tank_1a_port.get_capacity() > tank_1a_port.get_level()
			and tank_2_port.get_level() > 0){
				amount_2_port = ( flowrate_lbs_hr /
					(tank_1a_port.get_ppg()*60*60) )* UPDATE_PERIOD;
				#print ("amount_2_port " , amount_2_port);
				if (amount_2_port > tank_2_port.get_level() ) {
					amount_2_port = tank_2_port.get_level() ;
				}
				tank_2_port.set_level( tank_2_port.get_level() - amount_2_port );
				tank_1a_port.set_level( tank_1a_port.get_level() + amount_2_port );
		}
	}
	if ( tank_1a_stbd.get_capacity() > (tank_1a_stbd.get_level() + 59.4)) {
		if ( tank_1a_stbd.get_capacity() > tank_1a_stbd.get_level()
			and tank_2_stbd.get_level() > 0){
				amount_2_stbd = ( flowrate_lbs_hr /
					(tank_1a_stbd.get_ppg()*60*60) )* UPDATE_PERIOD;
				#print ("amount_2_stbd " , amount_2_stbd);
				if (amount_2_stbd > tank_2_stbd.get_level() ) {
					amount_2_stbd = tank_2_stbd.get_level() ;
				}
				tank_2_stbd.set_level( tank_2_stbd.get_level() - amount_2_stbd );
				tank_1a_stbd.set_level( tank_1a_stbd.get_level() + amount_2_stbd );
		}
	}
	
	# transfer pinion to 1a
	if ( tank_2_port.get_level() == 0 ) {
		
		if ( tank_1a_port.get_capacity() > tank_1a_port.get_level()
			and pinion_port.get_level() > 0){ 
				amount_pinion_port = ( flowrate_lbs_hr /
					pinion_port.get_ppg()*60*60) )* UPDATE_PERIOD;
				#print ("amount_2_port " , amount_2_port);
				if ( amount_pinion_port > pinion_port.get_level() ) {
					amount_pinion_port = pinion_port.get_level();
				}
				pinion_port.set_level( pinion_port.get_level() 
					- amount_pinion_port;
				tank_1a_port.set_level( tank_1a_port.get_level() + amount_pinion_port );
		}
	
	}
	if ( tank_2_stbd.get_level() == 0 ) {
		
		if ( tank_1a_stbd.get_capacity() > tank_1a_stbd.get_level()
			and pinion_stbd.get_level() > 0){ 
				amount_pinion_stbd = ( flowrate_lbs_hr /
					pinion_stbd.get_ppg()*60*60) )* UPDATE_PERIOD;
				#print ("amount_2_stbd " , amount_2_stbd);
				if ( amount_pinion_stbd > pinion_stbd.get_level() ) {
					amount_pinion_stbd = pinion_stbd.get_level();
				}
				pinion_stbd.set_level( pinion_stbd.get_level() 
					- amount_pinion_stbd;
				tank_1a_stbd.set_level( tank_1a_stbd.get_level() + amount_pinion_stbd );
		}
	
	}
	
	# transfer 3 to 1a
	if ( pinion_port.get_level() == 0) {
		
		if (tank_1a_port.get_capacity() > tank_1a_port.get_level()
			and tank_3_port.get_level() > 0){
				amount_3_port = ( flowrate_lbs_hr /(tank_3_port.get_ppg()*60*60) ) 
					* UPDATE_PERIOD;
				#print ("amount_3_port " , amount_3_port);
				if ( amount_3_port > tank_3_port.get_level() ) {
					amount_3_port = tank_3_port.get_level();
				}
				tank_3_port.set_level( tank_3_port.get_level() - amount_3_port);
				tank_1a_port.set_level( tank_1a_port.get_level() + amount_3_port );
		}
	}
	if ( pinion_stbd.get_level() == 0) {
		
		if (tank_1a_stbd.get_capacity() > tank_1a_stbd.get_level()
			and tank_3_stbd.get_level() > 0){
				amount_3_stbd = ( flowrate_lbs_hr /(tank_3_stbd.get_ppg()*60*60) ) 
					* UPDATE_PERIOD;
				#print ("amount_3_stbd " , amount_3_stbd);
				if ( amount_3_stbd > tank_3_stbd.get_level() ) {
					amount_3_stbd = tank_3_stbd.get_level();
				}
				tank_3_stbd.set_level( tank_3_stbd.get_level() - amount_3_stbd);
				tank_1a_stbd.set_level( tank_1a_stbd.get_level() + amount_3_stbd );
		}
	
	}
	
	# transfer 4 to 1a
	if ( tank_3_port.get_level() == 0 ) {
		
		if (tank_1a_port.get_capacity() > tank_1a_port.get_level()
			and tank_4_port.get_level() > 0){
				amount_4_port = ( flowrate_lbs_hr /(tank_4_port.get_ppg()*60*60) ) 
					* UPDATE_PERIOD;
				#print ("amount_4_port " , amount_3_port);
				if ( amount_4_port > tank_4_port.get_level() ) {
					amount_4_port = tank_4_port.get_level();
				}
				tank_4_port.set_level( tank_4_port.get_level() - amount_4_port);
				tank_1a_port.set_level( tank_1a_port.get_level() + amount_4_port );
		}
		
	}
	
	if ( tank_3_stbd.get_level() == 0 ) {
		
		if (tank_1a_stbd.get_capacity() > tank_1a_stbd.get_level()
			and tank_4_stbd.get_level() > 0){
				amount_4_stbd = ( flowrate_lbs_hr /(tank_4_stbd.get_ppg()*60*60) ) 
					* UPDATE_PERIOD;
				#print ("amount_4_stbd " , amount_3_stbd);
				if ( amount_4_stbd > tank_4_stbd.get_level() ) {
					amount_4_stbd = tank_4_stbd.get_level();
				}
				tank_4_stbd.set_level( tank_4_stbd.get_level() - amount_4_stbd);
				tank_1a_stbd.set_level( tank_1a_stbd.get_level() + amount_4_stbd );
		}
		
	}
	
	
	# transfer 1a to 1     
	if ( tank_1_port.get_capacity() > tank_1_port.getlevel() 
		and tank_1a_port.get_level() > 0){
		amount_port = tank_1_port.get_capacity() - tank_1_port.getlevel();
		if ( amount_port > tank_1a_port.get_level() ) {
			amount_port = tank_1a_port.get_level();
		}
		#print( "Amount port: " , amount_port);
		tank_1a_port.set_level( tank_1a_port.get_level() - amount_port );
		tank_1_port.set_level( tank_1_port.get_level() + amount_port );
	}
	
	if ( tank_1_stbd.get_capacity() > tank_1_stbd.getlevel() 
		and tank_1a_stbd.get_level() > 0){
		amount_stbd = tank_1_stbd.get_capacity() - tank_1_stbd.getlevel();
		if ( amount_stbd > tank_1a_stbd.get_level() ) {
			amount_stbd = tank_1a_stbd.get_level();
		}
		#print( "Amount stbd: " , amount_stbd);
		tank_1a_stbd.set_level( tank_1a_stbd.get_level() - amount_stbd );
		tank_1_stbd.set_level( tank_1_stbd.get_level() + amount_stbd );
	}
	
	
	var sum_port = sum_stbd = 0;
	
	total_port = props.globals.getNode("consumables/fuel/total-fuel-port-lbs", 1);
	total_stbd = props.globals.getNode("consumables/fuel/total-fuel-stbd-lbs", 1);
	
	for ( i=0 ;i<10 ; i=i+2 ){ #note- pinion and drop tanks are un-gauged
		  	  
			tank = props.globals.getNode("consumables/fuel",1).getChild("tank",i,1);
			contents_port =  tank.getNode("level-lbs", 1).getValue();;
			
			if (contents_port == nil){contents_port = 0;}
			sum_port = sum_port + contents_port;
			
			tank = props.globals.getNode("consumables/fuel",1).getChild("tank",i + 1,1);
			contents_stbd =  tank.getNode("level-lbs", 1).getValue();;
			
			if (contents_stbd==nil){contents_stbd = 0;}
			sum_stbd = sum_stbd + contents_stbd;
	}
				
	total_port.setValue(sum_port);
	total_stbd.setValue(sum_stbd);
	
	registerTimer(fuelTrans);
	
	} # end funtion fuelTrans    
		
	
	# fire it up
	
	registerTimer(init_fuel_system);
	
	
	
	
	
	
	
	
	