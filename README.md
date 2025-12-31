# Buoy - Like vim marks for filesystem paths

## Description
The buoy program will create cross-session variables for filesystem paths. Buoys are more robust than environment variables, and don't clog the environment variable namespace.  By aliasing the provided buoy options to shorter names, use of repeated paths in shell operations can be made effortless.
Buoy provides little advantage over using traditional environment variables - it mostly exists to save a few seconds here and there, and for use cases that require use across terminal sessions and shutdowns.


The buoy table will run as a daemon, and will be updated and accessed by the following commands.

## Usage

[m]ake a buoy named 'a' to the current directory
```
$ buoy -m a 
```
  - You may also make a buoy to a path or file under the current directory by specifying the path after the buoy name ```$ buoy -m a file.txt```
  - Buoy names must only contain characters that meet the regex `^[a-zA-Z0-9,._+:%-]*$`.  That is, and character that is NOT a bash metacharacter, with the exception of `@` (the buoy dereference operator - more on this later) and `/` (as we allow filepaths to continue after dereferenced buoys and need to avoid ambiguity).


[e]xecute a command, substituting all buoys (dereferenced using @) for their paths
```
$ buoy -e cd @a
```
  - See [Avoiding Ambiguitiy](#avoiding-ambiguity) for more details on usage
  - You may also use filepaths in the subtree of a buoy by continuing after the buoy.  Note that bash does not know what buoys are, so autocomplete can't help you here ```$ buoy -e cat @a/file.txt```

<!--
[l]ist the buoy table to stdout
```
buoy -l
```
-->

Shortcut to quickly [c]d to a buoy.  No derefernce operator needed.
```
$ buoy -c a
```
  - Also works with directories in the subtree of a buoy ```buoy -c a/dir```


## Avoiding Ambiguity
Escaping characters gets a little dicey here - since we have to take in a command, modify it, and then eval the modified command, we have added a "layer of escaping" to bash's normal syntax.

Normally, there are two types of bash metacharacters: they are either escaped, or they are not.  For the sake of example, lets use the pipe `|` character.
 - [Normal] `...|...` - The pipe is executed by bash, the executing program never knows the pipe was there
 - [Escaped, Single Level] `...\|...` or `"...|..."` - The pipe character is passed as a string to the executing program.

This all is expected.  However, in interpreting and re-evlauting a shell expression, we have changed the game a bit.
 - [Normal] `...|...` - Same as above, buoy never knows the pipe is there
 - [Escaped, Single Level] `...\|...` or `"...|..."` - Now, buoy knows about the pipe, and will include it in the final command.  That is, **if you need to include bash metacharacters in your command passed into buoy -e, you need to escape them**.
 - [Meta-Escaped, Two Levels] `...\\|...` or `"...\|..."` or `"\"...|...\""` - If you want a bash metacharacter to appear as a string in your final output command, you will now need two levels of escape, since your command is now getting passed through shell expansion *twice*.
  - To simplify this, we have provided the syntactic shortcut `@@"...|..."` (when used at the beginning of a argument), which expands to `"\"...|...\""`, but is a lot cleaner.  This reserves the `@` buoy, hence why it is not allowed in buoy names

Note: Even though the buoy dereference operator `@` is not a bash metacharacter, it should be treated as such.  If you wish for `@` to appear as text in your final command, it should be Double/Meta-Escaped.  We recommend using `@@"...@..."` syntax for simplicity.

## Dependencies
This program uses systemd for daemonization.

The program is written in janet, and requires the janet / jpm to compile.  It depends on the sh and spork janet modules.

## Building

The makefile is configured to run the program, install in systemd, and add a function to evaluate output in current terminal. Run make for full setup. 
```
$ make
```

To just build binaries (and automatically install dependencies), run:
```
$ make exe
```

To daemonize using systemd (and configure to boot on startup), run:
```
$ make daemon
```

To add the bash wrapper to automatically eval output from the buoy-client, run:
```
$ make wrapper
```

To remove all installed files (this will not clear the managed section of your bashrc), run:
```
$ make clean
```

## Purpose
This program mostly exists for me to practice programming in janet-lang and daemonization.  There are much more apt ways to implement the described functionality.  However, in the case of this program, the structure will not be changing.

## Known bugs 
The first time you use `$ buoy -c @buoy` on a buoy, it does not do anything.

## Todo
- It would be nice to use janet-lang's C FFI to implement forking daemonization on machines not managed by systemd.
- Update / Uninstall scripts
 - Some way to remove the managed section of ~/.bashrc would be nice 

