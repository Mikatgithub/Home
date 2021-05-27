$searcher = new-object system.DirectoryServices.Directorysearcher

$searcher.filter = "(&(objectclass=group)(name=examplegroup))"

$props = "name","distinguishedname","member"
foreach($item in $props){
$searcher.propertiestoload.add($item) | out-null
}
$capture = $searcher.findall()
$displayresults =  $capture.Properties;$displayresults.name
$displayresults
