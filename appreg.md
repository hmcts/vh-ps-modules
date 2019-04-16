Azure Active Directory Application Registration and Provisioning

Azure Active Directory Application Registration (AAD App Registration) and configuration can be performed by setting up a provisioning job in Azure DevOps.

Everything starts with a GithHub repository that contains build definition in azure-pipelines.yml, configuration for AAD Resource Access that is stored in resourceAccess.json, infrastructure code as Azure Resource Manager template for provisioning a website Infrastructure/azuredeploy.json.

Example app provisioning GitHub repo can be found here. You can copy the repo’s content to your application provisioning repo and amend accordingly.
GitHub repository

Once GitHub repository has been created you need to configure it accordingly:

    Collaborators & teams
        Reform - Read
        VH - Admin
        DevOps - Admin
    [Virtual Hearings > Azure Active Directory Application Regisration > image2019-2-28_14-24-40.png]
    Branches
        master - Require pull request reviews before merging
    [Virtual Hearings > Azure Active Directory Application Regisration > image2019-2-28_14-25-56.png] 

You need to add the correct teams to the repository so that members form these teams can edit the repo's content and so that Azure DevOps pipelines can checkout the source and report back the status of builds.

[Virtual Hearings > Azure Active Directory Application Regisration > image2019-2-28_14-27-38.png]
Build definition - azure-pipelines.yml

The content of azure-pipelines.yml defines the build pipeline for AAD App registration and Web App provisioning. As an example we can provision new application vh-example-api. In the azure-pipelines.yml file we need to update two variables accordingly - appName, aadAppReplyUrls.

variables:
  - group: 'vh-vsts-automation'  # variable group
  - group: 'Azure AD Tenant - hearings.reform.hmcts.net'
  - group: 'vh-hearings-ssl-certificates'
  - group: 'vh-hearings-reform-hmcts-net-dns-zone'

  - name: appName 
    value: vh-example-api # name of the app to be registered and provisioned

  - name: WebSiteName
    value: $(appName)-$(environmentName) # web site name "$(environmentName)" is set during runtime from GUI. 

  - name: aadAppReplyUrls
    value: https://$(WebSiteName)$(AzureAppServiceWebSiteCustomDomainName)/ #CSV list of replay urls

# GitHub Repo that conatins build templates. Reference https://docs.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=vsts#using-other-repositories
resources:
  repositories:
  - repository: azureDevOpsTemplates
    type: github
    name: hmcts/azure-devops-templates
    #ref: refs/heads/master  # ref name to use, defaults to 'refs/heads/master'
    endpoint: 'GitHubDevOps'

trigger:
- master
pr:
- master

jobs:
- template: jobs/aadAppRegistration.yml@azureDevOpsTemplates # Template reference
  parameters:
    appName: $(appName)
    aadAppReplyUrls: $(aadAppReplyUrls)

AAD Resource access - resourceAccess.json

If the registered application requires access to Microsoft Grap API this can be granted using the AAD GUI as shown below but the preferred way is to use resourceAccess.json. By using resourceAccess.json we can source control the permissions and this will guarantee consistency across all environments.

Example resourceAccess.json:

{
    "requiredResourceAccess": [
        {
            "resourceAppName": "Microsoft.Azure.ActiveDirectory",
            "resourceAppId": "00000002-0000-0000-c000-000000000000",
            "resourceAccess": [
                {
                    "resourceAccessName": "Sign in and read user profile",
                    "id": "311a71cc-e848-46a1-bdf8-97ff7156d8e6",
                    "type": "Scope"
                }
            ]
        }
    ]
}


GUI:

[Virtual Hearings > Azure Active Directory Application Regisration > image2019-2-28_15-20-56.png]
GUI Manifest:

[Virtual Hearings > Azure Active Directory Application Regisration > image2019-2-28_15-21-45.png]
Group Membership Claims

To add Group Membership Claims to AAD app a new variable has to be added to the yaml build pipeline:

variables:
	- name: groupMembershipClaims # Available values: SecurityGroup, All
  	  value: SecurityGroup  


jobs:
- template: jobs/aadAppRegistration.yml@azureDevOpsTemplates # Template reference
  parameters:
    appName: $(appName)
    aadAppReplyUrls: $(aadAppReplyUrls)
    groupMembershipClaims: $(groupMembershipClaims)

Full template example - https://github.com/hmcts/vh-example-api-provisioning/blob/master/azure-pipelines.yml
Infrastructure

Each provisioning project has to have the Infrastructure code. This ARM template will automatically provision a WebApp that will be used during the actual application deployment. In most cases default values in the infrastructure code will be enough.
Azure DevOps Pipeline

Once the repo has been created and the required content has been committed to the repo it's time to create a build pipeline that will be used to provision the application. The easiest way to create new build pipeline is to clone an existing pipeline. As an example we can use hmcts.vh-example-api-provisioning. When pipeline is cloned all the variables and variable groups required for running the provisioning job get cloned as well. It is mandatory to link the variable groups and variables defined in the build definition to the build pipeline! 
Cloning the pipeline

[Virtual Hearings > Azure Active Directory Application Regisration > image2019-2-28_15-26-40.png]

After cloning the pipeline we need to makes some adjustments:

    Pipeline Name - changed it to the same name as the repository / application name
    Service Connection - make sure it is set to GitHubDevOps
    Repository - make sure it is set to repository containing source code

[Virtual Hearings > Azure Active Directory Application Regisration > image2019-2-28_15-37-3.png]
Provisioning

Once the pipeline has been configured select "Save & Queue". This will now queue a job to provision the application for "Preview" environment. The "Preview" environment has been set as the default environment.

One the resourceAccess.json and azure-pipelines.yml files have been amended accordingly and tested in preview environment we can start provisioning the applications in other environments like sandbox. To provision the application in sandbox environment we need to change the "EnvironmentName" at queue time. To do that queue new job:

[Virtual Hearings > Azure Active Directory Application Regisration > image2019-2-28_15-55-40.png]


https://raw.githubusercontent.com/hmcts/vh-ps-modules/master/README.md




