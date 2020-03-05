#!/usr/bin/perl
my $VERSION="1.01";

print "Version: $VERSION\n";

use strict;
use File::Slurp;
use Data::Dumper;
use Getopt::Long;
use Term::ReadKey;

# constants definition
use constant STATS_FILE => "LEBFlashcards_stats.txt";
use constant MIN_VERSES => 2;
use constant MAX_VERSES => 3;
use constant SEARCH_TRIES => 8;
use constant REGUESS_TRY => 3; # if a random number generated is this, try to reguess an earlier miss

my @bookCode = (
                "1 Th"
               ,"2 Th"
               ,"1 Ti"
               ,"2 Ti"
               ,"Titus"
#               ,"Heb"
               ,"Jas"
               ,"1 Pe"
               ,"2 Pe"
               ,"1 Jn"
               ,"2 Jn"
               ,"3 Jn"
               ,"Jud"
#               ,"Re"
               );

my @line = read_file( 'LEB.xml' ); 

my $capture = 0;
my $skip;

# array of possible verses
my @verseAddr;
my @verse;

my $sessionPercentCorrect=0;
my $sessionPercentIncorrect=0;

my $createStats = 0;
my %stat;

if ( -e STATS_FILE ) {
   #load the stats
   my @s = read_file( STATS_FILE );
   foreach my $s ( @s ) {
      # parse, storing in associative array
      my @x = split( /\|/, $s );
      my $key = shift( @x );
      $key =~ s/^\s+|\s+$//g;
      chomp @x;
      $stat{ $key } = \@x;
   }
}
else {
   $createStats = 1;
}

# loop, pulling verses for the books we want
foreach my $l ( @line ) {
   $skip = 0;

   # See if this is one of our books
   if ( $l =~ /<book/ ) {
      $capture = 0; 
      foreach my $bc ( @bookCode ) {
         if ( $l =~ /book id="$bc"/ ) {
           $capture = 1;
         }
      }
   }

   if ( $capture ) {
      # search for and hide chapter tag
      # assumption - this tag occupies its own line
      if ( $l =~ /<chapter/ || $l =~ /chapter>/ ) {
         $skip = 1;
      }

      # get the address of the each verse, break up the verse lines, and hide the tags
      if ( $l =~ /verse-number/ ) {
         my @vAr = split( /<verse-number/, $l );
         foreach my $v ( @vAr ) {
            if ( !( $v =~ /\s+<p>/ ) ) {
               my $vAdd = $v;
               $vAdd =~ s/id="([A-Za-z0-9\s\:]+)">.*/\1/;
               # left and right trim
               $vAdd =~ s/^\s+|\s+$//g;
   
               $v =~ s/ id="[A-Za-z0-9\s\:]+">[0-9a-zA-Z]*<\/verse-number>//g;

               if ( $createStats ) {
                  my @a = ( 0, 0, 0 );
                  $stat{ $vAdd } = \@a;
               }
         
               # search for and hide pericope tag and contents
               # assumption - always exists on one line
               $v =~ s/<pericope>/~/g;
               $v =~ s/<\/pericope>/~/g;
               $v =~ s/~[^~]*~//g;
            
               # search for and hide note tag and contents
               # assumption - always exists on one line
               $v =~ s/<note/~/g;
               $v =~ s/<\/note>/~/g;
               $v =~ s/~[^~]*~//g;
            
               # remove the idiom-start and idiom-end tags
               $v =~ s/<idiom-start \/>//g;
               $v =~ s/<idiom-end \/>//g;
            
               # remove the supplied, em, ul, li, p tags
               $v =~ s/<supplied>//g;
               $v =~ s/<\/supplied>//g;
               $v =~ s/<em>//g;
               $v =~ s/<\/em>//g;
               $v =~ s/<ul>//g;
               $v =~ s/<\/ul>//g;
               $v =~ s/<li[0-9]*>//g;
               $v =~ s/<\/li[0-9]*>//g;
               $v =~ s/<p>//g;
               $v =~ s/<\/p>//g;
         
               # replace special characters for brackets with regular bracket characters
               $v =~ s/〚/[ /g;
               $v =~ s/〛/ ]/g;
              
               # trim whitespace
               $vAdd =~ s/^\s+|\s+$//g;
               $v =~ s/^\s+|\s+$//g;

               push( @verseAddr, $vAdd );
               push( @verse, $v );
            }
         }
      }
   }
}


# generate a random series of verses (provided they haven't already been guessed correctly twice)

# create a place to put verses you need to re-guess
my @reguessTry; 

my $looping = 1;
# seed the random number generator
srand( );

