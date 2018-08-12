<#  
.SYNOPSIS  
    Gets information about SharePoint farm content.
.DESCRIPTION  
    Retrieved information about number of web applications,
    site collectsion, subsites, lists and list items.
    
.PARAMETER LoadAllSubsites
    Boolean, if $true will load all the subsites of each site collection. 

.PARAMETER LoadPersonalSites
    If true, Personal (My) Sites in the SharePoint farm will also be loaded.

.PARAMETER MySiteHostUrl
    String - e.g. "https://mysite.company.com" - used to filter-out all Personal (My) sites. Required if filtering is LoadPersonalSites is set to false.

.NOTES  
    File Name  : SPEnviromentScope.ps1  
    Author     : Toni Frankola
.LINK  
    https://github.com/tonifrankola/PowerShell/blob/master/SPEnviromentScope.ps1

.EXAMPLE
    .\SPEnvironmentScope.ps1
    Loads SharePoint environment with the default settings. Only lists site collections without retrieving subsites and list items.
.EXAMPLE
    .\SPEnvironmentScope.ps1 -LoadAllSubsites $true
    Loads SharePoint environment including subsites
.EXAMPLE
    .\SPEnvironmentScope.ps1 -LoadAllSubsites $true -LoadPersonalSites $false -MySiteHostUrl "https://mysite.company.com"
    Loads SharePoint environment including subsites
#>


param (
    [switch]$LoadAllSubsites = $false,
    [switch]$LoadPersonalSites = $true,
    [String]$MySiteHostUrl = $null
 )

Function Get-StringHash([String] $string, $hashName = "MD5") 
{ 
    $stringBuilder = New-Object System.Text.StringBuilder 
    [System.Security.Cryptography.HashAlgorithm]::Create($hashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($string))|%{ 
    [Void]$stringBuilder.Append($_.ToString("x2")) 
    } 
    $stringBuilder.ToString() 
}

Function Get-SPEnvironmentScope()
{
    $outFile = "$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"

    Write-Host -ForegroundColor Yellow "$(get-date -format g) - Using $outfile to log progress."

    "Web Application, My Site, Site Collection, Database Name, Size, Users Count, Webs Count, Lists Count, Items Count" | Out-File $outFile -Append

    if($MySiteHostUrl -ne $null -and -not ($MySiteHostUrl.endswith("/")))
    {
            $MySiteHostUrl = $MySiteHostUrl+"/"
    }

    [Microsoft.SharePoint.SPSecurity]::RunWithElevatedPrivileges(
    {
        $WebApps = Get-SPWebApplication
        foreach ($WebApp in $WebApps)
        {
            if($MySiteHostUrl -ne $null)
            {
                $itemCountsMySiteHost = $WebApp.Url -eq $MySiteHostUrl
            }
            else
            {
                $itemCountsMySiteHost = "Unknown"
            }

            if($LoadPersonalSites -or ($itemCountsMySiteHost -eq "Unknown"))
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

                    if($LoadAllSubsites -eq $true)
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
}

Add-PSSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue
$spPSSS = Get-PSSnapin | Where-Object{$_.Name -eq "Microsoft.SharePoint.PowerShell"}
if($null -ne $spPSSS)
{
    Get-SPEnvironmentScope
}
else
{
    Write-Host -ForegroundColor Red "This script needs to run on a SharePoint machine."
}