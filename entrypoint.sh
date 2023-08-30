#!/bin/bash -l

set -e  # if a command fails it stops the execution
set -u  # script fails if trying to access to an undefined variable

echo "[+] Action start"
TARGET_FILE="${1}"
SED_COMMAND="${2}"
DESTINATION_GITHUB_USERNAME="${3}"
DESTINATION_REPOSITORY_NAME="${4}"
GITHUB_SERVER="${5}"
USER_EMAIL="${6}"
USER_NAME="${7}"
TARGET_BRANCH="${8}"
COMMIT_MESSAGE="${9}"
TARGET_DIRECTORY="${10}"


echo " TARGET_FILE =  ${TARGET_FILE}"
echo " SED_COMMAND =  ${SED_COMMAND}"
echo " DESTINATION_GITHUB_USERNAME =  ${DESTINATION_GITHUB_USERNAME}"
echo " DESTINATION_REPOSITORY_NAME =  ${DESTINATION_REPOSITORY_NAME}"
echo " GITHUB_SERVER =  ${GITHUB_SERVER}"
echo " USER_EMAIL =  ${USER_EMAIL}"
echo " USER_NAME =  ${USER_NAME}"
echo " TARGET_BRANCH =  ${TARGET_BRANCH}"
echo " COMMIT_MESSAGE =  ${COMMIT_MESSAGE}"
echo " TARGET_DIRECTORY =  ${TARGET_DIRECTORY}"


DESTINATION_REPOSITORY_USERNAME="$DESTINATION_GITHUB_USERNAME"

if [ -z "$USER_NAME" ]
then
	USER_NAME="$DESTINATION_GITHUB_USERNAME"
fi

CLONE_DIR=$(mktemp -d)

echo "[+] Configuring SSH"

eval "$(ssh-agent -s)"
ssh-add <(echo "$DEPLOY_KEY")
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts

echo "[+] Cloning destination git repository $DESTINATION_REPOSITORY_NAME"
# Setup git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

{
	git clone --single-branch --branch "$TARGET_BRANCH" "git@$GITHUB_SERVER:$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git" "$CLONE_DIR"
} || {
	echo "::error::Could not clone the destination repository. Command:"
	echo "::error::git clone --single-branch --branch $TARGET_BRANCH git@$GITHUB_SERVER:$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git $CLONE_DIR"
	echo "::error::Please verify that the target repository exist AND that it contains the destination branch name, and is accesible by the DEPLOY_KEY"
	exit 0

}
ls -la "$CLONE_DIR"


echo "[+] Running sed command on file $TARGET_FILE in $CLONE_DIR"
echo "[+] running now"
echo "sed -i $SED_COMMAND $CLONE_DIR/$TARGET_FILE"
sed "$SED_COMMAND" "$CLONE_DIR/$TARGET_FILE"
sed -i "$SED_COMMAND" "$CLONE_DIR/$TARGET_FILE"

ORIGIN_COMMIT="https://$GITHUB_SERVER/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
COMMIT_MESSAGE="${COMMIT_MESSAGE/ORIGIN_COMMIT/$ORIGIN_COMMIT}"
COMMIT_MESSAGE="${COMMIT_MESSAGE/\$GITHUB_REF/$GITHUB_REF}"

echo 'Moving to clone dir'
cd "$CLONE_DIR"

echo "[+] Adding git commit"
git add .

echo "[+] git status:"
git status

echo "[+] git diff-index:"
# git diff-index : to avoid git commit failing if there are no changes to commit
git diff-index --quiet HEAD || git commit --message "$COMMIT_MESSAGE"

echo "[+] Pushing git commit"
# --set-upstream: sets the branch when pushing to a branch that does not exist
n=0
until [ "$n" -ge 5 ]
do
  git pull --rebase
	git push "git@$GITHUB_SERVER:$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git" --set-upstream "$TARGET_BRANCH"  && break
  n=$((n+1))
  sleep 5
done
