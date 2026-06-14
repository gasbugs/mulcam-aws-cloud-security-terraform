# Multicampus FA01HC Terraform Labs

This workspace is organized for the Multicampus FA01HC AWS cloud security course curriculum.

Authoritative curriculum source:

- https://m.multicampus.com/course/crsDetail?corsCd=FA01HC

Reference lab source used while composing this course:

- https://github.com/gasbugs/mulcam-aws-infra-automation-terraform

The original license file is preserved as `LICENSE`.

The final teaching structure lives under `terraform/fa01hc/` and mirrors the day/unit order from the FA01HC course.

## Structure

```text
terraform/
  fa01hc/
    common/
    day01-cloud-and-account-security/
    day02-account-and-compute-security/
    day03-compute-and-network-security/
    day04-network-and-storage-security/
    day05-storage-and-security-services/
```

Each Terraform root module is tracked in `terraform-roots.txt`. Shared instructor foundations live under `terraform/fa01hc/common/`. The final FA01HC day/unit inventory is tracked in `fa01hc-curriculum.json`. The old `labs.json` file is retained only as imported source inventory.

## Quick Start

List the course lab inventory:

```bash
make list
```

List actual Terraform root modules:

```bash
make roots
```

Initialize and validate one FA01HC lab:

```bash
make init LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
make validate LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
```

Run a plan for one lab:

```bash
make plan LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
```

Run the full FA01HC init/validate check:

```bash
make check
```

Run the full non-mutating plan check:

```bash
make plan-check
```

The helper scripts use the default AWS credential chain by default. To force a named AWS CLI profile for labs that expose `aws_profile`, set:

```bash
FA01HC_AWS_PROFILE=my-profile make plan-check
```

Run a guarded apply followed by destroy for one lab:

```bash
CONFIRM_APPLY_DESTROY=YES make lifecycle-apply-destroy LAB=terraform/fa01hc/day05-storage-and-security-services/02-aws-config-compliance
```

When a lab has `terraform.tfvars.example`, the plan command uses it unless you create a local `terraform.tfvars`.

## Variables

Many labs include an intended `terraform.tfvars` file. Those files are kept on purpose so an instructor can prepare the lab defaults explicitly. To create a separate local variant, copy an example file when one exists:

```bash
cp terraform/fa01hc/day04-network-and-storage-security/03-aurora-rds-relational-database/terraform.tfvars.example \
  terraform/fa01hc/day04-network-and-storage-security/03-aurora-rds-relational-database/terraform.tfvars
```

The helper script prefers `terraform.tfvars` and falls back to `terraform.tfvars.example` only when the real tfvars file is absent.

## Safety

`make plan` can contact AWS data sources but does not create resources. Plain `apply` is not exposed as a Makefile target.

For course rehearsal, use `make lifecycle-apply-destroy` instead of a manual apply. It requires `CONFIRM_APPLY_DESTROY=YES`, attempts `terraform destroy` after apply, and verifies that no managed resources remain in Terraform state.
