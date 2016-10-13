 <#
FILE: DocumentDbHelper.ps1
DEV: yingxue

SUMMARY: DocumentDB helper functions: Get databases, collections; Post document; Query documents 
#>
    function Upsert-DocumentToDocumentDB
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
            [string]$documentContent
        )

        $rootUri = "https://$accountName.documents.azure.com" 
        $apiDate = GetUTDate
           
        UpsertDocument -document $documentContent -dbname $databaseName -collection $collectionName             
    }

    function Delete-DocumentFromDocumentDB
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
                [string]$documentName
            )
        
        $rootUri = "https://$accountName.documents.azure.com"   
        $apiDate = GetUTDate
         
        DeleteDocument -documentName $documentName -dbname $databaseName -collection $collectionName              
    }

    function Query-DocumentsFromDocumentDB
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
                [string]$queryString
            )
        
        $rootUri = "https://$accountName.documents.azure.com"   
        $apiDate = GetUTDate

        $docs = QueryDocuments -queryString $queryString -dbname $databaseName -collection $collectionName 
        $docs            
    }

    function Get-DatabaseFromDocumentDB
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
    
        $rootUri = "https://$accountName.documents.azure.com" 
        $apiDate = GetUTDate
 
        $db = GetDatabases | where { $_.id -eq $databaseName }
 
        if ($db -eq $null) {
            write-error "Could not find database in account"
            return
        } 
    
        $db 
    }

    function Get-CollectionFromDocumentDB
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
 
        $rootUri = "https://$accountName.documents.azure.com"   
        $apiDate = GetUTDate
    
        $dbname = "dbs/$databaseName"
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
        
        $headers = @{"Authorization" = $authz; "x-ms-version"='2015-12-16'; "x-ms-date" = $apiDate} 

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
        $uri = "$rootUri/dbs"
 
        $headers = BuildHeaders -resType dbs
 
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        $response.Databases
 
        Write-Host ("Found $Response.Databases.Count Database(s)")
    }

    function GetCollections([string]$dbname)
    {
        $uri = "$rootUri/$dbname/colls"

        $headers = BuildHeaders -resType colls -resourceId $dbname

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        $response.DocumentCollections

        Write-Host ("Found $Response.DocumentCollections.Count DocumentCollection(s)")
    }

    function UpsertDocument([string]$document, [string]$dbname, [string]$collection)
    {
        $collName = "dbs/$dbname/colls/$collection"

        $uri = "$rootUri/$collName/docs"

        $headers = BuildHeaders -action Post -resType docs -resourceId $collName
        $headers.Add("x-ms-documentdb-is-upsert", "true")
     
        $response = Invoke-RestMethod $uri -Method Post -Body $document -ContentType 'application/json' -Headers $headers
           
        Write-Host ("Upserted document into Collection $collection in DB $databaseName")
    }

    function DeleteDocument([string]$documentName, [string]$dbname, [string]$collection)
    {       
        $docName = "dbs/$dbname/colls/$collection/docs/$documentName"

        $uri = "$rootUri/$docName"

        $headers = BuildHeaders -action Delete -resType docs -resourceId $docName

        $response = Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers
             
        Write-Host ("Deleted document $documentName from Collection $collection in DB $databaseName")
    }

    function QueryDocuments([string]$queryString, [string]$dbname, [string]$collection)
    {
        $collName = "dbs/$dbname/colls/$collection"

        $uri = "$rootUri/$collName/docs"

        $headers = BuildHeaders -action Post -resType docs -resourceId $collName
        $headers.Add("x-ms-documentdb-isquery", "true")
     
        $response = Invoke-RestMethod $uri -Method Post -Body $queryString -ContentType 'application/query+json' -Headers $headers
        $response.Documents

        Write-Host ("Queried document(s) into Collection $collection in DB $databaseName")
    }