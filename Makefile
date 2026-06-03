LAB ?=

.PHONY: list roots init validate plan fmt check plan-check lifecycle-plan lifecycle-apply-destroy

list:
	@./scripts/tf-lab.sh list

roots:
	@./scripts/tf-lab.sh roots

init:
	@./scripts/tf-lab.sh init "$(LAB)"

validate:
	@./scripts/tf-lab.sh validate "$(LAB)"

plan:
	@./scripts/tf-lab.sh plan "$(LAB)"

fmt:
	@./scripts/tf-lab.sh fmt "$(LAB)"

check:
	@./scripts/fa01hc-validate-all.sh

plan-check:
	@./scripts/fa01hc-plan-all.sh

lifecycle-plan:
	@./scripts/fa01hc-lifecycle.sh plan "$(LAB)"

lifecycle-apply-destroy:
	@./scripts/fa01hc-lifecycle.sh apply-destroy "$(LAB)"
