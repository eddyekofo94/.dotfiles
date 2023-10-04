#  NOTE: 2023-10-04 - https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
ssh-keygen -t ed25519 -C "eddy.ekofo@amadeus.com"

# Start the ssh-agent in the background.
eval "$(ssh-agent -s)"

# Add your SSH private key to the ssh-agent.
ssh-add ~/.ssh/id_ed25519

# Add to your host
#  NOTE: 2023-10-04 - https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account
cat ~/.ssh/id_ed25519.pub
