Param (
    [Parameter(Mandatory = $true, HelpMessage = "Direction of transfer either 'Import' or 'Export'")] 
    [ValidateSet("Import", "Export")]
    [string] $Direction,

    [Parameter(Mandatory = $true, HelpMessage = "Resource group of Azure API MAnagement")] 
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "Azure API Management Name")] 
    [string] $APIMName,

    [Parameter(Mandatory = $true, HelpMessage = "Folder used for storing the developer portal content")] 
    [string] $Folder
)

Import-APIMDeveloperPortal (
    [Parameter(Mandatory = $true, HelpMessage = "Resource group of API MAnagement")] 
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "API Management Name")] 
    [string] $APIMName,

    [Parameter(Mandatory = $true, HelpMessage = "Import folder")] 
    [string] $ImportFolder
)
{
    $ErrorActionPreference = "Stop"

    "Importing Azure API Management Developer portal content from: $ImportFolder"
    $mediaFolder = (Resolve-Path (Join-Path -Path $ImportFolder -ChildPath "Media")).Path
    $dataFile = Join-Path -Path $ImportFolder -ChildPath "data.json"

    if ($false -eq (Test-Path $ImportFolder)) {
        throw "Import folder path was not found: $ImportFolder"
    }

    if ($false -eq (Test-Path $mediaFolder)) {
        throw "Media folder path was not found: $mediaFolder"
    }

    if ($false -eq (Test-Path $dataFile)) {
        throw "Data file was not found: $dataFile"
    }

    "Reading $dataFile"
    $contentItems = Get-Content -Encoding utf8  -Raw -Path $dataFile | ConvertFrom-Json -AsHashtable
    $contentItems | Format-Table -AutoSize

    $apiManagement = Get-AzApiManagement -ResourceGroupName $ResourceGroupName -Name $APIMName
    $developerPortalEndpoint = "https://$APIMName.developer.azure-api.net"

    if ($null -ne $apiManagement.DeveloperPortalHostnameConfiguration) {
        # Custom domain name defined
        $developerPortalEndpoint = "https://" + $apiManagement.DeveloperPortalHostnameConfiguration.Hostname
        $developerPortalEndpoint
    }

    $ctx = Get-AzContext
    $ctx.Subscription.Id

    $baseUri = "subscriptions/$($ctx.Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/service/$APIMName"
    $baseUri

    "Processing clean up of the target content"
    $contentTypes = (Invoke-AzRestMethod -Path "$baseUri/contentTypes?api-version=2019-12-01" -Method GET).Content | ConvertFrom-Json
    foreach ($contentTypeItem in $contentTypes.value) {
        $contentTypeItem.id
        $contentType = (Invoke-AzRestMethod -Path "$baseUri/$($contentTypeItem.id)/contentItems?api-version=2019-12-01" -Method GET).Content | ConvertFrom-Json

        foreach ($contentItem in $contentType.value) {
            $contentItem.id
            Invoke-AzRestMethod -Path "$baseUri/$($contentTypeItem.id)?api-version=2019-12-01" -Method DELETE
        }
        Invoke-AzRestMethod -Path "$baseUri/$($contentTypeItem.id)/contentItems?api-version=2019-12-01" -Method DELETE
    }

    "Processing clean up of the target storage"
    $storage = (Invoke-AzRestMethod -Path "$baseUri/portalSettings/mediaContent/listSecrets?api-version=2019-12-01" -Method POST).Content | ConvertFrom-Json
    $containerSasUrl = [System.Uri] $storage.containerSasUrl
    $storageAccountName = $containerSasUrl.Host.Split('.')[0]
    $sasToken = $containerSasUrl.Query
    $contentContainer = $containerSasUrl.GetComponents([UriComponents]::Path, [UriFormat]::SafeUnescaped)

    $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
    Set-AzCurrentStorageAccount -Context $storageContext

    $totalFiles = 0
    $continuationToken = $null

    $allBlobs = New-Object Collections.Generic.List[string]
    do {
        $blobs = Get-AzStorageBlob -Container $contentContainer -MaxCount 1000 -ContinuationToken $continuationToken
        "Found $($blobs.Count) files in current batch."
        $blobs
        $totalFiles += $blobs.Count
        if (0 -eq $blobs.Length) {
            break
        }

        foreach ($blob in $blobs) {
            $allBlobs.Add($blob.Name)
        }
    
        $continuationToken = $blobs[$blobs.Count - 1].ContinuationToken;
    }
    while ($null -ne $continuationToken)

    foreach ($blobName in $allBlobs) {
        "Removing $blobName"
        Remove-AzStorageBlob -Blob $blobName -Container $contentContainer -Force
    }

    "Removed $totalFiles files from container $contentContainer"
    "Clean up completed"

    "Uploading content"
    foreach ($key in $contentItems.Keys) {
        $key
        $contentItem = $contentItems[$key]
        $body = $contentItem | ConvertTo-Json -Depth 100

        Invoke-AzRestMethod -Path "$baseUri/$key`?api-version=2019-12-01" -Method PUT -Payload $body
    }

    "Uploading files"
    $stringIndex = ($mediaFolder + [System.IO.Path]::DirectorySeparatorChar).Length
    Get-ChildItem -File -Recurse $mediaFolder `
    | ForEach-Object { 
        $name = $_.FullName.Substring($stringIndex)
        Write-Host "Uploading file: $name"
        Set-AzStorageBlobContent -File $_.FullName -Blob $name -Container $contentContainer
    }

    "Publishing developer portal"
    $revision = [DateTime]::UtcNow.ToString("yyyyMMddHHmm")
    $data = @{
        properties = @{
            description = "Migration $revision"
            isCurrent   = $true
        }
    }
    $body = ConvertTo-Json $data
    $publishResponse = Invoke-AzRestMethod -Path "$baseUri/portalRevisions/$($revision)?api-version=2019-12-01" -Method PUT -Payload $body
    $publishResponse

    if (202 -eq $publishResponse.StatusCode) {
        "Import completed"
        return
    }

    throw "Could not publish developer portal"
}

Export-APIMDeveloperPortal (
    [Parameter(Mandatory = $true, HelpMessage = "Resource group of API MAnagement")] 
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "API Management Name")] 
    [string] $APIMName,

    [Parameter(Mandatory = $true, HelpMessage = "Export folder")] 
    [string] $ExportFolder
)
{
    $ErrorActionPreference = "Stop"

    "Exporting Azure API Management Developer portal content to: $ExportFolder"
    $mediaFolder = Join-Path -Path $ExportFolder -ChildPath "Media"
    mkdir $ExportFolder -Force
    mkdir $mediaFolder -Force

    $ctx = Get-AzContext
    $ctx.Subscription.Id
    $baseUri = "subscriptions/$($ctx.Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/service/$APIMName"
    $baseUri

    $contentItems = @{ }
    $contentTypes = (Invoke-AzRestMethod -Path "$baseUri/contentTypes?api-version=2019-12-01" -Method GET).Content | ConvertFrom-Json

    foreach ($contentTypeItem in $contentTypes.value) {
        $contentTypeItem.id
        $contentType = (Invoke-AzRestMethod -Path "$baseUri/$($contentTypeItem.id)/contentItems?api-version=2019-12-01" -Method GET).Content | ConvertFrom-Json

        foreach ($contentItem in $contentType.value) {
            $contentItem.id
            $contentItems.Add($contentItem.id, $contentItem)    
        }
    }

    $contentItems
    $contentItems | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $ExportFolder -ChildPath "data.json")

    $storage = (Invoke-AzRestMethod -Path "$baseUri/portalSettings/mediaContent/listSecrets?api-version=2019-12-01" -Method POST).Content | ConvertFrom-Json
    $containerSasUrl = [System.Uri] $storage.containerSasUrl
    $storageAccountName = $containerSasUrl.Host.Split('.')[0]
    $sasToken = $containerSasUrl.Query
    $contentContainer = $containerSasUrl.GetComponents([UriComponents]::Path, [UriFormat]::SafeUnescaped)

    $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
    Set-AzCurrentStorageAccount -Context $storageContext

    $totalFiles = 0
    $continuationToken = $null
    do {
        $blobs = Get-AzStorageBlob -Container $contentContainer -MaxCount 1000 -ContinuationToken $continuationToken
        "Found $($blobs.Count) files in current batch."
        $blobs
        $totalFiles += $blobs.Count
        if (0 -eq $blobs.Length) {
            break
        }

        foreach ($blob in $blobs) {
            Get-AzStorageBlobContent -Blob $blob.Name -Container $contentContainer -Destination (Join-Path -Path $mediaFolder -ChildPath $blob.Name)
        }
    
        $continuationToken = $blobs[$blobs.Count - 1].ContinuationToken;
    }
    while ($null -ne $continuationToken)

    "Downloaded $totalFiles files from container $contentContainer"
    "Export completed"
}

if ([string]::IsNullOrEmpty($Folder))
{
    # Let's create temporary folder for the content
    $Folder = Join-Path $Env:Temp "apim-export"
}

"Running $Direction for $APIMName in $ResourceGroupName using folder $Folder."

if ($Direction -eq "Import")
{
    Import-APIMDeveloperPortal `
        -ResourceGroupName $ResourceGroupName `
        -APIMName $APIMName `
        -ImportFolder $Folder
}
else {
    Export-APIMDeveloperPortal `
        -ResourceGroupName $ResourceGroupName `
        -APIMName $APIMName `
        -ImportFolder $Folder 
}


"::set-output name=path::$($Folder)"
