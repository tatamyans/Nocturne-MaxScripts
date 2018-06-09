struct keyframed
(
	name,
	version		= 8,
	textures		= #(),
	parts			= #(),
	scale 		= 0.038915,
	params 		= #(0, 0, 0, 0),
	
	msh,
	
	fn load pth = 
	(		
		if doesFileExist pth == false do throw ("Unable to open file: " + pth)	 
		local f = openFile pth 
		name = getFilenameFile pth
		
		skipPastString f "// .KFM version"
		version = gets f t:integer
		
		skipPastString f "// vertexCount,polyCount,textureCount,partCount,frameCount"
		d = getarr f t:integer
		nvts				= d[1]
		npoly				= d[2]
		ntextures		= d[3]
		nparts			= d[4]
		nframes			= d[5]
		
		--// useCollisionListFlag	
		--// transparentPixelFlag 
		--// disableBackfaceCulling	
		--// envMapListFlag
		for i = 1 to version - 5 do append params (gets f t:integer) 
		for i = 1 to 8 - version do append params 0
		if version == 7 do swap params[3] params[4]
		
		skipPastString f "// vertex list: x,y,z"
		vts = for i = 1 to nvts collect ( (getv3 f) * scale )
		
		fcs	= #()
		tfcs	= #()
		mids	= #()
		uvs	= #()
		
		skipPastString f "// poly list: textureIndex, n, verts(index,x2s,y2s)"
		order = #(1, 2, 3, 3, 4, 1)
		
		tvert = 0
		for i = 1 to npoly do
		(
			d = getarr f t:integer
			mid		= d[1] + 1
			tris		= d[2] / 2			
			
			od = 0
			for j = 1 to tris do
			(
				face	= [0, 0, 0]
				tface	= [0, 0, 0]
				
				for k = 1 to 3 do
				(
					n = order[od += 1] * 3
					
					face[k] 	= d[n] + 1
					tface[k]	=	tvert += 1
					
					u = d[n + 1] / 16776960.0
					v = d[n + 2] / 16776960.0
					
					uvs[tvert] = [u, 1.0 - v, 0] 										
				)				
				
				append fcs face
				append tfcs tface
				append mids mid
			) 
		)
		
		skipPastString f "// texture list" 
		textures = for i = 1 to ntextures collect (filterString ( gets f ) ".")[1]
		
		skipPastString f "// part list (vertexCount, polyCount)"
		parts = for i = 1 to nparts collect getarr f t:integer
		
		local m = mesh vertices:vts faces:fcs materialIDs:mids name:name
		
		setNumTVerts m uvs.count
		for i = 1 to uvs.count do ( setTVert m i uvs[i] ) 
		buildTVFaces m false
		for i = 1 to m.numfaces do ( setTVFace m i tfcs[i] ) 
		
		m.transform *= (matrix3 [1,0,0] [0,0,1] [0,-1,0] [0,0,0])			
		msh = m
		msh.name = name
		
		mat = multimaterial numsubs:textures.count
	
		for i = 1 to textures.count do
		(
			pth = textures[i] + ".PNG"
			for dir in tri.txtpath do
			(
				pth = dir + textures[i] + ".PNG"
				if doesFileExist pth do exit
			)
			
			mat[i].diffusemap = Bitmaptexture fileName:pth
			showTextureMap mat[i] on
		)
		
		m.material = mat			 
		completeRedraw()  
	),
	
	fn save pth =
	(
		local f = openFile pth mode:"w" 
		if f == undefined do throw ("Unable to open file: " + pth)
		
		format "// .KFM version\n%\n" 8 to:f
		
		--Textures
		textures = #()
		mat = msh.material
		for i = 1 to mat.numsubs do 
		(
			txt = filterString mat[i].diffuseMap.filename "\\."
			append textures txt[txt.count - 1]
		) 
		
		format "// vertexCount,polyCount,textureCount,partCount,frameCount\n%,%,%,%,%\n" \
		msh.numverts msh.numfaces textures.count 1 1 to:f
		
		format "// useCollisionListFlag\n%\n" params[1] to:f
		format "// transparentPixelFlag\n%\n" params[2] to:f
		format "// disableBackfaceCulling\n%\n" params[3] to:f
		format "// envMapListFlag\n%\n" params[4] to:f
		
		format "// vertex list: x,y,z\n" to:f
		local _msh = copy msh
		_msh.transform *= (EulerAngles -90 0 0) as matrix3 
		
		a = #()
		for i = 1 to msh.numverts do 
		(			
			v = msh.verts[i].pos / scale		 
			for j = 1 to 3 do ( a[j] = (round v[j]) as integer )  
			format "%,%,%\n" a[1] a[3] -a[2] to:f
		)
		
		format "// poly list: textureIndex, n, verts(index,x2s,y2s)" to:f
		fn writeFace m n f =
		(
			local mat = getFaceMatID m n
			local face 	= getFace m n
			local tface	= getTVFace m n
			
			format "\n%,3" (mat - 1) to:f
			for i = 1 to 3 do
			(					
				tv = getTVert m tface[i]
				u = (tv[1] * 16776960.0) as integer
				v = ((1 - tv[2]) * 16776960.0) as integer
				format ", %,%,%" ((face[i] - 1) as integer) u v to:f
			)
		)
		for fc = 1 to msh.numfaces do writeface msh fc f
		
		format "\n// texture list\n" to:f
		for t in textures do format "%.RAW\n" t to:f
		
		format "// part list (vertexCount, polyCount)\n%,%\n" msh.numverts msh.numfaces to:f 
		
		delete _msh
		fclose f
		
	) 
	
) 