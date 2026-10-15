extends RefCounted

const WIDTH: float=1280.0
const NAMES=[
	"雨中的独腿人","街角的风","屋檐滴答","错拍的雨","风雨之间","第一条水沟",
	"湿木板","钉子与接头","坡上的风","雨中的接头","低低的檐","逆风越沟",
	"水上的盖子","涨落之间","错开的落脚","顺水与逆风","雨打软木","潮声的间隙",
	"旧招牌","风里的钟摆","滴水的短桥","低处的小跳","木箱的背风面","摆影与骤雨",
	"斜坡与雨滴","错开的滴答","起伏的渡口","桥中央的安静","雨水的岔口","最后一道沟",
	"檐下的残雨","门前的断阶","陌生的旋律","温暖的灯光","孩子的脚步","报纸的小船"]
const GROUPS=["雨中的石板","倾斜的木板","水面上的落脚点","风里的旧物","沟岸的长路","陌生的旋律"]
# Authored routes: x, foot elevation, width, material, optional slope.
# Boundary banks share a level cap and overlap; visible water separates true gaps.
const ROUTES=[
	[],[],[],
	[[390,610,210],[735,575,220]],
	[[360,600,200],[700,535,200]],
	[[415,595,180],[790,570,180]],
	[[355,625,260,"wet",-12],[770,575,245,"wet",10]],
	[[355,620,240,"wet",-16],[690,545,155],[930,600,160,"wet",12]],
	[[380,620,260,"wet",-18],[800,550,210]],
	[[370,605,210],[730,545,240,"wet",-14]],
	[[370,650,230],[760,650,230]],
	[[400,585,195],[780,550,190]],
	[[360,590,210,"float"],[675,335,200],[970,510,170]],
	[[350,590,180,"float"],[650,330,180],[940,480,170,"float"]],
	[[355,610,175,"float"],[660,570,160,"float"],[945,610,160]],
	[[380,595,185,"float"],[750,555,205]],
	[[365,600,195],[715,590,185,"float"],[990,340,140]],
	[[350,610,160,"float"],[625,565,175],[920,600,175,"float"]],
	[[370,585,200],[760,575,210]],
	[[355,605,210],[730,535,270]],
	[[370,605,220],[760,565,185]],
	[[355,650,175],[670,650,170],[975,650,155]],
	[[370,600,230],[785,550,200]],
	[[355,600,185],[700,550,200],[995,615,140]],
	[[355,615,250,"wet",-17],[770,555,220]],
	[[350,590,180],[665,520,170],[975,595,155]],
	[[360,590,180,"float"],[685,325,180],[970,520,165,"float"]],
	[[395,605,260],[810,590,215]],
	[[360,610,215,"wet",-15],[720,535,180],[1000,610,130]],
	[[370,590,180],[710,515,185],[1005,605,130]],
	[[380,605,210],[755,565,195]],
	[[370,590,170],[690,520,175],[980,605,150]],
	[],
	[[365,605,195],[725,545,190]],
	[[365,600,180],[700,540,180],[990,610,140]],
	[]]

static func platform(x: float,y: float,w: float,asset: String="quay_rock_v3",angle: float=0.0) -> Dictionary:
	return {"x":x,"y":y,"w":w,"asset":asset,"wet":asset.begins_with("plank_"),"motion":asset=="floating_lid" or asset=="cork","angle":deg_to_rad(angle)}

