{ ... }:
{
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            swap = {
              size = "16G";
              content = {
                type = "mdraid";
                name = "swap";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "root";
              };
            };
          };
        };
      };

      nvme1 = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot2";
                mountOptions = [ "umask=0077" "nofail" ];
              };
            };
            swap = {
              size = "16G";
              content = {
                type = "mdraid";
                name = "swap";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "root";
              };
            };
          };
        };
      };
    };

    mdadm = {
      root = {
        type = "mdadm";
        level = 1;
        metadata = "1.2";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };

      swap = {
        type = "mdadm";
        level = 1;
        metadata = "1.2";
        content = {
          type = "swap";
        };
      };
    };
  };
}
