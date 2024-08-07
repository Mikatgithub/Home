#Script will set a folder to Read only, It will break inheritance to achieve the goal
#requires PnP Powershell and the M365 Tenant to Consent to PnP.Powershell App https://pnp.github.io/powershell/cmdlets/Register-PnPManagementShellAccess.html
#Script has no paramaters and will ask you to type in the Site, List and the folder itself
#Script can be edited to use other permissions such as contribute
#Contributing Articles: 
#https://www.sharepointdiary.com/2018/03/sharepoint-online-powershell-to-get-folder-permissions.html
#https://www.sharepointdiary.com/2019/06/sharepoint-online-powershell-break-folder-permission-inheritance.html#ixzz8i5HHXkZm

#SPO Tenant Domain name
#Set your SPO Tenant URL here
$SPO = "https://TypeInYourDomain.sharepoint.com/sites/"


write-host "This script is for SharePoint Online only" -ForegroundColor Magenta
write-host "Note:Script requires Site Collection Admin or SharePoint Admin" -ForegroundColor Cyan
#Prepare Log file
Function Get-Timestamp()
{get-date -format "HHmm_ddMMyyyy"}
$script:logfile = "Log file started at $(get-timestamp) `n"
$logfile += "Script executed by $(whoami) `n"
Function exit-script()
{$logfile | out-file .\Set-FolderRO_Logfile_$(get-timestamp).txt
exit}

#Check PnP Powershell is Installed
Write-host "Checking if PnP Powershell is installed"
if(get-module -ListAvailable | ? {$_.name -like "pnp.powershell"}){
    Write-host "PnP Powershell Version $((get-module -ListAvailable | ? {$_.name -like "pnp.powershell"}).version -join ";") Found"
    $logfile += "PnP Powershell Version $((get-module -ListAvailable | ? {$_.name -like "pnp.powershell"}).version -join ";") Found `n"
    }
else {Write-host "PnP Powershell not found, Exiting" -ForegroundColor Yellow
      $logfile += "PnP Powershell not found, Exiting `n"
      exit-script   
}

#Capture SPO Site, List and Folder via User Input 
Write-host ""
write-host "Please type in url of the SharePoint Site" -ForegroundColor Cyan -NoNewline
$wshell = New-Object -ComObject wscript.shell;
$wshell.SendKeys($SPO)
$SiteURL = read-host ">"
Write-host "Site is set to >" -NoNewline
$logfile += "Site is set to $siteurl `n"
Write-host $siteurl -ForegroundColor green
Write-host ""
Write-host "Please type in the list name where the folder sits in" -NoNewline -ForegroundColor DarkCyan
$SPOList = read-host ">"
Write-host "List name is " -NoNewline
$logfile += "List name is $spolist `n"
Write-host $spolist -ForegroundColor green
Write-host ""
Write-host "Please type in the folder name" -NoNewline -ForegroundColor Cyan
$ROFolder = read-host ">"
Write-host "Top Level Folder is set to " -NoNewline
$logfile += "Top Level Folder is set to $rofolder `n"
Write-host $ROFolder -ForegroundColor green
$FolderRelativeURL = "/sites/" + $siteurl.split("/")[4] + "/" + $SPOList + "/" + $ROFolder
Write-host ""
Write-host "Folder Path is " -ForegroundColor DarkCyan -NoNewline
$logfile += "Folder Path is $FolderRelativeURL `n"
Write-host $FolderRelativeURL -ForegroundColor green
Write-host ""
Write-host "Connecting to $siteurl via PnP Powershell"

Try {
    #Connect to SharePoint Site
    Connect-PnPOnline -Url $SiteURL -Interactive
    $logfile += "Connected to Site $siteurl `n"
}
Catch {
    write-host -f Red "Error:" $_.Exception.Message
    Write-host "Couldn't connect to Site"
    $logfile += "Error: $($_.Exception.Message) `n"
    $logfile += "Couldn't connect to Site $siteurl `n"
    exit-script
}

