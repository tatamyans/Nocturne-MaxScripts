struct dfm_part
(
	name, 
	dmbone, 
	--adjPartCount, 
	--adjparts, 
	lods = #()  
)

struct deformable
(
	name,  
	version			= 7, 
	
	skl, 
	ld_mshs			= #(),
	
	lods,
	textures 		= #(),		
	bones			= #(),	
	parts				= #(),

	weights 			= #(),	
	vertices 		= #(),
	faces 			= #(),
	capfaces 		= #(),
	
	matIds,
	brefs			 	= #(), 
	partForbones 	= #(), 
	ro_scale,
	bias,
	
	--todo
	flip_uvs			= true,
	
	fn parse pth =
	(
		local f = undefined		
		try f = openFile pth catch print pth
		
		version = gets f t:integer
		
		a = getarr f t:integer
		nlods					= a[1]
		ntextureSets		= a[2]
		ntextures			= a[3]
		nbones				= a[4]
		nparts				= a[5]
		
		nverts	= 0
		ntris		= 0
		ncaptris	= 0
		
		lods = for i = 1 to nlods collect ( getarr f t:integer )	
		for ld in lods do
		( 
			nverts	+= ld[1]
			ntris		+= ld[2]
			ncaptris += ld[3]			
		)
		
		if skl == undefined do skl = noc_skl()
		skl.name = gets f 
		
		--Parts
		for i = 1 to nparts do 
		(
			p = dfm_part()
			
			a = filterString ( gets f ) ", \t"
			p.name = substring a[1] 2 (a[1].count - 2)
			p.dmbone = a[2] as integer
				
			for j = 1 to nlods do
			(
				a = getarr f sep:", \t" t:integer
				p.lods[j] = #(a[1], a[2])
			)
			parts[i] = p
		)
		skip f
		
		--vertexList					
		for i = 1 to nverts do
		(
			bns = gets f as integer
			v = undefined
			
			weights[i] = #()
			for j = 1 to bns do
			(
				a = getarr2 f #(integer, float, float, float, float)
				b = a[1] + 1
				append weights[i] #( b, a[2] )
				v = #( b, [a[3], a[4], a[5]] )
			)
			vertices[i] = v			
		)
		
		--triList
		skipPastString f "// triList: textureIndex, verts(index, u, v)"				
		ntris += ncapTris
		for i = 1 to ntris do ( faces[i] = getarr f t:integer )
		
		--capTriList
		skipPastString f "// capTriList: matching part"
		for i = 1 to ncapTris do ( capfaces[i] = gets f as integer )

		skipPastString f "// texture list"
		for i = 1 to ntextures do 	( textures[i] = (filterString ( gets f ) ".")[1] )
		
		skipPastString f "// bone origin list"
		for i = 1 to nbones do 
		( 
			v = getarr f t:float 
			brefs[i] = Point3 v[1] v[2] v[3]
		)
		
		v = getarr f t:float
		ro_scale = [ v[1], -v[3], v[2]]
		skl.ro_scale = ro_scale
		
		bias = getv3 f 
		skl.bias = bias
		
		for i = 1 to nbones do ( partForbones[i] = gets f t:integer )
		
	),
	
	fn clean =
	(
		vertices 		= #()
		faces 			= #() 
		capfaces 		= #()	
		weights 			= #()
	),
  
	fn set_lod_mesh lod = 
	(
		vts	= #()
		fcs	= #()
		tfcs	= #()
		uvs	= #()
		mids	= #()		
		
		ld = lods[lod]
		
		if skl.bones.count == 0 do skl.set_bones brefs:brefs
		
		--LOD offsets
		offs = #(0, 0, 0)
		for i = 1 to lod - 1 do ( for j = 1 to 3 do offs[j] += lods[i][j] )
		
		offs_vts_lod	= offs[1]								--to LOD in vertices
		offs_fcs_lod	= offs[2] + offs[3]					--to LOD in faces
		offs_fcs_cp		= offs_fcs_lod + ld[2]				--to capped faces for LOD
		
		--vertices
		for i = 1 to ld[1] do 
		(
			id = offs_vts_lod + i
			b = vertices[id][1]
			v = vertices[id][2] 
			
			vts[i] = skl.bones[b].pos + [-v[1], -v[3], v[2]] * skl.scale 
		)
		
		--faces
		tvert = 0
		nfcs = ld[2] + ld[3]
		for fc = 1 to nfcs do
		( 
			local id = offs_fcs_lod + fc 
			--if fc > ld[2] do id = offs_fcs_cp + fc 
			
			fdata = this.faces[id] 
			face 	= [0, 0, 0]
			tface	= [0, 0, 0] 
			
			for i = 1 to 3 do
			(
				j 			= i + i * 2 - 1				
				face[i] 	= fdata[j] + 1
				tface[i]	=	tvert += 1
				
				u = fdata[j + 1] / 16776960.0
				v = fdata[j + 2] / 16776960.0
				
				uvs[tvert] = [u, 1.0 - v, 0] 
			)
			
			mids[fc]	= fdata[1] + 1
			fcs[fc]	= face
			tfcs[fc]	= tface
		)
		
		name = "LOD" + (lod as string)
		local m = mesh vertices:vts faces:fcs materialIDs:mids name:name
		
		setNumTVerts m uvs.count
		for i = 1 to uvs.count do ( setTVert m i uvs[i] ) 
		buildTVFaces m false
		for i = 1 to m.numfaces do ( setTVFace m i tfcs[i] ) 
		
		meshop.flipNormals m m.faces 
		
		for i = 1 to m.numfaces do
		(				
			setFaceSmoothGroup m i 0
			if i <= ld[2] then setFaceSmoothGroup m i 1
			else setFaceSmoothGroup m i 2
		)
		
		--create selection sets		
		offs = #(0, 0)
		for p in parts do
		(
			plod = p.lods[lod]
			
			fsel = #{}
			
			a = --faces
			a = offs[1] + 1
			b = offs[1] + plod[1]
			if a < b do fsel += #{a..b}
			
			--capped faces
			c = ld[2] + offs[2] + 1
			d = ld[2] + offs[2] + plod[2]
			if c < d do fsel += #{c..d}
			
			--format "% : % % (%)\n" p.name (b-a) (d-c) fsel.count
			
			m.faces[p.name] = fsel
			
			offs[1] += plod[1]  
			offs[2] += plod[2] 
		)
		
		ld_mshs[lod] = m
	),
 	
	fn set_material lod =
	(
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
		
		if classof ld_mshs[lod] == Editable_mesh then ld_mshs[lod].material = mat
		else ( for m in ld_mshs[lod] do ( m.material = mat ) ) 
	),

	fn set_skin lod =
	(
		sliderTime = 0		
		
		m = ld_mshs[lod]	
		
		select m	
		setCommandPanelTaskMode #modify 
		addModifier m (Skin())
		sk = m.modifiers[#skin]
		modPanel.setCurrentObject sk 
		
		for b in skl.bones do skinOps.addbone sk b 0
		completeRedraw()
		
		b0 = for i = 1 to skl.bones.count collect i
		w0 = for i = 1 to skl.bones.count collect 0		
		for i = 1 to m.numverts do ( skinOps.ReplaceVertexWeights sk i b0 w0 )
		
		sk.bone_limit = 3
		sk.clearZeroLimit = 0.01
		sk.ignoreBoneScale  = true
		
		voffs	= 0
		for i = 1 to lod - 1 do voffs += lods[i][1] 
		
		for i = 1 to lods[lod][1] do 
		( 			
			id = i + voffs			
			for w in weights[id] do (skinOps.SetVertexWeights sk i w[1] w[2] )
		)
		
	),  
	
	fn load pth lod:0 anim:false =
	(
		this.name = getFilenameFile pth
		if doesFileExist pth == false do throw ("Unable to open file: " + pth)		
		
		format "Loading %\n" name
		
		sliderTime = 0
		completeRedraw()
		
		parse pth
		
		pth = getFilenamePath pth
		pth = replace pth (pth.count - 6) 7 "DATA\\"
		pth += skl.name
		
		skl.load pth brefs:brefs anim:anim		
		
		/*
		skl.parse pth
		skl.set_bones()
		select skl.bones
		dim0 = $.max - $.min
		delete skl.bones
		skl.bones = #()
		
		skl.set_bones brefs:brefs	
		select skl.bones
		dim1 = $.max - $.min
		
		if anim do skl.set_anim pth		
		skl.clean()
		*/
		
		
		tri.skl = this.skl		
		
		i = 1
		if lod == 0 then lod = lods.count
		else i = lod		
		if lod < 0 or lod > lods.count do return "lod index out of bounds\n"		
		
		for i = i to lod do 
		(
			set_lod_mesh i
			set_material i
			set_skin i
		)
		
		clean()
	),
	
	fn get_dmbone m vts =
	(
		select m
		sk = m.modifiers[#Skin]
		setCommandPanelTaskMode #modify			
		modPanel.setCurrentObject sk
		
		dmBnsNum = skinOps.GetNumberBones sk
		inf = for i = 1 to dmBnsNum collect 0.0		
		
		for v in vts do
		(
			bns = skinOps.GetVertexWeightCount sk v
			
			for i = 1 to bns do
			(
				bId 	= skinOps.GetVertexWeightBoneID sk v i
				w 		= skinOps.GetVertexWeight sk v i
				
				inf[bId] += w
			)
		)
		
		b = findItem inf (amax inf)		
		return b
	),
	
	fn save pth =
	(
		local f = undefined 
		try f = openFile pth mode:"w" catch print pth		
		
		parts =  break_mesh ld_mshs[1]		
		lods = #()
		
		setCommandPanelTaskMode #modify
		
		if tri.skl == undefined do return messagebox "SKL not set" 
		if skl == undefined do skl = tri.skl
		
		for msh in ld_mshs do 
		(
			select msh
			modPanel.setCurrentObject msh.baseObject
			subobjectlevel = 3
			
			part	= #()
			
			for p in parts do
			(
				fsel = msh.faces[p.name]				
				msh.verts[p.name] = meshop.getVertsUsingFace msh fsel
				vsel = msh.verts[p.name]
				
				--fcs = for fc in fsel where (sgBit msh fc.index 1) collect fc.index 
				--cfs = for fc in fsel where (sgBit msh fc.index 2) collect fc.index 
				
				fcs = for fc in fsel collect fc.index 
				vts = for v in vsel collect v.index
				
				append part #(fcs, vts)
			)
			
			append lods part
		)
		
		subobjectlevel = 0
		
		dmbones = for p in lods[1] collect ( get_dmbone ld_mshs[1] p[2] )
		
		--Textures
		textures = #()
		mat = ld_mshs[1].material
		for i = 1 to mat.numsubs where (mat[i].diffuseMap != undefined) do
		(
			txt = filterString mat[i].diffuseMap.filename "\\."
			append textures txt[txt.count - 1]
		)
		
		----------------------------------------------------------------------------------------------------		
		
		format "// version\n%\n" version to:f
		format "// lodCount,textureSetCount,textureCount,boneCount,partCount\n%,%,%,%,%\n" \
		lods.count 1 textures.count skl.bones.count parts.count to:f		
		
		format "// Lod list: VertexCount,triCount,capTriCount,pixelHeight,shadowOnlyFlag\n" to:f
		for i = 1 to lods.count do
		(	
			m = ld_mshs[i]
			capped = 0
			for i = 1 to m.numfaces where ( sgBit m i 2 ) do capped += 1
			format "%,%,%,%,%\n" m.numverts (m.numfaces - capped) capped 999999 0 to:f
		)
		
		format "// skeleton file\n%.SKL\n" skl.name to:f
		
		--Parts list
		format "// partList: \"name\", dominantBone, adjPartCount, adjpartList, lods(triCount, capTriCount)\n" to:f		
		for i = 1 to parts.count do
		(								
			format "\"%\", %\n" parts[i].name (dmbones[i] - 1) to:f
			
			for j = 1 to lods.count do
			(
				msh = ld_mshs[j]
				part = lods[j][i]
				capped = 0
				for fc in part[1] where ( sgBit msh fc 2 ) do capped += 1				
				format "\t%, %\n" (part[1].count - capped) capped to:f
			)
		)
		
		--Vertices
		format "// vertexList: boneCount, boneInfo(index, weight, x,y,z)\n" to:f
		for i = 1 to lods.count do
		(
			msh = ld_mshs[i]
			select msh
			sk = msh.modifiers[#skin]
			modPanel.setCurrentObject sk
			
			for v in msh.verts do
			(
				nbones = skinOps.GetVertexWeightCount sk v.index
				format "%\n" nbones to:f
				for j = 1 to nbones do 
				(
					b 		= skinOps.GetVertexWeightBoneID sk v.index j
					w 		= skinOps.GetVertexWeight sk v.index j
					pos	= ( v.pos * inverse skl.bones[b].transform ) / skl.scale
					
					format "%, %, %, %, %\n" (b - 1) w -pos.y pos.x pos.z to:f
				) 
			)
		)
		
		--Faces
		format "// triList: textureIndex, verts(index, u, v)" to:f 
		fn writeFace m n f =
		(
			local mat = getFaceMatID m n
			local face 	= getFace m n
			local tface	= getTVFace m n
			
			format "\n%" (mat - 1) to:f
			for i = 1 to 3 do
			(					
				tv = getTVert m tface[i]
				u = (tv[1] * 16776960.0) as integer
				v = ((1 - tv[2]) * 16776960.0) as integer
				format ",%,%,%" ((face[i] - 1) as integer) u v to:f
			)			
		)
		
		for i = 1 to lods.count do
		(
			m		= ld_mshs[i]
			lod	= lods[i]
			
			meshop.flipNormals m m.faces
			
			for p in lod do ( for fc in p[1] where (sgBit m fc 1) do ( writeFace m fc f ) )
			for p in lod do ( for fc in p[1] where (sgBit m fc 2) do ( writeFace m fc f ) )
			
			meshop.flipNormals m m.faces
		)
		
		fn getFaceNamedSel m fc = 
		(			
			return ( for i = 1 to parts.count where (findItem m.faces[parts[i].name] fc ) != 0 collect i )
		)
		
		format "\n// capTriList: matching part\n" to:f
		for i = 1 to lods.count do			
		(
			m		= ld_mshs[i]
			lod	= lods[i]
			select m
			modPanel.setCurrentObject m.baseObject
			subobjectlevel = 3
			
			for j = 1 to lod.count do 
			(
				p = lod[j]
				
				for face in p[1] where (sgBit m face 2) do
				(
					mpart = j
					
					vts = meshop.getVertsUsingFace m face
					m.selectedFaces = (meshop.getFacesUsingVert m vts) - #{face}
					
					adj = #()
					for fc in m.selectedFaces where (sgBit m fc.index 2) do ( adj += getFaceNamedSel m fc.index )
					
					for a in adj where a != mpart do ( mpart = a; exit )
					
					format "%\n" (mpart - 1) to:f
				)
			)
		)
		
		subobjectlevel = 0
		
		format "// texture list\n" to:f
		for txt in textures do ( format "%.RAW\n" txt to:f )
		
		format "// bone origin list\n" to:f
		for b in skl.bones do
		(
			v = (b.transform * inverse b.parent.transform).pos / skl.scale			
			format "%,%,%\n" -v[2] v[1] v[3] to:f			
		) 
		
		v = skl.ro_scale
		format "// defaultRootOffsetScale\n%,%,%\n" -v.y v.x v.z to:f
		
		v = skl.bias
		format "// biasUsed\n%,%,%\n" v.x v.y v.z to:f  		
		format "// partForBoneList\n" to:f
		
		for p in parts do ( update p )
		completeRedraw()
		
		for b in skl.bones do
		(			
			local pos = b.pos
			if b.children.count == 1 do ( pos = ((pos + b.children[1].pos) / 2) )	
			
			p = -1
			
			for i = 1 to parts.count do 
			( 
				if ( isInside parts[i] pos ) do ( p = i; exit ) 	
			)
			
			if p == -1 do p = near parts pos
			
			format "%\n" (p - 1) to:f
		)
		
		fclose f
		delete parts
		
	)

)
