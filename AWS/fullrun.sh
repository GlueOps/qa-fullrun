#!/bin/bash

yolo

if [ -f /workspaces/glueops/saved_variables ]; then
  . /workspaces/glueops/saved_variables
else
  unset FULLTENANT
  unset CLUSTER
  read -p "Enter your full tenant name: " FULLTENANT
  read -p "Enter your captain domain: " CLUSTER
  unset awsacc
  unset wafacc
  read -p "Enter your AWS account credentials: " awsacc
  read -p "Enter your WAF account credentials: " wafacc
  echo "FULLTENANT=$FULLTENANT" >> /workspaces/glueops/saved_variables
  echo "CLUSTER=$CLUSTER" >> /workspaces/glueops/saved_variables
  echo "awsacc=$awsacc" >> /workspaces/glueops/saved_variables
  echo "wafacc=$wafacc" >> /workspaces/glueops/saved_variables
fi

IFS='-' read -r compname rank city <<< "$wafacc"

# Split cluster name to different parts

IFS='.' read -r ENV TENANT DOMAIN <<< "$CLUSTER"

STATE_FILE="/workspaces/glueops/state.txt"

save_state() {
  echo "current_step=$current_step" > "$STATE_FILE"
}

if [[ -f "$STATE_FILE" ]]; then
  source "$STATE_FILE"
else
  current_step=0
fi

# Step 1
if [[ $current_step -le 0 ]]; then
 yolo
 cd /workspaces/glueops
 gh repo clone development-captains/$CLUSTER
 gh repo clone $FULLTENANT/deployment-configurations
 cd /workspaces/glueops/deployment-configurations
 git pull
 current_step=1
 save_state
fi

# Step 2
if [[ $current_step -le 1 ]]; then
 yolo
 cd /workspaces/glueops
 # Hints
 echo "1. Move to https://github.com/development-captains/$CLUSTER , find "AWS" >> "Deploy Kubernetes" , click on "Launch a CloudShell" hyperlink "
 echo "2. Move to https://github.com/development-captains/$CLUSTER in another tab , find "AWS" >> "Deploy Kubernetes" , execute bash account-setup.sh command in CloudShell "
 echo "3. Enter AWS account name ($awsacc) >> Enter another AWS account name ($wafacc) "
 echo "4. Move to codespace >> Create .env file by following hints from CloudShell (add all content between 1st and last rows) and save it in "$CLUSTER" repo "
 echo "5. Update tenant.tf (https://github.com/internal-GlueOps/development-infrastructure/blob/main/tenants/$TENANT/tf/tenant.tf) by inserting aws_access_key and aws_secret values from CloudShell , create new branch. "
 echo "6. Confirm changes in Terraform "
 read -n 1 -s -r -p "Press any key to continue when all actions above are done"
 cd /workspaces/glueops/$CLUSTER/terraform/kubernetes
 git fetch
 git pull
 cd /workspaces/glueops
 echo " Check wheter changes are applied in "platform.yaml" "
 current_step=2
 save_state
fi

