#!/usr/bin/perl                # <= Adapt if needed


###################################################
#
# Sample Usage:
#
# Call the program with no parameters to get the
# help function. Alternatively, use the -man
# parameter to have the help shown as manual.
#
# Configuration:
#
# For adding your own regular expression, look at
# the %parser definition further down this file.
#
###################################################

use strict;
use warnings;

binmode STDOUT, ":utf8";
use utf8;
use Config::Simple;
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use Data::Dumper;
use RTF::TEXT::Converter;
use XML::LibXML;
use Tie::IxHash;
use Term::ANSIColor qw( colored );

my $cfg;
my $config;
my @projects = ();
my $dontparse;
my $debug;
my $man = 0;
my $help = 0;
my $documentation = 0;
my $list          = 0;
my $all           = 0;
my @showid        = 0;
my $search        = "";

my $itemlevel   = 0;  # for itemizes: level; 0, 1 or 2
my $currentitem = ""; # current bullet kind: "", "m" or "t"



#
# If we have a configuration file set, we use that
# as to drive ourselves, i.e. we assume we'll find
# more information in there as to which projects to
# parse, in which order, and to which destination,
# and what to do with that destination.
#
# This essentially creates a wrapper around texdown.
#
if ($cfg) {
  runFromCfg (@ARGV);
} else {
  #
  # Decide which processing ot use: STDIN or files
  #
  if (-t STDIN) {
    if (@ARGV > 0) {
      runOnFiles (@ARGV);
    } else {
      pod2usage(2);
    }
  } else {
    runAsFilter();
  }
}



#
# runFromCfg
#
# Run from a configuration file
#
sub runFromCfg {
  my ($dir, $file) = (@_);

  if (! -f $cfg) {
    pod2usage({ -message => "\nConfiguration file $cfg not found\n" ,
                -exitval => 2,
              });
  }

  #
  # If we did not specify a project, let's attempt to
  # resolve it.
  #
  if (@projects == 0) {
    my ($d, $f, $p) = resolveFiles("$dir");

    $projects[0] = $p;
  }

  #
  # Capture current project and empty
  # out $projects - we are going to
  # read the projects from the configuration
  # file now.
  #
  my @back = @projects;
  @projects=();

  #
  # If we had been given a configuration file, make sure
  # we also have got a scrivx file.
  #
  if (!$file) {
    ($dir, $file) = resolveFiles("$dir");
  }

  foreach my $curproj (@back) {
    #
    # Initialize the Configuration File
    #
    $config = new Config::Simple($cfg);

    my $pr = cfg($curproj, "p");

    if (ref($pr) eq 'ARRAY') {
      @projects = @$pr;
    } else {
      $projects[0] = $pr;
    }

    parseScrivener($dir, $file);
  }

  #
  # Restore the projects
  #
  @projects = @back;
}



