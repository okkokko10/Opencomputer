---@class Database
---@field datafiles table<string,GenericDataFile>
local Database = {}

Database.__index = Database

---todo: a branch of the database, with its own writes that can be commited or rolled back.
---@class Transaction: Database
---@field datafiles table<string,CachedDataFile>
---@field database Database
local Transaction = {}
function Transaction:commit()
    for name, datafile in pairs(self.datafiles) do
        datafile:commit()
    end
    return self.database
end
function Transaction:rollback()
    for name, datafile in pairs(self.datafiles) do
        datafile:rollback()
    end

    -- todo: unimplemented
    return self.database
end

---creates a Transaction.
---@param database Database
---@return Database|Transaction
function Transaction.create(database)
    local datafiles = {}
    for name, datafile in pairs(database.datafiles) do
        datafiles[name] = datafile:branch()
    end
    local transaction = {
        database = database,
        commit = Transaction.commit,
        rollback = Transaction.rollback,
        datafiles = datafiles
    }

    return setmetatable(transaction, {__index = database})
end

function Database:beginTransaction()
    return Transaction.create(self)
end

return Database
