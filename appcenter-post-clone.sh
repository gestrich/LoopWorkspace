# Print out ssh known hosts for debugging
#echo "Known hosts:"
#cat ~/.ssh/known_hosts

#TODO: Is this SSH stuff useful?

echo "Adding github to ssh known hosts"
ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

# Add Github ssh key
echo "Adding Github SSH key:"

#Had to run this on my mac to create the key and convert to base64
#Then upload this to the AppCenter Env variables
#cat id_rsa_app_center | base64 | pbcopy

echo "$SSH_KEY" | base64 -D > ~/.ssh/github-ssh
chmod 600 ~/.ssh/github-ssh
ssh-add ~/.ssh/github-ssh

#Add Git Token
echo "https://gestrich:$GIT_TOKEN@github.com" > ~/.git-credentials
echo "[credential]" >> ~/.gitconfig
echo "  username = gestrich" >> ~/.gitconfig
echo "  helper = store" >> ~/.gitconfig
