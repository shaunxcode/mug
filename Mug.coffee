#!/usr/bin/env coffee
fs = require "fs"
coffee = require "coffee-script"
T = require "node-term-ui"
_ = require "underscore"
_.mixin require "underscore.string"

StringStream = require "./modes/StringStream"

#this will be abstracted to load code mirror modes and add the wrapper
#automatically as well as keep a list of available modes and mime types
csmode = (require "./modes/coffeescript").modes.coffeescript indentUnit: 2, mode: {}

debugCounter = 0
_d = (args...) -> 
	true 
	#args.map (msg) -> fs.appendFile "dbug.log", "#{debugCounter++} #{msg}\n"
_j = (obj) -> JSON.stringify obj

[INC, DEC] = [1, -1]
MODE = insert: "INSERT", visual: "VISUAL"

class Editor
	theme:
		background: "#141414"
		foreground: "#f7f7f7"
		selected: "#323232"
		"gutters-background": "#222222"
		lineNumbers: "#aaaaaa"

		keyword: "#f9ee88"
		atom: "#FFCC00"
		number: "#CA7841"
		def: "#8DA6CE"
		variable: "#607392"
		"variable-2": "#607392"
		"variable-3": "#607392"
		property: "#000000"
		operator: "#CDA869"
		comment: "#777777"
		string: "#8F9D6A"
		"string-2": "#BD6B18"
		meta: "#f7f7f7"
		error: "#ff0000"
		qualifier: "#555555"
		builtin: "#CDA869"
		bracket: "#999977"
		tag: "#117700"
		attribute: "#D6BB6D"
		header: "#FF64))"
		quote: "#009900"
		hr: "#999999"
		link: "#0000cc"
		invalidchar: "#ff0000"
		matchingbracket: "#00ff00"
		nonmatchingbracket: "#ff2222"
		punctuation: "#CDA869"

	constructor: ->
		@commandHistory = []
		@commandHistoryPos = 0

		@row = 0
		@col = 0
		

		@mode = MODE.insert 
		@lines = [[]]

		#determine this from file extension/allow to set by command
		@textMode = csmode 
		@tabSize = 8

		@calcGutter()

		@scrollStart = 0
		@cursorRow = 1
		@cursorCol = @minCursorCol 

		@setupListeners()		
		T.clear()
		@drawScreen true

	calcGutter: ->
		@gutterWidth = (String @lines.length).length
		@minCursorCol = @gutterWidth + 2

		this

	validFile: (name) -> 
		return if not fs.existsSync name
		return if not fs.statSync(name).isFile()
		true

	loadFile: (name) ->
		if @validFile name		
			@filename = name 
			@lines = (line.split "" for line in (fs.readFileSync name, "utf-8").split("\n"))

		@calcGutter()
		@cursorCol = @minCursorCol
		@drawScreen true

	saveFile: ->
		fs.writeFileSync @filename, (line.join "" for line in @lines).join "\n"
		this

	quit: -> 
		T.quit()

	clearStyle: (row) -> 
		if @lines[row].style
			delete @lines[row].style
		this

	setStyle: (row) -> 
		styles = []
		curStyle = null
		curText = ""
		state = @textMode.startState()
		
		stream = new StringStream @lines[row].join(""), @tabSize

		if @lines[row].length is 0 and @textMode.blankLine?
			@textMode.blankLine state 

		while not stream.eol()
			style = @textMode.token stream, state
			substr = stream.current()
			stream.start = stream.pos
			if curStyle isnt style 
				if curStyle then styles.push [curStyle, curText] 
				curText = substr
				curStyle = style
			else
				curText += substr

		if curText.length
			styles.push [curStyle, curText]

		@lines[row].style = styles
		_d _j styles 

		this

	_renderRow: (row) ->
		if not @lines[row].style
			@setStyle row

		T.bg(T.C.r).fg(T.C.w).out((_.pad (String row + 1), @gutterWidth, " ") + " ")
			.bg(T.C.k).fg(T.C.g)
			.eraseToEnd()

		si = 0
		words = @lines[row].join("").split " "
		_d words
		_d @lines[row].style 
		
		for word, i in words 
			_d "SI #{si} #{word} #{@lines[row].style[si]?[1]}"
			if word is @lines[row].style[si]?[1] and hex = @theme[@lines[row].style[si][0]]
				_d "USE #{hex}"
				T.fgHex hex
				si++
			T.out word
			if i < words.length
				T.out " "
		this

	drawRow: (screenRow, row) -> 
		T.saveCursor().pos(1, screenRow).hideCursor()
			
		@_renderRow row

		T.restoreCursor().showCursor()
		
		this

	drawScreen: (draw = false) ->
		T.hideCursor()

		if @cursorRow > T.height - 1
			@cursorRow = T.height - 1
			@scrollStart++
			draw = true

		if @cursorRow < 1 
			@cursorRow = 1
			@scrollStart--
			draw = true
	
		if draw
			trow = 1
			for row in [@scrollStart..@scrollStart + T.height - 1] when @lines[row]
				T.pos 0, trow
				
				@_renderRow row

				trow++

		details = "(#{@col + 1}/#{@lines[@row].length}, #{@row + 1}/#{@lines.length}) [#{@mode}]"

		T.pos(0, T.height)
			.eraseLine()
			.pos(T.width - details.length, T.height)
			.out(details)
			.pos(@cursorCol, @cursorRow)
			.showCursor()
		
		this

	moveRow: (amt) ->
		if amt is INC and @row is @lines.length - 1
			@moveColRight()
			return 

		@row += amt
		@cursorRow += amt

		if amt is DEC and @row < 0 			
			@row = 0
			@cursorRow = 1
			@moveColLeft()

		if @col > 0
			@rememberCol = @col
			@moveColRight()

		if @rememberCol <= @lines[@row].length
			@col = @rememberCol
			@cursorCol = @col + @minCursorCol

		this

	moveCol: (amt) ->
		@col += amt
		@cursorCol += amt

		if amt is DEC and @cursorCol < @minCursorCol
			@moveColLeft()
		
		if @col > @lines[@row].length
			@moveColRight()

		this

	moveColLeft: -> 
		@col = 0
		@cursorCol = @minCursorCol
		this

	moveColRight: -> 
		@col = @lines[@row].length 
		@cursorCol = @col + @minCursorCol
		this

	setupListeners: ->
		T.on "resize", =>
			T.clear()
			@drawScreen true

		T.on "keypress", (char, key) => 
			draw = false

			key or= name: char 

			if @command
				switch key.name
					when "escape"
						@command = false 
						@commandPos = 0
						draw = true

					when "right"
						if @commandCol <= @command.length
							@commandCol++

					when "left"
						if @commandCol > 1
							@commandCol--

					when "up"
						_d "up history"

					when "down"
						_d "down history"

					when "backspace"
						if @commandCol > 1
							@commandCol--
							@command[@commandCol-1..] = @command[@commandCol..@command.length-1]

					when "enter"
						cmd = @command[1..-1].join("")
						cmdParts = cmd.split(" ")

						switch cmdParts[0]
							when "q", "quit"
								@quit()

							when "s", "save"
								@saveFile()

							when "sq", "wq"
								@saveFile().quit()

							when "sa", "saveAs"
								_d "save file as #{cmdParts[1]}"
							else
								try
									result = coffee.eval cmd, sandbox: doc: @
									@commandHistory.push @command
									@command = []
									@commandCol = 1
									@drawScreen true
									_d "RESULT", result
								catch e
									_d "EXCEPTION", e 

					else
						if char 
							@command[@commandCol-1..] = [char].concat @command[@commandCol-1..]
							@commandCol++

			else
				switch key.name
					when "right"
						@moveCol INC

					when "left"
						@moveCol DEC

					when "down"
						@moveRow INC

					when "up"
						@moveRow DEC

				if @mode is MODE.visual
					switch key.name
						when "i"
							@mode = MODE.insert
						
						when ":"
							@command = [":"]
							@commandCol = 2

						when "/"
							@command = ["/"]
							@commandCol = 2
						
						when ">"
							@command = ":do -> ".split ""
							@commandCol = @command.length + 1

				else
					switch key.name
						when "escape"
							@mode = MODE.visual

						when "backspace"
							if @col is 0 and @row > 0 
								@moveRow DEC 
								@moveColRight()

								@lines[@row][@col..] = @lines[@row + 1]
								@lines[@row+1..] = @lines[@row+2..]

								@clearStyle @row 
								draw = true
							else
								@moveCol DEC
								@lines[@row][@col..] = @lines[@row][@col+1..@lines[@row].length - 1]
								@clearStyle @row 
								@drawRow @cursorRow, @row 

						when "enter"
							newLine = @lines[@row][@col..]

							if @col is 0
								@lines[@row] = []
							else
								@lines[@row] = @lines[@row][0..@col - 1]
								@clearStyle @row
							
							@lines[@row+1..] = [newLine].concat @lines[@row+1..]
							
							@moveRow INC
							@calcGutter()
							@moveColLeft()

							draw = true

						else
							if char 
								@lines[@row][@col..] = [char].concat @lines[@row][@col..]
								@clearStyle @row 
								@drawRow @cursorRow, @row
								@moveCol INC
			
			if @command
				T.hideCursor()
					.pos(0, T.height)
					.eraseLine()
					.out(@command.join "")
					.pos(@commandCol, T.height)
					.showCursor()
			else	
				@drawScreen draw

		this

module.exports = Editor 