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
(Ruby syntax, no whitespace, e.g. `/wor(l)?d/` - modifiers i and x are supported but considered experimental).
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
If `--linebased` is passed as an option, every line in the input file is associated with an ID, which is the first word of the line. Lines with the same id are treated as belonging to the same dataset. Separate output will be generated for each ID. Whitespace other than linebreaks is still ignored.
### Output data 
If `--human` is passed as an argument, TinyTAWC outputs a header row explaining the column values and one row for each category that matched at least one word.
Row entries are separated by a single space character.  
If `--json` is passed, output is formatted as a JSON hashmap containing the categories as keys or, in line-based mode, a hashmap containing the IDs as keys and the regular output hashmap as a value.  
In the default machine-readable mode, TinyTAWC output has the format `cat0:count0 cat1:count1 ...` where catn is the n-th category code and countn is the wordcount or percentage matching this category.
In line-based mode, every line of output corresponds to one ID (format: `%id cat0:count0 ...`).  
Output data is sorted alphabetically by category by default or descending by match count if `--sort` is passed as an argument.

(For similar and perhaps more up-to-date info, use the `--format` option)

## Options & Usage
Basic usage: `ruby ttawc.rb [options] [dict file] [input file]`  
If no input file is given, STDIN will be used instead. All output is sent to STDOUT.  

Option|Description
---|---
`--raw (-r)`|Use raw input data with no sanitizing
`--linebased (-l)`|Treat lines in the input as separate datasets - see Input Data
`--include="cat0,cat1,..."`|Include only the given categories
`--exclude="cat0,cat1,..."`|Include everything except the given categories
`--human`|Show human-readable output (implies round=4)
`--json`|Show JSON-encoded output
`--percent (-p)`|Show output in percent of total words
`--round=n`|Round percentage values to n digits
`--sort (-s)`|Sort output by match count (descending)
`--show-matching (-m)`|Include every word and the category it matches in output
`--verbose (-d)`|Show debug information on STDERR
`--cachesize=NUM`|Set maximum number of words to keep in cache (default 10.000)
`--version (-v)`|Show version and exit
`--help (-h)`|Show help and exit
`--format`|Show input and dict format help

(For similar and perhaps more up-to-date info, use the `--help` option)

## Tools
TinyTAWC comes with a separate utility script called `tools.rb` to help with preparing and analyzing data.

### Cleaning
`ruby tools.rb clean [input file]` Reads the input file (or STDIN if no file is given) and performs the same cleaning that TinyTAWC would perform on input data in default mode. This creates single-line output without special characters and with normalized whitespace.  
If `--keeplines` is passed, linebreaks are not replaced.

### Combining
`ruby tools.rb combine [files]` Combines all input files into an output that can be processed by TinyTAWC in line-based mode. This includes cleaning and reducing the input to a single line. The filename is used as the dataset ID.

### Comparing
`ruby tools.rb compare [file]` Takes default-formatted TinyTAWC output (`%datasetID cat0:count0 ...`) and compares the dataset in the first line of the input file to every other line. Differences are calculated in percent point by default or percentage change if `--percent` is passed. This requires absolute - not relative - input data and exactly one dataset per line.  
If no input file is given, data is read from STDIN (which makes things like `ruby ttawc.rb -l dict.dic input | ruby tools.rb compare` possible).  
In addition to calculating differences between the datasets, the compare script performs a two-dimensional χ² test estimating the statistical significance of observed differences (χ² > 3.84 implies that the difference is significant on a p < 0.05 level).  
**Note that this may or may not be the correct way to test for significance in your usecase** - always double-check your results.

### Options
Option|Description
---|---
`--keeplines`|Keep linebreaks when cleaning (clean only)
`--percent (-p)`|Show differences in percent instead of percentage points (compare only)
`--round=n`|Round percentage values to n digits (compare only)
`--verbose (-d)`|Show debug information on STDERR
`--help (-h)`|Show help and exit