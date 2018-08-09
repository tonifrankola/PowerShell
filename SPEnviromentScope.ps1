
param (
    [switch]$all = $false
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

Write-Host -ForegroundColor Yellow "Using $outfile to log progress."

"Web Application, Site Collection, Database Name, Size, Web Count, Lists Count, Items Count" | Out-File $outFile -Append

$WebApps = Get-SPWebApplication

foreach ($WebApp in $WebApps)
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


        if($all -eq $true)
        {
            $i=0
            $websCount = 0;
            $listsCount = 0;

            Try
            {
                foreach ($SPWeb in $Site.AllWebs)
                {
                    foreach ($SPList in $SPWeb.Lists)
                    {
                        foreach ($SPListItem in $SPList.Items)
                        {
                            $i=$i+1 
                        }
                
                        $listsCount++; 
                    }

                    $websCount++;
                    $SPWeb.dispose() 
                }
            }
            Catch
            {
                $i=-1;
                $websCount = -1;
                $listsCount = -1;
            }
        }
        else
        {
            $i=-2;
            $websCount = -2;
            $listsCount = -2;
        }

        $Site.dispose()


        $webAppDisplayName + "," + $siteUrl + "," + $contentDatabaseName + "," + $SizeInGB + "," + $websCount + "," + $listsCount + "," + $i | Out-File $outFile -Append
    }

}

Write-Host -ForegroundColor Green "Data writen to $outfile."