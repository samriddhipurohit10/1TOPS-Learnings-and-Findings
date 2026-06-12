# Placement 
checkDesign -floorplan
checkFPlan -reportUtil

# Pre placement settings
setPlaceMode -place_detail_check_route true
setPlaceMode -place_global_max_density 0.55 
setPlaceMode -place_global_uniform_density true

# Active all modes and set max_fanout limit 
set_interactive_constraint_modes [all_constraint_modes -active]
set_max_fanout 12 [dbGet top.name]

# Set max routing layers 
setDesignMode -topRoutingLayer 7
setDesignMode -bottomRoutingLayer 1

# Set Analysis views for setup and hold
set_analysis_view -setup func_ss -hold func_ff

# Coarse Placement + Placement optimization + legalize
# To run coarse placement 
# setPlaceMode -place_design_refine_place false 
# place_design -noPrePlaceOpt 
place_design 

# Check legalization 
checkPlace
 
# Legalize Placement 
refinePlace

# Placement + inplacement_opt + post Placement optimization 
place_opt_design
saveDesign ./design/placement_new.enc

# placeDesign : Coarse Placement + Placement optimization + legalize + incr_optimization 
# place_opt_design :  Coarse Placement + Placement optimization + legalize + incr_optimization + HFNS + Fixing DRVs and setup violation

# Report Congestion 
reportCongestion -3d -overflow 

# Fix Congestion 
restoreDesign ./design/power_planning_done.enc.dat chip_top 
deletePlaceBlockage -all
finishFloorplan -fillPlaceBlockage partial 30
dbset [dbget -p1 top.fplan.pBlkgs.type partial].density 5 
# Source all placement settings `
place_design
place_opt_design -incremental 
saveDesign ./design/placement2_done.enc

################ BOUNDS IN CADENCE ###########################
# 1) Guide : Assigned may be placed in bound region or even it can be placed outside bound region	
		#  Other cells can be placed inside bound region 

# 2) Region : Assigned cells should be placed in bound region and even other cells are 
		# allowed to place in bound region 
# 3) Fence : Assigned cells should be placed in bound region and no other cells are allowed to place in 
		# bound region 
		createFence ch1/sub_chip2_Multiplier {1191.0 1627.92 1476.4 1733.94}

 ######### Place TIE Cells ##############################################
 setTieHiLoMode -maxfanout 10 -cell "TIEHI TIELO"
 addTieHiLo -prefix TIE

############################## DRV Checks ####################################
# Max trans 
report_constraint -all_violators -drv_violation_type max_transition
# Max Cap 
report_constraint -all_violators -drv_violation_type max_capacitance
# Max Fanout 
report_constraint -all_violators -drv_violation_type max_fanout
######################################### Timing Check ########################
timeDesign -preCTS -outDir ./reports/placement -prefix prects
report_timing -max_paths 22 -format {arc cell delay arrival load}

# Create different path groups 
proc path_group {} {
	reset_path_group -all
	set inp [all_inputs -no_clocks]
	set outp [all_outputs] 
	set mem [filter_collection [all_registers] {is_memory_cell == true}]
	set reg [filter_collection [all_registers] {is_memory_cell == false}] 

	group_path -from $inp -to $reg -name i2r
	group_path -from $inp -to $mem -name i2m
	group_path -from $reg -to $reg -name r2r
	group_path -from $reg -to $mem -name r2m
	group_path -from $mem -to $reg -name m2r	
	group_path -from $reg -to $outp -name r2o
	group_path -from $mem -to $outp -name m2o
	group_path -from $inp -to $outp -name i2o
	group_path -from $mem -to $mem -name m2m
} 


# Assign weights usign separe command 
setPathGroupOptions -weight 2 r2r
# Upsizing or downsizing or Vt swapping 
ecoChangeCell -inst Top_I18 -cell BUFX20
ecoChangeCell -inst  ch3/sub_chip3_Multiplier/FE_OFC15680_n_408 -cell BUFX8