# Azure API Management Developer Portal Import and Export Actions

GitHub Action for importing and exporting Azure API Management Developer Portal content.
This action encapsulates [scripts](https://github.com/JanneMattila/azure-api-management-developer-portal-import-and-export-scripts)
that handle the developer portal content import and export functionality.

## Examples

You can combine these actions with `actions/upload-artifact` and
`actions/download-artifact` actions for easier moving the developer portal
content between jobs.

```yml
#...
    - name: Upload developer portal as artifact
      uses: jannemattila/azure-api-management-developer-portal-action@main
      with:
        name: portal

    - name: Upload developer portal as artifact
      uses: actions/upload-artifact@v2.2.4
      with:
        name: portal
        path: 
        if-no-files-found: error
```
