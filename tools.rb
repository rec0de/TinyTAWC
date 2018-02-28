#!/usr/bin/env ruby

def log(msg)
	STDERR.puts '[Debug] ' + msg if $debug
end

def error(msg, warn = false)
	STDERR.puts( (warn ? '[Warning] ' : '[Error] ') + msg)
end

# rounds to x significant digits - doesn't round for digits < 0
def round(num, digits)
	return num if digits < 0

	return ((num*(10**digits)).round).to_f / 10**digits
end

def sanitize(text)
	# Regex used to discard non-matching characters
	if RUBY_VERSION < '2.3' then
		error('You are running an old version of Ruby. Parsing files with non-english characters (Accents, Umlauts, Chinese characters, ...) might not produce useful results when not using --raw', true)
		inputalphabet = /[^A-Za-zöäüß]/ #[:word:] for word characters does not work in old Ruby versions, use english alphabet + german umlauts as a fallback
	else
		inputalphabet = Regexp.new('[^[:word:]]') # discard all non-word characters
	end
		
	return text.gsub(inputalphabet, ' ').gsub(/[0-9]/, ' ').gsub(/\s+/, ' ')
end

def sanitize_lines(lines)
	# Regex used to discard non-matching characters
	if RUBY_VERSION < '2.3' then
		error('You are running an old version of Ruby. Parsing files with non-english characters (Accents, Umlauts, Chinese characters, ...) might not produce useful results when not using --raw', true)
		inputalphabet = /[^A-Za-zöäüß]/ #[:word:] for word characters does not work in old Ruby versions, use english alphabet + german umlauts as a fallback
	else
		inputalphabet = Regexp.new('[^[:word:]]') # discard all non-word characters
	end
		
	return lines.map{|line| line.gsub(inputalphabet, ' ').gsub(/[0-9]/, ' ').gsub(/\s+/, ' ')}
end

def clean()
	# Remove all options from ARGV
	args = ARGV.select{ |a| (a[0] != 45 && a[0] != '-')} # 45 = "-", weird code to support Ruby 1.8.7

	if args.length == 1 then
		data = STDIN.readlines()
	elsif args.length == 2 then
		if File.exists?(args[1]) && File.readable?(args[1])
			data = File.readlines(args[1])
		else
			error('Input file does not exist or is not readable')
			exit
		end
	else
		error('Too many arguments - clean expects one input file or STDIN')
		exit
	end

	return $keeplines ? sanitize_lines(data) : sanitize(data.join(' '))
end

def combine()
	result = ''

	# Remove all options from ARGV and remove first argument
	args = ARGV.select{ |a| (a[0] != 45 && a[0] != '-')} # 45 = "-", weird code to support Ruby 1.8.7
	args = args[1...args.length]

	args.each{|path|
		if File.exists?(path) && File.readable?(path)
			result += path.gsub(/(.*\/|.*\\|\s)/, '') + ' ' + sanitize(File.read(path)) + "\n"
		else
			error('Input file does not exist or is not readable')
			exit
		end
	}

	return result
end

