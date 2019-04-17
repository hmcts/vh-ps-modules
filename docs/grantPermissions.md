<link href="../images/style.css" rel="stylesheet"></link>

# Grant Permissions

If Azure Active Directory Application Application requires access to a resource like Microsoft Graph API, Azure AD, Office 365 this can be configured under API access -> Required permissions.

![Azure AD App Registration API Access](../images/aadAppResourceAccessUi.png#thumbnail)

Once the desired API access has been selected and required permissions have been set an admin has to give consent to allow the Azure AD Application Registration to interact with API by **Granting Permissions**.

![Azure AD App Registration API Grant Permissions](../images/aadAppResourceAccessGrantPermissions.png#thumbnail)

## Types of permissions

### Azure AD defines two kinds of permissions

* Delegated permissions - Are used by apps that have a signed-in user present. For these apps, either the user or an administrator consents to the permissions that the app requests and the app is delegated permission to act as the signed-in user when making calls to an API. Depending on the API, the user may not be able to consent to the API directly and would instead require an administrator to provide "admin consent".

* Application permissions - Are used by apps that run without a signed-in user present; for example, apps that run as background services or daemons. Application permissions can only be consented by an administrator because they are typically powerful and allow access to data across user-boundaries, or data that would otherwise be restricted to administrators.

### Effective permissions are the permissions that your app will have when making requests to an API

* For delegated permissions, the effective permissions of your app will be the least privileged intersection of the delegated permissions the app has been granted (through consent) and the privileges of the currently signed-in user. Your app can never have more privileges than the signed-in user. Within organizations, the privileges of the signed-in user may be determined by policy or by membership in one or more administrator roles. To learn which administrator roles can consent to delegated permissions, see Administrator role permissions in Azure AD. For example, assume your app has been granted the `User.ReadWrite.All` delegated permission in Microsoft Graph. This permission nominally grants your app permission to read and update the profile of every user in an organization. If the signed-in user is a global administrator, your app will be able to update the profile of every user in the organization. However, if the signed-in user is not in an administrator role, your app will be able to update only the profile of the signed-in user. It will not be able to update the profiles of other users in the organization because the user that it has permission to act on behalf of does not have those privileges.

* For application permissions, the effective permissions of your app are the full level of privileges implied by the permission. For example, an app that has the `User.ReadWrite.All` application permission can update the profile of every user in the organization.

## Automation

The process of granting permissions has been automated. Users are not required to use **Grant Permissions** from Azure AD UI. This happens automatically when the application is provisioned using a pipeline as described in [Azure Active Directory Application Registration and Provisioning](azureADApplicationRegistration.md).

### Behind the screen
When user selects **Grant Permissions** form Azure AD UI a process takes place that creates a service principal and marries it to Azure AD Application Registration app.