#
# runOnFiles
#
# Do the processing on files
# from the command line
#
# arguments: The files to parse
#
sub runOnFiles {
  foreach (@ARGV) {
    if (-e "$_" || -e "$_.scriv") {
      my ($dir, $file, $project) = resolveFiles($_);

      if (defined($project) && $project ne "") {
        #
        # Scrivener
        #

        #
        # Option 1:
        #
        # - Indirect project definition by configuration file...
        # - ...but don't even say, which configuration file to use
        # - ...or even, which project to use from that file
        #
        # If we don't have a project, as a fallback, we default
        # to the $fname, and if we do have a $fname.cfg, and the
        # cfg option was not set on the command line, we
        # default to it using the $fname as project to run.
        #
        # This is invoked e.g. like so:
        #
        # ./texdown.pl Dissertation -l -c
        #
        # We are hence working on Dissertation.scriv, but we are
        # not even saying which project we want to run, and neither
        # are we saying which configuration file we want to use. We
        # just say that we want to use a configuration file. In this
        # case, the program will assume Dissertation.cfg as
        # configuration file, and also, Dissertation as project.
        #
        if (@projects == 0) {
          $projects[0] = $project;

          if (defined($cfg)) {
            if (-f "$dir/../$project.cfg") {
              $cfg = "$dir/../$project.cfg";
              runFromCfg($dir, $file);

              next;
            }
          }
        }


        #
        # Option 2:
        #
        # - Indirect project definition by configuration file...
        # - ...but don't even say, which configuration file to use
        # - yet at least, we say which project(s) to use
        #
        # If we did have projects, and cfg set, but empty,
        # we still try to find a default configuration,
        # rather than running on the projects ourselves
        #
        # This is invoked e.g. like so:
        #
        # ./texdown.pl Dissertation -l -c -p roilr
        #
        # We are hence working on the Dissertation.scriv,
        # and we are saying we want to use a configuration
        # file, without specifying its name. Hence the
        # program will attempt to use Dissertation.cfg.
        # We also said that we want to use a given project
        # that's defined in the configuration file, in this
        # case roilr.
        #
        if (@projects > 0 && defined($cfg) && $cfg eq "") {
          if (-f "$dir/../$project.cfg") {
            $cfg = "$dir/../$project.cfg";
            runFromCfg($dir, $file);

            next;
          }
        }

        #
        # This is the standard case, invoked e.g. like so:
        #
        # ./texdown.pl Dissertation -l -p /Trash
        #
        # We are working on Dissertation.scriv, and we say we
        # want to use a project that's actually like this available
        # in that file (we can use absolute or relative names).
        #
        parseScrivener ($dir, $file);
      } else {
        #
        # Plain Text
        #
        parsePlain ($dir, $file);
      }
    }
  }
}


#
# runAsFilter
#
# Do the processing on input
# piped via STDIN
#
sub runAsFilter {
  while (<STDIN>) {
    my $line = $_;
    $line = parse($line) unless $dontparse;
    print $line;
  }
}


#
# parseScrivener
#
# Parse a Scrivener Database
#
# $dir      : The .scriv  directory to parse
# $file     : The .scrivx file to parse in that directory
#
sub parseScrivener {
  my ($dir, $file) = (@_);

  if ($debug) {
    print "% Scrivener Processing...\n";
    print "% Projects   : " . join( ', ', @projects ) . "\n";
    print "% Directory  : $dir\n";
    print "% File       : $file\n";
  }

  my $doc = XML::LibXML->load_xml(location => $file);

  #
  # If we are asked to retrieve a path for adocument id, we do only that.
  #
  if (@showid > 1) {
    foreach my $id (@showid) {
      my @binderItems = $doc->findnodes('/ScrivenerProject/Binder//BinderItem[@ID="'.$id.'"]');

      foreach my $binderItem (@binderItems) {
        my $binderItemName = $binderItem->nodeName;
        my $currentNode    = $binderItem;
        my $binderItemPath = "";

        while($currentNode->nodeName ne "Binder") {
          if ($currentNode->nodeName eq "BinderItem") {
            $binderItemPath = $currentNode->find("Title")->to_literal."/$binderItemPath";
          }
          $currentNode = $currentNode->parentNode();
        }

        print "/$binderItemPath\n" unless $id == 0;
      }
    }
    exit 0;
  }


  #
  # Check whether we have an absolute or a relative location
  #
  foreach my $project (@projects) {
    if ($project =~ "^/.*") {
      #
      # Absolute location
      #
      my $leaf = 0;
      my $path = "/ScrivenerProject/Binder";

      my $document = $doc;

      foreach my $location (split("/", $project)) {
        if ($location ne "") {
          my $subpath = '/BinderItem[Title/text() = "'."$location".'"]';
          my $document = $document->findnodes($path.$subpath)->get_node(1);

          #
          # Cound the children to detect leaves
          #
          if (!$document) {
            $path .= "/Children$subpath";
            last;
          }
          my $childcount = $document->findvalue("count($path$subpath/Children)");

          my $parentType = $document->getAttribute("Type");

          if ($childcount == 0 || $parentType eq "Text") {
            $path .= '/BinderItem[Title/text() = "'."$location".'"]';
            $leaf = 1;
          } else {
            $path .= "$subpath/Children";
          }
        }
      }

      $path .= "/*" unless $leaf;

      foreach my $binderItem ($doc->findnodes($path)) {
        printNode($binderItem, "", 0, $dir);
      }

    } elsif ($project =~ /^-?\d+$/) {
      #
      # Giving directly a project Id
      #
      foreach my $binderItem ($doc->findnodes('//BinderItem[@ID="'.$project.'"]')) {
        printNode($binderItem, "", 0, $dir)
      }
    } else {
      #
      # Relative location; /Children/* are being resolved by recursion
      #
      foreach my $binderItem ($doc->findnodes('//BinderItem[Title/text() = "'."$project".'"]')) {
        printNode($binderItem, "", 0, $dir)
      }
    }
  }
}


