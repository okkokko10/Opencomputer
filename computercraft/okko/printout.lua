

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
        local oldprint = print
        oldprint("opening")
        local path = shell.resolve(name)
        local file = fs.open(path, "w")
        local write = file.write
        print = function (...)
            oldprint("|",...)
            if select("#",...) ~= 0 then
            file.write(select(1,...))
            for i = 2, select("#",...) do
                file.write(" " .. select(i,...))
            end
            end
            file.write("\n")
        end
        local epath = --shell.resolve
            (executable)
        oldprint("in main function ... is",...)

        oldprint("starting ", epath, "......")
        pcall(
            function (...)
            require(epath)
            oldprint"success"
            end,...
        )
        -- os.run({print=myprint},shell.resolve(executable),...)
        oldprint"closing..."
        file.close()
        oldprint"done"
    end


end

main(...)