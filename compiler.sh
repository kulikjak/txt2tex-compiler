#!/bin/bash

__debug=false   # true/false - show debug informations
__verbose=false # true/false - show additional informations during translation

script_location="$(dirname "$0")"   # location of this script
config_location="$script_location/config.txt"    # default linux like config location

forceconfig=false              # true/false - use configuration file

USAGE=$(cat <<USAGE
Usage:  $0 [-v] [-c config] file
        $0 [-hg]

        -v      verbose
        -c      specify config file
        -g      generate new config file
        -h      this help
USAGE
)

# default configuration values
typeset -A Options
Options[DocumentHeader]="Simple Document"
Options[DocumentDateFormat]="%d. %B %Y"
Options[DocumentShowDate]=false

# document tags
Options[TagMain]="Main"
Options[TagTerm]="Term"
Options[TagFooter]="Footer"

# tex package settings
Options[TexBabel]="czech"
Options[TexMargins]="top=2cm,bottom=4cm,left=2.5cm,right=2.5cm"

# boolean values for LaTeX compilation itself
Options[LatexCompile]=false
Options[LatexSanitizeOutput]=false
Options[LatexCleanAux]=false
Options[LatexCleanLog]=false
Options[LatexPreserveTexFile]=true


# ------------------------- # Functions # ------------------------- #

war() { echo "$0 [warning]: $@" >&2; }
err() { echo "$0 [error]: $@" >&2; exit 2; }

debug()   { $__debug && echo "$0 [debug]: $@" >&2; }
verbose() { $__verbose && echo "$0 [info]: $@" >&2; }

# print given associative array (requires debug mode)
print_array() {
   if $__debug; then
      debug $2
      for i in $(eval echo \${!$1[@]}); do
         echo " - $i: $( eval echo \${$1[$i]})"
      done
   fi;
}

# generates configuration file (pretty obvious)
generate_config() {
# compressed with $> gzip --best < config.txt | base64
local CONFIG_FILE=$(cat <<CONFIG_FILE
H4sIAFvKkFgCA6VUwY7TMBC9+ytGqiqBRKNtASGt1APdVYWgC2i7F46TZJJaTeLIHtPd/XrGSTdN
mwAS9JDa8+a9NzN2MoEbS8iUQvwEn3HvY/jiC71XE9igYyhNqjOdIGtTXcPiav5hdjWfvZ0rJRmz
8IMVOp3ArUl8SRWDI2Zd5e6ITkJiB+4IU7IhQhn6gq876FODwFaXdUFdVP0F7msXJjeypyiPuuBG
Yg0Q1VUu4FcDaescqNudOUD6wk/CIKRNSGUeYyWG9FvBIMPCkfpNuF/SmSRkxpbIY8qBvm5QmKYR
TFcw/aH+CJ7G35kx9oY+gYewFUtAz0bIUgVbrJxuCoqJD0RSmM4ysoHezaFGy071yxSpO9QVhIc6
21xkPZAtITzU2eYia20My1m2f2oQOLXG9AiZlvMeu1MbDHCMMRVScrLHnKDAKveyODOkx1WTlDxT
slMX204oJ1MS26dOq0Sb68pdSN21UWBTLxdJ+SY2LNNdvpNlQRkvF9F7WVqd745r9U+k0ww2KAKQ
mLLWRXuXejO4acIElpwUKBM6jeygedeS+x00vb6w2vs6Egqvhq9rUXXgGKsUbQrGc+0ZTDZS0ivv
juaZ4dcDwy1Wcuue6Vsr0fMdRYR/T6X5SRChP7aDWbghQ2ft5OJWNOyxIKw+BnavyfNYz0a+EP9h
swnsC5tTTDjfZZJkxag7ndZHcxD2Tr6+4UUd2A7sXoQkbx1k2Pqj6SjyCzTUFJLdBQAA
CONFIG_FILE
)
   if [ -f "$script_location/config.txt" ]; then
      printf "Configuration file already exists and will be overwritten.\n"
      printf "Do you want to continue? [Y/n] "
      read prompt
      [[ $prompt == "Y" || $prompt == "y" ]] || return 0
   fi

   echo "$CONFIG_FILE" | base64 -di | gunzip > "$script_location/config.txt"
   echo "Configuration file was successfully generated."
}