static func room(index: int) -> Dictionary:
	var platforms: Array=[]
	var continuous: bool=ROUTES[index].is_empty()
	if continuous: platforms.append(platform(-80,650,1440,"pavement_v2"))
	else:
		platforms.append(platform(-80,650,385,"broken_quay_v3"))
		for j in range(ROUTES[index].size()):
			var p: Array=ROUTES[index][j]
			var material: String=str(p[3]) if p.size()>3 else "stone"
			var asset: String="quay_rock_v3"
			if material=="wet": asset="plank_oak" if j%2==0 else "plank_pine"
			if material=="float": asset="floating_lid" if j%2==0 else "cork"
			var entry:=platform(float(p[0]),float(p[1]),float(p[2]),asset,float(p[4]) if p.size()>4 else 0.0)
			entry.amplitude=58.0 if index==12 else (78.0 if index<18 else 90.0)
			entry.period=4.2 if index==12 else 3.7
			entry.motion_phase=(j+1)*0.8
			if index in [12,13,16,26] and entry.motion:
				entry.amplitude=100.0 if index==12 else 110.0
				entry.period=6.4
				entry.motion_phase=PI/2 if j<2 else -PI/2
			platforms.append(entry)
		platforms.append(platform(1150,650,350,"broken_quay_v3"))
	var wind: float=0.0
	if index in [1,4,8,11,15,19,22,23,24,26,28,29,31,33,34]: wind=-460.0 if index<12 else -560.0
	if index in [15,26,34]: wind=470.0
	var drop_slots: Array=[]
	match index:
		2: drop_slots=[520]
		3: drop_slots=[470,840]
		4: drop_slots=[455,795]
		9: drop_slots=[475,845]
		14: drop_slots=[440,740]
		16: drop_slots=[460,805]
		17: drop_slots=[430,1010]
		20: drop_slots=[465,850]
		21: drop_slots=[430,745,1045]
		23: drop_slots=[445,875]
		24: drop_slots=[475,875]
		25: drop_slots=[435,740,1045]
		26: drop_slots=[445,770]
		28: drop_slots=[475,810,1060]
		29: drop_slots=[460,800]
		30: drop_slots=[470,850]
		31: drop_slots=[450,775]
		33: drop_slots=[465,820]
		34: drop_slots=[450,790]
	var period: float=2.8 if index==2 else (2.35 if index<12 else (2.1 if index<24 else 1.9))
	var drops: Array=[]
	for j in range(drop_slots.size()):
		var x: float=float(drop_slots[j])
		var y: float=650
		for p in platforms:
			if x>=p.x and x<=p.x+p.w: y=p.y
		drops.append({"x":x,"y":y,"phase":j*period*0.43,"period":period})
	var wet: bool=false
	var floating: bool=false
	for p in platforms:
		wet=wet or p.wet
		floating=floating or p.motion
	var kind: String="float" if floating else ("wet" if wet else "stone")
	if index==32: kind="melody"
	if not drops.is_empty(): kind+="_drops"
	if wind!=0: kind+="_wind"
	var hint: String="朝那扇亮着的窗，向前走。"
	if not drops.is_empty(): hint="水珠鼓起，涟漪亮起。\n别在落点下停留。"
	if wind!=0 and not drops.is_empty(): hint="风歇时找落点，雨落前离开。\n立正挡得住风，挡不住水滴。"
	elif wind!=0: hint="Shift — 立正，迎着风站稳。\n再找一个起跳的间隙。"
	elif floating: hint="等它升到合适的高度。\n落脚之后，还要准备下一步。"
	elif wet: hint="湿木板会滑。\n平石台上可以安心蓄力。"
	if index in [10,21]: hint="檐下用小跳。\n留心前方的落水声。"
	if index==22: hint="箱子后面是背风处。\n走出去，才会碰到风。"
	if index==27: hint="桥中央，可以喘一口气。"
	if index==32: hint="门廊下，雨暂时够不着他。\n也许可以站一会儿。"
	if index==33: hint="灯光很暖，却不是他的家。\n风和雨还没有停。"
	if index==34: hint="雨里，传来了孩子的脚步。"
	if index==35: hint="他还想回到那扇窗前。"
	if index==12: hint="低处先登上木盖。\n等水把他托高，再跳上高岸。"
	if index==13: hint="两处水位错开涨落。\n高岸是中途歇脚处。"
	if index==16: hint="木盖升高时，才够得着右岸。\n岸上的纸星，还要再跳一次。"
	if index==26: hint="先借涨水登高，再找风停的间隙。\n别停在积水的檐角下。"
	if index==19: hint="招牌向左让开时，风会暂歇。\n提前蓄力，穿过它身后的空当。"
	var star:=Vector2(820,575) if continuous else Vector2(float(platforms[2].x)+float(platforms[2].w)*0.55,float(platforms[2].y)-75)
	if index==13: star=Vector2(1020,295)
	if index==16: star=Vector2(1060,265)
	return {"index":index,"name":NAMES[index],"group":GROUPS[index/6],"kind":kind,"platforms":platforms,"drops":drops,"wind":wind,"wind_period":6.0 if index==19 else (4.5 if index>3 else 5.0),"swing":index in [18,19,23],"low":index in [10,21],"hint":hint,"calm":index in [27,32,35],"continuous":continuous,"height_gate":index in [12,13,16,26],"star":star,"swing_period":6.0 if index==19 else (3.6 if index==23 else 4.6)}
