{
  lib,
  pkgs,
  irakli-home,
  ...
}:
let
  cfg = import ../../config.nix;

  usersCfg = cfg.users;
  hmCfg = cfg.homeManager or { enable = false; };

  mkUser =
    u:
    let
      name = u.name or (throw "users[].name is required");
      isSudoer = u.isSudoer or false;
    in
    {
      inherit name;
      value = {
        isNormalUser = true;
        shell = pkgs.zsh;
        extraGroups = lib.optionals isSudoer [ "wheel" ];
      }
      // lib.optionalAttrs (u ? sshKey) {
        openssh.authorizedKeys.keys = [ u.sshKey ];
      };
    };

  userAttrs = builtins.listToAttrs (map mkUser usersCfg);

  sudoerNames = map (u: u.name) (lib.filter (u: u.isSudoer or false) usersCfg);

  hmEnabled = hmCfg.enable or false;
  hmUsers = lib.filter (u: u ? homeManagerProfile && u.homeManagerProfile != "") usersCfg;
  hmUserAttrs = builtins.listToAttrs (
    map (u: {
      name = u.name;
      value = irakli-home.homeModules.linux {
        profile = u.homeManagerProfile;
      };
    }) hmUsers
  );

  ipv6 = cfg.network.ipv6 or { enable = false; };
  requireIPv6 =
    key: ipv6.${key} or (throw "network.ipv6.${key} is required when network.ipv6.enable = true");
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = cfg.hostName or "example-hetzner-host";
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.useDHCP = true;

  networking.interfaces = lib.mkIf (ipv6.enable or false) {
    ${requireIPv6 "interface"}.ipv6.addresses = [
      {
        address = requireIPv6 "address";
        prefixLength = requireIPv6 "prefix";
      }
    ];
  };

  networking.defaultGateway6 = lib.mkIf (ipv6.enable or false) {
    address = requireIPv6 "gateway";
    interface = requireIPv6 "interface";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users = userAttrs // {
    root.hashedPassword = "!";
  };

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ "root" ] ++ sudoerNames;
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    curl
    ghostty.terminfo
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users = lib.mkIf hmEnabled hmUserAttrs;
  };

  boot = {
    supportedFilesystems = [ "ext4" ];

    loader = {
      efi.canTouchEfiVariables = false;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";
        useOSProber = false;
      };
    };

    swraid = {
      enable = true;
      mdadmConf = ''
        MAILADDR root
      '';
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  system.stateVersion = "25.11";
}
