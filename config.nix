# IMPORTANT: Modify this file for your own host before deploying.
{
  hostName = "example-hetzner-host";

  homeManager.enable = true;

  users = [
    {
      name = "admin";
      sshKey = "ssh-ed25519 AAAA...replace-with-your-key";
      isSudoer = true;
      homeManagerProfile = "irakli";
    }
    {
      name = "claw";
      isSudoer = false;
      # Optional: if you want Home Manager for this user
      # homeManagerProfile = "claw";
    }
  ];

  network = {
    ipv6 = {
      enable = true;
      interface = "enp6s0";
      address = "";
      prefix = 64;
      gateway = "fe80::1";
    };
  };
}
