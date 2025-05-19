## Version 0.2

- [ ] Clean up "apply_insert_cr" and "apply_normal_o" to internally incorporate formatting, numbering and indent fixes
- [ ] Handle moving cursor to end of line correctly during edits
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
- [ ] Handle indentation:
  - [x] Automatically increase indentation on ending bullet with colon
  - [x] Override <C-t> and <C-d> in insert mode
  - [x] Override >> and << commands
  - [ ] Override > and < operators
