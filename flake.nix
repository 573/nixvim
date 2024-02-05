{
  description = "A neovim configuration system for NixOS";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    unstable.url = "github:NixOS/nixpkgs/b2e4fd1049a3e92c898c99adc8832361fa7e1397"; #/635a306fc8ede2e34cb3dd0d6d0a5d49362150ed"; # nvim broken in 8d447c5626cfefb9b129d5b30103344377fe09bc, see https://github.com/573/nix-config-1/actions/runs/4960709342/jobs/8876554875#step:6:3671

    beautysh = {
      url = "github:lovesegfault/beautysh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    pre-commit-hooks,
    ...
  } @ inputs:
    with nixpkgs.lib;
    with builtins; let
      # TODO: Support nesting
      nixvimModules = map (f: ./modules + "/${f}") (attrNames (builtins.readDir ./modules));

      modules = pkgs:
        nixvimModules
        ++ [
          rec {
            _file = ./flake.nix;
            key = _file;
            config = {
              _module.args = {
                pkgs = mkForce pkgs;
                inherit (pkgs) lib;
                helpers = import ./plugins/helpers.nix {inherit (pkgs) lib;};
                inherit inputs;
              };
            };
          }

          # ./plugins/default.nix
        ];

      wrapperArgs = {
        inherit modules;
        inherit self;
      };

      flakeOutput =
        flake-utils.lib.eachDefaultSystem
        (system: let
          pkgs = import nixpkgs {inherit system;};
          # Some nixvim supported plugins require the use of unfree packages.
          # This unfree-friendly pkgs is used for documentation and testing only.
          pkgs-unfree = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in {
          checks =
            (import ./tests {
              inherit pkgs;
              inherit (pkgs) lib;
              # Some nixvim supported plugins require the use of unfree packages.
              # As we test as many things as possible, we need to allow unfree sources by generating
              # a separate `makeNixvim` module (with pkgs-unfree).
              makeNixvim = let
                makeNixvimWithModuleUnfree = import ./wrappers/standalone.nix pkgs-unfree wrapperArgs;
              in
                configuration:
                  makeNixvimWithModuleUnfree {
                    module = {
                      config = configuration;
                    };
                  };
            })
            // {
              lib-tests = import ./tests/lib-tests.nix {
                inherit (pkgs) pkgs lib;
              };
              pre-commit-check = pre-commit-hooks.lib.${system}.run {
                src = ./.;
                hooks = {
                  alejandra = {
                    enable = true;
                    excludes = ["plugins/_sources"];
                  };
                  statix.enable = true;
                };
                settings.statix.ignore = ["plugins/lsp/language-servers/rust-analyzer-config.nix"];
              };
            };
          devShells = {
            default = pkgs.mkShell {
              inherit (self.checks.${system}.pre-commit-check) shellHook;
            };
          };
          packages = let
            pluggo = pname:
              inputs.unstable.legacyPackages.${system}.vimUtils.buildVimPlugin {
                inherit pname;
                src = inputs."${pname}";
                version = "0.1";
              };
            config = {
              colorschemes.gruvbox.enable = true;
              extraPlugins = with pkgs; [
                vimPlugins.nnn-vim
                vimPlugins.trouble-nvim
                vimPlugins.vimtex
                vimPlugins.vim-jack-in
                vimPlugins.neoterm
              ];
              extraConfigLua = ''
                require("trouble").setup({
                	-- settings without a patched font or icons
                	icons = false,
                	fold_open = "v", -- icon used for open folds
                	fold_closed = ">", -- icon used for closed folds
                	indent_lines = false, -- add an indent guide below the fold icons
                	signs = {
                		-- icons / text used for a diagnostic
                		error = "error",
                		warning = "warn",
                		hint = "hint",
                		information = "info"
                	},
                	use_diagnostic_signs = false -- enabling this will use the signs defined in your lsp client
                })
              '';
              plugins = {
                nvim-osc52.enable = true;
                treesitter-context.enable = true;
                rainbow-delimiters.enable = true;
		which-key.enable = true;
		conjure.enable = true;
                lsp = {
                  enable = true;
                  servers = {
                    nixd.enable = true;
                    ltex.enable = true;
                    texlab.enable = true;
                    lua-ls.enable = true;
                  };
                };

                treesitter = {
                  enable = true;
                  nixGrammars = true;
                  indent = true;
                  # DONT see https://discourse.nixos.org/t/conflicts-between-treesitter-withallgrammars-and-builtin-neovim-parsers-lua-c/33536/3
                  #grammarPackages = with pkgs.tree-sitter-grammars; [
                  #  tree-sitter-nix
                  #  tree-sitter-bash
                  #  tree-sitter-yaml
                  #  tree-sitter-json
                  #  tree-sitter-lua
                  #  tree-sitter-latex
                  #  tree-sitter-comment
                  #];
                };
                gitsigns = {
                  enable = true;
                  currentLineBlame = true;
                };
                # # Source: https://github.com/hmajid2301/dotfiles/blob/ab7098387426f73c461950c7c0a4f8fb4c843a2c/home-manager/editors/nvim/plugins/coding/cmp.nix
                luasnip.enable = true;
                cmp-buffer = {enable = true;};

                cmp-emoji = {enable = true;};

                cmp-nvim-lsp = {enable = true;};

                cmp-path = {enable = true;};

                cmp_luasnip = {enable = true;};

                nvim-cmp = {
                  enable = true;
                  sources = [
                    {name = "nvim_lsp";}
                    {name = "luasnip";}
                    {name = "buffer";}
                    {name = "nvim_lua";}
                    {name = "path";}
                  ];

                  formatting = {
                    fields = ["abbr" "kind" "menu"];
                    format =
                      # lua
                      ''
                        function(_, item)
                          local icons = {
                            Namespace = "󰌗",
                            Text = "󰉿",
                            Method = "󰆧",
                            Function = "󰆧",
                            Constructor = "",
                            Field = "󰜢",
                            Variable = "󰀫",
                            Class = "󰠱",
                            Interface = "",
                            Module = "",
                            Property = "󰜢",
                            Unit = "󰑭",
                            Value = "󰎠",
                            Enum = "",
                            Keyword = "󰌋",
                            Snippet = "",
                            Color = "󰏘",
                            File = "󰈚",
                            Reference = "󰈇",
                            Folder = "󰉋",
                            EnumMember = "",
                            Constant = "󰏿",
                            Struct = "󰙅",
                            Event = "",
                            Operator = "󰆕",
                            TypeParameter = "󰊄",
                            Table = "",
                            Object = "󰅩",
                            Tag = "",
                            Array = "[]",
                            Boolean = "",
                            Number = "",
                            Null = "󰟢",
                            String = "󰉿",
                            Calendar = "",
                            Watch = "󰥔",
                            Package = "",
                            Copilot = "",
                            Codeium = "",
                            TabNine = "",
                          }
                          local icon = icons[item.kind] or ""
                          item.kind = string.format("%s %s", icon, item.kind or "")
                          return item
                        end
                      '';
                  };

                  snippet = {expand = "luasnip";};

                  window = {
                    completion = {
                      winhighlight = "FloatBorder:CmpBorder,Normal:CmpPmenu,CursorLine:CmpSel,Search:PmenuSel";
                      scrollbar = false;
                      sidePadding = 0;
                      border = ["╭" "─" "╮" "│" "╯" "─" "╰" "│"];
                    };

                    documentation = {
                      border = ["╭" "─" "╮" "│" "╯" "─" "╰" "│"];
                      winhighlight = "FloatBorder:CmpBorder,Normal:CmpPmenu,CursorLine:CmpSel,Search:PmenuSel";
                    };
                  };

                  mapping = {
                    "<C-n>" = "cmp.mapping.select_next_item()";
                    "<C-p>" = "cmp.mapping.select_prev_item()";
                    "<C-j>" = "cmp.mapping.select_next_item()";
                    "<C-k>" = "cmp.mapping.select_prev_item()";
                    "<C-d>" = "cmp.mapping.scroll_docs(-4)";
                    "<C-f>" = "cmp.mapping.scroll_docs(4)";
                    "<C-Space>" = "cmp.mapping.complete()";
                    "<C-e>" = "cmp.mapping.close()";
                    "<CR>" = "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = true })";
                    "<Tab>" = {
                      modes = ["i" "s"];
                      action =
                        # lua
                        ''
                          function(fallback)
                            if cmp.visible() then
                              cmp.select_next_item()
                            elseif require("luasnip").expand_or_jumpable() then
                              vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, true), "")
                            else
                              fallback()
                            end
                          end
                        '';
                    };
                    "<S-Tab>" = {
                      modes = ["i" "s"];
                      action =
                        # lua
                        ''
                          function(fallback)
                            if cmp.visible() then
                              cmp.select_prev_item()
                            elseif require("luasnip").jumpable(-1) then
                              vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-jump-prev", true, true, true), "")
                            else
                              fallback()
                            end
                          end
                        '';
                    };
                  };
                };
              };
            };
            keymaps.lspBuf = {
              "gd" = "definition";
              "gD" = "references";
              "gt" = "type_definition";
              "gi" = "implementation";
              "K" = "hover";
            };
            nixvim' = self.legacyPackages."${system}";
            nvim = nixvim'.makeNixvim config;
          in
            {
              inherit nvim;
              default = nvim;
              docs = pkgs-unfree.callPackage (import ./docs) {
                modules = modules pkgs;
              };
            }
            // (import ./helpers pkgs)
            // (import ./man-docs {
              pkgs = pkgs-unfree;
              modules = modules pkgs;
            });
          legacyPackages = rec {
            makeNixvimWithModule = import ./wrappers/standalone.nix pkgs wrapperArgs;
            makeNixvim = configuration:
              makeNixvimWithModule {
                module = {
                  config = configuration;
                };
              };
          };
          formatter = pkgs.alejandra;
          lib = import ./lib {
            inherit pkgs;
            inherit (pkgs) lib;
            inherit (self.legacyPackages."${system}") makeNixvim;
          };
        });
    in
      flakeOutput
      // {
        nixosModules.nixvim = import ./wrappers/nixos.nix wrapperArgs;
        homeManagerModules.nixvim = import ./wrappers/hm.nix wrapperArgs;
        nixDarwinModules.nixvim = import ./wrappers/darwin.nix wrapperArgs;
        rawModules.nixvim = nixvimModules;

        overlays.default = final: prev: {
          nixvim = rec {
            makeNixvimWithModule = import ./wrappers/standalone.nix prev wrapperArgs;
            makeNixvim = configuration:
              makeNixvimWithModule {
                module = {
                  config = configuration;
                };
              };
          };
        };

        templates = let
          simple = {
            path = ./templates/simple;
            description = "A simple nix flake template for getting started with nixvim";
          };
        in {
          default = simple;
        };
      };
}
