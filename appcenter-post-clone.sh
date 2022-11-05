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

#Copy provisioning profiles
mv profiles/1887b257-3f9b-4223-89a3-8f98fddd8ea1.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles
mv profiles/6d1a531b-fca9-4485-81a4-b54adb90bb69.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles
mv profiles/99accffc-a353-425f-baf3-15884221b680.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles
mv profiles/f41cd326-5705-42f4-90f6-1e3d9228adc8.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles
ls ~/Library/MobileDevice/Provisioning\ Profiles
