

# crafting
- note how long a recipe takes and how much energy it consumes. (note, if a machine works faster than it recharges...)
- at first exact values of fluid, energy, tool consumption etc can be waived when writing a recipe. when it is performed these are updated.
- restock capability. Restock until ingredients are low.

# crafter robot
- according to a recipe, moves items in inventory to correct position
- handle instances where there's not enough space because the items are many



## Crafting UI
- click on an ingredient to show its recipe (it will be highlighted if you have one set.)



# inventory
- warns when inventory is full. shows slots
- aware of all chests in the area.
- maybe a sql-like structure.
- items in storage and items in other places 


# view of all items
- sort
  - sort by mod (or rather, alphabetically sort by the internal name)
- filter, also @ for mod
- click to fetch
- see items that have once been but have 0



# recipes
- has a machine
- also has a generic machine that does not lead anywhere.
- add a crafting table recipe by standing on top of one and calling a drone to look.
- read a recipe from a database upgrade. 
- command "retire" to disable a recipe


# bookmarked recipes
- see what you are missing to implement 


# machines
- can be configured as crafting stations.
- configure different chests as input or output inventories.
? how to treat machines with random output? a tag at least. the output inventory is tagged as a loot input.
- can become busy.
- a type of machine can have multiple instances.

# GUI
- show how much something is generated over time

# nicknames
- a command allows for nicknames. by default it is the internal name without the mod name.
- a nickname can be used as oredict later too.
- internally represented by its number and metadata, or something else that can be known from it.
- stored in a file, maybe in a csv format.

# history
- shows a history of what has been done.

# Drone
- tasked with fetching items, and registering inventories.
- remember to recharge.
- all parts can be listed.
- list inventory contents.
- can be given a route.
- locate by triangulating messages?
- seems like in init.lua you have to do: local m=component.proxy(component.list("modem")())




# Tablet
- mark all chest positions. 
- log a chest position twice to have it updated.
- log a position where a chest was to log it no longer existing.


# queue
there a queue for items being crafted. items have three main amount values: free, reserved, produced

# commands

fetch [-c --craft -r --recursive] itemname["/"..metadata] [amount (default 1)]
- brings items from storage
- tells how many are left, and how much can be crafted
- if insufficient, tell how many can be brought
[-a --amount] how many are left 
- craft tells what materials are going to be consumed, including energy, and time at a machine.
maybe "fetch" could be just one part
- -f --force

distribute x y z
pulls all items from the inventory there into the system





# Hologram
- can track the progress of things and show the base
- 



# Central pipe system
- instead of a drone making multiple trips, it puts its cargo into a nearby depot. then a signal is sent to Integrated Dynamics to send all depot contents to a depot near the drone's destination.








break the resolution limit by having multiple gpus connected to different screens

have a "in transit" inventory file
slots in inventories are marked reserved instead of empty while a transaction is happening
 - what circumstances?
  -   

drone control scheme: click a spot away from the current location on a map to choose x and z, and drag up or down to choose y
- have ability to choose the axes. inventories are stacked in a xy or zy plane anyway

request items on tablet with linked card to receive in ender pouch.
put the tablet itself in the pouch to have it recharged and returned.
put a travelers backpack in the pouch to have it emptied and 


send a drone squad and a geolyzer chunkloader robot with an ender chest to mine in other dimensions like midnight and cavern

periodically check external inventories
- isExternal could have multiple values. input external inventories shouldn't need to be checked

# orders
Orders list: contains conditions and instructions.
conditions like "these items can be found" and instructions like "move these items to this crafter and send a craft command.
instructions can have repeat amounts, up to math.huge.
-- item movement orders: put a specific item in a specific slot in an inventory, or in any slot in it.
-- empty a slot in an inventory and put the item in any other inventory
-- for recipes: empty all other slots in the inventory, and put these specific items there


when searching items, put them in a cart


# inventory lock

add and remove maximum
when starting removing items, add the amount to remove_max. when finishing, subtract it.
similarly adding and add_max.
orders that would increase remove_max above the amount currently commited, need to wait.
similarly, add_max+size cannot go above maxSize*sizeMultiplier
when an order to remove items causes the amount to be 0, there also needs to be 0 incoming items to that slot to mark it as empty.
- nevermind, if we just define "empty" as also 0 incoming items



packet size will be a problem. use ids for items
have all changes to the db stored, so that can be sent instead of the entire database everytime

a way to see what files need updating if there's multiple copies of the db. storageIO

query all drones and add them to the list of drones.

idea: all stored tables have a persistent=true tag?

relation?
Node(nodeid)( x, y, z, nodeparent FK)
Inventory(iid)( side, space, isExternal, sizeMultiplier, file, nodeid FK)
Item(itemid)(name, damage, label, hasTag, maxDamage, maxSize)
ItemSlot(iid FK, slot)(itemid FK, size, future_max, future_min)



a running DroneInstruction should be a thread.

each drone has a thread?


how to handle multiple bases? set up a "relay" ender chest


Special inventories where the move function itself is different. for example a detached system accessible through a relay chest: before you reserve a drone you have to send out an order to it.


graphics color palette
graphics color string

