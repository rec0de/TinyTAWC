#!/usr/bin/env ruby
=begin
MIT License

Copyright (c) 2018 rec0de

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
=end

# log: string -> nil
# Logs a debug message to STDERR
def log(msg)
	STDERR.puts '[Debug] ' + msg if $debug
end

# error: string (, bool) -> nil
# Logs an error message to STDERR if no warn parameter is passed or a warning if warn is true
def error(msg, warn = false)
	STDERR.puts((warn ? '[Warning] ' : '[Error] ') + msg)
end

# round: float, integer -> float
# rounds to x significant digits - doesn't round for digits < 0
def round(num, digits)
	return num if digits < 0

	return ((num*(10**digits)).round).to_f / 10**digits
end
version = '1.4.4'
helptext = ['Usage:', 'ruby ttawc.rb [options] [dictionary] [input file]', 'If no input file is given, input data is read from STDIN', '',
			'Options:',
			'--raw (-r) Use raw input data with no sanitizing',
			'--linebased (-l) Treat lines in the input as potentially separate datasets. See --format',
			'--include="cat0,cat1,..." Include only the given categories',
			'--exclude="cat0,cat1,..." Include everything except the given categories',
			'--human Show human-readable output (implies round=4 by default)',
			'--json Show JSON-formatted output',
			'--percent (-p) Show output in percent of total words',
			'--round=n Round percent values to n significant digits',
			'--sort (-s) Sort output by count (desc)',
			'--show-matching (-m) Show every word and the category it matches',
			'--verbose (-d) Show debug information',
			'--cachesize=NUM Set maximum number of words to keep in cache (default 10.000)',
			'--version (-v) Show version and exit',
			'--help (-h) Show this help and exit',
			'--format Show input and dict format help',
			''
		]

formattext = ['', 'tinyTAWC format help', '',
			'INPUT DATA',
			'In the default mode, the input file can be any plaintext file. Whitespace and linebreaks are ignored.',
			'If --linebased is passed as an option, every line in the input file is associated with an id, which is the first word of the line.',
			'Lines with the same id are treated as belonging to the same dataset. Separate output will be generated for each id.',
			'Whitespace other than linebreaks is still ignored.',
			'',
			'DICT DATA',
			'Dict file format should be compatible with LIWC dict format. Every line of the dict file specifies a case-insensitive word rule with * as a wildcard for arbitrary characters.',
			'Alternatively, word rules can be specified as complete regular expressions (Ruby syntax, no whitespace, e.g. /wor(l)?d/ - i and x modifiers are supported but considered experimental).',
			'Word rules are followed by the categories they belong to, separated by a single tab character (or other whitespace). Trailing whitespace is ignored.',
			'Lines starting with a % are treated as single-line comments. Lines containing only a % start or end a multi-line comment block.',
			'TinyTAWC searches for category maps within multi-line comment blocks. Category maps are expected to consist of the category code, followed by arbitrary whitespace, followed by the human-readable category name, containing no whitespace.',
			'Note that only the first match for a word is counted. A dictionary containing the rules "word catA" and "word catB" will only count an occurence of \'word\' towards catA. Use "word catA catB" instead.',
			'',
			'OUTPUT DATA',
			'If --human is passed as an argument, TinyTAWC outputs a header row explaining the column values and one row for each category that matched at least one word.',
			'Row entries are separated by a single space character. Note that human readable percentages are rounded to 4 significant digits by default.',
			'If --json is passed, output is formatted as a JSON hashmap containing the categories as keys or, in line-based mode, a hashmap containing the IDs as keys and the regular output hashmap as a value.',
			'In the default machine-readable mode, TinyTAWC output has the format "cat0:count0 cat1:count1 ..." where catn is the n-th category code and countn is the wordcount or percentage matching this category.',
			'In line-based mode, every line of output corresponds to one id (format: "%id cat0:count0 ...").',
			'Output data is sorted alphabetically by category by default or descending by match count if --sort is passed as an argument.', ''
		]

$sanitize = true
$debug = false
$human = false
$json = false
$sort = false
$percent = false
$excluderules = false
$excluderegex = nil
$include = true
$showmatching = false
$maxcache = 10000 # Maximum number of cached words
$linebased = false
$round = -1 # Default to no rounding

