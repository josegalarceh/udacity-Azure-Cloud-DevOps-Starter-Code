# Azure Infrastructure Operations Project: Deploying a scalable IaaS web server in Azure

### Introduction
For this project, you will write a Packer template and a Terraform template to deploy a customizable, scalable web server in Azure.

### Getting Started
1. Clone this repository

2. Create your infrastructure as code

3. Update this README to reflect how someone would use your code.

### Dependencies
1. Create an [Azure Account](https://portal.azure.com) 
2. Install the [Azure command line interface](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
3. Install [Packer](https://www.packer.io/downloads)
4. Install [Terraform](https://www.terraform.io/downloads.html)

### Instructions
1. Validate that they have all the tools installed (dependencies).
    az --version
    packer --version
    terraform --version
2. Clone this repo.
3. Create a Service Principal on Azure portal, with the Owner suscription role and a secret. Save the Aplication ID (Client ID) and the Secret Value (Client Secret).
4. Create a Resource Group on Azure portal, with the name rgPacker
5. Complete and save the values on the file 'servicePrincipal.sh' with the service principal data (Client ID and Client Secret), Suscription ID and tenant ID. Then execute:
    ./servicePrincipal.sh
6. Go to subfolder 'azurePolicy' and run:
    az policy definition create -n 'tagging-policy' --display-name 'Audit Resources with tags' --description 'Enforces a required tag and its value.' --rules azurePolicyRules.json --params azurePolicyParameters.json --mode Indexed --debug
    az policy assignment create --name 'tagging-policy' --scope "/subscriptions/${SUBSCRIPTION_ID}" --policy "tagging-policy" --params "{'tagName':{'value': 'role'}}"
    az policy assignment list    
7. Go to subfolder 'packerTemplate' and run:
    packer build server.json
8. Get and save the image ID, execute the following command:
    az image list --resource-group rgPacker -o json | jq .'[]'.id
8. Go to subfolder terraformFiles, and personalice the terraform.tfvars file with your values, then run:
    terraform init
    terraform validate
    terraform plan -out solution.plan
    terraform apply -auto-approve

9. validate the web server, make a curl over the ip
    curl <IP of the load balancer>

10. If all the deploy is ok and done, then clean your resources. Inside the subfolder terraformFile run:
    terraform destroy 

11. In the azure Portal, delete the resource group rgPacker


### Output

1. When create the image of the Virtual machine with the step 7 of the instruction, the output show you the imageID, save it:
    ManagedImageId: /subscriptions/<suscription id>/resourceGroups/rgPacker/providers/Microsoft.Compute/images/Ubuntu_image_1804_lts

2. When deploy the infraestructure, with the step 8 of the instruccions, the output of the terraform plan, show what will deploy. The output of the terraform apply show the result of the deploy and the public IP of the service, save it:
    public_ip = [
      [
        "40.75.88.61",
      ],
    ]
3. When validate the service, the response of the curl may be:
    Hello Wold!
