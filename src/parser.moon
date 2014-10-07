fillArray = (filler, length) -> Array.apply(null, new Array(length)).map(-> fillter)

class Source
	constructor: (@str) =>
		@pos = 0

	consume: (length) =>
		part = @str.slice(@pos, @pos + length)
		@pos += length
		part
	peek: (length) => @str.slice(@pos, @pos + length)
	current: => @str.slice(@pos)

	clone: =>
		src = new Source
		src.initCopy(@)
		src

	initCopy: (parent) =>
		@str = parent.str
		@pos = parent.pos

M = (matcherGenerator) -> (args...) ->
	rawMatcher = matcherGenerator.apply(this, args)

	matcher = (src) -> rawMatcher.call(this, src)

	matcher.repeat = (args...) => @repeat(matcher, args...)
	matcher.then   = (args...) => @add(matcher, args...)
	matcher.or     = (args...) => @or(matcher, args...)
	matcher.map    = (fn) =>
		prevMatcher = rawMatcher
		rawMatcher = (src) =>
			match = prevMatcher.call(@, src)

			if match.matched
				match.result = fn(match.result...)

			match

		matcher

	matcher

--[===[Parser]===]
-- The base parser class, you generally don't need to extend this
-- Usage: new Parser([definition: function])
-- Example:
-- new Parser ->
-- 	@root = @R('\s').repeat()
class Parser
	constructor: (fn) -> fn?.call?(@)

	--[=[Parser::string]=]
	-- Aliases: str, S
	-- Matches a string
	string: (str) -> (src) =>
		if src.peek(str.length) == str
			src.consume(str.length)
			{
				matched: true
				consumed: str.length
				result: [str]
			}
		else
			matched: false

	--[=[Parser::regexp]=]
	-- Aliases: re, R
	-- Matches a regular expression
	regexp: (re) -> (src) =>
		re.lastIndex = 0
		match = re.exec(src.current())

		if match
			src.consume(match[0].length)
			{
				matched: true
				consumed: match[0].length
				result: match
			}
		else
			matched: false

	--[=[Parser::add]=]
	-- Aliases: A
	-- Combines a bunch of matchers into one
	-- For it to match all the matchers need to match one after another
	add: (matchers...) -> (src) =>
		results = []
		consumed = 0
		for matcher in matchers
			match = matcher(src)
			if match.matched
				# Ability to join results that contain a single string
				lastResult = results[results.length - 1]
				if lastResult? and lastResult.length == 1 and typeof(lastResult[0]) == 'string' and
				   match.result.length == 1 and typeof(match.result[0]) == 'string'
					lastResult[0] += match.result[0]
				else
					results.push(match.result)

				consumed += match.consumed
			else
				return { matched: false }

		{
			matched: true
			consumed: consumed
			result: results.map (input) ->
				if input? and input.length == 1
					input[0]
				else
					input
		}

	--[=[Parser::or]=]
	-- Aliases: O
	-- Ordered choice of the matchers
	-- TODO: Better description
	or: (matchers...) -> (src) =>
		for matcher in matchers
			match = matcher(src)

			if match.matched
				return match

		{ matched: false }

	--[=[Parser::repeat]=]
	-- Match a matcher at most, exactly or at least num times
	repeat: (matcher, num = 0, expansion = if num == 0 then 1 else 0) -> (src) =>
		results = []
		consumed = 0

		while true
			match = matcher(src)
			if match.matched
				if expansion < 0 and results.length >= num # Fail early if it gets too many matches
					return { matched: false }

				# Ability to join results that contain a single string
				lastResult = results[results.length - 1]
				if lastResult? and lastResult.length == 1 and typeof(lastResult[0]) == 'string' and
				   match.result.length == 1 and typeof(match.result[0]) == 'string'
					lastResult[0] += match.result[0]
				else
					results.push(match.result)

				consumed += match.consumed
			else if expansion >= 0 and results.length < num -- Fail early if it doesn't get enough matches
				return { matched: false }
			else
				break

		{
			matched: true
			consumed: consumed
			result: results.map (input) ->
				if input? and input.length == 1
					input[0]
				else
					input
		}

	-- Aliases
	O:   (a...) -> @or(a...)
	str: (a...) -> @string(a...)
	S:   (a...) -> @string(a...)
	re:  (a...) -> @regexp(a...)
	R:   (a...) -> @regexp(a...)
	A:   (a...) -> @add(a...)

-- Make the matcherGenerators generate proper matchers
-- Adds the repeat, then, or and map functions
for key, matcherGenerator of Parser::
	Parser::[key] = M matcherGenerator

parser = new Parser ->
	@blockBody   = @A(@S('if'), @S(' ').repeat(), @S('this'))
	-- @blockBody = @O(@S('if'), @S(' ').repeat())
	@root        = @blockBody

src = new Source('if this.works then print("it works") end')
-- src = new Source('   ')

console.log(parser.root(src))
console.log(src.current())