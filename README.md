# terraform

## Dependencies

 - [awscli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
 - [jq](https://stedolan.github.io/jq/download/)
 - [kubectl](https://kubernetes.io/docs/tasks/tools/)
 - [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
 - [terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/)

## Usage

open environment tier folder
```
$ cd dev
$ cd staging
$ cd prod
```

create `backend-config.tfvars` with content
```
username="<your-gitlab-username>"
password="<your-gitlab-access-token>"
```

preview changes plan to make by terraform
```
$ terragrunt run-all plan
```

executes actions proposed in previous plan
```
$ terragrunt run-all apply
```

destroy remote resources managed by terraform
```
$ terragrunt run-all destroy
```
