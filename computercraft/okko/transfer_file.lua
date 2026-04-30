
local tf = {}

function tf.transfer_naive(from, to)
    to.write(from.readAll())
end

function tf.transfer(from, to)
    to.write(from.readAll())
end