# creates LaTeX document header
document_header() {
echo "\documentclass[11pt, fleqn]{article}
\usepackage[${Options[TexMargins]}]{geometry}
\usepackage[${Options[TexBabel]}]{babel}

\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{enumitem}

\pagenumbering{arabic}
\setlength\headheight{68pt}

\usepackage{fancyhdr}
\newcommand{\customtitle}{$1}
\newcommand{\customdate}{$2}
\newcommand{\customnumber}{$3}
\newcommand\invisiblesection[1]{%
  \refstepcounter{section}%
  \addcontentsline{toc}{section}{\protect\numberline{\thesection}#1}%
  \sectionmark{#1}}
\setlist{nolistsep}"

# check if header image is set
[ -z "${Options[DocumentLogo]}" ] && echo "\lhead{}" || echo "\usepackage{graphicx}
\lhead{\includegraphics[width=1.6cm]{$script_location/${Options[DocumentLogo]}}}"

# check if document creation date should be displayed
if ${Options[DocumentShowDate]}; then
   curr_date=$(date +"${Options[DocumentDateFormat]}")
   echo "\rfoot{created: $curr_date}"
fi

# last part of the document header
echo "\chead{\centering\fontsize{12}{14}\selectfont \textbf{${Options[DocumentHeader]}}\\\\ \customtitle\\ \customnumber \vfill}
\rhead{\fontsize{8}{8}\selectfont\customdate}
\pagestyle{fancy}
\begin{document}"
}

# parser specific functions
handlelevel() { 
   while [ $1 -gt $_level ]; do
      echo "\begin{itemize}"
      let _level+=1
   done

   while [ $1 -lt $_level ]; do
      echo "\end{itemize}"
      let _level-=1
   done
}

# close current state
closestates() {
   [ "$_state" -eq 0 ] && handlelevel 0
   [ "$_state" -eq 1 ] && endterm 

   _substate=0
}

space() { [ "$_space" -eq 1 ] && echo "\vspace{5mm}" && _space=0; }
beginterm() { echo "\begin{description}"; echo "\setlength\itemsep{.3em}"; }
endterm() { echo "\end{description}"; }

# ------------------------- # Stage one: Lets load the prompt first # ------------------------- #

# load options from propt
while getopts c:gvh opt
do
   case "$opt" in
      v) __verbose=true;;
      c) config_location="$OPTARG"; forceconfig=true;;
      g) generate_config; exit 0;;
      h) echo "$USAGE"; exit 0;;
      \?) echo "$USAGE" >&2; exit 2;;
   esac
done
shift `expr $OPTIND - 1`

# load check input file and check it
[ $# -lt 1 ] && err "You have to specify atleast one input file"

file=$1

[ -f "$file" ] || err "'$file' is not a file"
[ -r "$file" ] || err "file '$file' is not readable"
[ -s "$file" ] || err "file '$file' is empty"

[ $# -gt 1 ] && war "The script will compile only the first file: '$file'"

debug "Prompt processing part done."

# ------------------------- # Stage two: Config file's awaiting # ------------------------- #

# check config file
if [ $forceconfig == false ]; then
   [ -f $config_location ] && forceconfig=true
else
   [ -f $config_location ] || err "Config file '$config_location' not found."
fi

# load configuration file if it should be loaded
if [ $forceconfig == true ]; then
   [ -r $config_location ] || err "Cannot read config file"
   [ -s $config_location ] || war "Config file is empty"

   # load entire config file inside its array
   typeset -A configOptions
   while read line; do
      if [[ "$line" =~ ^[^#].* ]]; then   # filtered comments
         name=$(echo $line | cut -d" " -f1)
         value=$(echo $line | sed -e "s/$name//" -e "s/^ //" -e 's/#.*//')

         [ ${configOptions[$name]} ] && war "Option '$name' is defined multiple times and it shouldn't..."
         configOptions[$name]=$value
      fi
   done < $config_location

   # merge all the options together
   configerror=false

   for item in ${!configOptions[@]}; do
      case $item in
         LatexCompile | LatexCleanAux | LatexCleanLog | LatexSanitizeOutput | LatexPreserveTexFile | DocumentShowDate)
            regexp='^true$|^false$'
            [[ ! ${configOptions[$item]} =~ $regexp ]] && { war "Option '$item' has wrong format."; configerror=true; } || Options[$item]=${configOptions[$item]} ;;
         DocumentDateFormat | DocumentHeader | TexBabel | TexMargins)
            Options[$item]=${configOptions[$item]} ;;
         TagMain | TagTerm | TagFooter )
            [ -z "${configOptions[$item]}" ] && { war "Tag name cannot be empty: '$item'."; configerror=true; continue; }
            Options[$item]=${configOptions[$item]} ;;
         DocumentLogo)
            [ -f "$script_location/${configOptions[$item]}" ] || { war "Logo file does not exist."; continue; }
            [ -r "$script_location/${configOptions[$item]}" ] || { war "Cannot read logo file."; continue; }
            Options[$item]=${configOptions[$item]} ;;
         *) war "Unknown config option: '$item'"; configerror=true ;;
      esac
   done

   if $configerror; then 
      war "There were problems with your config file. Wrong values were replaced with defauts."
      war "You can find correct and default values inside generated config file."
   fi

fi

debug "Config file processing part done"
print_array "Options" "Final Options:"

# ------------------------- # Stage three: Let's translate  # ------------------------- #

# variables for finite automaton simulation
_level=0    # indentation level
_state=-1   # state of finite automaton
_substate=0 # substates used by some states
_space=0    # delayed spaces (sometimes spaces from input file are not in the output)

# output file and stdout redirect
output=$( printf "%s.tex" ${file%.*} )
exec 6>&1 
exec > $output