drone pool: add capability to shut down drones. drones: add capability to descend onto the ground when shutting down


todo: change .csv to .txt

todo: instead of immediately ordering items to be moved, add an order.



Items(iid, slot, uItem, size, added, removed)

Planned(uItem, producing, reserved)

todo: find items with any nbt

list all items used in recipes

GraphicsItem

todo: Story, an async coroutine with phases

poll Integrated Dynamics on the shape of shaped crafting recipes

New data structure for item storage:
```

amounts = amount, amount_adding, amount_removing



items = {
  ["minecraft"] = {
    ["wool"] = {
      [0]={
        maxSize = 64,

        amount = ?,
        amount_adding = ?, 
        amount_removing = ?,

        labels = {
          ["White Wool"] = { -- maybe this could be stored separately, since often it's not needed.
            ["abcdefghqwerty"] = {
              hasTag = false,

              nbt = ?,
              extra = ?,

              amount = ?,
              amount_adding = ?, 
              amount_removing = ?,

              stacks = {
                {iid, slot, amount, amount_adding, amount_removing}
              }
            }
          },
          
        }
      }
    },
    ["iron_pickaxe"] = {
      ["damage"] = {
        maxSize = 1,

        amount = ?,
        amount_adding = ?, 
        amount_removing = ?,

        labels = {
          ["Iron Pickaxe"] = {
            ["abcdefghqwerty"] = {
              hasTag = false,
              damage = ?,
              maxDamage = ?,

              nbt = ?,
              extra = ?,

              amount = ?,
              amount_adding = ?, 
              amount_removing = ?,

              stacks = {
                {iid, slot, amount, amount_adding, amount_removing}
              }
            }
          }
        }
      }
    }
  }
}

fluids = {
  ["xpjuice"] = {
    ["Liquid XP"] = {
      amounts = ?,

      stacks = {
        {fluidtank, slot, amount, amount_adding, amount_removing}
      }
    }
  }
}



byLabel = {
  ["White Wool"] = {
    {"minecraft","wool",0}, -- Item("minecraft","wool",0,"White Wool")
  }
}


Item:
  mod
  name
  meta?
  label?
  hash?
  iid?
  slot?
  
  =>

  maxSize
  hasTag
  damage
  maxDamage

  nbt -- if label and hash both have nbt, they are combined
  extra -- these have to be added manually. if these exist, the entry won't be removed even if amounts fall to 0

  amount = ?,
  amount_adding = ?, 
  amount_removing = ?,


rather:

Item_meta:
  mod, name, meta,
  amounts

Item_label:
  Item_meta,label,
  amounts,
  nbt, extra

Item_hash:
  Item_label,hash,
  amounts,
  nbt, extra,
  hasTag, damage, maxDamage, maxSize

Item_stack:
  Item_hash, {iid,slot},
  amounts

all of them are Item, and have a method to get their associations.
amounts is a sum of specific amounts'

ItemStackPortion:
  Item_stack, amount  -- an Item that refers to a part of a stack. For example inventoryhigh.find returns a list of these.


Item(mod,name,meta) -> Item_meta
Item(mod,name,meta,label) -> Item_label
Item(mod,name,meta,label,hash) -> Item_hash
Item(mod,name,meta,label,hash,{iid,slot}) -> Item_stack

Item.byLabel(label) -> Item_label

Items can be virtual, where they do not represent an item in the system. used in recipes.





fluids and oreDict could be
Item("fluid","fire_water",0,"Fire Water","",{fluidsystem,"fire_water Fire Water"})



```

items are arranged mod -> name -> meta(maxSize, amount...) -> label -> hash(hasTag,amount...) -> stack

does it even matter what items are in a certain inventory? maybe it's enough for an inventory to know whether a slot is empty.
so `(iid, slot) -> Item` does not need to be possible.


Ways to search items. 

by label, by part of a label.


item classes that don't care about certain values (should this be done? recipes shouldn't need oredict)





which is better, this
```
stacks = {
  {iid, slot, amount, amount_adding, amount_removing}
}
```
or this,
```
stacks = {
  [iid]={
    [slot]={amount, amount_adding, amount_removing}
  }
}
```
or this?
```
stacks = {
  ["{iid,slot}"]={amount, amount_adding, amount_removing}
}
```

maybe {iid,slot} could be generalized


todo: fluid carrying items contain extra information not captured.
todo: there is a previously missed inventory_controller.getAllStacks
todo: send drones code.

todo: integrated dynamics fluid system, possibly also inventory system.

todo: when an item is scanned, see if there is anything extra associated with it.
 when a silent's gems weapon, or any damaged tool, trash, is found, it is bunched with others like it.
 So, an item category can be made fuzzy, meaning all items that match its description have some of their data overwritten.
 Also, the item category and the level of obfuscation don't have to be the same.
  for example, "all items where meta (damage) is not 0, and maxDamage also is not 0" have their meta set to "damage". 


0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ,.-;:_"#(){}[]

faster placing items in crafty crates with integrated dynamics.
 sign: at index i is an encoded number n that tells what input slot n the item belonging to crafter slot i is in. 
integrated dynamics 
 parse sign text
 can IntDyn be programmed with text using reduce on a list of operators gotten from a string?
