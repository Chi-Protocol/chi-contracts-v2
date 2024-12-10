# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

deploy-staking-manager :; forge script script/DeployStakingManager.s.sol:DeployStakingManager --force --rpc-url ${MAINNET_RPC_URL} --slow --broadcast --verify --delay 5 --verifier-url ${VERIFIER_URL} -vvvv
deploy-locking-manager :; forge script script/DeployLockingManager.s.sol:DeployLockingManager --force --rpc-url ${MAINNET_RPC_URL} --slow --broadcast --delay 5 -vvvv
deploy-stusc :; forge script script/DeploystUSC.s.sol:DeploystUSC --force --rpc-url ${MAINNET_RPC_URL} --slow --broadcast --delay 5 -vvvv