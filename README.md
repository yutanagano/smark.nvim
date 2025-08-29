# 🧠🚅 smark.nvim

![neovim_plugin](https://img.shields.io/badge/Plugin-darkgreen?style=for-the-badge&logo=neovim&logoColor=white)
![MIT_license](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Tests](https://img.shields.io/github/actions/workflow/status/yutanagano/smark.nvim/ci.yml?style=for-the-badge)

Smark is a [NeoVim][neovim] plugin that helps you write and manipulate markdown
lists. It has an opinionated design with the following principles:

1. **Correct**: only consider and always output valid Markdown lists that have
   a sane structure (e.g. list block is a clean tree, no sudden jumps in
   indentation level, correct numbering)
2. **Clean**: follow [Prettier's][prettier] style convention
3. **Smart**: Automatically infer as much as possible

## 📋 Features

| Feature                                                                             | Demo                                                                                                      |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Automatic generation of list markers with `<CR>` (insert mode) or `o` (normal mode) | ![autobullet](https://github.com/user-attachments/assets/56ccf9d8-42c5-4fee-a7bf-f2873f24f11e)            |
| Supports list indentation / nested lists                                            | ![indentation](https://github.com/user-attachments/assets/96f70a39-d930-4c91-8080-9d55a656cc0a)           |
| Indenting multiple items at once                                                    | ![multiline_indentation](https://github.com/user-attachments/assets/d424c6e8-dbc1-4621-8816-324d45a5a65d) |
| Toggle between ordered and unordered list types                                     | ![ordered](https://github.com/user-attachments/assets/d2d91ccc-3ba0-44f7-8668-a3cab6d4c298)               |
| Support for task list items                                                         | ![completion](https://github.com/user-attachments/assets/8811cc28-e222-4915-a6ff-1c519c7cf807)            |
| Toggle between plain and task list items                                            | ![task](https://github.com/user-attachments/assets/f695f1dd-79a4-4f41-906b-b706cf02dd88)                  |
| Support for multi-line list items                                                   | ![multiline](https://github.com/user-attachments/assets/e95443cd-0c83-4d0d-9a59-faa4b98927d0)             |
| Inference of indent level list type from context                                    | ![type_inference](https://github.com/user-attachments/assets/a777aef9-9c9e-4ba4-a87b-55b949c709fa)        |
| Automatic updates to indentation rules as necessary                                 | ![indent_spacing](https://github.com/user-attachments/assets/3a5cd857-1b4c-46e7-8fff-f7574e7ce948)        |
| Clearnly turning list items into paragraphs                                         | ![paragraph](https://github.com/user-attachments/assets/9a626a66-a931-4ca7-b809-ac3a6f33629f)             |
| Manual triggering of list block formatting                                          | ![format](https://github.com/user-attachments/assets/b3107378-3822-4f62-bb98-6f5655b3b307)                |

## ⚙️ Installation

With [lazy.nvim][lazy]:

```lua
return {
  {
    "yutanagano/smark.nvim",
    ft = { "markdown", "text" },
    -- You can omit the opts table below and simply set config = true if you
    -- are happy with the default settings
    opts = {
      --Default keymapping settings for list action commands.
      --Set to false to disable.
      mappings = {
        --Format the current list block to be clean / correct
        format_list = "<leader>lf",
        --Switch between ordered / unordered list types
        toggle_ordered = "<leader>lo",
        --Toggle the completion status of a task list item
        toggle_completion = "<leader>lx",
        --Toggle between plain and task list items
        toggle_task = "<leader>lt",
      },
    },
  }
}
```

> [!IMPORTANT]
> The `ft = { "markdown", "text" }` setting ensures the plugin is lazily loaded
> only after NeoVim opens a markdown or plain text buffer. However, regardless
> of lazy loading, the plugin is only active when editing markdown or plain
> text documents.

## 💭 Why smark?

I take a lot of Markdown notes in [NeoVim][neovim]. I'm lazy, so 1. I don't
like to think about formatting, and 2. I don't want to have to write out lists
manually. For the first problem, I use [conform.nvim][conform] and
[prettierd][prettierd] to auto-format my Markdown documents at write-time. For
the second problem, I previously used the wonderful plugin
[bullets.vim][bullets]. I love it, but one thing annoyed me - it didn't play
well with [Prettier's][prettier] auto-formatting of lists, specifically the
list indentation levels. So, I wrote my own auto-bullet plugin that
auto-completes lists in a Prettier-compatible way, which became smark.

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
> 2. Foo
> 3. Foo
> 4. Foo
> 5. Foo
> 6. Foo
> 7. Foo
> 8. Foo
> 9. Foo
> 10. Foo:
>     1. Bar
> ```

## 📢 Shout-outs

- A less opinionated alternative plugin: [Bullets.vim][bullets]
- Hyperlinking Markdown documents: [markdown-oxide][markdown-oxide], [marksman][marksman]
- Render Markdown within NeoVim: [render-markdown.nvim][render-markdown]
- This plugin is tested using [mini.test][mini]

[bullets]: https://github.com/bullets-vim/bullets.vim
[conform]: https://github.com/stevearc/conform.nvim
[lazy]: https://github.com/folke/lazy.nvim
[markdown-oxide]: https://github.com/Feel-ix-343/markdown-oxide
[marksman]: https://github.com/artempyanykh/marksman
[mini]: https://github.com/echasnovski/mini.nvim/blob/main/README.md
[neovim]: https://neovim.io/
[prettier]: https://prettier.io/
[prettierd]: https://github.com/fsouza/prettierd
[render-markdown]: https://github.com/MeanderingProgrammer/render-markdown.nvim
