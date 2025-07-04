---@class ListItem
---@field spec ListSpec List item characteristics necessary to properly render it.
---@field content string[] The text content of the list item. Each string in the array will be rendered on a new line.

---@class ListSpec
---@field is_ordered boolean
---@field is_task boolean
---@field is_completed boolean True if task which is marked completed.
---@field index integer The item index number.
---@field indent_spaces integer The indentation level of the line in number of spaces. -1 results in a line with no list marker element.

---@alias indent_spec IndentLevelSpec[] Integer array describing the number of indent spaces required to align to each level, up to current

---@class IndentLevelSpec
---@field is_ordered boolean
---@field indent_spaces integer

---@class CursorCoords
---@field row1 integer 1-indexed row number of cursor
---@field col0 integer 0-indexed column number of cursor

---@class LiCursorCoords
---@field list_index integer index of list item that the cursor is inside
---@field content_lnum integer 1-indexed line number relative to the list item contents that the cursor is on
---@field col 0-indexed column number of cursor

---@class TextBlockBounds
---@field upper integer 1-indexed upper bound line number
---@field lower integer 1-indexed lower bound line number
