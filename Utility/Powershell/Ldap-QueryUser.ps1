$searcher = new-object system.DirectoryServices.Directorysearcher

$searcher.filter = "(objectclass=user)"

$props = "name","distinguishedname","samaccountname","mail","memberof"
foreach($item in $props){
$searcher.propertiestoload.add($item) | out-null
}
$capture = $searcher.findall()
$displayresults =  $capture.Properties;$displayresults.name
$displayresults
