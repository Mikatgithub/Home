$services = invoke-command -ComputerName YourServer -ScriptBlock {get-service | ? {$_.displayname -like "*hopex*" -and $_.status -notlike "Running-"}}| select displayname,status,pscomputername
$apppool = invoke-command -ComputerName YourIISServer -ScriptBlock {import-module webadministration;dir IIS:\Apppools | ? state -notlike "started"}|select name,state,pscomputername
if($services.count -gt 0){write-host "The following services hasn't started" -ForegroundColor Magenta;$services}else{Write-host "All Hopex Services running" -ForegroundColor green}
if($apppool.count -gt 0){write-host "The following IIS AppPools hasn't started" -ForegroundColor Magenta;$apppool}else{Write-host "All IIS AppPools are running" -ForegroundColor green}