#
# printNode
#
# Recursive Function to conditionally print and dive into children
#
# $parentItem: The starting point of the tree
# $path      : The path up to the $parentItem
# $level     : The level of recursion
# $dir       : The directory to retrieve rtf files from
#
sub printNode {
  my ($parentItem, $path, $level, $dir) = (@_);

  my $parentTitle = "$path/" . $parentItem->findnodes('./Title')->to_literal;
  my $docId   = $parentItem->getAttribute("ID");
  my $docType = $parentItem->getAttribute("Type");
  my $docTitle = $parentItem->findnodes('./Title')->to_literal;
  my $includeInCompile = $parentItem->findnodes('./MetaData/IncludeInCompile')->to_literal;

  #
  # If we are restricting by the Scrivener metadata field
  # IncludeInCompile (which we do by default), then if a
  # given node has that field unchecked, we don't print
  # that node, and we don't dive into it's children.
  #
  return if(!$all && $includeInCompile ne "Yes");

  #
  # If the current node is a text node, we have to print it
  #
  if($docType eq "Text") {
    if ($list) {
      my $printline = sprintf("[%8d] %s", $docId, $parentTitle);

      print "$printline\n";
    } else {
      my $rtf = "$dir/Files/Docs/$docId.rtf";

      if (-e "$rtf") {
        my $line = "";
        if($debug) {
          $line = "\n\n<!--\n%\n%\n% ". $docId . " -> " . $docTitle . "\n%\n%\n-->\n";
        }
        my $curline = rtf2txt("$dir/Files/Docs/$docId");

        #
        # If we are asked to search for something, we intepret the
        # search string as (potential) regex, and search the files,
        # but don't do anything else.
        #
        if ($search ne "") {
          $curline = parse($curline) unless $dontparse;
          if ($curline =~ m/(.{0,30})($search)(.{0,30})/m) {
            my $printline = sprintf("[%8d] %s: %s%s%s", $docId, $parentTitle, colored($1, 'green'), colored($2, 'red'), colored($3, 'green'));
            print "$printline\n";
          }
        } else {
          $line .= $curline;

          $line = parse($line) unless $dontparse;
          print $line . "\n";
        }
      }
    }
  }

  #
  # If the current node has children, we need to call them (and let
  # them decide whether they want to process themselves)
  #
  foreach my $binderItem ($parentItem->findnodes('./Children/*')) {
    printNode($binderItem, $parentTitle, ++$level, $dir);
  }
}


#
# parsePlain
#
# Parse a Plain TeXDown File
#
# $dir      : The directory to look into
# $file     : The file to parse
#
sub parsePlain {
  my ($dir, $file) = (@_);

  if(!defined($file)) { return; }

  if ($debug) {
    print "% Plain processing...\n";
    print "% dir  : $dir\n";
    print "% file : $file\n";
  }

  open my $info, $file or die "Could not open $file: $!";

  while (my $line  = <$info>) {
    $line = parse($line) unless $dontparse;
    print $line;
  }
  close $info;
}