# let's start parsing
while IFS='' read -r line || [[ -n "$line" ]]; do

   tabs=$(echo -e "$line" | awk '{print gsub(/\t/,"")}')
   line=`sed 's/\t//g' <<< $line`

   #escape special characters (& symbol)
   line=$(sed 's/&/\\&/g' <<< $line)

   # state changes based on selected keywords
   if [[ $line == \*\*${Options[TagMain]}* ]]; then

      # get text after main tag & use document title if there is no text
      line=$(echo "$line" | sed -e "s/\*\*${Options[TagMain]}//" -e "s/^ //" -e 's/#.*//')
      [ -z "$line" ] && line="$doc_title"

      closestates # close all previous states
      _state=0
      _space=0
      echo "\filbreak"
      echo "\section{$line}"
      continue

   elif [[ $line == \*\*${Options[TagTerm]}* ]]; then

      # get text after term tag & use document title if there is no text
      line=$(echo "$line" | sed -e "s/\*\*${Options[TagTerm]}//" -e "s/^ //" -e 's/#.*//')
      [ -z "$line" ] && line="Term"

      closestates
      _state=1
      _space=0
      echo "\filbreak\vspace{10mm}"
      echo "\section{$line}"
      beginterm
      continue

   elif [[ $line == \*\*${Options[TagFooter]}* ]]; then
   
      closestates
      _state=2
      _space=0

      echo
      echo "\invisiblesection{}"
      echo "\vspace{5mm}"
      continue
   fi

   #state (-1) - document header
   if [ "$_state" -eq -1 ]; then

      if [ "$_substate" -eq 0 ]; then
         doc_title=$line
         let _substate+=1
         continue

      elif [ "$_substate" -eq 1 ]; then
         doc_date=$line
         let _substate+=1
         continue

      elif [ "$_substate" -eq 2 ]; then
         doc_number=$line
         document_header "$doc_title" "$doc_date" "$doc_number"
         let _substate+=1
         continue

      # This will only happen if there is no tag right after the header.
      elif [ "$_substate" -eq 3 ]; then

         _state=0
         _space=0
         echo "\section{$doc_title}"
      fi
   fi

   # vertical spaces (new lines)
   [ -z "$line" ] && { space; _space=1; continue; }

   #state (0) - document body
   if [ "$_state" -eq 0 ]; then

      if [[ $line == -* ]]; then 
         space
         handlelevel $tabs
         line=$( sed 's/- /\\item /' <<< $line )
         echo "$line"
         continue
      fi

      handlelevel 0

      # first level indentation (subsection)
      if [[ $line == \** && $tabs == 0 ]]; then
         _space=0
         line=$( sed 's/*//g' <<< $line )
         echo "\filbreak"
         echo "\subsection{$line}"
         continue
      fi

      # second and further level indentation (subsection)
      if [[ $line == \** ]]; then
         _space=0
         line=$( sed 's/*//g' <<< $line )
         echo "\filbreak"
         printf "\sub"
         for (( c=0; c<$tabs; c++ )) do
            printf "sub"
         done
         printf "section{$line}\n"
         continue
      fi

      space

      # simple line
      #[ $tabs -eq 0 ] && echo "\noindent{$line}" || 
      echo "$line"
      echo

   #state (1) - document terms
   elif [ "$_state" -eq 1 ]; then
      
      # only text without any date
      if [[ $line == -* ]]; then
         space
         echo "\hfill\\\\ \hspace*{.1\textwidth} $line"
         continue
      fi

      if [[ $line =~ ^[0-9]+ ]]; then
         space
         echo $( sed 's/\([^ ]*\)/\\item[\1]/' <<< $line )
         continue
      fi

      #first=$( awk '{print $1;}' <<< $line)
      #if [[ $MONTHS == *$first* ]]; then
      #   space
      #   echo $( sed 's/\([^ ]*\)/\\item[\1]/' <<< $line )
      #   continue
      #fi

      if [[ $line =~ ^\* ]]; then
         space
         echo "\item[$(sed 's/^\*\(.*\)$/\1/' <<< $line)]"
         continue
      fi

      echo "\item $line"

   # state (2) - document footer (only simple lines)
   elif [ $_state -eq 2 ]; then
      space
      echo "\noindent{$line}"
      echo
   fi

done < "$file"

closestates
echo "\end{document}"

# restore original output (redirect back)
exec 1>&6 6>&- 

# ------------------------- # Stage four: The end # ------------------------- #

# compile resulting tex file with pdflatex
if ${Options[LatexCompile]}; then
   ${Options[LatexSanitizeOutput]} && texfot pdflatex "$output" || pdflatex "$output"
fi

# delete auxiliary files from LaTeX compilation
${Options[LatexCleanAux]} && rm "$( printf "%s.aux" ${output%.*} )"
${Options[LatexCleanLog]} && rm "$( printf "%s.log" ${output%.*} )"

# preserve tex file
${Options[LatexPreserveTexFile]} || rm "$output"