# Parse command line options
ARGV.each do|a|
	if a == '-d' or a == '--verbose' then
		$debug = true
	elsif a == '--human' then
		$human = true
		$round = $round > -1 ? $round : 4 # Human mode implies some rounding if not otherwise specified
	elsif a == '--json' then
		$json = true
	elsif a == '-p' or a == '--percent' then
		$percent = true
	elsif a =~ /^--round=/ then
		$round = a[8..-1].to_i
	elsif a == '-m' or a == '--show-matching' then
		$showmatching = true
	elsif a == '-s' or a == '--sort' then
		$sort = true
	elsif a == '-r' or a == '--raw' then
		$sanitize = false
	elsif a == '-l' or a == '--linebased' then
		$linebased = true
	elsif a =~ /^--include=/ then
		$excluderules = true
		$excluderegex = Regexp.new('\A('+a[10...a.length].gsub(',', '|')+')\Z')
	elsif a =~ /^--exclude=/ then
		$excluderules = true
		$excluderegex = Regexp.new('\A('+a[10...a.length].gsub(',', '|')+')\Z')
		$include = false
	elsif a =~ /^--cachesize=/ then
		$maxcache = a[12...a.length].to_i
	elsif a == '-v' or a == '--version' then
		puts 'tinyTAWC v'+version+' - Always sanity-check your results. Try --help for help.'
		exit
	elsif a == '-h' or a == '--help' then
		helptext.each{|line| puts line}
		exit
	elsif a == '--format' then
		formattext.each{|line| puts line}
		exit
	elsif a[0] == '-' then
		error('Unknown option \''+a+'\'')
		exit
	end
end

# Regex used to discard non-matching characters
if RUBY_VERSION < '2.0' then
	error('You are running an old version of Ruby. Parsing files with non-english characters (Accents, Umlauts, Chinese characters, ...) might not produce useful results when not using --raw', true)
	$inputalphabet = /[^A-Za-zöäüß]/ #[:word:] for word characters does not work in old Ruby versions, use english alphabet + german umlauts as a fallback
else
	$inputalphabet = Regexp.new('[^[:word:]]') # discard all non-word characters
end

# Remove all options from ARGV
args = ARGV.select{ |a| (a[0] != 45 && a[0] != '-')} # 45 = "-", weird code to support Ruby 1.8.7

# Validate and open input files
if args == nil || args.length < 1 then
	error('No dictionary specified. Try --help for help.')
	exit
elsif args.length == 1 then
	dictpath = args[0]
	sample = 'STDIN'
	datafile = STDIN
elsif args.length == 2 then
	dictpath = args[0]
	sample = args[1]
	if File.exists?(sample) && File.readable?(sample)
		datafile = File.open(sample)
	else
		error('Input file does not exist or is not readable')
		exit
	end
else
	error('Too many arguments')
	exit
end	

if File.exists?(dictpath) && File.readable?(dictpath)
	dict = File.open(dictpath)
else
	error('Dictionary does not exist or is not readable')
	exit
end

# numtohuman: number -> string
# Converts a (big) number to a more human-readable representation (1000 -> 1.0k)
def numtohuman(number)
	if number < 1000
		return number.to_s
	elsif number < 1000000
		return ((number/100).round.to_f / 10).to_s + 'k'
	else
		return ((number/100000).round.to_f / 10).to_s + 'M'
	end
end

# parseRegex: string -> regexp
# Parses a string as a regular expression. If the string is not surrounded by slashes,
# 	the string is interpreted as a literal match with * as a wildcard equivalent to .*
# 	Otherwise, the string is parsed as a normal regular expression delimited by forward slashes
def parseRegex(string)
	if string =~ /^\/.*\// then
		opt = nil
		string.gsub(/.*\//, '').split('').each{|c|
			if c == 'i' or c == 'x' then
				toadd = (c == 'i') ? Regexp::IGNORECASE : Regexp::EXTENDED
				opt = opt ? opt | toadd : toadd
			end
		}

		string.gsub!(/\/[a-z]*\Z/, '') # Remove trailing options and slash

		return Regexp.new(string[1..-1], opt)
	else
		return Regexp.new('\A'+string.gsub(/\*/, '.*')+'\Z', Regexp::IGNORECASE)
	end
end