def compare()
	# Remove all options from ARGV
	args = ARGV.select{ |a| (a[0] != 45 && a[0] != '-')} # 45 = "-", weird code to support Ruby 1.8.7

	if args.length == 1 then
		data = STDIN.readlines()
	elsif args.length == 2 then
		if File.exists?(args[1]) && File.readable?(args[1])
			data = File.readlines(args[1])
		else
			error('Input file does not exist or is not readable')
			exit
		end
	else
		error('Too many arguments - combine expects one input file or STDIN')
		exit
	end

	parsed = []
	relativewarn = false # Only warn once when detecting relative input data

	data.each{|line|

		# Every line should start with %id indicating a TTAWC output line
		if line[0] != '%' then
			error('Input file seems corrupted - compare expects TTAWC default format output in separate lines')
			exit
		end

		temp = {}
		parts = line.split
		temp['ttawc-id'] = parts[0][1..-1] # Save the id name
		# Build a hashmap of the current input line
		parts[1..-1].each{|part|
			subparts = part.split(':')

			# If the key data is non-integer, compare is most likely being used on percentage data
			# (which is bad)
			if subparts[1].to_f != subparts[1].to_i and not relativewarn then
				error('It seems the input data is in percent. Comparing most likely won\'t work (and will produce inaccurate data)', true)
				relativewarn = true # Don't warn again
			end
			temp[subparts[0]] = subparts[1].to_f
		}
		parsed.push(temp)
	}

	master = parsed[0]
	diff = {}

	for id in parsed[1..-1] do
		temp = {}
		catname = nil
		# Build a new hashmap containing differences and confidence values 
		id.each{|cat, value|
			if cat == 'ttawc-id' then
				catname = value
			else
				master[cat] = (master[cat] ? master[cat] : 0)
				cat_total = value + master[cat]
				total_total = master['total'] + id['total']

				# Calculate expected values based on average distribution
				expected_id = (cat_total.to_f / total_total) * id['total']
				expected_master = (cat_total.to_f / total_total) * master['total']

				# Disclaimer: I know nothing about statistics and chi² tests
				# chi² = sum((observedValue - expectedValue)^2 / observedValue)
				chisquare = ((value-expected_id)**2)/value + ((master[cat]-expected_master)**2)/master[cat]
				chisquare += (((id['total']-value)-(id['total']-expected_id))**2)/(id['total'] - value)
				chisquare += (((master['total']-master[cat])-(master['total']-expected_master))**2)/(master['total'] - master[cat])

				# Separate values for PercentagePoint and Percent mode
				pp_diff = (cat == 'total') ? (value - master[cat]) : ((value/id['total']) - (master[cat]/master['total']))*100
				percent_diff = (cat == 'total') ? ((value - master[cat])/master[cat])*100 : (((value/id['total']) - (master[cat]/master['total']))/(master[cat]/master['total']))*100

				temp[cat] = {:diff => ($percent ? percent_diff : pp_diff), :confidence => (cat == 'total' ? 0 : chisquare)}
			end
			diff[catname] = temp
		}
	end

	puts 'Comparing ' + (parsed.length - 1).to_s + ' datasets to master "' + master['ttawc-id'] + '"'
	puts '---- Master ----'
	master.each{|key, value|
		next if key == 'ttawc-id'
		puts '"' + key + '": ' + (key == 'total' ? value.to_s : round((value/master['total'])*100, $round).to_s + '%')
	}

	diff.each{|name, comparison|
		puts '---- ' + name + ' ----'
		comparison.each{|key, value|
			next if key == 'ttawc-id'
			change = (value[:diff] > 0 ? '+' : '') + round(value[:diff], $round).to_s + ($percent ? '%' : key == 'total' ? '' : 'pp')
			puts '"' + key + '": ' + change + ' (chi²=' + round(value[:confidence], 2).to_s + ')'
		}
	}

	error('Statistics are tricky. Always sanity-check what you\'re doing', true)

end

helptext = ['Usage:', 'ruby tools.rb [options] [mode] [input file/s]', 'If no input file is given, input data is read from STDIN', '',
			'Modes:',
			'clean Sanitizes the input file the same way TinyTAWC would',
			'combine Combine the given input files into a line-based one (Does not support STDIN)',
			'compare Compares a list of TinyTAWC outputs to one master output and calculates chi² values',
			'',
			'Options:',
			'--keeplines Keep linebreaks when cleaning',
			'--round=3 Round numeric values to e.g. 3 significant digits',
			'--percent Show comparison differences in percent as opposed to percentage points',
			'--verbose (-d) Show debug information',
			'--help (-h) Show this help and exit',
			''
		]

$debug = false
$keeplines = false
$percent = false
$round = -1

# Parse command line options
ARGV.each do|a|
	if a == '-d' or a == '--verbose' then
		$debug = true
	elsif a == '--keeplines' then
		$keeplines = true
	elsif a == '--percent' then
		$percent = true
	elsif a =~ /^--round=/ then
		$round = a[8..-1].to_i
	elsif a == '-h' or a == '--help' then
		helptext.each{|line| puts line}
		exit
	elsif a == 'clean' then
		puts clean()
		exit
	elsif a == 'combine' then
		puts combine()
		exit
	elsif a == 'compare' then
		compare()
		exit
	elsif a[0] == '-' then
		error("Unknown option '"+a+"'")
		exit
	end
end