# Step 3
if [[ $current_step -le 2 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 read -n 1 -s -r -p "Press any key to continue "
 cd /workspaces/glueops
 # 1st piece
 mkdir -p qa-fullrun/AWS/templates
 mkdir -p qa-fullrun/AWS/templates2
 unset AWSEKS
 read -p "Enter AWS/EKS version: " AWSEKS
 curl https://raw.githubusercontent.com/GlueOps/terraform-module-cloud-aws-kubernetes-cluster/refs/tags/$AWSEKS/glueops-tests/main.tf -o qa-fullrun/AWS/templates/main.tf 
 cd /workspaces/glueops/$CLUSTER
 source $(pwd)/.env
 cd /workspaces/glueops/$CLUSTER/terraform/kubernetes
 read -p "Enter arn:aws:iam number" value2
 render_templates() {
   local template_dir="$1"
   local target_dir="$PWD"

   # Create the target directory if it doesn't exist
   mkdir -p "$target_dir"

   # Loop through the template files in the template directory
   for template_file in "$template_dir"/*; do
     if [ -f "$template_file" ]; then
       # Extract the filename without the path
       template_filename=$(basename "$template_file")

       # Replace the placeholder with the user-entered value and save it to the target directory
       sed -e "s/761182885829/$value2/g" -e "s/\.\.\//git::https:\/\/github.com\/GlueOps\/terraform-module-cloud-aws-kubernetes-cluster.git?ref=$AWSEKS/g" "$template_file" > "$target_dir/$template_filename"
     fi
   done

   echo "main.tf is successfully created in $target_dir."
 }

 # Call the function with the template and target directories
 render_templates "../../../qa-fullrun/AWS/templates" 

 cd /workspaces/glueops/$CLUSTER

 source .env

 cd /workspaces/glueops/$CLUSTER/terraform/kubernetes/

 # 2nd piece

 terraform init

 terraform apply -auto-approve

 cd /workspaces/glueops

 aws eks update-kubeconfig --region us-west-2 --name captain-cluster --role-arn arn:aws:iam::$value2:role/glueops-captain-role

 sed -i 's/^#//' $CLUSTER/.env

 source /workspaces/glueops/$CLUSTER/.env

 kubectl get nodes

 kubectl delete daemonset -n kube-system aws-node

 cd /workspaces/glueops/$CLUSTER

 curl https://raw.githubusercontent.com/wiki/GlueOps/terraform-module-cloud-aws-kubernetes-cluster/calico.yaml.md -o ../qa-fullrun/AWS/templates2/calico.yaml 

 render_templates2() {
   local template_dir="$1"
   local target_dir="$PWD"

   # Create the target directory if it doesn't exist
   mkdir -p "$target_dir"

   # Loop through the template files in the template directory
   for template_file in "$template_dir"/*; do
     if [ -f "$template_file" ]; then
       # Extract the filename without the path
       template_filename=$(basename "$template_file")

       # Delete yaml markers
       sed '1d;$d' "$template_file" > "$target_dir/$template_filename"
     fi
   done

   echo "calico.yaml is successfully created in $target_dir."
 }

 render_templates2 "../qa-fullrun/AWS/templates2" 

 # 3d piece

 echo " Move to aws >> install calico "
 read -n 1 -s -r -p "Press any key when you are ready to perform step above "

 cd /workspaces/glueops/$CLUSTER

 captain_utils

 sed -i 's/    #//g' terraform/kubernetes/main.tf

 cd /workspaces/glueops/$CLUSTER/terraform/kubernetes

 terraform init

 terraform apply -auto-approve

 current_step=3
 save_state
fi

# Step 4
if [[ $current_step -le 3 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 cd /workspaces/glueops/$CLUSTER
 echo "1. Move to https://github.com/development-captains/$CLUSTER , find Deploying GlueOps the Platform >> Deploy ArgoCD , copy command , split the terminal , enter yolo, enter source /workspaces/glueops/$CLUSTER/.env , enter command in splited terminal , wait untill 3 of 3 argocd-redis-ha-server are ready , press ctrl + c (use kubectl get pods -n glueops-core command for monitoring).  "
 echo "2. Move back to https://github.com/development-captains/$CLUSTER , find Deploying GlueOps the Platform >> Deploy the GlueOps Platform , copy command , move back to splited terinal , enter command , wait untill all are sync (only one health status should be degraded ) , press ctrl + c (use kubectl get applications -n glueops-core for monitoring) ( if some of the apps are processing for long time then: 1. kubectl get certificates -A 2. kubectl delete pods --all -n glueops-core-cert-manager).  "
 echo "3. Close splited termminal  "
 current_step=4
 save_state
fi

# Step 5
if [[ $current_step -le 4 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 read -n 1 -s -r -p "Press any key to continue when all actions above are done"
 cd /workspaces/glueops/$CLUSTER
 kubectl get pods -n glueops-core-vault
 read -n 1 -s -r -p "Press any key to continue if all items above are working "
 cd /workspaces/glueops/
 source /workspaces/glueops/$CLUSTER/.env
 kubectl -n glueops-core-vault port-forward svc/vault-ui 8200:8200 &
 sleep 15  
 cd /workspaces/glueops/$CLUSTER/terraform/vault/configuration/
 terraform init && terraform apply -auto-approve
 sleep 10
 pkill -f "kubectl -n glueops-core-vault port-forward"
 sleep 30
 kubectl get applications -A
 read -n 1 -s -r -p " Press any key to continue if all items above are healthy. Secrets may become healthy with some delay. To check it again you need: split terminal , enter yolo , enter source /workspaces/glueops/$CLUSTER/.env , enter kubectl get applications -A ( if secrets are still degraded >> go to ArgoCD >> external secrets >> sync. If still degraded >> delete clustersecretstore) "
 current_step=5
 save_state
fi

# Step 6
if [[ $current_step -le 5 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 cd /workspaces/glueops/$CLUSTER/manifests

mkdir -p ../../qa-fullrun/AWS/manifeststemplates
curl https://raw.githubusercontent.com/GlueOps/qa-tools/v20240827/manifests-ecr-protected-script/templates/appproject.yaml -o ../../qa-fullrun/AWS/manifeststemplates/appproject.yaml
curl https://raw.githubusercontent.com/GlueOps/qa-tools/v20240827/manifests-ecr-protected-script/templates/appset.yaml -o ../../qa-fullrun/AWS/manifeststemplates/appset.yaml
curl https://raw.githubusercontent.com/GlueOps/qa-tools/v20240827/manifests-ecr-protected-script/templates/dockerregistry.yaml -o ../../qa-fullrun/AWS/manifeststemplates/dockerregistry.yaml
curl https://raw.githubusercontent.com/GlueOps/qa-tools/v20240827/manifests-ecr-protected-script/templates/ecr-regcred.yaml -o ../../qa-fullrun/AWS/manifeststemplates/ecr-regcred.yaml
curl https://raw.githubusercontent.com/GlueOps/qa-tools/v20240827/manifests-ecr-protected-script/templates/namespace.yaml -o ../../qa-fullrun/AWS/manifeststemplates/namespace.yaml
curl https://raw.githubusercontent.com/GlueOps/qa-tools/v20240827/manifests-ecr-protected-script/templates/pullrequestapplicationset.yaml -o ../../qa-fullrun/AWS/manifeststemplates/pullrequestapplicationset.yaml


 # Function to render templates
 render_templates() {
   local template_dir="$1"
   local target_dir="$PWD"
  
   # Split cluster name to different parts

   IFS='.' read -r ENV TENANT DOMAIN <<< "$CLUSTER"


   unset process_file

   until [ "$process_file" == "yes" ] || [ "$process_file" == "no" ]; do
     # Ecrregcred manifest creating
     read -p "Do you want to create ecr-regcred.yaml manifest? Type 'yes' or 'no': " process_file

     # Checking of input
     if [ "$process_file" != "yes" ] && [ "$process_file" != "no" ]; then
       echo "Invalid input. Please enter 'yes' or 'no'."
     fi
   done

   # Define ecrregcred manifest fullname
   REGCRED="ecr-regcred.yaml"

   if [ "$process_file" == no ]; then
     echo "File processing skipped for $REGCRED."
   else
     read -p "Enter access-key-id for ecr-regcred: " valueid
     read -p "Enter secret-access-key: " valuesecret
   fi

   unset use_defaultorg
   unset use_defaultrepo
  
   until [ "$use_defaultorg" == "yes" ] || [ "$use_defaultorg" == "no" ]; do
     # Organization path
     read -p "Do you use default organization(example-tenant)? Type 'yes' or 'no': " use_defaultorg

     # Checking of input
     if [ "$use_defaultorg" != "yes" ] && [ "$use_defaultorg" != "no" ]; then
       echo "Invalid input. Please enter 'yes' or 'no'."
     fi
   done
  
   if [ "$use_defaultorg" == yes ]; then
     org_name="example-tenant"
   else
     read -p "Enter organization name: " org_name
   fi

   until [ "$use_defaultrepo" == "yes" ] || [ "$use_defaultrepo" == "no" ]; do
     # Repository path
     read -p "Do you use default repository (deployment-configurations)? Type 'yes' or 'no': " use_defaultrepo

     # Checking of input
     if [ "$use_defaultrepo" != "yes" ] && [ "$use_defaultrepo" != "no" ]; then
       echo "Invalid input. Please enter 'yes' or 'no'."
     fi
   done

   if [ "$use_defaultrepo" == yes ]; then
     repo_name="deployment-configurations"
   else
     read -p "Enter repository name: " repo_name
   fi

   # Create the target directory if it doesn't exist
   mkdir -p "$target_dir"

   # Loop through the template files in the template directory
   for template_file in "$template_dir"/*; do
     if [ -f "$template_file" ]; then
       # Extract the filename without the path
       template_filename=$(basename "$template_file")

       # Replace the placeholder with the user-entered value and save it to the target directory
       if  [ "$process_file" == yes ] || [ "$template_filename" != "$REGCRED" ]; then
         sed "s/cluster_env/$ENV/g; s/CLUSTER_VARIABLE/$CLUSTER/g; s/key_id/$valueid/g; s/key_value/$valuesecret/g; s/example-tenant/$org_name/g; s/deployment-configurations/$repo_name/g" "$template_file" > "$target_dir/$template_filename"
       fi
     fi
   done
   echo "Templates have been rendered and saved to $target_dir."
 }

 # Call the function with the template and target directories
 render_templates "../../qa-fullrun/AWS/manifeststemplates" 
 sleep 5
 yolo
 git status
 read -n 1 -s -r -p " Press any key to continue if you agree to add all the changes "
 git add -A
 git status
 read -n 1 -s -r -p " Press any key to continue if you agree to commit "
 git commit
 read -n 1 -s -r -p " Press any key to continue if you agree to push the changes "
 git push
 current_step=6
 save_state
fi

# Step 7
if [[ $current_step -le 6 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 cd /workspaces/glueops/$CLUSTER/manifests
 unset update

 until [ "$update" == "yes" ] || [ "$update" == "no" ]; do
   read -p "Do you want to update ArgoCD and GlueOps Platform? Type 'yes' or 'no': " update

   if [ "$update" != "yes" ] && [ "$update" != "no" ]; then
     echo "Invalid input. Please enter 'yes' or 'no'."
   fi
 done
 current_step=7
 save_state
fi

# Step 8
if [[ $current_step -le 7 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 if [ "$update" != "no" ]; then
  cd /workspaces/glueops/$CLUSTER/manifests
  echo -e "1. Move to https://github.com/GlueOps/terraform-module-cloud-multy-prerequisites. \n2. Select the required version (usually from branch). \n3. Move to https://github.com/internal-GlueOps/development-infrastructure/blob/main/tenants/$TENANT/tf/tenant.tf .\n4. Insert verison into the 2nd row of the code (after ref=).\n5. Save changes and manage them in Terraform."
  read -n 1 -s -r -p " Press any key to continue if all actions above are completed successfully"
  git pull
  cd /workspaces/glueops/$CLUSTER
  helm repo update
  read -p "Enter ArgoCD version: " ArgoCDv
  read -p "Enter helm-chart version: " Helmv
  kubectl apply -k "https://github.com/argoproj/argo-cd/manifests/crds?ref=$ArgoCDv"
  sleep 15
  helm upgrade argocd argo/argo-cd --version $Helmv -f argocd.yaml -n glueops-core
  echo -e "1. Move to ArgoCD (https://argocd.$CLUSTER/) and pay attention to the version on the left top near the logo after signing in. \n2. Split terminal , enter yolo , enter source /workspaces/glueops/$CLUSTER/.env , enter kubectl get pods -n glueops-core .\n3. Pods should be updated and no older than 5 mins "
  read -n 1 -s -r -p " Press any key to continue if steps above are completed you closed splited terminal."
  git pull
  read -p "Enter glueops-platform version: " gpv
  sleep 15
  helm upgrade glueops-platform glueops-platform/glueops-platform --version $gpv -f platform.yaml --namespace=glueops-core
  sleep 15
  git pull
 fi
 current_step=8
 save_state
fi

# Step 9
if [[ $current_step -le 8 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 cd /workspaces/glueops/$CLUSTER/manifests
 echo -e "1. Move to Argo CD (https://argocd.$CLUSTER).\n2. Login with github SSO (if still not logined in).\n3. Click to glueops-core/captain-manifests.\n4. Check whether all manifests are created (usually 8 on 2nd column) "
 read -n 1 -s -r -p " Press any key to continue if all manifests are present and working"
 echo -e "\n1. Move to https://github.com/settings/tokens .\n2. Click on "Example tenet regcred".\n3. Click on "Renegerate token". Repeat.\n4. Copy token. "
 read -n 1 -s -r -p " Press any key to continue if token is copied. Enter copied token and then GitHub username below"

 unset token_var
 unset username_var

 read -p "Token: " token_var
 read -p "Username: " username_var

 create-ghcr-regcred -u $username_var -t $token_var

 echo -e "1. Copy output, that has appeared above. \n2. Move to https://vault.$CLUSTER/ \n3. Relogin by entering "editor" role. \n4. Create new secret with following values: \npath for this secret: regcred; \nkey: .dockerconfigjson; \nkey value: output that is coppied from the previous step. \n5. Open ArgoCD >> captain manifests >> enter in "wordpress-stage" >> delete pod (in the far right) (there should be created new pod). \n6. Repeat the same actions with "wordpress-qa" and "wordpress-prod" "

 read -n 1 -s -r -p " Press any key to continue if all actions above are performed without issues"

 echo -e " Add secret to App. \n1. https://vault.$CLUSTER/ >> secret/ >> create secret: \n Path for this secret: hello-world-env-vars-app \n Key: GREETING_MESSAGE \n value: anything.\n2. Check wheter is value is visible in https://argocd.$CLUSTER (enter to captain-manifests app >> "Hello-world-env-vars-qa-public"). If it has degraded status - delete the pod and wait untill it refreshes.\n3. Go to Vault again >> create the new version of the secret >> enter another value.\n4. Go to Agro CD >> delete pod >> check changes. 
 If the page conten't is not changing - delete pod (pod must be new one)  "

 read -n 1 -s -r -p " Press any key to continue if all actions above are performed without issues"
 current_step=9
 save_state
fi

# Step 10
if [[ $current_step -le 9 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 cd /workspaces/glueops/$CLUSTER/manifests
 echo -e "Confirm all ArgoCD apps are healthy in UI: \n1. Move to argocd. \n2. Check the "SYNC STATUS" and the "HEALTH" status (in the left dropdown menu). \n3. Select "items per page: all" (right top corner). \n4. Check all apps manually (if some is out of sync - enter there >> try sync it manually).  "
 read -n 1 -s -r -p " Press any key to continue if all actions above are performed without issues"
 echo -e "\n Deploy test app from private repo (ghcr and ecr): \n1. Confirm all apps opening in AgroCD (captain manifests >> far right apps). \n2. Confirm that SSL works in every app.  "
 read -n 1 -s -r -p " Press any key to continue if all actions above are performed without issues"
 cd /workspaces/glueops

 # Repository and branch parameters
 read -p "Enter your temporary branch name: "  NEW_BRANCH
 FILE_PATH="index.html" # Change the file path if necessary

 # Clone a repository using the GitHub CLI
 gh repo clone $FULLTENANT/wordpress
 cd /workspaces/glueops/wordpress

 # Enter new content on the page
 read -p "Enter new content for the page " NEW_TEXT

 # File editing
 sed -i "26s|<h1>.*</h1>|<h1>${NEW_TEXT}</h1>|" $FILE_PATH

 # Creating a new branch, commit, and push
 git checkout -b $NEW_BRANCH
 git add $FILE_PATH
 git commit -m "Update index.html"
 git push --set-upstream origin $NEW_BRANCH

 # Creating a Pull Request through GitHub CLI and getting the URL
 PR_URL=$(gh pr create --title "Update text in index.html" --body "QA step" --base main --head $NEW_BRANCH)

 # Outputting the Pull Request URL
 echo "Follow next link to check PR bot: $PR_URL"

 # Pausing the script and asking whether to continue
 read -p "Have you completed all checks and wish to continue? (All input combinations except of "yes" will terminate the script) " answer
 if [ "$answer" != "yes" ]; then
     echo "Script stopped."
     exit 1
 fi

 # Merging the Pull Request
 PR_NUMBER=$(basename "$PR_URL")
 gh pr merge $PR_NUMBER --merge -d
 echo "Pull Request #${PR_NUMBER} is successfully merged and ${NEW_BRANCH} is deleted"

 # Instruct the user to wait for GitHub Actions to complete
 echo "Please follow https://github.com/$FULLTENANT/wordpress/actions to ensure the completion of GitHub Actions."

 # Wait for user input to continue
 read -n 1 -s -r -p "Press any key to continue after confirming that all actions have completed successfully."

 # Continue with the rest of the script
 echo "Continuing script..."

 # Comparing values
 echo "Compare the new tag from the last GlueOps bot message here (https://github.com/$FULLTENANT/deployment-configurations) with the last commit tag here (https://github.com/$FULLTENANT/wordpress) "

 # Wait for user input to continue
 read -n 1 -s -r -p "Press any key to continue in the case when tags are the same"

 # Continue with the rest of the script
 echo "Continuing script..."

 # Unset TAG_NAME in case it was set in a previous run
 unset TAG_NAME

 # Prompt the user to enter a tag name
 while true; do
     read -p "Enter the tag name for the release: " TAG_NAME
     if [ -n "$TAG_NAME" ]; then
         break
     else
         echo "Tag name cannot be empty. Please enter a valid tag name."
     fi
 done

 # Create a new tag
 git tag $TAG_NAME

 # Push the tag to the remote repository
 git push origin $TAG_NAME

 # Create a release using GitHub CLI
 gh release create $TAG_NAME --title "$TAG_NAME" --target main

 # Output the result
 echo "Release $TAG_NAME created with tag $TAG_NAME"

 # Instruct the user to wait for GitHub Actions to complete
 echo "Please follow https://github.com/$FULLTENANT/wordpress/actions to ensure the completion of GitHub Actions."

 # Wait for user input to continue
 read -n 1 -s -r -p "Press any key to continue after confirming that all actions have completed successfully."

 cd /workspaces/glueops/deployment-configurations

 git fetch

 git pull

 # Get 2 latest PR in deployment-configurations repo
 PR_IDS=$(gh pr list --limit 2 --state open --json number -q '.[].number')
 PR_ID_ARRAY=($PR_IDS)

 # Check if two PRs are found
 if [ ${#PR_ID_ARRAY[@]} -eq 2 ]; then
     # Merging the first PR
     gh pr merge ${PR_ID_ARRAY[0]} --merge --delete-branch

     # Merging the second PR
     gh pr merge ${PR_ID_ARRAY[1]} --merge --delete-branch
 else
     echo "Not found exactly two PRs."
     exit 1
 fi

 # Returning to the initial directory
 cd /workspaces/glueops

 echo -e "Move to ArgoCD and make sure that 3 apps are updated "

 read -n 1 -s -r -p " Press any key to continue if everything is okay "
 current_step=10
 save_state
fi

# Step 11
if [[ $current_step -le 10 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 cd /workspaces/glueops
 echo -e "Grafana / Loki \n1. https://grafana.$CLUSTER/ >> alerting(hamburger) >> alerting >> alert rules >> search by data sources: loki (should be 3 alerts). \n2. https://grafana.$CLUSTER/alerting/list - should be 1 required alert. \n3. Grafana >> hamburger >> dashboards >> ingress by Host >> watch correct IP tracking according own IP and right ammount of requests adding. \n4. https://grafana.$CLUSTER.rocks/ >> hamburger >> dashboards >> DevOps - ArgoCD >> check wheter all charts are functioning "
 read -n 1 -s -r -p " Press any key to continue if all steps above are completed"
 echo -e "\n Developer Regression - RBAC (USE incognito and the developer persona user (creds are in 1password)):\n ArgoCD:\n1. Try to delete pods from UI. \n2. Try to exec/terminal into pod. \n3. Try to delete an application.\n Grafana: \n1. Should not see a lot of the other options for Administration tab (only 4 options should be visible ).\n2. Load ingress by host dashboard (change time frame to last hour(s) so you can see some data in the dashboard).  "
 read -n 1 -s -r -p " Press any key to continue if all steps above are completed"
 current_step=11
 save_state
fi

# Step 22
if [[ $current_step -le 21 ]]; then
 yolo
 source /workspaces/glueops/$CLUSTER/.env
 cd /workspaces/glueops/$CLUSTER/manifests
 echo -e " You may perform next algorithms (AWS and GitHub) separately at the same time. Feel free to combine them in order to reduce time consuming.\n AWS teardown:\n1. Move to https://github.com/development-captains/$CLUSTER .\n2. Find Teardown Kubernetes >> AWS Teardown.\n3. Copy nuke command.\n4. Click on Launch a Cloudshell link.\n5. WARNING: SELECT ROOT ACCOUNT (Click on dropdown with account name at the right top >> click Switch back if root is not selected yet).\n6. Execute command several times (usually 3) for each account ($awsacc and $wafacc).\n NOTE: in about 5 minutes after 1st and 2nd run for each account you should press ctrl + c (stop executing) and execute command again.\n FINAL OUTPUT SHOULD BE: No resource to delete.\n7. Move back to https://github.com/development-captains/$CLUSTER >> find Delete Tenant Data From S3 >> copy command >> execute in CloudShell too by entering domain name.\nGitHub deleting/reverting:\n1. Move to https://github.com/internal-GlueOps/development-infrastructure/blob/main/tenants/$TENANT/tf/tenant.tf .\n2. Edit this file >> Delete cluster environments (rows 9-78 including).\n3. Commit changes >> Commit in the new branch.\n4. Create pull request >> click on Details on the right of Terraform icon >> wait untill plan is finished.\n5. Move back to pull request >> merge pull request >> confirm merge >> delete branch.\n6. Move back to Terraform >> runs >> manage run which is appeared (confirm and apply).\n7. Move to https://github.com/internal-GlueOps/development-infrastructure/pulls >> closed. \n8. Revert changes from the last pull request by analogy with applying the changes in Terraform. "
 current_step=22
 save_state
fi


