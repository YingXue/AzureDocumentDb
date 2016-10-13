    function PostDocumentToDocumentDB
    {
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory = $true)]
            [string]$accountName,
            [Parameter(Mandatory = $true)]
            [string]$connectionKey,
            [Parameter(Mandatory = $true)]
            [string]$databaseName,
            [Parameter(Mandatory = $true)]
            [string]$collectionName,
            [Parameter(Mandatory = $true)]
            [string]$sourceFile
        )
    
        $TestPath = "D:\test.txt"
        "in helper" | Out-File $TestPath
        $rootUri = "https://" + $accountName + ".documents.azure.com" 
        $apiDate = GetUTDate
    
        $collection = GetCollectionFromDocumentDB -accountName $AccountName -connectionKey $ConnetionKey -databaseName $DatabaseName -collectionName $CollectionName
         
        $json = Get-Content -Path $sourceFile
        PostDocument -document $json -dbname $databaseName -collection $collectionName 
    }

    function GetDatabaseFromDocumentDB
    {
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory = $true)]
            [string]$accountName,
            [Parameter(Mandatory = $true)]
            [string]$connectionKey,
            [Parameter(Mandatory = $true)]
            [string]$databaseName
        )
    
        $rootUri = "https://" + $accountName + ".documents.azure.com" 
        $apiDate = GetUTDate
 
        $db = GetDatabases | where { $_.id -eq $databaseName }
 
        if ($db -eq $null) {
            write-error "Could not find database in account"
            return
        } 
    
        $db 
    }

    function GetCollectionFromDocumentDB
    {
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory = $true)]
            [string]$accountName,
            [Parameter(Mandatory = $true)]
            [string]$connectionKey,
            [Parameter(Mandatory = $true)]
            [string]$databaseName,
            [Parameter(Mandatory = $true)]
            [string]$collectionName
        )
 
        $rootUri = "https://" + $accountName + ".documents.azure.com"   
        $apiDate = GetUTDate

        $db = GetDatabaseFromDocumentDB -accountName $AccountName -connectionKey $ConnetionKey -databaseName $DatabaseName
    
        $dbname = "dbs/" + $databaseName
        $collection = GetCollections -dbname $dbname | where { $_.id -eq $collectionName }
     
        if($collection -eq $null){
            write-error "Could not find collection in database"
            return
        }
 
        $collection
    }


     # ---------------------------------------------------------------------
     #          Helper Functions
     #----------------------------------------------------------------------

  
    function GetKey([string]$Verb = '',[string]$ResourceId = '',[string]$ResourceType = '',[string]$Date = '',[string]$masterKey = '') 
    {
        $keyBytes = [System.Convert]::FromBase64String($masterKey) 
        $text = @($Verb.ToLowerInvariant() + "`n" + $ResourceType.ToLowerInvariant() + "`n" + $ResourceId + "`n" + $Date.ToLowerInvariant() + "`n" + "`n")
        $body =[Text.Encoding]::UTF8.GetBytes($text)
        $hmacsha = new-object -TypeName System.Security.Cryptography.HMACSHA256 -ArgumentList (,$keyBytes) 
        $hash = $hmacsha.ComputeHash($body)
        $signature = [System.Convert]::ToBase64String($hash)
 
        [System.Web.HttpUtility]::UrlEncode($('type=master&ver=1.0&sig=' + $signature))
    }

     function BuildHeaders([string]$action = "get",[string]$resType, [string]$resourceId)
     {
        $authz = GetKey -Verb $action -ResourceType $resType -ResourceId $resourceId -Date $apiDate -masterKey $connectionKey
        
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", $authz)
        $headers.Add("x-ms-version", '2015-12-16')
        $headers.Add("x-ms-date", $apiDate) 
        $headers
    }
 
    function GetUTDate() 
    {
        $date = get-date
        $date = $date.ToUniversalTime();
        return $date.ToString("r", [System.Globalization.CultureInfo]::InvariantCulture);
    }
 
    function GetDatabases() 
    {
        $uri = $rootUri + "/dbs"
 
        $headers = BuildHeaders -resType dbs
 
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        $response.Databases
 
        Write-Host ("Found " + $Response.Databases.Count + " Database(s)")
    }

    function GetCollections([string]$dbname)
    {
        $uri = $rootUri + "/" + $dbname + "/colls"

        $headers = BuildHeaders -resType colls -resourceId $dbname

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        $response.DocumentCollections

        Write-Host ("Found " + $Response.DocumentCollections.Count + " DocumentCollection(s)")
    }

    function PostDocument([string]$document, [string]$dbname, [string]$collection)
    {
        $collName = "dbs/"+$dbname+"/colls/" + $collection

        $uri = $rootUri + "/" + $collName + "/docs"

        $headers = BuildHeaders -action Post -resType docs -resourceId $collName
        $headers.Add("x-ms-documentdb-is-upsert", "true")
     
        $response = Invoke-RestMethod $uri -Method Post -Body $document -ContentType 'application/json' -Headers $headers
        #$response
       
        Write-Host ("Posted document into Collection " + $collection + " in DB " + $databaseName)
    }