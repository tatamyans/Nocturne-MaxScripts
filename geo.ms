struct gameset
(	
	name,
	version,
	
	fn getvt f = ( [readfloat f, readfloat f, readfloat f] ),
	fn getfc f = ( [readlong f, readlong f, readlong f] ),
	
	fn parse_geometry pth = 
	(
		local f = fopen pth "rb"
		if f == undefined do ( throw "unable to open file"; exit)
		fseek f 0 #seek_end
		fsize = ftell f
		fseek f 0 #seek_set
		
		cm = matrix3 [1,0,0] [0,0,1] [0,1,0] [0,0,0]
		
		--version lights? frames? cameras?
		header 	= for i = 1 to 4 collect ( readLong f )	
		unk 		= for i = 1 to 9 collect ( readlong f )
		parts		= #()
		
		pos = 0 
		
		while pos < fsize do
		(
			while (finditem unk (readlong f)) == 0 do ( fseek f -3 #seek_cur )
			
			fseek f -4 #seek_cur
			unk = for i = 1 to 6 collect ( readlong f )
			
			nvts = readLong f
			nfcs = readLong f
			
			while nvts == 0 and pos + 8 < fsize do 
			( 
				fseek f 24 #seek_cur
				nvts = readLong f 
				nfcs = readLong f 				
			)			
			if classof nvts != integer do exit
			
			--read vert and faces			
			vts = for i = 1 to nvts collect ( getvt f )
			fcs = #()
			for i = 1 to nfcs do ( fcs[i] = (getfc f) + 1; fseek f 20 #seek_cur )
			m = mesh vertices:vts faces:fcs
			
			m.transform *= cm
			append parts m
			
			--format "% (% %)\n" (ftell f) nvts nfcs
			
			pos = (ftell f) + 512
		) 
		
		fclose f  
	),
	
	fn pbh2m v =
	(
		cp = cos v[1]
		cb = cos v[2]
		ch = cos v[3]
		
		sp = sin v[1]
		sb = sin v[2]		
		sh = sin v[3]		
		
		rx = ch * cb + sh * sp * sb
		ry = sb * cp
		rz = -sh * cb + ch * sp * sb
		
		ux = -ch * sb + sh * sp * cb
		uy = cb * cp
		uz = sb * sh + ch * sp * cb
		
		fx = sh * cp
		fy = -sp
		fz = ch * cp
		
		m = matrix3 [rx, rz, ry] [fx, fz, fy] [ux, uz, uy] [0, 0, 0]
		m = inverse m
		rotateX m -90
		m
	),
	
	fn parse_light f = 
	(
		nm		= gets f s:1
		print nm
		
		pos		= getv3 f; skip f				
		rot		= getv3 f; skip f
		fov		= gets f t:float s:1
		aspect	= gets f t:float s:1
		intensity	= gets f t:float s:1
		type		= gets f t:integer s:1
		rgba		= getarr f t:float; skip f
		sz_xy		= getarr f; 
		
		skipPastString f "visible"
		visible	= gets f t:integer
		skip f n:(visible + 1)
		
		fs = freeSpot name:nm castShadows:true
		if type == 1 do fs.type = #omni
		
		swap pos[2] pos[3]
		rot *= 57.2958
		
		fs.rotation	 		= (pbh2m rot).rotationpart
		fs.position			= pos
		fs.rgb 				= color rgba[1] rgba[2] rgba[3]
		fs.multiplier 		= intensity
		fs.nearAttenStart	= rgba[4]
		fs.nearAttenEnd	= rgba[5]
		fs.value 				= 155		
		fs.useFarAtten 	= true
		--fs.showFarAtten 	= true
		
		if type == 0 do
		(
			fs.hotspot = fov
			fs.falloff = fov * 2.8
		)
		
		
	),
	
	fn parse_cam f =
	(
		nm 		= gets f s:1
		pos 		= getv3 f; swap pos[2] pos[3]; skip f
		ori			= getv3 f; skip f
		fov 		= (gets f t:float) * 2.6923
		skip f
		
		mx = matrix3 0
		for i = 1 to 3 do ( mx[i] = getv3 f)
		swap mx[2] mx[3]
		mx = inverse mx
		mx.row3 *= -1
		mx.row4 = pos
		
		cam 				= freecamera name:nm 
		cam.transform = mx
		cam.fov 		= fov	
		skip f n:7
		
	),	 
	
	fn setread f =
	(
		if f == undefined do ( throw "File is undefined!" )
		seek f #eof
		fsize = filepos f
		seek f 0
		--res = readChars f fsize errorAtEOF:false
		
		format "fsize: %\n"  fsize
		
		pos = 0
		lncount = 0
		while pos < fsize - 3 do
		(
			ln = readline f
			lncount += 1
			
			if (findString ln "-- light name" ) != undefined do parseLight f
			if (findString ln "-- camera name") != undefined do parseCamera f
			
			pos = filepos f
		)
		
		format "lncount %\n" lncount
		
	),
	
	fn load pth geo:true = 
	(		
		local f = openFile pth
		if f == undefined do throw ("Unable to open file: " + pth)	 
		name	= getFilenameFile pth
		version = gets f t:integer
		
		for i = 1 to 2 do gets f
		
		geoname = gets f
		geopth = (substituteString (getFilenamePath pth) "MODELS" "DATA") + geoname
		if doesFileExist geopth == false do throw ("Unable to open file: " + geopth)	 
		
		if geo do parse_geometry geopth		
		
		skipPastString f "lightCount"
		nlights = gets f t:integer s:1
		for i = 1 to nlights do parse_light f
		
		--skipPastString f "cameraCount"
		ncams = gets f t:integer s:1
		for i = 1 to ncams do parse_cam f
		
		fclose f
		
	)		
)