# count: string -> array of (array of string, number)
# Counts how many words in the input match which category
def count(text)
	result = {}
	cachehits = 0
	words = ($sanitize ? text.gsub($inputalphabet, ' ').gsub(/[0-9]/, ' ') : text).gsub(/\s+/, ' ').split

	log('Found ' + words.length.to_s + ' words')
	log('Checking ' + numtohuman(words.length) + '*' + numtohuman($rulecount) + '=' + numtohuman(words.length * $rulecount) + ' rules, this may take a while')

	for word in words do

		if word.length < 1 then
			next
		end

		# Remove one element from cache if cache is full
		if $cache.length >= $maxcache then
			$cache.delete_if{|key, value| (not $cache_performance[key]) || $cache_performance[key] < $cache_minhits} # Delete every cache entry that has not been used often enough
			if $cache.length >= ($maxcache - $maxcache * 0.3) then # If less than 30% of cache entries have been removed, increment threshold for keeping values in cache
				$cache_minhits += 1
			end
		end

		# Shortcut if word is in cache
		if $cache[word] then
			cachehits += 1
			$cache_performance[word] = $cache_performance[word] ? $cache_performance[word] + 1 : 1
			# Increment every matching category
			$cache[word].each{|cat|
				puts word + ' ~= ' + cat if $showmatching
				result[cat] = result[cat] ? result[cat]+1 : 1
			}
			next
		end

		# Test rules until a matching one is found
		$cache[word] = [] # Assume no rule matches the word and cache that. If a rule does match, the cache is overwritten
		for rule in $regexes do
			if word =~ rule[:regex] then
				$cache[word] = rule[:categories] # Save word categories in cache
				# Increment every matching category
				for category in rule[:categories] do
					puts word + ' ~= ' + category if $showmatching
					if result[category] then
						result[category] += 1
					else
						result[category] = 1
					end
				end
				break
			end
		end
	end

	result = result.to_a

	if $percent then
		result = result.map { |e| [e[0], round((e[1].to_f / words.length)*100, $round)] }
	end

	result.push(['total', words.length])

	log('Done - Cached: ' + (((cachehits.to_f / words.length)*1000).round.to_f / 10).to_s + '%')
	return result
end

# generateOutput: array of (array of string, number) -> string
# Converts [category, count] data to a human- or machine-readable format
def generateOutput(data)
	result = ''

	if $sort then
		data.sort!{|a, b| b[1] <=> a[1]}
	else
		data.sort!{|a, b| a[0] <=> b[0]}
	end

	if $human then
		data.each { |elem| result += (elem[1] ? elem[1].to_s : '0') + ($percent ? '% ' : ' ') + elem[0] + ($categories[elem[0]] ? ' ('+$categories[elem[0]]+')' : '') + "\n"}
	elsif $json then
		result = '{'
		data.each { |elem| result += '"' + elem[0] + '":' + (elem[1] ? elem[1].to_s : '0') + ','}
		result[result.length-1] = '}'
	else
		data.each { |elem| result += elem[0] + ':' + (elem[1] ? elem[1].to_s : '0') + ' '}
	end

	return result;
end

# combineOutputs: array of (array of string, (array of string, number))
# Combines the output created by generateOutput for multiple different texts
def combineOutputs(data)
	result = $json ? '{' : ''
	data.each{|id|
		if $human then
			result += '---- ' + id[0] + " ----\n" + id[1]
		elsif $json then
			result += '"' + id[0] + '":' + id[1] + ','
		else
			result += '%' + id[0] + ' ' + id[1] + "\n"
		end
	}

	if $json then
		result[result.length-1] = '}'
	end

	return result;
end

lines = dict.readlines

mode = 'parseWords'
$categories = {}
$regexes = []
$catcount = 0
$rulecount = 0
$cache = {}
$cache_performance = {}
$cache_minhits = 1

log('Starting')
log('Dict file: "'+dictpath+'"')
log('Input file: "'+sample+'"')

for line in lines do

	clean = line.gsub(/\s+\n/, '').chomp
	clean = clean.gsub(/(\s+)/, ' ')

	# Parse categories
	if mode == 'parsingCategories' && clean != '%' then
		parts = clean.split
		$categories[parts[0]] = parts[1]
		$catcount += 1;
	elsif mode == 'parsingCategories' then
		mode = 'parseWords'
		log('Parsed ' + $catcount.to_s + ' categories')
		log('Parsing rules...')
	elsif mode == 'parseWords' then
		if clean == '%' then
			log('Found start of comment section - possible category definition?')
			mode = 'parsingCategories'
		elsif clean[0] == '%' then
			next # Skip commented lines
		elsif(clean.length > 0) then
			parts = clean.split
			regex = parts.shift

			# keep only matching categories
			if $excluderules then
				parts = parts.select{ |cat| ((cat =~ $excluderegex)!=nil) == $include}
				next if parts.length < 1
			end

			element = {:regex => parseRegex(regex), :categories => parts}
			$regexes.push(element)
			$rulecount += 1
		end
	end

end

log('Parsed ' + $rulecount.to_s + ' word rules')
log('Analyzing input file')

if not $linebased then
	result = generateOutput(count(datafile.read))
else
	lines = datafile.readlines
	outputs = {}
	ids = {}

	log('Grouping ' + numtohuman(lines.length) + ' lines by id, this may take a while')
	lines.each{|l|
		words = l.split
		if words.length > 1 then
			entry = words[1...words.length].join(' ') 
			ids[words[0]] = ids[words[0]] ? (ids[words[0]] + ' ' + entry) : entry
		end
	}

	for id in ids.to_a do
		log('Processing id "' + id[0] + '"')
		outputs[id[0]] = generateOutput(count(id[1]))
	end
	
	result = combineOutputs(outputs.to_a)
end

puts 'count | category | category name (if present)' if $human
puts result