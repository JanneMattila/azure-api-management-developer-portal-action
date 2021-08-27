# Azure API Management Developer Portal Import and Export Actions

GitHub Action for importing and exporting Azure API Management Developer Portal content.
This action encapsulates [scripts](https://github.com/JanneMattila/azure-api-management-developer-portal-import-and-export-scripts)
that handle the developer portal content import and export functionality.

## Examples

You need to authenticate with Azure before you can use this task in your workflow.
Follow these [instructions](https://github.com/Azure/login) on how to
use `azure/login` task.

You can combine these actions with `actions/upload-artifact` and
`actions/download-artifact` actions for easier moving the developer portal
content between jobs.

```yml
#...
    - uses: azure/login@v1
      with:
        creds: '${{ secrets.AZURE_CREDENTIALS }}'
        enable-AzPSSession: true

    - id: apim-export
      name: Export developer portal content
      uses: jannemattila/azure-api-management-developer-portal-action@main
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
