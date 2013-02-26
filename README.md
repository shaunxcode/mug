mug
===

coffeescript/ncurse based command line text editor which utilizes codemirror modes

#What?
Yeah basically vim but written in coffee with way less features! 

Right now you can edit and save files and issue some very basic commands.

You start in insert mode, pressing escape brings you back to visual mode. 

In visual mode 
	i visual mode
	: command
	> short cut for :do -> 
	/ regular expression
	s,save save file
	sa,saveAs save file as
	q,quit quit
	sq,wq save and quit
	esc exit command mode

When writing commands you have access to the entire Mug object via @doc. This is mainly useful for manipulating @doc.lines e.g. 

	:do -> @doc.lines = (line.map((c) -> c.toUpperCase()) for line in @doc.lines)

would upper case all of the lines in the document.

#TODO
add selecting of text/cut/copy/paste
add regex searching
show result of commands
plugin system 
code mirror syntax highlighting 
web server mode (starts express server for your project so you can do js fiddle style rapid dev)