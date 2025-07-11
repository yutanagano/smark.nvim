## Version 0.2

- [ ] Make it so that when adding a new line (using <CR> or o) inside of a task
      list block, make sure the parent level item becomes marked as incomplete
      (because there is now at least one child that is incomplete)
- [ ] Make it so that when list elements are fully outdented (they are no
      longer list elements), empty lines are added in the spaces between any
      adjacent list elements and normal paragraph lines
- [ ] Implement configuration options:
  - [ ] Auto-numbering
  - [ ] List type on indenting
- [ ] Add method to toggle task list:
  - [ ] For normal mode
  - [ ] For visual mode
- [ ] Add method to toggle between lists and standard paragraphs

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
  - [x] Handle over-outdentation (in visual mode you can outdent an arbitrary
        number of times)
  - [x] Automatically detect ordered/unordered after ending bullet with colon
  - [x] Study and handle hyper-indented lists (root item already starts with
        positive indent spaces)
  - [x] Change behaviour of carriage return on empty lists to outdent one level
        instead of completely exiting the list
- [x] Add method to toggle list ordered types:
  - [x] For normal mode
  - [x] For visual mode
- [x] Handle checking task markers:
  - [x] For normal mode:
    - [x] Make it so that ticking all children automatically ticks the parent
  - [x] For visual mode
- [x] Update only lines whose content change
- [x] Bind format fixing routine by itself to a keymap
- [x] Handle multi-line bullets:
  - [x] Update list item schema to handle multi-line content
  - [x] Update code to scan document and generate list items
  - [x] Update code to write list items to screen
  - [x] Make sure insert <CR> is working
  - [x] Make sure normal o is working
  - [x] Make sure in/outdent keybinds are working
  - [x] Make sure list formatting / numbering / ticking shortcuts are working
- [x] Bug fixes
  - [x] Fix bug of new incremental update system where line updates are out of
        sync if starting text is non-standard
  - [x] Fix numbering bug when indenting mixed ordered and unordered lists
  - [x] Detection of empty lines as content if list block above
  - [x] Toggling ordered type at end of block causes issues
- [x] Cleaning code:
  - [x] Clean up "apply_insert_cr" and "apply_normal_o" to internally
        incorporate formatting, numbering and indent fixes
- [ ] Add integration tests
- [ ] Add basic documentation
