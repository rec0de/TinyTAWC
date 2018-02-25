#!/usr/bin/env ruby

def log(msg)
	STDERR.puts '[Debug] ' + msg if $debug
end

def error(msg, warn = false)
	STDERR.puts( (warn ? '[Warning] ' : '[Error] ') + msg)
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

helptext = ['Usage:', 'ruby tools.rb [options] [mode] [input file/s]', 'If no input file is given, input data is read from STDIN', '',
			'Modes:',
			'clean Sanitizes the input file the same way TinyTAWC would',
			'combine Combine the given input files into a line-based one (Does not support STDIN)',
			'',
			'Options:',
			'--keeplines Keep linebreaks when cleaning',
			'--verbose (-d) Show debug information',
			'--help (-h) Show this help and exit',
			''
		]

$debug = false
$keeplines = false

# Parse command line options
ARGV.each do|a|
	if a == '-d' or a == '--verbose' then
		$debug = true
	elsif a == '--keeplines' then
		$keeplines = true
	elsif a == '-h' or a == '--help' then
		helptext.each{|line| puts line}
		exit
	elsif a == 'clean' then
		puts clean()
		exit
	elsif a == 'combine' then
		puts combine()
		exit
	elsif a[0] == '-' then
		error("Unknown option '"+a+"'")
		exit
	end
end