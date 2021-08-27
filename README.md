# Azure API Management Developer Portal Import and Export Actions

GitHub Action for importing and exporting Azure API Management Developer Portal content.
This action encapsulates [scripts](https://github.com/JanneMattila/azure-api-management-developer-portal-import-and-export-scripts)
that handle the developer portal content import and export functionality.

## Examples

You need to authenticate with Azure before you can use this task in your workflow.
Follow these [instructions](https://github.com/Azure/login) on how to
use `azure/login` task.

You can combine these actions with 
[actions/upload-artifact](https://github.com/actions/upload-artifact) and
[actions/download-artifact](https://github.com/actions/download-artifact)
actions for moving the developer portal content between jobs.

### Export to artifact

```yml
#...
    - uses: azure/login@v1
      with:
        creds: '${{ secrets.AZURE_CREDENTIALS }}'
        enable-AzPSSession: true

    - id: apim-export
      name: Export developer portal content
      uses: jannemattila/azure-api-management-developer-portal-action@v1
      with:
        apimName: contoso # Your Azure API Management instance name
        resourceGroup: apim-dev-rg # Name of the resource group
        direction: Export # Export or Import
        folder: somepath # (optional) Folder used for storing the developer portal content

    - name: Upload developer portal content as artifact
      uses: actions/upload-artifact@v2.2.4
      with:
        name: portal
        path: ${{ steps.apim-export.outputs.folder }}
        if-no-files-found: error
```

### Import from artifact

```yml
#...
      - name: Download developer portal content from artifact
        uses: actions/download-artifact@v2.0.10
        with:
          name: portal
          path: portal

      - uses: azure/login@v1
        with:
          creds: '${{ secrets.AZURE_CREDENTIALS }}'
          enable-AzPSSession: true

      - id: apim-import
        name: Import developer portal content
        uses: jannemattila/azure-api-management-developer-portal-action@v1
        with:
          apimName: ${{ secrets.APIM }} # Your Azure API Management instance name
          resourceGroup: ${{ secrets.APIM_RG }} # Name of the resource group
          direction: Import # Import to this instance
          folder: portal
```

### Full workflow example

This example demonstrates the use of export from `test` environment
and then importing the content to `prod` environment. You
can combine this with approvals and other validations. 

```yml
name: "Azure API Management Developer Portal Export-Import"
on:
  workflow_dispatch:

jobs:
  Export:
    runs-on: ubuntu-latest
    steps:
    - uses: azure/login@v1
      with:
        creds: '${{ secrets.AZURE_CREDENTIALS }}'
        enable-AzPSSession: true
        
    - id: apim-export
      name: Export developer portal content
      uses: jannemattila/azure-api-management-developer-portal-action@v1
      with:
        apimName: ${{ secrets.APIM_TEST }} # Your test Azure API Management instance name
        resourceGroup: ${{ secrets.APIM_TEST_RG }} # Name of the resource group
        direction: Export # Export or Import
        
    - name: Upload developer portal content as artifact
      uses: actions/upload-artifact@v2.2.4
      with:
        name: portal
        path: ${{ steps.apim-export.outputs.folder }}
        if-no-files-found: error

  Release:
    runs-on: ubuntu-latest
    needs: Export
    steps:
      - name: Download developer portal content from artifact
        uses: actions/download-artifact@v2.0.10
        with:
          name: portal
          path: portal

      - uses: azure/login@v1
        with:
          creds: '${{ secrets.AZURE_CREDENTIALS }}'
          enable-AzPSSession: true

      - id: apim-import
        name: Import developer portal content
        uses: jannemattila/azure-api-management-developer-portal-action@v1
        with:
          apimName: ${{ secrets.APIM_PROD }} # Your production Azure API Management instance name
          resourceGroup: ${{ secrets.APIM_PROD_RG }} # Name of the production resource group
          direction: Import # Import to this instance
          folder: portal
```
