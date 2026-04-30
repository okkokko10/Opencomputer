

function main(name,executable,...)
    -- if string.match(name,"%f[^\\0]#")
    local hash_name = string.match(name,"^#(.*)$")
    if hash_name then
        local printer
        if hash_name == "find" then
            printer = peripheral.find("printer")
        else
            if peripheral.getType(hash_name) ~= "printer" then error("not a printer") end
            printer = peripheral.wrap(hash_name)
        end
        if not printer then error("no printer found") end
    else
        local path = shell.resolve(name)
        local file = fs.open(path, "w")
        local write
        print = function (...)
            if select("#",...) ~= 0 then
            write(select(1,...))
            for i = 2, select("#",...) do
                write(" " .. select(i,...))
            end
            end
            write("\n")
        end
        shell.run(executable,...)
        file.close()

    end


end

main(...)