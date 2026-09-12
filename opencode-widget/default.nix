# opencode chat widget: injects a chat bubble into every page nginx serves
# and proxies it to the opencode server (see home.nix), so you can talk to
# opencode about the app you're looking at and it can edit the app's files.
#
# Disabled by default; enable per machine in configuration.nix.

{ config, lib, ... }:

let
  cfg = config.opencode-widget;
in
{
  options.opencode-widget.enable = lib.mkEnableOption
    "opencode chat widget injected into nginx-served pages";

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts."${config.networking.hostName}.orb.local" = {
      extraConfig = ''
        sub_filter_once on;
        sub_filter_types text/html;
        sub_filter '</body>' '<script src="/opencode-widget/widget.js" defer></script></body>';
      '';
      locations."= /opencode-widget/widget.js".alias = toString ./widget.js;
      locations."/opencode/" = {
        proxyPass = "http://127.0.0.1:4096/";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          # /opencode/event is a long-lived SSE stream.
          proxy_buffering off;
          proxy_read_timeout 1h;
        '';
      };
    };
  };
}