while ( $looping ) {
   my $vRange = MIN_VERSES + int rand( MAX_VERSES );

   my $found = 0;
   my $tryCount = 0;
   my $r;
   while ( !$found && $tryCount < SEARCH_TRIES ) { 
      $tryCount++;
      if ( ( ( 1 + int rand( REGUESS_TRY ) ) == REGUESS_TRY ) && $#reguessTry > 0 ) {
print "***** RETRYING *******";
ReadMode 'cbreak';
my $key = ReadKey(0);
ReadMode 'normal';
         $r = shift( @reguessTry );
      } 
      else {
         $r = int rand( $#verse + 1 );
      }
      # if a verse in this range has already been guessed correctly more than once, keep looking

      my $guessedCorrectlyMoreThanOnce = 0;
      for ( my $i=0; $i<$vRange; $i++ ) {
         my $m = $stat{ $verseAddr[ $r ] };
         if ( @$m[ 1 ] > 1 ) {
            $guessedCorrectlyMoreThanOnce = 1;
         } 
      }

      if ( !$guessedCorrectlyMoreThanOnce ) {
         $found = 1;
      }   
   }
   my $go = 1;
 
   $looping = 0;


   if ( $go ) {
      system( "clear" );
      print "\n----------------------------------------\n";

      # get the book for this range (cutting off any verses that go over to the next book)
      my $book = $verseAddr[ $r ];
      $book =~ s/([1-3]*\s*[A-Za-z]+).*/\1/;
   
      # print the passage
      my $passageStart;
      my $passageEnd;
      for ( my $i=0; $i<$vRange; $i++ ) {
         my $j = $r + $i;
         # don't want to go over into a new book
         my $b = $verseAddr[ $j ];
         $b =~ s/([1-3]*\s*[A-Za-z]+).*/\1/;
       
         # don't want to go over the array range either
         
         if ( $b == $book && $j <= $#verse ) {
            if ( !$passageStart ) {
               $passageStart = $verseAddr[ $j ];
            }
            print  $verse[ $j ] . " ";
            $passageEnd = $verseAddr[ $j ];
         }
         else {
            $vRange--;
         }
      }

      print "\n----------------------------------------\n";

      # get user "guess" as to the book for the range
      print "\nWhich book is this?\n";
      my $correctGuess = -1;
      for ( my $bc=0; $bc<=$#bookCode; $bc++ ) {
          my $vbc = $bc+1;
          print $vbc . ">" . $bookCode[ $bc ] . "  ";
          if ( $bookCode[ $bc ] eq $book ) {
             $correctGuess = $bc;
          }
      }
      print "\n: ";
      my $guess = <STDIN>;
      chomp $guess;

      # check the results
      if ( $guess == ( $correctGuess + 1 ) ) {
         print "Correct!\n";
         $sessionPercentCorrect++;

         # store the stats
         for ( my $n=$r; $n < $r + $vRange; $n++ ) {
            my $m = $stat{ $verseAddr[ $n ] };
            @$m[ 0 ] = @$m[ 0 ] + 1; 
            @$m[ 1 ] = @$m[ 1 ] + 1; 
            @$m[ 2 ] = @$m[ 2 ]; 
            $stat{ $verseAddr[ $n ] } = $m;
         }
      }
      else {
         print "Incorrect. The correct guess is " . $bookCode[ $correctGuess ] . "\n";
         $sessionPercentIncorrect++;

         
         push( @reguessTry, $r ); # just the first verse, even if more than one in the range

         # store the stats
         for ( my $n=$r; $n < $r + $vRange; $n++ ) {
            my $m = $stat{ $verseAddr[ $n ] };
            @$m[ 0 ] = @$m[ 0 ] + 1; 
            @$m[ 1 ] = @$m[ 1 ]; 
            @$m[ 2 ] = @$m[ 2 ] + 1; 
            $stat{ $verseAddr[ $n ] } = $m;
         }
      }

      # print the passage
      print "\nThe passage is " . $passageStart . " through " . $passageEnd . "\n";

      # store the stats
      # This is inefficient and overkill, but it's what I'm going with...
      my @sAr;

      my $totalVerses = 0;
      my $shownVerses = 0;
      my $correctVerses = 0;
      my $incorrectVerses = 0;

      foreach my $k ( keys %stat ) {
         my $sLn = $k . "|" . $stat{ $k }->[ 0 ] . "|" . $stat{ $k }->[ 1 ] . "|" . $stat{ $k }->[ 2 ] . "\n";
         push( @sAr, $sLn );

         $totalVerses++;
         $shownVerses += ( $stat{ $k }->[ 0 ] > 0 ? 1 : 0 );
         $correctVerses += ( $stat{ $k }->[ 1 ] > 0 ? 1 : 0 );
         $incorrectVerses += ( $stat{ $k }->[ 2 ] > 0 ? 1 : 0 );
      }

      write_file( STATS_FILE, @sAr );

      # display overall stats
      print "\n";
      print "Total verses: $totalVerses\n";
      print "Shown verses: $shownVerses\n";
      print "Correct guesses: $correctVerses\n";
      print "Incorrect guesses: $incorrectVerses\n";
      
      print "\nSession success rate: " . sprintf("%2d%%", ( ( $sessionPercentCorrect / ( $sessionPercentCorrect + $sessionPercentIncorrect ) ) ) * 100 ) . "\n";
      print "\nHit any key to guess another passage, or press \"q\" to quit: ";
      ReadMode 'cbreak';
      my $key = ReadKey(0);
      ReadMode 'normal';

      if ( $key eq "q" ) {
         print "\n\nExiting...\n";
      }
      else {
         $looping = 1;
      }
   }
}
