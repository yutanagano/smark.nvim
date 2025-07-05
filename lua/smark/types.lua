---@class ListItem
---@field indent_rules IndentRule[] Specs for each indentation level up until the current one.
---@field is_task boolean
---@field is_completed boolean True if task which is marked completed.
---@field index integer The number of the list item (relevant if ordered list).
---@field content string[] The text content of the list item. Each string in the array will be rendered on a new line.

---@class IndentRule
---@field is_ordered boolean
---@field num_spaces integer

---@class CursorCoords
---@field row integer 1-indexed row number of cursor
---@field col integer 0-indexed column number of cursor

---@class LiCursorCoords
---@field list_index integer index of list item that the cursor is inside
---@field content_lnum integer 1-indexed line number relative to the list item contents that the cursor is on
---@field col 0-indexed column number of cursor

---@class TextBlockBounds
---@field upper integer 1-indexed upper bound line number
---@field lower integer 1-indexed lower bound line number
