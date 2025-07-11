# 🧠🚅 smark.nvim

![neovim_plugin](https://img.shields.io/badge/Plugin-darkgreen?style=for-the-badge&logo=neovim&logoColor=white)
![MIT_license](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Tests](https://img.shields.io/github/actions/workflow/status/yutanagano/smark.nvim/ci.yml?style=for-the-badge)

Smark is a neovim plugin that helps you write and manipulate markdown lists. It
has an opinionated design with the following principles:

1. Always produce a sane list (e.g. list block is a clean tree, no sudden jumps
   in indentation level, correct numbering)
2. Follow [Prettier's][prettier] style convention
3. Automatically infer as much as possible

![demo](./demo.gif)

## 📋 Features

- Automatic generation of list markers with `<CR>` (insert mode) or `o` (normal
  mode) within a list block
- Automatic numbering of ordered lists
- Always auto-formats current list block to be
  [Prettier][prettier]-compatible
- Easy indenting / outdenting of list items using standard vim bindings:
  - Insert mode: `<C-t>` indents, `<C-d>` outdents
  - Normal mode: `>>`/`>` indents, `<<`/`<` outdents
  - Visual mode: `>` indents, `>` outdents
- Easy toggling of ordered / unordered list types with `<leader>lo` in normal
  and visual modes
- Easy toggling of task item completion status `<leader>lx` in normal and
  visual modes:
  - Task item completion status is automatically propagated up and down the
    tree (e.g. marking a task complete will automatically mark all of its
    children as complete, and its parent as well if all its siblings are also
    complete)
- Infers and updates indentation rules across the current list block when edits
  are made
- Support for multi-line list item contents

> [!NOTE]
> See CHANGELOG.md for planned features in future releases

## ⚙️ Installation

With [lazy.nvim][lazy]:

```lua
return {
  {
    "yutanagano/smark.nvim",
    ft = "markdown",
    config = true
  }
}
```

> [!IMPORTANT]
> The plugin is active only when editing markdown documents.
> The `ft = "markdown"` setting ensures the plugin is only loaded when opening a markdown buffer.

## 💭 Why smark?

I take a lot of Markdown notes in neovim. I'm lazy, so 1. I don't like to think
about formatting, and 2. I don't want to have to write out lists manually. For
the first problem, I use [conform.nvim][conform] and [prettierd][prettierd] to
auto-format my Markdown documents at write-time. For the second problem, I
previously used the wonderful plugin [bullets.vim][bullets]. I love it, but one
thing annoyed me -- it didn't play well with [Prettier's][prettier]
auto-formatting of lists, specifically the list indentation levels. So, I wrote
my own auto-bullet plugin that auto-completes lists in a Prettier-compatible
way, which became smark.

> [!NOTE]
> Prettier formats nested Markdown lists so that the child list marker aligns
> with the content of the parent list item, resulting in 2 spaces for unordered
> lists and enough spaces (usually 3 or more) for ordered lists.
>
> ```markdown
> - Foo:
>   - Bar
>
> 1. Foo
>    1. Bar
> ```

## 📢 Shout-outs

- A less opinionated alternative plugin: [Bullets.vim][bullets]
- Hyperlinking Markdown documents: [markdown-oxide][markdown-oxide], [marksman][marksman]
- This plugin is tested using [mini.test][mini]

[bullets]: https://github.com/bullets-vim/bullets.vim
[conform]: https://github.com/stevearc/conform.nvim
[lazy]: https://github.com/folke/lazy.nvim
[markdown-oxide]: https://github.com/Feel-ix-343/markdown-oxide
[marksman]: https://github.com/artempyanykh/marksman
[mini]: https://github.com/echasnovski/mini.nvim/blob/main/README.md
[prettier]: https://prettier.io/
[prettierd]: https://github.com/fsouza/prettierd
