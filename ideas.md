

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

# TreeNode Items
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


TreeNode item
  needed uses:
    in recipes
    general virtual itemstack
    item with a slot in a recipe
    fuzzy, but with a slot in a recipe

  other representations
  Item("minecraft","name",0)
  Item(nil,"name") -- matches all with name "name"

  function "matching", which gets all items in a node that match a representation

  each layer should have its own metatable?

  items:matchingRecursive("%","%","%","%","%","%","1 52")
  -- gets the item in the slot "1 52"


TreeNodeClass
  items, mod, name, meta, label, hash, pos

How to represent recipes?

```
recipe
  0 -- recipe id
    "inputs" -- todo: a TreeNode structure that has attributes as children, which are different types of TreeNode?
      "minecraft"
        "wood_planks": 6
          "%"
            "%"
              "%": 6
                "cr 0": 1
                "cr 2": 1
                "cr 3": 1
                "cr 4": 1
                "cr 5": 1
                "cr 7": 1
        "iron_ingot": 1
          "%"
            "%"
              "%": 1
                "cr 1": 1
    "station"
      "crafting": 1
    "outputs"
      "minecraft"
        "shield": 1
          "%", "%", "%", "cr out" : 1
  1
    "station"
      "runicaltar": 1
    "inputs"
      "botania"
        "rune"
          "?"
            "Rune of Water"
              "%"
                "al": 1
            "Rune of Fire"
              "%"
                "al": 1


craftables
  "minecraft"
    "shield"
      "%"
        "%"
          "%"
            recipe.0


Items:
  (item mod...hash), pos  : sums

Recipes:
  Recipes_inputs:
    recipeID, (item mod...hash), recipePos : amount
  Recipes_station:
    recipeID, station
  Recipes_outputs:
    recipeID, (item mod...hash), recipePos : amount

Craftables:
  (item mod...hash), recipeID_FK
```




idea: "free mode", where changes to stored items won't be saved and crafting requests won't be sent out, and you can add ites freely, and recipes complete instantly. at the end, tracks what you have done, and makes a to-do list of it.

todo: writing "?" in a place like "%", will be replaced with the first value that fits, permanently.
    for example, writing in a recipe ("botania", "rune", "?", "Rune of Water"), the first time a rune labeled "Rune of Water" appears, the "?" in the recipe data is replaced with the appropriate value.
    -What happens when different items have a common "?" root?
  other special characters:
    one that means it is unknown, but does not make the category fuzzy

list of items should be separate from the storage system?
each node is referenced in a table containing sums?

adding ("silents","sword","&","&","&") creates a fuzzy branch.
todo: adding ("silents", "sword", "&", "%", "&") makes meta and hash fuzzy, but not label?

todo: make branch fuzzy afterwards.


Item(mod ... hash) : extra

Storage:
  Item, pos : sums



Items up to "label" should be stored in one file / in cache, and hashes and positions in another, each on their own line. those need only be accessed when moving items.


File structure:


A:

root-mod: 
  "minecraft": 0 (10,5,0), "botania": 1

mod-name:
  0-  "stone": 0, "planks": 1, "diamond_sword": 4
  1-  "rune": 2, "manaresource": 3

name-meta:
  0-  0: 0
  1-  0: 1
  2-  0: 2, 1: 3, 4: 4
  3-  2: 5
  4:  0: 6, "d": 7

meta-label:
  0-  "Stone": 0
  1-  "Oak Planks": 1
  2-  "Rune of Water": 2
  3-  "Rune of Fire": 3
  4-  "Rune of Spring": 4
  5-  "Mana Diamond": 5
  6-  "Diamond Sword": 6, "New Sword": 8
  7-  "Diamond Sword": 7, "Old Sword": 9

label-hash:
  0- "abcd": 0
  1- "abcd": 1
  2- "abcd": 2 
  3- "abcd": 3
  4- "abcd": 4
  5- "abcd": 5
  6- "efgh": 6, "xxxx": 10
  7- "efgh": 7
  8- "efgh": 8, "yxaw": 11
  9- "efgh": 9

hash-pos:
  0- "1 20": {20,1}






0 "botania"
1 "rune"
2 "0"
3 "Rune of Water"
2 "1"
3 "Rune of Fire"



Item("botania","rune",0): 1



Sql?


