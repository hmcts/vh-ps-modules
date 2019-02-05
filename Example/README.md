`access.json` is used by Set-AzureADResourceAccessV2.ps1 

Powershell cmdlet to automate Azure AD Resource access like Microsoft Graph and Windows Azure Active Directory. Application registration permissions can can be stored in a json file.

**How it works:**

Call `Set-AzureADResourceAccessV2` Powershell Cmdlet, provide app name and location of the json file that contains the required permissions. The cmdlet will add missing permissions from the json to the Application Regitration.

`Set-AzureADResourceAccessV2 -$resourceAccessDefinition .\access.json -azureAdAppName "vh_app_jb_preview"`

**json file example**

```json
{
    "requiredResourceAccess": [
        {
            "resourceAppName": "Microsoft.Azure.ActiveDirectory",
            "resourceAppId": "00000002-0000-0000-c000-000000000000",
            "resourceAccess": [
                {
                    "resourceAccessName": "some permission name",
                    "id": "311a71cc-e848-46a1-bdf8-97ff7156d8e6",
                    "type": "Scope"
                },
                {
                    "resourceAccessName": "some permission name",
                    "id": "78c8a3c8-a07e-4b9e-af1b-b5ccab50a175",
                    "type": "Role"
                },
                {
                  "id": "5778995a-e1bf-45b8-affa-663a9f3f4d04",
                  "type": "Role"
                }
            ]
        },
        {
            "resourceAppName": "Microsoft.Graph",
            "resourceAppId": "00000003-0000-0000-c000-000000000000",
            "resourceAccess": [
                {
                    "resourceAccessName": "some permission name",
                    "id": "5b567255-7703-4780-807c-7be8301ae99b",
                    "type": "Role"
                },
                {
                    "resourceAccessName": "some permission name",
                    "id": "5f8c59db-677d-491f-a6b8-5f174b11ec1d",
                    "type": "Scope"
                },
                {
                    "resourceAccessName": "some permission name",
                    "id": "741f803b-c850-494e-b5df-cde7c675a1ca",
                    "type": "Role"
                },
                {
                    "resourceAccessName": "some permission name",
                    "id": "62a82d76-70ea-41e2-9197-370581804d09",
                    "type": "Role"
                }
            ]
        }
    ]
}
```



**Before**
GUI
![image](https://user-images.githubusercontent.com/38721775/52266617-c2815100-292e-11e9-9913-6176b312a91e.png)

Manifest
![image](https://user-images.githubusercontent.com/38721775/52266673-e349a680-292e-11e9-940b-bf24c80b88b3.png)

**After**
GUI
![image](https://user-images.githubusercontent.com/38721775/52269994-8bfc0400-2937-11e9-9f72-3aa7b866cb0c.png)

Manifest
![image](https://user-images.githubusercontent.com/38721775/52270024-a33af180-2937-11e9-80ef-ad0315f39450.png)


