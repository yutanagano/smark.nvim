## Version 0.2

- [x] Update only lines whose content change
- [x] Fix bug of new incremental update system where line updates are out of sync if starting text is non-standard
- [x] Fix numbering bug when indenting mixed ordered and unordered lists
- [x] Handle over-outdentation (in visual mode you can outdent an arbitrary number of times)
- [x] Change behaviour of carriage return on empty lists to outdent one level instead of completely exiting the list
- [x] Automatically detect ordered/unordered after ending bullet with colon
- [x] Clean up "apply_insert_cr" and "apply_normal_o" to internally incorporate formatting, numbering and indent fixes
- [ ] Study and handle hyper-indented lists (root item already starts with positive indent spaces)
- [ ] Handle multi-line bullets
- [ ] Handle insertion with "O"
- [ ] Handle checking task markers

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
