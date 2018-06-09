struct clothes
(
	name,
	version			= 3,	
	params 			= #(0.250000,32.000000,0.950000,0.025000,0.500000,0.500000,0.050000,0.150000),
	model,
	kfm				= keyframed(),
	transparency	= 1.0,
	dSided			= 1,
	vts				= #(),
	bones			= #(),
	
	fn parse pth = 
	(
		local f = openfile pth
		
		skipToNextLine f
		version = getss f t:integer 
		model = getss f
		
		--weight,gravity,dampen,spring,bodyFriction,floorFriction,windArea,momInert		
		params 			= getarr f t:float 
		skipToNextLine f
		
		transparency	= getss f t:float  
		dSided 			= getss f t:integer 
		nLockedVts		= getss f t:integer 
		
		vts = for i = 1 to nLockedVts collect ( 1 + gets f t:integer )
		skipToNextLine f
		
		fmt = #(string, float, float, float, float, float, float, float, float, float) 
		
		nbones = gets f t:integer
		this.bones = for i = 1 to nbones collect (getarr2 f fmt sep:",")
		
	),
	
	fn load pth = 
	(
		if doesFileExist pth == false do throw ("Unable to open file: " + pth)
		name = getFilenameFile pth
		
		parse pth
		pth = (getFilenamePath pth) + model		
		
		kfm.load pth		
		
		select kfm.msh
		setCommandPanelTaskMode #modify
		modPanel.setCurrentObject kfm.msh.baseobject 
		subobjectlevel = 1
		kfm.msh.verts["locked"] = vts 
		
		subobjectlevel = 0
		
	),
	
	fn save pth =
	(
		local f = openFile pth mode:"w"
		
		if model == undefined do model = kfm.name + ".KFM"		
		
		format "version\n%\n" 3 to:f
		format "model\n%\n" model to:f 
		
		p = params
		format "weight,gravity,dampen,spring,bodyFriction,floorFriction,windArea,momInert\n" to:f
		format "%,%,%,%,%,%,%,%\n" p[1] p[2] p[3] p[4] p[5] p[6] p[7] p[8]  to:f
		
		format "transparency\n%\ndoubleSided\n%\n" transparency dSided to:f		
		
		local m = tri.cth.kfm.msh
		select m
		setCommandPanelTaskMode #modify
		modPanel.setCurrentObject m.baseobject 
		subobjectlevel = 1 
		local locked = m.verts["locked"]
		
		format "lockedVertexCount\n%\n" locked.count to:f
		
		format "lockedVertexList\n" to:f
		
		for i = 1 to locked.count do format "%\n" (locked[i].index - 1) to:f
		
		subobjectlevel = 0
		
		format "collideBoneCount\n%\n" bones.count to:f
		for b in this.bones do
		(
			format "%,%,%, %,%,%, %,%,%, %\n" b[1] b[2] b[3]   b[4] b[5] b[6]   b[7] b[8] b[9]   b[10] to:f
		)
		
		fclose f
	)
)