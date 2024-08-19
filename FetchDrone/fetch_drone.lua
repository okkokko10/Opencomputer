---@diagnostic disable
ver="0.1.2"
PORT=2400
c=component
modem=c.proxy(c.list("modem")())
d=c.proxy(c.list("drone")())
ic=c.proxy(c.list("inventory_controller")())
dba=c.list("database")()
db=dba and c.proxy(dba)
co=computer

function unserialize(data)
	return select(2,pcall(load("return "..data,"=data",nil,{math={huge=math.huge}})))
end
function acm(...)
	modem.broadcast(PORT,...)
end
function longmsg(name,msg)
	local id=math.random()
	local mxs=8192-49-#name
	local ma=math.ceil(#msg/mxs)
	for i=1,ma do
		acm("longmsg",id,i,ma,name,string.sub(msg,(i-1)*mxs+1,i*mxs))
	end
end
function stis(i,slot)
	local h = db and db.computeHash(1) or "nil"
	return i and "{"..table.concat({slot,i.size,"\""..i.name.."\"",i.damage,"\""..i.label.."\"",i.hasTag and "true" or "false",i.maxDamage,i.maxSize,"\""..h.."\""},",").."}"
end

x=0
y=0
z=0
ofs=0.1
vel=1
function center() 
	while d.getOffset()>ofs or d.getVelocity()>vel do end
end

a={}

c_cmdl=nil
c_cmd_index=nil
c_cmd_id=nil
function a.move(o)
	d.move(o.dx,o.dy,o.dz)
	x=x+o.dx
	y=y+o.dy
	z=z+o.dz
	center()
end
function a.moveto(o)
	d.move(o.x-x,o.y-y,o.z-z)
	x=o.x
	y=o.y
	z=o.z
	center()
end
function a.scan(o,noSend)
	local side=o.side
	local space=ic.getInventorySize(side) or 0
	local first=math.min(o.from or 1, space)
	local last=math.min(o.to or space, space)

	local ts=co.uptime()
	local st={}
	for i=first, last do
		l=db and ic.store(side,i,dba,1)
		table.insert(st,stis(ic.getStackInSlot(side, i),i))
	end
	local te=co.uptime()
	local scd= "{id="..o.id..",time_start="..ts..",time_end="..te..",space="..space..",from="..first..",to="..last..",storage={" .. table.concat(st,",") .. "}" .. "}"
	if not noSend then
		longmsg("scan_data",scd)
	end
	return scd
end

function a.suck(o)
	d.select(o.own_slot)
	return ic.suckFromSlot(o.side,o.slot,o.size)
end
function a.drop(o)
	d.select(o.own_slot)
	ic.dropIntoSlot(o.side,o.slot,o.size)
end
function a.suckall(o)
	local ownspace=d.inventorySize() or 0
	local space=ic.getInventorySize(o.side) or 0
	local i=1
	local j=1
	while i <= ownspace and j <= space do
		if a.suck({own_slot=i,side=o.side,slot=j}) then
			i=i+1
		end
		j=j+1
	end
end

function a.execute(o)
	load(o.code)()
end

function a.setWakeMessage(o)
	if o.message then modem.setWakeMessage(o.message,o.fuzzy and true) end
end
function a.shutdown(o)
	co.shutdown(o.reboot)
end

bp=co.beep

function a.beep(o)
	bp(o.frequency,o.duration)
end

function ist()
	local space=d.inventorySize() or 0
	local storage={}
	for i=1, space do
		l=db and ic.storeInternal(i,dba,1)
		table.insert(storage,stis(ic.getStackInInternalSlot(i),i))
	end
	return "space="..space..",storage={" .. table.concat(storage,",") .. "}"

end
function a.status(o,ovN,extra)
	longmsg(ovN or "status","{"..ist()..",freeMemory="..co.freeMemory()..",totalMemory="..co.totalMemory()..
	",energy="..co.energy()..",maxEnergy="..co.maxEnergy()..",uptime="..co.uptime()..
	",x="..x..",y="..y..",z="..z..",cmd_id="..(c_cmd_id or "nil")..",cmd_index="..(c_cmd_index or "nil")..
	",offset="..d.getOffset()..
	",extra="..(extra or "nil")..
	",ver=\""..ver..
	"\"}")
end

function a.echo(o)
	longmsg("echo",tostring(o.message))
end

function a.updateposition(o)
	x=o.x
	y=o.y
	z=o.z
end


function signalerror(result)
	a.status(nil,"error",tostring(result))
	bp(100,0.3);bp(102,0.1);bp(99,0.1)
end
function parse(id,cmdl)
	c_cmd_id=id
	c_cmdl=cmdl
	for i=1, #cmdl do
		c_cmd_index=i
		local ok,result=pcall(function() a[cmdl[i].type](cmdl[i]) end)
		if not ok then
			signalerror(result)
		end
	end
	c_cmd_index=nil
end


function main()
	modem.open(PORT)
	a.status(nil,"wakeup")
	while true do
		local evt,l,r,p,d,first,id,commandlist=co.pullSignal()
		if evt=="modem_message" and first=="fetcher" then parse(id,unserialize(commandlist)) end
	end
end
main()