{
  description = "GapYears -- healthspan-lifespan gap replication, R environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, utils, ... }:
    utils.lib.eachSystem [
      utils.lib.system.x86_64-darwin
      utils.lib.system.x86_64-linux
      utils.lib.system.aarch64-darwin
      utils.lib.system.aarch64-linux
    ]
      (system:
        let
          pkgs = import nixpkgs { inherit system; };

          rEnv = pkgs.rWrapper.override {
            packages = with pkgs.rPackages; [
              jsonlite
              dplyr
              tidyr
              readxl
              cluster
              ggplot2
              maps
              mapdata
              countrycode
              pheatmap
              MASS
              randomForest
              nlme
              Boruta
              plm
              quantreg
              glmnet
              forecast
              testthat
            ];
          };
        in
        {
          devShell = pkgs.mkShell { buildInputs = [ rEnv ]; };

          apps.default = utils.lib.mkApp {
            drv = pkgs.writeShellApplication {
              name = "run-all";
              runtimeInputs = [ rEnv ];
              text = ''Rscript run_all.R'';
            };
          };
        });
}
