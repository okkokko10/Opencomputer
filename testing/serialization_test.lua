function unserialize(data)
checkArg(1,data,"string")
return select(2,pcall(load("return "..data,"=data",nil,{math={huge=math.huge}})))
end