Write-host ""
write-host "Checking if SharePoint list exists" -ForegroundColor cyan

Try {
    #sharepoint online get list using powershell
    $List = Get-PnPList $SPOList -ThrowExceptionIfListNotFound -ErrorAction Stop
    $list | add-member ServerRelativeUrl((Get-PnPProperty -ClientObject $list -Property rootfolder).serverrelativeurl)
    $logfile += "List Found $SPOlist `n"  

}
Catch {
    write-host -f Red "Error:" $_.Exception.Message
    Write-host "List doesn't exist, exiting"
    $logfile += "List $SPOList doesn't exist, exiting `n"
    exit-script
}
Write-host "List $spolist Found"

Write-host ""
Write-host "Checking for $rofolder"
Try {
    #check folder exists
    $folder = Get-PnPFolder -list $list -Includes ListItemAllFields.HasUniqueRoleAssignments | ? name -like "*$rofolder*" -ErrorAction Stop -WarningAction SilentlyContinue
    Write-host "Folder $($folder.name) Found!" -ForegroundColor Green
    If($folder.count -gt 1){
        Write-host "Multiple folders found, please type in the full folder path below"
        $folder |%{ write-host $_.serverrelativeurl -ForegroundColor Cyan}    
        $wshell.SendKeys($list.ServerRelativeUrl+"/")
        $rofolder = read-host "Type in the full path"
        $folder = Get-PnPFolder -url $rofolder -Includes ListItemAllFields.HasUniqueRoleAssignments -ErrorAction Stop

    }
    $logfile += "Folder Found $rofolder `n"
 
}
Catch {
    write-host -f Red "Error:" $_.Exception.Message
    Write-host "Folder doesn't exist, exiting"
    $logfile += "Folder $rofolder doesn't exist, exiting `n"
    Exit-script
}
#Break Folder Permissions
If($Folder.ListItemAllFields.HasUniqueRoleAssignments)
{
    Write-host "Folder is already with broken permissions!" -f Yellow
    $logfile += "Folder is already with broken permissions! `n"
}
Else
{
    #Break Folder permissions - keep all existing permissions($True) & keep Item level permissions($true)
    $Folder.ListItemAllFields.BreakRoleInheritance($True,$True)
    Invoke-PnPQuery
 
    Write-host "Folder Permission Inheritance broken" -f Green  
    $logfile += "Folder Permission Inheritance broken `n"
}



Write-host "Grabbing Names on the Folder"

