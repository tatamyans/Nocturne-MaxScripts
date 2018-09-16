--Since max12 filestream treats Unix EOL as 2 bytes instead of 1
_eol	= 2
_pos	= 0

fn getEOL pth = 
(
	local f = fopen pth "r"
	fseek f -2 #seek_end
	eol = readshort f
	fclose f
	if eol != 2573 then 1 else 2	
)

fn skip f n:1 = ( for i = 1 to n do ( _pos += ((readline f).count + _eol )) )

fn skipPastString f str = 
(
	local s = ""
	while s != str do (s = readline f; _pos += (s.count + _eol) ) 
	
)

fn gets f t:string s:0 =
(
	str = ""
	do ( str = readline f; _pos += (str.count + _eol) ) while (str == "" or matchpattern str pattern:"//*")
	skip f n:s
	str as t
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


fn round val = ( floor ( val + 0.5 ) )

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
	
	subobjectlevel = 0	
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

fn add_skin_mod msh root =
(	
	bns = #()	
	traverse root.children bns
	
	select msh
	setCommandPanelTaskMode #modify 
	addModifier msh (Skin())
	local sk = msh.modifiers[#skin]
	modPanel.setCurrentObject sk	
	
	for b in bns do skinOps.addbone sk b 0
	completeRedraw()
	
	b0 = for i = 1 to bns.count collect i
	w0 = for i = 1 to bns.count collect 0		
	for i = 1 to  msh.numverts do ( skinOps.ReplaceVertexWeights sk i b0 w0 )
	
	sk.bone_limit = 3
	sk.clearZeroLimit = 0.01
	sk.ignoreBoneScale  = true
	
)

fn selsg m sg =
(
	select m
	setCommandPanelTaskMode #modify
	modPanel.setCurrentObject m.baseObject
	subobjectlevel = 3
	
	setFaceSelection m (for fc = 1 to (getNumFaces m) where ((getFaceSmoothGroup m fc) == sg) collect fc)	
)

fn cpselsets src dst =
(
	setCommandPanelTaskMode #modify
	
	select src
	modPanel.setCurrentObject src.baseObject
	subobjectlevel = 3
	completeRedraw()
	
	if dst.faces.count != src.faces.count do return "face count mismatch"
	if src.faces.selSetNames.count == 0 do return "nothing to copy"

	local names	= #()
	local data		= #()
	
	for i = 1 to src.faces.selSetNames.count do
	(		
		selset = src.faces.selSetNames[i]
		append names selset
		append data (for fc in src.faces[selset] collect  fc.index )
	)
	
	subobjectlevel = 0
	select dst
	modPanel.setCurrentObject dst.baseObject
	subobjectlevel = 3
	completeRedraw()
	
	for i = 1 to names.count do dst.faces[names[i]] = data[i]
	
	print dst.faces.selSetNames.count
	subobjectlevel = 0
	"OK"
)