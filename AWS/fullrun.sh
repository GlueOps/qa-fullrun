#!/bin/bash

source /home/vscode/.oh-my-zsh/custom/yolo.zsh
source /home/vscode/.oh-my-zsh/custom/create-ghcr-regcred.zsh

yolo

unset FULLTENANT

unset CLUSTER

read -p "Enter your full tenant name: " FULLTENANT

read -p "Enter your captain domain: " CLUSTER

unset awsacc

unset wafacc

read -p "Enter your AWS account credentials: " awsacc

read -p "Enter your WAF account credentials: " wafacc

IFS='-' read -r compname rank city <<< "$wafacc"

# Split cluster name to different parts

IFS='.' read -r ENV TENANT DOMAIN <<< "$CLUSTER"

gh repo clone development-captains/$CLUSTER

gh repo clone $FULLTENANT/deployment-configurations

cd /workspaces/glueops/deployment-configurations

git pull

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

read -n 1 -s -r -p "Press any key to continue "

# 1st piece

mkdir -p qa-fullrun/AWS/templates

mkdir -p qa-fullrun/AWS/templates2

curl https://raw.githubusercontent.com/GlueOps/terraform-module-cloud-aws-kubernetes-cluster/main/tests/main.tf -o qa-fullrun/AWS/templates/main.tf 

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
      sed -e "s/761182885829/$value2/g" -e "s/\.\.\//git::https:\/\/github.com\/GlueOps\/terraform-module-cloud-aws-kubernetes-cluster.git/g" "$template_file" > "$target_dir/$template_filename"
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

raw_link="https://raw.githubusercontent.com/wiki/GlueOps/terraform-module-cloud-aws-kubernetes-cluster/install-calico.md"

commands=$(curl -s "$raw_link")

commands=$(echo "$commands" | sed '1d;$d') 

echo "$commands"

bash -c "$commands"

sed -i 's/^#//' terraform/kubernetes/main.tf

cd /workspaces/glueops/$CLUSTER/terraform/kubernetes

terraform init

terraform apply -auto-approve

cd /workspaces/glueops/$CLUSTER

echo "1. Move to https://github.com/development-captains/$CLUSTER , find Deploying GlueOps the Platform >> Deploy ArgoCD , copy command , split the terminal , enter yolo, enter source /workspaces/glueops/$CLUSTER/.env , enter command in splited terminal , wait untill 3 of 3 argocd-redis-ha-server are ready , press ctrl + c (use kubectl get pods -n glueops-core command for monitoring).  "
echo "2. Move back to https://github.com/development-captains/$CLUSTER , find Deploying GlueOps the Platform >> Deploy the GlueOps Platform , copy command , move back to splited terinal , enter command , wait untill all are sync (only one health status should be degraded ) , press ctrl + c (use kubectl get applications -n glueops-core for monitoring) ( if some of the apps are processing for long time then: 1. kubectl get certificates -A 2. kubectl delete pods --all -n glueops-core-cert-manager).  "
echo "3. Close splited termminal  "

read -n 1 -s -r -p "Press any key to continue when all actions above are done"

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

cd /workspaces/glueops/$CLUSTER/manifests