#Function to Get Folder Permissions Before setting to read only
Function Get-PnPPermissions([Microsoft.SharePoint.Client.SecurableObject]$Object)
{
    Try {
        #Get permissions assigned to the Folder
        Get-PnPProperty -ClientObject $Object -Property HasUniqueRoleAssignments, RoleAssignments
 
        #Check if Object has unique permissions
        $HasUniquePermissions = $Object.HasUniqueRoleAssignments
    
        #Loop through each permission assigned and extract details
        $Script:PermissionCollection = @()
        Foreach($RoleAssignment in $Object.RoleAssignments)
        {
            #Get the Permission Levels assigned and Member
            Get-PnPProperty -ClientObject $RoleAssignment -Property RoleDefinitionBindings, Member
    
            #Get the Principal Type: User, SP Group, AD Group
            $PermissionType = $RoleAssignment.Member.PrincipalType
            $PermissionLevels = $RoleAssignment.RoleDefinitionBindings | Select -ExpandProperty Name
 
            #Remove Limited Access
            $PermissionLevels = ($PermissionLevels | Where { $_ -ne "Limited Access"}) -join ","
            If($PermissionLevels.Length -eq 0) {Continue}
 
            #Get SharePoint group members
            If($PermissionType -eq "SharePointGroup")
            {
                #Get Group Members
                $GroupMembers = Get-PnPGroupMember -Identity $RoleAssignment.Member.LoginName
                 
                #Leave Empty Groups
                If($GroupMembers.count -eq 0){Continue}
 
                ForEach($User in $GroupMembers)
                {
                    #Add the Data to Object
                    $Permissions = New-Object PSObject
                    $Permissions | Add-Member NoteProperty Login($RoleAssignment.Member.LoginName)
                    $Permissions | Add-Member NoteProperty User($User.Title)
                    $Permissions | Add-Member NoteProperty Type($PermissionType)
                    $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                    $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
                    $Script:PermissionCollection += $Permissions
                }
            }
            Else
            {
                #Add the Data to Object
                $Permissions = New-Object PSObject
                $Permissions | Add-Member NoteProperty Login($RoleAssignment.Member.LoginName)
                $Permissions | Add-Member NoteProperty User($RoleAssignment.Member.Title)
                $Permissions | Add-Member NoteProperty Type($PermissionType)
                $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                $Permissions | Add-Member NoteProperty GrantedThrough("Direct Permissions")
                $SCript:PermissionCollection += $Permissions
            }
        }
        #cleanup Permissions Report
        $script:PermissionCollection = $script:PermissionCollection | select -Unique login,permissions,type
        $script:PermissionCollection| %{If($_.login -like "*@*"){$_.login = $_.login.split('|')[2]}}
        #Export Permissions to CSV File
        $PermissionCollection | Export-CSV "FolderPermissionRpt_$(get-timestamp).csv" -NoTypeInformation
        Write-host -f Green "`n*** Folder Permission Report Generated Successfully!***"
        $logfile += "Folder Permission Report Generated Successfully!`n"
    }
    Catch {
    write-host -f Red "Error Generating Folder Permission Report!" $_.Exception.Message
    $logfile += "Couldn't create permissions report `n"
    exit-script
    }
}

#Call the function to generate permission report
Get-PnPPermissions $Folder.ListItemAllFields

Write-host "There is $($PermissionCollection.count) to Process"

#Wipe Permissions
write-host "Wiping Permissions" -ForegroundColor Cyan
Try{
    if($PermissionCollection[0].type -eq "user"){
        Set-PnPfolderPermission -List $spolist -identity $folder.ServerRelativeUrl -User $PermissionCollection[0].login -removeRole $PermissionCollection[0].permissionlevels -ClearExisting -SystemUpdate -ErrorAction Stop
    write-host "Cleared All Permissions"
    $logfile += "Cleared All Permission `n"}
    else { Set-PnPfolderPermission -List $spolist -identity $folder.ServerRelativeUrl -Group $PermissionCollection[0].login -removeRole $PermissionCollection[0].permissionlevels -ClearExisting -SystemUpdate -ErrorAction Stop
    write-host "Cleared All Permissions"
    $logfile += "Cleared All Permission `n"
    }
        }
    Catch {write-host -f Red "Error Removing Permissions" $_.Exception.Message
    $logfile += "Error Removing Permissions $($_.Exception.Message) `n"}

#Set the users found the report, to Read Only except for Site Collection Admins
foreach($user in $PermissionCollection)
{
    Try {
       if($user.type -eq "user"){
        Set-PnPfolderPermission -List $spolist -identity $folder.ServerRelativeUrl -User $user.login -AddRole read -SystemUpdate -ErrorAction stop
        write-host "Added Read permission to $($user.login) on $($folder.ServerRelativeUrl)"
        $logfile += "Added Read permission to $($user.login) on $($folder.ServerRelativeUrl) `n"}
        else{Set-PnPfolderPermission -List $spolist -identity $folder.ServerRelativeUrl -group $user.login -AddRole read -SystemUpdate -ErrorAction stop
            write-host "Added Read permission to $($user.login) on $($folder.ServerRelativeUrl)"
            $logfile += "Added Read permission to $($user.login) on $($folder.ServerRelativeUrl) `n"}}
    Catch {write-host -f Red "Error Adding Permissions" $_.Exception.Message
           $logfile += "Error Removing Permissions $($_.Exception.Message) `n"}
    
}
#End of script reached, Output logfile
exit-script
