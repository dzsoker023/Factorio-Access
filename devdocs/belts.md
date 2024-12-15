<<<<<<< HEAD
--[[
Transport belt graph crawling and analysis.

This is long. That's because the official docs are weak here.

# Our Model

Before we get into what Factorio does, let's get into our model.  In our model,
each belt segment, splitter, etc. is a node in a graph.  At each node in this
graph, one may ask for:

- The parent belt entity.
- Any sideloading belt entities.
- The child belt entity.
- The contents of the belt segment if it is a belt or underground exit.
- The contents of the left or right side if it is a splitter.
- The contents of the underground belt part if it is an underground belt
  entrance.

Off this, we then implement a variety of heuristics.  Each node is a class-like
metatable (storage-safe, per usual), and on that are methods which can tell one
various heuristic things, for example "is this belt carrying something even
though the focused segment is empty".  This is all done by crawling the graph.
The heuristics which are available are documented on the methods--this comment
itself is already quite a lot.

This module exposes a function `node_from_entity` which  takes a belt
connectable entity and converts it to a node.  Note that calling it twice does
*not* return the same object.  Due to various API limitations and the like, we
can't do that conveniently so for now we don't.

To find out if two nodes are the same thing, call `is_same_node(other)` on the
node.  Under the hood, that's unit number comparisons.

Like with Factorio objects nodes may invalidate.  To check for this, use
`:valid()` like other Factorio objects, except in our case it's a function
because we have to check the underlying.  Nodes validate this: using an invalid
node crashes reliably.

# The Engine API

The engine separates things into transport lines.  Each line is what we call a
lane.  There is a defines.transport_line  which itslef documented, but the fact
of it going with get_transport_line isn't.  If on a given entity type, the
relevant defines there are always available.  The rules are as follows:

- For transport belts, the left and right lane get a line.
- For underground belt exits, we get a half-length line containing the contents,
  like it's a transportr belt but short, and a second set of lanes which seem to
  always be unused.
- For underground belt entrances, we get a half-length line for each incoming
  lane for the tile of the underground belt itself, then two more lanes whose
  length is the number of tiles underground.
- For splitters, we get 8 (!). Two each for the 2 inputs and 2 outputs.  That is
  4 incoming to process the input side, left/right/left/right, and then 4
  outgoing in the same way.
- For loaders, we get 2 like it's a belt.

All of the above are known as "belt connectable entities" in the official docs.
Belt connectable entities are entities which, when placed near belts, will join
up with each other to form the belt network.

LuaEntity has two fields: neighbours, and belt_neighbours.  If you are blind
note that neighbours is spelled with a u.  For everything but underground belts,
the belt_neighbours field shows us the neighbours.  For underground belts, one
must consult neighbours.  By consulting these two, it becomes possible to figure
out what's around the belt, but not to figure out the shape.

For the "shape", the first place we can look is belt_shape.  This tells us if it
is a corner.  That's the cheap version: if it's a corner we're done, there's no
sideloading going on.  For sideloading, we must infer that by looking at the
directions.  If a belt is going east and we have a north,  that is left
sideloading.  We can get this without tables with modulus tricks: in general at
this point it's probably safe to assume the engine won't add new directions, so
we'll always be at 16, and a shift is then +-4.  This is available in
geometry.lua.

There is an API on LuaTransportLine `input_lines` and `output_lines`.  Do not
use this without care.  They will skip until the line changes, e.g. they can go
50 or 100 belt entities before hitting a change.  There are two reasons one may
wish to play with this.  The first and simplest is that it does provide a veiw
of all sideloads on a long segment regardless of how far away they are.

The second reason brings us to splitters.  As mentioned above, the splitter has
8 lines.  It happens that these lines are given precise indexes and that the
inputs never move beyond the splitter's immediate parent.  That is, the input
side and output side of a splitter are both "walls" in the traversal.  This gets
rid of the need to do geometry.  Instead, we may ask for the inputs of the left
input line of the left side, and that'll always be the left input.

So, in conclusion the complex part is the recursion.  Once we have an entity and
the shape of it everything else is "assk the API".  All the complexity here then
shifts into the function which can let one recurse inputs and outputs, and then
the checks to make sure that loops aren't crawled indefinitely.
=======
Last reviewed: 2024-12-04

NOTE: this is what we believe to be true. It could be wrong.  If it turns out to
be, there's probably a mod bug but also this doc should be updated.

# Introduction

If you got this far you presumably know what transport belts are as a game
mechanic. This document servers two purposes: to document how the mod handles
them, and to document how the Factorio API works itself.

To briefly cover the approach from the player perspective, we detect corners,
sideloads, and "safe merges".  A safe merge meaning two sideloads into the
beginning of a belt, which merges two belts of one item into one belt of two
items.  We also detect and announce underground connections.

This by itself is insufficient.  To deal with that, we also offer the belt
analyzer.  The belt analyzer provides an abstracted view over the local belt as
well as statistics on upstream and downstream contents.  It provides a raw
direct look at the approximate 8 local slots (4 on each side), and aggregate
counts and relative percents for things up or downstream.

# The Factorio API

There is no direct abstraction of a single unit of transport belt in the
factorio API.  Instead, we have two things:

- On LuaEntity, we have information on the local shape.
- On LuaTransportLine, we have local information about the contents, plus mostly
  not useful to us information about the overall transport line.

To start with the most immediately important thing: a transport line (not the
lua object) is a merged set of belts.  The engine takes sets of belts without
sideloads or splitters and combines them for efficiency and (as of 2.0) allows
the circuit network to read the entire line.  That is to say that, from the
user's perspective, the transport line is the full sequence *including* belts
which have an incoming sideload.  The outgoing sideload stops rather than
merging; the items magically appear on the other lane instead.

This gets down to the biggest subtlety of the Lua API.  You might expect that
LuaTransportLine is this full line, but it isn't.  Instead, everything to do
with the contents is local to the entity, and everything to do with incoming and
outgoing lines is actually local to the whole line.  This means that it is not
enough to grab LuaTransportLine and crawl the graph.

To work around this we turn to LuaEntity.  Factorio calls everything which may
connect to a belt network a belt connectable.  For those entities,
`belt_neighbours` provides the information we need to crawl the graph.  There is
one special case: underground belts instead use `neighbours` instead.  That's
easily abstracted behind a function.  If you are blind note the spelling: this
is neighbours with a u.

All transport belts have two lines, one for the left and right lane
respectively.  Underground belts and splitters are special:

- Underground entrances have 4 lines. Two of them are the entire underground
  contents. The other two are half a tile for things entering the belt.
- Exits have 4 lines.  Two of them are the exiting contents.  The other two seem
  to be unused; we do not know why they are present as of this writing.
- Splitters have 8 lines.  It is entirely unclear which line does what, other
  than indexes 1, 3, 5, and 7 are left and 2, 4, 6, and 8 are right.  These seem
  to change function depending on the surrounding belts.

Lastly is belt shapes.  For transport belts, this is `belt_shape`.  For
underground belts this is `belt_to_ground_type`.  Belt corners and undergrounds
always face in the direction of travel.  It is the input direction which gets
tricky.  For example a left corner facing west has input coming from the south.


Finally, a brief note: as of 2.0 belt contents have unique ids.  This can be
used to tell if a belt has changed between ticks, e.g. "is moving".  An API
request was made for this but rejected because it is unclear what the engine
should interpret as "moving"; we will someday implement this ourselves.

# Our Implementation

We encapsulate our belt handling behind two abstractions, the node and the
function pair `get_parents` and `get_children`.  This is a "one clever trick"
scenario.

The parent/child nomenclature comes from the fact that 99% of working belt
setups are a directed acyclic graph, usually a full-on tree of some form.
parents are inputs, and children are outputs.  The reason we don't use
input/output is because there are subtleties: the biggest being that a belt may
be an indirect child of itself when inside a loop.

`get_children` isn't particularly special because children (outputs) are almost
exclusively singletons.  The only case they're not is a splitter.  We won't
cover that more here at this time.

`get_parents` is the clever trick.  It always and only returns 3 values.  This
allows putting them on the stack rather than intermediate tables, which is very
important for performance in Lua when doing heavy algorithmic work.  Though
normally a bad practice, belt stuff is heavy algorithmic work.  You write:

```
back, left, right = get_parents(entity)
```

and back, left, right are set appropriately.  This works out because the most
parents any belt connectable may have is 3: a belt with two sideloads.  In the
case of a splitter, it's 2, and in all other cases it's only one.  The
interpretations match the geometry.  If a belt has only one parent (e.g. is a
corner) and items are flowing along it uninterrupted, it has one parent.  If it
has sideloads it also gets a left/right.  The only one that's tricky is
splitters, for which back is never set: a splitter with one parent is left or
right depending.

You can then write `count3(back, left, right)` to find out how many parents a
belt has.  count3 is defined in transport-belts.lua, and like with get_parents
itself is about performance: variadic functions are expensive if at the Lua
level (they are much faster, even free, in the C API, but we aren't in the C
API).

This allows for writing the higher level construct, the node.  At this point the
belt code is stateless, and the node seems pointless.  It is tempting to remove
it.  But it exists for two very important reasons:

- Firstly, having a stateful hook where we can put more stuff is useful if we
  ever need to optimize; the nodes can be cached in global and we can start
  returning the same one for the same belt all the time, and then external code
  "magically" works.  The second reason is why we don't just put it behind
  functions:
- Belt movement is fundamentally stateful.  If we ever wish to do analysis of
  movement then we must track belts over at least one tick.  This is very
  important to have eventually, and we don't want to rewrite later.  Since
  having the node object in the middle is no cost save for a little bit of
  inconvenience, we do it now.


The one subtlety left is the splitter.  The belt APIs can return the splitters
parents.  In the case of 2, it's always returned from Factorio as `left, right`
in that order.  But in the case of one it comes back as an aray of one item with
no indication.  Initially the hope was that we could ask the splitter by asking
the lines what their inputs were.  Unfortunately, that's how we found out about
the aforementioned bugs/weirdnesses around splitters: as soon as one mixes belt
types the API starts returning nonsense.  Instead, we can use a trick.  Sine
Factorio's engine cannot have belts of more than one tile (e.g. mods cannot just
be like weee 2 tile wide belts) and because splitters are always 2, we get to
use geometry.  if we transform the positions of the parent belts into the local
coordinate system of the splitter such that positive y is the facing direction
of the splitter, we can use dot products to figure out which is which.  After
some mathematical rearrangement you end up with the math in `get_parents`, which
can do this without doing a full transform (you only need the x value, the y
value is a waste).

Before closing this out, a final note.  Our "transport line" as presented to the
user in the belt analyzer does see through splitters with single parents.  This
decision was made because it is not uncommon to have splitters to e.g. move
stuff off a bus, where the output goes both ways but the input is only one. This
is more useful for what the user needs to know than stopping at every splitter
especially in dense sets of them.

The rest of the magic is straightforward code in fa-info.lua that takes all of
this and turns it into words.
>>>>>>> test
