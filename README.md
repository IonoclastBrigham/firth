# :Firth

:Firth (n.) – a Forth-like language designed for DSL creation, implemented in Lua.

## Alpha Warning!
This code is incomplete, broken in places, and generally not ready for prime
time. I decided to make it available on Github because, why not?

## What's All This, Then?
I had previously created a forth-like language / parser / interpreter / virtual
machine / _thing_, and had a great time doing it. It was far more successful an
endeavor than I had dared to hope. Unfortunately, the project ended up growing
into an unmaintainable, convoluted mess, and it was thus abandoned.

So what went wrong? Well, for one, the project originally started out as an
extremely simple INI file reader for parsing static polygon definitions to be
rendered at runtime. Over successive iterations of refactoring it to be more
interactive, flexible, and turing-complete, it eventually became a full-fledged
stack-based language, with a compiler, virtual machine, and runtime library.

I blame the constant goading and "what if you..?" comments I received from my
friend Paul during development.

It grew into something it was never intended to be, and—lacking a sound
foundation—crumbled under the weight of this added complexity. That said, I do
still hold that the core ideas were sound and reasonable. Now, years later, I
am keen to take another go at it, coming into the experiment with both eyes open.
I learned a lot from that initial foray into forthitude, and have a lot of new
ideas about how to do things and how to make it an awesome language and
programming environment to work with.

We'll get into more details about what the language is, how it works, and what
to do with it as it develops.

## Building and Running
Currently, it is implemented completely in the LuaJIT dialect of Lua 5.1. This
means it has a few Lua 5.2-isms, and should generally run on PUC-Rio 5.2 as well.
It doesn't depend on any 3rd party libraries or C extensions. That said, it is
recommended to use [LuaJIT](http://luajit.org/), version 2.0.2 or later, for optimal performance.

You can require the libraries from Lua code, run the REPL from the command line,
or load the whole thing at runtime from the Lua API. Details to follow.

To build the Doxygen documentation, you need Perl 5 and the Doxygen::Lua
perl module (available on CPAN) installed on your system.

## Examples
The _examples_ directory is where to look for code that shows off the :Firth's
power and abilities. Currently, there is only iniloader.firth, and a sample input file.
You would run it from the :Firth REPL thusly:

```forth
" examples/iniloader.firth" loadfile
inifile: examples/test.ini
BLERG @ .
```

You should see output `127.0.0.1:8080 ok` if it all ran successfully

## License
Copyright © 2015 Brigham Toskin.
[MIT License](https://github.com/IonoclastBrigham/firth/blob/master/LICENSE).