Idea: the data structure that stores which items are in what slots should have constant size (as long as inventories aren't connected), since it is expected that it will become dense.

Files:
  Uniques: all unique items. arbitrary data size. delimited by linebreak.
    accompanied by index = id.
    designed to be loaded to memory
    append-only (can be cleaned up, but this requires restructuring)
  UniqueIndex:
    constant memory size array.
    stores starting index of the item string in Uniques.
    
  Amounts: (system)
    constant memory size array.
    starting at byte i*size is the amount of the item with id=i
    buffered.
    only concerns total available amount.
  
  
  -- if it can be given that unique items have ids:
  ## slotdatabase

  Slots:
    constant memory size array.
    because it's designed to be dense, has a constant size, only affected by the number of slots, not how many are filled.
    (itemID, amount, prevSlot, nextSlot, containerHash)
    arrayfile.make(lpath,"itemID amount prev next containerHash","I3 I4 I3 I3 I1")
    containerHash is a 1-byte value that narrows down the container.
      Edit: it is now 2-byte, allowing for precise container identification.
    prevSlot and nextSlot point to the previous and next index in this array that stores this item. 
      it's a two-way linked list.
      they aren't necessarily sequential in the array.
      the top edge is stored for the item, for faster access.
        it could be that stacks are filled with this in mind.
      0 means it's the first/last
      air also has this. (air's itemID is 0)
    
      When a slot's item changes:
        -- note that "next" and "previous" are confusing. top is what doesn't have next.
        -- mend the connected slots together
        Stored[self.prevSlot].nextSlot = self.nextSlot
        if self.nextSlot == 0 then -- means this == itemOut.topSlot
          itemOut.topSlot = self.prevSlot
        else
          Stored[self.nextSlot].prevSlot = self.prevSlot
        end
        -- new item in. put it at the top of its linked list
        self.prevSlot = itemIn.topSlot
        self.nextSlot = 0
        Stored[itemIn.topSlot ( == new self.prevSlot) ].nextSlot = this
        itemIn.topSlot = this
        -- also the leaving item's total size is affected.
        self.itemID = itemIn.itemID
        self.amount = inAmount
    How should air be linked by default?
      the air topSlot should be the first index, its prevSlot the second index, and so on.
      when containers are added to the end of the array, they are full of air.
      so that newer containers get filled up last, they link to air's bottomSlot.
    Memory size:
      itemID 3-byte, amount 4-byte (could be 1-byte as it's usually max 64)
      next,previous: 3-byte
      containerHash: 2-byte
      in total 15-byte
      4-byte maximum uint is 4G
      3-byte is 16M. this means the file would be 15*16M = 240MB large if it needed more than 3 bytes for slot pointers
      One chest takes up 27*15 = 405 bytes.
      1MB can store 69_905 slots, == 2589 chests
    
    Order of values:
      values that are often updated together should be next to each other.
      amount and next should be neighbors, since when items are added to it that don't fit in the slot, they are placed in a new slot.


  TopSlots:
    constant memory size array.
    store edges of Stored linked lists.
  
  Containers:
    must be searched when deciding to move items.
    should be small.
    serialized.
    data:
      container id
      container stack multiplier
      start slot
      end slot (exclusive?) -- or size
      Location
      airID
    When moving items, searching containers with containerHash and start/end slot
    
  






In ram:
    arriving and leaving items are only stored in ram (or a serialized table)
      they are also just internal values
    reserved amount, ordered amount (in ram)
  








last time playing DH: 17.7.
DH unique items: < 19_000


Idea: set trash filtered unstackable items to be stored in a specified container without storing what they are


Idea: fluids, energy, other, are called AbstractItem
They are contained in AbstractContainer.
when an abstract container is empty, it does not contain air, but something else.
fluid storage grows dynamically? How to deal with? Permanently add a slot to Stored when needed?
Unmanaged drive's performance seems faster?
 inconclusive. if using multiple files, seeking while changing through them would be slow.


Hmm, rethinking Lock?


ItemHashes
1-bit modID hash, 
1-byte bitmask of the existence of letters in the name.
  abcd  8
  efgh  2
  ijkl  39
  mnop  40
  qrs   5
  tuvw  67
  xy z_ 1
  possibly do a calculation of what letters most often appear with other letters, and group them together.
1-byte sum of chars.
1-byte meta (does it need a whole bit?)
label letter 1-byte bitmask     -- the 0000 0000 might be underused. maybe items whose label is the same as their name? that might complicate calculation, though.
1-byte: itemdata hash first byte
6 bytes
meta's most significant bit could encode whether there's been a hash collision

todo: datafile editor
  includes jumping to foreign keys


mod "_custom" which contains remapped items.
mod "_empty" which contains all air items.
mod "_fluid"

todo: slots that only allow a specific item, not turning into air even with 0 items inside
  most significant bit of itemID?
  making it so it can be something other than the bottommost slot for the item might be challenging.

todo: add the corresponding air id to items/containers


How to represent external inventories in the new system?
  Currently isExternal is just a value in inventories. hmm?



some slots shouldn't just be filled in order. 
  slots with stack multipliers should only be used when needed.
  maybe an airID that allows the same items as normal air, but won't be automatically assigned to.


option for an item to be unstackable, but instead track its durability with its amount. 
  used for artisan tools
  denoted by 0 maxStack
  could apply to any unstackable item.

todo: slotdatabase translate slot to location+side+slot