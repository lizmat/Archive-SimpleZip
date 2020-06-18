unit module ZipTest ;


use File::Which;
use File::Temp;
use Test ;

# Check external zip & unzip are available

my $base_dir = tempdir(:unlink(True));
sub t-file
{
    my ($filename,$filehandle) = tempfile(:tempdir($base_dir));
    close $filehandle;
    return $filename ;
}

my $ZIP   = which('zip');
my $UNZIP = which('unzip');

sub clean-filename(Str:D $filename) returns Str:D
{
    return $filename
            .chomp
            .subst(/^ <[A..Za..z]> ":" /, '') # remove drive
            .subst(/ '\\' + /, '/', :g) ; # "\" => "/"
}

sub external-zip-works() returns Bool:D is export
{
    if ! $ZIP
    {
        diag "Cannot find zip";
        return False;
    }

    if ! $UNZIP
    {
        diag "Cannot find unzip";
        return False;
    }

    my $outfile = t-file() ~ ".zip" ;
    my $content = q:to/EOM/;
        Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Ut tempus odio id
        dolor. Camelus perlus.  Larrius in lumen numen.  Dolor en quiquum filia
        est.  Quintus cenum parat.
        EOM

    my $filename = write-file-with-zip($outfile, $content)
        or return False;

    my $got = pipe-in-from-unzip($outfile)
        or return False;

    if $got ne $content
    {
        diag "Uncompressed content is wrong, got[$got], expected[$content]";
        return False ;
    }

    # Test zipinfo mode
    $got = pipe-in-from-unzip($outfile, :options('-Z1'))
        or return False;

    $filename = clean-filename($filename);

    return True
        if '/' ~ $got.chomp eq $filename ;

    diag "Filenames are wrong, got[$got], expected[$filename]";

    return False ;
}

sub explain-failure($subname, @cmd, Proc $proc)
{
    # caller not supported yet, so pass in the subname
    #diag caller.subname ~ " [@cmd] failed: $!, exitcode { $proc.exitcode }";
    diag $subname ~ " [{@cmd}] failed, exitcode { $proc.exitcode }";
    diag "    out [{ $proc.out.slurp }]" if $proc.out ;
    diag "    err [{ $proc.err.slurp }]" if $proc.err;
}

sub write-file-with-zip($file, $content, $options='-v')
{
    my $infile = t-file ;

    spurt($infile, $content);

    unlink $file ;
    # fz -- force zip64
    # fd -- force descriptors

    my @comp = $ZIP, '-q', $options, $file, $infile ;
    my $proc = run |@comp, :out, :err;

    return $infile but True
        if $proc.exitcode == 0 ;

    explain-failure "write-file-with-zip", @comp, $proc ;

    return False ;
}

sub pipe-in-from-unzip($file, $name='', :$options='', Bool :$binary=False) is export
{
    my @comp = $UNZIP ;
    if $options { @comp.push($options) } else { @comp.push('-p') }
    @comp.push: $file ;
    @comp.push: $name if $name ;

    my $proc;

    if $binary
        { $proc = run |@comp, :out :err :bin }
    else
        { $proc = run |@comp, :out :err }

    if $proc.exitcode == 0
    {
        return $proc.out.slurp but True
            if ! $binary;

        return $proc.out.read ;

    }

    explain-failure "pipe-in-from-unzip", @comp, $proc ;
    return False ;
}

sub comment-from-unzip($filename) is export
{
    my $data = pipe-in-from-unzip($filename, '', :options('-qz'))
        or return '';

    return $data.chomp;
}

sub test-with-unzip($file) is export
{
    my @comp = $UNZIP, '-t', $file;
    # say "Running [{ @comp }]";
    my $proc = run |@comp, :out, :err ;

    return True
        if $proc.exitcode == 0 ;

    explain-failure "test-with-unzip", @comp, $proc ;
    return False ;
}

sub get-filenames-in-zip($file) is export
{
    my @comp = $UNZIP, '-Z1', $file ;
    # say "Running [{ @comp }]";

    # Get the filenames in Latin1 as a convenient way to get the filenames as a stream of 8-bit values
    # Means we can handle any badly-formed UTF8 encodngs, either from the zip file itself
    # or from running unzip.
    my $proc = run |@comp, :out, :err, :enc('latin1') ;

    return $proc.out.lines(:chomp)
        if $proc.exitcode == 0 ;

    explain-failure "test-with-unzip", @comp, $proc ;
    return False ;
}

sub string-to-binary(Str:D $string) is export
{
    # Convert a string into a sequence of bytes
    return $string.encode('utf8').decode('latin1');
}

sub unzipToTempDir($file)
{
    my $dir = tempdir(:unlink(True));

    my @comp = $UNZIP, '-d', $dir,  $file;
    say "Running [{ @comp }]";
    my $proc = run |@comp ;

    return $dir
        if $proc.exitcode == 0 ;

    diag "'{ @comp }' failed: $!";
    return False ;
}


#sub testWithFUnzip($file)
#{
#    my $outfile = t-file;
#
#    my $comp = "$UNZIP" ;
#
#    if ( system("$comp -p $file >$outfile") == 0 )
#    {
#        $_[0] = slurp($outfile, :b);
#        return 1
#    }
#
#    diag "'$comp' failed: $?";
#    return False ;
#}
#

#sub unzip64Available returns Bool
#{
#   #my $stuff = `$STRINGS $UNZIP`;
#   my $stuff = `$UNZIP -v`;
#   return $stuff =~ /ZIP64_SUPPORT/;
#}
#
#sub zip64Available returns Bool
#{
#    # return grep { /ZIP64_SUPPORT/ }
#    #       `$STRINGS $UNZIP`;
#   my $stuff = `$ZIP -v`;
#   return $stuff =~ /ZIP64_SUPPORT/;
#}

#sub testWithZip($file)
#{
#    my $outfile = t-file;
#
#    my $status = ( system("$ZIP -T $file >$outfile") == 0 ) ;
#
#    $_[0] = slurp($outfile, :b);
#
#    return $status ;
#}
