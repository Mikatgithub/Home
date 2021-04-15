$i = 0; gc "YourTextFile" -ReadCount 100000 |%{$i++; $_ | out-file 'YourTextFile_Part$i.txt' -Encoding UTF8}
