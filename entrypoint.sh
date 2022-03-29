#!/bin/bash -l

set -e  # if a command fails it stops the execution
set -u  # script fails if trying to access to an undefined variable

echo "[+] Action start"
TARGET_FILE="${1}"
SED_REGEX_MATCH="${2}"
SED_NEW_VALUE="${3}"
DESTINATION_GITHUB_USERNAME="${4}"
DESTINATION_REPOSITORY_NAME="${5}"
GITHUB_SERVER="${6}"
USER_EMAIL="${7}"
USER_NAME="${8}"
DESTINATION_REPOSITORY_USERNAME="${9}"
TARGET_BRANCH="${10}"
COMMIT_MESSAGE="${11}"
TARGET_DIRECTORY="${12}"

if [ -z "$DESTINATION_REPOSITORY_USERNAME" ]
then
	DESTINATION_REPOSITORY_USERNAME="$DESTINATION_GITHUB_USERNAME"
fi

if [ -z "$USER_NAME" ]
then
	USER_NAME="$DESTINATION_GITHUB_USERNAME"
fi

CLONE_DIR=$(mktemp -d)

echo "[+] Cloning destination git repository $DESTINATION_REPOSITORY_NAME"
# Setup git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

{
	git clone --single-branch --branch "$TARGET_BRANCH" "https://$USER_NAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git" "$CLONE_DIR"
} || {
	echo "::error::Could not clone the destination repository. Command:"
	echo "::error::git clone --single-branch --branch $TARGET_BRANCH https://$USER_NAME:the_api_token@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git $CLONE_DIR"
	echo "::error::(Note that the USER_NAME and API_TOKEN is redacted by GitHub)"
	echo "::error::Please verify that the target repository exist AND that it contains the destination branch name, and is accesible by the API_TOKEN_GITHUB"
	exit 1

}
ls -la "$CLONE_DIR"


echo "[+] Running sed command on file $TARGET_FILE in $CLONE_DIR"
echo "[+] running now"
echo "sed -i 's/$SED_REGEX_MATCH/$SED_NEW_VALUE/g' $CLONE_DIR/$TARGET_FILE"
sed 's/'"$SED_REGEX_MATCH"'/'"$SED_NEW_VALUE"'/g' $CLONE_DIR/$TARGET_FILE
sed -i 's/'"$SED_REGEX_MATCH"'/'"$SED_NEW_VALUE"'/g' $CLONE_DIR/$TARGET_FILE

# echo "awk '{sub(/$SED_REGEX_MATCH/,"$SED_NEW_VALUE"); print}'  $CLONE_DIR/$TARGET_FILE "
# awk '{sub(/$SED_REGEX_MATCH/,$SED_NEW_VALUE); print}'  $CLONE_DIR/$TARGET_FILE
# echo "first succeeded"

# awk '{sub(/$SED_REGEX_MATCH/,$SED_NEW_VALUE); print}'  $CLONE_DIR/$TARGET_FILE > tmpfile && mv tmpfile $CLONE_DIR/$TARGET_FILE
# echo ' second succeeded'

ORIGIN_COMMIT="https://$GITHUB_SERVER/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
COMMIT_MESSAGE="${COMMIT_MESSAGE/ORIGIN_COMMIT/$ORIGIN_COMMIT}"
COMMIT_MESSAGE="${COMMIT_MESSAGE/\$GITHUB_REF/$GITHUB_REF}"

echo 'Moving to lcone dir'
cd $CLONE_DIR

echo "[+] Adding git commit"
git add .

echo "[+] git status:"
git status

echo "[+] git diff-index:"
# git diff-index : to avoid doing the git commit failing if there are no changes to be commit
git diff-index --quiet HEAD || git commit --message "$COMMIT_MESSAGE"

echo "[+] Pushing git commit"
# --set-upstream: sets de branch when pushing to a branch that does not exist
git push "https://$USER_NAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git" --set-upstream "$TARGET_BRANCH"
