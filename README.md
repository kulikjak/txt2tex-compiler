# txt2tex Compiler
Easy tool for compiling plain text documents to LaTeX source code.
* GitHub repo: https://github.com/Kulikjak/txt2tex-compiler

This tool is used (and was written) mainly for the compilation of meeting reports written in plain text into PDFs but it is pretty versatile and can be used for anything else.

### Installation
Simply download the shell script file.
If you want to use LaTeX compilation option you will have to download pdflatex.

### Usage
You can simply run the script as you downloaded it with txt file as the input.

If you don't like default settings, you can generate custom config file by running the script with `-g` flag. 
Generated configuration file has every possible option in it with its description (header images, auto LaTex compilation and so on).

If you have `config.txt` file in the same directory as your script, it will be automatically loaded and used. 
To use config with different name, run the script with `-c` option.

#### Input file format
File on the input must be in this format to work correctly:

First three lines are reserved for document title, date and number (in this order). You can use them for different purpose - this is just how I envisioned them ;). Each one of them can be ommited with blank line.

Document type parts can be switched with tags such as `**Term Events` or `**Main Meeting`. Names of tags can be changed in the configuration file. String after tag will be used for LaTeX section name. 

You can ommit `**Main` tag at the beginning of the document - it will be automaticly added with docuemnt title as section name.

Check example document for more informations about the format.
### Example
File translation with automatic pdfLaTeX compilation and sanitized output options.

    $> ./compiler.sh input.txt
    /usr/bin/texfot: invoking: pdflatex input.tex
    This is pdfTeX, Version 3.14159265-2.6-1.40.16 (TeX Live 2015/Debian) (preloaded format=pdflatex)
    Output written on input.pdf (3 pages, 75489 bytes).
    $> evince input.txt

You can find example plain text file, config file and resulting pdf in the example folder.

### Author
* Jakub Kulik, <kulikjak@gmail.com>
