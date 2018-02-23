# TinyTAWC
A simple script for text analysis using LIWC-compatible dictionaries

## Running TinyTAWC
Everything you need to run TinyTAWC is the ttawc.rb script and a version of Ruby installed on your computer.
The script _should_ be downward-compatible with Ruby 1.8.7 which means it can be run using the Ruby version pre-installed on MacOS.
To run the script and display usage help, open a terminal and run `ruby [location of ttawc.rb] --help`.

## File formats
### Dictionaries
Dict file format should be compatible with LIWC dict format.
Every line of the dict file specifies a case-insensitive word rule with * as a wildcard for arbitrary characters.
Alternatively, word rules can be specified as complete regular expressions
(Ruby syntax, no whitespace, e.g. `/wor(l)?d/` - modifiers like i, s or U can currently not be used).
Word rules are followed by the categories they belong to, separated by a single tab character (or other whitespace).
Trailing whitespace is ignored.
Lines starting with a % are treated as single-line comments. Lines containing only a % start or end a multi-line comment block.  
TinyTAWC searches for category maps (usually human readable names for short category codes) within multi-line comment blocks.
Category maps are expected to consist of the category code, followed by arbitrary whitespace, followed by the human-readable category name, containing no whitespace.  
Note that only the first match for a word is counted. A dictionary containing the rules "word catA" and "word catB" will only count an occurence of 'word' towards catA. Use "word catA catB" instead.
### Input data
In the default mode, the input file can be any plaintext file. Whitespace and linebreaks are ignored. Input is sanitized by replacing all non-word characters with whitespace, 
thereby parsing `hello|world thisis,tinyTAWC` as `'hello' 'world' 'thisis' 'tinyTAWC'` instead of `'hello|world' 'thisis,tinyTAWC'`.
If this is not what you want, use the `--raw` option to use unsanitized input. If you use an old Ruby version, word character matching might not be available.
In this case, TinyTAWC will print a warning message and fall back to replacing every non-english character (except german umlauts).
### Output data 
If `--human` is passed as an argument, TinyTAWC outputs a header row explaining the column values and one row for each category that matched at least one word.
Row entries are separated by a single space character.  
In the default machine-readable mode, TinyTAWC output has the format `cat0:count0 cat1:count1 ...` where catn is the n-th category code and countn is the wordcount or percentage matching this category.

(For similar and perhaps more up-to-date info, use the `--format` option)

## Options & Usage
Basic usage: `ruby ttawc.rb [options] [dict file] [input file]`  
If no input file is given, STDIN will be used instead. All output is sent to STDOUT.  

Option|Description
---|---
`--raw (-r)`|Use raw input data with no sanitizing  
`--include="cat0,cat1,..."`|Include only the given categories  
`--exclude="cat0,cat1,..."`|Include everything except the given categories  
`--human`|Show human-readable output  
`--percent (-p)`|Show output in percent of total words  
`--sort (-s)`|Sort output by match count (descending)  
`--show-matching (-m)`|Include every word and the category it matches in output  
`--verbose (-d)`|Show debug information on STDERR  
`--version (-v)`|Show version and exit  
`--help (-h)`|Show help and exit  
`--format`|Show input and dict format help  

(For similar and perhaps more up-to-date info, use the `--help` option)
