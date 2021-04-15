gci ‘HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP’ -recurse | gp -name Version -EA 0 | ? { $_.PSChildName -match ‘^(?!S)\p{L}’} | select PSChildName,Version
