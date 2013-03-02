countColumn = (string, end, tabSize) ->
  if end is null
    end = string.search /[^\s\u00a0]/
    if end is -1 
      end = string.length
  n = 0 
  for i in [0..end]
    if string.charAt(i) is "\t"
      n += tabSize - (n % tabSize)
    else
      ++n   
  return n

class StringStream 
  constructor: (@string, @tabSize = 8) ->
    @pos = @start = 0

  eol: -> @pos >= @string.length

  sol: -> @pos is 0

  peek: -> @string.charAt(@pos) or undefined
  
  next: ->
    if @pos < @string.length
      @string.charAt @pos++
  
  eat: (match) -> 
    ch = @string.charAt @pos
    if typeof match is "string" 
      ok = ch == match
    else 
      ok = ch and (if match.test then match.test(ch) else match(ch))

    if ok 
      ++this.pos
      return ch

  eatWhile: (match) -> 
    start = @pos
    while @eat match then continue
    @pos > start
  
  eatSpace: ->
    start = @pos
    while /[\s\u00a0]/.test(@string.charAt @pos) then ++@pos
    @pos > start
  
  skipToEnd: -> @pos = @string.length

  skipTo: (ch) -> 
    found = @string.indexOf ch, @pos
    if found > -1 
      @pos = found
      return true

  backUp: (n) -> @pos -= n

  column: -> countColumn @string, @start, @tabSize

  indentation: -> countColumn @string, null, @tabSize

  match: (pattern, consume, caseInsensitive) ->
    if typeof pattern is "string"
      cased = (str) -> if caseInsensitive then str.toLowerCase() else str

      if cased(@string).indexOf(cased(pattern), @pos) is @pos
        if consume isnt false then @pos += pattern.length
        return true
    else 
      match = @string.slice(@pos).match(pattern)
      if match and match.index > 0 then return null;
      if match and consume isnt false then this.pos += match[0].length
      return match

  current: -> @string.slice @start, @pos

module.exports = StringStream