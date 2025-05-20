## Version 0.2

- [ ] Change fix logic so that if indent is valid pre-renumbering then they are understood as such when fixing
- [ ] Study and handle hyperindented lists (root item already starts with positive indent spaces)
- [ ] Automatically detect ordered/unordered after ending bullet with colon
- [ ] Clean up "apply_insert_cr" and "apply_normal_o" to internally incorporate formatting, numbering and indent fixes
- [ ] Handle moving cursor to end of line correctly during edits
- [ ] Update only lines whose content change
- [ ] Handle insertion with "O"
- [ ] Handle checking task markers
- [ ] Handle multi-line bullets

## Version 0.1

- [x] Automatically insert bullets with <CR>
- [x] Handle insertion with "o"
- [x] Handle insertion from middle of line
- [x] Handle end list if list item empty
- [x] Handle numbered bullets
- [x] Handle checkbox bullets
- [x] Accept all valid markdown list elements (-, \*, +, etc.)
- [x] Handle block auto-formatting
- [x] Handle indentation:
  - [x] Automatically increase indentation on ending bullet with colon
  - [x] Override <C-t> and <C-d> in insert mode
  - [x] Override >> and << commands
  - [x] Override > and < operators in normal mode
  - [x] Override > and < operators in visual mode
