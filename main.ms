(	
	struct tritools
	(
		txtpath	= #(
			@"C:\Dev\Nocturne\ART\PNG\",
			@"C:\Dev\BlairWitch1\ART\PNG\"
		),
		
		skl, dfm, kfm, cth, geo, rout	
	)
	
	global TRI
	TRI = undefined
	if TRI == undefined do  TRI = tritools() 
	
	include "util.ms"
	include "skl.ms"
	include "dfm.ms"
	include "kfm.ms"
	include "cth.ms"
	include "geo.ms"
	
	tri.dfm	= deformable()
	
	
	fn add_col dgv header width readonly:false =
	(
		local c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn" 
		c.width = width
		c.headerText = header
		c.readonly = readonly
		dgv.columns.add c
	) 
	
	fn dgv_fill dgv arr =
	(
		dgv.rows.clear()
		
		if arr == undefined or arr.count < 1 do return 1
		
		if dgv.columns.count == 1 do arr = for e in arr collect #(e)		
		
		for e in arr do ( if e != indefined do dgv.rows.add e )		
	)
	
	fn upd_id dgv = 
	( 
		for i = 0 to dgv.rows.count - 2 do dgv.rows.Item[i].cells.Item[0].value = i		
	)
	
	fn dgvInitColumns dgv headers width = 
	(
		for h in headers do
		(
			local c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
			c.headerText = h
			c.width = width
			dgv.columns.add c
		)
	)
	
	rollout MotionsEditRollout "Edit Motions List" width:818 height:480
	(
		local _block = true
		local _mns = undefined --tri.skl.motions
		local _mid = -1
		
		rollout StatesSubRollout "States" 
		(
			dotNetControl dgv_states "System.Windows.Forms.DataGridView" pos:[4, 4]	width:198 height:412
			
			on StatesSubRollout open do
			(
				dgv_states.RowHeadersVisible = false
				dgv_states.AllowUserToResizeRows = false
				dgv_states.SelectionMode = dgv_states.SelectionMode.FullRowSelect
				dgv_states.ScrollBars = dgv_states.ScrollBars.None
				
				c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn" 
				c.width = 30
				c.headerText = "#"	
				c.readonly = true
				dgv_states.columns.add c
				
				c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn" 
				c.width = 165
				c.headerText = "State"
				dgv_states.columns.add c
				
				for i = 1 to tri.skl.states.count do 
				( 
					dgv_states.rows.add #( i - 1, tri.skl.states[i] ) 
				)
			)
			
			on StatesSubRollout rolledup ev do
			(
				MotionsEditRollout.MotionsSubRollout.open = not ev
			)
			
			on dgv_states MouseWheel ev do 
			(					 
				if ev.delta < 0 or dgv_states.FirstDisplayedScrollingRowIndex > 0 do
				(
					dgv_states.FirstDisplayedScrollingRowIndex -= (ev.delta / 120)
				)
			) 
			
			on dgv_states RowsAdded ev do  
			(
				if _block do return 0
				
				upd_id dgv_states
			)
			
			on dgv_states RowsRemoved ev do 
			(
				if _block do return 0
				
				deleteItem tri.skl.states (ev.rowindex + 1)
				
				upd_id dgv_states
			)
			
			on dgv_states CellValueChanged  ev do
			(
				if ev.rowindex >= dgv_states.rows.count - 1 do return 0
				
				tri.skl.states[ev.rowindex + 1] = dgv_states.rows.Item[ev.rowindex].cells.Item[1].value as string
				
				upd_id dgv_states
				
			)
			
		)
		
		rollout MotionsSubRollout "Motions" 
		(
			dotNetControl dgv_motions "System.Windows.Forms.DataGridView" pos:[4, 4] width:198 height:412
			
			on MotionsSubRollout open do
			(				
				dgv_tb = dotNetClass "System.Windows.Forms.DataGridViewTextBoxColumn"
				
				dgv_motions.RowHeadersVisible = false
				dgv_motions.AllowUserToResizeRows = false
				dgv_motions.SelectionMode = dgv_motions.SelectionMode.FullRowSelect
				dgv_motions.ScrollBars = dgv_motions.ScrollBars.None
				
				local c = dotNetObject dgv_tb 
				c.width = 30
				c.headerText = "id"		
				c.readonly = true
				dgv_motions.columns.add c
				
				c = dotNetObject dgv_tb 
				c.width = 165
				c.headerText = "Name"
				dgv_motions.columns.add c
				
				_block = true 
				format "# block set %\n" _block
				
				for i = 1 to _mns.count do dgv_motions.rows.add #( i - 1, _mns[i].params[1] ) 	
				
				_block = false
				format "# block set %\n" _block
				
			)

			on dgv_motions RowsAdded ev do 
			(
				if _block do return 0  
				m = skl_motion()				
				insertItem m _mns ev.rowindex   
				upd_id dgv_motions
			)
			
			on dgv_motions RowsRemoved ev do 
			(
				if _block do return 0 
				deleteItem _mns _mid 
				upd_id dgv_motions
			)
			
			on dgv_motions SelectionChanged ev do 
			(
				if _block do return 0 
				_mid = dgv_motions.SelectedRows.Item[0].Index + 1 
				if _mid < 0 or _mid > _mns.count do return 0
				m = _mns[_mid] 
				
				_block = true
				dgv = MotionsEditRollout.dgv_mparams
				for i = 0 to dgv.rows.count - 1 do
				(
					c = dgv.item 1 i
					c.value = ""
					if m.params[i + 2] != undefined do c.value = m.params[i + 2]
				)				
				
				dgv_fill MotionsEditRollout.dgv_transitions m.transitions
				dgv_fill MotionsEditRollout.dgv_signals 		m.signals
				dgv_fill MotionsEditRollout.dgv_markers 	m.markers
				_block = false
				
			)
			
			on dgv_motions CellValueChanged ev do
			(
				if _block do return 0  
				id = ev.rowindex + 1  
				if _mns[id] == undefined do _mns[id] = skl_motion() 
				_mns[id].params[1] = (dgv_motions.Item 1 (id - 1)).value
				
				upd_id dgv_motions
			)
			
			on MotionsSubRollout rolledup ev do
			(
				MotionsEditRollout.StatesSubRollout.open = not ev 
			)
			
			on dgv_motions MouseWheel ev do 
			(					 
				if ev.delta < 0 or dgv_motions.FirstDisplayedScrollingRowIndex > 0 do
				(
					dgv_motions.FirstDisplayedScrollingRowIndex -= (ev.delta / 120)
				)
			)
			
		)
		
		subRollout subroll_states			pos:[4, 4] width:220 height:472
		
		dotNetControl dgv_transitions 	"System.Windows.Forms.DataGridView" pos:[228, 4] 		width:363 	height:472	
		dotNetControl dgv_mparams 	"System.Windows.Forms.DataGridView" pos:[595, 4] 		width:220 	height:333		
		dotNetControl dgv_signals 		"System.Windows.Forms.DataGridView" pos:[595, 341] 	width:138 	height:135
		dotNetControl dgv_markers 		"System.Windows.Forms.DataGridView" pos:[736, 341] 	width:78 	height:135
		
		on MotionsEditRollout open do
		(
			_mns = tri.skl.motions
			
			dgv_mparams.RowHeadersVisible = false
			dgv_mparams.AllowUserToAddRows  = false
			dgv_mparams.AllowUserToResizeRows  = false
			dgv_mparams.MultiSelect = false
			
			local c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn" 
			c.width = 157
			c.headerText = "Param"
			c.readonly = true
			c.DefaultCellStyle.BackColor = c.DefaultCellStyle.BackColor.LightGray
			dgv_mparams.columns.add c
			
			local c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
			c.width = 60
			c.headerText = "Value"
			c.resizable = c.resizable.false
			dgv_mparams.columns.add c

			dgv_mparams.rows.add #( "Fps", "30" ) 
			dgv_mparams.rows.add #( "State", " " )
			dgv_mparams.rows.add #( "Frame start", "0" )
			dgv_mparams.rows.add #( "Frame count", "0" )			
			
			dgv_mparams.rows.add #( "Fwd from frame", "0" )
			dgv_mparams.rows.add #( "Fwd to motion", "0" )
			dgv_mparams.rows.add #( "Fwd to frame", "0" )
			
			dgv_mparams.rows.add #( "Fwd cmd", "0" )
			dgv_mparams.rows.add #( "Fwd tween time", "0" )
			dgv_mparams.rows.add #( "Fwd set new state", "0" )	
			
			dgv_mparams.rows.add #( "Bck to motion", "0" )
			dgv_mparams.rows.add #( "Bck to frame", "0" )
			
			dgv_mparams.rows.add #( "Frame resolution", "0" )
			dgv_mparams.rows.add #( "Stored frame count", "0" )
			
			--------------------------------------------------------------------------
			
			dgv_transitions.RowHeadersVisible = false
			dgv_transitions.AllowUserToResizeRows  = false
			dgv_transitions.MultiSelect = false
			dgv_transitions.SelectionMode = dgv_transitions.SelectionMode.FullRowSelect
			
			headers = #( "State", "Cmd", "Motion", "Frame", "Time", "SetState")
			
			dgvInitColumns dgv_transitions headers 60
			
			--------------------------------------------------------------------------
			
			dgv_signals.RowHeadersVisible = false
			dgv_signals.AllowUserToResizeRows  = false
			dgv_signals.ScrollBars = dgv_signals.ScrollBars.None
			
			local c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
			c.width = 66
			c.headerText = "Frame"			
			dgv_signals.columns.add c
			
			local c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
			c.width = 69
			c.headerText = "Signal"
			dgv_signals.columns.add c
			
			--------------------------------------------------------------------------
			
			dgv_markers.RowHeadersVisible = false
			dgv_markers.AllowUserToResizeRows  = false
			dgv_markers.ScrollBars = dgv_markers.ScrollBars.None
			
			local c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
			c.width = 75
			c.headerText = "Marker"			
			dgv_markers.columns.add c
			
			--------------------------------------------------------------------------
			
			ignoreOnRowsAdded = true
			
			AddSubRollout subroll_states StatesSubRollout
			AddSubRollout subroll_states MotionsSubRollout
			MotionsSubRollout.open = false 
			
			ignoreOnRowsAdded = false
			ignoreOnRowsRemoved = false
		)
		 
		--****************************************************************--
		--***************    TRANSITIONS
		--****************************************************************--
		
		on dgv_transitions RowsAdded ev do
		(
			if _block or _mid < 0 do return 0
			m = _mns[_mid]
			
			if m != undefined do _mns[_mid].transitions[ev.rowIndex] = #()			
		)
		
		on dgv_transitions RowsRemoved ev do 
		(
			if _block or _mid < 0 do return 0
			
			id = ev.rowIndex + 1
			tr = m = _mns[_mid].transitions
			
			if id < 1 or id > tr.count do return 0
			
			format "dgv_transitions RowsRemoved %\n" id
			deleteItem  tr id   
		)
		
		on dgv_transitions CellValueChanged ev do
		( 
			if _block or _mid < 0 do return 0
				
			ridx = ev.rowIndex + 1
			cidx = ev.columnIndex + 1 
				
				
			tft = #(integer, integer, integer, integer, float, integer)			
			cells = dgv_transitions.rows.item[ridx - 1].Cells.item
			
			m = _mns[_mid]
			
			if m != undefined do
			(
				if m.transitions[ridx] == undefined do m.transitions[ridx] = #()
				
				m.transitions[ridx][cidx] = cells[cidx - 1].value as (tft[cidx])
			)
		)
		
		on dgv_mparams CellValueChanged ev do
		(
			if _block or _mid < 0 do return 0
			
			m = _mns[_mid]
			
			fmt = #(string, integer, integer, integer, integer, integer, 
				integer, integer, integer, float, integer, integer, integer, integer, integer)
				
			r = ev.rowindex
				
			val = (dgv_mparams.item 1 r).value
			if val != undefined do m.params[r + 2] = val as (fmt[r + 2]) 
			
		)
		
		
		--****************************************************************--
		--***************    SIGNALS
		--****************************************************************--
		
		on dgv_signals RowsAdded ev do
		(
			if _block or _mid < 0 do return 0 
			m = _mns[_mid] 
			if m != undefined do m.signals[ev.rowIndex] = #() 
		)
		
		on dgv_signals RowsRemoved ev do 
		(
			if _block do return 0
			
			id = ev.rowIndex + 1
			m = _mns[_mid]
			
			if id < 1 or id > m.signals.count do return 0
			
			deleteItem m.signals id 
			
		)
		
		on dgv_signals CellValueChanged ev do
		(
			if _mid < 0 or _mns[_mid] == undefined do return 0
			
			r = ev.rowIndex
			c = ev.columnIndex			
			sgs = _mns[_mid].signals
			
			if sgs[r + 1] == undefined do sgs[r + 1] = #()			
			
			sgs[r + 1][c + 1] = (dgv_signals.item c r).value as integer
			
		)
		
		on dgv_signals MouseWheel ev do 
		(					 
			if ev.delta < 0 or dgv_signals.FirstDisplayedScrollingRowIndex > 0 do
			(
				dgv_signals.FirstDisplayedScrollingRowIndex -= (ev.delta / 120)
			) 
		)
		
		--****************************************************************--
		--***************    MARKERS
		--****************************************************************--
		
		on dgv_markers RowsRemoved ev do 
		(
			if _block do return 0
			
			id = ev.rowIndex + 1
			m = _mns[_mid] 
			
			if m == undefined or id > m.markers.count do return 0
			
			deleteItem m.markers id
		)
		
		on dgv_markers CellValueChanged ev do
		(
			if _mid < 0 do return 0
			m = _mns[_mid] 
			id = ev.rowIndex
			
			if m == undefined do return 0
			
			m.markers[id + 1] = (dgv_markers.item 0 id).value as integer
			
		)
		
		on dgv_markers MouseWheel ev do 
		(					 
			if ev.delta < 0 or dgv_markers.FirstDisplayedScrollingRowIndex > 0 do
			(
				dgv_markers.FirstDisplayedScrollingRowIndex -= (ev.delta / 120)
			)
			
		) 
 
	)
 
	rollout SklRollout "SKL" width:240 height:280
	(
		fn box_filt obj = classof obj == Point
		
		
		pickbutton 		pck_bones 		"Pick" 	pos:[121,5] 	width:45 	height:20 filter:box_filt
		edittext 			tb_pckname 	"" 			pos:[0,4] 		width:115 	height:20 toolTip:"Dummy Root" 
		button 				btn_load 		"Load" 	pos:[170,5] 	width:45	height:20 
		button 				btn_save 		"Save" 	pos:[170,29] 	width:45 	height:20	 
		button 				btn_edit 		"Edit" 	pos:[121,29] 	width:45 	height:20 
		dropdownList 	ddl_ver 			""			pos:[5,29] 		width:55 	height:21 items:#("3", "4") toolTip:"SKL Version" 
		dropdownList 	ddl_mver 		"" 			pos:[62,29] 	width:55 	height:21 items:#("2", "3") toolTip:"Motion list version" 
		
		fn redraw =
		(
			skl = tri.skl
			try skl.bones[1].name catch 
			(
				skl.bones		= #()
				skl.name			= ""
			)
			
			tb_pckname.text		= skl.name
			ddl_ver.selection		= skl.version - 2
			ddl_mver.selection	= skl.mversion - 1			
		)
		
		on btn_edit pressed do
		(
			createdialog MotionsEditRollout
		)
		
		on tb_pckname entered ev do
		(
			tri.skl.name = tb_pckname.text
		)
		
		on pck_bones picked obj do
		(
			if obj == undefined or obj.children.count == 0 do return 0
			
			if tri.skl != undefined then 
			(
				motions = deepcopy tri.skl.motions
				tri.skl = noc_skl()
				tri.skl.motions = motions
			) 
			else tri.skl = noc_skl()
			skl = tri.skl
			skl.name	= obj.name
			
			traverse obj.children skl.bones
			
			tb_pckname.text	= obj.name
			
		)
		
		on btn_load pressed do
		(
			pth = getOpenFileName caption:"Open SKL File:" types:"Skeleton(*.SKL)|*.skl|*.txt|"
			if pth == undefined do return 0
			
			tri.skl = noc_skl()
			skl = tri.skl
			
			skl.load pth anim:true 
			tb_pckname.text	= skl.name
			
			print "Done."
		)
		
		on btn_save pressed do
		(
			pth = getSaveFileName caption:"Open SKL File:" types:"Skeleton(*.SKL)|*.skl|*.txt|"
			if pth == undefined do return 0
			
			if tri.skl.motions.count == 0 do messagebox "Motions list empty"			
			
			tri.skl.save pth
			
			format "Done %.SKL\n" tri.skl.name
		)
		
		on ddl_ver selected ev do
		(
			tri.skl.version = ev + 2 
		)
		
		on ddl_mver selected ev do
		(
			tri.skl.mversion = ev + 1
		)
		
		on SklRollout open do
		( 
			if tri.skl == undefined do tri.skl = noc_skl()
			redraw()
		)
	)
	
	rollout DfmRollout "DFM" width:240 height:280 
	(
		fn msh_filt obj = classof obj == Editable_Mesh 
		
		local lod_load = 1
		
		dotNetControl	dgv_lods		"System.Windows.Forms.DataGridView" pos:[4,28] width:160 height:118	
		
		button 				btn_load 		"Load" 		pos:[169,6] 		width:45 	height:20
		pickbutton 		btn_add 		"Add" 		pos:[169,30] 		width:45 	height:20 		filter:msh_filt
		button 				btn_rem 		"Rem" 		pos:[169,54] 		width:45	height:20
		button 				btn_up 			"Up" 			pos:[169,78] 		width:45 	height:20
		button 				btn_dn 			"Dn"			pos:[169,102] 	width:45 	height:20
		button 				btn_save 		"Save" 		pos:[169,126] 	width:45 	height:20 
		
		checkbox 			chb_anim 		"" 				pos:[143,5] 		width:18 	height:18 		checked:false toolTip:"Animation loading is SLOW"
		edittext 			tb_lod 			"" 				pos:[32,4] 			width:40	height:18 		toolTip:"LOD"
		
		label 				lbl_motions 	"Motions" 	pos:[95,6] 			width:45 	height:18
		label 				lbl_lod 			"LOD" 		pos:[8,6] 			width:24 	height:18
		
		fn add_col header width =
		(
			local c = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn" 
			c.width = width
			c.headerText = header
			c.readonly = true
			dgv_lods.columns.add c
		) 
		
		fn add_row m =
		(
			select m
			setCommandPanelTaskMode #modify
			modPanel.setCurrentObject m.baseobject
			
			capped = for face in m.faces where (sgbit m face.index 2) collect face
			numfaces = m.numfaces - capped.count
			--numparts = m.faces.selSetNames.count
			
			dgv_lods.rows.add #( m.name, m.numverts, numfaces, capped.count ) 
		)
		
		fn redraw_lods =
		( 
			dgv_lods.columns.clear()
			dgv_lods.rows.clear()
			
			add_col "Name" 67
			--add_col "Parts" 38		--must redraw modpanel
			add_col "Verts" 45
			add_col "Faces" 45
			--add_col "Capped" 49
			
			dfm = tri.dfm			
			
			try dfm.ld_mshs[1].name catch dfm.ld_mshs = #()
			
			for m in dfm.ld_mshs do add_row m
			
		)
		
		on btn_rem pressed do 
		(			
			if dgv_lods.rows.count > 0 do
			(
				deleteitem tri.dfm.ld_mshs (dgv_lods.selectedRows.Item[0].index + 1)
			)
			
			redraw_lods()
		)
		
		on btn_add picked obj do
		(
			if obj == undefined do return 0
			
			if classof obj != Editable_Mesh do return messagebox "Not an Editable_Mesh"		
			sk = obj.modifiers[#skin]		
			if sk == undefined do return messagebox "Skin modifier not found"		
			if skinOps.GetNumberBones sk == 0 do return messagebox "No bones"
			
			append tri.dfm.ld_mshs obj			
			
			redraw_lods()
		)
		
		on btn_load pressed do
		(
			pth = getOpenFileName caption:"Open DFM File:" types:"Deformable(*.DFM)|*.dfm|*.txt|"
			if pth == undefined do return 0
			
			tri.dfm = deformable() 		
			
			tri.dfm.load pth lod:lod_load anim:chb_anim.checked
			
			/*try tri.dfm.load pth lod:lod_load anim:chb_anim.checked catch 
			(	
				errstr = (getCurrentException())
				messagebox errstr
				format "Exception: %\n" errstr
				return 1		
			)*/
			
			redraw_lods()
			tri.rout.subroll.SKlRollout.redraw()
			
			local m = tri.dfm.ld_mshs[1]
			select m
			modPanel.setCurrentObject m.modifiers[#skin]			
		)
		
		on btn_save pressed do
		(
			pth = getSaveFileName caption:"Open DFM File:" types:"Deformable(*.DFM)|*.dfm|*.txt|"
			if pth == undefined do return 0
			
			if tri.skl == undefined do 
			(				
				messagebox "SKL not set"
				return 0
			)
			
			tri.dfm.save pth
			
			print "Done."			
		)
		
		on btn_up pressed do
		(
			id = dgv_lods.selectedRows.Item[0].index + 1
			mshs = tri.dfm.ld_mshs
			if id > 1 do 
			(
				swap mshs[id] mshs[id - 1]
				redraw_lods()
			)
		)
		
		on btn_dn pressed do
		(
			id = dgv_lods.selectedRows.Item[0].index + 1
			mshs = tri.dfm.ld_mshs
			if id < mshs.count do 
			(
				swap mshs[id] mshs[id + 1]			
				redraw_lods()
			)
			
		)
 
		on DfmRollout open do
		(
			dgv_lods.RowHeadersVisible = false
			dgv_lods.AllowUserToAddRows  = false
			dgv_lods.AllowUserToResizeRows  = false
			dgv_lods.MultiSelect = false
			dgv_lods.SelectionMode = dgv_lods.SelectionMode.FullRowSelect
			
			tb_lod.text = lod_load as string
			
			redraw_lods()
		)
		
		on tb_lod entered ev do
		(
			try lod_load = (ev as integer) catch (lod_load = 0; tb_lod.text = "0")
		)
		
		on ddl_ver selected ev do
		(
			tri.dfm.version = ev + 5 
		)
	)
	
	rollout CthRollout "CTH " width:240 height:280
	(
		fn msh_filt obj = classof obj == Editable_Mesh 
		
		edittext	tb_pck		""			pos:[2,5] 		width:66	height:18	
		pickbutton btn_pck 	"Pick" 	pos:[74,4] 		width:45 	height:20	filter:msh_filt
		button 		btn_load 	"Load" 	pos:[122,4] 	width:45 	height:20 
		button 		btn_save 	"Save" 	pos:[170,4] 	width:45 	height:20 
		
		on btn_pck picked obj do
		(
			if obj == undefined do return 0
			
			cth = clothes()	
			cth.name 		= obj.name			
			cth.kfm.name	= obj.name
			cth.kfm.msh	= obj			
			tb_pck.text		= obj.name
			tri.cth = cth
			
		)
		
		on btn_load pressed do
		(
			pth = getOpenFileName caption:"Open CTH File:" types:"Cloth (*.CTH)|*.cth|"
			if pth == undefined do return 0
			
			tri.cth = clothes()
			tri.cth.load pth			
			tb_pck.text = tri.cth.name
			
		)
		
		on btn_save pressed do
		(
			pth = getSaveFileName caption:"Open CTH File:" types:"Cloth (*.CTH)|*.cth|"
			if pth == undefined do return 0
			
			try tri.cth.kfm.msh.name catch
			(
				tri.cth = undefined
				tb_pck.text = ""
				return 0			
			)
			
			tri.cth.save pth
			
		)
		
		on CthRollout open do
		(
			try tri.cth.kfm.msh.name catch 
			( 
				tri.cth = undefined
				return 0
			)
			
			tb_pck.text = tri.cth.name as string
		)
		
	)
	
	rollout KfmRollout "KFM" width:240 height:280
	(
		fn msh_filt obj = classof obj == Editable_Mesh 
		
		edittext	tb_pck		""			pos:[2,5] 		width:66	height:18				
		pickbutton btn_pck 	"Pick" 	pos:[74,4] 		width:45 	height:20 filter:msh_filt
		button 		btn_load 	"Load" 	pos:[122,4] 	width:45 	height:20 
		button 		btn_save 	"Save" 	pos:[170,4] 	width:45 	height:20
		
		on btn_pck picked obj do
		(
			if obj == undefined do return 0
			
			kfm = keyframed()
			kfm.msh = obj
			kfm.name = obj.name
			tb_pck.text = obj.name
			tri.kfm = kfm
			
		)
		
		on btn_load pressed do
		(
			pth = getOpenFileName caption:"Open KFM File:" types:"Keyframed (*.KFM)|*.kfm|"
			if pth == undefined do return 0
			
			tri.kfm = keyframed()
			tri.kfm.load pth			
			tb_pck.text = tri.kfm.name
			
		)
		
		on btn_save pressed do
		(
			pth = getSaveFileName caption:"Open KFM File:" types:"Keyframed (*.KFM)|*.kfm|"
			if pth == undefined do return 0
			
			try tri.kfm.msh.name catch return 0			
			
			tri.kfm.save pth
			
		)
		
		on KfmRollout open do
		(
			try tri.kfm.msh.name catch 
			( 
				tri.kfm = undefined
				return 0
			)
			
			tb_pck.text = tri.kfm.name
		)
		
	)
	
	rollout GeoRollout "GEO" width:240 height:280
	( 
		button 		btn_load 	"Load" 	pos:[2,4] 	width:45 	height:20  
		
		on btn_load pressed do
		(
			pth = getOpenFileName caption:"Open SET File:" types:"Set (*.SET)|*.set|"
			if pth == undefined do return 0
			
			tri.geo = gameset()
			tri.geo.load pth 
			
			"OK"
		) 
		
		on GeoRollout open do
		( 
			
		)
	)
	
	rollout OptRollout "Parameters" width:240 height:280 
	(		
		dotNetControl	dgv_textures	"System.Windows.Forms.DataGridView" pos:[4,4] width:210 height:90
		local _block = true
		
		on OptRollout open do
		(
			dgv_textures.RowHeadersVisible 	= false  			
			dgv_textures.SelectionMode 			= dgv_textures.SelectionMode.FullRowSelect
			dgv_textures.ScrollBars 				= dgv_textures.ScrollBars.None
			
			add_col dgv_textures "Textures" 210		 
			for str in tri.txtpath do dgv_textures.rows.add #( str )  
			_block = false
		)
		
		on dgv_textures MouseWheel ev do 
		(					 
			if ev.delta < 0 or dgv_textures.FirstDisplayedScrollingRowIndex > 0 do
			(
				dgv_textures.FirstDisplayedScrollingRowIndex -= (ev.delta / 120)
			)
		)
		
		on dgv_textures RowsAdded ev do  
		(
			if _block do return 0  
			
		)
		
		on dgv_textures RowsRemoved ev do 
		(
			if _block do return 0 
			deleteItem tri.txtpath (ev.rowindex + 1)
			
		)
		
		on dgv_textures CellValueChanged ev do
		(
			idx = ev.rowindex
			
			if idx >= dgv_textures.rows.count - 1 do return 0
			
			tri.txtpath[idx + 1] = (dgv_textures.item 0 idx).value as string
			
		)
	)
	
	rollout ToolsRollout "TRI Tools" width:240 height:344
	(
		subRollout subroll pos:[4, 4] width:232 height:336
		
		on ToolsRollout open do
		( 	  
			AddSubRollout ToolsRollout.subroll DfmRollout 
			AddSubRollout ToolsRollout.subroll SklRollout		rolledUp:true
			AddSubRollout ToolsRollout.subroll CthRollout 	rolledUp:true
			AddSubRollout ToolsRollout.subroll KfmRollout	rolledUp:true  
			AddSubRollout ToolsRollout.subroll GeoRollout	rolledUp:true
			AddSubRollout ToolsRollout.subroll OptRollout	rolledUp:true
		)
	)
	
	createDialog ToolsRollout 
	tri.rout = ToolsRollout
	
)