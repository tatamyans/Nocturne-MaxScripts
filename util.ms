fn round val = ( floor ( val + 0.5 ) )

fn skip f n:1 = 
(  
	for i = 1 to n do ( skipToNextLine f ) 
)

fn gets f t:string =
(
	s = ""
	do ( s = readline f ) while matchpattern s pattern:"//*"
	--print s
	s as t
) 

fn getss f t:string =
(
	s = ""
	do ( s = readline f ) while matchpattern s pattern:"//*"
	skipToNextLine f 
	s as t
) 
 
fn getarr f sep:", \t" t:string = 
(
	arr = filterString ( gets f ) sep
	for e in arr collect e as t
)

fn getarr2 f t sep:", \t" = 
(
	arr = filterString ( gets f ) sep
	for i = 1 to t.count collect arr[i] as (t[i])
)

fn getv3 f sep:", \t" = 
(
	v = getarr f sep:sep t:float	
	Point3 v[1] v[2] v[3]
)

fn skipPastString f str =
(
	skipToString f str
	skip f
)

fn sgBit m fc sg = 
( 
	bit.get (getFaceSmoothGroup m fc ) sg 
)

fn getbbox m vsel =
(
	vmin = vsel[1].pos 
	vmax = vsel[1].pos
	
	for v in vsel do
	(
		for i = 1 to 3 where v.pos[i] < vmin[i] do vmin[i] = v.pos[i]
		for i = 1 to 3 where v.pos[i] > vmax[i] do vmax[i] = v.pos[i]
	)
	
	return #(vmin, vmax)
)

fn isInside m v =
(
	bb = nodeLocalBoundingBox m
	
	if	( bb[1].x <= v.x and v.x  <= bb[2].x ) and	 \
		( bb[1].y <= v.y and v.y <= bb[2].y ) and \
		( bb[1].z <= v.z and v.z <= bb[2].z )
	then return true
	else return false
)

fn near ms v = 
( 	
	local min_dist = 0x7FFFFFFF
	local res = -1
	
	for i = 1 to ms.count do
	(
		dist = distance v ms[i].center
		if dist < min_dist do 
		(
			min_dist = dist
			res = i
		)		
	)	
	return res
)

fn break_mesh m = 
(
	select m
	setCommandPanelTaskMode #modify
	modPanel.setCurrentObject m.baseObject
	subobjectlevel = 3
	
	if m.faces.selSetNames.count == 0 do m.faces["onlypart"] = #{1..m.numfaces}
	update m
	
	mshs = #()
	parts = m.faces.selSetNames	
	for p in parts do
	(
		sel = m.faces[p]
		tmesh = meshop.detachfaces m sel delete:false asmesh:true
		obj = Editable_Mesh name:p
		obj.transform = m.transform
		obj.mesh = tmesh
		obj.material = m.material
		update obj
		append mshs obj
	)
	
	return mshs
)


fn bname_cmp a b = 
(	 
	case of 
	(
		(a.name < b.name)	: -1		
		(a.name > b.name)	: 1
		default : 0
	)	
)

fn traverse bns dst =
(
	join dst bns

	local arr = #()
	for b in bns where (b.children.count > 0) do ( arr += b.children ) 
	
	if arr.count > 0 do
	(
		qsort arr bname_cmp
		traverse arr dst
	) 
)


