param (
    [switch]$loadAllItems = $false,
    [switch]$itemCountncludePersonalSites = $true,
    [String]$mySiteHostUrl = $null
 )

if((Get-PSSnapin | Where {$_.Name -eq "Microsoft.SharePoint.PowerShell"})-eq $null)
{Add-PSSnapin Microsoft.SharePoint.PowerShell;}
cls

Function Get-StringHash([String] $String, $HashName = "MD5") 
{ 
    $StringBuilder = New-Object System.Text.StringBuilder 
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))|%{ 
    [Void]$StringBuilder.Append($_.ToString("x2")) 
    } 
    $StringBuilder.ToString() 
}

$outFile = "$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"

Write-Host -ForegroundColor Yellow "$(get-date -format g) - Using $outfile to log progress."

"Web Application, My Site, Site Collection, Database Name, Size, Users Count, Webs Count, Lists Count, Items Count" | Out-File $outFile -Append

if($mySiteHostUrl -ne $null -and -not ($mySiteHostUrl.endswith("/")))
{
        $mySiteHostUrl = $mySiteHostUrl+"/"
}

[Microsoft.SharePoint.SPSecurity]::RunWithElevatedPrivileges(
{
    $WebApps = Get-SPWebApplication
    foreach ($WebApp in $WebApps)
    {
        if($mySiteHostUrl -ne $null)
        {
            $itemCountsMySiteHost = $WebApp.Url -eq $mySiteHostUrl
        }
        else
        {
            $itemCountsMySiteHost = "Unknown"
        }

        if($itemCountncludePersonalSites -or ($itemCountsMySiteHost -eq "Unknown"))
        {
            $Sites = Get-SPSite -WebApplication $WebApp -Limit All
            
            foreach($Site in $Sites)
            {
                $SizeInKB = $Site.Usage.Storage
                $SizeInGB = $SizeInKB/1024/1024/1024
                $SizeInGB = [math]::Round($SizeInGB,2)

                $webAppDisplayName = Get-StringHash $WebApp.DisplayName
                $siteUrl = Get-StringHash $Site.URL
                $contentDatabaseName = Get-StringHash $Site.ContentDatabase.Name

                if($loadAllItems -eq $true)
                {
                    $userCount = 0;
                    $itemCount=0;
                    $websCount = 0;
                    $listsCount = 0;

                    Try
                    {
                        $userCount = $Site.RootWeb.AllUsers.Count

                        foreach ($SPWeb in $Site.AllWebs)
                        {
                            foreach ($SPList in $SPWeb.Lists)
                            {
                            $itemCount= $itemCount + $SPList.ItemCount
                            $listsCount++; 
                            }

                            $websCount++;
                            $SPWeb.dispose() 
                        }
                    }
                    Catch
                    {
                        $ErrorMessage = $_.Exception.Message

                        Write-Host "Error loading $Site.Url ($_.Exception.Message)." -ForegroundColor Yellow

                        $userCount = -1;
                        $itemCount=-1;
                        $websCount = -1;
                        $listsCount = -1;
                    }
                }
                else
                {
                    $userCount = -2;
                    $itemCount=-2;
                    $websCount = -2;
                    $listsCount = -2;
                }

                $Site.dispose()

                $webAppDisplayName + "," + $itemCountsMySiteHost + "," + $siteUrl + "," + $contentDatabaseName + "," + $SizeInGB + "," + $userCount + "," + $websCount + "," + $listsCount + "," + $itemCount | Out-File $outFile -Append
            }        
        }
    }
})

Write-Host -ForegroundColor Green "$(get-date -format g) - Data writen to $outfile."
