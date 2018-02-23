#!/usr/bin/env ruby

def log(msg)
	STDERR.puts '[Debug] ' + msg if $debug
end

# Regex used to discard non-matching characters
if RUBY_VERSION < '2.4' then
	STDERR.puts '[Warning] You are running an old version of Ruby. Parsing files with non-english characters (Accents, Umlauts, Chinese characters, ...) might not produce useful results when not using --raw'
	$inputalphabet = /[^A-Za-zöäüß]/ #[:word:] for word characters does not work in old Ruby versions, use english alphabet + german umlauts as a fallback
else
	$inputalphabet = /[^[:word:]]/ # discard all non-word character
end

version = '1.3.2'
helptext = ['Usage:', 'ruby ttawc.rb [options] [dictionary] [input file]', 'If no input file is given, input data is read from STDIN', '',
			'Options:',
			'--raw (-r) Use raw input data with no sanitizing',
			'--include="cat0,cat1,..." Include only the given categories',
			'--exclude=\"cat0,cat1,...\" Include everything except the given categories',
			'--human Show human-readable output',
			'--percent (-p) Show output in percent of total words',
			'--sort (-s) Sort output by count (desc)',
			'--show-matching (-m) Show every word and the category it matches',
			'--verbose (-d) Show debug information',
			'--version (-v) Show version and exit',
			'--help (-h) Show this help and exit',
			'--format Show input and dict format help',
			''
		]

formattext = ['', 'tinyTAWC format help', '',
			'INPUT DATA',
			'In the default mode, the input file can be any plaintext file. Whitespace and linebreaks are ignored.',
			'',
			'DICT DATA',
			'Dict file format should be compatible with LIWC dict format. Every line of the dict file specifies a case-insensitive word rule with * as a wildcard for arbitrary characters.',
			'Alternatively, word rules can be specified as complete regular expressions (Ruby syntax, no whitespace, e.g. /wor(l)?d/ - modifiers like i, s or U can currently not be used).',
			'Word rules are followed by the categories they belong to, separated by a single tab character (or other whitespace). Trailing whitespace is ignored.',
			'Lines starting with a % are treated as single-line comments. Lines containing only a % start or end a multi-line comment block.',
			'TinyTAWC searches for category maps within multi-line comment blocks. Category maps are expected to consist of the category code, followed by arbitrary whitespace, followed by the human-readable category name, containing no whitespace.',
			'Note that only the first match for a word is counted. A dictionary containing the rules "word catA" and "word catB" will only count an occurence of \'word\' towards catA. Use "word catA catB" instead.',
			'',
			'OUTPUT DATA',
			'If --human is passed as an argument, TinyTAWC outputs a header row explaining the column values and one row for each category that matched at least one word.',
			'Row entries are separated by a single space character.',
			'In the default machine-readable mode, TinyTAWC output has the format "cat0:count0 cat1:count1 ..." where catn is the n-th category code and countn is the wordcount or percentage matching this category.', ''
		]

$sanitize = true
$debug = false
$human = false
$sort = false
$percent = false
$excluderules = false
$excluderegex = nil
$include = true
$showmatching = false

# Parse command line options
ARGV.each do|a|
	if a == '-d' or a == '--verbose' then
		$debug = true
	elsif a == '--human' then
		$human = true
	elsif a == '-p' or a == '--percent' then
		$percent = true
	elsif a == '-m' or a == '--show-matching' then
		$showmatching = true
	elsif a =~ /^--include=/ then
		$excluderules = true
		$excluderegex = Regexp.new('\A('+a[10...a.length].gsub(',', '|')+')\Z')
	elsif a =~ /^--exclude=/ then
		$excluderules = true
		$excluderegex = Regexp.new('\A('+a[10...a.length].gsub(',', '|')+')\Z')
		$include = false
	elsif a == '-s' or a == '--sort' then
		$sort = true
	elsif a == '-r' or a == '--raw' then
		$sanitize = false
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
		puts "Unknown option '"+a+"'"
		exit
	end
end

# Remove all options from ARGV
args = ARGV.select{ |a| (a[0] != 45 && a[0] != '-')} # 45 = "-", weird code to support Ruby 1.8.7

# Validate and open input files
if args == nil || args.length < 1 then
	puts 'No dictionary specified. Try --help for help.'
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
		puts 'Input file does not exist or is not readable'
		exit
	end
else
	puts 'Too many arguments'
	exit
end	

if File.exists?(dictpath) && File.readable?(dictpath)
	dict = File.open(dictpath)
else
	puts 'Dictionary does not exist or is not readable'
	exit
end

def numtohuman(number)
	if number < 1000
		return number.to_s
	elsif number < 1000000
		return ((number/100).round.to_f / 10).to_s + 'k'
	else
		return ((number/100000).round.to_f / 10).to_s + 'M'
	end
end

def parseRegex(string)
	if string =~ /^\/.*\/$/ then
		return Regexp.new(string[1...string.length-1])
	else
		return Regexp.new('^'+string.gsub(/\*/, '.*')+'$', Regexp::IGNORECASE)
	end
end

def count(text)
	result = {}
	words = ($sanitize ? text.gsub($inputalphabet, ' ') : text).gsub(/\s+/, ' ').split

	log('Found ' + words.length.to_s + ' words')
	log('Checking ' + numtohuman(words.length) + '*' + numtohuman($rulecount) + '=' + numtohuman(words.length * $rulecount) + ' rules, this may take a while')

	for word in words do

		if word.length < 1 then
			next
		end

		# Test rules until a matching one is found
		for rule in $regexes do
			if word =~ rule[:regex] then
				# Increment every matching category
				for category in rule[:categories] do
					puts word + ' matches ' + category if $showmatching
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
		result = result.map { |e| [e[0], (e[1].to_f / words.length)*100] }
	end

	result.push(['total', words.length])

	log('Done')
	return result
end

def generateOutput(data)

	result = ''

	if $sort then
		data.sort!{|a, b| b[1] <=> a[1]}
	end

	if $human then
		data.each { |elem| result += (elem[1] ? elem[1].to_s : '0') + ' ' + elem[0] + ($categories[elem[0]] ? ' ('+$categories[elem[0]]+')' : '') + "\n"}
	else
		data.each { |elem| result += elem[0] + ':' + (elem[1] ? elem[1].to_s : '0') + ' '}
	end

	return result;
end

lines = dict.readlines

mode = 'parseWords'
$categories = {}
$regexes = []
$catcount = 0
$rulecount = 0

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

result = generateOutput(count(datafile.read))

puts 'count | category | category name (if present)' if $human
puts result