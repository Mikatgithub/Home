#Script will query Active Directory user account and Returns the Name, email, State or Province, department and Job Title
#Specify the Sam account name with the -sam parameter
#Usage .\LDAP-QueryUser.ps1 -sam mylogin
# update $props parameter to pull out other user account information
# Make a new line/entry after Line 42 (Don't override) with $OutputTable | Add-member NoteProperty YourProperty -Value $result.yourproperty.replace("{","")

param([string]$sam)

Function Get-Timestamp()
{get-date -format "HHmm_ddMMyyyy"}
$script:logfile = "Log file started at $(get-timestamp) `n"
$logfile += "Script executed by $(whoami) `n"
Function exit-script()
{$logfile | out-file .\Query-User_Logfile_$(get-timestamp).txt
exit}
Function reset-int()
{$script:i=1}
reset-int

if($sam -like "*\*"){$sam = $sam.split("\")[1]}else{exit-script}

$searcher = new-object System.DirectoryServices.DirectorySearcher

$searcher.filter = "(&(objectclass=user)(samaccountname=$($sam)))"

$props = "name","Distinguishedname","samaccountname","mail","title","st","Department"

foreach($item in $props){
$searcher.propertiestoload.add($item)|out-null
}
$capture = $searcher.findall()
$displayresults = $capture.properties;$displayresults.name
#$displayresults
$output = @()
foreach($result in $displayresults){
        $OutputTable = New-Object PSObject
        $OutputTable | Add-member NoteProperty DisplayName -Value $result.name.replace("{","")
        $OutputTable | Add-member NoteProperty Email -Value $result.mail.replace("{","")
        $OutputTable | Add-member NoteProperty State -Value $result.st.replace("{","")
        $OutputTable | Add-member NoteProperty Department -Value $result.department.replace("{","")
        $OutputTable | Add-member NoteProperty Title -Value $result.title.replace("{","")
        $output += $outputtable}
$output
