
## Generate 
`ssh-keygen -t ed25519 -C "example@email.com"`
## Start the ssh-agent in the background.
`eval (ssh-agent -c)` # fish specific
## Add your SSH private key to the ssh-agent
`ssh-add ~/.ssh/id_ed25519`
## Copy the ssh to paste on Github
`cat ~/.ssh/id_ed25519.pub`
