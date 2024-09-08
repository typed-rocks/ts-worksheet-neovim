# ts-worksheet for nvim - Live results in your editor

A plugin to show the result of your TypeScript or JavaScript code right beside your code in your neovim editor. Supporting NodeJs, Deno and Bun

## Installation
Copy the `ts-worksheet.lua` and the `ts-worksheet-cli.js` files into the location your nvim installation looks up plugins. It's only important that both files are in the same directory.
If you want to use `bun` or `deno` to run your code, the binaries have to be available from a terminal. (Check with `which bun` or or `which deno` if they are available)
## Setup
You don't need any setup to start using it. So just require it:
```lua
require('ts-worksheet')
```

If you want to change the diagnostics color of the output, you can use a setup like this:
```lua
require('ts-worksheet').setup({
    type = vim.diagnostic.severity.WARN
})
```

## Usage
Just call `:Tsw` in a `js` or `ts` file to run the worksheet. By default it uses `node` as runtime and does not show the results of variables.

### Examples

`Tsw rt=[bun|node|deno] show_variables=[true|false]`
`Tsw rt=[bun|node|deno] show_variables=[true|false]`
