


local url = "https://raw.githubusercontent.com/tekytek/ccgit/refs/heads/main/git.lua"

local path = shell.resolve("git.lua")

print "requesting"
local request = http.get(url)

local text = (request.readAll())
request.close()
print "writing"
local file = fs.open(path, "w")
file.write(text)
file.close()
print "done"
print "note that there are bugs in this git program."