# Function to render templates
render_templates() {
  local template_dir="$1"
  local target_dir="$PWD"
  
  # Split cluster name to different parts

  IFS='.' read -r ENV TENANT DOMAIN <<< "$CLUSTER"

  unset process_webacl
  
  until [ "$process_webacl" == "yes" ] || [ "$process_webacl" == "no" ]; do
    # Webacl manifest creating
    read -p "Do you want to create webacl.yaml manifest? Type 'yes' or 'no': " process_webacl

    # Checking of input
    if [ "$process_webacl" != "yes" ] && [ "$process_webacl" != "no" ]; then
      echo "Invalid input. Please enter 'yes' or 'no'."
    fi
  done

  # Define webacl manifest fullname
  WEBACL="webacl.yaml"

  if [ "$process_webacl" == no ]; then
  echo "File processing skipped for $WEBACL."
  fi

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
        if [ "$process_webacl" == yes ] || [ "$template_filename" != "$WEBACL" ]; then
        sed "s/cluster_env/$ENV/g; s/CLUSTER_VARIABLE/$CLUSTER/g; s/key_id/$valueid/g; s/key_value/$valuesecret/g; s/example-tenant/$org_name/g; s/deployment-configurations/$repo_name/g" "$template_file" > "$target_dir/$template_filename"
        fi
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

unset update

until [ "$update" == "yes" ] || [ "$update" == "no" ]; do
  read -p "Do you want to update ArgoCD and GlueOps Platform? Type 'yes' or 'no': " update

  if [ "$update" != "yes" ] && [ "$update" != "no" ]; then
    echo "Invalid input. Please enter 'yes' or 'no'."
  fi
done

if [ "$update" != "no" ]; then
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

echo -e "Grafana / Loki \n1. https://grafana.$CLUSTER/ >> alerting(hamburger) >> alerting >> alert rules >> search by data sources: loki (should be 3 alerts). \n2. https://grafana.$CLUSTER/alerting/list - should be 1 required alert. \n3. Grafana >> hamburger >> dashboards >> ingress by Host >> watch correct IP tracking according own IP and right ammount of requests adding. \n4. https://grafana.$CLUSTER.rocks/ >> hamburger >> dashboards >> DevOps - ArgoCD >> check wheter all charts are functioning "

read -n 1 -s -r -p " Press any key to continue if all steps above are completed"

echo -e "\n Developer Regression - RBAC (USE incognito and the developer persona user (creds are in 1password)):\n ArgoCD:\n1. Try to delete pods from UI. \n2. Try to exec/terminal into pod. \n3. Try to delete an application.\n Grafana: \n1. Should not see a lot of the other options for Administration tab (only 4 options should be visible ).\n2. Load ingress by host dashboard (change time frame to last hour(s) so you can see some data in the dashboard).  "

read -n 1 -s -r -p " Press any key to continue if all steps above are completed"

cd /workspaces/glueops/$CLUSTER/manifests

curl https://raw.githubusercontent.com/GlueOps/metacontroller-operator-waf-web-acl/main/manifests/webacls.yaml -o webacl.yaml

git status

read -n 1 -s -r -p " Press any key to continue if you agree to add all the changes "

git add -A

git status

read -n 1 -s -r -p " Press any key to continue if you agree to commit "

git commit

read -n 1 -s -r -p " Press any key to continue if you agree to push the changes "

git push

echo -e "\n1. Move to https://argocd.$CLUSTER >> captain-manifests. There should be 4 new healthy manifests (2nd row).\n2. Move to https://aws.amazon.com/ .\n3. Sign In to the Concole.\n4. Click on the key extention (right top corner of the browser) and switch to "$wafacc" account.\n5. Enter to WAF & Shield (can find in search as an option) >> Web ACLs (left part of the screen).\n6. Select global region (dropdown in the middle).\n There should be 4.\n1. Click for eg. on the primary one >> rules >> too-many-requests-per-source-ip >> pay attention to rate limit (100)  "

read -n 1 -s -r -p " Press any key to continue if you everything above is okay and you are ready "

unset rtlmt

unset nmprvd

read -p "Enter new limit(for eg 110) " rtlmt

read -p "Enter the new name to note, by whom it's provided " nmprvd

sed -i -e "106s/100/$rtlmt/" -e "63s/GlueOps/$nmprvd/" webacl.yaml

git status

read -n 1 -s -r -p " Press any key to continue if you agree to add all the changes "

git add -A

git status

read -n 1 -s -r -p " Press any key to continue if you agree to commit "

git commit

read -n 1 -s -r -p " Press any key to continue if you agree to push the changes "

git push

echo -e "\n1. Back to Amazon.\n2. Refresh and check wheter ratelimit is updated.\n3. Move back to general webacl's description and check whether description is changed  "

read -n 1 -s -r -p " Press any key to continue "

rm webacl.yaml

git status

read -n 1 -s -r -p " Press any key to continue if you agree to add all the changes "

git add -A

git status

read -n 1 -s -r -p " Press any key to continue if you agree to commit "

git commit

read -n 1 -s -r -p " Press any key to continue if you agree to push the changes "

git push

echo -e "\n1. Go to Amazon.\n2. Refresh and ensure that web ACLs are deleted  "

read -n 1 -s -r -p " Press any key to continue "

curl https://raw.githubusercontent.com/GlueOps/metacontroller-operator-waf-web-acl/main/manifests/webacls.yaml -o webacl.yaml

git status

read -n 1 -s -r -p " Press any key to continue if you agree to add all the changes "

git add -A

git status

read -n 1 -s -r -p " Press any key to continue if you agree to commit "

git commit

read -n 1 -s -r -p " Press any key to continue if you agree to push the changes "

git push

echo -e "\n1. Move to https://github.com/$FULLTENANT/deployment-configurations/blob/main/apps/waf-test/envs/prod/values.yaml.\n2. Delete comments from rows 44-61.\n3. Commit changes >> Commit directly to the main branch.\n4. Move to https://argocd.$CLUSTER >> glueops-core/captain-manifests >> waf-test-prod.\n5. Check whether 3 wafs are appeared. "

read -n 1 -s -r -p " Press any key to continue "

echo -e "\n1. Move to Amazon.\n2. ACM in search (certificate manager).\n3. List certificates.\n4. Change region to us-east-1 (N. Virginia).\n5. Enter to those, which starts from 1 (according to firstwaf in ArgoCD).\n6. Compare copied CNAME name and value with AroCD's.  "

read -n 1 -s -r -p " Press any key to continue "

echo -e "\n1. Copy CNAME name in ArgoCD (for eg. inside firstwaf >> all line 34).\n2. Move to the codespace.\n3. Split terminal.\n4. Use dig coppied text command. \n5. Compare name and value with ArgoCD's.\n6. Close splited terminal.  "

read -n 1 -s -r -p " Press any key to continue "

echo -e "\n1. Move back to Amazon.\n2. Search "cloudfront" (there should be 2 issued distributions according to WAF's).  "

read -n 1 -s -r -p " Press any key to continue "

unset nwcstcrt

until [ "$nwcstcrt" == "yes" ] || [ "$nwcstcrt" == "no" ]; do
  read -p "Do you want to create new custom certificate? Type 'yes' or 'no': " nwcstcrt

  if [ "$nwcstcrt" != "yes" ] && [ "$nwcstcrt" != "no" ]; then
    echo "Invalid input. Please enter 'yes' or 'no'."
  fi
done

if [ "$nwcstcrt" != "no" ]; then
  echo -e " Several hints for actions below:\n1. First input - enter working email. Second input - type yes. Third input - type no. Fourth input - *.$city.waf.qa-glueops.com.\n2. After fourth input is entered - copy value that has appeared as output.\n3. Move to AWS >> change account to qa-shared-resources >> search route53 >> hosted zones >> $city.waf.qa-glueops.com.\n4. Find those record name, which is the same as in codespace output.\n5. Select it >> Edit record >> paste value in value field >> save.\n6. Move back to codespace.\n7. Copy name fully in output.\n8. Split terminal.\n9. dig txt (copied DNS txt record) in the new terminal >> compare the values.\n10. Exit splited terminal, finally press enter. "
  read -n 1 -s -r -p " Press any key to  start performing steps. "
  sudo certbot certonly --manual --preferred-challenges dns
  sudo ls /etc/letsencrypt/live/$city.waf.qa-glueops.com/
  echo -e "\n1. Enter to https://vault.$CLUSTER with editor role.\n2. Secret >> Create secret:\n Path for this secret: ssl-cert/wildcard.$city.waf.qa-glueops.com\n key: CERTIFICATE\n value: get when ready "
  read -n 1 -s -r -p " Press any key to get the value "
  sudo cat /etc/letsencrypt/live/$city.waf.qa-glueops.com/cert.pem
  echo -e "\n1. Save. \n2. Create new version:\n key: PRIVATE_KEY (add not replace old value)\n value: get when ready"
  read -n 1 -s -r -p " Press any key to get the value "
  sudo cat /etc/letsencrypt/live/$city.waf.qa-glueops.com/privkey.pem
  echo -e "\n key: CERTIFICATE_CHAIN\n value: get when ready "
  read -n 1 -s -r -p " Press any key to get the value "
  sudo cat /etc/letsencrypt/live/$city.waf.qa-glueops.com/chain.pem
  echo -e "\n Save "
  read -n 1 -s -r -p " Press any key to continue "
fi

echo -e "\n1. Enter to https://vault.$CLUSTER with editor role.\n2. Secret >> Create secret:\n Path for this secret: ssl-cert/wildcard.$city.waf.qa-glueops.com\n key: CERTIFICATE\n value: copy from where it is saved "

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\n1. Save. \n2. Create new version:\n key: PRIVATE_KEY (add not replace old value)\n value: copy from where it is saved"

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\n key: CERTIFICATE_CHAIN\n value: copy from where it is saved.\n Save. "

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\n1. ArgoCD: all WAFs should become healthy.\n2. AWS($city account):\n- there are 3 distributions in cloudfront\n- there are 3 certificates in ACM(certificate manager) "

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\n1. Move to https://argocd.$CLUSTER >>captain-manifests >> waf-test-prod >> waf-test-prod-firstwaf \n2. Copy cloudfront_url value\n3. Move to AWS >> qa-shared-resources >> route53 in search >> hosted zones >> $city.waf.qa-glueops.com.\n4. Create record:\n - paste the value (cloudfront_url);\n paste 1 in the record name;\n record type - CNAME;\n TTL - 1 min;\n Create records "

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\nRepeat the same with waf-test-prod-secondwaf by analogy (paste 2 in the record name) "

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\nRepeat the same with waf-test-prod-thirdwafmultipledomains by analogy (create 3 different records (3,4,5 in the record name) with the same cloudfront_url) "

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\n1. Move to https://argocd.$CLUSTER >> captain-manifests >> waf-test-prod >> waf-test-prod-public.\n2. Check whether encryption is those one what is selected (Lets encrypt - for custom certs)(check all 5 apps).\nTo check encryption:\n1. Select app (each one from five).\n2. Click on View site information(left top corner near Refresh the page icon).\n3. Click on Connection is secure.\n4. Click on Certificate is valid. \n (to check which encryption for which WAF is set up (Amazon or Let's encrypt) you can here https://github.com/$FULLTENANT/deployment-configurations/blob/main/apps/waf-test/envs/prod/values.yaml)"

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\n1. Move to https://github.com/$FULLTENANT/deployment-configurations/blob/main/apps/waf-test/envs/prod/values.yaml .\n2. Edit >> put customCertificateSecretStorePath (select all text in raw) in those WAF, where it is not and delete in those where it is (usually swap between second and third ones).\n3. Commit changes >> commit directly to the main branch. "

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\n1. Move to https://argocd.$CLUSTER >> captain-manifests >> waf-test-prod >> waf-test-prod-public.\n2. Check whether encryptions are changed.\n IF the changes are not displayed there are several options:\n1. Try to refresh app pages.\n2. Open pages in Incognito mode.\n3. Split terminal and use next commands for each app to check manually in terminal:\ncurl 1.$city.waf.qa-glueops.com -vIL\ncurl 2.$city.waf.qa-glueops.com -vIL\ncurl 3.$city.waf.qa-glueops.com -vIL\ncurl 4.$city.waf.qa-glueops.com -vIL\ncurl 5.$city.waf.qa-glueops.com -vIL "

read -n 1 -s -r -p " Press any key to continue. "

echo -e "\n1. Move to AWS ($city account) >> ACM >> check whether right certificates are active: whether there are in use with those type of encryption, which is configured (there should be usually 5 certs on this stage: 3 are in use and 2 are not).\n2. Move to cloudfront >> distributions >> 3 distributions are active (status - enabled). "

read -n 1 -s -r -p " Press any key to continue. "

URL="https://3.$city.waf.qa-glueops.com"
COUNT=120

for (( i=1; i<=$COUNT; i++ ))
do
   curl -s "$URL" > /dev/null
   echo "Request $i completed"
done

echo -e "Please wait for 1 minute untill information is updating "

sleep 60

curl https://3.$city.waf.qa-glueops.com -v

read -n 1 -s -r -p " Press any key to continue if there is Too many requests message "

curl https://3.$city.waf.qa-glueops.com -v

read -n 1 -s -r -p " Press any key to continue if there is Too many requests message "

echo -e "\n1. Move to https://github.com/$FULLTENANT/deployment-configurations/blob/main/apps/waf-test/envs/prod/values.yaml \n2. Edit this file >> comment all WAF part (from row 44 to the end.) >> commit changes >> commit directly to the main branch.\n3. Move to the codespace.\n4. Comment webacl.yaml. " 

read -n 1 -s -r -p " Press any key to continue. "

git status

read -n 1 -s -r -p " Press any key to continue if you agree to add all the changes "

git add -A

git status

read -n 1 -s -r -p " Press any key to continue if you agree to commit "

git commit

read -n 1 -s -r -p " Press any key to continue if you agree to push the changes "

git push

echo -e "\n1. Move to https://argocd.$CLUSTER .\n2. Enter glueops-core/captain-manifests.\n3. Pay attention wheter 4 webacl manifests are deleted or not (should be 8 manifests available in 2nd column).\n4. Enter to waf-test-prod (3 column).\n5. Wait untill 3 wafs are deleted. "

read -n 1 -s -r -p " Press any key to continue when wafs are deleted "

echo -e "\n1. Move to AWS ($city account) >> WAF & Shield >> Web ACLs ( left side) >> change region to "Global" >> should be nothing there.\n2. ACM ($city account)  >> ceritficate manager >> all should be deleted after ArgoCD is done.\n3. Cloudfront ($city account) >> distributions  >> all is gone. "

read -n 1 -s -r -p " Press any key to continue if everything above is deleted "

echo -e "\n1. Move to qa-shared-resources account >> route53 >> hosted zones >> $city.waf.qa-glueops.com >> delete records that begins from 1/2/3/4/5 ."

read -n 1 -s -r -p " Press any key to continue if are ready to start deleting/reverting process. "

echo -e " You may perform next algorithms (AWS and GitHub) separately at the same time. Feel free to combine them in order to reduce time consuming.\n AWS teardown:\n1. Move to https://github.com/development-captains/$CLUSTER .\n2. Find Teardown Kubernetes >> AWS Teardown.\n3. Copy nuke command.\n4. Click on Launch a Cloudshell link.\n5. WARNING: SELECT ROOT ACCOUNT (Click on dropdown with account name at the right top >> click Switch back if root is not selected yet).\n6. Execute command several times (usually 3) for each account ($awsacc and $wafacc).\n NOTE: in about 5 minutes after 1st and 2nd run for each account you should press ctrl + c (stop executing) and execute command again.\n FINAL OUTPUT SHOULD BE: No resource to delete.\n7. Move back to https://github.com/development-captains/$CLUSTER >> find Delete Tenant Data From S3 >> copy command >> execute in CloudShell too by entering domain name.\nGitHub deleting/reverting:\n1. Move to https://github.com/internal-GlueOps/development-infrastructure/blob/main/tenants/$TENANT/tf/tenant.tf .\n2. Edit this file >> Delete cluster environments (rows 9-78 including).\n3. Commit changes >> Commit in the new branch.\n4. Create pull request >> click on Details on the right of Terraform icon >> wait untill plan is finished.\n5. Move back to pull request >> merge pull request >> confirm merge >> delete branch.\n6. Move back to Terraform >> runs >> manage run which is appeared (confirm and apply).\n7. Move to https://github.com/internal-GlueOps/development-infrastructure/pulls >> closed. \n8. Revert changes from the last pull request by analogy with applying the changes in Terraform. "


