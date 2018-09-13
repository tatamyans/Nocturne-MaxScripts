 
struct skl_motion
(
	index,
 
	params 			= #(),
	transitions 		= #(),	 	
	signals 			= #(), 
	markers 			= #()
)

struct noc_skl
(
	name				= "",
	
	root,
	scale				= 1.0,
	bones			= #(),
	
	version			= 3,	
	nframes,
	offs_angles,
	
	--from dfm 
	ro_scale			= [1, 1, 1],
	bias				= [0, 0, 0],
	
	blist				= #(),	
	angles			= #(),
	canceled		= #(),
	rootoffs			= #(),
	brefs				= #(),
	
	mversion		= 2, 
	states 			= #(),	
	motions 			= #(),
	
	fn parse pth = 
	(	
		oldpos = _pos 
		oldEOL = _eol
		_pos = 0
		_eol = getEOL pth
		
		local f = undefined
		f = openFile pth mode:"rb"
		
		name = getFilenameFile pth 
		version	= gets f t:integer 
		a	 		= getarr f t:integer		
		nbones 	= a[1]
		nframes	= a[2]
		nangles 	= nbones * nframes
		
		--bones list
		for i = 1 to nbones do blist[i] = ( getarr2 f #(string, integer) sep:",\"" )
		for b in blist do ( b[2] += 1 )
		
		--angles
		skipPastString f "// angle list: w,x,y,z"
		offs_angles = _pos --filepos f 
		if version == 4 do ( seek f (_pos + nangles * 16) ) 
		
		skipPastString f "// root offset list: x,y,z" 
		rootoffs 		= for i = 1 to nframes collect ( getarr f t:float )
		canceled 	= for i = 1 to nframes collect ( getarr f t:float )		
		
		mversion	= gets f as integer
		nstates		= gets f as integer
		for i = 1 to nstates do states[i] = gets f	
		
		nmotions = gets f as integer		
		for i = 1 to nmotions do
		(
			m = skl_motion()
			m.index = i - 1
			m.params   = getarr2 f #(string, integer, integer, integer, integer) sep:","	--1 "name",fps,state,frameStart,frameCount			
			m.params += getarr f t:integer	--6 exitForwardFromFrameNumber,    exitForwardToMotionNumber,    exitForwardToFrameNumber									
			m.params += getarr2 f #(integer, float, integer)  --9 exitForwardCmd,   exitForwardTweenTime,   exitForwardsetNewStateAsDesired
			m.params += getarr f t:integer	--12 exitBackwardToMotionNumber,    exitBackwardToFrameNumber
			
			if mversion == 2 do
			(				
				m.params[14] = 1					--14 frameResolution, storedFrameCount
				m.params[15] = m.params[5] 
			)			
			if mversion == 3 do ( m.params += getarr f t:integer )	--14 frameResolution, storedFrameCount
			
			
			m.params[1] = substring m.params[1] 2 (m.params[1].count - 2)		--unquote name string	
			n = gets f as integer		
			for j = 1 to n do ( m.transitions[j] = getarr2 f #(integer, integer, integer, integer, float, integer) )
				
			n = gets f as integer
			for j = 1 to n do ( m.signals[j] = getarr f t:integer )
			
			m.markers = getarr f t:integer
			deleteItem m.markers 1
			
			motions[i] = m
		)
		
		--reference bone org list: x,y,z
		for i = 1 to nBones do ( brefs[i] = getv3 f )
		
		
		_pos	= oldpos
		_eol	= oldEOL 
		fclose f		
	),
	
	fn clean =
	(
		angles 		= #()
		canceled	= #()
		rootoffs		= #()
	),
	
	fn set_bones brefs:undefined =
	(
		if brefs == undefined do brefs = this.brefs
		
		bsz = 1
		maxver = maxversion()
		if maxver[1] > 12000 do
			bsz = 0.1		
		
		for i = 1 to blist.count do
		(
			bname 	= blist[i][1]
			pid	 	= blist[i][2]
			blen 		= brefs[i] * scale
			
			v1 = brefs[1] * scale
			
			parent = undefined			
			if pid > 0 do 
			(
				parent = (for b in bones where b.name == blist[pid][1] collect b)[1]
				v1 = parent.pos + blen 
			)
			
			v2 = copy v1
			v2.y += 1
			b = BoneSys.CreateBone v1 v2 [0, 0, bsz] 
			
			b.name		= bname
			b.parent		= parent 
			b.width		= 0.1
			b.height		= 0.1
			b.scale		= [-0.3, -1.0, -1.0]
			resetScale b 
			
			bones[i] = b
		)
		
		root = point()
		root.name = name
		root.size = 3 * scale
		root.wirecolor = color 200 255 200	
		root.transform = (matrix3 [0,1,0] [-1,0,0] [0,0,1] [0,0,0])
		
		for b in bones where b.parent == undefined do b.parent = root
		
		bones[1].pos -= bias * scale
		bias = [0.0, 0.0, 0.0] 
		
		root.transform *= (matrix3 [-1,0,0] [0,0,1] [0,-1,0] [0,0,0]) 
		
	),
 
	fn set_anim pth =
	(
		fn getangles3 f = ( q = filterString ( f.readline() ) ", ";  for i = 1 to 4 do q[i] = q[i] as float; q ) 		
		fn getangles4 f = ( for j = 1 to 4 collect ( readFloat f ) )
		
		local f = undefined
		
		if version == 3 do
		(			
			f = memStreamMgr.openFile pth 
			f.seek offs_angles #seek_set		--filepos treats LF as 2 bytes since max11-12!
			--do str = f.readline() while str != "// angle list: w,x,y,z" and f.pos() < f.size()  
			getangles = getangles3
		)		
		if version == 4 do
		( 
			f = fopen pth "rb"
			fseek f offs_angles #seek_set			
			getangles = getangles4
		)
		
		m0 =	for i = 1 to bones.count collect ( at time 0 bones[i].transform )	
		r0  = at time 0 root.transform
		
		FrameTagManager.ResetFrameTags()
		print "Loading motions. Please wait..."
		
		with animate on
		( 
			tm_start = 0
			
			for m in motions do
			(
				frm_start		= m.params[4]
				frm_count		= m.params[5] 
				frm_res 			= m.params[14]
				frm_stored		= m.params[15]
				
				at time (tm_start + 1) root.pos = r0.pos 
					
				FrameTagManager.CreateNewTag m.params[1] (tm_start + 1)
				
				for frm = 0 to frm_stored - 1 do
				(
					tm = tm_start + frm * frm_res + 1					
					n = frm_start + frm + 1
					
					for i = 1 to bones.count do
					(						
						q = getangles f
						b = bones[i]
						
						q = quat -q[2] -q[4] q[3] q[1] 
						rm = q as matrix3
						
						at time tm 
						(
							pos = b.pos
							b.transform = m0[i] *  rm
							b.pos = pos
						)
					) 
					
					at time tm  
					(
						v	= rootoffs[n]
						v1	= [ -v[1], -v[3], v[2] ]
						
						--v1 *= v
						v1 *= scale
						v1 *= ro_scale						
						
						v	= canceled[n]
						v2	= [ -v[1], -v[3], v[2] ] * scale
						
						root.pos += v2
						bones[1].pos = m0[1].pos + root.pos + v1    
					) 
				) 
				
				tm_start += frm_stored * frm_res 
			) 
			
			animationRange = interval 0 tm_start	
		) 
		
		fclose f  
	),

	fn load pth anim:false brefs:undefined =
	(   
		if doesFileExist pth == false do throw ("Unable to open file: " + pth)			
		
		sliderTime = 0
		completeRedraw()
		
		name = getFilenameFile pth 
		parse pth
		
		if brefs == undefined do brefs = this.brefs
		set_bones brefs:brefs		
		
		if anim do set_anim pth		
		
		clean()
	),
	
	fn save pth = 
	(		
		format "version: %\n" version
		
		local f = undefined
		f = openFile pth mode:"w" 
		if f == undefined do (print "Unable to open: " + pth as string; return 0)		
		
		fpos = 0
		
		format "// skeleton version\n%\n" version to:f
		format "// bonecount, frameCount\n%,%\n// boneList\n" bones.count nframes to:f	
		
		bList = #()	
		for b in bones do 
		( 
			id = (findItem bones b.parent) - 1
			append bList #(b.name, id)
			format "\"%\", %\n" b.name id to:f
		)
		
		--------------------------------------------------------------------------------
		--------------------------------------------------------------------------------
		format "// angle list: w,x,y,z\n" to:f
		
		fn writeangles3 f q =  ( format "%,%,%,%\n"  q.w -q.y q.x q.z to:f )
		
		fn writeangles4 f q = ( writefloat f q.w; writefloat f q.x; writefloat f q.z; writefloat f -q.y)
		writeangles = writeangles3
		
		if version == 4 do
		(
			fpos = filepos f
			fclose f
			f = fopen pth "ab"
			fseek f fpos #seek_set
			writeangles = writeangles4
		)
		
		tr0 = for b in bones collect ( at time 0 b.transform )
		
		tm_start = 0
		for m in motions do
		(
			frm_start		= m.params[4]
			frm_count		= m.params[5] 
			frm_res 			= m.params[14] 
			frm_stored		= (frm_count / frm_res + (mod frm_count frm_res)) as integer
			m.params[15] = frm_stored
			
			for frm = 0 to frm_stored - 1 do
			(
				tm = tm_start + frm * frm_res + 1
				
				for j = 1 to bones.count do
				(	
					tr1 = at time tm bones[j].transform
					q = (inverse (tr1 * inverse tr0[j])).rotation
					writeangles f q					
				)
			)
			
			tm_start += frm_count  
		)
		
		if version == 4 then 
		(
			fpos = ftell f
			fclose f
		)	
		else 
		(
			fpos = filepos f
			close f
		)
		
		--------------------------------------------------------------------------------
		--------------------------------------------------------------------------------
		
		if root == undefined do root = bones[1].parent
		
		f = openFile pth mode:"a"
		fseek f fpos #seek_set
		if version == 4 do format "\n" to:f
		
		format "// root offset list: x,y,z\n" to:f
		b		= bones[1]
		tr0	= at time 0 b.pos
		v		= undefined 
		v0		= at time 0 b.transform
		r0		= at time 0 root.transform
		
		tm_start = 0
		for m in motions do
		(
			--format "//%\n" m.params[1] to:f
			
			frm_start		= m.params[4]
			frm_count		= m.params[5] 
			frm_res 			= m.params[14] 
			frm_stored		= m.params[15] 
			
			for frm = 0 to frm_stored - 1 do
			(
				tm = tm_start + frm * frm_res + 1 
				
				v1		= at time tm b.transform
				r1		= at time tm root.transform 
				d 		= v0 + (r1 - r0)			
				v 		= (v1 * inverse d).pos / scale
				
				format "%,%,%\n" -v.y v.x v.z to:f	
			)
			
			tm_start += frm_count  
		)		
		 
		_r0 = at time 0 root.transform.pos		
		format "// canceled movement list: x,y,z\n" to:f		
		
		tm_start = 0		
		for m in motions do
		(
			--format "//%\n" m.params[1] to:f
			
			frm_start		= m.params[4]
			frm_count		= m.params[5] 
			frm_res 			= m.params[14] 
			frm_stored		= m.params[15]
			
			r0 = _r0
			
			for frm = 0 to frm_stored - 1 do
			(
				tm = tm_start + frm * frm_res + 1 
				
				r1 = at time tm root.pos 
				
				v =  (r1 - r0)  / scale
				r0 = r1
				
				format "%,%,%\n" -v.x v.z -v.y to:f					
				--format "\t\t %  %  %  %  %\n" tm_start frm_count frm_stored frm tm to:f
			)
			
			tm_start += frm_count  			
		)
		
		------------------------------------------------------
		--motion list
		------------------------------------------------------
		
		format "// motion list version\n%\n// state list\n%\n" mversion states.count to:f		
		for s in states do  format "%\n" s to:f
			
		format "// motion count\n%\n" motions.count to:f		
		for i = 1 to motions.count do
		(
			m = motions[i]
			id = i - 1
			
			p = m.params
			format "// motion %: \"name\",fps,state,frameStart,frameCount\n\"%\",%,%,%,%\n" \
				id p[1] p[2] p[3] p[4] p[5] to:f
			format "// motion %: exitForwardFromFrameNumber,exitForwardToMotionNumber,exitForwardToFrameNumber\n%,%,%\n"  \
				id p[6] p[7] p[8] to:f 
			format "// motion %: exitForwardCmd,exitForwardTweenTime,exitForwardsetNewStateAsDesired\n%,%,%\n" \
				id p[9] p[10] p[11] to:f
			format "// motion %: exitBackwardToMotionNumber,exitBackwardToFrameNumber\n%,%\n" \
				id p[12] p[13] to:f 
			
			
			if mversion == 3 do 
			(
				p[15] = (p[5] / p[14]) as integer
				format "// motion %: frameResolution, storedFrameCount\n%,%\n" \
				id p[14] p[15] to:f
			)
			
			format "// motion % transition count, list: desiredState, cmd, toMotionNumber, toFrameNumber, tweenTime, setNewStateAsDesired\n%\n" id m.transitions.count to:f
			for t in m.transitions do ( format "%,%,%,%,%,%\n" t[1] t[2] t[3] t[4] t[5] t[6] to:f 	)
			format "// motion % signal count, list: frameNumber, value\n%\n" id m.signals.count to:f
			for s in m.signals do ( format "%,%\n" s[1] s[2] to:f 	)
			
			mkstr = m.markers as string
			mkstr = substring mkstr 3 (mkstr.count - 3)
			
			format "// motion % marker count, list\n% %\n" id m.markers.count mkstr to:f 	 
		)
		
		format "// reference bone org list: x,y,z\n" to:f
		
		timeslider = 0
		
		for b in bones do
		(
			v = (b.transform * inverse b.parent.transform).pos / scale			
			format "%,%,%\n" -v[2] v[1] v[3] to:f
		)
		
		fclose f
	) 
	
	
	
)