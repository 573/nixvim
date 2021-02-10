{
  imports = [
    ./colorschemes/gruvbox.nix
    ./colorschemes/base16.nix

    ./statuslines/lightline.nix
    ./statuslines/airline.nix

    ./git/gitgutter.nix

    ./utils/undotree.nix

    ./languages/treesitter.nix

    ./nvim-lsp
  ];
}
