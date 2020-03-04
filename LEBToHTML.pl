use strict;
use File::Slurp;
use Data::Dumper;
use Getopt::Long;

# gather options
my $bookCode = '1 Th';
my $title = '';
my $author = '';
my $publisher = '';

GetOptions( 'book_code=s' => \$bookCode
           ,'title=s' => \$title
           ,'author:s' => \$author
           ,'publisher:s' => \$publisher
          );

#print "Author: $author, $bookCode, $title, $publisher\n";

# print simple html header
print "<html>";
print "<head>";
print "<meta charset=\"UTF-8\">";
print "<meta name=\"title\" content=\"$title\">";
print "<meta name=\"author\" content=\"$author\">";
print "<meta name=\"publisher\" content=\"$publisher\">";
print "</head>";
print "<body>";

my @line = read_file( 'LEB.xml' ); #, binmode => ':utf8' );

my $capture = 0;
my $skip;

# will include lines from the opening section (preface, etc) and the book requested
foreach my $l ( @line ) {
   $skip = 0;

   if ( $l =~ /<title>/ ) {
      $capture = 1;
      $l = "<h2>Title</h2><p>$title</p>";
   }

   if ( $l =~ /<\/title>/ ) {
      $skip = 1;
   }

   if ( $l =~ /<license>/ ) {
      $l = "<h2>License</h2>";
   }

   if ( $l =~ /<p>License<\/p>/ ) {
      $skip = 1;
   }

   if ( $l =~ /<\/license>/ ) {
      $skip = 1;
   }

   if ( $l =~ /<trademark>/ ) {
      $l = "<h2>Trademark</h2>";
   }

   if ( $l =~ /<\/trademark>/ ) {
      $skip = 1;
   }

   if ( $l =~ /<preface>/ ) {
      $l = "<h2>Preface</h2>";
   }

   if ( $l =~ /<\/preface>/ ) {
      $skip = 1;
   }

   # turn off capture if a book id found (will check in a moment for the book we want
   if ( $l =~ /<book/ ) {
      $capture = 0;
   }

   my $bookTag = "<book id=\"$bookCode\">";
   if ( $l =~ /$bookTag/ ) {
      $capture = 1;
      $l = "<h2>$title</h2>";
   }

   if ( $capture ) {
      # search for and hide chapter tag
      # assumption - this tag occupies its own line
      if ( $l =~ /<chapter/ || $l =~ /chapter>/ ) {
         # for psalms and proverbs, need to show the chapter
         if ( $l =~ /<chapter id="Ps ([0-9]+)"/ ) {
            $l = "<h3>Psalm $1</h3>";
         }
         elsif ( $l =~ /<chapter id="Pr ([0-9]+)"/ ) {
            $l = "<h3>Proverb $1</h3>";
         }
         else {
            $skip = 1;
         }
      }

      # search for and hide verse number tag and contents
      # assumption - always exists on one line
      $l =~ s/<verse-number id="[A-Za-z0-9\s\:]+">[0-9a-zA-Z]*<\/verse-number>//g;

      # search for and hide pericope tag and contents
      # assumption - always exists on one line
      $l =~ s/<pericope>/~/g;
      $l =~ s/<\/pericope>/~/g;
      $l =~ s/~[^~]*~//g;
   
      # search for and hide note tag and contents
      # assumption - always exists on one line
      $l =~ s/<note/~/g;
      $l =~ s/<\/note>/~/g;
      $l =~ s/~[^~]*~//g;
   
      # replace <supplied> tag with emphasis tag
      $l =~ s/supplied>/em>/g;
   
      # remove the idiom-start and idiom-end tags
      $l =~ s/<idiom-start \/>//g;
      $l =~ s/<idiom-end \/>//g;
   
      # convert ul to blockquote
      $l =~ s/<ul>/<blockquote>/g;
      $l =~ s/<\/ul>/<\/blockquote>/g;

      # fix numbered li tags
      $l =~ s/<(li)[0-9]+>/<\1>/g;
      $l =~ s/<\/(li)[0-9]+>/<\/\1>/g;

      $l =~ s/<li>/<p>/g;
      $l =~ s/<\/li>/<\/p>/g;

      # replace special characters for brackets with regular bracket characters
      $l =~ s/〚/[ /g;
      $l =~ s/〛/ ]/g;
   }
   
   if ( $capture && $l =~ "<\/book" ) {
      $capture = 0;
   }

   if ( $capture && !$skip ) {
      print $l;
   }
}

print "</body>";
