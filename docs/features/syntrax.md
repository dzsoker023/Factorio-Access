# Syntrax

## Introduction

Note: Syntrax errors are not very helpful. We know, but this cannot be improved in a reasonable amount of effort.

Syntrax is a language for taking what you would do with the virtual train builder and writing it down. It also adds some
capabilities needed for train power users.  It can represent repeated patterns of the same structure and provides tools
to talk about layouts with other people.  Syntrax is designed so that knowing the virtual train is enough to run it in
your head, but it is nonetheless a programming language.  If you aren't a programmer, you can still make use of this by
getting Syntrax strings from others and saving them in your save as custom items in the train builder menu.

If you have not yet used trains, please instead start with the [virtual train](./rails.md) and the other information in
that document.  Syntrax will be very confusing otherwise.

Syntrax consists of:

- Basic things that directly correspond to placing rails and signals
- A mark/reset command pair for simple bookmarking
- rpush and rpop, for a more complex stack of rails
- syntaxes for repetition

This document covers all of these.

One notable thing missing from Syntrax are standard loops and control structures.  If you are coming from another
language, you will not find them here.  All Syntrax programs execute in a finite (if possibly very large) number of
steps.

You also won't find support for stations or schedules here.  To do those, you do them in game yourself. What Syntrax can
do is lay out the rails for you.  Station support is somewhat planned, but schedules are outside the purview of Syntrax
because of things such as schedule groups for which there is no clear way to map.  Other text-based formats for things
might appear in future depending on demand and available contributor bandwidth.

## Basic Commands and Syntax

A Syntrax program consists of some number of words and brackets separated by whitespace (space and newlines). For
example, `s s s` places 3 straight rails.  Whitespace is always required, save for as explained below in the chord
section.

Syntrax supports block comments `/* comment */` which can appear anywhere in the code.

The following commands do what the virtual train would do and correspond to virtual train keys:

- l, for left
- s, for straight
- r, for right
- f, for flip, also available  as flip
- sigleft, sigright: place normal signals to the left and/or right of the virtual train
- chainleft, chainright: place chain signals to the left/right of the virtual train

The following are some basic structures that Syntrax adds which do not have a key equivalent:

- l90, r90: left/right 90-degree turns. (no space between the letter and number, equivalent to `l x 4` and r x 4`).
- l45, r45: 45-degree left and right turns (equivalent to `l x 2` and `r x 2`).
- chain: pair of chain signals
- sig: pair of regular signals

## Repetitions

A repetition is expressed in one of two forms:

- `word x number` runs word number times, but may only be used with a restricted list of words as explained below.
- `[words here] x number` runs the bracketed program number times.

There is whitespace between the word/program, the x, and the number.

For example, `s x 5` is 5 straight, and `[l l] x 2` is l90, or 4 lefts.

Repetitions nest. So, `[l x 2] x 2` is `l x 4`.

Right now, you cannot write a repetition in the un-bracketed form after all commands, only after some.  The commands
which support this are l, s, r, l45, r45, l90, r90.

Syntrax does not particularly care in general which words are repeated and how. A syntrax program is expanded to have no
brackets and no repetitions, then run.  That is to say, something like `[flip] x 4` is entirely valid though useless.
Other more advanced constructs however can be useful.

## Chords, or how to type without spaces

Syntrax is primarily a language for typing, not reading.  It would be annoying if you had to type spaces all the time.
For that reason, Syntrax supports chords.  A chord is a sequence of words without spaces.

Only some words can be in a chord.  These are the basic l, s, r, their 45 and 90 degree variants, f, m, u, d, x, and ;.
In a chord f cannot be spelled flip, m cannot be spelled mark, u and d cannot be spelled up and down, and ; cannot be
spelled reset (see below for reset). Bracketed subprograms cannot be in a chord.

Note that heavy use of chords renders your program nearly unreadable.  The reason these exist is because one of the two
most common uses of Syntrax is typing little fragments into the game.  Use chords with caution.

## Mark and Reset, or how to make forks

Syntrax offers two facilities for "going back".  The first is mark and reset, which is the simpler of the two and
convenient for common things like "a straight line with branches off it here and there".

- Mark records the current rail end until the next time a mark command runs. It is important to remember this does
  include the way the virtual train is facing.
- Reset goes back to the last mark, but does not clear it.

You can think of mark like "I am done here, we can move on".  Some examples should make this clear.  This is a simple
fork:

```
l90 reset r90 reset s x 4
```

This is two forks, stacked:

```
l90 reset r90 reset s x 4
mark
l90 reset r90 reset s x 4
```

Reset can be spelled `;`.  In this form (and *not* as the full word), it can be used in chords. So, we can also write:

```
l90;r90;sx4
mark
l90;r90;sx4
```

As previously stated, Syntrax does not care what is repeated. So, we can also do:

```
[
   l90;r90;sx4
   mark
] x 2
```

Which is the same program, just with an extra mark at the end that does nothing.

You can then of course do `x 10` or so on.

## the rail stack: repetition for advanced users

NOTE: the key word is advanced. If you are just getting started you probably don't need or want this. This facility is
for coders trying to have at least a bit of organization, and not about typing fast or anything.

The problem with mark and reset is that they have side effects.  You can't take a mark/reset sequence and paste it
somewhere else inside another program, because the outer program might be using mark and reset too.

To this end we offer the rail stack.  This is exactly what it sounds like and rpush/rpop do exactly what you think. They
are also more powerful, in the sense that you can rpush 5 times and rpop 5 times later if you want, and so on.

The sequence `rpush program rpop` is *almost* the same as the sequence `mark program reset` except that it does not
break if program itself contains more rpush/rpop, as long as the inner progranm runs a balanced number (e.g. 2 rpush and
2 rpop).

This is roughly the same as the bookmark keys.  Mark and reset don't map to the bookmark keys because the simpler model
in text goes quite far, and having a full stack on the keyboard is important.  SO we map the keyboard to rpush and rpop,
instead.

To know which one you want think of it like this:

- mark/reset: "I am done here forever, forget about it"
- rpush/rpop: "I am done with this substructure but may need to get to the wider thing again".

Syntrax does not care if your program ends with a matched number of rpush or rpop.  It also does not care if they are
matched inside brackets.  `[ rpush ] x 5 rpop` is a valid program for instance (all be it one that places nothing).

## Elevated rails

With Space Age (or the elevated rails mod) Syntrax can build bridges. You need the elevated rails research and a rail
planner that can build elevated rails, which the normal rail item can.

- up, or u: place a ramp from the current end up to the elevated layer. Everything after it is elevated.
- down, or d: place a ramp from the current end down to the ground.
- elev: a ramp to the other layer, whichever that is. up and down are easier to read later, so prefer them.
- sup: place a rail support at the current end. Only on elevated rails, and only at ends facing one of the 8 main
  directions (not the half-diagonal ends in the middle of a curve).

Ramps can only start from an end facing north, east, south or west, and you cannot put two ramps in a row. A ramp is as
long as 8 straight rails. Signals cannot go on a ramp itself; put a rail after it first. Signals placed on the elevated
layer are placed on the bridge, not on the ground below.

You normally do not need sup. Syntrax works out where supports go and adds them for you, using as few as it can: the top
of a ramp holds 4 straight rails, and a support holds 5 straight rails on each side, so a bridge can have up to 9 rails
after a ramp before the first support and up to 10 rails between supports. When the bridge ends in a ramp (or in a
support you placed), the supports Syntrax adds are spread evenly between the two ends, so `up s x 10 down` gets one
support in the middle with 5 rails on each side. When the bridge just stops, the last support goes as far ahead as it
can, so it is useful when you carry on building later. A support you place with sup is used, and Syntrax only adds more
where it is still needed. If Syntrax cannot find a place for a support, it reports the rail that cannot be held and
builds nothing.

Two more words give you control over the planner:

- nosup: no support at the current end. Syntrax puts the support it would have placed here somewhere else, for
  example because something else will be built on that spot later.
- autosup off, autosup on: from here on, Syntrax adds no supports of its own (or does again). It still checks that every
  elevated rail is held, by a ramp or by a support you placed with sup, and reports the first rail that is not held
  instead of building anything.

For example, `up autosup off s x 6 sup s x 6 down` builds a bridge with exactly the one support you wrote.

Mark, reset, rpush and rpop remember the layer too, so `up s x 6 mark l45 s x 4 reset r45 s x 4` forks on the bridge,
and a reset back to a mark on the ground puts you back on the ground.

Examples:

- `up s x 10 down`: a bridge with 10 rails between the ramps. Syntrax adds one support.
- `usx20d`: the same as `up s x 20 down`, typed as a chord.
- `up s x 4 sup s x 5 sup s x 4 down`: supports exactly where you want them.

A ground rail and an elevated rail can be at the same place, one under the other, so Syntrax builds both if a program
goes over the same spot on both layers.
