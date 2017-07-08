if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
fi

if [ ! -f /etc/ssh/ssh_host_dsa_key ]; then
    ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
fi


if [ ! -f /etc/ssh/ssh_host_ecdsa_key ]; then
    ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa
fi


if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519
fi

if [ -n $STRICT_MODES ]; then
        echo "StrictModes $STRICT_MODES" >> /ssh/sshd_config
fi

/usr/sbin/sshd -D -p 22 -f /ssh/sshd_config
